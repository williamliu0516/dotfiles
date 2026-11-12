# 刘海布局：状态栏的窗口标签按编号固定分成左右两组，在摄像头两侧对称排开，中间空出刘海的宽度。
# 窗口放不下时分页，‹ / › 表示还有窗口；长名称截断，保留颜色和鼠标点选。
#
# 状态栏是每个客户端各算各的，所以同一个会话里，只有从 MacBook 屏幕看的那个客户端让出刘海，
# iPad、别的电脑、这台机器自己的屏幕照常。用这个布局的客户端：
#   - 本机（tmux.conf 按机型设 @notch-local）上的 Ghostty
#   - pid 登记在 @notch-clients 里的客户端：MacBook 上的 sshx / moshx 连到别的机器时，接入后登记自己。
#     这个文件也是 sshx 每次连接时带到对方机器上的，所以对方不用装这套 dotfiles
# 另外都要求：状态栏在顶部、客户端不窄于 120 列、右侧还能留出 42 列。
#
# 文件可以反复加载：已经是刘海格式时不再把它当成默认格式记下来。
#
# 要 tmux 的 #{R:} 和多参数 #{&&:}（3.4 都没有：R: 原样输出，&& 只看前两个参数）；没有就整段不加载，状态栏照常
%if "#{&&:#{==:#{R:x,2},xx},#{!:#{&&:1,1,0}}}"

if -F '#{!:#{m:*@notch-format*,#{status-format[0]}}}' {
  set -gF @notch-default '#{status-format[0]}'
}

# 每格标签的列宽预算：所有标签都不超过 8 列按 8，否则按截断后的最大 12 列。结果按会话缓存，
# 免得在窗口循环里再套一层窗口循环；窗口增删改名、新会话、有客户端接入时重算
set -g @notch-cell '12'
set -g @notch-cell-format '#{?#{n:#{W:#{?#{e|>:#{w;T:window-status-format},8},x,},#{?#{e|>:#{w;T:window-status-format},8},x,}}},12,8}'
set-hook -g after-new-window[90]    'set -F @notch-cell "#{E:@notch-cell-format}"'
set-hook -g after-rename-window[90] 'set -F @notch-cell "#{E:@notch-cell-format}"'
set-hook -g window-renamed[90]      'set -F @notch-cell "#{E:@notch-cell-format}"'
set-hook -g window-linked[90]       'set -F @notch-cell "#{E:@notch-cell-format}"'
set-hook -g window-unlinked[90]     'set -F @notch-cell "#{E:@notch-cell-format}"'
set-hook -g session-created[90]     'set -F @notch-cell "#{E:@notch-cell-format}"'
set-hook -g client-attached[90]     'set -F @notch-cell "#{E:@notch-cell-format}"'
if -F '#{session_id}' { set -F @notch-cell '#{E:@notch-cell-format}' }

# 客户端断开时，只留下还连着的那些 pid（client-detached 钩子里已经拿不到断开的那个客户端，只能反过来筛）
set-hook -g client-detached[90] 'set -gF @notch-clients "#{L:#{?#{m:* #{client_pid} *,#{@notch-clients}}, #{client_pid} ,}}"'

# 摄像头区域 102 像素，按客户端报的字符宽度换成列数再加两列边距；终端不报字符宽度（mosh、多数 iPad 客户端）时留 8 列
set -g @notch-pixels '102'
set -g @notch-gap '#{?#{e|>:#{client_cell_width},0},#{e|+:#{e|/:#{e|+:#{@notch-pixels},#{e|-:#{client_cell_width},1}},#{client_cell_width}},2},8}'
set -g @notch-limit '#{e|/:#{e|-:#{e|-:#{e|/:#{client_width},2},#{?#{e|>:#{w;T:status-left},42},#{w;T:status-left},42}},#{e|+:#{e|/:#{e|+:#{E:@notch-gap},1},2},4}},#{E:@notch-cell}}'
set -g @notch-active-order '#{e|-:#{active_window_index},#{base-index}}'
set -g @notch-page-size '#{e|*:#{E:@notch-limit},2}'
set -g @notch-start '#{e|+:#{base-index},#{e|*:#{e|/:#{E:@notch-active-order},#{E:@notch-page-size}},#{E:@notch-page-size}}}'
set -g @notch-end '#{?#{e|>=:#{last_window_index},#{e|+:#{E:@notch-start},#{E:@notch-page-size}}},#{e|+:#{E:@notch-start},#{E:@notch-page-size}},#{e|+:#{last_window_index},1}}'
set -g @notch-split '#{e|+:#{E:@notch-start},#{e|/:#{e|+:#{e|-:#{E:@notch-end},#{E:@notch-start}},1},2}}'
set -g @notch-left '#{?#{e|>:#{E:@notch-start},#{base-index}},‹,}#{W:#{?#{&&:#{e|>=:#{window_index},#{E:@notch-start}},#{e|<:#{window_index},#{E:@notch-split}}},#[range=window|#{window_index}]#{=/11/…:#{T:window-status-format}}#[norange default],},#{?#{&&:#{e|>=:#{window_index},#{E:@notch-start}},#{e|<:#{window_index},#{E:@notch-split}}},#[range=window|#{window_index}]#{=/11/…:#{T:window-status-current-format}}#[norange default],}}'
set -g @notch-right '#{W:#{?#{&&:#{e|>=:#{window_index},#{E:@notch-split}},#{e|<:#{window_index},#{E:@notch-end}}},#[range=window|#{window_index}]#{=/11/…:#{T:window-status-format}}#[norange default],},#{?#{&&:#{e|>=:#{window_index},#{E:@notch-split}},#{e|<:#{window_index},#{E:@notch-end}}},#[range=window|#{window_index}]#{=/11/…:#{T:window-status-current-format}}#[norange default],}}#{?#{e|<=:#{E:@notch-end},#{last_window_index}},›,}'
# 左边补两列空白，使可见标签整体右移一列，对准相机中心。
set -g @notch-format '#[align=left range=left #{E:status-left-style}]#{T:status-left}#[norange default]#[list=on align=absolute-centre]  #{?#{e|>:#{w;E:@notch-right},#{w;E:@notch-left}},#{R: ,#{e|-:#{w;E:@notch-right},#{w;E:@notch-left}}},}#{E:@notch-left}#{R: ,#{E:@notch-gap}}#{E:@notch-right}#{?#{e|>:#{w;E:@notch-left},#{w;E:@notch-right}},#{R: ,#{e|-:#{w;E:@notch-left},#{w;E:@notch-right}}},}#[nolist align=right range=right #{E:status-right-style}]#{T:status-right}#[norange default]'

# 这个客户端要不要让出刘海
set -g @notch-client '#{||:#{&&:#{@notch-local},#{m:*ghostty*,#{client_termname}}},#{m:* #{client_pid} *,#{@notch-clients}}}'
set -g 'status-format[0]' '#{?#{&&:#{E:@notch-client},#{==:#{status-position},top},#{e|>=:#{client_width},120},#{e|>=:#{active_window_index},#{base-index}},#{e|>:#{E:@notch-limit},0}},#{E:@notch-format},#{E:@notch-default}}'
%endif
