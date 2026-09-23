#!/bin/sh
# dwm 式自动排版：左边一个主窗格，其余在右边从上往下排成一栏，开 / 关窗格后自动重排，
# 不用再手动 Alt+m | / _ 挑布局。思路来自 ausbxuse 的 tmux 配置（github.com/ausbxuse/tmux 的 dwm.sh）：
# 每次开关窗格后 select-layout main-vertical。这里改成挂在 hook 上，所以鼠标、菜单、
# 前缀键分屏都会自动重排；再加上 dwm 的"设为主窗格"和按窗口开关自动排版。
# 用法: dwm.sh new|zoom|toggle|keep <pane_id>
#   new     新窗格，排到右侧栏最下面，焦点跟过去
#   zoom    当前窗格和主窗格互换（dwm 的 Mod+Enter）；本身就是主窗格时和栈顶互换
#   toggle  当前窗口开 / 关自动排版（关掉后分屏、布局都回到手动）
#   keep    手动调过主窗格宽度后记下来，之后重排保持这个宽度（dwm 的 mfact）
# 自动重排本身在 tmux.conf 的 hook 里，不走这个脚本，省得每次开关窗格都起一个 shell
cmd=$1
pane=${2:-$TMUX_PANE}
[ -n "$pane" ] || exit 2
win=$(tmux display -p -t "$pane" '#{window_id}') || exit 0
tiling() { [ "$(tmux show -wqv -t "$win" @tiling)" != off ]; }
retile() {
  tiling || return 0
  [ "$(tmux display -p -t "$win" '#{window_zoomed_flag}')" = 1 ] && return 0
  tmux select-layout -t "$win" main-vertical
}

case "$cmd" in
  new)
    dir=$(tmux display -p -t "$pane" '#{pane_current_path}')
    [ "$(tmux display -p -t "$win" '#{window_zoomed_flag}')" = 1 ] && tmux resize-pane -Z -t "$win"
    if tiling; then
      # 从栈底分出来，新窗格就排在最后；after-split-window hook 负责重排
      tmux split-window -v -t "$win.{bottom-right}" -c "$dir"
    else
      tmux split-window -h -t "$pane" -c "$dir"
    fi
    ;;
  zoom)
    [ "$(tmux display -p -t "$win" '#{window_panes}')" -gt 1 ] || exit 0
    [ "$(tmux display -p -t "$win" '#{window_zoomed_flag}')" = 1 ] && tmux resize-pane -Z -t "$win"
    master=$(tmux display -p -t "$win.{top-left}" '#{pane_id}')
    if [ "$pane" = "$master" ]; then
      other=$(tmux list-panes -t "$win" -F '#{pane_id}' | sed -n 2p)
    else
      other=$pane
    fi
    tmux swap-pane -d -s "$other" -t "$master"
    tmux select-pane -t "$other"
    retile
    ;;
  toggle)
    if tiling; then
      tmux set -w -t "$win" @tiling off
      tmux display "自动排版：关（当前窗口）"
    else
      tmux set -wu -t "$win" @tiling
      retile
      tmux display "自动排版：开"
    fi
    ;;
  keep)
    tiling || exit 0
    [ "$(tmux display -p -t "$win" '#{window_zoomed_flag}')" = 1 ] && exit 0
    [ "$(tmux display -p -t "$win" '#{window_panes}')" -gt 1 ] || exit 0
    w=$(tmux display -p -t "$win.{top-left}" '#{pane_width}')
    # 只记宽度不重排：右侧栏里上下调的高度要留着，下次开关窗格才会重排
    tmux set -w -t "$win" main-pane-width "$w"
    ;;
  *) echo "用法: $0 new|zoom|toggle|keep <pane_id>" >&2; exit 2 ;;
esac
exit 0
