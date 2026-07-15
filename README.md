# claude-statusline

Custom Claude Code statusline script. Displays GitHub account, model, project / worktree name, git branch, context usage bar, elapsed time, rate limits, language mode indicator, and reasoning effort, across two lines.

## Statusline format

Main checkout:
```
@sh-ai-x [Sonnet 4.6] [my-project] ▓▓▓░░░░░░░ 30%
⏱ 2m 14s |  git:(main) | en:off effort:high
```

Inside a git worktree (`my-project` is the project, `feat-x` is the worktree):
```
@sh-ai-x [Sonnet 4.6] [my-project][feat-x] ▓▓▓░░░░░░░ 30%
⏱ 2m 14s |  git:(feat-x) | en:off effort:high
```

Outside any git repo:
```
@sh-ai-x [Sonnet 4.6] tmp ▓▓▓░░░░░░░ 30%
⏱ 2m 14s |  en:off effort:high
```

| Segment | Description |
|---|---|
| `@user` | Active `gh` CLI account, read from `~/.config/gh/hosts.yml` (bright white) |
| `[Model]` | Active Claude model (magenta) |
| `[project]` or `[project][worktree]` | Project name (git repo basename); `[project][worktree]` inside a worktree, plain dir name when not in a git repo (cyan) |
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
