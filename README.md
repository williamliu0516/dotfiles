# dotfiles

Terminal setup: **Ghostty + tmux + zsh**. One command on a fresh machine.

```bash
curl -fsSL https://xiaweiliu.com/dotfiles/install.sh | bash
```

Installs Ghostty itself if it isn't already there. Same script straight from GitHub, if the site is ever down:

```bash
curl -fsSL https://raw.githubusercontent.com/williamliu0516/dotfiles/main/install.sh | bash
```

---

## What you get

| | |
|---|---|
| **Terminal** | Ghostty — `snappy` theme (dark/light, follows the system), Maple Mono NF CN, cursor-trail shader, semi-transparent with a dimmed background image |
| **Shell** | zsh + powerlevel10k, autosuggestions, fast-syntax-highlighting, history prefix search |
| **Multiplexer** | tmux — one menu key instead of a wall of shortcuts, sessions survive reboot |
| **Tools** | eza, bat, zoxide, fzf |

### Shell

Tab accepts the greyed-out suggestion when there is one, and completes normally when there isn't. Up-arrow filters history by what you've already typed. `Ctrl+R` fuzzy-searches all of it.

### tmux

You only need one key: **`Alt+m`** opens a menu with every action labelled — splits, windows, sessions, search, save output. **`Ctrl+b` `?`** shows a cheatsheet generated from the config itself, so it can't drift out of date.

Direct keys worth knowing: `Alt+h/j/k/l` panes · `Alt+←/→` windows · `Alt+f` zoom · `Alt+d` detach.

Split a window and each pane gets a title bar — index, running command, path — with the active one in the accent colour. A single pane has no title bar, so it doesn't cost a row.

Window numbers are colour-coded by Claude Code state — cyan running, yellow needs approval, green done, red error.

Sessions auto-save every 15 minutes and restore on start (tmux-resurrect + continuum).

The status bar shows battery level with time to empty, or time to full while charging. On a desktop with no battery the segment disappears entirely.

---

## Layout

```
config/
  zsh/       zshrc, p10k.zsh
  tmux/      tmux.conf
  ghostty/   config.ghostty, themes/, shaders/
bin/
  theme-preview        preview any Ghostty theme in the terminal, ranked by contrast
  tmux/cheatsheet.sh   the Ctrl+b ? popup
  tmux/claude-state.sh Claude Code hook → tmux window colour
  tmux/save-pane.sh    dump the current pane's scrollback to a file
  tmux/battery.sh      battery segment for the status bar
install.sh
index.html           the page at xiaweiliu.com/dotfiles
```

Everything is symlinked from `~/.dotfiles`, so edits in the repo are live. Existing files are backed up as `<name>.bak.<timestamp>` before being replaced.

## Requirements

Debian/Ubuntu with `apt` and `sudo`. Ghostty comes from [`mkasberg/ghostty-ubuntu`](https://github.com/mkasberg/ghostty-ubuntu); the installer picks the `.deb` matching your release and architecture, falling back to the newest build for your architecture.

## Options

```bash
DOTFILES_DIR=~/src/dotfiles  bash install.sh   # clone somewhere else
MAPLE_FONT_VERSION=v7.8      bash install.sh   # pin the font version
```

## Notes

The installer changes your login shell to zsh (`chsh`) and merges the Claude Code hooks into `~/.claude/settings.json` only if that directory already exists, backing the file up first. Nothing else outside `$HOME` is touched.

`theme-preview` ranks every installed Ghostty theme by WCAG contrast and renders a real sample of each — useful when a theme looks nice but reads badly.
