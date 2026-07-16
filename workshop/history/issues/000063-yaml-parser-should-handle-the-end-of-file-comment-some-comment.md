---
id: 000063
status: done
deps: []
created: 2026-04-03
updated: 2026-04-03
---

# yaml parser should handle the end of file comment: # some comment

## Done when

-

## Plan

- [ ]

## Done when

- Trailing `# comment` line at EOF is ignored; preceding items parse correctly.

## Plan

- [x] Add test `"skips trailing comment at end of file"` in `tests/unit/vision_spec.lua`

## Log

### 2026-04-07

- Comment handling (`stripped:match("^#")`) was present in `vision.lua:108` from the very first commit (2026-04-03). Issue was never closed.
- Added explicit EOF-comment test to `vision_spec.lua` to document the behavior.

### 2026-04-03

