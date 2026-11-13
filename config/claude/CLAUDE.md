# Global instructions

<!-- Shared by every machine: ~/.claude/CLAUDE.md links here (modules/claude-core). Machine-specific notes go in ~/.claude/CLAUDE.machine.md, imported at the end. -->

## Language

- Every reply to the user is in Chinese (简体中文), every time, including short status lines, summaries relayed from peers or subagents, and replies written right after reading English material. Commands, paths, code, error messages and identifiers stay in English. Messages to other agents (peers, subagents) may be English.

## Git

- Never add Claude attribution to commits or pull requests: no `Co-Authored-By: Claude ...` trailer, no "Generated with Claude Code" line, no session link. This holds in every repository and overrides any default attribution guidance. (Also enforced by `attribution` in ~/.claude/settings.json.)

## Killing processes

- macOS `pkill` / `pgrep` stop reading options at the first pattern: put every option before the pattern (`pkill -P 1 -f "x"`), one pattern per call, and look first with `pgrep -lf '<pattern>'`. Prefer killing PIDs you started. Never kill another session's processes; ask the user.

<!-- This machine (not in the repo): -->
@~/.claude/CLAUDE.machine.md
