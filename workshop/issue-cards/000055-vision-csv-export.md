---
id: '000055'
status: done
created: 2026-04-04
updated: 2026-04-04
actual_hours: N/A
---

# vision CSV export

## Problem

Generate CSV spreadsheet from parsed vision data. This is the killer first output — TPMs live in spreadsheets.

Columns: `name | type | size | quarter | depends_on`

TPMs will add their own columns (status, owner, notes) in the spreadsheet. The YAML remains the structural source of truth.

Parent: #52
