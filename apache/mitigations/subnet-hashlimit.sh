#!/bin/bash
# Deploy to /opt/ecosis-deployment/apache/mitigations/subnet-hashlimit.sh and
# run once on the host (idempotent - safe to re-run). Rate-limits HTTP(S)
# traffic per source /24: only requests ABOVE the rate are dropped, the
# subnet isn't banned outright, so real users sharing that ISP's address
# pool (CGNAT, mobile carriers, university NATs) aren't fully locked out -
# just capped alongside whatever's scraping from the same block.
#
# Start in LOG-only mode first (see "monitor" below) to see what WOULD be
# dropped before actually enabling DROP, so you can tune the rate without
# risking real traffic.
set -euo pipefail

RATE="${SUBNET_HASHLIMIT_RATE:-120/min}"  # sustained rate allowed per /24 - generous
                                           # default: a single frontpage load is ~18
                                           # requests (HTML + CSS/JS/images), and
                                           # several real visitors may share one /24
                                           # (CGNAT, university NAT) - iptables can't
                                           # see HTTP paths on HTTPS traffic to be any
                                           # more selective than raw request count.
BURST="${SUBNET_HASHLIMIT_BURST:-240}"    # short burst allowance above that rate
MODE="${1:-monitor}"                      # monitor | enforce | remove
NAMES="subnet_http80_mon subnet_https443_mon subnet_http80 subnet_https443"

add_rule() {
  local port="$1" name="$2" target="$3"
  iptables -C INPUT -p tcp --dport "$port" -m hashlimit \
    --hashlimit-name "$name" --hashlimit-mode srcip --hashlimit-srcmask 24 \
    --hashlimit-above "$RATE" --hashlimit-burst "$BURST" \
    --hashlimit-htable-expire 120000 \
    -j "$target" 2>/dev/null \
  || iptables -I INPUT -p tcp --dport "$port" -m hashlimit \
    --hashlimit-name "$name" --hashlimit-mode srcip --hashlimit-srcmask 24 \
    --hashlimit-above "$RATE" --hashlimit-burst "$BURST" \
    --hashlimit-htable-expire 120000 \
    -j "$target" --log-prefix "subnet-hashlimit-$port: "
}

remove_rules() {
  local pattern removed=0 rule
  pattern=$(echo "$NAMES" | tr ' ' '|')
  while IFS= read -r rule; do
    [ -z "$rule" ] && continue
    eval "iptables -D ${rule#-A }"
    removed=$((removed + 1))
  done < <(iptables -S INPUT | grep -E -- "--hashlimit-name ($pattern)")
  echo "Removed $removed subnet-hashlimit rule(s) (monitor and/or enforce)."
}

case "$MODE" in
  monitor)
    add_rule 80  subnet_http80_mon  LOG
    add_rule 443 subnet_https443_mon LOG
    echo "Monitor mode: watch 'journalctl -k -f | grep subnet-hashlimit' to see" \
         "what would be dropped at rate=$RATE burst=$BURST. Nothing is blocked yet."
    ;;
  enforce)
    add_rule 80  subnet_http80  DROP
    add_rule 443 subnet_https443 DROP
    echo "Enforcing: traffic above $RATE per /24 (burst $BURST) on ports 80/443 is now dropped."
    echo "Persist across reboot with: apt-get install -y iptables-persistent && netfilter-persistent save"
    ;;
  remove)
    remove_rules
    echo "If rules were persisted via netfilter-persistent, re-save with: netfilter-persistent save"
    ;;
  *)
    echo "Usage: $0 [monitor|enforce|remove]" >&2
    exit 1
    ;;
esac
