---
id: 000426
status: open
deps: []
github_issue:
created: 2026-10-23
updated: 2026-10-23
estimate_hours:
collaboration-mode: collaboration
card_mirror: '64364945a99e017b9f2c9a67aa74fb6c316a385a' # card fields mirrored from issue-cards; edit via sdlc
flake_tests: ["lua:tests/integration/agentic_document_owned_move_spec.lua#registered ordinary Markdown through Parley move doors refuses overlapping geometry before any effects: new-in-source-side children=true native=false modified=false", "lua:tests/integration/agentic_document_owned_move_spec.lua#registered ordinary Markdown through Parley move doors refuses overlapping geometry before any effects: new-in-source-side children=true native=true modified=false", "lua:tests/integration/agentic_document_owned_move_spec.lua#registered ordinary Markdown through Parley move doors refuses overlapping geometry before any effects: new-in-source-side children=true native=true modified=true"]
---

# Owned-move overlapping-geometry refusal snapshot flake

## Problem

`tests/integration/agentic_document_owned_move_spec.lua`, case `registered ordinary Markdown through Parley move doors refuses overlapping geometry before any effects: new-in-source-side ...`, fails intermittently at :162: "refusal must preserve every file, directory, lock, journal and cache byte". The tree snapshot taken after the refusal differs from the one taken before it. The snapshot includes the fake editor's `registry.json.editor-*` files and `state/document-cache`/`document-leases`, so an effect from a background process may land between the two snapshots.

## Spec

Find which byte changes between the snapshots and what writes it. Decide whether the refusal really leaves an effect (a product bug) or the snapshot races a background write that isn't the refusal's (a fixture bug). Fix the cause, not the timing.

## Done when

- The differing entry and the process that writes it are named, with evidence.
- The case can't fail from that race, and a negative control shows it still catches a refusal that leaves an effect.

## Plan

- [ ]

## Log

2026-10-23 (found during #414): it failed in the recorded suite on parley 88fedfd8 (variant `children=true native=true modified=true`, attempt 7cd79e2bae17dc53b8944d14e9f0b892). It reproduces on pure main 20f3513b: 1 failure in 6 runs of this spec on an idle machine (variant `children=true native=false modified=false`). On the #414 head, 1 in 3 runs (`children=true native=true modified=false`). So it predates #414.

2026-10-24 (found during #427's merge, parley.nvim:1): a second failure shape, at :99 rather than :162. The merged suite on 371c0ff2 failed on nvim 0.11.7 (compat pass) in variant `children=true native=false modified=true`, attempt 3fdc60f991f4dc13b76dd4537967bd78: complete_tree's walk raised `.../registry.json.editor-pid.27702.tmp: No such file or directory`. The walk lists a directory with fs_scandir and then opens each entry; the fake editor endpoint (tests/fixtures/fake_couch_editor.py) writes `registry.json.editor-pid` by temp file plus rename, so the temp file was listed and then renamed away before the open. That names one background writer inside the snapshot root: the editor endpoint's pid file, written concurrently with the snapshot, which also fits the :162 shape if the pid file (or another endpoint file) lands between the two snapshots. The main baseline and the 0.12.5 pass of the same spec passed on that run. Registered this variant on #426.
