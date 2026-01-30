#!/usr/bin/env bash
# server-stats.sh - Basic server performance stats for Linux
# Usage: ./server-stats.sh

set -euo pipefail

# ---------- helpers ----------
hr() { printf '%*s\n' 70 '' | tr ' ' '-'; }
section() { hr; echo "$1"; hr; }

have() { command -v "$1" >/dev/null 2>&1; }

human_bytes() {
  # input: bytes (integer) -> human readable (GiB/MiB/etc)
  awk -v b="${1:-0}" '
    function human(x,  unit) {
      unit="B KiB MiB GiB TiB PiB"
      split(unit,u," ")
      for (i=1; x>=1024 && i<6; i++) x/=1024
      return sprintf("%.2f %s", x, u[i])
    }
    BEGIN { if (b < 0) b = 0; print human(b) }
  '
}

percent() {
  # percent used = used/total*100
  awk -v used="${1:-0}" -v total="${2:-0}" '
    BEGIN {
      if (total <= 0) { print "N/A"; exit }
      printf "%.1f", (used/total)*100
    }'
}

# ---------- CPU ----------
cpu_usage() {
  # Read /proc/stat twice and compute usage over the interval
  local u1 n1 s1 i1 w1 ir1 si1 st1
  local u2 n2 s2 i2 w2 ir2 si2 st2
  read -r _ u1 n1 s1 i1 w1 ir1 si1 st1 _ _ < /proc/stat
  local idle1=$((i1 + w1))
  local total1=$((u1 + n1 + s1 + i1 + w1 + ir1 + si1 + st1))

  sleep 0.6

  read -r _ u2 n2 s2 i2 w2 ir2 si2 st2 _ _ < /proc/stat
  local idle2=$((i2 + w2))
  local total2=$((u2 + n2 + s2 + i2 + w2 + ir2 + si2 + st2))

  local idle_delta=$((idle2 - idle1))
  local total_delta=$((total2 - total1))

  awk -v idle="$idle_delta" -v total="$total_delta" '
    BEGIN {
      if (total <= 0) { print "N/A"; exit }
      printf "%.1f%%\n", (1 - (idle/total))*100
    }'
}

# ---------- Memory ----------
memory_usage() {
  # Uses MemAvailable (best practical "free") for Linux
  local mem_total_kb mem_avail_kb
  mem_total_kb=$(awk '/^MemTotal:/ {print $2}' /proc/meminfo)
  mem_avail_kb=$(awk '/^MemAvailable:/ {print $2}' /proc/meminfo)

  if [[ -z "${mem_total_kb}" || -z "${mem_avail_kb}" ]]; then
    echo "Memory stats unavailable."
    return
  fi

  local total_b=$((mem_total_kb * 1024))
  local free_b=$((mem_avail_kb * 1024))
  local used_b=$((total_b - free_b))

  local used_pct free_pct
  used_pct=$(percent "$used_b" "$total_b")
  free_pct=$(percent "$free_b" "$total_b")

  printf "Used: %s (%s%%)\n" "$(human_bytes "$used_b")" "$used_pct"
  printf "Free: %s (%s%%)\n" "$(human_bytes "$free_b")" "$free_pct"
  printf "Total: %s\n" "$(human_bytes "$total_b")"
}

# ---------- Disk ----------
df_supports_B1() {
  df -B1 / >/dev/null 2>&1
}

disk_usage_total() {
  # Total across local filesystems; excludes tmpfs/devtmpfs by default.
  # Compute using bytes for accurate percentages.
  local out
  if df_supports_B1; then
    out=$(df -P -B1 -x tmpfs -x devtmpfs 2>/dev/null || true)
    awk '
      NR==1 {next}
      {size+=$2; used+=$3; avail+=$4}
      END {
        if (size<=0) { print "Disk stats unavailable."; exit }
        used_pct=(used/size)*100
        free_pct=(avail/size)*100
        printf "Used:  %d bytes (%.1f%%)\nFree:  %d bytes (%.1f%%)\nTotal: %d bytes\n", used, used_pct, avail, free_pct, size
      }' <<<"$out" \
    | awk '
      function human(x,  unit){ unit="B KiB MiB GiB TiB PiB"; split(unit,u," "); for(i=1; x>=1024 && i<6; i++) x/=1024; return sprintf("%.2f %s", x, u[i]) }
      /Used:/  {printf "Used:  %s (%s)\n", human($2), $4}
      /Free:/  {printf "Free:  %s (%s)\n", human($2), $4}
      /Total:/ {printf "Total: %s\n", human($2)}
    '
  else
    # Fallback: df -Pk (1K blocks), convert to bytes
    out=$(df -P -k -x tmpfs -x devtmpfs 2>/dev/null || true)
    awk '
      NR==1 {next}
      {size+=$2; used+=$3; avail+=$4}
      END {
        if (size<=0) { print "Disk stats unavailable."; exit }
        size_b=size*1024; used_b=used*1024; avail_b=avail*1024
        used_pct=(used_b/size_b)*100
        free_pct=(avail_b/size_b)*100
        printf "Used: %d bytes (%.1f%%)\nFree: %d bytes (%.1f%%)\nTotal: %d bytes\n", used_b, used_pct, avail_b, free_pct, size_b
      }' <<<"$out" \
    | awk '
      function human(x,  unit){ unit="B KiB MiB GiB TiB PiB"; split(unit,u," "); for(i=1; x>=1024 && i<6; i++) x/=1024; return sprintf("%.2f %s", x, u[i]) }
      /Used:/  {printf "Used:  %s (%s)\n", human($2), $4}
      /Free:/  {printf "Free:  %s (%s)\n", human($2), $4}
      /Total:/ {printf "Total: %s\n", human($2)}
    '
  fi
}

# ---------- Top processes ----------
top_processes_cpu() {
  if ! have ps; then echo "ps not found"; return; fi
  echo "PID     %CPU   COMMAND"
  ps -eo pid=,%cpu=,comm= --sort=-%cpu | head -n 5 | awk '{printf "%-7s %-6s %s\n",$1,$2,$3}'
}

top_processes_mem() {
  if ! have ps; then echo "ps not found"; return; fi
  echo "PID     %MEM   COMMAND"
  ps -eo pid=,%mem=,comm= --sort=-%mem | head -n 5 | awk '{printf "%-7s %-6s %s\n",$1,$2,$3}'
}

# ---------- Stretch stats ----------
os_version() {
  if [[ -r /etc/os-release ]]; then
    # shellcheck disable=SC1091
    . /etc/os-release
    echo "${PRETTY_NAME:-${NAME:-unknown}}"
  else
    uname -srmo 2>/dev/null || echo "unknown"
  fi
}

uptime_pretty() {
  if have uptime; then
    uptime -p 2>/dev/null || true
  fi
  if [[ -r /proc/uptime ]]; then
    awk '{
      s=int($1);
      d=int(s/86400); s%=86400;
      h=int(s/3600); s%=3600;
      m=int(s/60);
      out="";
      if(d>0) out=out d "d ";
      if(h>0) out=out h "h ";
      out=out m "m";
      print out
    }' /proc/uptime
  fi
}

load_avg() {
  [[ -r /proc/loadavg ]] && awk '{print $1, $2, $3}' /proc/loadavg || echo "N/A"
}

logged_in_users() {
  if have who; then
    who | awk '{print $1}' | sort | uniq -c | awk '{printf "  %-5s %s\n",$1,$2}'
  else
    echo "who not found"
  fi
}

failed_logins() {
  # lastb often requires root; show friendly message if not permitted.
  if have lastb; then
    if ! lastb 2>/dev/null | head -n 1 >/dev/null; then
      echo "Not permitted (try sudo) or no btmp data."
      return
    fi
    lastb 2>/dev/null | head -n 10
  else
    echo "lastb not found"
  fi
}

# ---------- main ----------
section "SERVER PERFORMANCE STATS"
echo "Host:  $(hostname 2>/dev/null || echo N/A)"
echo "OS:    $(os_version)"
echo "Uptime: $(uptime_pretty | head -n 1)"
echo "Load:  $(load_avg)"
echo "Time:  $(date)"
echo

section "Total CPU usage"
cpu_usage
echo

section "Total memory usage (Free vs Used including percentage)"
memory_usage
echo

section "Total disk usage (Free vs Used including percentage)"
disk_usage_total
echo

section "Top 5 processes by CPU usage"
top_processes_cpu
echo

section "Top 5 processes by memory usage"
top_processes_mem
echo

section "Logged in users (counts)"
logged_in_users
echo

section "Failed login attempts (last 10, if available)"
failed_logins
echo
