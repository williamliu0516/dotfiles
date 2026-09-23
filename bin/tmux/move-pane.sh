#!/bin/sh
# 把当前窗格和相邻窗格交换位置，焦点跟着被移动的窗格走（连按就一直往那边挪）。
# 到了窗口边缘就什么都不做，不绕回另一头。
# 全屏（zoom）状态下先还原、交换、再全屏，看起来就像窗格在背后换了位置。
# 用法: move-pane.sh L|R|U|D <pane_id>
# tmux 自带的 swap-pane 有两个坑，所以要这个脚本：
#   1. 焦点默认留在原位置（停在被换过来的那个窗格上），得再 select-pane 一次
#   2. {left-of} 在最左边时会绕到最右边；全屏时几何关系不对
case "$1" in
  L) edge=pane_at_left;   to='{left-of}'  ;;
  R) edge=pane_at_right;  to='{right-of}' ;;
  U) edge=pane_at_top;    to='{up-of}'    ;;
  D) edge=pane_at_bottom; to='{down-of}'  ;;
  *) echo "用法: $0 L|R|U|D <pane_id>" >&2; exit 2 ;;
esac
pane=${2:-$TMUX_PANE}
[ -n "$pane" ] || exit 2
win=$(tmux display -p -t "$pane" '#{window_id}')
zoomed=$(tmux display -p -t "$pane" '#{window_zoomed_flag}')
# 被移动的必须是活动窗格，{left-of} 等是相对活动窗格算的
tmux select-pane -t "$pane"
[ "$zoomed" = 1 ] && tmux resize-pane -Z -t "$pane"
if [ "$(tmux display -p -t "$pane" "#{$edge}")" != 1 ]; then
  tmux swap-pane -s "$pane" -t "$win.$to" \; select-pane -t "$pane"
fi
[ "$zoomed" = 1 ] && tmux resize-pane -Z -t "$pane"
exit 0
