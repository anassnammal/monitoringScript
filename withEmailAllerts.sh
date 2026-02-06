#!/bin/bash

HOST=$(hostname -f)
TO="anass.nammal@inelm.com"

# ---- alert thresholds ----
CPU_LIMIT=85
MEM_LIMIT=85
DISK_LIMIT=90
SSH_FAIL_THRESHOLD=5
SSH_WINDOW_MIN=15

COOLDOWN_SECONDS=3600
COOLDOWN_FILE="/tmp/monitor-cooldown"
touch "$COOLDOWN_FILE"
chmod 600 "$COOLDOWN_FILE"

LOCKFILE="/var/run/sys-monitor.lock"
exec 9>"$LOCKFILE" || exit 1
flock -n 9 || exit 0



GPG_KEY_ID="11F9E3B6B003F858"

# ---- CPU (accurate) + Per-core ----
read cpu_user cpu_nice cpu_system cpu_idle cpu_iowait cpu_irq cpu_softirq cpu_steal _ \
  < <(grep '^cpu ' /proc/stat)

cpu_total=$((cpu_user + cpu_nice + cpu_system + cpu_idle + cpu_iowait + cpu_irq + cpu_softirq + cpu_steal))
cpu_used=$((cpu_user + cpu_nice + cpu_system + cpu_irq + cpu_softirq + cpu_steal))

per_core_1=$(mktemp)
trap 'rm -f "$per_core_1"' EXIT
while read -r line; do
  core=$(echo "$line" | awk '{print substr($1,4)}')
  read -r _ u n s i io irq soft steal __ < <(echo "$line")
  total=$((u + n + s + i + io + irq + soft + steal))
  used=$((u + n + s + irq + soft + steal))
  echo "$core $total $used"
done < <(grep '^cpu[0-9]' /proc/stat) > "$per_core_1"

sleep 1

read cpu_user2 cpu_nice2 cpu_system2 cpu_idle2 cpu_iowait2 cpu_irq2 cpu_softirq2 cpu_steal2 _ \
  < <(grep '^cpu ' /proc/stat)

cpu_total2=$((cpu_user2 + cpu_nice2 + cpu_system2 + cpu_idle2 + cpu_iowait2 + cpu_irq2 + cpu_softirq2 + cpu_steal2))
cpu_used2=$((cpu_user2 + cpu_nice2 + cpu_system2 + cpu_irq2 + cpu_softirq2 + cpu_steal2))

cpu_delta=$((cpu_total2 - cpu_total))
if [ "$cpu_delta" -eq 0 ]; then
  cpu_load=0
  cpu_iowait=0
else
  cpu_load=$(( (cpu_used2 - cpu_used) * 100 / cpu_delta ))
  cpu_iowait=$(( (cpu_iowait2 - cpu_iowait) * 100 / cpu_delta ))
fi

# ---- Memory ----
mem_usage=$(free | awk '/Mem:/ {printf "%.0f", $3/$2 * 100}')

# ---- Disk ----
disk_usage=$(df -P / | awk 'NR==2 {gsub("%",""); print $5}')

# ---- Zombies ----
zombies=$(ps -eo pid,ppid,user,stat,cmd 2>/dev/null | awk '$4 ~ /Z/' || true)

# ---- Load average ----
load_avg=$(uptime | awk -F'load average:' '{print $2}')

# ---- Docker stats (if available) ----
docker_stats_section() {
  if command -v docker &>/dev/null; then
    echo
    echo "Docker container usage:"
    docker stats --no-stream --format "table {{.Name}}\t{{.CPUPerc}}\t{{.MemUsage}}" 2>/dev/null || echo "  (Docker daemon not available)"
  fi
}

# ---- SSH brute-force check ----
ssh_bruteforce_check() {
  local offenders
  if command -v journalctl &>/dev/null; then
    offenders=$(journalctl -u ssh -u sshd --since "${SSH_WINDOW_MIN} min ago" --no-pager 2>/dev/null \
      | grep -i "Failed password" \
      | sed -n 's/.*from \([0-9.]*\) .*/\1/p' \
      | sort | uniq -c | awk -v t="$SSH_FAIL_THRESHOLD" '$1 >= t {print $1, $2}' || true)
  else
    [ -r /var/log/auth.log ] || return
    offenders=$(grep "Failed password" /var/log/auth.log 2>/dev/null | tail -500 \
      | sed -n 's/.*from \([0-9.]*\) .*/\1/p' \
      | sort | uniq -c | awk -v t="$SSH_FAIL_THRESHOLD" '$1 >= t {print $1, $2}' || true)
  fi
  [ -n "$offenders" ] && echo "$offenders"
}

# ---- Cooldown ----
can_send_alert() {
  local type=$1
  local now last
  now=$(date +%s)
  last=
  [ -f "$COOLDOWN_FILE" ] && last=$(grep "^${type}:" "$COOLDOWN_FILE" 2>/dev/null | cut -d: -f2 | head -1)
  if [ -n "$last" ] && [ $((now - last)) -lt "$COOLDOWN_SECONDS" ]; then
    return 1
  fi
  return 0
}

mark_alert_sent() {
  local type=$1
  local now=$(date +%s)
  local tmp
  tmp=$(mktemp)
  if [ -f "$COOLDOWN_FILE" ]; then
    grep -v "^${type}:" "$COOLDOWN_FILE" > "$tmp" 2>/dev/null || true
  fi
  echo "${type}:${now}" >> "$tmp"
  mv "$tmp" "$COOLDOWN_FILE"
}

send_alert() {
  local subject=$1
  local body
  if [ -n "${2:-}" ]; then
    body=$2
  else
    body=$(cat)
  fi
  local signed

  if [ -n "$GPG_KEY_ID" ]; then
    signed=$(echo "$body" | gpg --clearsign --armor -u "$GPG_KEY_ID" 2>/dev/null) || true
    if [ -n "$signed" ]; then
      echo "$signed" | mail -s "$subject" "$TO"
    else
      echo "$body" | mail -s "$subject" "$TO"
    fi
  else
    echo "$body" | mail -s "$subject" "$TO"
  fi
}

system_snapshot() {
  echo "Host: $HOST"
  echo "Time: $(date -Is)"
  echo
  echo "Kernel: $(uname -srmo)"
  echo "Last boot: $(who -b | awk '{print $3, $4}')"
  echo
  echo "Uptime: $(uptime -p)"
  echo
  echo "Load average:$load_avg"
  echo "CPU cores: $(nproc)"
  echo
  echo "Logged-in users:"
  who | awk '{printf " - %s from %s (%s)\n", $1, ($5 ? $5 : "local"), $2}'
  echo
  echo "Total logged-in users: $(who | wc -l)"
  echo
}

# ---- Per-core CPU breakdown (uses sample 1 from main flow + current /proc/stat = sample 2) ----
per_core_cpu_section() {
  local core total1 used1 total2 used2 delta pct
  while read -r core total1 used1; do
    line2=$(grep "^cpu${core} " /proc/stat 2>/dev/null)
    [ -z "$line2" ] && continue
    read -r _ u n s i io irq soft steal __ < <(echo "$line2")
    total2=$((u + n + s + i + io + irq + soft + steal))
    used2=$((u + n + s + irq + soft + steal))
    delta=$((total2 - total1))
    if [ "$delta" -gt 0 ]; then
      pct=$(( (used2 - used1) * 100 / delta ))
      printf 'Core %s: %s%% | ' "$core" "$pct"
    fi
  done < "$per_core_1" 2>/dev/null || true
}

# ---- CPU ALERT ----
if [ "$cpu_load" -ge "$CPU_LIMIT" ]; then
  if can_send_alert cpu; then
    {
      system_snapshot
      echo "CPU usage: ${cpu_load}%"
      echo "CPU iowait: ${cpu_iowait}%"
      echo
      echo "Per-core CPU:"
      per_core_cpu_section
      echo
      docker_stats_section
      echo
      echo "Top CPU processes:"
      ps -eo pid,user,%cpu,%mem,cmd --sort=-%cpu | head -n 6
    } | send_alert "🚨 CPU Alert on $HOST (${cpu_load}%)"
    mark_alert_sent cpu
  fi
fi

# ---- MEMORY ALERT ----
if [ "$mem_usage" -ge "$MEM_LIMIT" ]; then
  if can_send_alert mem; then
    {
      system_snapshot
      echo "Memory usage: ${mem_usage}%"
      docker_stats_section
      echo
      echo "Top memory processes:"
      ps -eo pid,user,%mem,%cpu,cmd --sort=-%mem | head -n 6
    } | send_alert "🚨 Memory Alert on $HOST (${mem_usage}%)"
    mark_alert_sent mem
  fi
fi

# ---- DISK ALERT ----
if [ "$disk_usage" -ge "$DISK_LIMIT" ]; then
  if can_send_alert disk; then
    {
      system_snapshot
      echo "Disk usage: ${disk_usage}% on /"
      echo
      df -h /
    } | send_alert "🚨 Disk Alert on $HOST (${disk_usage}%)"
    mark_alert_sent disk
  fi
fi

# ---- ZOMBIE ALERT ----
if [ -n "$zombies" ]; then
  if can_send_alert zombie; then
    {
      system_snapshot
      echo "Zombie processes detected:"
      echo
      echo "$zombies"
    } | send_alert "🧟 Zombie Process Alert on $HOST"
    mark_alert_sent zombie
  fi
fi

# ---- SSH BRUTE-FORCE ALERT ----
ssh_offenders=$(ssh_bruteforce_check)
if [ -n "$ssh_offenders" ]; then
  if can_send_alert ssh; then
    {
      system_snapshot
      echo "SSH brute-force detected (>= ${SSH_FAIL_THRESHOLD} failed attempts in last ${SSH_WINDOW_MIN} min):"
      echo
      echo "Count | IP"
      echo "$ssh_offenders"
    } | send_alert "🔐 SSH Brute-Force Alert on $HOST"
    mark_alert_sent ssh
  fi
fi
