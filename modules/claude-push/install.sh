#!/usr/bin/env bash
# name: Claude → 手机推送
# desc: Claude Code 一停下或等你批准，就用 ntfy 推到手机 / iPad
# os:   linux macos
set -euo pipefail
. "${DOTFILES_DIR:-$HOME/.dotfiles}/lib/common.sh"

have python3 || die "需要 python3"
BIN="$HOME/.local/bin/claude-push"
link "$DOTFILES/bin/claude-push" "$BIN"

# 主题名就是密码（ntfy.sh 上谁知道谁就能读），所以配置不进仓库；已有就不动，换机器时拷过去即可同用一个主题
CONF="$HOME/.config/claude-push/config.json"
if [ ! -s "$CONF" ]; then
  mkdir -p "$(dirname "$CONF")"
  topic="claude-$(python3 -c 'import secrets; print(secrets.token_hex(12))')"
  (umask 077; cat >"$CONF" <<JSON
{
  "server": "https://ntfy.sh",
  "topic": "$topic",
  "excerpt": true
}
JSON
)
  ok "新建 $(tilde "$CONF")"
fi

info "注册 Claude Code hook（合并进 ~/.claude/settings.json）"
R=$(claude_hook "$BIN" 15 Stop Notification)
if [ "$R" = unchanged ]; then ok "hooks 早已注册，没有改动"
else ok "hooks 已合并，原文件备份为 settings.json.bak（新开的 Claude Code 会话生效）"; fi

topic=$(python3 -c 'import json,sys; print(json.load(open(sys.argv[1]))["topic"])' "$CONF")
info "手机 / iPad 装 ntfy，订阅 ntfy.sh 上的主题：$topic"
info "订阅好以后运行 claude-push --test 试一条"
