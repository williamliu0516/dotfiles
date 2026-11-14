#!/usr/bin/env python3
"""所有会话里的 Claude Code 窗格：Alt+a 跳到要你处理的那个，Alt+g 用 fzf 总览。

  agents.sh next <client>     Alt+a：等你批准 → 出错 → 跑完，同类里最近的在前；
                              连按依次往下跳，到最后一个绕回第一个
  agents.sh popup <client>    Alt+g：给这个客户端开一个 display-popup，里面跑 pick
  agents.sh pick <client>     弹窗里的 fzf 总览，回车跳过去
  agents.sh list              总览的行（pick 和 fzf 里 Ctrl-R 刷新用，调试时也能直接看）
  agents.sh preview <pane>    fzf 下方的预览：那个窗格当前的屏幕

Alt+g 的第一行总是协调者（bin/coordinator 开的那个，名字是 ~/.config/coordinator/config 的 COORD_NAME），
打开就直接回车回去。它是 `claude attach` 接上的后台会话，前台进程看着像 shell、窗格上也没有 @claude-session，
所以 agents() 认不出它，另找：窗格标题是这个名字、那个终端上跑着 coordinator。

状态由 claude-state.sh 写：窗格上的 @agent-pane-state / @agent-pane-at（每个 hook 事件都记）。
这两个是后加的，之前就开着的 Claude 在它的下一个事件之前只有窗口上的 @agent-state，这时用窗口的。
<client> 是按键那个客户端（#{client_name}）：Mac 和 iPad 同时连着时，只切按键的那一边。
"""
import os
import re
import shlex
import subprocess
import sys
import time
import unicodedata

# 状态 → (排序, 标签, 颜色)；颜色和顶栏窗口号一致（tmux.conf 的 @cc-style）
STATES = {
    'waiting': (0, '等你', '\x1b[1;33m'),
    'error':   (1, '出错', '\x1b[1;31m'),
    'done':    (2, '完成', '\x1b[1;32m'),
    'running': (3, '在跑', '\x1b[36m'),
    'idle':    (4, '空闲', '\x1b[37m'),
}
UNKNOWN = (5, '未知', '\x1b[90m')
ATTENTION = ('waiting', 'error', 'done')   # Alt+a 只跳这几种：都是在等你下一步
DIM, RESET = '\x1b[90m', '\x1b[0m'
SHELLS = {'zsh', '-zsh', 'bash', '-bash', 'sh', 'fish', '-fish'}
SELF = os.path.realpath(__file__)

FIELDS = ['pane_id', 'session_name', 'window_index', 'pane_index', 'window_panes',
          '@agent-pane-state', '@agent-state', '@agent-pane-at', '@claude-session',
          'pane_current_command', 'pane_current_path', 'pane_title', 'host', 'pane_tty']
COORD_CONF = os.path.expanduser('~/.config/coordinator/config')
COORD = (-1, '协调', '\x1b[1;35m')


def tmux(*args):
    return subprocess.run(['tmux', *args], capture_output=True, text=True).stdout


def agents():
    """Claude 窗格，按状态和最近事件排好。

    认 Claude 的办法：窗格上有 @claude-session（claude-state.sh 每个事件都记，SessionEnd 时清掉），
    或者前台进程就是 claude（它的进程名有时是版本号，比如 2.1.319）。前台已经回到 shell 的不算，
    那是 Claude 没走 SessionEnd 就退出了留下的旧标记。
    """
    out = tmux('list-panes', '-a', '-F', '\t'.join('#{%s}' % f for f in FIELDS))
    rows = []
    for line in out.splitlines():
        p = parse(line)
        if not p:
            continue
        cmd = p['pane_current_command']
        if cmd in SHELLS:
            continue
        if not (p['@claude-session'] or cmd == 'claude' or re.fullmatch(r'\d+\.\d+\.\d+', cmd)):
            continue
        rows.append(p)
    rows.sort(key=lambda p: (STATES.get(p['state'], UNKNOWN)[0], -p['at']))
    return rows


def parse(line):
    p = dict(zip(FIELDS, line.split('\t')))
    if len(p) < len(FIELDS):
        return None
    p['state'] = p['@agent-pane-state'] or p['@agent-state']
    p['at'] = int(p['@agent-pane-at']) if p['@agent-pane-at'].isdigit() else 0
    return p


def coordinator():
    """协调者的窗格，没开着就是 None。"""
    try:
        with open(COORD_CONF) as f:
            m = re.search(r'^COORD_NAME=["\']?([^"\'\n]+)', f.read(), re.M)
    except OSError:
        return None
    if not m:
        return None
    out = tmux('list-panes', '-a', '-F', '\t'.join('#{%s}' % f for f in FIELDS))
    for line in out.splitlines():
        p = parse(line)
        if not p or title(p) != m.group(1):
            continue
        # 标题会留在退出后的 shell 上；只认终端上还跑着 coordinator 的
        ps = subprocess.run(['ps', '-o', 'command=', '-t', p['pane_tty'].removeprefix('/dev/')],
                            capture_output=True, text=True, timeout=2).stdout
        if 'bin/coordinator' in ps:
            p['coord'] = True
            return p
    return None


def where(p):
    loc = f"{p['session_name']}:{p['window_index']}"
    return loc + f".{p['pane_index']}" if p['window_panes'] != '1' else loc


def jump(client, pane):
    # switch-client 换到窗格所在的会话；select-window / select-pane 把那个会话的当前窗口和窗格也指过去
    tmux('switch-client', '-c', client, '-t', pane, ';',
         'select-window', '-t', pane, ';', 'select-pane', '-t', pane)


def say(client, text):
    # display-message 把参数当格式解析，标题里的 # 要写成 ##
    tmux('display-message', '-c', client, '-d', '1500', text.replace('#', '##'))


def cmd_next(client):
    rows = [p for p in agents() if p['state'] in ATTENTION]
    if not rows:
        say(client, '没有要你处理的 Claude')
        return
    here = tmux('display-message', '-p', '-c', client, '#{pane_id}').strip()
    ids = [p['pane_id'] for p in rows]
    i = (ids.index(here) + 1) % len(rows) if here in ids else 0
    p = rows[i]
    jump(client, p['pane_id'])
    say(client, ' · '.join(filter(None, [f"{STATES[p['state']][1]} {i + 1}/{len(rows)}", where(p), title(p)])))


def title(p):
    # Claude Code 把对话标题写成终端标题，前面带一个状态符号（✳ 或转圈的 ⠂⠐），去掉。
    # 还没设过标题的窗格，tmux 给的默认标题是主机名，不显示
    if p['pane_title'] == p['host']:
        return ''
    return re.sub(r'^[^\w\s]+\s*', '', p['pane_title']).strip()


def width(text):
    return sum(0 if unicodedata.combining(c) else
               2 if unicodedata.east_asian_width(c) in 'WF' else 1 for c in text)


def fit(text, n):
    """截到 n 列（超了用 … 结尾）再补空格到 n 列。"""
    if width(text) > n:
        while text and width(text) > n - 1:
            text = text[:-1]
        text += '…'
    return text + ' ' * (n - width(text))


def branch(path, cache):
    if path not in cache:
        git = ['git', '-C', path, '--no-optional-locks']
        try:
            name = subprocess.run(git + ['symbolic-ref', '--short', '-q', 'HEAD'],
                                  capture_output=True, text=True, timeout=1).stdout.strip()
            if not name:
                sha = subprocess.run(git + ['rev-parse', '--short', 'HEAD'],
                                     capture_output=True, text=True, timeout=1).stdout.strip()
                name = '@' + sha if sha else ''
        except (OSError, subprocess.TimeoutExpired):
            name = ''
        cache[path] = name
    return cache[path]


def age(at, now):
    if not at:
        return ''
    s = max(0, now - at)
    for unit, n in (('d', 86400), ('h', 3600), ('m', 60)):
        if s >= n:
            return f'{s // n}{unit}'
    return f'{s}s'


def cmd_list():
    rows, cache, now = agents(), {}, int(time.time())
    coord = coordinator()
    if coord:
        rows = [coord] + [p for p in rows if p['pane_id'] != coord['pane_id']]
    if not rows:
        return
    cells = [(where(p), os.path.basename(p['pane_current_path']) or '/',
              branch(p['pane_current_path'], cache), age(p['at'], now)) for p in rows]
    w_loc = max(width(c[0]) for c in cells)
    w_dir = min(20, max(width(c[1]) for c in cells))
    w_br = min(24, max(width(c[2]) for c in cells))
    for p, (loc, folder, br, ago) in zip(rows, cells):
        _, label, color = COORD if p.get('coord') else STATES.get(p['state'], UNKNOWN)
        print(f"{p['pane_id']}\t{color}● {label}{RESET}  {fit(loc, w_loc)}  {fit(folder, w_dir)}  "
              f"{DIM}{fit(br, w_br)}{RESET}  {DIM}{ago:>3}{RESET}  {title(p)}")


def cmd_preview(pane):
    screen = tmux('capture-pane', '-e', '-p', '-t', pane).split('\n')
    # 屏幕没写满时底下是空行；去掉，fzf 的 follow 才会停在 Claude 的输入框上
    while screen and not re.sub(r'\x1b\[[0-9;:]*[A-Za-z]', '', screen[-1]).strip():
        screen.pop()
    print('\n'.join(screen))


def cmd_popup(client):
    cmd = ' '.join(shlex.quote(a) for a in (SELF, 'pick', client))
    tmux('display-popup', '-c', client, '-w', '90%', '-h', '85%', '-E', cmd)


def cmd_pick(client):
    rows = subprocess.run([SELF, 'list'], capture_output=True, text=True).stdout
    if not rows:
        print('没有在跑的 Claude')
        time.sleep(1)
        return
    picked = subprocess.run(
        # --height / --border 盖掉 FZF_DEFAULT_OPTS 里的 40% 和圆角框：弹窗本身就有框，要占满它
        ['fzf', '--height=100%', '--border=none',
         '--ansi', '--layout=reverse', '--delimiter=\t', '--with-nth=2..',
         '--prompt=agent › ', '--header=回车跳过去（第一行是协调者） · Ctrl-R 刷新 · Esc 或 Alt+g 关闭',
         f'--preview={SELF} preview {{1}}', '--preview-window=down,60%,border-top,follow',
         f'--bind=ctrl-r:reload({SELF} list)', '--bind=alt-g:abort'],
        input=rows, stdout=subprocess.PIPE, text=True).stdout
    if picked.strip():
        jump(client, picked.split('\t', 1)[0])


def main(argv):
    cmd, args = (argv[1], argv[2:]) if len(argv) > 1 else ('', [])
    if cmd == 'list' and not args:
        cmd_list()
    elif cmd == 'preview' and len(args) == 1:
        cmd_preview(args[0])
    elif cmd in ('next', 'popup', 'pick') and len(args) == 1:
        {'next': cmd_next, 'popup': cmd_popup, 'pick': cmd_pick}[cmd](args[0])
    else:
        sys.exit(__doc__)


if __name__ == '__main__':
    main(sys.argv)
