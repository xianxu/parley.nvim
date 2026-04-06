---
id: 000070
status: done
deps: [68]
created: 2026-04-05
updated: 2026-04-05
---

# Allocation report export

Text report showing team capacity vs project demand per quarter.

## Done when

- `export_allocation_report(items, range_start, range_end)` returns formatted text
- `:ParleyVisionAllocation [--quarter=25Q3]` command works
- Shows per-team: persons + capacity, projects + demand, balance with warnings

## Details

Output format:
```
=== 25Q3 Planning Summary (backend) ===

Team capacity: 21.0w (2 persons)
  Alice Chen      11w
  Bob Park        10w

Project demand:   21.7w
  ehr-sync-v2      8.7w  (2.0m charged, 33% → 67% target)
  api-gateway     13.0w  (3.0m charged, 0% → 100% target)

Balance: -0.7w ⚠ over-committed (3%)
```

## Plan

- [x] Add `export_allocation_report` pure function
- [x] Add `cmd_export_allocation` IO command (scratch buffer output)
- [x] Updated `cmd_export_dot` to accept `--quarter=` flag
- [x] Unit tests (4 tests)

## Files

- `lua/parley/vision.lua`
- `tests/unit/vision_spec.lua`

## Log

### 2026-04-05
- Report shows per-namespace: persons+capacity, projects+demand, balance with warning
- cmd_export_allocation: --quarter=25Q3 flag, auto-detects from quarterly folders
- cmd_export_dot: added --quarter= flag for quarterly filtering
