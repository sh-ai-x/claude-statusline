# claude-statusline

Custom Claude Code statusline script. Displays GitHub account, model, project / worktree name, git branch, context usage bar, elapsed time, rate limits, language mode indicator, and reasoning effort, across two lines.

## Statusline format

Main checkout:
```
@sh-ai-x [Sonnet 4.6] my-project git:(main) ▓▓▓░░░░░░░ 30%
⏱ 2m 14s | en:off effort:high
```

Inside a git worktree (`my-project` is the project, `feat-x` is the worktree):
```
@sh-ai-x [Sonnet 4.6] my-project/feat-x git:(feat-x) ▓▓▓░░░░░░░ 30%
⏱ 2m 14s | en:off effort:high
```

| Segment | Description |
|---|---|
| `@user` | Active `gh` CLI account, read from `~/.config/gh/hosts.yml` (bright white) |
| `[Model]` | Active Claude model (magenta) |
| `loc` | Project name (git repo basename); suffixed with `/<worktree>` when inside a worktree, plain dir name when not in a git repo (cyan) |
| `git:(branch)` | Git branch; red branch name, yellow `✗` if dirty |
| `▓▓▓░░░░░░░ N%` | Context window usage bar (green/yellow/red) |
| `⏱ Xm Ys` | Session elapsed time |
| `5h: N% \| 7d: N%` | Rate limit usage (when available) |
| `en:on\|off` | Language mode indicator — yellow (requires [claude-lang-mode](https://github.com/sh-ai-x/claude-lang-mode)) |
| `effort:X` | Reasoning effort level (when set) |

## Install

```bash
git clone https://github.com/sh-ai-x/claude-statusline
cd claude-statusline
bash install.sh
```

Requires `jq` and `git` in PATH.

## Language mode indicator

The `en:on` / `en:off` segment reads from `~/.claude/.lang-mode`. Install [claude-lang-mode](https://github.com/sh-ai-x/claude-lang-mode) to manage it via `/english on` / `/english off` inside Claude Code. Without it the indicator shows `en:off` by default.

## Settings reference

`~/.claude/settings.json`:

```json
{
  "statusLine": {
    "type": "command",
    "command": "bash ~/.claude/statusline-command.sh"
  }
}
```
