---
id: 000381
status: done
created: 2026-10-17
updated: 2026-10-17
estimate_hours:
github_issue:
started: 2026-10-17T18:13:34-07:00
claimant:
    operator: Xian Xu
    machine: 4716879978a7b90f6b583da1716fd0e9
    machine_name: Xian’s MacBook Pro
    workspace: parley.nvim:4
    worktree: /Users/xianxu/workspace/worktree/parley.nvim-slot4/parley.nvim
    repository: github.com/xianxu/parley.nvim
actual_hours: 0.30
tracker:
    version: 1
    completion:
        token: close-f00c0ab9d2cb
        repository: github.com/xianxu/parley.nvim
        reviewed_head: 4d29297e2e121189e49cc8a26ecdc5765bb0eeb1
        evidence_commit: 18b252d5d7f65e0c37c03a00b1e2f3fbd4803ccc
        landed_commit: 04778522a9f9b6af3bd6a06be764b1c47573c4d3
---

# review_protocol_export_test hardcodes /tmp for temp dirs (#342 rule)

## Problem

`tests/unit/review_protocol_export_test.py` creates its scratch directories with `tempfile.TemporaryDirectory(prefix='review-export-', dir='/tmp')` (lines 308 and 328). Inside a sandboxed agent shell `/tmp` is denied. `tests/integration/review_protocol_bundle_spec.lua` then fails with `PermissionError: [Errno 1] Operation not permitted: '/tmp/review-export-…'`, on any Neovim version. Seen during #379's 0.11 measurement, run as `make -k test` from an agent's Bash. The test also breaks the #342 rule: build temp dirs from `TMPDIR`, never a fixed path.
