#!/usr/bin/env bash
# name: Claude → tmux 窗口染色
# desc: tmux 窗口编号随 Claude Code 状态变色（运行 / 等你批准 / 完成 / 出错）
# os:   linux macos
# needs: terminal
set -euo pipefail
. "${DOTFILES_DIR:-$HOME/.dotfiles}/lib/common.sh"

HOOK="$HOME/.local/bin/tmux/claude-state.sh"
[ -x "$HOOK" ] || die "找不到 ${HOOK}，先装 Ghostty + tmux + zsh 模块"
have python3 || die "需要 python3"

info "注册 Claude Code hook（合并进 ~/.claude/settings.json）"
R=$(claude_hook "$HOOK" 5 SessionStart UserPromptSubmit Notification Stop StopFailure SessionEnd 'PreToolUse:*')
if [ "$R" = unchanged ]; then ok "hooks 早已注册，没有改动"
else ok "hooks 已合并，原文件备份为 settings.json.bak（新开的 Claude Code 会话生效）"; fi
