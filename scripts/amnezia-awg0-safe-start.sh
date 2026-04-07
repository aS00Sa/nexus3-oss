#!/bin/bash
# Safe bring-up of AmneziaWG awg0 on Nexus: refuse full-tunnel, auto-rollback if SSH breaks.
set -euo pipefail

CONF="/etc/amnezia/amneziawg/awg0.conf"
ROLLBACK_SEC="${AWG_ROLLBACK_SEC:-120}"

if [[ ! -f "$CONF" ]]; then
  echo "ERROR: $CONF not found"
  exit 1
fi

if grep -E '^\s*AllowedIPs\s*=' "$CONF" | grep -E '0\.0\.0\.0/0|::/0' >/dev/null 2>&1; then
  echo "REFUSE: AllowedIPs contains 0.0.0.0/0 or ::/0 (would hijack default route). Fix config first."
  exit 1
fi

# Background rollback: stop interface if we lose management access
(
  sleep "$ROLLBACK_SEC"
  echo "$(date -Is) rollback: stopping awg-quick@awg0" >> /tmp/awg-safety.log
  systemctl stop awg-quick@awg0 2>/dev/null || true
  systemctl disable awg-quick@awg0 2>/dev/null || true
) &
SAFETY_PID=$!
echo "$SAFETY_PID" > /tmp/awg-safety-rollback.pid

cleanup_safety() {
  if kill -0 "$SAFETY_PID" 2>/dev/null; then
    kill "$SAFETY_PID" 2>/dev/null || true
    wait "$SAFETY_PID" 2>/dev/null || true
  fi
  rm -f /tmp/awg-safety-rollback.pid
}

systemctl daemon-reload
systemctl enable awg-quick@awg0

if ! systemctl start awg-quick@awg0; then
  echo "ERROR: systemctl start awg-quick@awg0 failed"
  cleanup_safety
  exit 1
fi

sleep 4

if ! systemctl is-active --quiet awg-quick@awg0; then
  echo "ERROR: awg-quick@awg0 is not active"
  cleanup_safety
  exit 1
fi

echo "--- ip -br a (awg) ---"
ip -br a | grep -E 'awg0' || true
echo "--- default route ---"
ip route | grep -E '^default|awg0' || true

# Success: cancel automatic rollback
cleanup_safety
echo "$(date -Is) OK: awg-quick@awg0 is up; rollback timer cancelled" >> /tmp/awg-safety.log
echo "OK: awg-quick@awg0 active, safety rollback cancelled."
