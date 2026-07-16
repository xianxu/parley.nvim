---
id: 000007
status: done
deps: []
created: 2026-03-28
updated: 2026-03-28
---

# publish should generate array of tags

right now, we generate `tags: a, b, c`, this is not valid, it should be tags: [a, b, c]

## Done when

- Export generates `tags: [a, b, c]` instead of `tags: a, b, c`

## Plan

- [x] Fix tag formatting in `exporter.lua` to wrap in `[]`
- [x] Update export tests to expect YAML array format
- [x] All tests pass

## Log

### 2026-03-28

- Fixed `exporter.lua:94-101`: tags now formatted as `[tag1, tag2]` (valid YAML flow sequence)
- Default changed from `unclassified` to `[unclassified]`
- Updated 2 test assertions in `export_spec.lua` (lines 228, 353)
