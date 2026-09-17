#!/usr/bin/env bash
# Ghostty + tmux + zsh 终端环境一键安装
#   curl -fsSL https://raw.githubusercontent.com/williamliu0516/dotfiles/main/install.sh | bash
set -euo pipefail

REPO_URL="${DOTFILES_REPO:-https://github.com/williamliu0516/dotfiles.git}"
DOTFILES="${DOTFILES_DIR:-$HOME/.dotfiles}"
FONT_VER="${MAPLE_FONT_VERSION:-v7.9}"

bold()  { printf '\033[1m%s\033[0m\n' "$*"; }
info()  { printf '\033[38;5;111m▎\033[0m %s\n' "$*"; }
ok()    { printf '\033[38;5;77m  ✓\033[0m %s\n' "$*"; }
warn()  { printf '\033[38;5;215m  !\033[0m %s\n' "$*"; }
die()   { printf '\033[38;5;203m  ✗\033[0m %s\n' "$*" >&2; exit 1; }
have()  { command -v "$1" >/dev/null 2>&1; }

# ── 环境检查 ────────────────────────────────────────────────
[ "$(uname -s)" = "Linux" ] || die "目前只支持 Linux（macOS 请用 brew 装 ghostty 后手动 stow）"
have apt-get || die "目前只支持 Debian/Ubuntu 系（apt）"
[ "$(id -u)" -ne 0 ] || die "请用普通用户运行，需要时脚本会自己调 sudo"

SUDO=""
if [ "$(id -u)" -ne 0 ]; then have sudo || die "需要 sudo"; SUDO="sudo"; fi

. /etc/os-release
ARCH="$(dpkg --print-architecture)"
bold "Ghostty + tmux + zsh 环境安装"
info "系统 $PRETTY_NAME  架构 $ARCH"

# ── 1. 系统包 ───────────────────────────────────────────────
info "安装系统包"
PKGS=(zsh tmux git curl unzip fontconfig fzf eza bat zoxide ca-certificates)
MISSING=()
for p in "${PKGS[@]}"; do
  dpkg -s "$p" >/dev/null 2>&1 || MISSING+=("$p")
done
if [ ${#MISSING[@]} -gt 0 ]; then
  $SUDO apt-get update -qq
  # eza/zoxide 在旧版 Ubuntu 可能没有，逐个装，失败不中断
  for p in "${MISSING[@]}"; do
    $SUDO apt-get install -y -qq "$p" >/dev/null 2>&1 && ok "$p" || warn "$p 装不上（源里没有），跳过"
  done
else
  ok "系统包已齐"
fi

# ── 2. Ghostty ──────────────────────────────────────────────
if have ghostty; then
  ok "Ghostty 已安装（$(ghostty --version 2>/dev/null | head -1)）"
else
  info "安装 Ghostty（从 mkasberg/ghostty-ubuntu 的 .deb）"
  API="https://api.github.com/repos/mkasberg/ghostty-ubuntu/releases/latest"
  # 优先精确匹配本机发行版号，否则退回该架构下最新的一个
  URL="$(curl -fsSL "$API" \
        | grep -o "https://[^\"]*ghostty_[^\"]*_${ARCH}_${VERSION_ID}\.deb" | head -1 || true)"
  if [ -z "$URL" ]; then
    URL="$(curl -fsSL "$API" | grep -o "https://[^\"]*ghostty_[^\"]*_${ARCH}_[^\"]*\.deb" | head -1 || true)"
    [ -n "$URL" ] && warn "没有 $VERSION_ID 的构建，改用 $(basename "$URL")"
  fi
  if [ -n "$URL" ]; then
    TMP="$(mktemp -d)"; trap 'rm -rf "$TMP"' EXIT
    curl -fsSL -o "$TMP/ghostty.deb" "$URL"
    $SUDO apt-get install -y -qq "$TMP/ghostty.deb" >/dev/null 2>&1 \
      || { $SUDO dpkg -i "$TMP/ghostty.deb" >/dev/null 2>&1; $SUDO apt-get -f install -y -qq >/dev/null 2>&1; }
    have ghostty && ok "Ghostty $(ghostty --version 2>/dev/null | head -1)" || die "Ghostty 安装失败"
  else
    warn "找不到匹配的 .deb，跳过 Ghostty（其余配置照常安装）"
  fi
fi

# ── 3. 字体 ─────────────────────────────────────────────────
if fc-list 2>/dev/null | grep -qi "Maple Mono NF CN"; then
  ok "Maple Mono NF CN 已安装"
else
  info "安装 Maple Mono NF CN（含中文 + Nerd 图标，约 150MB）"
  TMPF="$(mktemp -d)"
  curl -fsSL -o "$TMPF/f.zip" \
    "https://github.com/subframe7536/maple-font/releases/download/${FONT_VER}/MapleMono-NF-CN.zip"
  unzip -oq "$TMPF/f.zip" -d "$TMPF/x"
  mkdir -p "$HOME/.local/share/fonts/MapleMonoCN"
  for w in Regular Bold Italic BoldItalic; do
    f="$(ls "$TMPF/x"/*-${w}.ttf 2>/dev/null | head -1)"
    [ -n "$f" ] && cp "$f" "$HOME/.local/share/fonts/MapleMonoCN/"
  done
  rm -rf "$TMPF"
  fc-cache -f "$HOME/.local/share/fonts" >/dev/null 2>&1
  ok "字体已安装"
fi

# ── 4. 拉仓库 ───────────────────────────────────────────────
if [ -d "$DOTFILES/.git" ]; then
  info "更新 dotfiles"; git -C "$DOTFILES" pull --ff-only -q || warn "pull 失败，用现有版本"
else
  info "克隆 dotfiles → $DOTFILES"; git clone -q --depth 1 "$REPO_URL" "$DOTFILES"
fi
ok "$DOTFILES"

# ── 5. zsh 插件 ─────────────────────────────────────────────
info "安装 zsh 插件"
ZP="$HOME/.config/zsh/plugins"; mkdir -p "$ZP"
clone_plugin() {
  local url=$1 name=$2
  if [ -d "$ZP/$name/.git" ]; then git -C "$ZP/$name" pull -q --ff-only 2>/dev/null || true
  else git clone -q --depth 1 "$url" "$ZP/$name"; fi
  ok "$name"
}
clone_plugin https://github.com/zsh-users/zsh-autosuggestions            zsh-autosuggestions
clone_plugin https://github.com/zdharma-continuum/fast-syntax-highlighting fast-syntax-highlighting
clone_plugin https://github.com/zsh-users/zsh-history-substring-search   zsh-history-substring-search
clone_plugin https://github.com/romkatv/powerlevel10k                    powerlevel10k

# ── 6. tmux 插件 ────────────────────────────────────────────
info "安装 tmux 插件"
TP="$HOME/.config/tmux/plugins"; mkdir -p "$TP"
[ -d "$TP/tpm/.git" ] || git clone -q --depth 1 https://github.com/tmux-plugins/tpm "$TP/tpm"
ok "tpm"

# ── 7. 软链配置 ─────────────────────────────────────────────
info "链接配置文件"
link() {
  local src=$1 dst=$2
  mkdir -p "$(dirname "$dst")"
  if [ -e "$dst" ] && [ ! -L "$dst" ]; then
    mv "$dst" "$dst.bak.$(date +%Y%m%d%H%M%S)"; warn "已备份原有 $(basename "$dst")"
  fi
  ln -sfn "$src" "$dst"; ok "$(echo "$dst" | sed "s|$HOME|~|")"
}
printf 'export ZDOTDIR="$HOME/.config/zsh"\n' > "$HOME/.zshenv"
link "$DOTFILES/config/zsh/zshrc"                 "$HOME/.config/zsh/.zshrc"
[ -f "$DOTFILES/config/zsh/p10k.zsh" ] && \
link "$DOTFILES/config/zsh/p10k.zsh"              "$HOME/.config/zsh/.p10k.zsh"
link "$DOTFILES/config/tmux/tmux.conf"            "$HOME/.config/tmux/tmux.conf"
link "$DOTFILES/config/ghostty/config.ghostty"    "$HOME/.config/ghostty/config.ghostty"
link "$DOTFILES/config/ghostty/themes"            "$HOME/.config/ghostty/themes"
link "$DOTFILES/config/ghostty/shaders"           "$HOME/.config/ghostty/shaders"
mkdir -p "$HOME/.local/bin/tmux"
link "$DOTFILES/bin/theme-preview"                "$HOME/.local/bin/theme-preview"
for f in "$DOTFILES"/bin/tmux/*.sh; do
  link "$f" "$HOME/.local/bin/tmux/$(basename "$f")"
done
chmod +x "$DOTFILES"/bin/theme-preview "$DOTFILES"/bin/tmux/*.sh 2>/dev/null || true

# ── 8. Claude Code hook（可选，仅在已装时合并）──────────────
if [ -d "$HOME/.claude" ]; then
  info "注册 Claude Code → tmux 状态染色 hook"
  python3 - "$HOME/.claude/settings.json" "$HOME/.local/bin/tmux/claude-state.sh" <<'PY' && ok "hooks 已合并" || warn "hooks 合并跳过"
import json,os,sys
p,cmd=sys.argv[1],sys.argv[2]
d=json.load(open(p)) if os.path.exists(p) else {}
h=d.setdefault("hooks",{})
entry=lambda m=None:{**({"matcher":m} if m else {}),
    "hooks":[{"type":"command","command":cmd,"async":True,"timeout":5}]}
for ev in ["SessionStart","UserPromptSubmit","Notification","Stop","SessionEnd"]:
    h.setdefault(ev,[entry()])
h.setdefault("PreToolUse",[entry("*")])
if os.path.exists(p): os.replace(p,p+".bak")
json.dump(d,open(p,"w"),indent=2,ensure_ascii=False)
PY
fi

# ── 9. 默认 shell ───────────────────────────────────────────
ZSH_BIN="$(command -v zsh)"
if [ "$(getent passwd "$USER" | cut -d: -f7)" != "$ZSH_BIN" ]; then
  info "把登录 shell 改成 zsh"
  grep -qxF "$ZSH_BIN" /etc/shells || echo "$ZSH_BIN" | $SUDO tee -a /etc/shells >/dev/null
  chsh -s "$ZSH_BIN" && ok "已改（下次登录生效）" || warn "chsh 失败，请手动: chsh -s $ZSH_BIN"
else
  ok "登录 shell 已是 zsh"
fi

echo
bold "装完了。"
echo "  1. 重启 Ghostty（字体和配置生效）"
echo "  2. 新终端里首次进 zsh 会弹 powerlevel10k 向导（已带配置则跳过）"
echo "  3. 敲 tmux 启动；按 Alt+m 打开菜单，Ctrl+b ? 看速查表"
