---
id: 000058
status: done
deps: [54]
created: 2026-04-04
updated: 2026-04-04
---

# vision depends_on omnifunc completion

Custom omnifunc (or nvim-cmp source) that provides namespace-aware autocomplete when editing `depends_on` fields in vision YAML files.

Parses all YAML files in the vision directory, builds the full namespaced ID list (`sync.auth_rewrite`, `px.mobile_app`), and offers completions contextually:
- Inside `depends_on: [...]` → complete with IDs
- Bare prefix → local namespace IDs first, then cross-namespace
- Shows namespace.id format for cross-file refs

Reuses the parser and ID resolution from #53 and #54.

Parent: #52

## Done when

- Completion triggers inside `depends_on` fields in `*.yaml` files under vision_dir
- Lists all valid initiative IDs (namespaced)
- Local namespace IDs shown without prefix, cross-namespace with prefix
- Works with `ctrl-x ctrl-o` (omnifunc) or nvim-cmp if available
- ~50-80 lines of Lua

## Plan

- [x] Implement `M.omnifunc(findstart, base)` in `lua/parley/vision.lua`
- [x] Detect cursor context: only complete inside `depends_on` lines
- [x] Load and parse all vision YAMLs for candidate list via `get_all_ids()`
- [x] Set `omnifunc` via `BufRead`/`BufNewFile` autocmd for `*.yaml` files in vision_dir
- [x] Matches both full IDs and bare name parts

## Log

### 2026-04-04

