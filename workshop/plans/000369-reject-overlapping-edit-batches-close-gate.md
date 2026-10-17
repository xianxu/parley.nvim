---
gate: boundary-review
issue: 369
id_prefix: BR
rounds:
    - reviewer_runs:
        - version: 1
          intent:
            disposable_root: true
            id: 116b8a96-d2af-472d-9f2b-add4f8906332
            repository: github.com/xianxu/parley.nvim
            issue_id: "000369"
            recipe: small-diff-review
            round: 1
            attempt: 1
            agent: claude
            root: /Users/xianxu/Library/Caches/sdlc/review-checkouts/226c39ef00a92b50
            reviewed_head: be2bcad41a9e7bc27fa907b933c7e4993dd862aa
            slot: parley.nvim:3
            requested_at: "2026-10-17T04:07:13.261809Z"
          phase: finished
          pid: 66749
          started_at: "2026-10-17T04:07:13.433011Z"
          finished_at: "2026-10-17T04:09:18.192241Z"
          session_id: e1558855-00d9-4a01-8f19-88fc7030c9e5
          outcome: returned
      actual_inputs:
        version: 1
        method: active-time-v3-engagement-v1
        repository: github.com/xianxu/parley.nvim
        code_head: be2bcad41a9e7bc27fa907b933c7e4993dd862aa
        tracker_head: 74fb3cfcf3e0e530a2caa2c998736bcaa0368001
        branch_point: 3e055bc1e3c11defa75743c020f2698204fb7bcc
        since: "2026-10-16T21:03:50-07:00"
        until: "2026-10-16T21:06:34-07:00"
        brain_root: /Users/xianxu/workspace/brain
        gap_minutes: 15
        commit_weight: 1
        include_assistant: true
        engagements:
            - start: "2026-10-16T21:03:50-07:00"
              end: "2026-10-16T21:06:34-07:00"
              began: "2026-10-16T21:03:50-07:00"
              roots:
                - /Users/xianxu/workspace/worktree/parley.nvim-slot3/parley.nvim
        sources:
            - harness: claude
              id: 996b651e-5e17-47f4-9815-33d9ff25fe0d
              cwd: /Users/xianxu/workspace/worktree/parley.nvim-slot3/parley.nvim
              digest: 16cb89f3fd16a8ab7092e25dcdad7b5eb88e924fe31f5b727922418245b46791
              started: "2026-10-15T18:27:53.241Z"
              spawned: false
              bytes: 20495600
              windows:
                - start: "2026-10-16T21:03:50-07:00"
                  end: "2026-10-16T21:06:34-07:00"
      "n": 1
      timestamp: "2026-10-16T21:09:25-07:00"
      dispatched: "2026-10-16T21:07:13-07:00"
      agent: claude
      findings:
        - kind: defect
          id: BR-1
          severity: Minor
          title: 'Overlap error snippet is the later-positioned edit''s old_string, not edit #second'
          detail: 'skill_edits.lua:62 shows edit.old_string (the edit later in the file) after "edits #first and #second", so the batch {pha, alpha} reads "edits #1 and #2 overlap: pha" where pha is #1. Show both snippets or label whose snippet it is. This is the only pair-naming error in the window.'
          family: error-message-names-wrong-referent
          round: 1
        - kind: defect
          id: BR-2
          severity: Minor
          title: skill_edits.lua header says propose_edits is its one caller; file_transform.lua:44 also calls compute_edits
          detail: This pre-existing comment sits next to the changed code, and a reader trusting it would miss that the async path also inherits the new refusal. Change it to name both callers (propose_edits.handler and tools/file_transform). No other doc claim in the window is affected.
          family: doc-claim-only-caller
          round: 1
      recipe: small-diff-review
      isolation: fenced
      reviewed: be2bcad41a9e7bc27fa907b933c7e4993dd862aa
      blocked: false
    - reviewer_runs:
        - version: 1
          intent:
            disposable_root: true
            id: 9e6adc6e-7a89-4784-9b27-e10e1687682a
            repository: github.com/xianxu/parley.nvim
            issue_id: "000369"
            recipe: fix-review
            round: 2
            attempt: 1
            agent: claude
            root: /Users/xianxu/Library/Caches/sdlc/review-checkouts/0a856e0cd0a1f7da
            reviewed_head: 6184b45993c76622407b6a68bbdd97f7fb62bff9
            slot: parley.nvim:3
            requested_at: "2026-10-17T04:10:33.683113Z"
          phase: finished
          pid: 97542
          started_at: "2026-10-17T04:10:33.880285Z"
          finished_at: "2026-10-17T04:11:40.673704Z"
          session_id: 21d0c211-d9dd-40aa-b7e5-0699115c0e46
          outcome: returned
      actual_inputs:
        version: 1
        method: active-time-v3-engagement-v1
        repository: github.com/xianxu/parley.nvim
        code_head: 6184b45993c76622407b6a68bbdd97f7fb62bff9
        tracker_head: 546fc4fee3bda004a08b168c87e9471acf068425
        branch_point: 3e055bc1e3c11defa75743c020f2698204fb7bcc
        since: "2026-10-16T21:03:50-07:00"
        until: "2026-10-16T21:10:09-07:00"
        brain_root: /Users/xianxu/workspace/brain
        gap_minutes: 15
        commit_weight: 1
        include_assistant: true
        engagements:
            - start: "2026-10-16T21:03:50-07:00"
              end: "2026-10-16T21:10:09-07:00"
              began: "2026-10-16T21:03:50-07:00"
              roots:
                - /Users/xianxu/workspace/worktree/parley.nvim-slot3/parley.nvim
        sources:
            - harness: claude
              id: 996b651e-5e17-47f4-9815-33d9ff25fe0d
              cwd: /Users/xianxu/workspace/worktree/parley.nvim-slot3/parley.nvim
              digest: 9f12fe566dd81c6217af42d835ac99eaffb2c483c0e30b36aa1c9a6589721c80
              started: "2026-10-15T18:27:53.241Z"
              spawned: false
              bytes: 20561920
              windows:
                - start: "2026-10-16T21:03:50-07:00"
                  end: "2026-10-16T21:10:09-07:00"
        cuts:
            - dispatched: "2026-10-16T21:07:13-07:00"
              finalized: "2026-10-16T21:09:25-07:00"
              finalizing: true
      "n": 2
      timestamp: "2026-10-16T21:11:41-07:00"
      dispatched: "2026-10-16T21:10:33-07:00"
      agent: claude
      dispose:
        - id: BR-1
          disposition: addressed
          note: 'skill_edits.lua:60-65 now shows "edits #a (snipA) and #b (snipB) overlap", with each snippet next to its own batch number. Exact-message asserts in skill_edits_spec (both orders), propose_edits and async_builtin specs fail with the base engine (6+1+1 red) and pass at head.'
          round: 2
        - id: BR-2
          disposition: addressed
          note: The header now names tools/file_transform as the one caller. A grep confirms file_transform.lua:44 is the only compute_edits call site, and propose_edits.lua:48 and :58 route through file_transform.
          round: 2
      recipe: fix-review
      isolation: fenced
      reviewed: 6184b45993c76622407b6a68bbdd97f7fb62bff9
      blocked: false
---

# Gate ledger — parley.nvim#369 (boundary-review)

Findings this gate raised, the stable ids the binary assigned them, and how
later rounds disposed of them. Generated — edit the gate, not this file.

## Round 1 — 2026-10-16T21:09:25-07:00 (claude) — passed

### Raised

- **BR-1** [Minor] `error-message-names-wrong-referent` (kind: defect) Overlap error snippet is the later-positioned edit's old_string, not edit #second
  skill_edits.lua:62 shows edit.old_string (the edit later in the file) after "edits #first and #second", so the batch {pha, alpha} reads "edits #1 and #2 overlap: pha" where pha is #1. Show both snippets or label whose snippet it is. This is the only pair-naming error in the window.
- **BR-2** [Minor] `doc-claim-only-caller` (kind: defect) skill_edits.lua header says propose_edits is its one caller; file_transform.lua:44 also calls compute_edits
  This pre-existing comment sits next to the changed code, and a reader trusting it would miss that the async path also inherits the new refusal. Change it to name both callers (propose_edits.handler and tools/file_transform). No other doc claim in the window is affected.

## Round 2 — 2026-10-16T21:11:41-07:00 (claude) — passed

### Disposed

- BR-1 — addressed — skill_edits.lua:60-65 now shows "edits #a (snipA) and #b (snipB) overlap", with each snippet next to its own batch number. Exact-message asserts in skill_edits_spec (both orders), propose_edits and async_builtin specs fail with the base engine (6+1+1 red) and pass at head.
- BR-2 — addressed — The header now names tools/file_transform as the one caller. A grep confirms file_transform.lua:44 is the only compute_edits call site, and propose_edits.lua:48 and :58 route through file_transform.

## Open findings

(none — every finding has been disposed)
