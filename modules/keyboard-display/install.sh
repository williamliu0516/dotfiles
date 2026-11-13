#!/usr/bin/env bash
# name: Claude 键盘屏幕
# desc: 机械键盘的 142×428 屏幕显示 Claude 会话状态；会问屏幕的 IP（切换快捷键仅 macOS）
# os:   linux macos
# group: 硬件（默认不装）
# default: off
set -euo pipefail
. "${DOTFILES_DIR:-$HOME/.dotfiles}/lib/common.sh"

# 代码在独立仓库里，这里只调用它自己的安装脚本；它会问键盘屏幕的 IP，
# 也可以提前设 PANEL_IP 跳过提问
info "安装 context-keyboard-display"
curl -fsSL https://raw.githubusercontent.com/williamliu0516/context-keyboard-display/main/install.sh | sh
