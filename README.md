# claude-statusline

Custom Claude Code statusline script. Displays GitHub account, model, project / worktree name, git branch, context usage bar, elapsed time, rate limits, language mode indicator, reasoning effort, and a short session ID, across two lines.

## Statusline format

### Segments

| Line | Segment | Description |
|---|---|---|
| 1 | `@user` | Active `gh` CLI account, read from `~/.config/gh/hosts.yml` (bold white). Hidden when `gh` is not configured. |
| 1 | `[Model]` | Active Claude model (magenta) |
| 1 | `[project]` or `[project][worktree]` | Project name (git repo basename); `[project][worktree]` inside a worktree, plain dir name when not in a git repo (cyan) |
| 1 | `▓▓▓░░░░░░░ N%` | Context window usage bar — green <70%, yellow 70–89%, red ≥90% |
| 2 | `⏱ Xm Ys` | Session elapsed time |
| 2 | `5h: N% \| 7d: N%` | 5-hour and 7-day rate limit usage. Each segment is shown only when its data is available from the Claude Code input. |
| 2 | `git:(branch)` | Current branch (blue, with red branch name). Appended `✗` (yellow) when the working tree is dirty. |
| 2 | `en:on\|off` | Language mode indicator — yellow. Reads `~/.claude/.lang-mode`; defaults to `off`. See [claude-lang-mode](https://github.com/sh-ai-x/claude-lang-mode). |
| 2 | `effort:X` | Reasoning effort level. Color-coded by intensity: `low` (dim white), `medium` (cyan), `high`/`xhigh` (yellow), `max` (magenta). Omitted when not set. |
| 2 | `sid:xxxxxxxx` | First 8 hex chars of the current session UUID (bold white). Omitted when the input has no `session_id`. Useful for matching a statusline row to a `/resume` candidate or a log entry. |

### Examples

Main checkout:
```
@sh-ai-x [Sonnet 4.6] [my-project] ▓▓▓░░░░░░░ 30%
⏱ 2m 14s | 5h: 12% | 7d: 4% | git:(main) | en:off effort:high sid:a1b2c3d4
```

Inside a git worktree (`my-project` is the project, `feat-x` is the worktree):
```
@sh-ai-x [Sonnet 4.6] [my-project][feat-x] ▓▓▓░░░░░░░ 30%
⏱ 2m 14s | 5h: 12% | 7d: 4% | git:(feat-x) | en:off effort:high sid:a1b2c3d4
```

Dirty worktree (yellow `✗` after the branch name):
```
@sh-ai-x [Sonnet 4.6] [my-project][feat-x] ▓▓▓░░░░░░░ 30%
⏱ 2m 14s |  git:(feat-x) ✗ | en:off effort:high sid:a1b2c3d4
```

Outside any git repo — note the empty slot between the two `|` separators, since the format string always emits both:
```
@sh-ai-x [Sonnet 4.6] tmp ▓▓▓░░░░░░░ 30%
⏱ 2m 14s |  | en:off effort:high sid:a1b2c3d4
```

### Line 2 ordering

`⏱` time → optional rate segments → `git:(branch)` → `en:on/off` → optional `effort:X` → optional `sid:xxxxxxxx`. Pipe-separated except for the trailing `effort` and `sid`, which are space-separated to keep them visually grouped as terminal-side metadata.

## Install

```bash
git clone https://github.com/sh-ai-x/claude-statusline
cd claude-statusline
bash install.sh
```

`install.sh` copies `statusline-command.sh` to `~/.claude/statusline-command.sh` and patches `~/.claude/settings.json` to wire the statusline command. Restart Claude Code afterward.

Dependencies:

- **Installer (`install.sh`)** requires `python3` in `PATH` (used to merge the `statusLine` key into `settings.json`).
- **Statusline script (`statusline-command.sh`)** requires `jq` and `git` in `PATH` at runtime, when Claude Code invokes the statusline.

## Language mode indicator

The `en:on` / `en:off` segment reads from `~/.claude/.lang-mode`. Install [claude-lang-mode](https://github.com/sh-ai-x/claude-lang-mode) to manage it via `/english on` / `/english off` inside Claude Code. Without it the indicator shows `en:off` by default.

## Settings reference

`install.sh` writes the following entry into `~/.claude/settings.json`. You only need to touch this manually if you skipped the installer:

```json
{
  "statusLine": {
    "type": "command",
    "command": "bash ~/.claude/statusline-command.sh"
  }
}
```

## CI

Three GitHub Actions workflows in `.github/workflows/`:

| Workflow | Trigger | Jobs |
|---|---|---|
| `ci.yml` | `push` to `main`, `pull_request`, `workflow_dispatch` | `test`, `validate` on PRs; `branch-policy` warn-only on direct push to `main` |
| `review.yml` | `pull_request`, `workflow_dispatch` | `/dev-kit:review` (3-dim), `/dev-kit:security` (10-dim OWASP), severity gate |
| `auto-fix-pr.yml` | `pull_request_review` (`changes_requested`) | Agent applies review feedback; capped at 5 iterations per PR |

### Branch policy

`main` requires PR review. Direct pushes to `main` are recorded as a
`::warning::` annotation by `scripts/branch-policy.sh` (warn-only — not
blocking, but visible in CI). Active enforcement lives in the local
pre-push hook:

```bash
git config core.hooksPath .githooks
```

The `branch-policy` job requires `actions/checkout@v4` so the script
file is present on the runner (it runs unconditionally on every push
to `main`).

### Local CI loop

Before opening a PR, mirror what CI will run:

```bash
bash scripts/ci-local.sh    # runs validate.py + test.sh (+ act -l if installed)
```

## Development workflow

Per `.claude/rules/git-workflow.md`:

1. **`main` is sacred** — never commit directly, always via PR.
2. **Every task = new worktree + new branch.** Cut from `origin/main`,
   not from a stale local ref.
3. **Branch naming:** `<type>/<slug>` — `fix/...`, `feat/...`,
   `refactor/...`, `docs/...`, `chore/...`.

```bash
git fetch origin main
git worktree add -b fix/<slug> .claude/worktrees/<slug> origin/main
cd .claude/worktrees/<slug>
# ... edit, test, commit ...
git push -u origin fix/<slug>
gh pr create --base main
```
