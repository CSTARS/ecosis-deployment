# Bot-mitigation configs for the production Apache host

Apache here runs directly on the production VM (not containerized, not part of
`docker-compose.yaml`), so these files aren't auto-deployed — copy them to the
paths noted in each file's header comment and apply manually over SSH.

## 1. Diagnose first

Before tuning any thresholds below, find out whether the bot traffic is a
handful of abusive IPs or broadly distributed. Run on the host:

```bash
# Top client IPs in the last 6 hours
N=6; { zcat -f /var/log/apache2/access.log.*.gz 2>/dev/null; cat /var/log/apache2/access.log; } \
  | awk -v d="$(date -d "-$N hours" '+%d/%b/%Y:%H')" '$4 > "["d {print $1}' \
  | sort | uniq -c | sort -rn | head -30

# Top User-Agent strings
awk -F'"' '{print $6}' /var/log/apache2/access.log | sort | uniq -c | sort -rn | head -30

# Which IPs are hitting /group/* and /organization/*
awk '$7 ~ /^\/(group|organization)(\/|$)/ {print $1}' /var/log/apache2/access.log \
  | sort | uniq -c | sort -rn | head -30

# Concentration by /24 subnet (few subnets dominating => small botnet; spread out => distributed)
awk '{print $1}' /var/log/apache2/access.log | awk -F. '{print $1"."$2"."$3".0/24"}' \
  | sort | uniq -c | sort -rn | head -30
```

If a handful of IPs/subnets dominate, you can `iptables -A INPUT -s <ip> -j DROP`
them directly for immediate relief while the rest of this is deployed.

## 2. mod_evasive — per-IP, per-page throttling

Trips on rapid repeat hits to the *same* URI, which is exactly the pattern in
the pasted logs (the same `/group/<uuid>` hit over and over, sub-second
apart). Also caps total requests/sec per IP across the vhost.

```bash
apt-get update && apt-get install -y libapache2-mod-evasive
cp apache/mitigations/evasive.conf /etc/apache2/mods-available/evasive.conf
mkdir -p /var/log/mod_evasive && chown www-data:www-data /var/log/mod_evasive
a2enmod evasive
apache2ctl configtest && systemctl restart apache2
```

## 3. fail2ban — catches abuse mod_evasive's per-page logic can miss

Bans an IP sustaining >300 req/min against either vhost, with an escalating
ban time on repeat offenses. Complements mod_evasive, which only looks at one
page/the whole site per second — this catches a client spreading load across
many different pages to dodge the per-page limit. Static assets
(`/webassets/*`, `.css`/`.js`/images/fonts) are excluded from the count, so a
normal page load (easily 15+ asset requests alongside the actual page) doesn't
inflate the numbers — only real route hits count toward the ban.

```bash
apt-get update && apt-get install -y fail2ban
cp apache/mitigations/fail2ban-filter.conf /etc/fail2ban/filter.d/apache-reqlimit.conf
cp apache/mitigations/fail2ban-jail.conf /etc/fail2ban/jail.d/apache-reqlimit.conf
systemctl restart fail2ban
fail2ban-client status apache-reqlimit
```

**Troubleshooting:** if `systemctl restart fail2ban` fails with `Have not found any
log file for sshd jail`, this host has no `/var/log/auth.log` (journald-only,
no rsyslog) and fail2ban's stock `sshd` jail (enabled by default) crashes the
whole service trying to find it — unrelated to the config above. Fix by
pointing just that jail at journald:

```bash
cp apache/mitigations/fail2ban-sshd-backend-fix.conf /etc/fail2ban/jail.d/sshd-systemd-backend.conf
systemctl restart fail2ban
```

## 4. Per-/24 subnet mitigation — for distributed scrapes

If diagnosis (step 1) shows no single IP crossing mod_evasive/fail2ban's
per-IP thresholds, but requests cluster heavily within the same `/24` (e.g.
many different IPs under `223.109.252.0/24` each making a handful of
requests — a scrape rotating through one ISP's address pool), per-IP tools
have a low ceiling against it. Two options, pick one:

**`subnet-hashlimit.sh` (recommended) — rate-limit per /24, don't block it outright.**
Uses `iptables`'s `hashlimit` module to drop only the traffic *above* a rate
from each source `/24`, so a few real users sharing that ISP's address block
(CGNAT, mobile carrier, university NAT) aren't fully locked out — just capped
alongside whatever's scraping from the same block. Runs in-kernel, before
Apache ever sees the request — which also means it **can't see the HTTP path**
on HTTPS traffic (it's encrypted at that layer), so unlike fail2ban/
subnet-ratelimit.sh below, it can't exclude static assets from the count. The
default rate (120/min, burst 240 per `/24`) is set generously to account for
that — a single frontpage load is ~18 requests, and several real visitors may
share one `/24`. Always verify with `monitor` mode before `enforce`.

```bash
chmod +x apache/mitigations/subnet-hashlimit.sh

# 1. Monitor mode first — logs what WOULD be dropped, blocks nothing
sudo ./apache/mitigations/subnet-hashlimit.sh monitor
sudo journalctl -k -f | grep subnet-hashlimit

# 2. Once the rate looks right (tune with SUBNET_HASHLIMIT_RATE /
#    SUBNET_HASHLIMIT_BURST env vars and re-run if needed), enforce it:
sudo ./apache/mitigations/subnet-hashlimit.sh enforce

# rules don't survive reboot unless saved:
apt-get install -y iptables-persistent && netfilter-persistent save
```

**`subnet-ratelimit.sh` (alternative) — hard-ban the whole /24 once it trips a threshold.**
Use this instead of (not alongside) `subnet-hashlimit.sh` if you'd rather
outright block an offending subnet than throttle it. Reads the access log
(not raw packets), so unlike the hashlimit script above it *can* exclude
static assets — the default threshold (60 dynamic-route requests/min per
`/24`) reflects that narrower, cleaner count, not raw total requests. Uses
`ipset`'s `hash:net` type so bans auto-expire — run every minute via cron:

```bash
apt-get install -y ipset
chmod +x apache/mitigations/subnet-ratelimit.sh
cp apache/mitigations/subnet-ratelimit.sh /opt/ecosis-deployment/apache/mitigations/subnet-ratelimit.sh
# crontab -e (as root):
# * * * * * /opt/ecosis-deployment/apache/mitigations/subnet-ratelimit.sh
```

## 5. mod_reqtimeout — verify it's already on

Debian's apache2 package enables `mod_reqtimeout` by default
(`/etc/apache2/mods-enabled/reqtimeout.conf`) with sane anti-slowloris
defaults. Just confirm it's active:

```bash
sudo apache2ctl -M | grep reqtimeout
```

No new config needed unless that comes back empty (`sudo` is required since
`apache2ctl` lives in `/usr/sbin`, which isn't always on a regular user's `$PATH`).

## 6. Reverse caching (mod_cache) — 1 hour, narrowly scoped

Caches anonymous GETs for 1 hour on two namespaces, likely the single biggest
load-reduction here: repeat bot hits on the same page get served from
Apache's disk cache instead of reaching the backend at all.

- `cache-search.conf` → `ecosis.org`'s `/search/`, `/package/`, `/webassets/`,
  `/base/`
- `cache-data.conf` → `data.ecosis.org`'s `/dataset/`, `/organization/`,
  `/group/`, `/webassets/`, `/base/` — `/organization/` and `/group/` are the
  exact paths the original bot logs that started this whole effort were
  hammering; `/webassets/` and `/base/` are static CSS/JS/image paths, safe
  to cache regardless of how the dynamic-page rules shake out

Both files apply the same base rules, but **not** via `<If>` around
`CacheEnable`/`CacheDisable` — this Apache build refuses to start with either
shape (`CacheEnable`/`CacheDisable cannot occur within <If> section`).
Instead: a `RewriteCond [OR]` chain sets an env var (`CACHE_SKIP`) whenever
the request fails *any* of the rules below, then `mod_headers` injects
`Cache-Control: no-store` when it's set, which mod_cache obeys — no `<If>`
needed anywhere. Adding a future rule is one more `RewriteCond ... [OR]` line
in the relevant file. Current conditions (all must hold for a response to be
cached):

- a CKAN session cookie is present (`ckan=...` — CKAN's
  `beaker.session.key`, see `containers/ckan/template.ini`) — i.e. logged-in/
  personalized requests
- the query string contains `q=` (an actual search query, not a static
  listing page)
- the path contains `/user/`
- (CKAN only) the path is a write/management action — `/new`, `/edit`,
  `/delete`, `/member_new`, `/member_delete` — never cached even if somehow
  reached anonymously

When none of the above apply, freshness comes from `CacheDefaultExpire`/
`CacheMaxExpire` (both set to 3600), not an injected header. Getting this
working against live CKAN traffic took three fixes, each found by testing
against a real `/dataset/<slug>` page and watching `/var/log/apache2/error.log`
and `curl`'s response headers:

- CKAN sends `Cache-Control: private` on every response. mod_cache is a
  *shared* cache and refuses to store anything marked `private` by default,
  regardless of any `max-age` also present — `CacheStorePrivate On` overrides
  that refusal.
- CKAN's dynamically-rendered pages send no `Last-Modified`, `ETag`, or
  `Expires` header at all. mod_cache also refuses to store a response with no
  validator of some kind, by default — `CacheIgnoreNoLastMod On` overrides
  *that* refusal.
- `CacheRoot` is set globally in Debian's
  `/etc/apache2/mods-enabled/cache_disk.conf`, but a vhost-scoped `CacheEnable`
  (ours, pulled in via `IncludeOptional` inside `<VirtualHost>`) does **not**
  inherit it on this host — `error.log` showed `AH00703: Cannot cache files to
  disk without a CacheRoot specified` on every request despite the global
  config existing. Fixed by re-declaring `CacheRoot /var/cache/apache2/mod_cache_disk`
  (same path) directly in both `cache-*.conf` files.

All three are now set in both files. If caching still doesn't take (`X-Cache`
stays `MISS` on a repeat request within the hour), check
`/var/log/apache2/error.log` for further `mod_cache`/`mod_cache_disk`
warnings, and confirm with
`curl -sI ... | grep -iE "cache-control|last-modified|etag|expires"` what the
backend is actually sending.

mod_cache also strips any `Set-Cookie` header from what it stores/serves,
regardless of the rules above — defense-in-depth against the leak risk this
section used to be deferred over.

```bash
mkdir -p /etc/apache2/mitigations
cp apache/mitigations/cache-search.conf /etc/apache2/mitigations/cache-search.conf
cp apache/mitigations/cache-data.conf /etc/apache2/mitigations/cache-data.conf
a2enmod cache cache_disk headers
apache2ctl configtest && systemctl reload apache2
```

**Verify** (repeat each GET — first should `MISS`, second within the hour
should `HIT`; the cookie/query/user/action cases should never `HIT`):

```bash
curl -sI https://ecosis.org/search/ | grep -i x-cache
curl -sI https://ecosis.org/search/ | grep -i x-cache
curl -sI -b "ckan=faketoken" https://ecosis.org/search/ | grep -i x-cache
curl -sI "https://ecosis.org/search/?q=grass" | grep -i x-cache
curl -sI "https://ecosis.org/search/user/profile" | grep -i x-cache
curl -sI https://ecosis.org/package/<a-real-package-slug> | grep -i x-cache
curl -sI https://ecosis.org/webassets/<a-real-asset-path> | grep -i x-cache
curl -sI https://data.ecosis.org/webassets/<a-real-asset-path> | grep -i x-cache

curl -sI https://data.ecosis.org/organization/<a-real-org-slug> | grep -i x-cache
curl -sI https://data.ecosis.org/organization/<a-real-org-slug> | grep -i x-cache
curl -sI https://data.ecosis.org/group/<a-real-group-slug> | grep -i x-cache
curl -sI -b "ckan=faketoken" https://data.ecosis.org/organization/<a-real-org-slug> | grep -i x-cache
curl -sI "https://data.ecosis.org/dataset/new" | grep -i x-cache

ls -la /var/cache/apache2/mod_cache_disk/ 2>/dev/null | head
```

`CacheMaxFileSize 5000000` in `cache-data.conf` (~5MB) keeps large resource
downloads under `/dataset/*/resource/*` from filling the disk cache with
single files — raise or drop it if resource downloads should be cached too.

## Uninstall / rollback

Each piece can be removed independently, or all at once:

```bash
sudo ./apache/mitigations/uninstall.sh
```

This disables mod_evasive, removes the fail2ban jail/filter (leaving the
unrelated sshd-backend fix in place), and tears down whichever subnet
mitigation you deployed. Individual pieces, if you only want one:

- mod_evasive: `a2dismod evasive && systemctl restart apache2`
- fail2ban: `rm /etc/fail2ban/jail.d/apache-reqlimit.conf /etc/fail2ban/filter.d/apache-reqlimit.conf && systemctl restart fail2ban`
- hashlimit: `sudo ./apache/mitigations/subnet-hashlimit.sh remove`
- subnet-ratelimit: `sudo ./apache/mitigations/subnet-ratelimit.sh teardown`
  (removes the iptables rule, destroys the ipset, and removes its crontab entry)
- cache: `rm /etc/apache2/mitigations/cache-*.conf && a2dismod cache_disk cache && systemctl reload apache2`
  (`headers`/`rewrite` are left enabled - too broadly useful to assume nothing
  else on the host depends on them)
  (the `IncludeOptional` lines left in the vhosts are harmless with the files gone)
