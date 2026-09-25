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
  # fd + ripgrep 给 fzf 用：列文件比 find 快得多，且自动跳过 .gitignore 里的东西
  pkg_install tmux mosh fzf eza bat zoxide yazi lazygit poppler btop fd ripgrep
else
  # Linux 上 apt 只装"必须是系统级"的东西：zsh（要写进 /etc/shells 当登录 shell）、mosh（ssh 远程命令
  # 要能直接找到 mosh-server）、libnotify-bin（notify-send 走桌面的 D-Bus）、git/curl/fontconfig。
  # 其余 CLI 工具全部交给 Nix + Home Manager（nix/home.nix）：版本锁在 flake.lock，和 Ubuntu 版本无关，
  # 不用再为 22.04 的 fzf 太旧、eza 不在源里、yazi/lazygit 要抓 GitHub release 这些事写特判。
  pkg_install zsh mosh git curl unzip fontconfig ca-certificates libnotify-bin xz-utils

  # ── 1b. Nix ─────────────────────────────────────────────
  NIX_SH=/nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh
  if have nix; then
    ok "Nix 已安装（$(nix --version 2>/dev/null | head -1)）"
  elif [ -r "$NIX_SH" ]; then
    . "$NIX_SH"; ok "Nix 已安装（$(nix --version 2>/dev/null | head -1)）"
  else
    info "安装 Nix（Determinate 安装器；卸载：/nix/nix-installer uninstall）"
    # 没有 systemd 的环境（Docker、老的 WSL）装不了 nix-daemon 服务，用单用户模式
    NIX_INIT=""; [ -d /run/systemd/system ] || NIX_INIT="--init none"
    if curl --proto '=https' --tlsv1.2 -fsSL https://install.determinate.systems/nix \
         | sh -s -- install linux --no-confirm $NIX_INIT; then
      . "$NIX_SH"; ok "Nix $(nix --version 2>/dev/null | head -1)"
    else
      die "Nix 安装失败。可以手动装：curl -fsSL https://install.determinate.systems/nix | sh -s -- install，然后重跑本脚本"
    fi
  fi

  # 没有 systemd 的环境里没人拉起 nix-daemon，普通用户连不上 store（"opening lock file big-lock: Permission denied"）。
  # 这里手动起一个，只在本次开机内有效；重复启动会因 socket 被占而自己退出，无害。
  if [ ! -d /run/systemd/system ] && ! { have pgrep && pgrep -x nix-daemon >/dev/null 2>&1; }; then
    $SUDO sh -c 'nohup /nix/var/nix/profiles/default/bin/nix-daemon >/dev/null 2>&1 &'
    sleep 1
    warn "这台机器没有 systemd，nix-daemon 已手动启动；以后每次开机要自己跑一次：sudo nix-daemon &"
  fi

  # ── 1c. Home Manager：装 CLI 工具和字体 ────────────────────
  info "Home Manager：安装 CLI 工具链（首次会下载几百 MB，yazi 要从源码编译几分钟）"
  # -b bak：Home Manager 要接管的文件如果已存在（比如旧的 fontconfig），改名成 *.bak 而不是报错
  if nix run "path:$DOTFILES/nix#home-manager" -- switch --flake "path:$DOTFILES/nix#linux" --impure -b bak; then
    [ -r "$HOME/.nix-profile/etc/profile.d/hm-session-vars.sh" ] && . "$HOME/.nix-profile/etc/profile.d/hm-session-vars.sh"
    export PATH="$HOME/.nix-profile/bin:$PATH"
    ok "工具链：$(for t in tmux fzf eza bat zoxide yazi lazygit btop fd rg; do have $t && printf '%s ' "$t"; done)"
    # 只清没人引用的 store 路径（编译 yazi 用的 Rust 工具链等，约 2-3 GB）；已装的生成代不受影响
    nix store gc >/dev/null 2>&1 || true
  else
    warn "Home Manager 失败，CLI 工具没装上；其余配置照常安装。单独重试：home-manager switch --flake path:$DOTFILES/nix#linux --impure"
    HM_FAILED=1
  fi
fi

# ── 2. Ghostty ──────────────────────────────────────────────
if have ghostty || [ -d /Applications/Ghostty.app ]; then
  ok "Ghostty 已安装"
elif [ "$OS" = macos ]; then
  info "安装 Ghostty（brew cask）"
  brew install -q --cask ghostty >/dev/null && ok "Ghostty" || warn "Ghostty 安装失败，其余配置照常安装"
# Ubuntu 26.04 起 Ghostty 进了官方源。看 Candidate 而不是 apt-cache show：卸掉的第三方 .deb 会留下元数据，show 照样有输出
elif apt-cache policy ghostty 2>/dev/null | grep -q 'Candidate: [0-9]' \
     && { info "安装 Ghostty（apt）"; $SUDO apt-get install -y -qq ghostty >/dev/null 2>&1; }; then
  ok "Ghostty $(ghostty --version 2>/dev/null | head -1 || true)"
elif have snap; then
  # Ghostty 是 GUI 程序，不走 Nix：Nix 装的图形程序在非 NixOS 上找不到系统 OpenGL 驱动，要套 nixGL 才能启动。
  # snap 是 Ghostty 官方文档列出的 Ubuntu 安装方式，各版本通用，classic 模式不受沙箱限制，能读 ~/.config 和用户字体。
  info "安装 Ghostty（snap，classic）"
  $SUDO snap install ghostty --classic >/dev/null 2>&1 && ok "Ghostty $(ghostty --version 2>/dev/null | head -1 || true)" \
    || warn "Ghostty snap 安装失败，其余配置照常安装。手动：sudo snap install ghostty --classic"
else
  warn "没有 apt 源里的 ghostty 也没有 snap，跳过 Ghostty。其他装法见 https://ghostty.org/docs/install/binary"
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
  # 正常情况字体已由 Home Manager 装好（nix/home.nix 的 maple-mono.NF-CN）；走到这里说明 HM 没成功，退回手动下载
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
clone_plugin https://github.com/Aloxaf/fzf-tab                          fzf-tab

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
# 非交互 shell（ssh 远程命令、mosh-server）也要有 Homebrew 的 PATH 和 UTF-8 locale；
# zsh 不会自己读 $ZDOTDIR/.zshenv，所以让 ~/.zshenv 去 source 它
ZSHENV_SRC='[ -r "$ZDOTDIR/.zshenv" ] && . "$ZDOTDIR/.zshenv"'
grep -qxF "$ZSHENV_SRC" "$HOME/.zshenv" 2>/dev/null || echo "$ZSHENV_SRC" >> "$HOME/.zshenv"
link "$DOTFILES/config/zsh/zshenv"                "$HOME/.config/zsh/.zshenv"
link "$DOTFILES/config/zsh/zshrc"                 "$HOME/.config/zsh/.zshrc"
[ -f "$DOTFILES/config/zsh/p10k.zsh" ] && \
link "$DOTFILES/config/zsh/p10k.zsh"              "$HOME/.config/zsh/.p10k.zsh"
link "$DOTFILES/config/tmux/tmux.conf"            "$HOME/.config/tmux/tmux.conf"
link "$DOTFILES/config/ghostty/config.ghostty"    "$HOME/.config/ghostty/config.ghostty"
# 系统专属的 Ghostty 设置：主配置用 config-file 引入这个文件
link "$DOTFILES/config/ghostty/$OS.ghostty"       "$HOME/.config/ghostty/platform.ghostty"
link "$DOTFILES/config/ghostty/themes"            "$HOME/.config/ghostty/themes"
link "$DOTFILES/config/ghostty/shaders"           "$HOME/.config/ghostty/shaders"
link "$DOTFILES/config/yazi/yazi.toml"            "$HOME/.config/yazi/yazi.toml"
link "$DOTFILES/config/yazi/init.lua"             "$HOME/.config/yazi/init.lua"
link "$DOTFILES/config/yazi/plugins"              "$HOME/.config/yazi/plugins"
mkdir -p "$HOME/.local/bin/tmux"
link "$DOTFILES/bin/theme-preview"                "$HOME/.local/bin/theme-preview"
link "$DOTFILES/bin/notify"                       "$HOME/.local/bin/notify"
for f in "$DOTFILES"/bin/tmux/*.sh; do
  link "$f" "$HOME/.local/bin/tmux/$(basename "$f")"
done
chmod +x "$DOTFILES"/bin/theme-preview "$DOTFILES"/bin/notify "$DOTFILES"/bin/tmux/*.sh 2>/dev/null || true

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
[ -z "${HM_FAILED:-}" ]   # 工具链没装上就算模块失败，入口脚本会提示单独重跑
