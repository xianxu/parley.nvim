---
id: 000066
status: done
deps: [65]
created: 2026-04-05
updated: 2026-04-05
---

# Pure functions: time parsing, month sizes, capacity

Add pure functions (no vim deps) for parsing the new schema fields.

## Done when

- `parse_time("25Q3")` returns `{year=25, q=3}`, `parse_time("25M11")` returns `{year=25, m=11}`
- `time_to_months(t)` converts to absolute months for comparison
- `quarters_between(t1, t2)` returns count of quarters in range
- `parse_size_months("3m")` returns 3, with T-shirt backward compat
- `parse_capacity_weeks("11w")` returns 11
- All unit tested

## Details

- Quarter start months: Q1=1, Q2=4, Q3=7, Q4=10
- T-shirt compat: S→1, M→3, L→6, XL→12
- `WEEKS_PER_MONTH = 4.33`

## Plan

- [x] Add `parse_time`, `time_to_months`, `quarters_between`
- [x] Add `parse_size_months`, `parse_capacity_weeks`
- [x] Unit tests for all functions (23 tests, all passing)

## Files

- `lua/parley/vision.lua`
- `tests/unit/vision_spec.lua`

## Log

### 2026-04-05
- Implemented all 5 pure functions in vision.lua (lines 137-211)
- 23 unit tests covering normal, edge, and invalid inputs
- Exposed WEEKS_PER_MONTH and TSHIRT_TO_MONTHS constants for downstream use
