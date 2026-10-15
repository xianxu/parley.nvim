---
id: 000330
status: working
deps: []
github_issue:
created: 2026-10-14
updated: 2026-10-14
estimate_hours:
card_mirror: '4aaf08f19b0c9a1d3ed684ad99bb2a4c881bf4b5' # card fields mirrored from issue-cards; edit via sdlc
started: 2026-10-14T21:25:39-07:00
claimant:
    operator: Xian Xu
    machine: 4716879978a7b90f6b583da1716fd0e9
    machine_name: Xian’s MacBook Pro
    workspace: parley.nvim:2
    worktree: /Users/xianxu/workspace/worktree/parley.nvim-slot2/parley.nvim
    repository: github.com/xianxu/parley.nvim
flow: {kind: quick, provenance: inferred, spec: "4c474229", done: "eea4b532"}
---

# session-sync: undo back to the lock's baseline releases the operator lock, even under auto-save

## Problem

After parley.nvim#324, any first edit takes the operator's lock, and an undo releases it only when the buffer
becomes *unmodified*, i.e. equal to the file on disk. The operator runs an immediate normal-mode auto-save, so a `dd`
is written to disk at once; after `u` the buffer differs from disk and the lock stays. The operator (2026-10-14): "`u`
should release the lock if that `u` moves the file to a state of no change."

## Spec

- "No change" means **equal to the content when the operator's lock was taken** (the baseline), not equal to disk.
- On acquiring the operator lock, record the baseline: a hash of the buffer content at that moment (the content the
  agent last wrote or saw).
- After every buffer change, including undo, redo and auto-save, if the buffer content hash equals the baseline,
  **silently release** the operator lock. Auto-save then writes the baseline back, so the disk matches what the agent
  last saw.
- Redo or a new edit away from the baseline takes the lock again (as #324 does).
- #324's rule holds: a pending agent write, deletion or overwrite is reconciled before any release.
- Explicit saves (`:w`) keep their turn semantics as in #324; only content equality with the baseline releases.

## Done when

- With the operator's real immediate auto-save installed before attachment (as in #324's tests): `dd` takes the lock;
  `u` back to the baseline releases it silently, and an agent write then succeeds; `Ctrl-r` takes it again.
- Multi-step edits then undo all the way back release; a partial undo doesn't.
- A pending agent write during the edit is reconciled before release.
- Headless tests with real input order cover each case.

## Plan

- [x] Retain a rolling hash of attached buffer lines. At successful first-edit lock acquisition, freeze the previous (pre-edit) hash as this turn's baseline; saves never move it. Reload refreshes the rolling hash; submit/free clears the turn baseline. A pre-existing lock has no known baseline and cannot auto-release.
- [x] Replace modified/mtime equality as the release predicate with baseline content equality. Keep the latest-edit token, reconcile foreign overwrite/deletion and undecided probes first; any violation retains the lock. If equality leaves unsaved baseline text, write it successfully before deleting the lock so an agent never observes a free turn with stale disk text.
- [x] Native child-editor regressions: auto-save before attachment; dd/undo/redo after initial open and both reload paths; multi-step partial/full undo; explicit-save retention away from baseline and undo-to-baseline release; pending foreign overwrite/deletion/failed preservation and undecided checks. Assert baseline on disk and successful following agent reload after release.
- [ ] Run make -k targeted session-sync tests and declared suite; close review, stage for operator acceptance, then land only after the live check.

## Core concepts

| Concept | Implementing entities | Kind | Status | Change |
| --- | --- | --- | --- | --- |
| Lock baseline | lua/parley/session_sync.lua: content_hash and M.attach | INTEGRATION | new | In-memory pre-edit content hash scoped to the lock this attachment acquired; rolling content hash supplies the pre-edit value because on_lines observes the completed edit. |
| Release reconciliation | lua/parley/session_sync.lua: M.attach | INTEGRATION | modified | Existing deferred token and foreign-write preservation remain authoritative; baseline equality replaces disk equality. |

## Design notes

ARCH-DRY/PURE: reuse native edit attachment and existing disk_changed/violation; hashing deterministic line content adds no alternate writer or lock format. ARCH-PURPOSE: auto-save must never advance the acquisition baseline. ARCH-MOCK: retain fake Couch seam and real child-Neovim/file effects, then operator live check. ARCH-CONSTRAINTS: session markdown keystroke path, at most three SHA-256 hashes over buffer lines per edit (observation, deferred comparison, and post-write verification on successful baseline restoration; linear buffer size), constant retained hashes, no extra subprocesses. ARCH-SECURE: no new persisted input or secrets; unknown existing locks retain protection rather than invent a baseline. ARCH-ORDER: free+edit captures previous hash only on confirmed lock write; held+edit retains baseline; latest deferred equality reconciles disk then saves baseline before confirmed lock deletion; reload replaces rolling hash and invalidates deferred token; submit/free clears baseline. Failed probes/writes retain lock. ARCH-FUNERAL: no new durable artifact; hashes die with attachment/turn; existing lock deletion lifecycle unchanged.

## Log

### 2026-10-14

- #324 landed in PR #236 at 2cf363f1421ce27ab3230099380f999a0a4bdaf6 and its stage was cleared. #327 design is parked via unclaim per the operator priority. Root cause for #330: release tests disk/modified state, which immediate auto-save advances; retain the lock acquisition content instead.

- TL approved the quick-flow design (Couch receipt 6d69262e-b0eb-41ce-b72d-457ec178e6eb). TDD: five new native cases failed on the prior release predicate (three auto-save/reload variants, multi-step undo, explicit-save then baseline undo). With the fix, all initial 102 mapped cases passed; expanded safety matrix is being verified before the full suite.
- Native safety expansion: pending overwrite/deletion/failed preservation now runs with auto-save both enabled and disabled; unknown pre-existing locks and failed baseline saves retain protection. In the ignored/errored classification + auto-save sequence, restoring checks does not necessarily repeat Neovim's disk-change event; tests assert that the lock and exact foreign content remain intact. They do not fabricate another external write to declare recovery.

- Expanded targeted verification passed: make -k test-spec SPEC=modes/session_sync (43 native + 52 integration + 14 unit = 109 cases, 0 failures); luacheck clean and git diff --check clean. Only 26 source lines added.

- Declared full suite passed via sdlc local-check run --name suite on 8f14544a8f2476e9a865236044fcd0d11aaccae0: 428 spec files, lint 724 files with 0 warnings/errors, no surviving processes; run time 2m13s after 43m41s capacity wait; log sha256 prefix fe3545a713a2. TL explicitly directed close review before staging/operator check; final Plan row remains open until live acceptance and landing.

## Revisions

### 2026-10-14 22:23 PDT — close review documentation corrections

- BR-1 (user-docs-match-behavior): README's two stale clauses (unmodified release and saved-text redo) now use the acquisition baseline. Swept README, docs, atlas and module comments; remaining unmodified references describe reload/overwrite handling or the historical Problem, not release.
- BR-2 (core-concept-classification): both Core concepts rows now name implementing entities, INTEGRATION kind and new/modified status.
- BR-3 (documented-work-bounds): correct the maximum from two to three hashes per edit; the third is post-write verification when restored baseline text needs saving. No implementation or Done-when change. Final acceptance/landing Plan row remains open.

## Review log

- Round 1: FIX-THEN-SHIP, but the ledger kept close unfinalized for one Important README finding; also two Minor plan corrections. Verified all three against source and corrected their full instance families. No runtime change; full-suite result remains applicable. Reviewer independently passed all 109 mapped tests.
