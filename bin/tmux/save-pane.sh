#!/usr/bin/env bash
set -euo pipefail
out="$HOME/tmux-output-$(date +%Y%m%d-%H%M%S).txt"
tmux capture-pane -p -S - > "$out"
tmux display-message "已保存 $(wc -l < "$out") 行 → $out"
