---
id: 000362
status: working
deps: [parley.nvim#319]
github_issue:
created: 2026-10-16
updated: 2026-10-16
estimate_hours:
card_mirror: '35486bcfe2e859798f929c26a758c60996822909' # card fields mirrored from issue-cards; edit via sdlc
started: 2026-10-16T16:04:39-07:00
claimant:
    operator: Xian Xu
    machine: 4716879978a7b90f6b583da1716fd0e9
    machine_name: Xian’s MacBook Pro
    workspace: parley.nvim:1
    worktree: /Users/xianxu/workspace/worktree/parley.nvim-slot1/parley.nvim
    repository: github.com/xianxu/parley.nvim
flow: {kind: quick, provenance: inferred, spec: "b8e85993", done: "dec7e7ee"}
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

- [x] Extend pure validation/rendering for an optional singleton at the fixed
  collaboration-modes.md path; compose round, grammar, collaboration modes.
  Keep old version-1 exports and strict rejection of unknown roles.
- [x] Extend owned-output preflight and add Python pure/real-CLI regressions
  for ordering, corruption, duplicate/unknown roles, stale/unsafe output and
  examples exclusion. Verify the existing local source orders its adapter last.
- [ ] Coordinate with ariadne:2 and snapshot the landed S2 M1 export; verify
  --check and standalone packaged composition. Update atlas and README.
- [ ] Run focused/mapped tests and a recorded full suite, close-review, land
  on SHIP and report to the hub.

## Log

- Filed by parley.nvim:4 as S2's design owner, from ariadne:2's question on the export member. It depends on #319 landing (the sync lives there) and on ariadne's M1 export.

### 2026-10-16 — initial plan

Dispatched by ops:0 in delivery 44a5640b-6633-4b68-8a4b-dee8c13e7a32.
Quick plan posted to the hub (70229a8f-43ec-4ee3-80ff-8af4ef1b884f,
submitted); proceeding unless objected. Producer coordination is queued to
ariadne:2, asking for its landed export pin. Build from fresh main after #334.

ARCH-DRY/PURE: reuse validate_manifest/render_snapshot (pure) and existing CLI
preflight (IO); no parallel prompt builder or runtime peer lookup. ARCH-PURPOSE:
consumer chain is export -> snapshot SKILL.md -> review.skill.source -> selected
mode context -> local adapter. Fixed output ownership must include the new file
so --check sees drift and preflight refuses symlinks before any write. The
optional member preserves prior version-1 packages; other unknown roles refuse.
One fixed package file is replaced by each sync, not an accumulating artifact
(ARCH-FUNERAL). Source digests/path validation remain the trust boundary
(ARCH-SECURE). This build-time batch adds no process or state between events
(ARCH-ORDER); input sizes remain the finite manifest/package (ARCH-CONSTRAINTS).
Real scratch source/output trees exercise IO without external services or mocks
(ARCH-MOCK). Do not snapshot an unlanded producer branch.

### 2026-10-16 — consumer implementation verified

The new acceptance tests failed against the old validator (invalid member role);
the minimal validator/renderer/preflight change makes all fifteen Python
contract tests pass. The real CLI cases cover new-member digest corruption,
--check drift without writes, repairs, preserved local adapters, explicit stale
member refusal when syncing an older export, output symlink safety and excluded
examples. Pure composition reverses manifest order and still checks exactly
once after round and grammar. Duplicate, unknown role and wrong path refuse.
The mapped modes/review suite passed with clean process census.

Producer coordination 175d76ec-d041-4afe-ac38-aedffddd563a is submitted to
ariadne:2. Own refreshed Ariadne main still exports the old version-1 shape;
its --check passes unchanged, proving backward compatibility. Await the landed
S2 M1 pin before refreshing the snapshot and final recorded full suite/close.
Couch discovery in a login shell temporarily failed; the same bare command in
a non-login shell resolves the installed binary normally. No resend needed.
