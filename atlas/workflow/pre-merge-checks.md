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
- `make c` / `scripts/parallel-checks.sh --audit` — all checks in parallel (read-only)

Checks are run on demand; there is no automatic threshold-based hook.

## Scripts

- `scripts/lib.sh` — shared helpers (colors, git diff base, output classification)
- `scripts/pre-merge-checks.sh` — individual check runner with agent invocation
- `scripts/parallel-checks.sh` — parallel orchestrator
