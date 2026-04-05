---
id: 000073
status: open
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

- [ ] Add field value suggestions for new fields
- [ ] Update `cmd_new` to support person template
- [ ] Unit tests

## Files

- `lua/parley/vision.lua`
- `tests/unit/vision_spec.lua`

## Log
