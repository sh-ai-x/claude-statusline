# claude-statusline

Custom Claude Code statusline script. Displays model, working directory, git branch, context usage bar, elapsed time, rate limits, and language mode indicator.

## Statusline format

```
[Sonnet 4.6] my-project git:(main) ▓▓▓░░░░░░░ 30% | ⏱ 2m 14s | en:off
```

| Segment | Description |
|---|---|
| `[Model]` | Active Claude model (magenta) |
| `dir` | Current working directory basename (cyan) |
| `git:(branch)` | Git branch; red branch name, yellow `✗` if dirty |
| `▓▓▓░░░░░░░ N%` | Context window usage bar (green/yellow/red) |
| `⏱ Xm Ys` | Session elapsed time |
| `5h: N% \| 7d: N%` | Rate limit usage (when available) |
| `en:on\|off` | Language mode indicator — yellow (requires [claude-lang-mode](https://github.com/sh-ai-x/claude-lang-mode)) |

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
