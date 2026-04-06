---
id: 000067
status: done
deps: [66]
created: 2026-04-05
updated: 2026-04-05
---

# Overlay filesystem loader

Support quarter folders (`vision/25Q2/`, `vision/25Q3/`) with file-level overlay semantics.

## Done when

- `overlay_files(base, current)` merges file lists with current overriding base
- `load_vision_quarterly(root, quarter)` loads with overlay from previous quarter
- `load_all()` auto-detects quarter folders vs flat YAML
- Backward compat: flat `vision/*.yaml` still works

## Details

- If vision_dir has `*.yaml` directly → flat mode (existing)
- If vision_dir has `YYQ[1-4]` subdirs → quarterly mode
- Default quarter = latest folder found
- Previous quarter = sorted predecessor in folder list

## Plan

- [x] Add `overlay_files` pure function
- [x] Add `discover_quarters` IO function
- [x] Add `load_vision_quarterly` IO function
- [x] Update `load_all()` for auto-detection (returns quarter as 3rd value)
- [x] Unit tests for overlay merging (6 tests)

## Files

- `lua/parley/vision.lua`
- `tests/unit/vision_spec.lua`

## Log

### 2026-04-05
- overlay_files: file-level merge, sorted by filename, current overrides base
- discover_quarters: finds YYQ[1-4] subdirs, sorted
- load_vision_quarterly: loads base quarter, overlays current
- load_all: auto-detects quarterly vs flat mode, defaults to latest quarter
