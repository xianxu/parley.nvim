---
gate: boundary-review
issue: 400
id_prefix: BR
rounds:
    - reviewer_runs:
        - version: 1
          intent:
            disposable_root: true
            id: 911c58ab-03f3-42b5-984e-dddd63e03545
            repository: github.com/xianxu/parley.nvim
            issue_id: "000400"
            recipe: small-diff-review
            round: 1
            attempt: 1
            agent: claude
            root: /Users/xianxu/Library/Caches/sdlc/review-checkouts/637be2cad62ad5ba
            reviewed_head: 9d5d5f7586131f1f162f46fbfea75abe4d4f7f26
            slot: parley.nvim:3
            requested_at: "2026-10-19T19:36:39.794063Z"
          phase: finished
          pid: 28189
          started_at: "2026-10-19T19:36:39.898306Z"
          finished_at: "2026-10-19T19:56:26.078862Z"
          session_id: cce98557-87ad-433a-a7ac-5e56c2e22bc6
          outcome: returned
      actual_inputs:
        version: 1
        method: active-time-v3-engagement-v1
        repository: github.com/xianxu/parley.nvim
        code_head: 9d5d5f7586131f1f162f46fbfea75abe4d4f7f26
        tracker_head: f5057134017dcb0a22c2211de4f1414f50826488
        branch_point: f5afbf45bf761ff0249f1e6a9d345ebe44814b1d
        since: "2026-10-19T12:01:16-07:00"
        until: "2026-10-19T12:36:13-07:00"
        brain_root: /Users/xianxu/workspace/brain
        gap_minutes: 15
        commit_weight: 1
        include_assistant: true
        engagements:
            - start: "2026-10-19T12:01:16-07:00"
              end: "2026-10-19T12:36:13-07:00"
              began: "2026-10-19T12:01:16-07:00"
              roots:
                - /Users/xianxu/workspace/worktree/parley.nvim-slot3/parley.nvim
        sources:
            - harness: claude
              id: 338ec900-e10b-4fe4-be14-0f0ef1bf7fbd
              slot: parley.nvim:3
              cwd: /Users/xianxu/workspace/worktree/parley.nvim-slot3/parley.nvim
              digest: b9030abde3a242b84af551f6d154fb9f7423c17d4505f23cc46edb9765ed0ae0
              started: "2026-10-18T22:09:43.273Z"
              spawned: false
              bytes: 8012686
              windows:
                - start: "2026-10-19T12:01:16-07:00"
                  end: "2026-10-19T12:36:13-07:00"
      "n": 1
      timestamp: "2026-10-19T12:56:34-07:00"
      dispatched: "2026-10-19T12:36:39-07:00"
      agent: claude
      reviewer: claude (anthropic; author anthropic)
      findings:
        - kind: defect
          id: BR-1
          severity: Important
          title: A timed-out status probe clears the band's owed state; the Spec says it keeps it
          detail: 'In session_sync.lua:405-420 a nil status (timeout) makes since nil, so s.owed gets set to nil and refresh(buf) drops the owed minutes. The Spec''s timeout table says the band keeps its last owed state. Family sweep: the actors query (:428) and own_slot behave as the Spec says; only the status query diverges. Fix: on nil status, clear s.probing and return before updating s.owed, and add a test that an owed band survives a status timeout. Or correct the Spec table.'
          family: spec-claim-diverges-from-code
          round: 1
        - kind: defect
          id: BR-2
          severity: Important
          title: couch.DEADLINE_MS uses the shipped agentic_submit_timeout_ms, not the user's configured value
          detail: 'couch.lua:14 reads require("parley.config") once at load time, while the registry and agentic_document submits use document_registry.config_ms (user override first). A user who raised the budget gets legacy submits killed and reported unconfirmed at 15 s. ARCH-DRY: resolve the default per call through a shared config_ms, and use the same value in the session_sync.lua:866 message.'
          family: config-read-single-source
          round: 1
        - kind: defect
          id: BR-3
          severity: Minor
          title: couch.timed_out requires signal 15; a child that traps TERM and exits 0 reads as failed
          detail: Neovim sets code 124 whenever its timer fired and the exit code was 0 or 1, whatever the signal. Checking obj.code == 124 alone would be more robust. The real couch binary dies by the signal, so this is low impact.
          family: timeout-detection-predicate
          round: 1
      recipe: small-diff-review
      isolation: checkout
      blocked: true
    - reviewer_runs:
        - version: 1
          intent:
            disposable_root: true
            id: 56294bd1-c2ca-44c7-8a11-7e23f60f7aa7
            repository: github.com/xianxu/parley.nvim
            issue_id: "000400"
            recipe: small-diff-review
            round: 2
            attempt: 1
            agent: claude
            root: /Users/xianxu/Library/Caches/sdlc/review-checkouts/5dff3a2815417e27
            reviewed_head: 5b58f710009b8d7191052e9908c7b57da51fbbf8
            slot: parley.nvim:3
            requested_at: "2026-10-19T20:16:23.456289Z"
          phase: finished
          pid: 46937
          started_at: "2026-10-19T20:16:23.550931Z"
          finished_at: "2026-10-19T20:23:51.274626Z"
          session_id: 069186f2-920b-4347-9950-0286b567b407
          outcome: returned
      actual_inputs:
        version: 1
        method: active-time-v3-engagement-v1
        repository: github.com/xianxu/parley.nvim
        code_head: 5b58f710009b8d7191052e9908c7b57da51fbbf8
        tracker_head: f5057134017dcb0a22c2211de4f1414f50826488
        branch_point: f5afbf45bf761ff0249f1e6a9d345ebe44814b1d
        since: "2026-10-19T12:01:16-07:00"
        until: "2026-10-19T13:15:35-07:00"
        brain_root: /Users/xianxu/workspace/brain
        gap_minutes: 15
        commit_weight: 1
        include_assistant: true
        engagements:
            - start: "2026-10-19T12:01:16-07:00"
              end: "2026-10-19T13:15:35-07:00"
              began: "2026-10-19T12:01:16-07:00"
              roots:
                - /Users/xianxu/workspace/worktree/parley.nvim-slot3/parley.nvim
        sources:
            - harness: claude
              id: 338ec900-e10b-4fe4-be14-0f0ef1bf7fbd
              slot: parley.nvim:3
              cwd: /Users/xianxu/workspace/worktree/parley.nvim-slot3/parley.nvim
              digest: 716ce23b8615f95112cf5cd51c39af67946b55df31c5b74a9d6097769f69b9e4
              started: "2026-10-18T22:09:43.273Z"
              spawned: false
              bytes: 8566628
              windows:
                - start: "2026-10-19T12:01:16-07:00"
                  end: "2026-10-19T13:15:35-07:00"
        cuts:
            - dispatched: "2026-10-19T12:36:39-07:00"
              finalized: "2026-10-19T12:56:34-07:00"
              finalizing: false
      "n": 2
      timestamp: "2026-10-19T13:24:00-07:00"
      dispatched: "2026-10-19T13:16:23-07:00"
      agent: claude
      reviewer: claude (anthropic; author anthropic)
      dispose:
        - id: BR-1
          disposition: addressed
          note: Revisions entry corrects the Spec row; a nil status reads as nothing owed like every failed status (session_sync.lua:405-420), which is consistent with pair 437's documented rule.
          round: 2
        - id: BR-2
          disposition: addressed
          note: couch.deadline_ms reads document_registry.config_ms per call (couch.lua:17-19); the unit spec "follows the user's submit budget, read per call" pins it; the session_sync notice uses the stderr couch.send formats.
          round: 2
        - id: BR-3
          disposition: addressed
          note: couch.timed_out is obj.code == 124 alone (couch.lua:43-45); the unit spec asserts code 124 with signal 0 counts as timed out.
          round: 2
      findings:
        - kind: defect
          id: BR-4
          severity: Minor
          title: Spec and Plan body still state the round-1 design the Revisions replaced
          detail: 'This is the 2nd finding in this family. The rule: when a Revision replaces a Spec or Plan claim, edit or strike the replaced sentence where it stands. Instances: Spec paragraph 1 (couch.DEADLINE_MS, shipped 15000); Spec table ping/violation and legacy-submit rows (default, but sends get 3x); status row (the band keeps its last owed state); ARCH-CONSTRAINTS (at most 15 s, but sends live up to 45 s); Plan item 1 (DEADLINE_MS, code 124 with signal 15).'
          family: spec-claim-diverges-from-code
          round: 2
      recipe: small-diff-review
      isolation: checkout
      reviewed: 5b58f710009b8d7191052e9908c7b57da51fbbf8
      blocked: false
---

# Gate ledger — parley.nvim#400 (boundary-review)

Findings this gate raised, the stable ids the binary assigned them, and how
later rounds disposed of them. Generated — edit the gate, not this file.

## Round 1 — 2026-10-19T12:56:34-07:00 (claude) — BLOCKED

### Raised

- **BR-1** [Important] `spec-claim-diverges-from-code` (kind: defect) A timed-out status probe clears the band's owed state; the Spec says it keeps it
  In session_sync.lua:405-420 a nil status (timeout) makes since nil, so s.owed gets set to nil and refresh(buf) drops the owed minutes. The Spec's timeout table says the band keeps its last owed state. Family sweep: the actors query (:428) and own_slot behave as the Spec says; only the status query diverges. Fix: on nil status, clear s.probing and return before updating s.owed, and add a test that an owed band survives a status timeout. Or correct the Spec table.
- **BR-2** [Important] `config-read-single-source` (kind: defect) couch.DEADLINE_MS uses the shipped agentic_submit_timeout_ms, not the user's configured value
  couch.lua:14 reads require("parley.config") once at load time, while the registry and agentic_document submits use document_registry.config_ms (user override first). A user who raised the budget gets legacy submits killed and reported unconfirmed at 15 s. ARCH-DRY: resolve the default per call through a shared config_ms, and use the same value in the session_sync.lua:866 message.
- **BR-3** [Minor] `timeout-detection-predicate` (kind: defect) couch.timed_out requires signal 15; a child that traps TERM and exits 0 reads as failed
  Neovim sets code 124 whenever its timer fired and the exit code was 0 or 1, whatever the signal. Checking obj.code == 124 alone would be more robust. The real couch binary dies by the signal, so this is low impact.

## Round 2 — 2026-10-19T13:24:00-07:00 (claude) — passed

### Disposed

- BR-1 — addressed — Revisions entry corrects the Spec row; a nil status reads as nothing owed like every failed status (session_sync.lua:405-420), which is consistent with pair 437's documented rule.
- BR-2 — addressed — couch.deadline_ms reads document_registry.config_ms per call (couch.lua:17-19); the unit spec "follows the user's submit budget, read per call" pins it; the session_sync notice uses the stderr couch.send formats.
- BR-3 — addressed — couch.timed_out is obj.code == 124 alone (couch.lua:43-45); the unit spec asserts code 124 with signal 0 counts as timed out.

### Raised

- **BR-4** [Minor] `spec-claim-diverges-from-code` (kind: defect) Spec and Plan body still state the round-1 design the Revisions replaced
  This is the 2nd finding in this family. The rule: when a Revision replaces a Spec or Plan claim, edit or strike the replaced sentence where it stands. Instances: Spec paragraph 1 (couch.DEADLINE_MS, shipped 15000); Spec table ping/violation and legacy-submit rows (default, but sends get 3x); status row (the band keeps its last owed state); ARCH-CONSTRAINTS (at most 15 s, but sends live up to 45 s); Plan item 1 (DEADLINE_MS, code 124 with signal 15).

## Open findings

- **BR-4** [Minor] `spec-claim-diverges-from-code` (kind: defect) Spec and Plan body still state the round-1 design the Revisions replaced
