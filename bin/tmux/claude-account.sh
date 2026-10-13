#!/usr/bin/env bash
# tmux 状态栏：这个 tmux 里的 Claude Code 正在用哪个账号（个人订阅显示 personal，团队/企业显示组织名）。
# 按 Claude 实际拿到的 token 查，不看 ~/.claude.json：从 ssh/mosh 启动的 tmux 读不到钥匙串，里面的 Claude
# 用的是 ~/.claude/.credentials.json 那份登录，可能和桌面上的不是同一个账号（2026-10-12 就是这样）。
# 参数是 #{socket_path}：statusline.py 记下这个 tmux 已经显示了账号，Claude 窗格里的状态栏就不再重复这一格。
# statusline.py 还是旧版（没有 --account）的机器什么都不输出，连分隔符也不留。
set -u
script="$HOME/.claude/statusline.py"
[ -f "$script" ] && grep -q -- '--account' "$script" || exit 0
name=$(python3 "$script" --account --tmux "${1:-}" 2>/dev/null) || exit 0
[ -n "$name" ] || exit 0
printf '#[fg=colour7]%s #[fg=colour8]│ ' "${name//#/##}"   # 组织名里的 # 会被 tmux 当格式，转义
