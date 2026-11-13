#!/usr/bin/env bash
# name: 杀进程前检查
# desc: pkill / killall / kill 之前先列出会杀到哪些进程，写错或会误杀的拒绝
# os:   macos
# group: Claude Code
set -euo pipefail
. "${DOTFILES_DIR:-$HOME/.dotfiles}/lib/common.sh"

BIN="$HOME/.local/bin/claude-killguard"
link "$DOTFILES/bin/claude-killguard" "$BIN"

info "注册 Claude Code hook（合并进 ~/.claude/settings.json）"
# 要能拒绝命令，必须同步
R=$(CLAUDE_HOOK_SYNC=1 claude_hook "$BIN pre" 60 'PreToolUse:Bash')
if [ "$R" = unchanged ]; then ok "hook 早已注册，没有改动"
else ok "hook 已合并，原文件备份为 settings.json.bak（新开的 Claude Code 会话生效）"; fi

PROTECT="$HOME/.config/claude-killguard/protect"
mkdir -p "$(dirname "$PROTECT")"
if [ ! -f "$PROTECT" ]; then
  cat >"$PROTECT" <<'EOF'
# claude-killguard：这台机器上不能被顺手杀掉的进程。每行一个正则，匹配进程的完整命令行（ps -o command=）。
# 命中的要杀，得在命令前加 KILLGUARD_OK=<个数>。Docker、tmux / ssh / mosh、系统进程、模拟器、
# 别的 Claude Code 会话脚本里已经有了，不用写。
EOF
  ok "$(tilde "$PROTECT")：把这台机器上常驻的服务写进去"
fi
info "claude-killguard check '<命令>' 看 hook 会怎么判；claude-killguard 列出最近拒绝的命令"
