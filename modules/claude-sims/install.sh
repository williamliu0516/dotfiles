#!/usr/bin/env bash
# name: Claude → 模拟器上限
# desc: 几个 Claude Code 会话合起来最多开 3 台 iOS 模拟器；会话结束或闲置 45 分钟就自动关掉
# os:   macos
set -euo pipefail
. "${DOTFILES_DIR:-$HOME/.dotfiles}/lib/common.sh"

have xcrun || die "需要 Xcode（xcrun simctl）"
BIN="$HOME/.local/bin/claude-sims"
link "$DOTFILES/bin/claude-sims" "$BIN"

info "注册 Claude Code hook（合并进 ~/.claude/settings.json）"
# pre 要能拒绝命令，必须同步；退出时的 end 自己把关机甩给后台进程，也同步
R1=$(CLAUDE_HOOK_SYNC=1 claude_hook "$BIN pre" 60 'PreToolUse:Bash')
R2=$(claude_hook "$BIN post" 30 'PostToolUse:Bash')
R3=$(CLAUDE_HOOK_SYNC=1 claude_hook "$BIN end" 10 SessionEnd)
if [ "$R1$R2$R3" = unchangedunchangedunchanged ]; then ok "hooks 早已注册，没有改动"
else ok "hooks 已合并，原文件备份为 settings.json.bak（新开的 Claude Code 会话生效）"; fi

# 闲置的模拟器靠 launchd 每 10 分钟扫一遍：会话一直开着（tmux 里常驻）就等不到 SessionEnd
LABEL=com.williamliu.claude-sims
PLIST="$HOME/Library/LaunchAgents/$LABEL.plist"
mkdir -p "$HOME/.cache/claude-sims" "$(dirname "$PLIST")"
cat >"$PLIST" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>Label</key><string>$LABEL</string>
  <key>ProgramArguments</key><array><string>$BIN</string><string>reap</string></array>
  <key>StartInterval</key><integer>600</integer>
  <key>StandardErrorPath</key><string>$HOME/.cache/claude-sims/launchd.log</string>
</dict>
</plist>
PLIST
launchctl bootout "gui/$(id -u)/$LABEL" 2>/dev/null || true
launchctl bootstrap "gui/$(id -u)" "$PLIST"
ok "launchd $LABEL 每 10 分钟关一次闲置的模拟器（记录在 ~/.cache/claude-sims/log）"
info "claude-sims 列出开着的模拟器、谁开的、闲了多久"
