# AI Workflow

## Issue-Based Development
Work is tracked via single-file-per-issue markdown in `issues/`. Two modes:
- **On main**: `make fetch` → work → `make push` (auto-commit, close GH issues, archive)
- **On branch**: `make issue` → work in worktree → `make pull-request` → `make merge`

Worktrees created under `../worktree/` for portability between local and openshell environments.

## Pre-Merge Checks
Agent-driven verification steps run before `push` and `merge`. Each check invokes a coding agent (`claude -p` by default, configurable via `AGENT_CMD`) with a focused prompt, then detects repo changes for user accept/discard.

### Checks
| Target          | What it does                                             |
|-----------------|----------------------------------------------------------|
| `check-dry`     | Report DRY violations in diff (read-only)                |
| `check-pure`    | Report pure/impure separation issues (read-only)         |
| `check-plan`    | Verify issue plans complete, steps checked, logs written  |
| `check-test`    | Run `make test`, feed output to agent for analysis       |
| `check-specs`   | Compare code changes to specs/ and README.md, update     |
| `check-lessons` | Reminder to review tasks/lessons.md (no agent)           |

### Usage
```bash
make pre-merge                          # parallel runner (interactive accept/discard)
make c                                  # audit mode (all parallel, report-only)
make check-dry                          # single check (interactive)
PRE_MERGE_CHECKS=yynnyn make pre-merge  # preset (y=run, n=skip)
PRE_MERGE_CHECKS=none make push         # push skipping all checks
```

### Parallel Execution
`make pre-merge` uses `scripts/parallel-checks.sh`. In audit mode (`--audit`), checks run in parallel with a concurrency limit (default 3, configurable via `MAX_PARALLEL_CHECKS`) as read-only agents (except `specs` which gets write tools). In interactive mode (no flags), it delegates to `pre-merge-checks.sh` for sequential accept/discard flow.

### No-Commit Mode
`CHECK_NO_COMMIT=1` runs checks in audit-only mode: violations are reported to stdout, agent changes are discarded. Used by hooks and `--no-commit` flag.

### Output Coloring
Check output containing violations is printed in red; clean output (matching known-good patterns like "No DRY violations found", "All tests pass", etc.) is printed normally. Helpers `is_clean_check_output` and `print_check_output` live in `scripts/lib.sh`.

### Change Detection
After each agent check (interactive mode), repo state is diffed. If files changed:
- User sees `git diff --stat`
- Accept → changes staged
- Discard → `git checkout/clean`

## Constitution Hook
A `PostToolUse:Write` hook in `.claude/settings.json` triggers batch constitution checks automatically during coding sessions when the diff crosses a threshold (400 lines or 10 files changed). Uses a 50% growth gate to avoid re-firing on every write. Findings are injected into the agent's context via stdout (silent-unless-violated).

## History
- 2026-03-29: Red-colored output for check violations (issue 000026)
- 2026-03-29: Concurrency-limited parallel checks (issue 000021)
- 2026-03-29: Parallel checks with hook-gated constitution enforcement (issue 000018)
- 2026-03-29: Progress display for headless agent calls (issue 000017)
- 2026-03-29: Pre-merge checks (issue 000015)
- 2026-03-29: Worktree portability for openshell (issue 000014)
