#!/usr/bin/env bash
# name: Claude 键盘屏幕
# desc: 在机械键盘的 142×428 屏幕上显示 Claude Code 会话状态（切换快捷键仅 macOS）
# os:   linux macos
set -euo pipefail
. "${DOTFILES_DIR:-$HOME/.dotfiles}/lib/common.sh"

# 代码在独立仓库里，这里只调用它自己的安装脚本；它会问键盘屏幕的 IP，
# 也可以提前设 PANEL_IP 跳过提问
info "安装 context-keyboard-display"
curl -fsSL https://raw.githubusercontent.com/williamliu0516/context-keyboard-display/main/install.sh | sh
