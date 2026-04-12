---
id: 000027
status: done
deps: []
created: 2026-03-29
updated: 2026-03-29
---

# `make check-*` doesn't work on mac

`make check-*` finishes too fast on mac, it's clear it didn't do anything. check if that's true.

## Done when

- `make c` and `make check-*` work correctly on macOS (no GNU coreutils required)

## Plan

- [x] Investigate: confirm checks silently skip on macOS
- [x] Fix `timeout` portability in `parallel-checks.sh` — use perl alarm fallback
- [x] Fix `wait -n -p` portability in `parallel-checks.sh` — replace with kill -0 polling
- [x] Test `make c` and `make check-dry` work on macOS after fix

## Log

### 2026-03-29

**Root cause found:** Two macOS compatibility issues in `scripts/parallel-checks.sh`:

1. **`timeout` command** (line 92) — GNU coreutils, not on macOS. `run_check_captured` exits 127, stdout is empty, and `assemble_context` treats empty output as "clean" → all checks show ✓ without running.
2. **`wait -n -p`** (line 122) — requires bash 4.3+/5.1+, macOS has bash 3.2. Concurrency limiting loop doesn't work properly (silenced by `2>/dev/null || true`).

`make check-dry` (sequential mode via `pre-merge-checks.sh`) works fine — only the parallel audit mode (`make c` / `make pre-merge`) is broken.

