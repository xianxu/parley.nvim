---
id: 000055
status: done
deps: [53]
created: 2026-04-04
updated: 2026-04-04
---

# vision CSV export

Generate CSV spreadsheet from parsed vision data. This is the killer first output — TPMs live in spreadsheets.

Columns: `name | type | size | quarter | depends_on`

TPMs will add their own columns (status, owner, notes) in the spreadsheet. The YAML remains the structural source of truth.

Parent: #52

## Done when

- CSV export produces valid CSV with header row
- All initiative fields included
- `depends_on` rendered as comma-separated string within the cell
- Output to file path
- Unit tests pass

## Plan

- [x] Implement `export_csv(initiatives)` in `lua/parley/vision.lua` — returns CSV string
- [x] Handle CSV escaping (commas in values, quotes)
- [x] Add unit tests (3 tests: header+rows, comma escaping, multiple deps)

## Log

### 2026-04-04

- Changed default export behavior: when no path argument is given, CSV exports to `roadmap.csv` at the repo root instead of printing to messages. DOT export similarly defaults to `roadmap.dot`. Explicit path argument still supported.
