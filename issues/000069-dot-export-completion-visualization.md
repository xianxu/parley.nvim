---
id: 000069
status: open
deps: [66, 68]
created: 2026-04-05
updated: 2026-04-05
---

# DOT export with completion visualization

Update `export_dot()` for linear month sizing, completion fill, and quarterly filter.

## Done when

- Node width scales linearly: `1.5 + months * 0.4`
- Completion shown via `style=striped` with weighted color list
- Label includes completion % and month size
- `--quarter` filter only shows projects with non-zero charge
- Person entities excluded from dot
- T-shirt sizes still work (mapped to months)

## Details

- Color pairs: tech done=`#5b9bd5` / base=`#a0d8ef`, business done=`#e6a23c` / base=`#ffe0b2`
- 0% → base only, 100% → done only, between → striped
- New opts: `opts.quarter`, `opts.range`

## Plan

- [ ] Replace `BASE_SIZE_MAP` with linear month scaling + T-shirt fallback
- [ ] Add completion striped fill logic
- [ ] Add quarterly filter to `export_dot`
- [ ] Update label format
- [ ] Unit tests for striped fill output

## Files

- `lua/parley/vision.lua`
- `tests/unit/vision_spec.lua`

## Log
