---
id: 000033
status: done
deps: []
created: 2026-03-29
updated: 2026-03-29
---

# make check-dry should work on both mac and sandbox

 let's use the current implementation of issue 32 as example 

## Done when

- `make check-dry` produces meaningful agent output on mac (not just "No changes needed")

## Plan

- [x] Diagnose why check-dry silently fails on mac
- [x] Fix: add `--verbose` flag to claude stream-json command

## Log

### 2026-03-29

- Root cause: `claude -p --output-format stream-json` requires `--verbose` on current CLI versions. Without it, the command errors to stderr (suppressed by `2>/dev/null`), producing empty output. Empty output → `✗` label but no actual violations shown, then git detects no file changes → `✓ No changes needed`.
- Fix: Added `--verbose` to `agent_run_claude()` in `scripts/pre-merge-checks.sh` when streaming is enabled.
