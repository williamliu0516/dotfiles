#!/bin/sh
# 把所有免前缀的 Alt 键位镜像到前缀表：先按 Ctrl+b 松开，再按同一个键，效果和 Alt+键 一样。
# 给发不出 Alt 的键盘用——iPad 上的 Termius / Moshi 等 SSH 客户端，Option 默认被 iPadOS 拿去打特殊字符，
# 没开"Option as Meta"时终端收不到 Alt；有些客户端的屏幕键盘干脆没有 Alt。
# 从运行中的 server 读 root 表生成，不手抄一份，所以 tmux.conf 里的 Alt 键位怎么改这里都跟着变。
# 会覆盖 tmux 默认的几个前缀键：n（下一窗口→新窗口）、;（上一窗格→上一窗口）、
# ←/→（切窗格→切窗口）、空格（换布局→新窗格）、f、t、m、s、x（不再确认）、< >。
# 用法: 由 tmux.conf 末尾的 run-shell 调用；prefix + r 重载配置时也会重跑
tmp="$(mktemp)" || exit 1
trap 'rm -f "$tmp"' EXIT
tmux list-keys -T root \
  | grep -v 'Mouse' \
  | sed -nE 's/^bind-key +(-r +)?-T root +"?M-([^ "]+)"? +/bind-key \1-T prefix "\2" /p' \
  > "$tmp"
tmux source-file "$tmp"
