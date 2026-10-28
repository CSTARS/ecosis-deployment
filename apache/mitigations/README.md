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
many different pages to dodge the per-page limit.

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
Apache ever sees the request.

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
outright block an offending subnet than throttle it. Uses `ipset`'s
`hash:net` type so bans auto-expire — run every minute via cron:

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

## 6. Reverse caching (mod_cache) — deliberately NOT included here yet

Caching anonymous GETs to `/dataset`, `/group/*`, `/organization/*` would
likely be the single biggest load-reduction, since repeat bot hits on the same
page would be served from Apache instead of reaching CKAN's single-worker
gunicorn backend. It's left out of this first pass because a misconfigured
reverse cache in front of an app with login sessions (CKAN sets an auth
cookie) can leak a cached response from one user's request to another's if the
cache doesn't strictly key/guard on the session cookie. Worth doing as a
follow-up once mod_evasive + fail2ban are confirmed to be working, with
careful testing (cache only responses from requests with no `Cookie` header,
short TTL, verify via curl with/without a logged-in session cookie that
responses never cross).

## Rollback

Each piece is independent and can be disabled on its own:
- `a2dismod evasive && systemctl restart apache2`
- `rm /etc/fail2ban/jail.d/apache-reqlimit.conf && systemctl restart fail2ban`
- hashlimit: remove the two rules (`iptables -D INPUT ...` matching what
  `subnet-hashlimit.sh enforce` added, or just reboot if rules weren't
  persisted) — or re-run the script with `monitor` mode to swap `DROP` back to `LOG`.
- subnet-ratelimit.sh: remove its cron entry and `ipset destroy bot-subnet-ban`
  (after removing the iptables rule referencing it: `iptables -D INPUT -m set --match-set bot-subnet-ban src -j DROP`).
