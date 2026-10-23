---
id: 000426
status: open
created: 2026-10-23
updated: 2026-10-23
estimate_hours:
github_issue:
flake_tests: ["lua:tests/integration/agentic_document_owned_move_spec.lua#registered ordinary Markdown through Parley move doors refuses overlapping geometry before any effects: new-in-source-side children=true native=false modified=false", "lua:tests/integration/agentic_document_owned_move_spec.lua#registered ordinary Markdown through Parley move doors refuses overlapping geometry before any effects: new-in-source-side children=true native=true modified=false", "lua:tests/integration/agentic_document_owned_move_spec.lua#registered ordinary Markdown through Parley move doors refuses overlapping geometry before any effects: new-in-source-side children=true native=true modified=true"]
---

# Owned-move overlapping-geometry refusal snapshot flake

## Problem

`tests/integration/agentic_document_owned_move_spec.lua`, case `registered ordinary Markdown through Parley move doors refuses overlapping geometry before any effects: new-in-source-side ...`, fails intermittently at :162: "refusal must preserve every file, directory, lock, journal and cache byte". The tree snapshot taken after the refusal differs from the one taken before it. The snapshot includes the fake editor's `registry.json.editor-*` files and `state/document-cache`/`document-leases`, so an effect from a background process may land between the two snapshots.
