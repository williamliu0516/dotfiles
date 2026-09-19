#!/usr/bin/env bash
# tmux 状态栏：CPU、内存、GPU 占用。macOS 和 Linux 通用。
# 输出形如 " 12% 󰍛 21.3G 󰢮 17% │ "；取不到 GPU 数据的机器不显示 GPU 段。
set -u
os=$(uname -s)

# ── CPU（整机平均，百分比）────────────────────────────────
cpu=""
if [ "$os" = Darwin ]; then
  # 各进程 %cpu 求和再除以核数：瞬时值，不用像 top 那样等 1 秒采样
  n=$(sysctl -n hw.ncpu)
  cpu=$(ps -A -o %cpu= | awk -v n="$n" '{s+=$1} END{printf "%d", s/n}')
else
  # /proc/stat 两次采样求差；上一次的值存在文件里，status-interval 决定采样间隔
  cache="${XDG_RUNTIME_DIR:-/tmp}/tmux-sysload-cpu.$UID"
  read -r _ u ni s idle io irq sirq st _ < /proc/stat
  busy=$((u + ni + s + irq + sirq + st)); total=$((busy + idle + io))
  if [ -r "$cache" ]; then
    read -r pb pt < "$cache"
    dt=$((total - pt)); [ "$dt" -gt 0 ] && cpu=$(( (busy - pb) * 100 / dt ))
  fi
  printf '%s %s\n' "$busy" "$total" > "$cache"
fi

# ── 内存（已用，GB）───────────────────────────────────────
mem="" mem_pct=""
if [ "$os" = Darwin ]; then
  total=$(sysctl -n hw.memsize)
  page=$(vm_stat | awk -F'[: .]+' '/page size/ {print $(NF-1)}')
  used=$(vm_stat | awk -v p="$page" '
    /Pages active/                 {a=$NF}
    /Pages wired down/             {w=$NF}
    /Pages occupied by compressor/ {c=$NF}
    END {gsub(/\./,"",a); gsub(/\./,"",w); gsub(/\./,"",c); printf "%d", (a+w+c)*p}')
else
  used=$(awk '/MemTotal/ {t=$2} /MemAvailable/ {a=$2} END {printf "%d", (t-a)*1024}' /proc/meminfo)
  total=$(awk '/MemTotal/ {printf "%d", $2*1024}' /proc/meminfo)
fi
if [ -n "${used:-}" ] && [ "${total:-0}" -gt 0 ]; then
  mem=$(awk -v u="$used" 'BEGIN{printf "%.1fG", u/1073741824}')
  mem_pct=$((used * 100 / total))
fi

# ── GPU（利用率，百分比）─────────────────────────────────
gpu=""
if [ "$os" = Darwin ]; then
  gpu=$(ioreg -r -d 1 -c IOAccelerator 2>/dev/null | sed -n 's/.*"Device Utilization %"=\([0-9]*\).*/\1/p' | head -1)
elif command -v nvidia-smi >/dev/null 2>&1; then
  gpu=$(nvidia-smi --query-gpu=utilization.gpu --format=csv,noheader,nounits 2>/dev/null | head -1 | tr -d ' ')
else
  for f in /sys/class/drm/card*/device/gpu_busy_percent; do
    [ -r "$f" ] && { gpu=$(cat "$f"); break; }
  done
fi

# ── 输出：>70% 黄，>90% 红 ────────────────────────────────
col() { if [ "$1" -ge 90 ]; then echo colour1; elif [ "$1" -ge 70 ]; then echo colour3; else echo colour7; fi; }
out=""
[ -n "$cpu" ]     && out+="#[fg=$(col "$cpu")] ${cpu}% "
[ -n "$mem" ]     && out+="#[fg=$(col "$mem_pct")]󰍛 ${mem} "
[ -n "$gpu" ]     && out+="#[fg=$(col "$gpu")]󰢮 ${gpu}% "
[ -n "$out" ] && printf '%s#[fg=colour8]│ ' "$out"
