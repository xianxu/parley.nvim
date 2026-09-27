---
id: '000086'
status: done
created: 2026-04-09
updated: 2026-05-05
actual_hours: 0.5
---

# hard to spot which test failed in `make test`

## Problem

`test-unit` and `test-integration` ran `xargs -P 8 -I {} nvim ... PlenaryBustedFile {}`. With 8 parallel jobs the per-file plenary output interleaved line-by-line, and on failure the only summary was `Unit tests failed` — the failing file path was technically present in plenary's chatter but invisible amid 50+ files of pass output. xargs also doesn't natively label which input produced which output, so even reading the noise didn't tell you which spec failed.
