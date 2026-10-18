---
id: 000381
status: working
deps: []
github_issue:
created: 2026-10-17
updated: 2026-10-17
estimate_hours:
collaboration-mode: collaboration
card_mirror: '79810cc83ec765840f6973a7c190b92aef698147' # card fields mirrored from issue-cards; edit via sdlc
started: 2026-10-17T18:13:34-07:00
claimant:
    operator: Xian Xu
    machine: 4716879978a7b90f6b583da1716fd0e9
    machine_name: Xian’s MacBook Pro
    workspace: parley.nvim:4
    worktree: /Users/xianxu/workspace/worktree/parley.nvim-slot4/parley.nvim
    repository: github.com/xianxu/parley.nvim
flow: {kind: quick, provenance: inferred, spec: "d23ddeb8", done: "d768b4e3"}
---

# review_protocol_export_test hardcodes /tmp for temp dirs (#342 rule)

## Problem

`tests/unit/review_protocol_export_test.py` creates its scratch directories with `tempfile.TemporaryDirectory(prefix='review-export-', dir='/tmp')` (lines 308 and 328). Inside a sandboxed agent shell `/tmp` is denied. `tests/integration/review_protocol_bundle_spec.lua` then fails with `PermissionError: [Errno 1] Operation not permitted: '/tmp/review-export-…'`, on any Neovim version. Seen during #379's 0.11 measurement, run as `make -k test` from an agent's Bash. The test also breaks the #342 rule: build temp dirs from `TMPDIR`, never a fixed path.

## Spec

Use `TMPDIR` (as `scripts/check-sdlc-resolve-conformance.py` does: `dir=os.environ.get("TMPDIR") or "/tmp"`), or no `dir=` at all, so Python honours `TMPDIR` itself.

## Done when

- No test or script under `tests/` or `scripts/` passes a fixed `/tmp` as a temp-dir root. Checked by grep, every instance swept.
- `review_protocol_bundle_spec` passes when `make test` runs from a sandboxed agent shell.

## Plan

- [x] Sweep every fixed `/tmp` temp-dir root in tracked `tests/`, `scripts/` and `Makefile*`. The search covered Python `TemporaryDirectory`/`mkdtemp`/`mkstemp`/`NamedTemporaryFile` and shell `mktemp`, plus any Lua write under a literal `/tmp`. It found 7 instances: `tests/unit/review_protocol_export_test.py` at 78, 110, 269, 297, 308 and 328, and `scripts/check-spell-compatibility.sh:10`. Every other `/tmp` hit is a path string that never touches disk, or the `${TMPDIR:-/tmp}` / `os.environ.get("TMPDIR") or "/tmp"` fallback.
- [x] Python: drop `dir=`, since `tempfile` honours `TMPDIR` itself. Shell: `mktemp -d "${TMPDIR:-/tmp}/…" || exit 1`, matching the sibling scripts.
- [x] Guard: `tests/arch/scratch_placement_spec.lua` scans the same files for both forms, with a fixture case showing it flags each form and passes the fallbacks. The class cannot come back unnoticed (ARCH-PURPOSE).

## Log

### 2026-10-17
- Verified from a sandboxed agent shell. review_protocol_bundle_spec passes, and failed before this change. scratch_placement passes 10/10. Mutation check: putting `dir='/tmp'` back at :308 fails both review_protocol_bundle (the sandbox denies /tmp) and the new guard.
- The first recorded suite on c058cde3 failed in `tests/unit/arch_helper_spec.lua`: every file-set guard must list files through `arch_helper.worktree_files`, because `git ls-files` cannot see untracked files. The new guard now uses it. That spec passes 9/9 and scratch_placement 10/10.
