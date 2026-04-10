#!/usr/bin/env bash
set -euo pipefail

# Show top request sources/endpoints in Nexus request.log for the last N hours.
# Usage:
#   nexus-requests-top.sh [hours] [request_log_path]
#
# Defaults:
#   hours=24
#   request_log_path=/var/nexus/log/request.log

HOURS="${1:-24}"
LOG_PATH="${2:-/var/nexus/log/request.log}"

if [[ ! "$HOURS" =~ ^[0-9]+$ ]] || [[ "$HOURS" -le 0 ]]; then
  echo "ERROR: hours must be a positive integer (got: $HOURS)" >&2
  exit 1
fi

if [[ ! -f "$LOG_PATH" ]]; then
  echo "ERROR: log file not found: $LOG_PATH" >&2
  exit 1
fi

echo "=== Nexus Request Diagnostics ==="
echo "log_path: $LOG_PATH"
echo "window_hours: $HOURS"
echo "generated_at_utc: $(date -u +%Y-%m-%dT%H:%M:%SZ)"
echo

gawk -v now_epoch="$(date -u +%s)" -v hours="$HOURS" '
function month_num(mon) {
  return (mon=="Jan")?1:(mon=="Feb")?2:(mon=="Mar")?3:(mon=="Apr")?4:(mon=="May")?5:(mon=="Jun")?6:(mon=="Jul")?7:(mon=="Aug")?8:(mon=="Sep")?9:(mon=="Oct")?10:(mon=="Nov")?11:12
}
function parse_epoch(ts,   a,d,mon,y,h,m,s) {
  # ts: 10/Apr/2026:10:01:52
  split(ts, a, /[\/:]/)
  d=a[1]; mon=month_num(a[2]); y=a[3]; h=a[4]; m=a[5]; s=a[6]
  return mktime(sprintf("%04d %02d %02d %02d %02d %02d", y, mon, d, h, m, s))
}
function trimq(s) {
  gsub(/^"+|"+$/, "", s)
  return s
}
BEGIN {
  from_epoch = now_epoch - (hours * 3600)
}
{
  # Common/combined log format expected:
  # IP ... [date] "METHOD URL HTTP/..." STATUS ...
  if ($0 !~ /\[[0-9]{2}\/[A-Za-z]{3}\/[0-9]{4}:[0-9]{2}:[0-9]{2}:[0-9]{2}/) next
  match($0, /\[([0-9]{2}\/[A-Za-z]{3}\/[0-9]{4}:[0-9]{2}:[0-9]{2}:[0-9]{2})/, t)
  if (t[1] == "") next
  ep = parse_epoch(t[1])
  if (ep < from_epoch) next

  ip = $1
  ip_count[ip]++
  total++

  # Pull first quoted request part
  if (match($0, /"([A-Z]+) ([^ ]+) HTTP\/[0-9.]+"/, r)) {
    method = r[1]
    url = r[2]
    split(url, u, /\?/)
    path = u[1]
    method_path_count[method " " path]++
    path_count[path]++
  }

  # crude status extraction (first 3-digit after request quote)
  if (match($0, /" [0-9]{3} /, s)) {
    status = substr(s[0], 3, 3)
    status_count[status]++
  }
}
END {
  print "requests_in_window:", total
  print ""

  print "== Top Source IP =="
  for (k in ip_count) printf "%9d  %s\n", ip_count[k], k | "sort -nr | head -20"
  close("sort -nr | head -20")
  print ""

  print "== Top URL Path =="
  for (k in path_count) printf "%9d  %s\n", path_count[k], k | "sort -nr | head -30"
  close("sort -nr | head -30")
  print ""

  print "== Top Method+Path =="
  for (k in method_path_count) printf "%9d  %s\n", method_path_count[k], k | "sort -nr | head -30"
  close("sort -nr | head -30")
  print ""

  print "== Status Codes =="
  for (k in status_count) printf "%9d  %s\n", status_count[k], k | "sort -nr"
  close("sort -nr")
}
' "$LOG_PATH"
