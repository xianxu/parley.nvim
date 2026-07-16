---
id: 000054
status: done
deps: [53]
created: 2026-04-04
updated: 2026-04-04
---

# vision ID resolution and validation

Implement namespaced prefix-matching ID system and graph validation for vision initiatives.

IDs are namespaced by filename: `px.yaml` containing `"Mobile App"` → full ID `px.mobile_app`.

Resolution rules:
- Within same file: bare prefix works (`mobile` → `px.mobile_app`)
- Cross-file: namespace prefix required (`sync.auth` → `sync.auth_rewrite`)
- Ambiguous or zero match → clear error with all matches listed
- Circular deps detected and reported

Parent: #52

## Done when

- IDs are `{namespace}.{snake_case_name}` derived from filename + initiative name
- Bare prefix refs resolve within same namespace first
- Namespaced prefix refs (`ns.prefix`) resolve across files
- Ambiguous prefix → clear error with all matches listed
- Zero match → clear error
- Circular deps detected and reported
- Dangling refs detected and reported
- Unit tests pass

## Plan

- [x] Implement `name_to_id(name)` — snake_case conversion
- [x] Implement `full_id(namespace, name)` — `{namespace}.{snake_case_name}`
- [x] Implement `resolve_ref(ref, current_namespace, all_ids)` — local-first, then global prefix match
- [x] Implement `validate_graph(initiatives)` — resolve all refs, detect cycles (DFS coloring), report errors
- [x] Add unit tests (14 tests: 6 name_to_id, 2 full_id, 7 resolve_ref, 5 validate_graph)

## Log

### 2026-04-04

