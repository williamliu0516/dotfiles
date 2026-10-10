# 所有模块共用的函数。由 install.sh 和各模块 source，不单独执行。
# 必须兼容 macOS 自带的 bash 3.2：不用关联数组、mapfile、${var,,}。

DOTFILES="${DOTFILES_DIR:-$HOME/.dotfiles}"

bold()  { printf '\033[1m%s\033[0m\n' "$*"; }
info()  { printf '\033[38;5;111m▎\033[0m %s\n' "$*"; }
ok()    { printf '\033[38;5;77m  ✓\033[0m %s\n' "$*"; }
warn()  { printf '\033[38;5;215m  !\033[0m %s\n' "$*"; }
die()   { printf '\033[38;5;203m  ✗\033[0m %s\n' "$*" >&2; exit 1; }
have()  { command -v "$1" >/dev/null 2>&1; }

case "$(uname -s)" in
  Linux)  OS=linux ;;
  Darwin) OS=macos ;;
  *)      OS=unknown ;;
esac

# GNOME 桌面单独算一个"平台"，Ubuntu 美化模块只在这里出现
is_gnome() { [ "$OS" = linux ] && case "${XDG_CURRENT_DESKTOP:-}" in *GNOME*) true ;; *) false ;; esac; }

SUDO=""
if [ "$(id -u)" -ne 0 ] && have sudo; then SUDO="sudo"; fi

# 能不能和用户交互：curl | bash 时 stdin 是管道，只能从 /dev/tty 读
has_tty() { [ -r /dev/tty ] && [ -w /dev/tty ] && { : </dev/tty; } 2>/dev/null; }

confirm() {  # confirm "问题"  →  y 返回 0；没有终端时按"否"处理
  has_tty || return 1
  local ans
  printf '\033[38;5;215m  ?\033[0m %s [y/N] ' "$1" >/dev/tty
  read -r ans </dev/tty || return 1
  case "$ans" in y|Y|yes|YES) return 0 ;; *) return 1 ;; esac
}

stamp() { date +%Y%m%d%H%M%S; }
tilde() { echo "$1" | sed "s|^$HOME|~|"; }

# 慢步骤（brew、下载、git clone）的完整输出都追加到这里，屏幕上每一项只留一行结果
DOTFILES_LOG="${DOTFILES_LOG:-$HOME/.cache/dotfiles-install.log}"
export DOTFILES_LOG
mkdir -p "$(dirname "$DOTFILES_LOG")"

# run_step "说明" 命令…：跑一个可能很慢的步骤。命令输出进日志，屏幕上显示正在做什么，做完由调用方打 ✓ / !。
# Ctrl-C 只跳过这一步（返回 130）；两秒内连按两次退出整个安装。
# 不这样的话，^C 打断 brew 会被当成"装不上"，打断 git clone 则直接杀掉整个模块，后面的配置都没链上。
STEP_INT="" LAST_INT=0
on_step_int() {
  local now; now=$(date +%s)
  if [ $((now - LAST_INT)) -le 2 ]; then
    if [ -t 1 ]; then printf '\r\033[K'; fi
    warn "已中止安装"
    # 让自己死于 SIGINT，调用本模块的 install.sh 才知道是用户中止、跟着退出，而不是接着装下一个模块
    trap - INT; kill -INT $$
  fi
  LAST_INT=$now STEP_INT=1
}
run_step() {
  local label=$1 rc=0; shift
  STEP_INT=""
  if [ -t 1 ]; then printf '\033[2m  … %s  (Ctrl-C 跳过)\033[0m' "$label"; else echo "  … $label"; fi
  printf '\n== %s %s\n$ %s\n' "$(date '+%F %T')" "$label" "$*" >>"$DOTFILES_LOG"
  trap on_step_int INT
  # stdin 接 /dev/null：curl | bash 时 stdin 是脚本本身，不能让子进程读走
  "$@" >>"$DOTFILES_LOG" 2>&1 </dev/null || rc=$?
  trap - INT
  if [ -t 1 ]; then printf '\r\033[K'; fi
  if [ -n "$STEP_INT" ]; then return 130; fi
  return $rc
}

step_failed() {  # step_failed 返回码 名字 [以后手动装的命令]：报告 run_step 没成功的一步
  local later="${3:+；以后要装：$3}"
  if [ "$1" = 130 ]; then warn "$2 已跳过（Ctrl-C）$later"
  else warn "$2 没装上（详情见 $(tilde "$DOTFILES_LOG")）$later"; fi
}

# gh_install 仓库 tag 资产名结尾 可执行文件…：下 GitHub release 里的预编译二进制装进 ~/.local/bin，有 sha256 就校验。
# tag 写 latest 表示最新正式版。资产名里的 @T@ 换成本机的 Rust 目标（x86_64-apple-darwin、aarch64-unknown-linux-musl…），
# @G@ 换成 Go 风格的 darwin_amd64 这类。Linux 用 musl 静态版，和发行版无关。
gh_install() {
  local repo=$1 tag=$2 suffix=$3 bins t g api tmp url sum b f rc=1
  shift 3; bins="$*"
  case "$OS-$(uname -m)" in
    macos-arm64)                t=aarch64-apple-darwin       g=darwin_arm64 ;;
    macos-*)                    t=x86_64-apple-darwin        g=darwin_amd64 ;;
    linux-aarch64|linux-arm64)  t=aarch64-unknown-linux-musl g=linux_arm64 ;;
    *)                          t=x86_64-unknown-linux-musl  g=linux_amd64 ;;
  esac
  suffix=$(printf '%s' "$suffix" | sed "s/@T@/$t/; s/@G@/$g/")
  if [ "$tag" = latest ]; then api=releases/latest; else api=releases/tags/$tag; fi
  tmp=$(mktemp -d) || return 1
  url=$(curl -fsSL "https://api.github.com/repos/$repo/$api" | python3 -c '
import json, sys
for a in json.load(sys.stdin)["assets"]:
    if a["name"].endswith(sys.argv[1]):
        print(a["browser_download_url"], (a.get("digest") or "").replace("sha256:", "")); break
' "$suffix") || true
  sum=${url#* } url=${url%% *}
  if [ -z "$url" ]; then
    echo "$repo 的 $tag 里没有 *$suffix"
  elif curl -fsSL -o "$tmp/pkg" "$url" \
    && { [ -z "$sum" ] || echo "$sum  $tmp/pkg" | if have sha256sum; then sha256sum -c -; else shasum -a 256 -c -; fi; } \
    && mkdir "$tmp/x" \
    && case "$url" in *.zip) unzip -q "$tmp/pkg" -d "$tmp/x" ;; *) tar -xzf "$tmp/pkg" -C "$tmp/x" ;; esac \
    && mkdir -p "$HOME/.local/bin"; then
    rc=0
    for b in $bins; do
      f=$(find "$tmp/x" -type f -name "$b" | head -1)
      if [ -z "$f" ] || ! install -m 755 "$f" "$HOME/.local/bin/$b"; then echo "压缩包里找不到 $b"; rc=1; break; fi
    done
  fi
  rm -rf "$tmp"
  return $rc
}

# 软链配置；目标已存在且不是软链时先备份
link() {
  local src=$1 dst=$2
  mkdir -p "$(dirname "$dst")"
  if [ -e "$dst" ] && [ ! -L "$dst" ]; then
    mv "$dst" "$dst.bak.$(stamp)"; warn "已备份原有 $(basename "$dst")"
  fi
  ln -sfn "$src" "$dst"; ok "$(echo "$dst" | sed "s|$HOME|~|")"
}

# Homebrew 在本机没有现成的包（bottle）、得从源码编译时，这几个改下 GitHub 上的官方预编译版，装进 ~/.local/bin
# （PATH 里排在 brew 前面）。Intel Mac 上很多包已经没有 bottle，fd、bat 这类 Rust 工具一编译就得先编译 LLVM 和 Rust，
# 一个多小时。格式：包名  仓库  资产名结尾（见 gh_install）  可执行文件…
PREBUILT='
fd       sharkdp/fd           -@T@.tar.gz   fd
ripgrep  BurntSushi/ripgrep   -@T@.tar.gz   rg
bat      sharkdp/bat          -@T@.tar.gz   bat
zoxide   ajeetdsouza/zoxide   -@T@.tar.gz   zoxide
fzf      junegunn/fzf         -@G@.tar.gz   fzf
'
prebuilt() { echo "$PREBUILT" | awk -v p="$1" '$1 == p { $1 = ""; print substr($0, 2) }'; }  # → 仓库 资产名结尾 可执行文件…
prebuilt_install() { local e; e=$(prebuilt "$1"); set -- $e; local repo=$1; shift; gh_install "$repo" latest "$@"; }
prebuilt_present() {  # 之前已经用预编译版装过
  local e b; e=$(prebuilt "$1"); [ -n "$e" ] || return 1
  for b in $(echo "$e" | cut -d' ' -f3-); do [ -x "$HOME/.local/bin/$b" ] || return 1; done
}

# 从源码编译这些要半小时到几小时；要编译的包里有它们，或者一共超过 5 个，就先问一声
HEAVY_BUILDS="llvm rust gcc ghc qtbase openjdk node"
heavy() {
  local b
  [ $# -gt 5 ] && return 0
  for b in "$@"; do case " $HEAVY_BUILDS " in *" ${b%%@*} "*) return 0 ;; esac; done
  return 1
}
short_list() { if [ $# -le 6 ]; then echo "$*"; else echo "$1 $2 $3 $4 $5 $6 等 $# 个"; fi; }

# brew_plan 包…：每个包输出一行「包名<TAB>要从源码编译的包，空格分隔」，不用编译就留空。
# brew info 只列本机能用的 bottle：为空就要编译它，连同它的编译依赖；有 bottle 的只看运行依赖。
brew_plan() {
  python3 - "$@" <<'PY'
import json, subprocess, sys
cache = {}
def load(names):
    names = [n for n in names if n not in cache]
    if not names: return
    p = subprocess.run(["brew", "info", "--json=v2", "--formula"] + names, capture_output=True, text=True)
    if p.returncode != 0:  # 有一个名字不对就整批报错，拆开逐个查
        if len(names) > 1:
            for n in names: load([n])
        return
    for req, f in zip(names, json.loads(p.stdout)["formulae"]):
        cache[req] = cache[f["name"]] = f
load(sys.argv[1:])
for root in sys.argv[1:]:
    todo, seen, build = [root], set(), []
    while todo:
        load(todo)
        nxt = []
        for n in todo:
            f = cache.get(n)
            if not f or f["name"] in seen: continue
            seen.add(f["name"])
            if f["installed"]: continue
            deps = list(f["dependencies"])
            if not f["bottle"].get("stable", {}).get("files"):
                build.append(f["name"]); deps += f["build_dependencies"]
            nxt += deps
        todo = [d for d in nxt if d not in seen]
    print(root + "\t" + " ".join(build))
PY
}

# 装 brew 包。先一次查清哪些要从源码编译：能下预编译版的直接下，编译量小的直接编，
# 量大的先问——问题都在开头问完，之后不用守着
brew_install() {
  local p how build plan rc todo="" later=""
  if [ -t 1 ]; then printf '\033[2m  … 查哪些包有现成的 bottle\033[0m'; fi
  plan=$(brew_plan "$@" 2>>"$DOTFILES_LOG") || plan=""
  if [ -t 1 ]; then printf '\r\033[K'; fi
  for p in "$@"; do
    build=$(printf '%s\n' "$plan" | awk -F'\t' -v p="$p" '$1 == p { print $2 }')
    if [ -z "$build" ]; then how=bottle
    elif [ -n "$(prebuilt "$p")" ]; then how=prebuilt
    elif ! heavy $build; then how=source
    elif [ "${DOTFILES_SOURCE_BUILD:-}" = 1 ] \
      || confirm "$p 没有现成的包，要从源码编译（$(short_list $build)），可能要几十分钟到几小时。现在编译？"; then how=source
    else how=skip; later="$later $p"
    fi
    todo="$todo $p:$how"
  done
  for p in $todo; do
    how=${p#*:} p=${p%%:*} rc=0
    case $how in
      bottle)   run_step "brew install $p" brew install -q "$p" || rc=$? ;;
      prebuilt) run_step "${p}：Homebrew 没有现成的包，下载官方预编译版" prebuilt_install "$p" || rc=$? ;;
      source)   build=$(printf '%s\n' "$plan" | awk -F'\t' -v p="$p" '$1 == p { print $2 }')
                run_step "${p}：从源码编译（$(short_list $build)）" brew install -q "$p" || rc=$? ;;
      skip)     continue ;;
    esac
    if [ $rc = 0 ]; then
      if [ $how = prebuilt ]; then ok "${p}（官方预编译版，在 ~/.local/bin）"; else ok "$p"; fi
    else step_failed $rc "$p" "brew install $p"; fi
  done
  if [ -n "$later" ]; then
    warn "没装：${later# }（要从源码编译，很久）。以后要装：brew install${later}，或 DOTFILES_SOURCE_BUILD=1 重跑本脚本"
  fi
}

# 装系统包：apt 或 brew。逐个装，单个失败不中断
pkg_install() {
  local p missing=""
  if [ "$OS" = macos ]; then
    for p in "$@"; do
      brew list --formula "$p" >/dev/null 2>&1 || prebuilt_present "$p" || missing="$missing $p"
    done
    [ -z "$missing" ] && { ok "系统包已齐"; return 0; }
    brew_install $missing
  else
    for p in "$@"; do dpkg -s "$p" >/dev/null 2>&1 || missing="$missing $p"; done
    [ -z "$missing" ] && { ok "系统包已齐"; return 0; }
    $SUDO apt-get update -qq
    for p in $missing; do
      $SUDO apt-get install -y -qq "$p" >/dev/null 2>&1 && ok "$p" || warn "$p 装不上（源里没有），跳过"
    done
  fi
}

# 往一个 gsettings 字符串数组里追加一项（已有则不动）
gsettings_append() {  # gsettings_append schema key value [schemadir]
  local schema=$1 key=$2 val=$3 dir=${4:-} cur new
  if [ -n "$dir" ]; then cur=$(gsettings --schemadir "$dir" get "$schema" "$key")
  else                   cur=$(gsettings get "$schema" "$key"); fi
  new=$(python3 -c "import ast,sys; l=ast.literal_eval(sys.argv[1].replace('@as ','')); v=sys.argv[2]; print(l if v in l else l+[v])" "$cur" "$val")
  if [ -n "$dir" ]; then gsettings --schemadir "$dir" set "$schema" "$key" "$new"
  else                   gsettings set "$schema" "$key" "$new"; fi
}

# 往 ~/.claude/settings.json 注册 Claude Code hook（async）：claude_hook 命令 超时秒数 事件...
# 事件写成 PreToolUse:* 就带 matcher。按命令去重：事件里已经有这条命令就跳过，
# 别人注册的 hook（键盘屏等）原样保留——不能用 setdefault，事件已被占用时会整个漏掉。
# 有改动时先备份成 settings.json.bak；输出 changed 或 unchanged
claude_hook() {
  local cmd=$1 timeout=$2; shift 2
  mkdir -p "$HOME/.claude"
  python3 - "$HOME/.claude/settings.json" "$cmd" "$timeout" "$@" <<'PY'
import json, os, shutil, sys
path, cmd, timeout, events = sys.argv[1], sys.argv[2], int(sys.argv[3]), sys.argv[4:]
d = json.load(open(path)) if os.path.exists(path) else {}
hooks, changed = d.setdefault("hooks", {}), False
for spec in events:
    event, _, matcher = spec.partition(":")
    groups = hooks.setdefault(event, [])
    if any(h.get("command") == cmd for g in groups for h in g.get("hooks", [])):
        continue
    entry = {"type": "command", "command": cmd, "async": True, "timeout": timeout}
    groups.append({**({"matcher": matcher} if matcher else {}), "hooks": [entry]})
    changed = True
if not changed:
    print("unchanged"); sys.exit(0)
if os.path.exists(path):
    shutil.copy2(path, path + ".bak")
with open(path + ".tmp", "w") as f:
    json.dump(d, f, indent=2, ensure_ascii=False); f.write("\n")
os.replace(path + ".tmp", path)
print("changed")
PY
}
