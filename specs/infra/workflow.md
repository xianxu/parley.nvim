# AI Workflow

## Issue-Based Development
Work tracked via single-file-per-issue markdown in `issues/`. Two modes:
- **On main**: `make fetch` -> work -> `make push` (auto-commit, close GH issues, archive)
- **On branch**: `make issue` -> work in worktree -> `make pull-request` -> `make merge`

Completed issues moved to `history/` (low-signal, avoid in agent workflows). Worktrees under `../worktree/` for portability between local and openshell.

## Pre-Merge Checks
Agent-driven verification before `push` and `merge`. Each check invokes a coding agent with a focused prompt, then detects repo changes for user accept/discard.

| Target | Purpose |
|--------|---------|
| `check-dry` | DRY violations in diff |
| `check-pure` | Pure/impure separation |
| `check-plan` | Issue plans complete |
| `check-test` | Tests + lint pass |
| `check-specs` | Specs match code |
| `check-lessons` | Lessons review reminder |

Supports interactive (sequential accept/discard) and audit mode (parallel, report-only). Configurable agent (`AGENT_CMD`: claude/codex/gemini).

## Constitution Hook
`PostToolUse` hooks on `Write`/`Edit` trigger constitution checks during coding sessions. Three-tier gate based on diff size: **none** (below threshold), **nag** (reminder to run audit), **force** (runs checks immediately). State resets when merge base advances. Hook output uses `additionalContext` JSON field so Claude sees and acts on the messages (not `systemMessage`, which is user-visible only).
