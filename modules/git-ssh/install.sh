#!/usr/bin/env bash
# name: Git + SSH 配置
# desc: git 默认分支等通用设置；ssh 的 GitHub 设置。身份、主机别名、密钥都留在本机，不进仓库
# os:   linux macos
# group: 基础
set -euo pipefail
. "${DOTFILES_DIR:-$HOME/.dotfiles}/lib/common.sh"

# git：通用设置用 XDG 位置 ~/.config/git/config；姓名、邮箱这类个人信息只放本机的 ~/.gitconfig
# （git 两个都读，~/.gitconfig 优先），gh auth setup-git 之类往里写东西也不会改进仓库
link "$DOTFILES/config/git/config" "$HOME/.config/git/config"
git config --global user.name >/dev/null 2>&1 || warn "还没设 git 身份：git config --global user.name …; git config --global user.email …（写进 ~/.gitconfig，不进仓库）"

# ssh：原来的 ~/.ssh/config 不是软链、又没有 config.local 时，整份挪成 config.local，
# 本机原有的主机一个都不丢（它被最先 Include，和仓库重复的项也不冲突）
mkdir -p "$HOME/.ssh"; chmod 700 "$HOME/.ssh"
CFG="$HOME/.ssh/config"
if [ -f "$CFG" ] && [ ! -L "$CFG" ] && [ ! -e "$CFG.local" ]; then
  mv "$CFG" "$CFG.local"; chmod 600 "$CFG.local"
  warn "原来的 ~/.ssh/config 挪成了 ~/.ssh/config.local，主机别名照常可用"
fi
link "$DOTFILES/config/ssh/config" "$CFG"
ls "$HOME"/.ssh/id_* >/dev/null 2>&1 || warn "~/.ssh 里还没有密钥，从别的机器拷过来（id_ed25519_github 等）"
