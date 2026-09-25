# dotfiles

Terminal setup (**Ghostty + tmux + zsh**), Claude Code extras, and a GNOME desktop look. One command on a fresh machine, Ubuntu or macOS:

```bash
curl -fsSL https://xiaweiliu.com/dotfiles/install.sh | bash
```

It opens a menu — pick what you want with the arrow keys and space, Enter to start. Only the parts that work on the current machine are listed. Same script straight from GitHub, if the site is ever down:

```bash
curl -fsSL https://raw.githubusercontent.com/williamliu0516/dotfiles/main/install.sh | bash
```

## Modules

| id | | Linux | macOS |
|---|---|:-:|:-:|
| `terminal` | Ghostty + tmux + zsh, fonts, plugins | ✓ | ✓ |
| `claude-tmux` | tmux window numbers coloured by Claude Code state (needs `terminal`) | ✓ | ✓ |
| `claude-statusline` | Claude Code status line — folder, branch, model, 5h and weekly usage. From [claude-status-bar](https://github.com/williamliu0516/claude-status-bar) | ✓ | ✓ |
| `keyboard-display` | Claude Code sessions on a keyboard's 142×428 panel. From [context-keyboard-display](https://github.com/williamliu0516/context-keyboard-display); the hotkeys are macOS-only | ✓ | ✓ |
| `gnome-desktop` | Orchis theme, Tela icons, lighter top bar and dock, auto-hiding top bar, Super+Enter drop-down Ghostty | GNOME | |

Skip the menu:

```bash
bash install.sh --list                         # what this machine can install
bash install.sh --only terminal,claude-tmux    # dependencies are added for you
bash install.sh --all
```

Every module is safe to re-run: it skips what's already there and backs up anything it replaces.

---

## What you get

| | |
|---|---|
| **Terminal** | Ghostty — `snappy` theme (dark/light, follows the system), Maple Mono NF CN, cursor-trail shader (off — it keeps a core 18% busy while idle), semi-transparent with a frosted-glass blur of the real desktop (Ghostty's own blur on macOS, Blur my Shell on GNOME) |
| **Shell** | zsh + powerlevel10k, autosuggestions, fast-syntax-highlighting, history prefix search |
| **Multiplexer** | tmux — one menu key instead of a wall of shortcuts, sessions survive reboot |
| **Tools** | eza, bat, zoxide, fzf with fd and ripgrep, lazygit (`Alt+g`), btop (`Alt+b`), poppler for yazi's PDF preview, yazi (`y` in the shell drops you in the directory you quit from; `Alt+y` opens it in its own tmux window, since quitting from a popup stalls 5 s on yazi 26.x) |

### Shell

Right-arrow accepts the greyed-out suggestion; Tab completes as usual. Up-arrow filters history by what you've already typed. `Ctrl+R` fuzzy-searches all of it, with the full command previewed below. `Ctrl+T` picks a file (fd lists them: fast, follows `.gitignore`; `Ctrl+H` inside fzf toggles hidden files in) with a bat preview on the right; `Alt+C` outside tmux jumps to a directory. Tab itself opens fzf (fzf-tab): type a few letters to filter any completion — paths, git branches, ssh hosts, command options — with a preview of directories, files and branches; `/` while completing a path dives into the chosen directory.

A command that runs longer than 30 seconds sends a desktop notification when it finishes (with the exit code if it failed), but only if you're not looking at that terminal. Editors, pagers, ssh and other interactive programs are excluded. `bin/notify` is the helper; `notify --if-away title body` from any script gets the same behaviour.

yazi shows hidden files, sorts directories first, gives the preview pane the most room, and shows sizes in the list (`config/yazi/yazi.toml`).

On GNOME, `Ctrl+Enter` maximizes rather than going fullscreen: GNOME stops compositing what's behind a fullscreen window, which would kill the blur. With the auto-hiding top bar it looks the same.

On macOS, Option works as Alt, so the tmux keys below are the same on both. Ghostty's own Option+←/→ (word movement) is unbound so tmux gets them for window switching, as on Linux; outside tmux they still move by word. `Ctrl+←/→` is taken by Mission Control on macOS — turn off "Move left/right a space" in System Settings › Keyboard › Keyboard Shortcuts › Mission Control if you want it back in the shell.

On macOS, `Ctrl+Enter` (or `Cmd+Enter`) uses non-native fullscreen: the window fills the screen on the current Space instead of moving to a new one, so the blur of what's behind it survives. Native fullscreen would put it on an empty Space with nothing to blur. Native macOS tabs don't work in this mode; use tmux windows.

### tmux

You only need one key: **`Alt+m`** opens a menu with every action labelled; pressing it again closes the menu. **`Ctrl+b` `?`**, or **`Alt+/`** anywhere in the shell (inside tmux or not), shows a cheatsheet covering the shell keys, the tmux keys and what happens automatically; the tmux part is generated from the config itself, so it can't drift out of date.

What the menu holds (the letter in brackets picks the item directly):

| Group | Items |
|---|---|
| Panes | new pane `s` · zoom / unzoom `f` |
| Tools | Claude Code in a new window `C` · pick a Claude session to resume `r` · continue the last Claude session `c` · yazi `y` · lazygit `g` · btop `b` (each in its own window, closes when you quit) |
| Layout | make this the main pane `m` · auto-tiling on / off for this window `t` |
| Text | scroll back / copy mode `v` · search this pane `/` · paste `p` · clipboard history `P` · save pane output to a file `S` |
| Sessions `z` | detach `d` · switch session / open project `s` · new `n` · rename `r` · kill this session `X` · pick another session to kill `k` (only lists sessions nobody is attached to) · kill all others `K` |
| Close | kill pane `x` · kill window `X` |
| | cheatsheet `?` · close menu `Alt+m` |

Window management is deliberately not in the menu: `Alt+n` new window, `Alt+1`–`5` or `Alt+←/→` to switch, `Alt+;` back to the previous one, and tmux's own `Ctrl+b ,` to rename.

Direct keys worth knowing: `Alt+b` btop · `Alt+s` session / project switcher (fzf over open sessions and your project folders; picking a folder starts a session named after it; list your roots one per line in `~/.config/tmux/projects`, default `~/projects ~/code ~/src ~/dev ~/.dotfiles`) · `Alt+c` Claude Code here · `Alt+y` yazi · `Alt+g` lazygit · `Alt+h/j/k/l` panes · `Alt+Shift+←/→/↑/↓` resize the current pane, neighbours shrink to match · `Alt+←/→` windows · `Alt+f` zoom · `Alt+d` detach · `Ctrl+b K` pick a session to kill. On macOS, Alt is Option.

No Alt on your keyboard? Every `Alt+key` also works as `Ctrl+b` then the same key — the prefix table is mirrored from the Alt bindings at startup (`bin/tmux/alt-fallback.sh`), so it can't drift. Meant for iPad SSH clients, where iPadOS eats Option unless the app's "Option as Meta" switch is on (Termius: Profile › Settings › Keyboard; Moshi: keyboard settings). The mirror overrides a few tmux defaults in the prefix table: `n` is new window (not next), `;` previous window (not pane), `←/→` switch windows (not panes), `Space` new pane (not next layout), `x` kills without asking.

Panes tile themselves the way dwm does (idea borrowed from [ausbxuse's tmux config](https://github.com/ausbxuse/tmux)): one main pane on the left takes half the width, every other pane stacks top to bottom on the right, and the layout is redone whenever a pane opens or closes, however it was opened. `Alt+Space` opens a new pane at the bottom of the stack · `Alt+Enter` swaps the current pane with the main one (on the main pane, it swaps with the top of the stack) · `Alt+x` closes the pane · `Alt+t` turns tiling off for this window when you want a hand-made layout, and on again. Widen or narrow the main pane with `Alt+Shift+←/→` and later retiles keep that width.

Split a window and each pane gets a title bar — index, running command, path — with the active one in the accent colour. A single pane has no title bar, so it doesn't cost a row.

Window numbers are colour-coded by Claude Code state — cyan running, yellow needs approval, green done, red error. When any window is waiting on you, a yellow bell with the count appears at the left of the status bar, and a desktop notification fires when Claude is waiting, finished or failed, if you're not looking at that window (it's not the current tmux window, or Ghostty isn't the front app).

Sessions auto-save every 15 minutes and restore on start (tmux-resurrect + continuum).

The status bar shows CPU, memory in use and GPU load (amber above 70%, red above 90%; the GPU segment appears where it can be read — Apple Silicon, NVIDIA, AMD), then battery level with time to empty, or time to full while charging (`/sys` and upower on Linux, `pmset` on macOS). On a desktop with no battery the segment disappears entirely.

### GNOME desktop

Everything goes into your home directory — nothing under `/usr` is touched. Before changing anything the module dumps all of dconf to `~/desktop-backup-<timestamp>.dconf`; `dconf load / < that-file` puts it all back.

- **Orchis-Dark-Compact** shell and GTK theme, **Tela-circle-dark** icons.
- **Top bar and dock** a lighter translucent grey instead of near-black. The patch matches CSS selectors rather than line numbers and keeps `gnome-shell.css.orig`; reinstalling Orchis undoes it, re-running the module redoes it.
- **Dock:** upstream Dash to Dock replaces Ubuntu Dock, whose own stylesheet overrides the theme.
- **Hide Top Bar** in intellihide mode: the bar hides only when a window covers it, and slides back when the pointer touches the top edge.
- **Quake Terminal:** `Super+Enter` drops Ghostty down from the top; press again to put it away.
- **Blur my Shell** blurs only behind Ghostty; panel, dock and overview blur stay off to save power.

Log out and back in afterwards — GNOME on Wayland only discovers new extensions at login.

---

## Layout

```
install.sh           menu, then runs the chosen modules in order
lib/common.sh        shared helpers (output, link, apt/brew)
modules/<id>/install.sh
                     one per module; the header declares name, desc, os, needs
config/
  zsh/       zshrc, p10k.zsh
  tmux/      tmux.conf
  ghostty/   config.ghostty (shared), linux.ghostty / macos.ghostty (linked as platform.ghostty), themes/, shaders/
  gnome/     extensions.dconf — extension settings, merged with dconf load
bin/
  theme-preview        preview any Ghostty theme in the terminal, ranked by contrast
  tmux/cheatsheet.sh   the Ctrl+b ? popup
  tmux/claude-state.sh Claude Code hook → tmux window colour
  tmux/save-pane.sh    dump the current pane's scrollback to a file
  tmux/battery.sh      battery segment for the status bar
index.html           the page at xiaweiliu.com/dotfiles
```

To add a module, create `modules/<id>/install.sh` with the header comments; the menu picks it up. Add the id to `ORDER` in `install.sh` if it should sort before the others.

Everything is symlinked from `~/.dotfiles`, so edits in the repo are live. Existing files are backed up as `<name>.bak.<timestamp>` before being replaced.

## Testing on Ubuntu from a Mac

`dev/ubuntu.yaml` is a [Lima](https://lima-vm.io) definition for a headless Ubuntu 24.04 VM with `~/.dotfiles` mounted at the same path, read-write. Edit on the Mac, test in the VM, no pull needed.

```bash
brew install lima
limactl start --name ubuntu ~/.dotfiles/dev/ubuntu.yaml          # first time: downloads the image
limactl shell ubuntu -- env DOTFILES_DIR=/Users/$USER/.dotfiles bash /Users/$USER/.dotfiles/install.sh --only terminal,claude-tmux
limactl shell ubuntu                                             # then: tmux, Alt+m, Ctrl+b ?
limactl stop ubuntu                                              # limactl delete ubuntu to remove it
```

Open the shell from Ghostty on the Mac and the Alt keys travel through Ghostty into the VM's tmux, so the key bindings get a real test. What it can't test is GNOME itself — Blur my Shell, Ctrl+Enter maximize, the `gnome-desktop` module.

## Requirements

- **Linux:** Debian/Ubuntu with `apt` and `sudo`. Ghostty comes from [`mkasberg/ghostty-ubuntu`](https://github.com/mkasberg/ghostty-ubuntu); the installer picks the `.deb` matching your release and architecture, falling back to the newest build for your architecture.
- **macOS:** [Homebrew](https://brew.sh) and the Xcode command line tools (`xcode-select --install`). Ghostty and the font come from brew casks; zsh stays the system `/bin/zsh`.

## Options

```bash
DOTFILES_DIR=~/src/dotfiles  bash install.sh   # clone somewhere else
MAPLE_FONT_VERSION=v7.8      bash install.sh   # pin the font version
```

## Notes

`terminal` changes your login shell to zsh (`chsh`) on Linux. `claude-tmux` merges its hooks into `~/.claude/settings.json`, backing the file up first, and leaves it alone if they're already there. `claude-statusline` asks before replacing a local `statusline.py` that differs from the published one. Nothing outside `$HOME` is touched except the packages themselves.

`theme-preview` ranks every installed Ghostty theme by WCAG contrast and renders a real sample of each — useful when a theme looks nice but reads badly.
