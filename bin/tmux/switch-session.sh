#!/usr/bin/env bash
# Alt+s：fzf 列出现有会话和常用项目目录，选中即切换；只是目录就按目录名新建会话再切过去。
# 在 tmux 的 display-popup 里运行。
set -u
command -v fzf >/dev/null 2>&1 || { echo "需要 fzf"; sleep 1; exit 1; }

# 项目根目录：~/.config/tmux/projects 每行一个（可用 ~），没有这个文件就用默认几个
roots=()
if [ -r "$HOME/.config/tmux/projects" ]; then
  while IFS= read -r line; do
    [ -n "$line" ] && [ "${line#\#}" = "$line" ] && roots+=("${line/#\~/$HOME}")
  done < "$HOME/.config/tmux/projects"
else
  roots=("$HOME/projects" "$HOME/code" "$HOME/src" "$HOME/dev" "$HOME/.dotfiles")
fi

# 每行 "类型<Tab>图标 名字"：类型 S=会话 D=目录，fzf 只显示 Tab 后面的部分
# 第一段：现有会话；第二段：项目目录（根目录本身 + 它的一级子目录）
{
  tmux list-sessions -F 'S	 #S' 2>/dev/null
  for r in "${roots[@]}"; do
    [ -d "$r" ] || continue
    printf 'D\t %s\n' "$r"
    for d in "$r"/*/; do [ -d "$d" ] && printf 'D\t %s\n' "${d%/}"; done
  done
} | awk '!seen[$0]++' | sed "s|$HOME|~|" \
  | fzf --reverse --no-sort --delimiter='\t' --with-nth=2 \
        --prompt='会话 / 项目 › ' --header='回车切换；目录会新建同名会话' \
  | { IFS= read -r pick || exit 0
      kind="${pick%%	*}"; name="${pick#*	}"; name="${name#* }"; name="${name/#\~/$HOME}"
      if [ "$kind" = S ]; then
        tmux switch-client -t "=$name"
      else
        # 会话名不能含 . 和 :；开头的点去掉（~/.dotfiles → dotfiles）
        s="$(basename "$name" | sed 's/^\.//' | tr '.:' '__')"
        tmux has-session -t "=$s" 2>/dev/null || tmux new-session -d -s "$s" -c "$name"
        tmux switch-client -t "=$s"
      fi; }
