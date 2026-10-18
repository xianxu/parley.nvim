---
id: 000381
status: open
deps: []
github_issue:
created: 2026-10-17
updated: 2026-10-17
estimate_hours:
collaboration-mode: collaboration
card_mirror: '757bbc501419d845a14fc5c1c96c5aaff9b9ef6a' # card fields mirrored from issue-cards; edit via sdlc
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

- [ ]

## Log

### 2026-10-17
