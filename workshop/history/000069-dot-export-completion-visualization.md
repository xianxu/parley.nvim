---
id: 000069
status: done
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

- [x] Replace `BASE_SIZE_MAP` with linear month scaling + T-shirt fallback
- [x] Add completion striped fill logic (striped for partial, solid for 0%/100%)
- [x] Add quarterly filter to `export_dot` (opts.quarter)
- [x] Update label format (month size + completion %)
- [x] Person entries excluded from DOT
- [x] Unit tests (6 new tests)

## Files

- `lua/parley/vision.lua`
- `tests/unit/vision_spec.lua`

## Log

### 2026-04-05
- size_to_width: linear formula `1.5 + months * 0.4`, T-shirt fallback via parse_size_months
- completion_fill: striped with weighted color list, done/base color pairs per type
- Quarterly filter via quarterly_charge — only shows projects with non-zero charge
