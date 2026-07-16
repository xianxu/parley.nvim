---
id: 000026
status: done
deps: []
created: 2026-03-29
updated: 2026-03-29
---

# use red color text for check-* violation

## Done when

- Check violation output is displayed in red, clean output is not

## Plan

- [x] Add `is_clean_check_output` and `print_check_output` helpers to `scripts/lib.sh`
- [x] Capture and colorize agent output in `run_check()` in `pre-merge-checks.sh`
- [x] Colorize output in `assemble_context()` in `parallel-checks.sh`

## Log

### 2026-03-29

- Added helpers to lib.sh that detect clean vs violation output using known clean patterns from agent prompts
- Updated both pre-merge-checks.sh and parallel-checks.sh to use the helpers
- Clean patterns: "No DRY/PURE violations found", "All tests pass", "No changes needed", "in sync", etc.

