---
id: 000071
status: open
deps: [66]
created: 2026-04-05
updated: 2026-04-05
---

# Validation updates

Extend `validate_graph()` for new schema fields and person entities.

## Done when

- Validates start_by/need_by format (quarter or month)
- Warns if need_by < start_by
- Warns on overdue projects (need_by before current quarter, completion < 100)
- Validates person entries have name and capacity
- Validates completion is 0-100
- Validates size is valid month format or T-shirt
- Person entries don't trigger "not a project" errors

## Plan

- [ ] Skip person entries in project validation
- [ ] Add time field format validation
- [ ] Add person field validation
- [ ] Add completion/size validation
- [ ] Unit tests

## Files

- `lua/parley/vision.lua`
- `tests/unit/vision_spec.lua`

## Log
