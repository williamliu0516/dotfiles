#!/usr/bin/env bash
# 抓当前屏幕上正在显示的桌面壁纸（WindowManager 的 Wallpaper 图层，动态壁纸也抓得到），
# 高斯模糊后存成 Ghostty 的背景图 backgrounds/wallpaper.png，由 macos.ghostty 引用。
# 用法: make.sh [sigma]   sigma 默认 30（原来 background-blur = 20 的观感）。换了壁纸重跑一次即可。
# 图是机器相关的（分辨率、壁纸都不同），不进 git；install.sh 在 macOS 上缺图时会自动跑。
set -euo pipefail
SIGMA=${1:-30}
OUT="$(cd "$(dirname "$0")" && pwd)/wallpaper.png"
TMP=$(mktemp -t ghostty-wp).png; trap 'rm -f "$TMP"' EXIT
command -v ffmpeg >/dev/null || { echo "需要 ffmpeg：brew install ffmpeg" >&2; exit 1; }
# 用 JXA 查壁纸窗口的 ID，不用编译任何东西
WID=$(osascript -l JavaScript <<'JS'
ObjC.import('CoreGraphics');
const ref = $.CGWindowListCopyWindowInfo($.kCGWindowListOptionOnScreenOnly, 0);
const arr = ObjC.deepUnwrap(ObjC.castRefToObject(ref));
const w = arr.find(w => w.kCGWindowOwnerName === 'WindowManager' && w.kCGWindowName === 'Wallpaper');
w ? String(w.kCGWindowNumber) : '';
JS
)
[ -n "$WID" ] || { echo "没找到壁纸窗口（WindowManager / Wallpaper）" >&2; exit 1; }
# -l 只抓这个窗口的图层，不含上面的任何窗口；需要给终端「屏幕录制」权限
screencapture -x -o -l "$WID" "$TMP"
ffmpeg -v error -y -i "$TMP" -vf "gblur=sigma=$SIGMA,format=rgb24" "$OUT"
echo "写入 ${OUT}（$(sips -g pixelWidth -g pixelHeight "$OUT" | awk '/pixel/{printf "%s ",$2}')sigma=$SIGMA）"
