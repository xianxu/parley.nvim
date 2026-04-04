---
id: 000052
status: done
deps: []
created: 2026-04-03
updated: 2026-04-03
---

# company vision tracker

check ../design/2026-04-03.07-16-59.100.md, and make a plan first. We will create sub tickets based on your research and design. 

## Done when

- All sub-tickets completed and verified
- Can parse a vision directory of YAML files, validate across files, export CSV and DOT graph
- Cross-file autocomplete works for depends_on fields

## Plan

- [x] #53 — Vision YAML parser (parse list-of-maps format into Lua tables)
- [x] #54 — ID resolution & validation (namespaced prefix matching, cycle detection, dangling refs)
- [x] #55 — CSV export (spreadsheet for TPMs)
- [x] #56 — DOT graph export (Graphviz dependency visualization)
- [x] #57 — Neovim commands & integration (`:ParleyVision*` commands, config, picker)
- [x] #58 — Cross-file omnifunc completion for depends_on fields
- [x] #59 — Vision finder (float picker for browsing initiatives)

Implementation order: 53 → 54 → 55+56 parallel → 57+58 parallel

## Log

### 2026-04-04

Created sub-tickets from design conversation in `design/2026-04-03.07-16-59.100.md`.

Key decisions:
- Purpose-built YAML parser (not full library)
- Multi-file: directory of YAML files, filename is namespace (e.g. `px.yaml` → `px.some_project`)
- Prefix-matching IDs from snake_case names, namespaced across files
- Local refs within same file (just prefix), cross-file refs use namespace (`px.mobile`)
- CSV as first output (TPM-friendly)
- Custom omnifunc completion for depends_on fields (option 3 — semantic, namespace-aware)

### 2026-04-03

