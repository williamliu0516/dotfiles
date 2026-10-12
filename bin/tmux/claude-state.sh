#!/usr/bin/env bash
# Claude Code 生命周期 hook → tmux 窗口号染色
# 事件从 stdin 以 JSON 传入；TMUX_PANE 指向发起的那个窗格。
set -euo pipefail

[[ -n "${TMUX_PANE:-}" ]] || exit 0
command -v tmux >/dev/null 2>&1 || exit 0

payload=""
[[ -t 0 ]] || payload="$(cat || true)"

field() {
  printf '%s' "$payload" | sed -n 's/.*"'"$1"'"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' | head -n1
}

event="$(field hook_event_name)"
[[ -n "$event" ]] || exit 0

case "$event" in
  SessionStart|SessionEnd) state=idle ;;
  UserPromptSubmit|PreToolUse) state=running ;;
  Notification)
    case "$(field notification_type)" in
      permission_prompt|elicitation_dialog|elicitation_url_dialog|agent_needs_input) state=waiting ;;
      *) exit 0 ;;
    esac
    ;;
  Stop) state=done ;;
  StopFailure) state=error ;;
  *) exit 0 ;;
esac

tmux set-option -w -t "$TMUX_PANE" @agent-state "$state" 2>/dev/null || true

# 窗格记下跑的是哪个会话，tmux 存档时一起存，重启后 claude-resume.sh 用它接回原对话。
# 每个事件都记：/clear、/resume 换了会话也跟得上，这个 hook 生效前就开着的会话下个事件也会记上
sid="$(field session_id)"
if [[ "$event" == SessionEnd ]]; then
  tmux set-option -p -u -t "$TMUX_PANE" @claude-session 2>/dev/null || true
elif [[ -n "$sid" ]]; then
  tmux set-option -p -t "$TMUX_PANE" @claude-session "$sid" 2>/dev/null || true
fi

# 等你批准 / 跑完 / 出错时弹桌面通知，但只在你没在看这个窗口时（窗口不是当前窗口，或 Ghostty 不在前台）
case "$state" in
  waiting) title="Claude Code 在等你" ;;
  done)    title="Claude Code 完成了" ;;
  error)   title="Claude Code 出错了" ;;
  *)       title="" ;;
esac
if [[ -n "$title" ]] && [[ -x "$HOME/.local/bin/notify" ]]; then
  where="$(tmux display -p -t "$TMUX_PANE" '#{session_name} · #{window_index}:#{window_name}' 2>/dev/null || true)"
  "$HOME/.local/bin/notify" --if-away "$title" "$where" &
fi
