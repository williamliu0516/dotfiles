#!/usr/bin/env bash
# 光敲 tmux 时由 zshrc 里的 tmux 函数调用：接回最近用的会话，没有才新开。
#   --dry-run  只说会做什么，什么都不动
#
# 会话号是 tmux 自增的计数器，关掉的号不回收，号码只会涨，不代表现在有几个会话。分两步：
#
# 1. 挑会话：没人连着的里面，有东西的（开着程序或不止一个窗格）优先，同类里挑最近用过的。
#    最近用的会话如果正被别的终端连着（另一台设备、另一个标签），先问：回车接进去，两个终端一起连着
#    （窗口大小跟着最近操作的那个，tmux 的 window-size latest）；n 不接，改接没人连着的那个或新开一个。
#    换设备时按回车，同一台设备上开第二个标签时按 n。
# 2. 其余没人连着的空会话关掉：自动编号、只有一个窗格、停在 shell 提示符、底下没有子进程。
#    里面只剩滚动历史，留着只会越积越多，tmux-resurrect 还会在重启后把它们一个个恢复回来。
#    起过名字的、有东西的都不动，要关用 Alt+m z k 自己挑。
#
# 这里不再挂断 mosh 连接（2026-10-08 起给 60 秒没联系的 mosh-server 发 SIGUSR1，10-11 去掉）：iOS 上 app 一进后台
# 就不发包，后台待满一分钟的 iPad 跟断掉的连接分不出来，换台设备一登录就把它挂断了。断掉的连接现在靠 zshenv 的
# MOSH_SERVER_NETWORK_TMOUT 自己退出（12 小时），在那之前它的 tmux 客户端还算"连着"，所以第 1 步会问一下。
set -u

dry=0
case "${1:-}" in
  --dry-run) dry=1 ;;
  "") ;;
  *) echo "用法: $(basename "$0") [--dry-run]" >&2; exit 2 ;;
esac
if [ "$dry" = 0 ] && [ -n "${TMUX:-}" ]; then
  echo "已经在 tmux 里了；切会话用 Alt+s" >&2; exit 1
fi

# ── 1. 挑会话 ───────────────────────────────────────────
# 空会话：只有一个窗格、停在 shell 提示符、shell 底下没有子进程
is_empty() {
  local info pid
  info=$(tmux list-panes -s -t "=$1" -F '#{pane_pid} #{pane_current_command}' 2>/dev/null) || return 1
  [ "$(printf '%s\n' "$info" | wc -l)" -eq 1 ] || return 1
  pid=${info%% *}
  case "${info#* }" in zsh|-zsh|bash|-bash|fish|sh) ;; *) return 1 ;; esac
  [ -z "$(pgrep -P "$pid")" ]
}

# free：没人连着的里面最好的；busy：有人连着的里面最近用过的（session_activity：最后一次按键或接入的时间）
free="" free_key="" free_full=0 free_last=0 busy="" busy_last=0 empties=""
while IFS='|' read -r attached last name; do
  last=${last:-0}
  if [ "$attached" != 0 ]; then
    if [ -z "$busy" ] || [ "$last" -gt "$busy_last" ]; then busy=$name; busy_last=$last; fi
    continue
  fi
  full=1
  if is_empty "$name"; then
    full=0
    case "$name" in *[!0-9]*) ;; *) empties="$empties $name" ;; esac
  fi
  key="$full $(printf '%012d' "$last")"
  if [ -z "$free" ] || [[ "$key" > "$free_key" ]]; then free=$name; free_key=$key; free_full=$full; free_last=$last; fi
done < <(tmux list-sessions -F '#{session_attached}|#{session_activity}|#{session_name}' 2>/dev/null)

ago() {
  local s=$(( $(date +%s) - $1 ))
  if [ "$s" -lt 60 ]; then echo "${s} 秒前"
  elif [ "$s" -lt 3600 ]; then echo "$((s / 60)) 分钟前"
  else echo "$((s / 3600)) 小时前"; fi
}

target=$free join=0
if [ -n "$busy" ] && { [ "$free_full" = 0 ] || [ "$busy_last" -gt "$free_last" ]; }; then
  if [ -n "$free" ] && [ "$free_full" = 1 ]; then other="接回没人连着的会话 $free"; else other="新开一个"; fi
  ask="会话 ${busy} 在别处连着（$(ago "$busy_last")还在用）。回车接进去，n ${other}"
  if [ "$dry" = 1 ]; then
    echo "会问：$ask"
    join=1
  elif [ -t 0 ]; then
    printf '%s：' "$ask"
    IFS= read -rsn1 ans || ans=""
    echo
    case "$ans" in
      ""|y|Y) join=1 ;;
      n|N) ;;   # 没人连着的那个；它是空会话也接它，跟新开一样，只是不多占一个号
      *) echo "没动；接进去按回车，新开一个用 tmux new" >&2; exit 1 ;;
    esac
  else
    join=1
  fi
fi
[ "$join" = 1 ] && target=$busy

# ── 2. 其余的空会话 ─────────────────────────────────────
for s in $empties; do
  [ "$s" = "$target" ] && continue
  if [ "$dry" = 1 ]; then echo "关掉空会话 ${s}"; else tmux kill-session -t "=$s"; fi
done

if [ "$dry" = 1 ]; then
  if [ "$join" = 1 ]; then echo "回车：接进会话 ${busy}"
  elif [ -n "$target" ]; then echo "接回会话 ${target}"
  else echo "新开会话"; fi
  exit 0
fi
if [ "$join" = 1 ]; then
  exec tmux attach-session -t "=$target" \; display-message -d 4000 "会话 ${target} 另一个终端也连着；要新开一个用 tmux new"
fi
if [ -n "$target" ]; then
  exec tmux attach-session -t "=$target" \; display-message -d 4000 "接回了没人连着的会话 ${target}；要新开一个用 tmux new"
fi
exec tmux new-session
