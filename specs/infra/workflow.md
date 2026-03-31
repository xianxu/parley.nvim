# AI Workflow

## Issue-Based Development
Work is tracked via single-file-per-issue markdown in `issues/`. Two modes:
- **On main**: `make fetch` → work → `make push` (auto-commit, close GH issues, archive)
- **On branch**: `make issue` → work in worktree → `make pull-request` → `make merge`

Completed issues are moved to `history/` upon archival. These are considered low-signal history and should generally be avoided by agent workflows to preserve context efficiency.

Worktrees created under `../worktree/` for portability between local and openshell environments.

## Pre-Merge Checks
Agent-driven verification steps run before `push` and `merge`. Each check invokes a coding agent (configurable via `AGENT_CMD`; supports `claude`, `codex`, `gemini`) with a focused prompt, then detects repo changes for user accept/discard. If any check reports violations, the runner stops and prompts the user before proceeding (interactive) or exits non-zero (non-interactive).

### Checks
| Target          | What it does                                             |
|-----------------|----------------------------------------------------------|
| `check-dry`     | Report DRY violations in diff (read-only)                |
| `check-pure`    | Report pure/impure separation issues (read-only)         |
| `check-plan`    | Verify issue plans complete, steps checked, logs written  |
| `check-test`    | Run `test` + `test-agents` + `lint`, feed to agent       |
| `check-specs`   | Compare code changes to specs/ and README.md, update     |
| `check-lessons` | Reminder to review tasks/lessons.md (no agent)           |

### Usage
```bash
make pre-merge                          # interactive sequential (accept/discard per check)
make c                                  # audit mode (all parallel, report-only)
make check-dry                          # single check (interactive)
PRE_MERGE_CHECKS=yynnyn make pre-merge  # preset (y=run, n=skip)
PRE_MERGE_CHECKS=none make push         # push skipping all checks
```

### Parallel Execution
`make pre-merge` uses `scripts/parallel-checks.sh`. In audit mode (`--audit`), checks run in parallel with a concurrency limit (default 3, configurable via `MAX_PARALLEL_CHECKS`) as read-only agents (except `specs` which gets write tools). In interactive mode (no flags), it delegates to `pre-merge-checks.sh` for sequential accept/discard flow.

### No-Commit Mode
`CHECK_NO_COMMIT=1` runs checks in audit-only mode: violations are reported to stdout, agent changes are discarded. Used by hooks and `--no-commit` flag.

### Agent CLI Tests
`make test-agents` (or `tests/test_agents.sh`) validates assumptions about agent CLI tools — flag combos, stream-json event schema, jq extraction patterns, and output classification helpers. Requires `claude` CLI; `codex`/`gemini` tests skipped if not installed.

### Output Formatting
Each check prints a consistent three-tier result: green `✓` for clean, yellow `ℹ` for informational (e.g. reminders), red `✗` for violations. Detection uses known-good patterns in `is_clean_check_output` and `is_info_check_output`. Empty output is treated as a failure (silent agent crash). Helpers live in `scripts/lib.sh`.

### Change Detection
After each agent check (interactive mode), repo state is diffed. If files changed:
- User sees `git diff --stat`
- Accept → changes staged
- Discard → `git checkout/clean`

## Constitution Hook
`PostToolUse` hooks on both `Write` and `Edit` in `.claude/settings.json` trigger constitution checks automatically during coding sessions. A filesystem lock prevents concurrent runs. Findings are injected into the agent's context via stderr.

In hook mode (`CHECK_MODE=hook`), the test check runs the lighter `make test-changed` + `make lint` instead of the full suite to keep the feedback loop fast.

## COMPARE-SHA
A `COMPARE-SHA` file in the repo root overrides the git diff base ref used by all check scripts and `test-changed`. This is useful for testing hook/check behavior with a wider diff than the default (origin/main or merge-base). The file is gitignored.

```bash
echo "abc1234" > COMPARE-SHA   # override diff base
rm COMPARE-SHA                  # revert to default
```

## History
- 2026-03-29: Multi-agent support (codex, gemini), failure-stops-merge, info output tier (issue 000029)
- 2026-03-29: Consistent pass/fail formatting for check output (issue 000026)
- 2026-03-29: Concurrency-limited parallel checks (issue 000021)
- 2026-03-29: Parallel checks with hook-gated constitution enforcement (issue 000018)
- 2026-03-29: Progress display for headless agent calls (issue 000017)
- 2026-03-29: Pre-merge checks (issue 000015)
- 2026-03-29: Worktree portability for openshell (issue 000014)
