---
id: '000054'
status: done
created: 2026-04-04
updated: 2026-04-04
actual_hours: N/A
---

# vision ID resolution and validation

## Problem

Implement namespaced prefix-matching ID system and graph validation for vision initiatives.

IDs are namespaced by filename: `px.yaml` containing `"Mobile App"` → full ID `px.mobile_app`.

Resolution rules:
- Within same file: bare prefix works (`mobile` → `px.mobile_app`)
- Cross-file: namespace prefix required (`sync.auth` → `sync.auth_rewrite`)
- Ambiguous or zero match → clear error with all matches listed
- Circular deps detected and reported

Parent: #52
