# AI Workflow

## Overview
Issue-driven development workflow for AI coding agents. Work is tracked in single-file-per-issue markdown files under `workshop/issues/`, with completed work archived to `workshop/history/`. Two operational modes: direct-on-main for small changes, worktree-based branches for larger work.

## Issue File Format
Each issue is a markdown file at `workshop/issues/NNNNNN-slug.md` with YAML frontmatter:

```yaml
---
id: "000042"
status: open        # open | done
deps: []
github_issue: 42    # optional, links to GitHub issue
created: 2026-03-01
updated: 2026-03-01
---
```

Standard sections: `# Title`, `## Done when`, `## Plan` (checkable items, steps to follow), `## Log` (dated entries), `##Spec` (specification of what to change). For complex issues, detailed designs go in `workshop/plans/NNNNNN-slug-plan.md`.

## Two Workflows

### Direct-on-Main (small changes)
1. `make fetch 42` — fetches GitHub issue #42, creates `workshop/issues/NNNNNN-slug.md`
2. Work directly on main branch
3. `make push` — auto-commits, runs pre-merge checks, pushes, closes done GitHub issues, archives done issue files to `workshop/history/`

### Worktree Branch (larger changes)
1. `make issue 42` — fetches GitHub issue, creates worktree at `../worktree/<repo>-42/` on branch `<repo>-42`, creates issue file inside worktree
2. Work in the worktree directory
3. `make pull-request` — pushes branch, creates GitHub PR (auto-discovers `github_issue` frontmatter for "Fixes #N" linking)
4. `make merge` — merges PR via GitHub API, archives done issues in main, removes worktree and branch

Worktrees live under `../worktree/` (portable between local and OpenShell sandbox).

## Pre-Merge Checks
Agent-driven verification runs before `push` and `merge`. Six checks, each invoking a coding agent (default: `claude`, configurable via `AGENT_CMD`) with a focused review prompt:

| Check | What it does | Agent mode |
|-------|-------------|------------|
| `dry` | DRY violations in diff | read-only |
| `pure` | Pure/impure separation | read-only |
| `plan` | Issue plan completeness (skipped if no issue files changed) | read-only |
| `test` | Runs `make test` + `make test-agents` + `make lint`, then agent analyzes results | read-only |
| `atlas` | Checks atlas/ docs match code changes | **read-write** (may update docs) |
| `lessons` | Reminder to review `workshop/tasks/lessons.md` | no agent |

### Execution Modes
- **Interactive** (`make check` or `make pre-merge`): sequential, prompts accept/discard for each check that modifies files
- **Audit** (`scripts/parallel-checks.sh --audit` or `make c`): all checks run in parallel (concurrency limit `MAX_PARALLEL_CHECKS`, default 3), report-only, updates state file
- **Single check**: `make check-dry`, `make check-specs`, etc.
- **Preset selection**: `PRE_MERGE_CHECKS=yynnyn make pre-merge` (y/n per check in order: dry, pure, plan, test, specs, lessons)

Agent adapters exist for `claude`, `codex`, and `gemini`. Claude uses `--permission-mode bypassPermissions` with stream-json progress output.

## Constitution Hook
A `PostToolUse` hook on `Write`/`Edit` events triggers constitution checks during coding sessions. Three-tier gate based on diff size since the merge base:

| Tier | Trigger | Behavior |
|------|---------|----------|
| **none** | Below threshold (300 lines / 5 files) | Silent, no action |
| **nag** | Above threshold | Sends `additionalContext` reminder to the agent |
| **force** | Above 3× nag threshold | Runs all checks immediately, blocks agent until violations are fixed |

Thresholds are relative: after a check runs, the state file (`.constitution-check-state`) records the current diff size, and the next threshold is +50% growth from that point. State resets when the merge base SHA changes (new commits on main).

The hook uses `additionalContext` in its JSON response so reminders reach the coding agent without appearing as user-visible messages. A filesystem lock (`mkdir`-based, cross-platform) prevents concurrent hook invocations.

## Artifact Lifecycle
```
GitHub Issue → make fetch/issue → workshop/issues/NNNNNN-slug.md
                                  workshop/plans/NNNNNN-slug-plan.md (complex only)
                                  atlas/*.md (updated incrementally)
              work...
              make push/merge  → workshop/history/NNNNNN-slug.md (archived)
                                 GitHub issue closed
```

## AGENTS.md Integration
The workflow enforces the AGENTS.md constitution:
- **Plan First**: issue file's `## Plan` section with checkable items
- **Track Progress**: mark items complete, log discoveries in `## Log`
- **Verify**: pre-merge checks enforce DRY, PURE, test passing, spec sync
- **Lessons**: `workshop/tasks/lessons.md` captures patterns from mistakes
- **Post-milestone review**: mandatory code review subagent at milestone boundaries
