---
id: 000362
status: open
deps: [parley.nvim#319]
github_issue:
created: 2026-10-16
updated: 2026-10-16
estimate_hours:
card_mirror: '094886e63ca3636e5910d9ab1e5743da2f85e2ca' # card fields mirrored from issue-cards; edit via sdlc
---

# Review-protocol sync accepts S2's collaboration-modes export member

## Problem

S2 M1 (ops `universal-agent-input-interface/design.side/01-s2-section-modes.md`, db130ac0) adds a member to ariadne's universal-review `export.json`, still version 1: role `collaboration-modes`, path `collaboration-modes.md`. #319's `scripts/sync-review-protocol.py` is strict and refuses any role outside {round, grammar, adapter, mode} ("invalid member role"). So the next sync after ariadne:2 lands M1 fails until parley accepts the role.

## Spec

- `validate` accepts the role `collaboration-modes`, exactly one when present, still at version 1. Any other unknown role keeps refusing.
- The member goes into the package snapshot like round and grammar, with its byte count and SHA256 checked. The generated `SKILL.md` composes it after the round and the grammar and before the Parley-owned `local-adapter.md`.
- `examples/` is not exported and not synced.

## Done when

- `tests/unit/review_protocol_export_test.py` covers: an export with the role syncs and composes it in that order; a duplicate refuses; a still-unknown role refuses.
- The sync against ariadne's M1 export updates `lua/parley/skills/review/` and `--check` is clean.

## Plan

- [ ]

## Log

- Filed by parley.nvim:4 as S2's design owner, from ariadne:2's question on the export member. It depends on #319 landing (the sync lives there) and on ariadne's M1 export.
