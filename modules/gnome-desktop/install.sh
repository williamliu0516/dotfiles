#!/usr/bin/env bash
# name: Ubuntu 桌面美化
# desc: Orchis 主题、Tela 图标、浅色顶栏和 Dock、顶栏智能隐藏、Super+Enter 下拉终端
# os:   gnome
set -euo pipefail
. "${DOTFILES_DIR:-$HOME/.dotfiles}/lib/common.sh"

# 全部装在家目录，不碰 /usr。改设置前先整份备份 dconf，还原：dconf load / < 备份文件
THEME=Orchis-Dark-Compact
ICONS=Tela-circle-dark
EXT_DIR="$HOME/.local/share/gnome-shell/extensions"
SHELL_VER="$(gnome-shell --version | grep -oE '[0-9]+' | head -1)"

BACKUP="$HOME/desktop-backup-$(stamp).dconf"
dconf dump / > "$BACKUP"
ok "当前桌面设置已备份到 ${BACKUP/#$HOME/~}"

info "安装依赖"
pkg_install git curl unzip python3

TMP="$(mktemp -d)"; trap 'rm -rf "$TMP"' EXIT

# ── 1. 主题和图标 ───────────────────────────────────────────
if [ -d "$HOME/.themes/$THEME" ]; then
  ok "$THEME 已安装"
else
  info "安装 Orchis 主题（深色、紧凑）"
  git clone -q --depth 1 https://github.com/vinceliuice/Orchis-theme "$TMP/orchis"
  # -l：把 gtk-4.0 软链到 ~/.config/gtk-4.0，让 libadwaita 应用也用上 Orchis
  "$TMP/orchis/install.sh" -c dark -s compact -l >/dev/null
  ok "$THEME"
fi
if [ -d "$HOME/.local/share/icons/$ICONS" ]; then
  ok "$ICONS 已安装"
else
  info "安装 Tela circle 图标"
  git clone -q --depth 1 https://github.com/vinceliuice/Tela-circle-icon-theme "$TMP/tela"
  "$TMP/tela/install.sh" >/dev/null
  ok "$ICONS"
fi

# ── 2. 扩展（从 extensions.gnome.org 下载匹配本机 GNOME 版本的包）──
install_ext() {
  local uuid=$1 url
  if [ -d "$EXT_DIR/$uuid" ]; then ok "$uuid 已安装"; return 0; fi
  url=$(curl -fsSL "https://extensions.gnome.org/extension-info/?uuid=$uuid&shell_version=$SHELL_VER" \
        | python3 -c 'import sys,json; print(json.load(sys.stdin)["download_url"])' 2>/dev/null || true)
  if [ -z "$url" ]; then warn "$uuid 没有 GNOME $SHELL_VER 的版本，跳过"; return 0; fi
  curl -fsSL "https://extensions.gnome.org$url" -o "$TMP/ext.zip"
  gnome-extensions install --force "$TMP/ext.zip" && ok "$uuid"
}
info "安装 GNOME 扩展"
EXTS="user-theme@gnome-shell-extensions.gcampax.github.com
blur-my-shell@aunetx
dash-to-dock@micxgx.gmail.com
hidetopbar@mathieu.bidon.ca
quake-terminal@diegodario88.github.io"
for e in $EXTS; do install_ext "$e"; done

# Ubuntu 自带的 Dock（ubuntu-dock）在 /usr 里带了自己的样式，会盖住 Orchis。
# 换成家目录里的上游 Dash to Dock，并去掉它自带的样式表，让 Orchis 的样式生效。
# Ubuntu 会话会强制启用 ubuntu-dock，只能靠 disabled-extensions 关掉。
DTD="$EXT_DIR/dash-to-dock@micxgx.gmail.com"
[ -f "$DTD/stylesheet.css" ] && mv "$DTD/stylesheet.css" "$DTD/stylesheet.css.bak"
gsettings_append org.gnome.shell disabled-extensions ubuntu-dock@ubuntu.com
# 新装的扩展要重新登录才会被 GNOME 发现，gnome-extensions enable 现在会失败，
# 所以直接写进启用列表
for e in $EXTS; do gsettings_append org.gnome.shell enabled-extensions "$e"; done
ok "扩展已启用（重新登录后生效）"

# ── 3. 扩展设置和外观 ───────────────────────────────────────
info "应用扩展设置和外观"
dconf load /org/gnome/shell/extensions/ < "$DOTFILES/config/gnome/extensions.dconf"
gsettings set org.gnome.desktop.interface gtk-theme "$THEME"
gsettings set org.gnome.desktop.interface icon-theme "$ICONS"
gsettings set org.gnome.desktop.interface color-scheme prefer-dark
ok "主题、图标、扩展设置"

# ── 4. 顶栏和 Dock 调浅 ─────────────────────────────────────
# Orchis 深色版的顶栏是半透明纯黑、Dock 是深灰：顶栏改成全透明，Dock 换成浅一点的中灰。
# 按选择器改而不是按行号改，主题更新后行号变了也能改对；重装主题会覆盖，重跑本模块即可。
CSS="$HOME/.themes/$THEME/gnome-shell/gnome-shell.css"
[ -f "$CSS.orig" ] || cp "$CSS" "$CSS.orig"
python3 - "$CSS" <<'PY' && ok "顶栏已透明、Dock 已调浅（原文件：gnome-shell.css.orig）" || warn "没找到要改的样式，主题结构可能变了，跳过"
import re, sys
path = sys.argv[1]
css = open(path).read()
rules = [  # (选择器, 属性, 颜色)
    ("#panel", "background-color", "transparent"),
    ("#panel .panel-corner", "-panel-corner-background-color", "transparent"),
    ("#dashtodockContainer #dash .dash-background", "background-color", "rgba(62, 62, 68, 0.6)"),
]
for sel, prop, color in rules:
    block = re.compile(r"(^" + re.escape(sel) + r" \{[^}]*?" + re.escape(prop) + r": )[^;]+;", re.M)
    css, n = block.subn(lambda m: m.group(1) + color + ";", css, count=1)
    if n == 0:
        sys.exit(f"missing {sel} {{ {prop} }}")
open(path, "w").write(css)
PY
# 让 GNOME 重新读主题（切走再切回）
# user-theme 的 schema 在扩展目录里，gsettings 找不到，用 dconf 直接写
dconf write /org/gnome/shell/extensions/user-theme/name "''"
sleep 1
dconf write /org/gnome/shell/extensions/user-theme/name "'$THEME'"

echo
echo "  · 注销后重新登录，新装的扩展才会加载"
echo "  · Super+Enter 拉出/收起下拉终端；窗口挡住顶栏时顶栏自动隐藏，鼠标碰顶边滑出"
echo "  · 不满意可以整体还原：dconf load / < ${BACKUP/#$HOME/~}"
