#!/usr/bin/env bash
# name: Claude → 对话里看图
# desc: Claude 读到、截到的图直接画在对话里（Ghostty / kitty，tmux 里也行），和手机 App 一样
# os:   linux macos
# needs: terminal
set -euo pipefail
. "${DOTFILES_DIR:-$HOME/.dotfiles}/lib/common.sh"

have python3 || die "需要 python3"
[ "$(uname)" = Darwin ] || have magick || have convert || warn "没有 ImageMagick：只有 PNG 能显示，JPEG / WebP 等转不了"
link "$DOTFILES/bin/claude-img" "$HOME/.local/bin/claude-img"
link "$DOTFILES/bin/tmux-kgp" "$HOME/.local/bin/tmux-kgp"
python3 "$DOTFILES/bin/tmux-kgp" --launcher

# 插件从仓库里直接加载（CLAUDE_CODE_PLUGIN_DIRS），改了文件下次开会话就生效，不用重装
PLUGIN="$DOTFILES/config/claude/inline-images"
info "在 ~/.claude/settings.json 的 env 里登记插件目录"
R=$(python3 - "$HOME/.claude/settings.json" "$PLUGIN" <<'PY'
import json, os, shutil, sys
path, plugin = sys.argv[1], sys.argv[2]
d = json.load(open(path)) if os.path.exists(path) else {}
env = d.setdefault("env", {})
dirs = [x for x in env.get("CLAUDE_CODE_PLUGIN_DIRS", "").split(":") if x]
changed = False
if plugin not in dirs:
    env["CLAUDE_CODE_PLUGIN_DIRS"] = ":".join(dirs + [plugin])
    changed = True
# 早先试过的侧边窗格版本留下的 PostToolUse hook，现在用不上了
for g in d.get("hooks", {}).get("PostToolUse", []):
    keep = [h for h in g.get("hooks", []) if not h.get("command", "").endswith("claude-img hook")]
    if len(keep) != len(g.get("hooks", [])):
        g["hooks"], changed = keep, True
if "hooks" in d and "PostToolUse" in d["hooks"]:
    d["hooks"]["PostToolUse"] = [g for g in d["hooks"]["PostToolUse"] if g.get("hooks")]
if not changed:
    print("unchanged"); sys.exit(0)
if os.path.exists(path):
    shutil.copy2(path, path + ".bak")
with open(path + ".tmp", "w") as f:
    json.dump(d, f, indent=2, ensure_ascii=False); f.write("\n")
os.replace(path + ".tmp", path)
print("changed")
PY
)
if [ "$R" = unchanged ]; then ok "早已登记，没有改动"
else ok "已登记，原文件备份为 settings.json.bak"; fi
info "新开的 shell 里 claude 自动经 tmux-kgp 启动；已经开着的 Claude 会话要退出重开（claude --resume 接回）才有图"
