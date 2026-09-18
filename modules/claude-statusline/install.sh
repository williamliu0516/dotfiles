#!/usr/bin/env bash
# name: Claude 状态栏
# desc: Claude Code 底部状态栏：目录、分支、模型、5 小时和每周用量（claude-status-bar 仓库）
# os:   linux macos
set -euo pipefail
. "${DOTFILES_DIR:-$HOME/.dotfiles}/lib/common.sh"

# 代码在独立仓库里，这里只调用它自己的安装脚本
SRC="https://raw.githubusercontent.com/williamliu0516/claude-status-bar/main"
LOCAL="$HOME/.claude/statusline.py"

have python3 || die "需要 python3"

# 它的安装脚本会直接覆盖 ~/.claude/statusline.py。本机那份如果和线上不同，
# 多半是还没推上去的新改动，别悄悄降级
if [ -f "$LOCAL" ]; then
  TMP="$(mktemp)"; trap 'rm -f "$TMP"' EXIT
  if curl -fsSL "$SRC/statusline.py" -o "$TMP" && ! cmp -s "$TMP" "$LOCAL"; then
    warn "本机的 statusline.py 和 GitHub 上的版本不同（可能有还没推送的改动）"
    if ! confirm "用线上版本覆盖本机的吗？"; then
      ok "保留本机版本，跳过"
      exit 0
    fi
    cp "$LOCAL" "$LOCAL.bak.$(stamp)"; warn "已备份为 statusline.py.bak.*"
  fi
fi

info "安装 claude-status-bar"
curl -fsSL "$SRC/install.sh" | sh
ok "新开的 Claude Code 会话生效"
