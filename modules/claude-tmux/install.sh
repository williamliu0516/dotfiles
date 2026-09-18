#!/usr/bin/env bash
# name: Claude → tmux 窗口染色
# desc: tmux 窗口编号随 Claude Code 状态变色（运行 / 等你批准 / 完成 / 出错）
# os:   linux macos
# needs: terminal
set -euo pipefail
. "${DOTFILES_DIR:-$HOME/.dotfiles}/lib/common.sh"

HOOK="$HOME/.local/bin/tmux/claude-state.sh"
[ -x "$HOOK" ] || die "找不到 $HOOK，先装 Ghostty + tmux + zsh 模块"
have python3 || die "需要 python3"

info "注册 Claude Code hook（合并进 ~/.claude/settings.json）"
mkdir -p "$HOME/.claude"
R=$(python3 - "$HOME/.claude/settings.json" "$HOOK" <<'PY'
import json,os,sys
p,cmd=sys.argv[1],sys.argv[2]
d=json.load(open(p)) if os.path.exists(p) else {}
before=json.dumps(d,sort_keys=True)
h=d.setdefault("hooks",{})
entry=lambda m=None:{**({"matcher":m} if m else {}),
    "hooks":[{"type":"command","command":cmd,"async":True,"timeout":5}]}
for ev in ["SessionStart","UserPromptSubmit","Notification","Stop","SessionEnd"]:
    h.setdefault(ev,[entry()])
h.setdefault("PreToolUse",[entry("*")])
if json.dumps(d,sort_keys=True)==before: print("unchanged"); sys.exit(0)   # 已经注册过，不重写也不覆盖旧备份
if os.path.exists(p): os.replace(p,p+".bak")
json.dump(d,open(p,"w"),indent=2,ensure_ascii=False)
PY
)
if [ "$R" = unchanged ]; then ok "hooks 早已注册，没有改动"
else ok "hooks 已合并，原文件备份为 settings.json.bak（新开的 Claude Code 会话生效）"; fi
