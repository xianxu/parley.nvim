---
gate: boundary-review
issue: 362
id_prefix: BR
rounds:
    - reviewer_runs:
        - version: 1
          intent:
            disposable_root: true
            id: a54f134a-81d2-436e-9624-04f06e3c31fa
            repository: github.com/xianxu/parley.nvim
            issue_id: "000362"
            recipe: small-diff-review
            round: 1
            attempt: 1
            agent: codex
            root: /Users/xianxu/Library/Caches/sdlc/review-checkouts/25a90caf93d724e6
            reviewed_head: 70ec26d438345fa93d0519fb1a8d115e812245af
            slot: parley.nvim:1
            requested_at: "2026-10-17T01:11:06.561409Z"
          phase: finished
          pid: 44706
          started_at: "2026-10-17T01:11:06.669296Z"
          finished_at: "2026-10-17T01:12:51.667835Z"
          session_id: 01a14769-9fd0-79f0-82ca-8113e8801376
          outcome: returned
      actual_inputs:
        version: 1
        method: active-time-v3-engagement-v1
        repository: github.com/xianxu/parley.nvim
        code_head: 70ec26d438345fa93d0519fb1a8d115e812245af
        tracker_head: f5ab523f97d17b6919184e257ef51478683b727b
        branch_point: 75c795b448fbe7fdd8c38785f2c7c64001ef91c4
        since: "2026-10-16T16:04:39-07:00"
        until: "2026-10-16T18:10:53-07:00"
        brain_root: /Users/xianxu/workspace/brain
        gap_minutes: 15
        commit_weight: 1
        include_assistant: true
        engagements:
            - start: "2026-10-16T16:04:39-07:00"
              end: "2026-10-16T18:10:53-07:00"
              began: "2026-10-16T16:04:39-07:00"
              roots:
                - /Users/xianxu/workspace/worktree/parley.nvim-slot1/parley.nvim
        sources:
            - harness: codex
              id: 01a138e8-e0b1-7a60-bb7e-e76aa10a425e
              cwd: /Users/xianxu/workspace/worktree/parley.nvim-slot1/parley.nvim
              digest: 2b618f6bd97dd5719f19d7e3fd037ff68ecfa16f8b698ff58c3b185fdf905b8b
              started: "2026-10-14T05:35:58.09Z"
              spawned: false
              bytes: 27864300
              windows:
                - start: "2026-10-16T16:04:39-07:00"
                  end: "2026-10-16T18:10:53-07:00"
            - harness: codex
              id: 01a146f9-ac61-7822-bc08-cf9d7136b471
              cwd: /Users/xianxu/workspace/worktree/parley.nvim-slot1/parley.nvim
              parent_id: 01a138e8-e0b1-7a60-bb7e-e76aa10a425e
              digest: 5d6d82af37c5a841eed73228ff16cf3920b542368a2670b4bc05a436fe3c8a5a
              started: "2026-10-16T23:08:50.276Z"
              spawned: true
              bytes: 569640
              windows:
                - start: "2026-10-16T23:08:50.276Z"
                  end: "2026-10-16T18:10:53-07:00"
        excluded_brain_sessions: 1
        excluded_brain_minutes: 0.042216666666666666
      "n": 1
      timestamp: "2026-10-16T18:12:54-07:00"
      dispatched: "2026-10-16T18:11:06-07:00"
      agent: codex
      findings:
        - kind: defect
          id: BR-1
          severity: Critical
          title: The imported collaboration contract requires operations the local adapter cannot perform
          detail: "lua/parley/skills/review/collaboration-modes.md:72 requires every discussion question to create a side doc; discussion is now the default even without frontmatter (line 29). Thus an ordinary local \U0001F916[why?] request can no longer be answered consistently: local-adapter.md:10-16 permits only one propose_edits call, and lua/parley/skill_invoke.lua:567-569 forcibly binds that call to the submitted artifact. No available write operation can create the required side doc. Removing the marker and inserting its prescribed link would leave a nonexistent target; answering inline violates the new contract.\nThe complete affected capability family in this window is discussion question/decision-note/nested side-doc creation (lines 72, 105-107, 155-157), chat answer creation and follow-up writes (128-138), cross-document approval folds (93, 202-218), and retry/relink/orphan discovery (205-222). Chat additionally requires a change baseline that local-adapter.md:18-20 explicitly lacks, while marker-free chat submissions are skipped by review/init.lua's existing precheck. These instructions are also embedded in generated SKILL.md. Reconcile the Parley-owned local compatibility policy with these capabilities, document the supported behavior, and add regression coverage for default questions and explicit collaboration/chat handling. ARCH-PURPOSE: successful concatenation does not establish a usable local contract."
          family: prompt-adapter-capability-contract
          round: 1
        - kind: defect
          id: BR-2
          severity: Important
          title: Done-when omits the newly required old-export notice
          detail: workshop/issues/000362-review-protocol-sync-accepts-s2-s-collaboration-modes-export-member.md:33-36 only requires tests and synchronization for an export containing collaboration modes. The revision at lines 133-135 adds a required notice when the member is absent, implemented in scripts/sync-review-protocol.py:156-158. The entire uncovered acceptance family is old-v1 success plus the notice during normal sync and --check; tests/unit/review_protocol_export_test.py:296-305 already exercises both. Update Done-when to require those outcomes explicitly.
          family: acceptance-contract-coverage
          round: 1
      recipe: small-diff-review
      isolation: fenced
      blocked: true
---

# Gate ledger — parley.nvim#362 (boundary-review)

Findings this gate raised, the stable ids the binary assigned them, and how
later rounds disposed of them. Generated — edit the gate, not this file.

## Round 1 — 2026-10-16T18:12:54-07:00 (codex) — BLOCKED

### Raised

- **BR-1** [Critical] `prompt-adapter-capability-contract` (kind: defect) The imported collaboration contract requires operations the local adapter cannot perform
  lua/parley/skills/review/collaboration-modes.md:72 requires every discussion question to create a side doc; discussion is now the default even without frontmatter (line 29). Thus an ordinary local 🤖[why?] request can no longer be answered consistently: local-adapter.md:10-16 permits only one propose_edits call, and lua/parley/skill_invoke.lua:567-569 forcibly binds that call to the submitted artifact. No available write operation can create the required side doc. Removing the marker and inserting its prescribed link would leave a nonexistent target; answering inline violates the new contract.
  The complete affected capability family in this window is discussion question/decision-note/nested side-doc creation (lines 72, 105-107, 155-157), chat answer creation and follow-up writes (128-138), cross-document approval folds (93, 202-218), and retry/relink/orphan discovery (205-222). Chat additionally requires a change baseline that local-adapter.md:18-20 explicitly lacks, while marker-free chat submissions are skipped by review/init.lua's existing precheck. These instructions are also embedded in generated SKILL.md. Reconcile the Parley-owned local compatibility policy with these capabilities, document the supported behavior, and add regression coverage for default questions and explicit collaboration/chat handling. ARCH-PURPOSE: successful concatenation does not establish a usable local contract.
- **BR-2** [Important] `acceptance-contract-coverage` (kind: defect) Done-when omits the newly required old-export notice
  workshop/issues/000362-review-protocol-sync-accepts-s2-s-collaboration-modes-export-member.md:33-36 only requires tests and synchronization for an export containing collaboration modes. The revision at lines 133-135 adds a required notice when the member is absent, implemented in scripts/sync-review-protocol.py:156-158. The entire uncovered acceptance family is old-v1 success plus the notice during normal sync and --check; tests/unit/review_protocol_export_test.py:296-305 already exercises both. Update Done-when to require those outcomes explicitly.

## Open findings

- **BR-1** [Critical] `prompt-adapter-capability-contract` (kind: defect) The imported collaboration contract requires operations the local adapter cannot perform
- **BR-2** [Important] `acceptance-contract-coverage` (kind: defect) Done-when omits the newly required old-export notice
