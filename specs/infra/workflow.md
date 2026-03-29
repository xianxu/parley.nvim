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
make pre-merge                          # interactive selection
make check-dry                          # single check
PRE_MERGE_CHECKS=yynnyn make pre-merge  # preset (y=run, n=skip)
PRE_MERGE_CHECKS=yynnyn make push       # push with preset checks
```

### Change Detection
After each agent check, repo state is diffed. If files changed:
- User sees `git diff --stat`
- Accept → changes staged
- Discard → `git checkout/clean`

## History
- 2026-03-29: Pre-merge checks (issue 000015)
- 2026-03-29: Worktree portability for openshell (issue 000014)
