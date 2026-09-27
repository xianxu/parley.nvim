---
id: '000061'
status: done
created: 2026-04-04
updated: 2026-04-04
actual_hours: N/A
---

# vision auto-complete depends_on

## Problem

Auto-trigger completion when typing inside `depends_on: [...]` brackets in vision YAML files, instead of requiring manual `Ctrl-X Ctrl-O`.

Additionally, prefer local (bare) names for same-namespace references. When the current file is `sync.yaml` and a candidate is `sync.auth_service_rewrite`, offer `auth_service_rewrite` (not `sync.auth_service_rewrite`). Cross-namespace refs should still show the full namespaced ID.

Parent: #52
Builds on: #58
