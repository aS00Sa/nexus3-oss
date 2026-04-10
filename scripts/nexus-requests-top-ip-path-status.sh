#!/usr/bin/env bash
set -euo pipefail

# Detailed Nexus request breakdown for the last N hours:
#   - top IP+status
#   - top IP+method+path
#   - top IP+path+status
#
# Usage:
#   nexus-requests-top-ip-path-status.sh [hours] [request_log_path]
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

echo "=== Nexus Request Detailed Diagnostics ==="
echo "log_path: $LOG_PATH"
echo "window_hours: $HOURS"
echo "generated_at_utc: $(date -u +%Y-%m-%dT%H:%M:%SZ)"
echo

gawk -v now_epoch="$(date -u +%s)" -v hours="$HOURS" '
function month_num(mon) {
  return (mon=="Jan")?1:(mon=="Feb")?2:(mon=="Mar")?3:(mon=="Apr")?4:(mon=="May")?5:(mon=="Jun")?6:(mon=="Jul")?7:(mon=="Aug")?8:(mon=="Sep")?9:(mon=="Oct")?10:(mon=="Nov")?11:12
}
function parse_epoch(ts,   a,d,mon,y,h,m,s) {
  split(ts, a, /[\/:]/)
  d=a[1]; mon=month_num(a[2]); y=a[3]; h=a[4]; m=a[5]; s=a[6]
  return mktime(sprintf("%04d %02d %02d %02d %02d %02d", y, mon, d, h, m, s))
}
BEGIN {
  from_epoch = now_epoch - (hours * 3600)
}
{
  if ($0 !~ /\[[0-9]{2}\/[A-Za-z]{3}\/[0-9]{4}:[0-9]{2}:[0-9]{2}:[0-9]{2}/) next
  match($0, /\[([0-9]{2}\/[A-Za-z]{3}\/[0-9]{4}:[0-9]{2}:[0-9]{2}:[0-9]{2})/, t)
  if (t[1] == "") next
  ep = parse_epoch(t[1])
  if (ep < from_epoch) next

  ip = $1
  total++

  method = "-"
  path = "-"
  if (match($0, /"([A-Z]+) ([^ ]+) HTTP\/[0-9.]+"/, r)) {
    method = r[1]
    split(r[2], p, /\?/)
    path = p[1]
  }

  status = "000"
  if (match($0, /" [0-9]{3} /, s)) {
    status = substr(s[0], 3, 3)
  }

  ip_status[ip " | " status]++
  ip_method_path[ip " | " method " " path]++
  ip_path_status[ip " | " path " | " status]++
}
END {
  print "requests_in_window:", total
  print ""

  print "== Top IP + Status =="
  for (k in ip_status) printf "%9d  %s\n", ip_status[k], k | "sort -nr | head -40"
  close("sort -nr | head -40")
  print ""

  print "== Top IP + Method + Path =="
  for (k in ip_method_path) printf "%9d  %s\n", ip_method_path[k], k | "sort -nr | head -60"
  close("sort -nr | head -60")
  print ""

  print "== Top IP + Path + Status =="
  for (k in ip_path_status) printf "%9d  %s\n", ip_path_status[k], k | "sort -nr | head -80"
  close("sort -nr | head -80")
}
' "$LOG_PATH"
