#!/usr/bin/env bash
# tmux-resurrect 的 hook：重启后在原来的窗格里接回 Claude Code 对话
# resurrect 只重开 vi / less 这类程序，Claude 窗格恢复出来只是个 shell。
# claude-state.sh 把每个窗格的会话 ID 记在窗格选项 @claude-session 上：
#   save <存档>  存档时把在跑 Claude 的窗格和它的 ID 追加进这份存档（claude 行，resurrect 读档时不认，会跳过）
#   pre          恢复前给已有的窗格做记号，恢复后不碰它们
#   restore      恢复后在恢复出来的窗格里跑 claude --resume <ID>
set -euo pipefail

TAB=$'\t'

resurrect_dir() {
  local d
  d="$(tmux show -gqv @resurrect-dir)"
  if [[ -z "$d" ]]; then
    if [[ -d "$HOME/.tmux/resurrect" ]]; then d="$HOME/.tmux/resurrect"
    else d="${XDG_DATA_HOME:-$HOME/.local/share}/tmux/resurrect"; fi
  fi
  d="${d//\$HOME/$HOME}"
  printf '%s\n' "${d/#\~/$HOME}"
}

save() {
  local file="$1" lines
  # 存档 pane 行（tab 分隔）：pane 会话 窗口 窗口激活 :标记 窗格 标题 :目录 激活 命令 :完整命令
  # 只收完整命令里有 claude 的窗格：Claude 被直接杀掉时不跑 SessionEnd，窗格上会留着旧 ID
  lines="$(tmux list-panes -a -F "#{session_name}${TAB}#{window_index}${TAB}#{pane_index}${TAB}#{@claude-session}" |
    awk -F'\t' -v OFS='\t' '
      NR == FNR { if ($1 == "pane" && $11 ~ /claude/) run[$2 FS $3 FS $6] = 1; next }
      $4 != "" && ($1 FS $2 FS $3) in run { print "claude", $1, $2, $3, $4 }' "$file" -)"
  [[ -z "$lines" ]] || printf '%s\n' "$lines" >> "$file"
}

pre() {
  local p
  for p in $(tmux list-panes -a -F '#{pane_id}'); do
    tmux set-option -p -t "$p" @claude-resume-skip 1
  done
}

shell_ready() {
  case "$(tmux display -p -t "$1" '#{pane_current_command}' 2>/dev/null)" in
    zsh|bash|fish|sh|-zsh|-bash) return 0 ;;
    *) return 1 ;;
  esac
}

restore() {
  local dir last kind sess win idx sid pane p todo="" seen=" "
  dir="$(resurrect_dir)"
  last="$dir/last"
  [[ -f "$last" ]] || return 0

  while IFS="$TAB" read -r kind sess win idx sid; do
    [[ "$kind" == claude && -n "$sid" ]] || continue
    pane="$(tmux display -p -t "$sess:$win.$idx" '#{pane_id}' 2>/dev/null)" || continue
    [[ "$(tmux show -pqv -t "$pane" @claude-resume-skip)" != 1 ]] || continue
    # 同一个会话只接回一次，两个窗格同时跑一个会话会互相写坏记录
    [[ "$seen" != *" $sid "* ]] || continue
    seen+="$sid "
    todo+="$pane $sid"$'\n'
  done < "$last"

  for p in $(tmux list-panes -a -F '#{pane_id}'); do
    tmux set-option -p -u -t "$p" @claude-resume-skip
  done
  [[ -n "$todo" ]] || return 0

  # 后台等 shell 起来再打字（resurrect 先 cat 旧屏幕内容再 exec shell），不拖住 resurrect
  (
    deadline=$((SECONDS + 20))
    while read -r pane sid; do
      [[ -n "$pane" ]] || continue
      until shell_ready "$pane"; do
        if (( SECONDS >= deadline )); then
          echo "$(date '+%F %T') skip $pane $sid: shell not ready" >> "$dir/claude-resume.log"
          continue 2
        fi
        sleep 0.2
      done
      tmux send-keys -t "$pane" -l "claude --resume $sid" \; send-keys -t "$pane" Enter
      echo "$(date '+%F %T') resume $pane $sid" >> "$dir/claude-resume.log"
    done <<< "$todo"
  ) >/dev/null 2>&1 &
}

case "${1:-}" in
  save) save "$2" ;;
  pre) pre ;;
  restore) restore ;;
  *) echo "用法：$0 save <存档> | pre | restore" >&2; exit 2 ;;
esac
