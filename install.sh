#!/usr/bin/env bash
# dotfiles 安装入口：选要装的模块，依次执行 modules/<名字>/install.sh
#   curl -fsSL https://xiaweiliu.com/dotfiles/install.sh | bash
#   （备用）curl -fsSL https://raw.githubusercontent.com/williamliu0516/dotfiles/main/install.sh | bash
#
#   bash install.sh                        交互菜单
#   bash install.sh --only terminal,claude-tmux
#   bash install.sh --all                  本系统能装的全部
#   bash install.sh --list                 列出模块
#
# 必须兼容 macOS 自带的 bash 3.2：不用关联数组、mapfile、${var,,}。
set -euo pipefail

REPO_URL="${DOTFILES_REPO:-https://github.com/williamliu0516/dotfiles.git}"
DOTFILES="${DOTFILES_DIR:-$HOME/.dotfiles}"
export DOTFILES_DIR="$DOTFILES"

# 模块的显示和执行顺序；不在这里的新模块排在最后
ORDER="terminal claude-tmux claude-statusline keyboard-display gnome-desktop"

# 仓库还没拉下来之前，lib/common.sh 不可用，先用最小的一套输出函数
bold() { printf '\033[1m%s\033[0m\n' "$*"; }
info() { printf '\033[38;5;111m▎\033[0m %s\n' "$*"; }
ok()   { printf '\033[38;5;77m  ✓\033[0m %s\n' "$*"; }
warn() { printf '\033[38;5;215m  !\033[0m %s\n' "$*"; }
die()  { printf '\033[38;5;203m  ✗\033[0m %s\n' "$*" >&2; exit 1; }
have() { command -v "$1" >/dev/null 2>&1; }

usage() { sed -n '2,10p' "$0" 2>/dev/null | sed 's/^# \{0,1\}//'; exit 0; }

MODE=menu ONLY=""
while [ $# -gt 0 ]; do
  case "$1" in
    --all)    MODE=all ;;
    --only)   MODE=only; ONLY="${2:-}"; shift ;;
    --only=*) MODE=only; ONLY="${1#--only=}" ;;
    --list)   MODE=list ;;
    -h|--help) usage ;;
    *) die "不认识的参数：$1（--help 看用法）" ;;
  esac
  shift
done

# ── 系统检查 ────────────────────────────────────────────────
[ "$(id -u)" -ne 0 ] || die "请用普通用户运行，需要时脚本会自己调 sudo"
case "$(uname -s)" in
  Linux)
    have apt-get || die "Linux 目前只支持 Debian/Ubuntu 系（apt）"
    have sudo || die "需要 sudo"
    have git || { info "安装 git"; sudo apt-get update -qq; sudo apt-get install -y -qq git curl >/dev/null; }
    ;;
  Darwin)
    # Apple Silicon 上新开的 shell 里 brew 可能还不在 PATH
    for b in /opt/homebrew/bin/brew /usr/local/bin/brew; do
      if ! have brew && [ -x "$b" ]; then eval "$("$b" shellenv)"; fi
    done
    have brew || die "需要 Homebrew。先装它再重跑本脚本：
    /bin/bash -c \"\$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)\""
    xcode-select -p >/dev/null 2>&1 || die "需要 Xcode 命令行工具（里面有 git）：先运行 xcode-select --install，装完重跑"
    ;;
  *) die "只支持 Linux（Debian/Ubuntu）和 macOS" ;;
esac

# ── 拉仓库 ──────────────────────────────────────────────────
if [ -d "$DOTFILES/.git" ]; then
  git -C "$DOTFILES" pull --ff-only -q 2>/dev/null || warn "dotfiles 没能更新，用现有版本"
else
  info "克隆 dotfiles → $DOTFILES"; git clone -q --depth 1 "$REPO_URL" "$DOTFILES"
fi
. "$DOTFILES/lib/common.sh"

# ── 发现模块 ────────────────────────────────────────────────
# 每个模块在 install.sh 开头用注释声明 name / desc / os / needs
meta() { sed -n "s/^# $2: *//p" "$DOTFILES/modules/$1/install.sh" | head -1; }

supported() {  # 本机能不能装这个模块
  local tag
  for tag in $(meta "$1" os); do
    [ "$tag" = "$OS" ] && return 0
    [ "$tag" = gnome ] && is_gnome && return 0
  done
  return 1
}

ALL=""
for id in $ORDER $(ls "$DOTFILES/modules"); do
  [ -f "$DOTFILES/modules/$id/install.sh" ] || continue
  case " $ALL " in *" $id "*) continue ;; esac
  supported "$id" && ALL="$ALL $id"
done
ALL="${ALL# }"
[ -n "$ALL" ] || die "这台机器上没有可装的模块"

if [ "$MODE" = list ]; then
  for id in $ALL; do printf '  %-18s %s — %s\n' "$id" "$(meta "$id" name)" "$(meta "$id" desc)"; done
  exit 0
fi

# ── 选择 ────────────────────────────────────────────────────
SEL=""
if [ "$MODE" = all ]; then
  SEL="$ALL"
elif [ "$MODE" = only ]; then
  for id in $(echo "$ONLY" | tr ',' ' '); do
    case " $ALL " in
      *" $id "*) SEL="$SEL $id" ;;
      *) die "模块 $id 不存在或不支持本系统（--list 看可用的）" ;;
    esac
  done
else
  has_tty || die "没有可交互的终端。用 --all 或 --only <模块,...> 指定要装什么"
  N=$(echo $ALL | wc -w | tr -d ' ')
  # 每个模块一个勾选位，1 = 选中；默认全选
  CHECK=""; for id in $ALL; do CHECK="${CHECK}1"; done
  CUR=1

  nth()    { echo $ALL | tr ' ' '\n' | sed -n "${1}p"; }   # 第 n 个模块名
  bit()    { printf '%s' "${CHECK:$(( $1 - 1 )):1}"; }
  toggle() {
    local b=1; [ "$(bit "$1")" = 1 ] && b=0
    CHECK="${CHECK:0:$(( $1 - 1 ))}$b${CHECK:$1}"
  }

  draw() {
    local i id mark ptr
    {
      printf '\033[H\033[J'
      printf '\n  \033[1m选择要安装的内容\033[0m  \033[2m(%s)\033[0m\n\n' "$( [ "$OS" = macos ] && echo macOS || echo "$PRETTY" )"
      i=1
      for id in $ALL; do
        [ "$(bit $i)" = 1 ] && mark='\033[38;5;77m◉\033[0m' || mark='\033[2m○\033[0m'
        if [ $i -eq $CUR ]; then ptr='\033[38;5;111m❯\033[0m'; else ptr=' '; fi
        printf "  $ptr $mark  %s\n" "$(meta "$id" name)"
        i=$((i + 1))
      done
      printf '\n  \033[2m%s\033[0m\n' "$(meta "$(nth $CUR)" desc)"
      local needs; needs=$(meta "$(nth $CUR)" needs)
      if [ -n "$needs" ]; then printf '  \033[2m依赖：%s（会自动一起装）\033[0m\n' "$needs"; fi
      printf '\n  \033[2m↑↓ 移动 · 空格 勾选 · a 全选/全不选 · 回车 开始 · q 退出\033[0m\n'
    } >/dev/tty
  }

  PRETTY="$( [ -r /etc/os-release ] && . /etc/os-release && echo "$PRETTY_NAME" || uname -s )"
  # 用备用屏幕画菜单：每次整屏重画，不怕中文宽度和自动换行算错行数
  printf '\033[?1049h\033[?25l' >/dev/tty
  trap 'printf "\033[?25h\033[?1049l" >/dev/tty' EXIT
  while :; do
    draw
    IFS= read -rsn1 key </dev/tty || key=q
    if [ "$key" = $'\033' ]; then IFS= read -rsn2 rest </dev/tty || rest=""; key="ESC$rest"; fi
    case "$key" in
      'ESC[A'|k) if [ $CUR -gt 1 ]; then CUR=$((CUR - 1)); fi ;;
      'ESC[B'|j) if [ $CUR -lt $N ]; then CUR=$((CUR + 1)); fi ;;
      ' ') toggle $CUR ;;
      a|A) case "$CHECK" in *0*) CHECK=$(printf '%s' "$CHECK" | tr 0 1) ;; *) CHECK=$(printf '%s' "$CHECK" | tr 1 0) ;; esac ;;
      '') break ;;
      q|Q) printf '\033[?25h\033[?1049l' >/dev/tty; trap - EXIT; echo "已取消"; exit 0 ;;
    esac
  done
  printf '\033[?25h\033[?1049l' >/dev/tty; trap - EXIT
  i=1; for id in $ALL; do if [ "$(bit $i)" = 1 ]; then SEL="$SEL $id"; fi; i=$((i + 1)); done
fi

# 补上依赖，并按 ORDER 排序
add_needs() {
  local id=$1 dep
  for dep in $(meta "$id" needs); do
    case " $SEL " in *" $dep "*) ;; *)
      case " $ALL " in *" $dep "*) SEL="$SEL $dep"; add_needs "$dep"; info "$(meta "$id" name) 依赖 $(meta "$dep" name)，一起装" ;;
      *) die "$id 依赖的 $dep 不支持本系统" ;; esac ;;
    esac
  done
}
for id in $SEL; do add_needs "$id"; done
RUN=""; for id in $ALL; do case " $SEL " in *" $id "*) RUN="$RUN $id" ;; esac; done
RUN="${RUN# }"
[ -n "$RUN" ] || { echo "什么都没选，退出"; exit 0; }
# 试运行：只打印会执行哪些模块（测试菜单和依赖用）
if [ -n "${DOTFILES_DRY_RUN:-}" ]; then echo "会执行：$RUN"; exit 0; fi

# ── 执行 ────────────────────────────────────────────────────
DONE="" FAILED=""
for id in $RUN; do
  echo
  bold "━━ $(meta "$id" name)"
  if bash "$DOTFILES/modules/$id/install.sh"; then DONE="$DONE $id"
  else FAILED="$FAILED $id"; warn "$(meta "$id" name) 出错，继续装下一个"; fi
done

echo
bold "装完了。"
for id in $DONE;   do ok   "$(meta "$id" name)"; done
for id in $FAILED; do warn "$(meta "$id" name)（失败，可以单独重跑：bash $DOTFILES/install.sh --only $id）"; done
[ -z "$FAILED" ]
