---
id: 000040
status: wontfix
deps: []
created: 2026-03-30
updated: 2026-05-03
---

# nagging behavior

check previous issue at ../history/000037-rethink-of-claude-hook.md. One issue I noticed is that when in nagging mode, we keep nagging on each hook trigger. there should be backing off behavior like wait till things grow another X%. essentially we need to keep track how many times we nagged.

think through this for me

1. when is state file generated.
2. how's the sha in state file determined, note there could be some commit on current git that are not in master, e.g. current top may not be what we want to compare to.

first describe what's current behavior, on a fresh start, without any state file. then think through the several workflows 1/ worktree; 2/ work on main. both may have multiple commits over the cause of a feature.

Apr 12, 2026 5:07:13 PM: as far as I remember, this nagging hook don't quite work, for now, we will need to run `make c` explicitly

## Done when

- Nagging mechanism removed from the base layer
- `make c` (audit) remains as the explicit entry point

## Plan

- [x] Remove `--hook-gate` mode, threshold/state logic, and `.constitution-check-state` references from the ariadne base layer (`scripts/parallel-checks.sh`, `atlas/workflow/pre-merge-checks.md`, `construct/setup.sh`, `.gitignore`)
- [x] Re-vendor parley via `make refresh`
- [x] Delete parley-local `tests/test_parallel_checks.sh` (tested only the removed logic)
- [x] Drop `.constitution-check-state` from parley's `.gitignore`

## Log

### 2026-03-30
f

### 2026-05-03

Closed as wontfix. Nagging behavior never tuned reliably — false-positive nags on every hook tick and unclear merge-base on worktrees made it more disruptive than helpful. Decision: rely on the explicit `make c` invocation.

Discovered during cleanup that the `PostToolUse` Write/Edit hook entries in `.claude/settings.json` had been silently dropped by commit `870aefa` "refresh ariadne" (Apr 28, 2026) when the construct adoption flow took over the settings file — the ariadne template never carried those entries. So the `--hook-gate` script branch had been orphaned dead code since then.

All nag code paths and the hook-gate mode are removed at the base layer; this repo picked them up via `make refresh`.
