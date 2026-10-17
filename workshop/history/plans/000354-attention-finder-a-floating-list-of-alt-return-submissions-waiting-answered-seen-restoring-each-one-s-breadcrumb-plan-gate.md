---
reviewer_runs:
    - version: 1
      intent:
        id: cd33c49a-96f6-4158-9d7b-05a156019a46
        repository: github.com/xianxu/parley.nvim
        issue_id: "000354"
        recipe: estimate-quality
        round: 1
        attempt: 1
        agent: claude
        root: /Users/xianxu/workspace/worktree/parley.nvim-slot3/parley.nvim
        reviewed_head: 5c82f42800995b41535e33b9923f034d1d849f98
        slot: parley.nvim:3
        requested_at: "2026-10-16T21:41:14.545338Z"
      phase: finished
      pid: 57211
      started_at: "2026-10-16T21:41:14.678049Z"
      finished_at: "2026-10-16T21:41:35.202705Z"
      session_id: 90c11d14-54c6-4cef-b441-ee83b536d8ed
      outcome: returned
gate: plan-quality
issue: 354
id_prefix: PQ
rounds:
    - reviewer_runs:
        - version: 1
          intent:
            id: 1d16309b-e417-450e-a9aa-a6c11d45a62c
            repository: github.com/xianxu/parley.nvim
            issue_id: "000354"
            recipe: plan-quality
            round: 1
            attempt: 1
            agent: claude
            root: /Users/xianxu/workspace/worktree/parley.nvim-slot3/parley.nvim
            reviewed_head: 2739a0f0fdf8ff5e95d9b6ba20f81280c77b5e76
            slot: parley.nvim:3
            requested_at: "2026-10-16T21:36:33.0308Z"
          phase: finished
          pid: 42623
          started_at: "2026-10-16T21:36:33.178027Z"
          finished_at: "2026-10-16T21:37:48.442087Z"
          session_id: 63beb7f6-5e18-48e9-8bae-6484d78ced70
          outcome: returned
      "n": 1
      timestamp: "2026-10-16T14:37:48-07:00"
      agent: claude
      findings:
        - kind: defect
          id: PQ-1
          severity: Important
          title: document_lease.acquire is non-blocking (LOCK_NB returns busy), so it does not serialize two editors; apply has no busy path
          detail: lua/parley/document_lease.lua acquire(namespace, key, options) returns failure('busy') when the lease is held. The plan says the lease serializes concurrent applies, so a concurrent submit record would be silently lost. Specify a bounded retry plus a visible warning on busy, pass the key argument, and test a held lease.
          family: unbacked-existing-behavior-claim
          round: 1
        - kind: defect
          id: PQ-2
          severity: Important
          title: An observed event from a probe that started before a newer submit removes the new ID and falsely marks the entry answered
          detail: The probe starts at t0, a submit records ID2 at t1, and the probe result (without ID2) applies at t2, so the transition removes ID2 as not owed. The observed event must carry the pending IDs (or the time) captured at probe start and remove only those. Add a sequence test with that interleaving (ARCH-ORDER).
          family: stale-observation-applied-to-newer-state
          round: 1
        - kind: defect
          id: PQ-3
          severity: Important
          title: type session-sync files submitted by Alt+Return via session_sync.submit also go through Couch but are neither recorded nor named as a non-goal
          detail: review_send.submit (lua/parley/review_send.lua:140) reaches session_sync.submit, then submit_now and release_and_send (session_sync.lua:744, 802), which sends the same submitted-PATH message. The non-goal says session_sync without Couch, which is a different case. Record in release_and_send's callback, shared by both paths (ARCH-DRY), or state the exclusion with a reason.
          family: purpose-subset-unstated
          round: 1
        - kind: defect
          id: PQ-4
          severity: Minor
          title: Tasks 1, 2, 3 and 5 enumerate test cases in prose instead of one strategy line per risky function
          detail: Compress to strategy lines, e.g. transition over random event sequences, checked by the property that no failure path reaches answered and waiting is never swept.
          family: test-prose-enumeration
          round: 1
        - kind: defect
          id: PQ-5
          severity: Minor
          title: The fake Couch says new or extending if one exists, but tests/helpers/fake_couch.lua and fake_couch_registry.py exist and its send prints no receipt ID
          detail: 'Name the extension: the send emits the receipt line on stdout, and the registry fixture supports Owed and fold.'
          family: vague-plan-item
          round: 1
        - kind: defect
          id: PQ-6
          severity: Minor
          title: The Done-when item breadcrumb restored on jump depends on the unlanded seam from issue 353, which deps does not declare
          family: undeclared-dependency
          round: 1
      blocked: true
    - reviewer_runs:
        - version: 1
          intent:
            id: 9d0acb0e-4a0d-4c48-9708-2e5c27829666
            repository: github.com/xianxu/parley.nvim
            issue_id: "000354"
            recipe: plan-quality
            round: 2
            attempt: 1
            agent: claude
            root: /Users/xianxu/workspace/worktree/parley.nvim-slot3/parley.nvim
            reviewed_head: 5c82f42800995b41535e33b9923f034d1d849f98
            slot: parley.nvim:3
            requested_at: "2026-10-16T21:39:23.472344Z"
          phase: finished
          pid: 49988
          started_at: "2026-10-16T21:39:23.6206Z"
          finished_at: "2026-10-16T21:40:03.602306Z"
          session_id: af54b6ac-7b02-4fb4-8a7c-8ff23f227998
          outcome: returned
      "n": 2
      timestamp: "2026-10-16T14:40:03-07:00"
      agent: claude
      dispose:
        - id: PQ-1
          disposition: addressed
          note: Bounded busy retry, a visible lost-record warning, the key argument passed, and a held-lease test; verified against document_lease.lua:31,92.
          round: 2
        - id: PQ-2
          disposition: addressed
          note: observed carries probed_ids captured at probe start and removes only those; a named interleaving test plus a property check.
          round: 2
        - id: PQ-3
          disposition: addressed
          note: Hook in release_and_send, shared by send_registered (session_sync.lua:844) and submit_now (849); both paths tested end to end.
          round: 2
        - id: PQ-4
          disposition: not-addressed
          note: Tasks 1-3 compressed; Task 5 Step 1 (and Task 4) still enumerate cases in prose. Minor, carried to close.
          round: 2
        - id: PQ-5
          disposition: addressed
          note: Names fake_couch.lua plus fake_couch_registry.py, the receipt line on stdout, Owed append, and the fold helper.
          round: 2
        - id: PQ-6
          disposition: addressed
          note: deps now lists parley.nvim#353; until it lands, restore runs against the injected seam.
          round: 2
      blocked: false
    - reviewer_runs:
        - version: 1
          intent:
            id: 498839a2-87bf-4d7b-8502-5f0e64e8e33b
            repository: github.com/xianxu/parley.nvim
            issue_id: "000354"
            recipe: plan-quality
            round: 3
            attempt: 1
            agent: claude
            root: /Users/xianxu/workspace/worktree/parley.nvim-slot3/parley.nvim
            reviewed_head: 5c82f42800995b41535e33b9923f034d1d849f98
            slot: parley.nvim:3
            requested_at: "2026-10-16T21:40:53.494406Z"
          phase: finished
          pid: 55573
          started_at: "2026-10-16T21:40:53.673347Z"
          finished_at: "2026-10-16T21:41:12.464467Z"
          session_id: 983bc5e5-6019-4a70-8c51-b5201568013a
          outcome: returned
      "n": 3
      timestamp: "2026-10-16T14:41:12-07:00"
      agent: claude
      dispose:
        - id: PQ-4
          disposition: not-addressed
          note: Tasks 1-3 now give strategy lines; Task 5 (and Task 4) still list cases in prose. Minor, carried to close.
          round: 3
      blocked: false
content_hash: 9d83dffae6d8242a70da7bfba17ffea794979bf537fbb8ed6d225b05f0b6e81b
---

# Gate ledger — parley.nvim#354 (plan-quality)

Findings this gate raised, the stable ids the binary assigned them, and how
later rounds disposed of them. Generated — edit the gate, not this file.

## Round 1 — 2026-10-16T14:37:48-07:00 (claude) — BLOCKED

### Raised

- **PQ-1** [Important] `unbacked-existing-behavior-claim` (kind: defect) document_lease.acquire is non-blocking (LOCK_NB returns busy), so it does not serialize two editors; apply has no busy path
  lua/parley/document_lease.lua acquire(namespace, key, options) returns failure('busy') when the lease is held. The plan says the lease serializes concurrent applies, so a concurrent submit record would be silently lost. Specify a bounded retry plus a visible warning on busy, pass the key argument, and test a held lease.
- **PQ-2** [Important] `stale-observation-applied-to-newer-state` (kind: defect) An observed event from a probe that started before a newer submit removes the new ID and falsely marks the entry answered
  The probe starts at t0, a submit records ID2 at t1, and the probe result (without ID2) applies at t2, so the transition removes ID2 as not owed. The observed event must carry the pending IDs (or the time) captured at probe start and remove only those. Add a sequence test with that interleaving (ARCH-ORDER).
- **PQ-3** [Important] `purpose-subset-unstated` (kind: defect) type session-sync files submitted by Alt+Return via session_sync.submit also go through Couch but are neither recorded nor named as a non-goal
  review_send.submit (lua/parley/review_send.lua:140) reaches session_sync.submit, then submit_now and release_and_send (session_sync.lua:744, 802), which sends the same submitted-PATH message. The non-goal says session_sync without Couch, which is a different case. Record in release_and_send's callback, shared by both paths (ARCH-DRY), or state the exclusion with a reason.
- **PQ-4** [Minor] `test-prose-enumeration` (kind: defect) Tasks 1, 2, 3 and 5 enumerate test cases in prose instead of one strategy line per risky function
  Compress to strategy lines, e.g. transition over random event sequences, checked by the property that no failure path reaches answered and waiting is never swept.
- **PQ-5** [Minor] `vague-plan-item` (kind: defect) The fake Couch says new or extending if one exists, but tests/helpers/fake_couch.lua and fake_couch_registry.py exist and its send prints no receipt ID
  Name the extension: the send emits the receipt line on stdout, and the registry fixture supports Owed and fold.
- **PQ-6** [Minor] `undeclared-dependency` (kind: defect) The Done-when item breadcrumb restored on jump depends on the unlanded seam from issue 353, which deps does not declare

## Round 2 — 2026-10-16T14:40:03-07:00 (claude) — passed

### Disposed

- PQ-1 — addressed — Bounded busy retry, a visible lost-record warning, the key argument passed, and a held-lease test; verified against document_lease.lua:31,92.
- PQ-2 — addressed — observed carries probed_ids captured at probe start and removes only those; a named interleaving test plus a property check.
- PQ-3 — addressed — Hook in release_and_send, shared by send_registered (session_sync.lua:844) and submit_now (849); both paths tested end to end.
- PQ-4 — not-addressed — Tasks 1-3 compressed; Task 5 Step 1 (and Task 4) still enumerate cases in prose. Minor, carried to close.
- PQ-5 — addressed — Names fake_couch.lua plus fake_couch_registry.py, the receipt line on stdout, Owed append, and the fold helper.
- PQ-6 — addressed — deps now lists parley.nvim#353; until it lands, restore runs against the injected seam.

## Round 3 — 2026-10-16T14:41:12-07:00 (claude) — passed

### Disposed

- PQ-4 — not-addressed — Tasks 1-3 now give strategy lines; Task 5 (and Task 4) still list cases in prose. Minor, carried to close.

## Open findings

- **PQ-4** [Minor] `test-prose-enumeration` (kind: defect) Tasks 1, 2, 3 and 5 enumerate test cases in prose instead of one strategy line per risky function
