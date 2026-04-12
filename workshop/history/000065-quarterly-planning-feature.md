---
id: 000065
status: done
deps: []
created: 2026-04-05
updated: 2026-04-05
---

# Quarterly Planning Feature for Vision Tracker

Evolve the vision tracker into a quarterly planning tool. Currently projects use T-shirt sizes (S/M/L/XL) in a flat YAML directory. This adds person entities, month-based sizing, quarter folders with overlay filesystem, completion tracking, and allocation reports.

Design: `design/2026-04-03.22-21-53.719.md`

## Done when

- Person entities parseable from YAML as `- person: Name` with `capacity: 11w`
- Quarter folders with file-level overlay work (`vision/25Q3/` over `vision/25Q2/`)
- Quarterly charge calculated from size, completion, start_by, need_by
- DOT export shows completion fill and linear month sizing
- Allocation report shows team capacity vs demand
- Backward compat with flat YAML and T-shirt sizes preserved

## Design Decisions

1. Overlay is **file-level** — `25Q3/backend.yaml` fully replaces `25Q2/backend.yaml`
2. Person: just `name` + `capacity: 11w`. No role, no per-person project allocation
3. Size in months: `1m`, `3m`, `6m` etc. Linear dot node scaling: `width = 1.5 + months * 0.4`
4. Completion is scope-based (not time-based). Affects charge: `remaining = size * (1 - completion/100)`
5. Quarterly charge: `remaining_effort / remaining_quarters_in_range`
6. No status field — delete projects to cut them, git has history
7. Type (`tech`/`business`) rendered as different background colors in dot
8. Single `description` field
9. Default quarter: latest quarter folder in vision dir
10. Overdue projects (past need_by, not 100%): charge full remaining to current quarter

## YAML Schema

```yaml
- person: Alice Chen
  capacity: 11w

- project: EHR Sync V2
  type: tech
  size: 6m
  start_by: 25Q2
  need_by: 25Q4
  completion: 33
  description: "Bi-directional patient sync via CDC + FHIR adapters"
  link: "https://notion.so/ehr-sync"
  depends_on:
    - api-gateway
```

## Sub-tickets

| ID | Title | Deps | Status |
|----|-------|------|--------|
| [#66](./000066-time-and-size-parsing.md) | Time parsing, month sizes, capacity | #65 | done |
| [#67](./000067-overlay-filesystem.md) | Overlay filesystem loader | #66 | done |
| [#68](./000068-quarterly-charge-calculation.md) | Quarterly charge calculation | #66 | done |
| [#69](./000069-dot-export-completion-visualization.md) | DOT export with completion visualization | #66, #68 | done |
| [#70](./000070-allocation-report.md) | Allocation report export | #68 | done |
| [#71](./000071-validation-updates.md) | Validation updates | #66 | done |
| [#72](./000072-specs-and-sample-data.md) | Specs and sample data | #69, #70 | done |
| [#73](./000073-typeahead-completion.md) | Typeahead completion updates | #67 | done |

## Plan

- [x] #66: time/size/capacity parsing
- [x] #67: overlay filesystem
- [x] #68: quarterly charge
- [x] #69: DOT export
- [x] #70: allocation report
- [x] #71: validation
- [x] #72: specs + sample data
- [x] #73: typeahead

## Log

### 2026-04-05

- Created issue from design doc `design/2026-04-03.22-21-53.719.md`
- Implemented all 8 sub-tickets. All tests pass (0 failures). Lint clean (no new warnings)
