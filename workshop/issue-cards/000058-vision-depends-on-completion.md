---
id: '000058'
status: done
created: 2026-04-04
updated: 2026-04-04
actual_hours: N/A
---

# vision depends_on omnifunc completion

## Problem

Custom omnifunc (or nvim-cmp source) that provides namespace-aware autocomplete when editing `depends_on` fields in vision YAML files.

Parses all YAML files in the vision directory, builds the full namespaced ID list (`sync.auth_rewrite`, `px.mobile_app`), and offers completions contextually:
- Inside `depends_on: [...]` → complete with IDs
- Bare prefix → local namespace IDs first, then cross-namespace
- Shows namespace.id format for cross-file refs

Reuses the parser and ID resolution from #53 and #54.

Parent: #52
