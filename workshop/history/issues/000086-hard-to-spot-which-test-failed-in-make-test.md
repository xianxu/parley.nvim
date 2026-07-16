---
id: 000086
status: done
deps: []
created: 2026-04-09
updated: 2026-05-05
actual_hours: 0.5
---

# hard to spot which test failed in `make test`

we should have better ways to print which test failed

## Problem

`test-unit` and `test-integration` ran `xargs -P 8 -I {} nvim ... PlenaryBustedFile {}`. With 8 parallel jobs the per-file plenary output interleaved line-by-line, and on failure the only summary was `Unit tests failed` — the failing file path was technically present in plenary's chatter but invisible amid 50+ files of pass output. xargs also doesn't natively label which input produced which output, so even reading the noise didn't tell you which spec failed.

## Done when

- [x] Failing test files print a clearly labelled block with the path.
- [x] After a parallel run, an end-of-run summary lists every failed file.
- [x] Passing runs print one progress line per file.
- [x] Exit code still propagates.

## Plan

- [x] Wrap the per-file `nvim … PlenaryBustedFile` invocation in a small shell wrapper that captures stdout/stderr to a temp file, prints `PASS: <path>` on success or `===FAIL: <path>===` followed by the indented captured output on failure, and appends failing paths to a shared `$FAILED_LOG`.
- [x] After `xargs` returns, print `=== Failed unit/integration test files ===` followed by `sort -u $FAILED_LOG` so the summary is reliable even when parallel FAIL blocks interleave.
- [x] Apply identically to both `test-unit` and `test-integration` (factored as `RUN_SPEC` make var, DRY).
- [x] Verify with a real run — pre-existing `keybindings_spec` failure now shows up clearly above a final one-line summary.

## Log

### 2026-04-09

- Issue authored.

### 2026-05-05

- Diagnosed: `Makefile.parley:41-54` ran `xargs -P 8 -I {} nvim … PlenaryBustedFile {} || echo "Unit tests failed"`. xargs doesn't label outputs and the parallel streams interleave; failure path is buried.
- Implemented `RUN_SPEC` wrapper + per-recipe `FAILED_LOG` summary.
- macOS quirk: `mktemp` ignores `TMPDIR` for the default-template path on BSD/macOS; uses `_CS_DARWIN_USER_TEMP_DIR` (per-user `/var/folders/...`). Sandbox blocks that path. Fixed by passing an explicit template `mktemp "$TMPDIR/parley-test.XXXXXX"` — also strictly more deterministic than relying on the implicit default.
- Verified end-to-end: pass-only files print one `PASS: <path>` line; the pre-existing `keybindings_spec` failure now shows as a labelled FAIL block plus a final `=== Failed unit test files ===` summary listing the path. Exit code propagates (`make: *** [test-unit] Error 1`).

