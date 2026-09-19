#!/usr/bin/env python3
"""从 tmux.conf 自动生成速查表 —— 绑定改了这里就跟着变。"""
import re,os,sys,shutil,unicodedata
ALT='Option+' if sys.platform=='darwin' else 'Alt+'   # Mac 键盘上 Alt 叫 Option
MAC=sys.platform=='darwin'
WAIT='--no-wait' not in sys.argv       # 走 less 时不用等按键
CONF=os.path.expanduser('~/.config/tmux/tmux.conf')
W=min(shutil.get_terminal_size((80,24)).columns, 78)

def dw(t):
    return sum(2 if unicodedata.east_asian_width(c) in 'WF' else 1 for c in t)
def pad(t,n):
    return t+' '*max(0,n-dw(t))

C={'t':'\x1b[1;38;5;111m','k':'\x1b[38;5;215m','d':'\x1b[38;5;252m',
   'm':'\x1b[38;5;245m','r':'\x1b[0m','b':'\x1b[1m'}

root,pref=[],[]
pat=re.compile(r'^bind(?:-key)?\s+((?:-[a-zA-Z]+\s+)*)-N\s+"([^"]+)"\s+("[^"]+"|\S+)')
for line in open(CONF,encoding='utf-8'):
    m=pat.match(line.strip())
    if not m: continue
    flags,note,key=m.groups()
    key=key.strip('"')
    key=key.replace('M-',ALT).replace('C-','Ctrl+')
    (root if '-n' in flags.split() else pref).append((key,note))

def block(title,items,hint):
    print(f"\n{C['t']}{title}{C['r']}  {C['m']}{hint}{C['r']}")
    print(f"{C['m']}{'─'*W}{C['r']}")
    for k,n in items:
        print(f"  {C['k']}{pad(k,16)}{C['r']}{C['d']}{n}{C['r']}")

print(f"\n{C['b']}  速查表{C['r']}   {C['m']}按 q 关闭 · 随时按 {ALT}/ 打开这张表（tmux 内外都行）{C['r']}")

block("shell（zsh）",[
    ("→","接受灰色建议"),
    ("Tab","fzf 补全：敲字母筛，/ 进下一层目录，< > 切组"),
    ("↑ / ↓","按已输入的前缀筛历史"),
    ("Ctrl+R","fzf 搜历史，下方预览完整命令"),
    ("Ctrl+T","fzf 选文件，右侧 bat 预览"),
    (ALT+"C","fzf 跳目录（tmux 外）"),
    (ALT+"← / →","按词移动（tmux 外）"),
    ("Ctrl+← / →","按词移动" + ("（Mac 上被 Mission Control 占用）" if MAC else "")),
    ("Ctrl+Backspace","删一个词"),
    ("y","yazi 文件管理器，退出时 cd 到停留目录"),
    ("z 关键词","zoxide 按访问频率跳目录"),
    ("cheat","打开这张表"),
    ("tk","杀整个 tmux server"),
],"")
block("自动发生",[
    ("命令 > 30 秒","结束时桌面通知（你没在看时）"),
    ("Claude 等你 / 完成 / 出错","窗口号变色 + 桌面通知（你没在看时）"),
    ("会话","每 15 分钟存档，重启后自动恢复"),
],"")
print(f"\n{C['b']}  tmux{C['r']}")
block("免前缀（直接按）",root,"")
block("前缀键",pref,"先按 Ctrl+b 松开，再按下面的键")

print(f"\n{C['t']}鼠标（已开启，这些完全不用记）{C['r']}")
print(f"{C['m']}{'─'*W}{C['r']}")
for k,n in [("单击窗格","切换焦点"),("拖拽窗格边框","调整大小"),
            ("单击顶栏窗口名","切到那个窗口"),("滚轮","翻历史（自动进复制模式）"),
            ("右键窗格 / 顶栏","弹出 tmux 自带菜单"),("拖选文字","自动复制到系统剪贴板")]:
    print(f"  {C['k']}{pad(k,16)}{C['r']}{C['d']}{n}{C['r']}")

print(f"\n{C['t']}复制模式（滚轮或 PageUp 进入）{C['r']}")
print(f"{C['m']}{'─'*W}{C['r']}")
for k,n in [("/","向下搜索"),("?","向上搜索"),("n / N","跳下一个 / 上一个匹配"),
            ("v","开始选择"),("y","复制并退出"),("g / G","跳到最顶 / 最底"),("q 或 Esc","退出")]:
    print(f"  {C['k']}{pad(k,16)}{C['r']}{C['d']}{n}{C['r']}")

print(f"\n{C['m']}  记不住？{C['r']}{C['k']}{ALT}m{C['r']}{C['m']} 开菜单，全部操作都在里面挑。{C['r']}\n")
if WAIT:
    try: input()
    except: pass
