---
gate: boundary-review
issue: 376
id_prefix: BR
rounds:
    - reviewer_runs:
        - version: 1
          intent:
            disposable_root: true
            id: 71da2e02-21d7-4490-a05f-4c06d27ae4de
            repository: github.com/xianxu/parley.nvim
            issue_id: "000376"
            recipe: small-diff-review
            round: 1
            attempt: 1
            agent: claude
            root: /Users/xianxu/Library/Caches/sdlc/review-checkouts/132c5289267ef4e1
            reviewed_head: 59a4ed85ee00dd1ee9cb85aa2e02c85581a4dd52
            slot: parley.nvim:3
            requested_at: "2026-10-17T14:21:39.201718Z"
          phase: finished
          pid: 45019
          started_at: "2026-10-17T14:21:39.297486Z"
          finished_at: "2026-10-17T14:26:50.740983Z"
          session_id: f1f03b33-2e60-40d4-818d-aaeba57a37f0
          outcome: returned
      actual_inputs:
        version: 1
        method: active-time-v3-engagement-v1
        repository: github.com/xianxu/parley.nvim
        code_head: 59a4ed85ee00dd1ee9cb85aa2e02c85581a4dd52
        tracker_head: 5e925694b39198dd5fc93112cbd94e63fe5dbeeb
        branch_point: 7d1f54b2c00d84e3324b738e405d4959393274ea
        since: "2026-10-17T07:18:15-07:00"
        until: "2026-10-17T07:21:18-07:00"
        brain_root: /Users/xianxu/workspace/brain
        gap_minutes: 15
        commit_weight: 1
        include_assistant: true
        engagements:
            - start: "2026-10-17T07:18:15-07:00"
              end: "2026-10-17T07:21:18-07:00"
              began: "2026-10-17T07:18:15-07:00"
              roots:
                - /Users/xianxu/workspace/worktree/parley.nvim-slot3/parley.nvim
        sources:
            - harness: claude
              id: 996b651e-5e17-47f4-9815-33d9ff25fe0d
              cwd: /Users/xianxu/workspace/worktree/parley.nvim-slot3/parley.nvim
              digest: cb1aab4bd5bfdc6cd2d25d4a9c3f5bfd90d2e4572418f75d321292ddd75666c1
              started: "2026-10-15T18:27:53.241Z"
              spawned: false
              bytes: 25550476
              windows:
                - start: "2026-10-17T07:18:15-07:00"
                  end: "2026-10-17T07:21:18-07:00"
      "n": 1
      timestamp: "2026-10-17T07:26:51-07:00"
      dispatched: "2026-10-17T07:21:39-07:00"
      agent: claude
      findings:
        - kind: defect
          id: BR-1
          severity: Important
          title: Done-when clause 2 (deterministic regression for the atomic vms.json write) not delivered and not revised
          detail: 'With fake_tart:67-69 reverted to statefile.write_text, every spec still passes, so the observed empty-vms.json flake (issue 376) is unpinned. The only new test pins the exec-on-stopped-VM check (verified: removing fake_tart:48-49 fails it; 17/1). Family members in window: atomic replace (fake_tart:67-69), exclusive flock (fake_tart:22-23), lock-protected calls.jsonl append (fake_tart:25-26). Pin them deterministically (FAKE_TART_WRITE_PAUSE hook between staged write and os.replace while the spec asserts state() still decodes; spec-held flock on vms.lock blocking a fake call) or add a Revisions entry narrowing Done-when, since the current text claims a fails-before/passes-after test that does not exist (ARCH-PURPOSE).'
          family: done-when-clause-unpinned
          round: 1
        - kind: defect
          id: BR-2
          severity: Minor
          title: The claim that real tart exits 1 on exec of a non-running VM is untested against real tart
          detail: fake_tart:7 docstring and fake_tart:48-49 (and the Plan line) assert parity with real tart; stop/delete have a live conformance case at packaging_vm_spec.lua:39-52, exec does not. Consider extending that conformance case.
          family: fixture-conformance-claim-unverified
          round: 1
      recipe: small-diff-review
      isolation: fenced
      blocked: true
    - reviewer_runs:
        - version: 1
          intent:
            disposable_root: true
            id: 142e537d-c3dc-4246-a675-a05d58ae1f78
            repository: github.com/xianxu/parley.nvim
            issue_id: "000376"
            recipe: small-diff-review
            round: 2
            attempt: 1
            agent: claude
            root: /Users/xianxu/Library/Caches/sdlc/review-checkouts/7c23086cbbfb5dc1
            reviewed_head: 9a2a54c3aed9aee6d7142fb7a85d951bc5918516
            slot: parley.nvim:3
            requested_at: "2026-10-17T14:29:57.1164Z"
          phase: finished
          pid: 21950
          started_at: "2026-10-17T14:29:57.395033Z"
          finished_at: "2026-10-17T14:34:34.793342Z"
          session_id: 5c144ee8-8f05-45b2-be9e-6542c8046442
          outcome: returned
      actual_inputs:
        version: 1
        method: active-time-v3-engagement-v1
        repository: github.com/xianxu/parley.nvim
        code_head: 9a2a54c3aed9aee6d7142fb7a85d951bc5918516
        tracker_head: 5e925694b39198dd5fc93112cbd94e63fe5dbeeb
        branch_point: 7d1f54b2c00d84e3324b738e405d4959393274ea
        since: "2026-10-17T07:18:15-07:00"
        until: "2026-10-17T07:29:11-07:00"
        brain_root: /Users/xianxu/workspace/brain
        gap_minutes: 15
        commit_weight: 1
        include_assistant: true
        engagements:
            - start: "2026-10-17T07:18:15-07:00"
              end: "2026-10-17T07:29:11-07:00"
              began: "2026-10-17T07:18:15-07:00"
              roots:
                - /Users/xianxu/workspace/worktree/parley.nvim-slot3/parley.nvim
        sources:
            - harness: claude
              id: 996b651e-5e17-47f4-9815-33d9ff25fe0d
              cwd: /Users/xianxu/workspace/worktree/parley.nvim-slot3/parley.nvim
              digest: a975b9f6ec5759d3650d817d4a897652f3d332e0191e2097b47dc52b5fa26b67
              started: "2026-10-15T18:27:53.241Z"
              spawned: false
              bytes: 25639484
              windows:
                - start: "2026-10-17T07:18:15-07:00"
                  end: "2026-10-17T07:29:11-07:00"
        cuts:
            - dispatched: "2026-10-17T07:21:39-07:00"
              finalized: "2026-10-17T07:26:51-07:00"
              finalizing: false
      "n": 2
      timestamp: "2026-10-17T07:34:35-07:00"
      dispatched: "2026-10-17T07:29:57-07:00"
      agent: claude
      dispose:
        - id: BR-1
          disposition: addressed
          note: 'Verified by mutation: reverting to statefile.write_text (no os.replace) fails "a reader never sees a torn state file"; removing fcntl.flock fails "a call overlapping another loses neither update"; head is 20/20.'
          round: 2
        - id: BR-2
          disposition: not-addressed
          note: Still Minor and non-blocking. fake_tart docstring and the exec check (fake_tart:7, :48-49) still claim real-tart parity; the live conformance case (packaging_vm_spec.lua:39-52) covers only stop/delete. A missing VM on exec exits 1 in the fake, and real tart may exit 2.
          round: 2
      findings:
        - kind: defect
          id: BR-3
          severity: Minor
          title: FAKE_TART_HOLD specs leak a forever-looping fake_tart when an assertion fails before release
          detail: 'packaging_vm_spec.lua:162-166 and :168-178 release the hold only on the happy path; the fixture loop at fake_tart:73-75 has no deadline. Observed: the orphan gate reaped "fake_tart clone image a" after a red run. Release the hold file in after_each, or bound the fixture loop. Both instances in the window are those two specs.'
          family: held-fixture-released-on-failure
          round: 2
        - kind: defect
          id: BR-4
          severity: Minor
          title: The absence wait in the overlap spec asserts nothing
          detail: 'This is the 2nd finding in family done-when-clause-unpinned. The rule: every labelled wait or claim in a spec should have an assertion that observes it. Here, packaging_vm_spec.lua:173 waits 200ms under an absence label but never checks that the second call is blocked; assert that calls.jsonl has no clone of b yet. This is the only such site in the window.'
          family: done-when-clause-unpinned
          round: 2
      recipe: small-diff-review
      isolation: fenced
      reviewed: 9a2a54c3aed9aee6d7142fb7a85d951bc5918516
      blocked: false
---

# Gate ledger — parley.nvim#376 (boundary-review)

Findings this gate raised, the stable ids the binary assigned them, and how
later rounds disposed of them. Generated — edit the gate, not this file.

## Round 1 — 2026-10-17T07:26:51-07:00 (claude) — BLOCKED

### Raised

- **BR-1** [Important] `done-when-clause-unpinned` (kind: defect) Done-when clause 2 (deterministic regression for the atomic vms.json write) not delivered and not revised
  With fake_tart:67-69 reverted to statefile.write_text, every spec still passes, so the observed empty-vms.json flake (issue 376) is unpinned. The only new test pins the exec-on-stopped-VM check (verified: removing fake_tart:48-49 fails it; 17/1). Family members in window: atomic replace (fake_tart:67-69), exclusive flock (fake_tart:22-23), lock-protected calls.jsonl append (fake_tart:25-26). Pin them deterministically (FAKE_TART_WRITE_PAUSE hook between staged write and os.replace while the spec asserts state() still decodes; spec-held flock on vms.lock blocking a fake call) or add a Revisions entry narrowing Done-when, since the current text claims a fails-before/passes-after test that does not exist (ARCH-PURPOSE).
- **BR-2** [Minor] `fixture-conformance-claim-unverified` (kind: defect) The claim that real tart exits 1 on exec of a non-running VM is untested against real tart
  fake_tart:7 docstring and fake_tart:48-49 (and the Plan line) assert parity with real tart; stop/delete have a live conformance case at packaging_vm_spec.lua:39-52, exec does not. Consider extending that conformance case.

## Round 2 — 2026-10-17T07:34:35-07:00 (claude) — passed

### Disposed

- BR-1 — addressed — Verified by mutation: reverting to statefile.write_text (no os.replace) fails "a reader never sees a torn state file"; removing fcntl.flock fails "a call overlapping another loses neither update"; head is 20/20.
- BR-2 — not-addressed — Still Minor and non-blocking. fake_tart docstring and the exec check (fake_tart:7, :48-49) still claim real-tart parity; the live conformance case (packaging_vm_spec.lua:39-52) covers only stop/delete. A missing VM on exec exits 1 in the fake, and real tart may exit 2.

### Raised

- **BR-3** [Minor] `held-fixture-released-on-failure` (kind: defect) FAKE_TART_HOLD specs leak a forever-looping fake_tart when an assertion fails before release
  packaging_vm_spec.lua:162-166 and :168-178 release the hold only on the happy path; the fixture loop at fake_tart:73-75 has no deadline. Observed: the orphan gate reaped "fake_tart clone image a" after a red run. Release the hold file in after_each, or bound the fixture loop. Both instances in the window are those two specs.
- **BR-4** [Minor] `done-when-clause-unpinned` (kind: defect) The absence wait in the overlap spec asserts nothing
  This is the 2nd finding in family done-when-clause-unpinned. The rule: every labelled wait or claim in a spec should have an assertion that observes it. Here, packaging_vm_spec.lua:173 waits 200ms under an absence label but never checks that the second call is blocked; assert that calls.jsonl has no clone of b yet. This is the only such site in the window.

## Open findings

- **BR-2** [Minor] `fixture-conformance-claim-unverified` (kind: defect) The claim that real tart exits 1 on exec of a non-running VM is untested against real tart
- **BR-3** [Minor] `held-fixture-released-on-failure` (kind: defect) FAKE_TART_HOLD specs leak a forever-looping fake_tart when an assertion fails before release
- **BR-4** [Minor] `done-when-clause-unpinned` (kind: defect) The absence wait in the overlap spec asserts nothing
