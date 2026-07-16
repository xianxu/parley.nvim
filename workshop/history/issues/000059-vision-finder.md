---
id: 000059
status: done
deps: [54]
created: 2026-04-04
updated: 2026-04-04
---

# vision finder

Float picker showing all initiatives across vision YAML files, reusing the issue finder / float picker pattern.

- `:ParleyVisionShow` / `<C-j>f`
- Display: name, type, size, quarter, namespace
- Open the source YAML file at the initiative's line on select
- Filter/search across all fields

Parent: #52

## Done when

- Float picker opens with all initiatives listed
- Each item shows name, type, size, quarter
- Selecting an item opens the YAML file at that initiative's line
- Search/filter works across fields

## Plan

- [x] Create `lua/parley/vision_finder.lua` (follow `issue_finder.lua` pattern)
- [x] Reuse `float_picker.lua` for the picker UI
- [x] Format items: `namespace  name  [size]  type  quarter`
- [x] On select: open file at `_line`
- [x] Register `M.cmd.VisionShow` in `init.lua`
- [x] Register `<C-j>f` shortcut via config

## Log

### 2026-04-04

