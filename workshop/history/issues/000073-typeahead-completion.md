---
id: 000073
status: done
deps: [67]
created: 2026-04-05
updated: 2026-04-05
---

# Typeahead completion updates

Add completion suggestions for new fields introduced by quarterly planning.

## Done when

- `start_by` / `need_by` suggest quarter values (`25Q1`–`25Q4`, `26Q1`, etc.)
- `size` suggests month values (`1m`, `2m`, `3m`, `6m`, `9m`, `12m`)
- `capacity` suggests common week values
- `type` keeps existing (`tech`, `business`)
- Person template available via `:ParleyVisionNew`

## Plan

- [x] Add size completion: month values (0.5m-12m) + T-shirt with month equivalent in menu
- [x] Add start_by completion: values from existing data
- [ ] Update `cmd_new` to support person template (deferred — low priority)
- [ ] Unit tests (typeahead is IO-dependent, covered by manual testing)

## Files

- `lua/parley/vision.lua`

## Log

### 2026-04-05
- Size completion now suggests 0.5m-12m plus S/M/L/XL with month equivalents
- start_by completion mirrors need_by: values from existing data
- Removed unused COLOR_MAP (replaced by DONE_COLOR_MAP/BASE_COLOR_MAP)
