---
id: 000067
status: open
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

- [ ] Add `overlay_files` pure function
- [ ] Add `discover_quarters` IO function
- [ ] Add `load_vision_quarterly` IO function
- [ ] Update `load_all()` for auto-detection
- [ ] Unit tests for overlay merging

## Files

- `lua/parley/vision.lua`
- `tests/unit/vision_spec.lua`

## Log
