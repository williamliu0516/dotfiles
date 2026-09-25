#!/bin/sh
# 自动排版：开 / 关窗格后自动重排，不用再手动 Alt+m | / _ 挑布局。思路来自 ausbxuse 的 tmux 配置
# （github.com/ausbxuse/tmux 的 dwm.sh）：按窗格数决定怎么分，分完统一 select-layout。
# 四种模式，按窗口记在 @tiling-mode 里，Alt+Shift+t 轮换：
#   row   一字排开（parallel）：所有窗格从左到右排成一行、宽度均分，新窗格永远接在最右边。给 32:9 超宽屏用
#   dwm   （默认）左边一个主窗格，其余在右边从上往下排成一栏（main-vertical）
#   grid  四宫格：上左 / 上右 / 下左 / 下右（tiled）。只有正好 4 个窗格时才进轮换
#   dwm2  dwm 变体：左边主窗格，右上一个，右下再左右分成两个。只有正好 4 个窗格时才进轮换
# 后两种在窗格数不是 4 的时候退回 dwm 排（模式仍记着，回到 4 个就恢复）。
# 重排挂在 tmux.conf 的 hook 上，所以鼠标、菜单、前缀键分屏都会自动重排；再加上 dwm 的"设为主窗格"
# 和按窗口开关自动排版。
# 用法: dwm.sh new|zoom|toggle|keep|mode <pane_id> [row|dwm|grid|dwm2]
#   new     新窗格：row 接到最右边，其余排到右侧栏最下面；焦点跟过去
#   zoom    当前窗格和主窗格（最左边那个）互换（dwm 的 Mod+Enter）；本身就是主窗格时和第二个互换
#   toggle  当前窗口开 / 关自动排版（关掉后分屏、布局都回到手动）
#   keep    手动调过主窗格宽度后记下来，之后重排保持这个宽度（dwm 的 mfact）；row / grid 永远均分，不记
#   mode    切换排版模式；不带参数就按 row → dwm →（grid → dwm2，仅 4 窗格）→ row 轮换。选了模式就顺手把自动排版打开
#   resized 窗口尺寸变了：grid / dwm2 按新尺寸重算（其余模式 tmux 自己等比缩放就够了）
# 自动重排本身在 tmux.conf 的 hook 里，不走这个脚本，省得每次开关窗格都起一个 shell；
# dwm2 的布局串在这里算好存进窗口选项 @dwm2-layout，hook 直接拿来 select-layout
cmd=$1
pane=${2:-$TMUX_PANE}
[ -n "$pane" ] || exit 2
win=$(tmux display -p -t "$pane" '#{window_id}') || exit 0
tiling() { [ "$(tmux show -wqv -t "$win" @tiling)" != off ]; }
# 窗口没设过就用全局的（tmux.conf 里 set -g @tiling-mode row 可以把默认改成一字排开）
mode() {
  case "$(tmux display -p -t "$win" '#{@tiling-mode}')" in
    row) echo row ;; grid) echo grid ;; dwm2) echo dwm2 ;; *) echo dwm ;;
  esac
}
panes() { tmux display -p -t "$win" '#{window_panes}'; }
zoomed() { [ "$(tmux display -p -t "$win" '#{window_zoomed_flag}')" = 1 ]; }
# 主窗格宽度（格数）：窗口自己记过的优先，否则全局的 main-pane-width（可能是百分比）
main_width() {
  W=$(tmux display -p -t "$win" '#{window_width}')
  w=$(tmux show -wqv -t "$win" main-pane-width)
  [ -n "$w" ] || w=$(tmux show -gqv main-pane-width)
  case "$w" in
    '') w=$((W / 2)) ;;
    *%) w=$((W * ${w%\%} / 100)) ;;
  esac
  echo "$w"
}
# tmux 自定义布局串前面 4 位十六进制校验和（layout_checksum：右旋一位再加字符）
checksum() {
  awk -v s="$1" 'BEGIN {
    for (i = 1; i < 256; i++) ord[sprintf("%c", i)] = i
    c = 0
    for (i = 1; i <= length(s); i++) { c = int(c / 2) + (c % 2) * 32768; c = (c + ord[substr(s, i, 1)]) % 65536 }
    printf "%04x", c
  }'
}
# dwm2 的布局串：左主窗格宽 $1 格，右边上下对半，下半再左右对半。
# tmux 解析时只看格子数和顺序，串里的窗格 id 随便写；尺寸和当前窗口不一致也会自动拉伸
dwm2_layout() {
  W=$(tmux display -p -t "$win" '#{window_width}')
  H=$(tmux display -p -t "$win" '#{window_height}')
  L=$1
  [ "$L" -ge 1 ] || L=1
  [ "$L" -le $((W - 3)) ] || L=$((W - 3))
  R=$((W - L - 1)); T=$((H / 2)); B=$((H - T - 1)); BL=$((R / 2)); BR=$((R - BL - 1))
  body="${W}x${H},0,0{${L}x${H},0,0,0,${R}x${H},$((L + 1)),0[${R}x${T},$((L + 1)),0,1,${R}x${B},$((L + 1)),$((T + 1)){${BL}x${B},$((L + 1)),$((T + 1)),2,${BR}x${B},$((L + BL + 2)),$((T + 1)),3}]}"
  printf '%s,%s' "$(checksum "$body")" "$body"
}
layout() {
  case "$(mode)" in
    row) echo even-horizontal ;;
    grid) [ "$(panes)" = 4 ] && echo tiled || echo main-vertical ;;
    dwm2) if [ "$(panes)" = 4 ]; then l=$(dwm2_layout "$(main_width)"); tmux set -w -t "$win" @dwm2-layout "$l"; echo "$l"
          else echo main-vertical; fi ;;
    *) echo main-vertical ;;
  esac
}
retile() {
  tiling || return 0
  zoomed && return 0
  tmux select-layout -t "$win" "$(layout)"
}

case "$cmd" in
  new)
    dir=$(tmux display -p -t "$pane" '#{pane_current_path}')
    [ "$(tmux display -p -t "$win" '#{window_zoomed_flag}')" = 1 ] && tmux resize-pane -Z -t "$win"
    if ! tiling; then
      tmux split-window -h -t "$pane" -c "$dir"
    elif [ "$(mode)" = row ]; then
      # 从最右边的窗格往右分，新窗格就接在行尾；after-split-window hook 负责均分
      tmux split-window -h -t "$win.{bottom-right}" -c "$dir"
    else
      # 从栈底分出来，新窗格就排在最后；after-split-window hook 负责重排
      tmux split-window -v -t "$win.{bottom-right}" -c "$dir"
    fi
    ;;
  zoom)
    [ "$(tmux display -p -t "$win" '#{window_panes}')" -gt 1 ] || exit 0
    [ "$(tmux display -p -t "$win" '#{window_zoomed_flag}')" = 1 ] && tmux resize-pane -Z -t "$win"
    master=$(tmux display -p -t "$win.{top-left}" '#{pane_id}')
    if [ "$pane" = "$master" ]; then
      other=$(tmux list-panes -t "$win" -F '#{pane_id}' | sed -n 2p)
    else
      other=$pane
    fi
    tmux swap-pane -d -s "$other" -t "$master"
    tmux select-pane -t "$other"
    retile
    ;;
  toggle)
    if tiling; then
      tmux set -w -t "$win" @tiling off
      tmux display "自动排版：关（当前窗口）"
    else
      tmux set -wu -t "$win" @tiling
      retile
      tmux display "自动排版：开"
    fi
    ;;
  keep)
    tiling || exit 0
    case "$(mode)" in row|grid) exit 0 ;; esac
    zoomed && exit 0
    [ "$(panes)" -gt 1 ] || exit 0
    w=$(tmux display -p -t "$win.{top-left}" '#{pane_width}')
    W=$(tmux display -p -t "$win" '#{window_width}')
    # 只记宽度不重排：右侧栏里上下调的高度要留着，下次开关窗格才会重排。
    # 记成百分比：换个尺寸的客户端（iPad）连上来时按比例缩，不会一个 150 格的主窗格把 160 格的窗口吃光
    tmux set -w -t "$win" main-pane-width "$((w * 100 / W))%"
    # dwm2 的布局串带着宽度，跟着更新，之后 hook 重排时才是新宽度
    [ "$(mode)" = dwm2 ] && [ "$(panes)" = 4 ] && tmux set -w -t "$win" @dwm2-layout "$(dwm2_layout "$w")"
    ;;
  mode)
    want=$3
    if [ -z "$want" ]; then
      # 轮换：正好 4 个窗格时多两种；当前模式不在队列里（4 窗格模式但现在不是 4 个）就当 dwm 往下走
      if [ "$(panes)" = 4 ]; then order="row dwm grid dwm2"; else order="row dwm"; fi
      cur=$(mode)
      case " $order " in *" $cur "*) ;; *) cur=dwm ;; esac
      want=${order%% *}; hit=
      for m in $order; do
        if [ -n "$hit" ]; then want=$m; break; fi
        [ "$m" = "$cur" ] && hit=1
      done
    fi
    case "$want" in
      row|dwm|grid|dwm2) tmux set -w -t "$win" @tiling-mode "$want" ;;   # 写死，之后改全局默认也不影响这个窗口
      *) echo "用法: $0 mode <pane_id> [row|dwm|grid|dwm2]" >&2; exit 2 ;;
    esac
    tmux set -wu -t "$win" @tiling
    zoomed && tmux resize-pane -Z -t "$win"
    retile
    case "$want" in
      row)  tmux display "排版：一字排开 parallel（新窗格接在最右边）" ;;
      dwm)  tmux display "排版：dwm（左主窗格 + 右侧栏）" ;;
      grid) tmux display "排版：四宫格 2×2" ;;
      dwm2) tmux display "排版：dwm 变体（左主窗格 + 右上 + 右下左右分）" ;;
    esac
    ;;
  resized)
    case "$(mode)" in grid|dwm2) [ "$(panes)" = 4 ] && retile ;; esac
    ;;
  *) echo "用法: $0 new|zoom|toggle|keep|mode|resized <pane_id> [row|dwm|grid|dwm2]" >&2; exit 2 ;;
esac
exit 0
