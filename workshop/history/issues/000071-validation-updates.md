---
id: 000071
status: done
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

- [x] Skip person entries in project validation
- [x] Add time field format validation (start_by, need_by)
- [x] Add person field validation (name, capacity format)
- [x] Add completion/size validation
- [x] Warn when need_by < start_by
- [x] Unit tests (10 new tests)

## Files

- `lua/parley/vision.lua`
- `tests/unit/vision_spec.lua`

## Log

### 2026-04-05
- Updated existing test data from old free-form need_by to structured format
- Person entries skip project validation, get own name+capacity checks
