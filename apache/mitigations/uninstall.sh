#!/bin/bash
# Deploy to /opt/ecosis-deployment/apache/mitigations/uninstall.sh and run on
# the host to remove everything this directory installed. Safe to run even if
# only some pieces were ever deployed - each step no-ops if its piece isn't present.
set -uo pipefail

echo "--- mod_evasive ---"
a2dismod evasive 2>/dev/null && systemctl restart apache2 && echo "disabled" \
  || echo "not enabled, skipping"

echo "--- fail2ban jail ---"
if [ -f /etc/fail2ban/jail.d/apache-reqlimit.conf ]; then
  rm -f /etc/fail2ban/jail.d/apache-reqlimit.conf /etc/fail2ban/filter.d/apache-reqlimit.conf
  systemctl restart fail2ban
  echo "removed"
else
  echo "not present, skipping"
fi
echo "(leaving /etc/fail2ban/jail.d/sshd-systemd-backend.conf in place - that's an"
echo " unrelated host fix, not a bot-mitigation rule.)"

echo "--- subnet-hashlimit (iptables hashlimit) ---"
if [ -x "$(dirname "$0")/subnet-hashlimit.sh" ]; then
  "$(dirname "$0")/subnet-hashlimit.sh" remove
else
  echo "subnet-hashlimit.sh not found next to this script, skipping"
fi

echo "--- subnet-ratelimit (ipset + cron) ---"
if [ -x "$(dirname "$0")/subnet-ratelimit.sh" ]; then
  "$(dirname "$0")/subnet-ratelimit.sh" teardown
else
  echo "subnet-ratelimit.sh not found next to this script, skipping"
fi

echo "--- cache (mod_cache) ---"
removed_cache=0
for f in cache-search.conf cache-data.conf; do
  if [ -f "/etc/apache2/mitigations/$f" ]; then
    rm -f "/etc/apache2/mitigations/$f"
    removed_cache=1
  fi
done
if [ "$removed_cache" = 1 ]; then
  a2dismod cache_disk cache 2>/dev/null
  systemctl reload apache2
  echo "removed (mod_headers/mod_rewrite left enabled - too broadly useful to"
  echo " assume nothing else on the host depends on them; the IncludeOptional"
  echo " lines left in the vhosts are harmless with the target files gone)"
else
  echo "not present, skipping"
fi

echo "Done. mod_reqtimeout was never touched by this repo (it's a stock Debian"
echo "default) and is left alone."
