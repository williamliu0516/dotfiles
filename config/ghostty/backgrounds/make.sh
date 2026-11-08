#!/usr/bin/env bash
# 手动从当前 macOS 壁纸生成 Ghostty 背景；参数是模糊半径，默认 30。
set -euo pipefail
exec /usr/bin/python3 "$(cd "$(dirname "$0")" && pwd)/sync.py" --force --sigma "${1:-30}"
