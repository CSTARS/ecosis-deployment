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

## 4. mod_reqtimeout — verify it's already on

Debian's apache2 package enables `mod_reqtimeout` by default
(`/etc/apache2/mods-enabled/reqtimeout.conf`) with sane anti-slowloris
defaults. Just confirm it's active:

```bash
apache2ctl -M | grep reqtimeout
```

No new config needed unless that comes back empty.

## 5. Reverse caching (mod_cache) — deliberately NOT included here yet

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
