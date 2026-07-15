# Repository review — `sh-ai-x/claude-statusline`

**Snapshot:** `origin/main` @ [`0890770`](https://github.com/sh-ai-x/claude-statusline/commit/0890770) (post PR #9 — ci-setup refresh to dev-kit 0.3.34).
**Date:** 2026-07-16.
**Scope:** code, docs, CI, hooks, security, observability. Not a performance review.

**Validity:** This doc is a **regenerable advisory snapshot** anchored to commit `0890770`. It is NOT a permanent architectural record. When the repo state changes meaningfully (new merge to `main`, dev-kit upgrade, workflow shape change), regenerate this doc from the new tip. Do NOT patch findings in place — findings are a point-in-time audit and go stale fast. The durable parts of the repo's architectural intent are captured by `README.md`, `.claude/rules/git-workflow.md`, and the workflow files themselves, NOT by this doc.

---

## 1. What this repo is

A 124-line bash script + 30-line installer that formats Claude Code's status JSON
(`stdin`) into a two-line colored ANSI display, plus the surrounding dev-kit CI
infrastructure (3 workflows, 5 hooks, branch-policy enforcement, pre-push block).

The product surface is intentionally tiny:

```
claude code session (stdin JSON)
        ↓
statusline-command.sh   (pure bash, jq only)
        ↓
2-line ANSI escape string → terminal statusline
```

There is no library, no daemon, no plugin runtime. Everything is a single shell
script invoked by Claude Code on every render tick.

---

## 2. File map

| Path | Lines | Role |
|---|---:|---|
| `statusline-command.sh` | 124 | **The product.** Reads stdin JSON, builds 2 ANSI lines. |
| `install.sh` | 30 | Copies script to `~/.claude/`, patches `settings.json` with `statusLine`. |
| `README.md` | 114 | Install, format reference, segment table, dev workflow. |
| `.github/workflows/ci.yml` | — | branch-policy warn + validate + test on PRs. |
| `.github/workflows/review.yml` | — | `/dev-kit:review` (3-dim) + `/dev-kit:security` (10-dim) + severity gate. |
| `.github/workflows/auto-fix-pr.yml` | — | Self-loop LLM auto-fix on `changes_requested`. |
| `.github/ci-review-provider.txt` | 1 | One-key config file (`CI_REVIEW_PROVIDER=deepseek`). **Dead config — not referenced anywhere** in `.github/`, `scripts/`, or `hooks/`. `review.yml` defines its own `review_provider` workflow_dispatch input with a `minimax` default. Likely a leftover from PR #8's deepseek-integration exploration that was never wired. |
| `.githooks/pre-push` | — | **Hard** block: refuses `git push` to `main`. |
| `hooks/worktree-guard.sh` | — | PreToolUse block on Edit/Write when cwd is main checkout. |
| `hooks/task-detector.sh` | — | UserPromptSubmit nudge for new tasks in main checkout. |
| `hooks/session-start-check.sh` | — | SessionStart reminder when started in main checkout. |
| `scripts/validate.py` | — | 5-step install validator (extract from `ci.yml`). |
| `scripts/test.sh` | — | Pytest wrapper; skips if no `tests/`. |
| `scripts/ci-local.sh` | — | Local entrypoint = `validate.py` + `test.sh` + `act -l`. |
| `tests/test_worktree_guard.py` | — | 32 regression tests for the 4 dev-kit rule hooks. |

---

## 3. Strengths

1. **No runtime deps beyond `jq` + `git`.** Zero npm/pip/apt required.
2. **Three rendering modes handled gracefully** — main checkout, worktree, non-repo.
3. **All input fields are optional.** `jq -r '.field // default'` pattern means a
   missing `rate_limits`, `effort`, `session_id` simply renders an empty segment.
4. **CI shape is canonical.** Branch-policy warn-only on direct push, hard-block
   via pre-push locally, validate + test on every PR, 3-dim review + 10-dim
   security + severity gate on every PR, auto-fix loop with 5-iter cap.
5. **Worktree discipline enforced three ways:** worktree-guard hook (PreToolUse),
   pre-push hook (blocks push to main), branch-policy CI job (warn annotation).
6. **README is concrete.** Shows actual rendered output for each mode, not
   abstract descriptions.
7. **No secrets in the repo.** Verified — no `.env`, no token strings, no API
   keys. `DEV_KIT_GITHUB_TOKEN` / `MINIMAX_API_KEY` are GitHub-side secrets only.

---

## 4. Findings

### HIGH — Tests cover dev-kit hooks, not the statusline script

The only test file is `tests/test_worktree_guard.py` — 32 tests for the 4 rule
hooks. **`statusline-command.sh` has zero test coverage.** The script is a pure
function of stdin JSON, so it is trivially testable: feed it a fixture, diff
the rendered output. Currently any change to color codes, segment ordering, or
field fallbacks relies on eyeballing the terminal.

Suggested fixture matrix:
- Empty stdin → graceful empty bar / 0%
- Missing `rate_limits`, missing `effort`, missing `session_id`
- `cwd` outside any git repo
- `cwd` in a worktree (verify `[project][worktree]` rendering)
- `cwd` with dirty working tree (verify yellow ✗)
- Context at 90%+ (verify red bar)

### MEDIUM — `install.sh` does not check `jq` is installed before wiring

`README.md` states `jq` is required, but `install.sh` never verifies it. A user
running `bash install.sh` on a fresh machine gets the script copied and
`settings.json` patched, then sees a render failure on first CC launch. Add a
one-line guard at the top:

```bash
command -v jq >/dev/null || { echo "jq required — brew install jq / apt install jq"; exit 1; }
```

### MEDIUM — `git_dirty` only inspects the first line of `git status --porcelain`

[`statusline-command.sh:61`](https://github.com/sh-ai-x/claude-statusline/blob/0890770/statusline-command.sh#L61) uses `head -1` to detect dirty state, so a 5-file
dirty tree shows the same yellow ✗ as a 1-file tree. Either show the count
(`✗5`) or drop the count and keep the boolean — current behavior is misleading
because it suggests "at least one dirty file" but reads like "the first dirty
file."

### MEDIUM — Color codes are hardcoded literals scattered through the script

`statusline-command.sh` has **15** `\033[…m` literals inline (`grep -oE '\\033\[[0-9;]*m' statusline-command.sh | wc -l` → `15`). Adding a dark-mode
override or per-host color theming requires touching the script. Worth
extracting to a small associative array at the top:

```bash
declare -A C=(
  [green]=$'\033[1;32m' [cyan]=$'\033[0;36m' ...
)
```

Low impact today, but the codebase will grow and inline ANSI is hostile to
maintain.

### LOW — `install.sh` settings.json patch uses shell expansion inside a python heredoc

```bash
python3 -c "
import json
with open('$SETTINGS') as f: s = json.load(f)
s['statusLine'] = {'type': 'command', 'command': 'bash $CLAUDE_DIR/statusline-command.sh'}
...
"
```

Works today because the heredoc is double-quoted so bash expands `$CLAUDE_DIR`
before python sees it. But this is fragile — anyone switching the heredoc to
single quotes (a python idiom) silently breaks the install. Worth a comment on
the line, or rewrite the patch as a separate python file in `scripts/`.

### LOW — No version field anywhere in the repo

There is no `VERSION`, no git tag, no changelog, no release section in README.
Users running `git clone … && bash install.sh` get whatever is on `main`
right now, with no reproducibility surface. Add:

```bash
# statusline-command.sh:2
# claude-statusline v0.1.0 — see https://github.com/sh-ai-x/claude-statusline/releases
```

…plus a `CHANGELOG.md` and a tag-on-merge habit (or rely on the auto-bump
workflow if you wire one).

### LOW — README install command pulls latest, no SHA pin

```bash
git clone https://github.com/sh-ai-x/claude-statusline
```

No tag, no `--branch`, no `--depth 1` for reproducible installs. For a single
user this is fine; for a team that wants every machine on the same version,
add a tag-based install path:

```bash
git clone --branch v0.1.0 --depth 1 https://github.com/sh-ai-x/claude-statusline
```

### LOW — `review.yml` uses `pull_request`, not `pull_request_target`

Intentional (per comment in the workflow: OIDC token exchange doesn't work on
`pull_request_target` for consumer repos without org-level OIDC trust).
Trade-off documented in the file. **Not a finding** — flagging only because
the workflow file's behavior depends on this and a future editor might
"improve" it without realizing why it was chosen.

### LOW — `.github/ci-review-provider.txt` is a one-key config file in `.github/`

Unusual placement — `.github/` is normally for workflows + CODEOWNERS +
templates, not runtime config. Reads cleanly today but if more provider
switches show up (model name, max-iter cap, …), consider moving to
`.github/review-config.env` or inlining into `review.yml`'s `env:` block.

**Verification (2026-07-16):** `grep -rn "ci-review-provider\|review_provider\|REVIEW_PROVIDER" .` returns only `review.yml` lines that reference the
**separate** `workflow_dispatch` input variable named `review_provider`. The
`.txt` file itself is unreferenced. Two valid resolutions: (a) delete the
file, or (b) wire it as a `pull_request`-time provider override (would
require a workflow file change to source it).

### INFO — `effort` color map has a duplicate

`statusline-command.sh:40-41` maps both `high` and `xhigh` to `\033[1;33m`
(yellow). Intentional? Reads as "high = max-ish" visually. Worth a comment
if intentional; pick a different shade if not.

### INFO — `head -1` on `git status --porcelain` is the dirty signal but counts as a number elsewhere

Cross-reference: see MEDIUM finding above. The behavior is "any-dirty" not
"count" — document that explicitly in a code comment to prevent future
"fixes" from changing semantics.

---

## 5. Security posture

| Area | Status |
|---|---|
| Secrets in repo | ✅ None found. |
| Workflow permissions | ⚠️ `review.yml` and `auto-fix-pr.yml` declare explicit `permissions:` overrides — `contents: read`, `pull-requests: write`, `issues: write`, `id-token: write` (review.yml jobs) and similar (auto-fix-pr.yml). This is **required** for the LLM-review OIDC token exchange and for posting PR comments. `ci.yml` uses defaults. Not a vulnerability — minimum-privilege is correctly scoped — but the table previously misclaimed "no overrides". |
| OIDC / token exchange | ⚠️ `review.yml` uses `pull_request` because OIDC doesn't federate on `pull_request_target` for consumer repos. Documented in workflow. |
| `actions/checkout` pin | ⚠️ Pinned to `@v4` — fine for now, but `@v4` is on a deprecation path. Recommend tracking `@v5` when it stabilizes for this repo. |
| Auto-fix loop | ✅ 5-iteration cap. Skips reviews from `claude[bot]` / `github-actions`. Skips fork PRs (no secret exposure). |
| Branch policy | ✅ Hard block via pre-push; warn-only via CI annotation. **Caveat:** the GitHub-side `branch-protection` rules are not visible from inside the repo — verify on the repo settings page that PR review is required to merge to `main`. |

---

## 6. Observability / debuggability

The statusline is a black box from the user's perspective:

- No `--debug` mode that dumps the parsed JSON fields to stderr.
- No `CLAUDE_STATUSLINE_DRY_RUN=1` env var to print JSON without ANSI codes.
- No log file or journal.

Adding a one-line dry-run mode is a 10-minute change and would cut
troubleshooting time substantially when users paste statusline screenshots
asking "why is X wrong":

```bash
if [ "${CLAUDE_STATUSLINE_DRY_RUN:-0}" = "1" ]; then
  echo "$input" | jq . >&2
fi
```

---

## 7. Recommendations — prioritized

1. **(HIGH)** Add `tests/test_statusline.sh` (bash + golden-output fixtures)
   covering the 6 cases in §4 HIGH.
2. **(MEDIUM)** Add `jq` presence check to `install.sh`.
3. **(MEDIUM)** Decide `git_dirty` semantics — boolean or count — and document.
4. **(MEDIUM)** Extract ANSI color codes to a named array at the top of the
   statusline script.
5. **(LOW)** Add a `VERSION` line + `CHANGELOG.md` + tag-on-merge.
6. **(LOW)** Add `--depth 1 --branch vX.Y.Z` install snippet to README.
7. **(INFO)** Add a one-line `CLAUDE_STATUSLINE_DRY_RUN=1` debug mode.
8. **(META)** Per the Validity line at top — when a meaningful change lands
   on `main` (new merge, dev-kit upgrade, workflow shape change), **regenerate**
   this doc from the new tip via a fresh `chore/repo-analysis` worktree.
   Do not patch findings in place. Treat this file as a point-in-time audit
   artifact, not a maintained design document.

---

## 8. What I would NOT change

- The CI shape. It is canonical for a dev-kit consumer and should not be
  re-imagined.
- The pre-push + worktree-guard + branch-policy stack. Triple-redundant branch
  protection is the right call for a repo where main is sacred.
- The single-script product surface. Splitting `statusline-command.sh` into a
  multi-file module would be net-negative — it would add a build step to a
  tool whose value is "no build step."
- The README segment table. Concrete > abstract for this kind of CLI tool.