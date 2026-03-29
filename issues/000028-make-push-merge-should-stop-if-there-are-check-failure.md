---
id: 000028
status: done
deps: []
created: 2026-03-29
updated: 2026-03-29
---

# make push/merge should stop if there are check-* failure

right now it would just go on essentially ignoring those checks

## Done when

- `make push`/`make merge` stops and prompts user when constitution checks find violations

## Plan

- [x] Track failures in `assemble_context` via `HAS_FAILURES` flag
- [x] After checks complete, prompt "Stop to address them? [Y/n]" if failures found
- [x] Exit non-zero to halt `make push`/`make merge` pipeline when user chooses to stop
- [x] Distinguish informational checks (lessons reminder) from real failures — use `ℹ` (yellow) vs `✗` (red)

## Log

### 2026-03-29

**Changes made** (in `scripts/parallel-checks.sh` and `scripts/lib.sh`):

1. `assemble_context` now sets `HAS_FAILURES=1` when any check output is not clean and not informational
2. After all checks print, if `HAS_FAILURES=1`: prompt "Stop to address them? [Y/n]" via `/dev/tty`, exit 1 if yes → halts `make push`/`make merge`
3. Added `is_info_check_output()` in `lib.sh` to classify `REMINDER:` messages as informational
4. `print_check_output` now shows three states:
   - `✓` (green) — passed
   - `ℹ` (yellow) — informational, non-blocking
   - `✗` (red) — violation found, triggers stop prompt

