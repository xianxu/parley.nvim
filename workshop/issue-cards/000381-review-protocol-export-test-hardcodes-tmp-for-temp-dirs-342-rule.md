---
id: 000381
status: open
created: 2026-10-17
updated: 2026-10-17
estimate_hours:
github_issue:
---

# review_protocol_export_test hardcodes /tmp for temp dirs (#342 rule)

## Problem

`tests/unit/review_protocol_export_test.py` creates its scratch directories with `tempfile.TemporaryDirectory(prefix='review-export-', dir='/tmp')` (lines 308 and 328). Inside a sandboxed agent shell `/tmp` is denied. `tests/integration/review_protocol_bundle_spec.lua` then fails with `PermissionError: [Errno 1] Operation not permitted: '/tmp/review-export-…'`, on any Neovim version. Seen during #379's 0.11 measurement, run as `make -k test` from an agent's Bash. The test also breaks the #342 rule: build temp dirs from `TMPDIR`, never a fixed path.
