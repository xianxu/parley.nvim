# Pre-merge Checks

## Purpose

Automated constitution enforcement. Before code lands on main, agent-driven checks verify adherence to core design principles.

## Checks

| Name | What it checks |
|------|---------------|
| dry | DRY violations — duplicated logic, copy-paste |
| pure | PURE principle — side effects mixed with business logic |
| plan | Issue file completeness — Plan checklist, Log entries, status |
| specs | Atlas/README sync — documentation drift |
| lessons | Reminder to capture patterns in lessons.md |

## Invocation

- `make check` or `make pre-merge` — interactive selection
- `make check-dry` — single check
- `scripts/parallel-checks.sh --audit` — all checks in parallel (read-only)
- `scripts/parallel-checks.sh --hook-gate` — threshold-based auto-trigger

## Threshold gate (hook mode)

The hook gate measures diff size since last check. Based on growth:
- **Below threshold**: silent (no interruption)
- **Nag threshold**: reminds agent to run checks voluntarily
- **Force threshold** (3x nag): runs checks immediately, blocks if violations found

State tracked in `.constitution-check-state` (git-ignored).

## Scripts

- `scripts/lib.sh` — shared helpers (colors, git diff base, output classification)
- `scripts/pre-merge-checks.sh` — individual check runner with agent invocation
- `scripts/parallel-checks.sh` — parallel orchestrator with threshold logic
