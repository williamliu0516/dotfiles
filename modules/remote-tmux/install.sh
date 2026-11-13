#!/usr/bin/env bash
# name: sshx / moshx
# desc: sshx 主机 [会话]：一步 ssh 进对方的 tmux（moshx 走 mosh）；刘海 MacBook 的状态栏布局跟过去
# os:   linux macos
# group: 终端
set -euo pipefail
. "${DOTFILES_DIR:-$HOME/.dotfiles}/lib/common.sh"

# 本机只需要 ssh（系统自带）和 mosh；tmux 跑在对方机器上
info "安装 mosh"
pkg_install mosh

mkdir -p "$HOME/.local/bin"
chmod +x "$DOTFILES/bin/sshx"
link "$DOTFILES/bin/sshx"  "$HOME/.local/bin/sshx"
link "$DOTFILES/bin/moshx" "$HOME/.local/bin/moshx"

# 刘海布局要本机机型在 config/tmux/notch-models 里；不在名单里也能用，只是不让出刘海
if [ "$OS" = macos ]; then
  model=$(/usr/sbin/sysctl -n hw.model 2>/dev/null || echo unknown)
  if px=$("$DOTFILES/bin/tmux/notch-model.sh"); then
    ok "本机 $model 在刘海名单里（让出 ${px} 像素）：连过去的 tmux 状态栏会避开刘海"
  else
    info "本机机型 $model 不在刘海名单里：sshx / moshx 照常连，状态栏不让刘海；带刘海的话在 config/tmux/notch-models 加一行"
  fi
fi
info "主机别名和密钥在 ~/.ssh/config、~/.ssh/ 里，不在 dotfiles 里，要自己搬过来；然后 sshx studio coord"
