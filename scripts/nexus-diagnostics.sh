#!/usr/bin/env bash
set -euo pipefail

echo "=== TIME/LOAD ==="
date -Is
uptime
echo "cpu_count=$(nproc)"

echo
echo "=== MEMORY ==="
free -h

echo
echo "=== FILESYSTEM ==="
df -h / /var /var/nexus || true

echo
echo "=== NEXUS SERVICE ==="
systemctl status nexus --no-pager | sed -n '1,25p' || true

echo
echo "=== NEXUS JOURNAL (last 80 lines) ==="
journalctl -u nexus -n 80 --no-pager || true

echo
echo "=== REST TIMINGS ==="
for endpoint in \
  "http://localhost:8081/service/rest/v1/status" \
  "http://localhost:8081/service/rest/v1/repositories"
do
  printf "%s -> " "$endpoint"
  curl -sS -u "admin:nexus1234" -o /dev/null \
    -w "status=%{http_code} total=%{time_total} connect=%{time_connect} starttransfer=%{time_starttransfer}\n" \
    "$endpoint" || true
done

echo
echo "=== SCRIPT PROBE: create_repos_from_list (payload=[]) ==="
curl -sS -u "admin:nexus1234" \
  -H "Content-Type: application/json" \
  -X POST \
  -d "[]" \
  -o /tmp/create_repos_probe.out \
  -w "status=%{http_code} total=%{time_total} connect=%{time_connect} starttransfer=%{time_starttransfer}\n" \
  "http://localhost:8081/service/rest/v1/script/create_repos_from_list/run" || true

echo "--- create_repos_probe.out (first 60 lines) ---"
sed -n '1,60p' /tmp/create_repos_probe.out || true
