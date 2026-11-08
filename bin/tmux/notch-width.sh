#!/usr/bin/env bash
# 缓存每个会话的窗口标签宽度等级，避免在窗口列表循环里再嵌套窗口循环。
# 常见短标签按 8 列计算；有较长标签时按截断后的最大 12 列计算。
set -u
width_format='#{?#{n:#{W:#{?#{e|>:#{w;T:window-status-format},8},x,},#{?#{e|>:#{w;T:window-status-format},8},x,}}},12,8}'
tmux list-sessions -F '#{session_id}' 2>/dev/null | while IFS= read -r session; do
  tmux set-option -F -t "$session" @notch-cell "$width_format" 2>/dev/null || :
done
