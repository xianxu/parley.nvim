---
id: 000076
status: done
deps: [65]
created: 2026-04-05
updated: 2026-04-05
---

# Capacity-Aware Projection

Add projected end-of-quarter completion for each project, accounting for team capacity and dependency ordering.

## Computation Model

Per namespace, per quarter:

1. **Planned work**: `quarterly_charge` gives months of work this quarter per project. "Planned completion" = `current_completion + (charge / size) * 100`.

2. **Capacity pool**: Sum of person `capacity` weeks in the namespace.

3. **Scheduling**: Topological sort projects by dependency order. Walk in order, deducting each project's charge (in weeks) from remaining capacity:
   - Remaining capacity >= charge → **fully funded**, reaches planned completion
   - Remaining capacity > 0 but < charge → **partially funded**, achievable = `current + (capacity_available / size) * 100`
   - Remaining capacity = 0 → **unfunded**, stays at current completion

4. **Cross-namespace deps**: Ordering constraint only — each project consumes its own namespace's capacity.

5. **Result per project**: `current_completion`, `achievable_completion`, `planned_completion`

## DOT Visualization (4-segment striped fill)

```
|  done  | achievable | shortfall |  remaining  |
|  dark  |   medium   |    red    |    base     |
0%     current    achievable   planned        100%
```

- **done** (0→current): existing done color (`#5b9bd5` tech / `#e6a23c` business)
- **achievable** (current→achievable): lighter shade — work we'll complete this quarter
- **shortfall** (achievable→planned): red tint (`#e57373`) — gap from capacity shortage
- **remaining** (planned→100%): base color

When fully funded: achievable == planned, no red segment.

## Allocation Report

Add projected column to project table: `current% → achievable%`, flag shortfall.

## Done when

- `project_projections(items, quarter)` returns per-project `{current, achievable, planned}` data
- DOT export uses 4-segment fill when `--quarter=` is specified
- Allocation report shows projected completion
- Dependency ordering respected: upstream projects get capacity first
- Cross-namespace deps are ordering-only, no capacity sharing

## Plan

- [x] Add `project_projections` pure function (topo sort + capacity deduction)
- [x] Update `export_dot` to use 4-segment fill when projection data available
- [x] Update `export_allocation_report` to show projected completion with shortfall warning
- [x] Unit tests (7 new tests)

## Files

- `lua/parley/vision.lua`
- `tests/unit/vision_spec.lua`

## Log

### 2026-04-05
- topo_sort_ns: DFS-based, deps processed first via append-on-finish
- 4-segment fill: done / achievable (lighter) / shortfall (red) / remaining (base)
- DOT label shows `current% → achievable%/planned%` when shortfall, `current% → planned%` when funded
- Allocation report: added Projection column with ⚠ on shortfall
