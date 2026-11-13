#!/usr/bin/env bash
# name: 两个账号 we / will
# desc: we 团队账号、will 个人账号直连；记忆、CLAUDE.md、hook、设置和会话记录两边共用
# os:   linux macos
# group: Claude Code
set -euo pipefail
. "${DOTFILES_DIR:-$HOME/.dotfiles}/lib/common.sh"

have claude || warn "还没装 Claude Code，装好后 we / will 才能用"
link "$DOTFILES/bin/claude-as" "$HOME/.local/bin/we"
link "$DOTFILES/bin/claude-as" "$HOME/.local/bin/will"
link "$DOTFILES/bin/coordinator" "$HOME/.local/bin/coordinator"
info "第一次用先各登录一次：we auth login、will auth login（浏览器授权页上看清是哪个账号）"
