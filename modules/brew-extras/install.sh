#!/usr/bin/env bash
# name: 常用命令行工具
# desc: Brewfile 里的 gh、jq、uv、node、xcodegen、codex 等（已装的不升级）
# os:   macos
# group: 基础
set -euo pipefail
. "${DOTFILES_DIR:-$HOME/.dotfiles}/lib/common.sh"

BF="$DOTFILES/config/brew/Brewfile"
if brew bundle check --file="$BF" --no-upgrade >/dev/null 2>&1; then ok "Brewfile 里的都装好了"; exit 0; fi
info "安装 Brewfile 里缺的包"
if run_step "brew bundle install" brew bundle install --file="$BF" --no-upgrade; then ok "Brewfile 已装齐"
else step_failed $? "Brewfile 里的部分包" "brew bundle install --file=$(tilde "$BF")"; exit 1; fi
