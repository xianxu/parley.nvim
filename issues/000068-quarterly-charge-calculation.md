---
id: 000068
status: open
deps: [66]
created: 2026-04-05
updated: 2026-04-05
---

# Quarterly charge calculation

Calculate how much effort a project charges to a given planning range, accounting for completion, start_by, need_by, and uniform distribution.

## Done when

- `quarterly_charge(project, range_start, range_end)` returns months charged
- `allocation_summary(items, range_start, range_end)` returns per-team capacity vs demand
- Edge cases handled: pre-start (0), overdue (full remaining), completion interaction

## Details

- `remaining = size_months * (1 - completion / 100)`
- start_by after range_end → 0
- need_by before range_start → overdue, charge full remaining
- Otherwise: remaining / remaining_quarters
- Missing start_by → range_start; missing need_by → range_end
- Allocation groups by namespace, converts months→weeks via 4.33

## Plan

- [ ] Add `quarterly_charge` pure function
- [ ] Add `allocation_summary` pure function
- [ ] Unit tests with edge cases

## Files

- `lua/parley/vision.lua`
- `tests/unit/vision_spec.lua`

## Log
