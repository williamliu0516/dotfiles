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

# 软链配置；目标已存在且不是软链时先备份
link() {
  local src=$1 dst=$2
  mkdir -p "$(dirname "$dst")"
  if [ -e "$dst" ] && [ ! -L "$dst" ]; then
    mv "$dst" "$dst.bak.$(stamp)"; warn "已备份原有 $(basename "$dst")"
  fi
  ln -sfn "$src" "$dst"; ok "$(echo "$dst" | sed "s|$HOME|~|")"
}

# 装系统包：apt 或 brew。逐个装，单个失败不中断
pkg_install() {
  local p missing=""
  if [ "$OS" = macos ]; then
    for p in "$@"; do brew list --formula "$p" >/dev/null 2>&1 || missing="$missing $p"; done
    [ -z "$missing" ] && { ok "系统包已齐"; return 0; }
    for p in $missing; do
      brew install -q "$p" >/dev/null 2>&1 && ok "$p" || warn "$p 装不上，跳过"
    done
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
