#!/usr/bin/env bash
# name: Ghostty + tmux + zsh
# desc: 终端、字体、zsh 插件、tmux 配置，全部软链到 ~/.dotfiles
# os:   linux macos
set -euo pipefail
. "${DOTFILES_DIR:-$HOME/.dotfiles}/lib/common.sh"

FONT_VER="${MAPLE_FONT_VERSION:-v7.9}"

# ── 1. 系统包 ───────────────────────────────────────────────
info "安装系统包"
if [ "$OS" = macos ]; then
  # zsh 用系统自带的 /bin/zsh（已是默认 shell），不另装 brew 版
  # poppler 提供 pdftoppm，yazi 靠它渲染 PDF 预览
  pkg_install tmux fzf eza bat zoxide yazi lazygit poppler
else
  pkg_install zsh tmux git curl unzip fontconfig fzf eza bat zoxide ca-certificates poppler-utils
  # yazi 不在 Ubuntu 的源里，装官方发布的 .deb
  if have yazi; then
    ok "yazi 已安装"
  else
    info "安装 yazi（GitHub 发布的 .deb）"
    case "$(dpkg --print-architecture)" in amd64) YARCH=x86_64 ;; arm64) YARCH=aarch64 ;; *) YARCH="" ;; esac
    YURL="$( [ -n "$YARCH" ] && curl -fsSL https://api.github.com/repos/sxyazi/yazi/releases/latest \
            | grep -o "https://[^\"]*yazi-${YARCH}-unknown-linux-gnu\.deb" | head -1 || true)"
    if [ -n "$YURL" ]; then
      TMPY="$(mktemp -d)"
      curl -fsSL -o "$TMPY/yazi.deb" "$YURL" && $SUDO apt-get install -y -qq "$TMPY/yazi.deb" >/dev/null 2>&1 \
        && ok "yazi $(yazi --version 2>/dev/null | head -1 || true)" || warn "yazi 装不上，跳过"
      rm -rf "$TMPY"
    else
      warn "没有本架构的 yazi 包，跳过"
    fi
  fi
  # lazygit 也不在源里：官方 tar.gz 里就一个二进制，放 ~/.local/bin
  if have lazygit; then
    ok "lazygit 已安装"
  else
    info "安装 lazygit（GitHub 发布的 tar.gz）"
    case "$(dpkg --print-architecture)" in amd64) LARCH=x86_64 ;; arm64) LARCH=arm64 ;; *) LARCH="" ;; esac
    LURL="$( [ -n "$LARCH" ] && curl -fsSL https://api.github.com/repos/jesseduffield/lazygit/releases/latest \
            | grep -o "https://[^\"]*lazygit_[^\"]*_[Ll]inux_${LARCH}\.tar\.gz" | head -1 || true)"
    if [ -n "$LURL" ]; then
      TMPL="$(mktemp -d)"; mkdir -p "$HOME/.local/bin"
      curl -fsSL "$LURL" | tar -xzf - -C "$TMPL" lazygit 2>/dev/null \
        && install -m 755 "$TMPL/lazygit" "$HOME/.local/bin/lazygit" \
        && ok "lazygit $("$HOME/.local/bin/lazygit" --version 2>/dev/null | grep -o 'version=[^,]*' || true)" \
        || warn "lazygit 装不上，跳过"
      rm -rf "$TMPL"
    else
      warn "没有本架构的 lazygit 包，跳过"
    fi
  fi
fi

# ── 2. Ghostty ──────────────────────────────────────────────
if have ghostty || [ -d /Applications/Ghostty.app ]; then
  ok "Ghostty 已安装"
elif [ "$OS" = macos ]; then
  info "安装 Ghostty（brew cask）"
  brew install -q --cask ghostty >/dev/null && ok "Ghostty" || warn "Ghostty 安装失败，其余配置照常安装"
else
  info "安装 Ghostty（从 mkasberg/ghostty-ubuntu 的 .deb）"
  . /etc/os-release
  ARCH="$(dpkg --print-architecture)"
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
    have ghostty && ok "Ghostty $(ghostty --version 2>/dev/null | head -1 || true)" || die "Ghostty 安装失败"
  else
    warn "找不到匹配的 .deb，跳过 Ghostty（其余配置照常安装）"
  fi
fi

# ── 3. 字体 ─────────────────────────────────────────────────
if [ "$OS" = macos ]; then
  if brew list --cask font-maple-mono-nf-cn >/dev/null 2>&1; then
    ok "Maple Mono NF CN 已安装"
  else
    info "安装 Maple Mono NF CN（brew cask）"
    brew install -q --cask font-maple-mono-nf-cn >/dev/null && ok "字体已安装" || warn "字体安装失败，跳过"
  fi
elif fc-list 2>/dev/null | grep -i "Maple Mono NF CN" >/dev/null 2>&1; then
  ok "Maple Mono NF CN 已安装"
else
  info "安装 Maple Mono NF CN（含中文 + Nerd 图标，约 150MB）"
  TMPF="$(mktemp -d)"
  curl -fsSL -o "$TMPF/f.zip" \
    "https://github.com/subframe7536/maple-font/releases/download/${FONT_VER}/MapleMono-NF-CN.zip"
  unzip -oq "$TMPF/f.zip" -d "$TMPF/x"
  mkdir -p "$HOME/.local/share/fonts/MapleMonoCN"
  for w in Regular Bold Italic BoldItalic; do
    f="$(ls "$TMPF/x"/*-${w}.ttf 2>/dev/null | head -1 || true)"
    [ -n "$f" ] && cp "$f" "$HOME/.local/share/fonts/MapleMonoCN/"
  done
  rm -rf "$TMPF"
  fc-cache -f "$HOME/.local/share/fonts" >/dev/null 2>&1
  ok "字体已安装"
fi

# ── 4. zsh 插件 ─────────────────────────────────────────────
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

# ── 5. tmux 插件 ────────────────────────────────────────────
info "安装 tmux 插件"
TP="$HOME/.config/tmux/plugins"; mkdir -p "$TP"
# 直接克隆，不靠 tpm 的 install_plugins——它要从运行中的 tmux server 读插件路径，新机器上还没有 server
for p in tpm tmux-resurrect tmux-continuum; do
  [ -d "$TP/$p/.git" ] || git clone -q --depth 1 "https://github.com/tmux-plugins/$p" "$TP/$p"
  ok "$p"
done

# ── 6. 软链配置 ─────────────────────────────────────────────
info "链接配置文件"
ZSHENV_LINE='export ZDOTDIR="$HOME/.config/zsh"'
if [ -e "$HOME/.zshenv" ] && ! grep -qxF "$ZSHENV_LINE" "$HOME/.zshenv"; then
  cp "$HOME/.zshenv" "$HOME/.zshenv.bak.$(stamp)"; warn "已备份原有 .zshenv"
fi
grep -qxF "$ZSHENV_LINE" "$HOME/.zshenv" 2>/dev/null || echo "$ZSHENV_LINE" >> "$HOME/.zshenv"
link "$DOTFILES/config/zsh/zshrc"                 "$HOME/.config/zsh/.zshrc"
[ -f "$DOTFILES/config/zsh/p10k.zsh" ] && \
link "$DOTFILES/config/zsh/p10k.zsh"              "$HOME/.config/zsh/.p10k.zsh"
link "$DOTFILES/config/tmux/tmux.conf"            "$HOME/.config/tmux/tmux.conf"
link "$DOTFILES/config/ghostty/config.ghostty"    "$HOME/.config/ghostty/config.ghostty"
# 系统专属的 Ghostty 设置：主配置用 config-file 引入这个文件
link "$DOTFILES/config/ghostty/$OS.ghostty"       "$HOME/.config/ghostty/platform.ghostty"
link "$DOTFILES/config/ghostty/themes"            "$HOME/.config/ghostty/themes"
link "$DOTFILES/config/ghostty/shaders"           "$HOME/.config/ghostty/shaders"
mkdir -p "$HOME/.local/bin/tmux"
link "$DOTFILES/bin/theme-preview"                "$HOME/.local/bin/theme-preview"
for f in "$DOTFILES"/bin/tmux/*.sh; do
  link "$f" "$HOME/.local/bin/tmux/$(basename "$f")"
done
chmod +x "$DOTFILES"/bin/theme-preview "$DOTFILES"/bin/tmux/*.sh 2>/dev/null || true

# ── 7. Ghostty 毛玻璃（GNOME，仅在装了 Blur my Shell 时）──────
# GNOME 不支持 Ghostty 自己的 background-blur，只能让 Blur my Shell 模糊它背后。
# macOS 由 Ghostty 自己的 background-blur 处理（见 macos.ghostty），这里不用管。
BMS_SCHEMAS=""
for d in "$HOME/.local/share/gnome-shell/extensions/blur-my-shell@aunetx" \
         /usr/share/gnome-shell/extensions/blur-my-shell@aunetx; do
  [ -d "$d/schemas" ] && { BMS_SCHEMAS="$d/schemas"; break; }
done
if [ -n "$BMS_SCHEMAS" ] && have gsettings; then
  info "Blur my Shell：模糊 Ghostty 窗口背后"
  S=org.gnome.shell.extensions.blur-my-shell.applications
  { gsettings_append $S whitelist com.mitchellh.ghostty "$BMS_SCHEMAS" \
    && gsettings --schemadir "$BMS_SCHEMAS" set $S opacity 255 \
    && gsettings --schemadir "$BMS_SCHEMAS" set $S dynamic-opacity false \
    && gsettings --schemadir "$BMS_SCHEMAS" set $S blur true; } \
    && ok "已开启（只对 Ghostty）" || warn "Blur my Shell 设置失败，跳过"
fi

# ── 8. 默认 shell ───────────────────────────────────────────
if [ "$OS" = macos ]; then
  ZSH_BIN=/bin/zsh
  CUR_SHELL="$(dscl . -read "/Users/$USER" UserShell 2>/dev/null | awk '{print $2}')"
else
  ZSH_BIN="$(command -v zsh)"
  CUR_SHELL="$(getent passwd "$USER" | cut -d: -f7)"
fi
if [ "$CUR_SHELL" != "$ZSH_BIN" ]; then
  info "把登录 shell 改成 zsh"
  grep -qxF "$ZSH_BIN" /etc/shells || echo "$ZSH_BIN" | $SUDO tee -a /etc/shells >/dev/null
  # 云镜像 / 虚拟机的用户常常没有密码但 sudo 免密：先试免密 sudo，不行再走会问密码的 chsh
  if { [ -n "$SUDO" ] && $SUDO -n chsh -s "$ZSH_BIN" "$USER" 2>/dev/null; } || chsh -s "$ZSH_BIN"; then
    ok "已改（下次登录生效）"
  else
    warn "chsh 失败，请手动: chsh -s $ZSH_BIN"
  fi
else
  ok "登录 shell 已是 zsh"
fi

echo
echo "  · 重启 Ghostty（字体和配置生效）"
echo "  · 新终端里首次进 zsh 会弹 powerlevel10k 向导（已带配置则跳过）"
if [ "$OS" = macos ]; then
  echo "  · 敲 tmux 启动；按 Option+m 打开菜单（Option 就是 Alt），Ctrl+b ? 看速查表"
  echo "  · Ctrl+Enter / Cmd+Enter 全屏；Ctrl+←/→ 被 Mission Control 占用，shell 里按词移动用 Option+←/→"
else
  echo "  · 敲 tmux 启动；按 Alt+m 打开菜单，Ctrl+b ? 看速查表"
fi
