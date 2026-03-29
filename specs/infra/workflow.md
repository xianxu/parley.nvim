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
| `check-dry`     | Review diff for DRY violations, refactor if found        |
| `check-pure`    | Review for pure/impure separation                        |
| `check-plan`    | Verify issue plans complete, steps checked, logs written  |
| `check-test`    | Run `make test`, feed output to agent for analysis       |
| `check-specs`   | Compare code changes to specs/ and README.md             |
| `check-lessons` | Review session for patterns worth capturing              |

### Usage
```bash
make pre-merge                          # parallel runner (interactive accept/discard)
make check-dry                          # single check (interactive)
PRE_MERGE_CHECKS=yynnyn make pre-merge  # preset (y=run, n=skip)
PRE_MERGE_CHECKS=none make push         # push skipping all checks
```

### Parallel Execution
`make pre-merge` uses `scripts/parallel-checks.sh` which runs checks in groups:
1. `dry` + `pure` (parallel)
2. `test`
3. `specs`
4. `plan`
5. `lessons`

Groups run sequentially; checks within a group run in parallel.

### No-Commit Mode
`CHECK_NO_COMMIT=1` runs checks in audit-only mode: violations are reported to stdout, agent changes are discarded. Used by hooks and `--no-commit` flag.

### Change Detection
After each agent check (interactive mode), repo state is diffed. If files changed:
- User sees `git diff --stat`
- Accept → changes staged
- Discard → `git checkout/clean`

## Constitution Hook
A `PostToolUse:Write` hook in `.claude/settings.json` triggers batch constitution checks automatically during coding sessions when the diff crosses a threshold (500 lines or 10 files changed). Uses a 20% growth gate to avoid re-firing on every write. Findings are injected into the agent's context via stdout (silent-unless-violated).

## History
- 2026-03-29: Parallel checks with hook-gated constitution enforcement (issue 000018)
- 2026-03-29: Progress display for headless agent calls (issue 000017)
- 2026-03-29: Pre-merge checks (issue 000015)
- 2026-03-29: Worktree portability for openshell (issue 000014)
