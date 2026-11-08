#!/usr/bin/env bash
# 安装用户级 launchd 任务；只检查选择变化，壁纸没变时不处理图像。
set -euo pipefail
DIR=$(cd "$(dirname "$0")" && pwd)
LABEL=com.williamliu.ghostty-wallpaper
PLIST="$HOME/Library/LaunchAgents/$LABEL.plist"
mkdir -p "$HOME/Library/LaunchAgents" "$HOME/Library/Logs"
/usr/bin/python3 - "$DIR/sync.py" "$LABEL" "$PLIST" "$HOME/Library/Logs/ghostty-wallpaper.log" <<'PY'
import plistlib, sys
script, label, target, log = sys.argv[1:]
with open(target, 'wb') as f:
    plistlib.dump({'Label': label,
                   'ProgramArguments': ['/usr/bin/python3', script],
                   'RunAtLoad': True, 'StartInterval': 60,
                   'StandardErrorPath': log}, f)
PY
launchctl bootout "gui/$(id -u)/$LABEL" 2>/dev/null || true
launchctl bootstrap "gui/$(id -u)" "$PLIST"
