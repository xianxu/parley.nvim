---
id: 000064
status: done
deps: []
created: 2026-04-03
updated: 2026-04-03
---

# add a command to display current quarter projects, for sanity check

## Done when

- `:ParleyVisionDot --quarter=25Q3` renders only projects charging to that quarter
- `:ParleyVisionAllocation --quarter=25Q3` shows allocation report for that quarter

## Plan

- [x] `--quarter=` flag supported in both commands (via `load_all` + `export_dot` opts)

## Log

### 2026-04-07

- Marked done retroactively. Both `:ParleyVisionDot` and `:ParleyVisionAllocation` accept `--quarter=<Q>` (vision.lua:1621, 1650). Auto-detects latest quarter folder by default. Issue was never closed.

### 2026-04-03

