#!/bin/bash
# Deploy to /opt/ecosis-deployment/apache/mitigations/subnet-ratelimit.sh on the
# host and run every minute via cron (see README). Groups requests by /24 —
# catches a distributed scrape spread across many IPs in the same ISP block,
# which per-IP tools (fail2ban, mod_evasive) can't see since no single IP
# crosses their threshold. Bans auto-expire via ipset's timeout, no separate
# unban step needed.
set -euo pipefail

LOG=/var/log/apache2/access.log
STATE_DIR=/var/lib/subnet-ratelimit
OFFSET_FILE="$STATE_DIR/offset"
SET_NAME=bot-subnet-ban
THRESHOLD="${SUBNET_RATELIMIT_THRESHOLD:-150}"   # requests/min from one /24 before banning
BANTIME="${SUBNET_RATELIMIT_BANTIME:-3600}"      # seconds

# Known-good ranges never counted toward a ban, regardless of volume.
# Refresh against the publishers' current ranges before relying on this long-term:
#   https://developers.google.com/static/search/apis/ipranges/googlebot.json
#   https://www.bing.com/toolbox/bingbot.json
WHITELIST_REGEX='^(66\.249\.|157\.55\.39\.|207\.46\.13\.)'

mkdir -p "$STATE_DIR"

ipset list "$SET_NAME" >/dev/null 2>&1 || ipset create "$SET_NAME" hash:net timeout "$BANTIME"
iptables -C INPUT -m set --match-set "$SET_NAME" src -j DROP 2>/dev/null \
  || iptables -I INPUT -m set --match-set "$SET_NAME" src -j DROP

CUR_SIZE=$(stat -c %s "$LOG")
LAST_OFFSET=$(cat "$OFFSET_FILE" 2>/dev/null || echo 0)
[ "$LAST_OFFSET" -gt "$CUR_SIZE" ] && LAST_OFFSET=0   # log rotated/truncated since last run

tail -c +"$((LAST_OFFSET + 1))" "$LOG" \
  | awk '{print $1}' \
  | grep -vE "$WHITELIST_REGEX" \
  | awk -F. '{print $1"."$2"."$3".0/24"}' \
  | sort | uniq -c | sort -rn \
  | awk -v th="$THRESHOLD" '$1 >= th {print $1, $2}' \
  | while read -r count net; do
      ipset add "$SET_NAME" "$net" timeout "$BANTIME" -exist
      logger -t subnet-ratelimit "banned $net ($count req in last interval, threshold $THRESHOLD)"
    done

echo "$CUR_SIZE" > "$OFFSET_FILE"
