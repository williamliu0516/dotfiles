#!/usr/bin/env bash
# tmux 状态栏电池：图标 + 百分比 + 剩余/充满时间。
# 台式机（没有系统电池）什么都不输出，连分隔符也不留。
set -u
PS_DIR="${POWER_SUPPLY_DIR:-/sys/class/power_supply}"   # 可覆盖，方便测试

# 找系统电池；scope=Device 的是鼠标、键盘这类外设电池，跳过
bat=""
for d in "$PS_DIR"/*; do
  [ "$(cat "$d/type" 2>/dev/null)" = "Battery" ] || continue
  [ "$(cat "$d/scope" 2>/dev/null)" = "Device" ] && continue
  bat=$d; break
done
[ -n "$bat" ] || exit 0

pct=$(cat "$bat/capacity" 2>/dev/null || echo 0)
status=$(cat "$bat/status" 2>/dev/null || echo Unknown)

# 剩余时间（分钟）：优先 upower，它做过平滑，不会每次刷新都跳
mins=""
if command -v upower >/dev/null 2>&1; then
  dev=$(upower -e 2>/dev/null | grep -m1 "/battery_$(basename "$bat")$" || true)
  if [ -n "$dev" ]; then
    read -r val unit < <(upower -i "$dev" 2>/dev/null \
      | awk '/time to (empty|full)/ {print $4, $5; exit}')
    case "${unit:-}" in
      minute*) mins=$(awk -v v="$val" 'BEGIN{printf "%d", v}') ;;
      hour*)   mins=$(awk -v v="$val" 'BEGIN{printf "%d", v*60}') ;;
      day*)    mins=$(awk -v v="$val" 'BEGIN{printf "%d", v*1440}') ;;
    esac
  fi
fi
# 没有 upower 时按瞬时功率自己算；energy_* 配 power_now，charge_* 配 current_now
if [ -z "$mins" ]; then
  if [ -r "$bat/energy_now" ]; then n=energy_now f=energy_full r=power_now
  else                              n=charge_now f=charge_full r=current_now; fi
  now=$(cat "$bat/$n" 2>/dev/null || echo 0)
  full=$(cat "$bat/$f" 2>/dev/null || echo 0)
  rate=$(cat "$bat/$r" 2>/dev/null || echo 0)
  if [ "$rate" -gt 0 ] 2>/dev/null; then
    case "$status" in
      Discharging) mins=$(( now * 60 / rate )) ;;
      Charging)    [ "$full" -gt "$now" ] && mins=$(( (full - now) * 60 / rate )) ;;
    esac
  fi
fi

fmt() { local m=$1; if [ "$m" -ge 60 ]; then printf '%dh%02dm' $((m/60)) $((m%60)); else printf '%dm' "$m"; fi; }

LEVELS=(󰁺 󰁺 󰁻 󰁼 󰁽 󰁾 󰁿 󰂀 󰂁 󰂂 󰁹)   # 下标 = 百分比/10，四舍五入
case "$status" in
  Charging)
    icon=󰂄; color=colour2 ;;
  Full|"Not charging")
    icon=󰚥; color=colour2; mins="" ;;
  *)
    i=$(( (pct + 5) / 10 )); [ $i -gt 10 ] && i=10
    icon=${LEVELS[$i]}
    if   [ "$pct" -le 15 ]; then color=colour1
    elif [ "$pct" -le 30 ]; then color=colour3
    else                         color=colour7; fi ;;
esac

out="#[fg=$color]$icon $pct%"
[ -n "$mins" ] && [ "$mins" -gt 0 ] && out+="#[fg=colour7] $(fmt "$mins")"
printf '%s #[fg=colour8]│ ' "$out"
