---
id: 000331
status: working
deps: []
github_issue:
created: 2026-10-14
updated: 2026-10-14
estimate_hours:
card_mirror: 'a3b41a7dc1de81340fcc072283cacd897e4fdf5a' # card fields mirrored from issue-cards; edit via sdlc
started: 2026-10-14T22:30:57-07:00
claimant:
    operator: Xian Xu
    machine: 4716879978a7b90f6b583da1716fd0e9
    machine_name: Xian’s MacBook Pro
    workspace: parley.nvim:2
    worktree: /Users/xianxu/workspace/worktree/parley.nvim-slot2/parley.nvim
    repository: github.com/xianxu/parley.nvim
flow: {kind: quick, provenance: inferred, spec: "8e0d221a", done: "4e0f18a1"}
---

# session-sync: read couch-owner: (Couch's canonical field) with owner: as the fallback

## Problem

Couch's session-sync contract calls `couch-owner:` the canonical frontmatter field naming a session-sync file's agent
(`owner:` is the older spelling, still read), and ariadne's tl-lead now writes `couch-owner:`. parley reads only
`owner:` (`lua/parley/session_sync.lua:60`), so a file using the canonical name loses its owner in parley: Alt+Return
has no recipient, the band can't name the agent, and owed-response pings stop. The operator (2026-10-14): "make it
consistent to be couch-owner".

## Spec

- parley reads `couch-owner:` first and falls back to `owner:` (the same precedence as Couch).
- Everything that uses the owner (submit recipient, band label, owed pings, quiet detection) goes through that one
  accessor.
- Docs and README name `couch-owner:` as canonical.

## Done when

- A file with only `couch-owner:` submits to that slot and shows it in the band; a file with only `owner:` still works;
  with both, `couch-owner:` wins. Headless tests cover all three.
- The operator's TL status file is switched to `couch-owner:` after this lands (TL does it).

## Plan

- [x] Normalize the owner once in the existing pure parse_header accessor: couch-owner first, owner fallback, exposed as the existing normalized owner field. Reuse header/owner_of and the captured submit header; no second parser or new public API. Update missing-owner diagnostics and module comments to canonical naming.
- [x] TDD: parser cases for canonical-only, legacy-only and conflicting-both. Headless integration matrix checks actual submit recipient, owed band, quiet-owner ping and violation recipient for all three; preserve the existing same-slot refusal tests. Use the filesystem-backed fake_couch seam and real Neovim/file events.
- [x] Update README and atlas examples/contract, including removing atlas's obsolete claim that parley does not read couch-owner. Run make -k test-spec SPEC=modes/session_sync, lint, declared local suite, and sdlc close review.
- [ ] Land on SHIP after required gates; report to TL so the TL can switch the real status file. The TL owns that file migration.

## Core concepts

| Concept | Implementing entity | Kind | Status | Change |
| --- | --- | --- | --- | --- |
| Normalized session owner | lua/parley/session_sync.lua: parse_header | PURE | modified | One canonical selection rule feeds the existing normalized owner consumed by every session-sync flow. |

## Design notes

ARCH-DRY/PURE: add precedence at the existing pure parsing boundary, not in submit/band/ping consumers. ARCH-PURPOSE: enumerate submit validation and sends, band rendering, owed/quiet probing and violation sends; all already read parse_header's normalized owner through header/owner_of or its captured header. Tests exercise that family, including conflicting fields. ARCH-MOCK: reuse filesystem fake Couch, no new subprocess dependency. ARCH-CONSTRAINTS: existing first-40-lines header read and flat parse, one extra table lookup per parse, no new IO. ARCH-SECURE: existing frontmatter parser handles comments/quotes/absent and blank fields; malformed or missing headers retain current refusal. No credentials. ARCH-ORDER: adds no state between events; existing owner snapshot and asynchronous submit validation remain unchanged. ARCH-FUNERAL: creates no durable runtime artifact or handle; only existing parser output gains an alternate source.

## Log

### 2026-10-14
- 2026-10-14: closed — 118 mapped cases pass (43 native, 58 integration, 17 unit), plus declared suite: 428 spec files, lint 724 clean, no survivors; log e4cb385d7540 on e4c74728. Three-variant matrix covers band, quiet ping, same-slot submit and violations. --no-plan-check acknowledges only the post-review publication/report row: TL explicitly directed land on SHIP and owns status-file migration after landing.; review verdict: SHIP

- Root cause: parse_header currently reads only fm.fields.owner. Every owner consumer already derives from its normalized result (directly or through owner_of), so canonical precedence belongs there. Expected quick flow, well below 100 source lines. Claimed from main after #330 landed; refreshed Ariadne substrate to 5c321f59ed35b83bda4f1fc698c83c836ebc22bb before planning.

- Approved by TL (receipt 441e74e5-65d4-424e-8679-defcce8bbba7). Red: canonical-only and conflicting fields failed four integration and two parser cases; legacy-only stayed green. Green after centralized normalization: 43 native + 58 integration + 17 unit = 118 mapped cases; luacheck and diff whitespace clean. All owner reads still derive from parse_header; no duplicate precedence in consumers. Hardened shared wait_sent to require newline-terminated complete payloads for every positive message wait, following the #324/#330 readiness lesson.

- Declared suite passed on e4c74728cdd45369a96c6d8ca929961eeed51290 via sdlc local-check run --name suite: 428 spec files, lint 724 files with 0 warnings/errors, no survivors, 2m9s runtime after 38m1s capacity wait; log sha256 prefix e4cb385d7540. Final Plan row is the post-review publication/report handoff, and the Spec explicitly reserves real status-file migration for the TL after landing; neither is an omitted implementation task.
