#!/usr/bin/env bash
# 光敲 tmux 时由 zshrc 里的 tmux 函数调用：接回没人连着的会话，没有才新开。
#   --reap     只做第 1 步（新的 mosh 连接登录时在后台先跑一次）
#   --dry-run  只说会做什么，什么都不动
#
# 会话号是 tmux 自增的计数器，关掉的号不回收，号码只会涨，不代表现在有几个会话。
# 让会话越积越多的是断了的 mosh 连接：iPad 那头关了页面、切走 app 或被系统杀掉，Mac 上的
# mosh-server 不知道，会一直等它回来（最长一周，见 zshenv），里面的 tmux 客户端也一直算"连着"，
# 于是每次敲 tmux 都找不到空着的会话，只能新开。所以分三步：
#
# 1. 清掉断了的 mosh 连接：给 mosh-server 发 SIGUSR1，60 秒内收到过客户端消息的不会退
#    （zshenv 的 MOSH_SERVER_SIGNAL_TMOUT=60），正在用的连接都不受影响；断了的那条退出后，
#    它的 tmux 客户端跟着退，会话就空出来了。只碰 shell 里除了 tmux 客户端什么都没跑的：
#    东西都在 tmux 里，断开不丢；直接在 mosh 里跑着的程序会被一起挂断，那种连接留着不动。
# 2. 接回一个没人连着的会话：有东西的（开着程序或不止一个窗格）优先，同类里挑最近用过的。
# 3. 其余没人连着的空会话关掉：自动编号、只有一个窗格、停在 shell 提示符、底下没有子进程。
#    里面只剩滚动历史，留着只会越积越多，tmux-resurrect 还会在重启后把它们一个个恢复回来。
#    起过名字的、有东西的都不动，要关用 Alt+m z k 自己挑。
set -u

mode=attach
case "${1:-}" in
  --reap) mode=reap ;;
  --dry-run) mode=dry ;;
  "") ;;
  *) echo "用法: $(basename "$0") [--reap | --dry-run]" >&2; exit 2 ;;
esac
if [ "$mode" = attach ] && [ -n "${TMUX:-}" ]; then
  echo "已经在 tmux 里了；切会话用 Alt+s" >&2; exit 1
fi

# ── 1. 断了的 mosh 连接 ─────────────────────────────────
signaled=""
for m in $(pgrep -u "$(id -u)" -x mosh-server); do
  only_tmux=1
  for sh in $(pgrep -P "$m"); do
    # 进程名：macOS 上 tmux 客户端叫 tmux，Linux 上会被改成 "tmux: client"
    [ "$(pgrep -P "$sh" | wc -l)" -eq "$(pgrep -P "$sh" '^tmux' | wc -l)" ] || only_tmux=0
  done
  [ "$only_tmux" = 1 ] || continue
  if [ "$mode" = dry ]; then echo "SIGUSR1 -> mosh-server ${m}（60 秒没联系才会退出）"; continue; fi
  kill -USR1 "$m" 2>/dev/null && signaled="$signaled $m"
done
[ "$mode" = reap ] && exit 0

# 断了的那条退出前要走完关闭流程（重发 16 次关闭包：局域网约 0.3 秒，延迟高时最多 4 秒）。
# 最多等 1 秒，都退了就不等；没赶上的下次再说（新 mosh 连接登录时已经在后台先清过一遍）。
# 正在用的连接不会退，所以另一台设备连着时总要等满这 1 秒
if [ -n "$signaled" ]; then
  gone=0
  for _ in 1 2 3 4 5 6 7 8 9 10; do
    alive=0
    for m in $signaled; do kill -0 "$m" 2>/dev/null && alive=1; done
    [ "$alive" = 0 ] && break
    sleep 0.1
  done
  for m in $signaled; do kill -0 "$m" 2>/dev/null || gone=1; done
  [ "$gone" = 1 ] && sleep 0.2   # 等 tmux 客户端跟着退出、server 把会话记成没人连着
fi

# ── 2. 挑一个没人连着的会话 ──────────────────────────────
# 空会话：只有一个窗格、停在 shell 提示符、shell 底下没有子进程
is_empty() {
  local info pid
  info=$(tmux list-panes -s -t "=$1" -F '#{pane_pid} #{pane_current_command}' 2>/dev/null) || return 1
  [ "$(printf '%s\n' "$info" | wc -l)" -eq 1 ] || return 1
  pid=${info%% *}
  case "${info#* }" in zsh|-zsh|bash|-bash|fish|sh) ;; *) return 1 ;; esac
  [ -z "$(pgrep -P "$pid")" ]
}

target="" target_key="" empties=""
while IFS='|' read -r attached last name; do
  [ "$attached" = 0 ] || continue
  full=1
  if is_empty "$name"; then
    full=0
    case "$name" in *[!0-9]*) ;; *) empties="$empties $name" ;; esac
  fi
  key="$full $(printf '%012d' "${last:-0}")"
  if [ -z "$target" ] || [[ "$key" > "$target_key" ]]; then target=$name; target_key=$key; fi
done < <(tmux list-sessions -F '#{session_attached}|#{?session_last_attached,#{session_last_attached},0}|#{session_name}' 2>/dev/null)

# ── 3. 其余的空会话 ─────────────────────────────────────
for s in $empties; do
  [ "$s" = "$target" ] && continue
  if [ "$mode" = dry ]; then echo "关掉空会话 ${s}"; else tmux kill-session -t "=$s"; fi
done

if [ "$mode" = dry ]; then
  if [ -n "$target" ]; then echo "接回会话 ${target}"; else echo "新开会话"; fi
  exit 0
fi
if [ -n "$target" ]; then
  exec tmux attach-session -t "=$target" \; display-message -d 4000 "接回了没人连着的会话 ${target}；要新开一个用 tmux new"
fi
exec tmux new-session
