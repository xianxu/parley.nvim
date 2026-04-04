---
id: 000061
status: open
deps: [58]
created: 2026-04-04
updated: 2026-04-04
---

# vision auto-complete depends_on

Auto-trigger completion when typing inside `depends_on: [...]` brackets in vision YAML files, instead of requiring manual `Ctrl-X Ctrl-O`.

Additionally, prefer local (bare) names for same-namespace references. When the current file is `sync.yaml` and a candidate is `sync.auth_service_rewrite`, offer `auth_service_rewrite` (not `sync.auth_service_rewrite`). Cross-namespace refs should still show the full namespaced ID.

Parent: #52
Builds on: #58

## Done when

- Completion menu auto-appears when typing inside `depends_on: [...]`
- Local namespace candidates shown as bare names (e.g. `auth_service_rewrite`)
- Cross-namespace candidates shown as full IDs (e.g. `px.mobile_app_v2`)
- No regression on manual `Ctrl-X Ctrl-O` trigger
- Existing omnifunc tests still pass

## Plan

- [ ] Detect typing context inside `depends_on: [...]` and auto-trigger completion
- [ ] Determine current file's namespace from filename
- [ ] Strip namespace prefix from candidates that match current namespace
- [ ] Keep full namespaced ID for cross-namespace candidates
- [ ] Test: local refs use bare names, cross-namespace use full IDs

## Log
