#!/usr/bin/env bash
# 本机在 config/tmux/notch-models 名单里就输出刘海像素宽度，退出码 0；不在名单里（或不是 Mac）退出码 1。
# tmux.conf 和 bin/sshx 都调它，名单只维护一处
set -u
[ "$(uname -s)" = Darwin ] || exit 1
here=$(dirname "$(readlink -f "$0")")
list="$here/../../config/tmux/notch-models"
model=$(/usr/sbin/sysctl -n hw.model 2>/dev/null) || exit 1
px=$(awk -v m="$model" '$1 == m { print $2; exit }' "$list" 2>/dev/null)
[ -n "$px" ] || exit 1
echo "$px"
