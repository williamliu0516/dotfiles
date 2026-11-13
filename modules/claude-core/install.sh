#!/usr/bin/env bash
# name: 全局指令 + 基础设置
# desc: 共用的 CLAUDE.md 和基础设置（不署名、主题）；本机专属的写 ~/.claude/CLAUDE.machine.md
# os:   linux macos
# group: Claude Code
set -euo pipefail
. "${DOTFILES_DIR:-$HOME/.dotfiles}/lib/common.sh"

C="$HOME/.claude"; mkdir -p "$C"

# CLAUDE.md：仓库里是各台机器共用的部分，结尾 @import 本机的 CLAUDE.machine.md。
# 原来的 CLAUDE.md 是普通文件、又还没有 CLAUDE.machine.md 时，整份挪过去，什么都不丢
if [ -f "$C/CLAUDE.md" ] && [ ! -L "$C/CLAUDE.md" ] && [ ! -e "$C/CLAUDE.machine.md" ]; then
  mv "$C/CLAUDE.md" "$C/CLAUDE.machine.md"
  warn "原来的 CLAUDE.md 挪成了 CLAUDE.machine.md；和共用部分重复的段落可以从里面删掉"
fi
[ -e "$C/CLAUDE.machine.md" ] || printf '## Machine\n\n- (notes about this machine: what it is for, what runs here)\n' >"$C/CLAUDE.machine.md"
link "$DOTFILES/config/claude/CLAUDE.md" "$C/CLAUDE.md"

# settings.json：仓库里的这几项覆盖本机的同名项，别的（hook、statusLine、env）不动
info "合并基础设置进 ~/.claude/settings.json"
R=$(python3 - "$C/settings.json" "$DOTFILES/config/claude/settings.base.json" <<'PY'
import json, os, shutil, sys
path, base = sys.argv[1], json.load(open(sys.argv[2]))
d = json.load(open(path)) if os.path.exists(path) else {}
if all(d.get(k) == v for k, v in base.items()):
    print("unchanged"); sys.exit(0)
if os.path.exists(path):
    shutil.copy(path, path + ".bak")
d.update(base)
json.dump(d, open(path, "w"), indent=2, ensure_ascii=False); open(path, "a").write("\n")
print("changed")
PY
)
if [ "$R" = unchanged ]; then ok "基础设置已经是最新的"
else ok "已合并，原文件备份为 settings.json.bak（新开的 Claude Code 会话生效）"; fi
