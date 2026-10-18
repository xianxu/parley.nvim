---
gate: boundary-review
issue: 380
id_prefix: BR
rounds:
    - reviewer_runs:
        - version: 1
          intent:
            disposable_root: true
            id: 01fc0a27-c082-4619-aa3f-5642eebb0dd9
            repository: github.com/xianxu/parley.nvim
            issue_id: "000380"
            recipe: small-diff-review
            round: 1
            attempt: 1
            agent: claude
            root: /Users/xianxu/Library/Caches/sdlc/review-checkouts/f1c5aaae2ad7a259
            reviewed_head: 8bd27502d14a6af76fa54b4cfe76066c826f0da3
            slot: parley.nvim:4
            requested_at: "2026-10-18T02:37:37.515225Z"
          phase: finished
          pid: 63476
          started_at: "2026-10-18T02:37:37.667013Z"
          finished_at: "2026-10-18T02:39:24.573742Z"
          session_id: 8416932e-fde3-467f-b0fc-d4fc4f256db5
          outcome: returned
      actual_inputs:
        version: 1
        method: active-time-v3-engagement-v1
        repository: github.com/xianxu/parley.nvim
        code_head: 8bd27502d14a6af76fa54b4cfe76066c826f0da3
        tracker_head: 477617d3a8f2cd89710c58c3ec3f14d83358ddfe
        branch_point: d293e6ec3b878a060f4d02f0c8e0c51a54d4cd8d
        since: "2026-10-17T19:05:38-07:00"
        until: "2026-10-17T19:09:24-07:00"
        brain_root: /Users/xianxu/workspace/brain
        gap_minutes: 15
        commit_weight: 1
        include_assistant: true
        engagements:
            - start: "2026-10-17T19:05:38-07:00"
              end: "2026-10-17T19:09:24-07:00"
              began: "2026-10-17T19:05:38-07:00"
              roots:
                - /Users/xianxu/workspace/worktree/parley.nvim-slot4/parley.nvim
        sources:
            - harness: claude
              id: af31f906-121a-4f29-b30d-46e8e1b30d2a
              slot: parley.nvim:4
              cwd: /Users/xianxu/workspace/worktree/parley.nvim-slot4/parley.nvim
              digest: 40898e882eb83b5621315d843bdcf18910aabfb4bc6784c1010780779eca3fb9
              started: "2026-10-16T00:42:14.062Z"
              spawned: false
              bytes: 39196280
              windows:
                - start: "2026-10-17T19:05:38-07:00"
                  end: "2026-10-17T19:09:24-07:00"
      "n": 1
      timestamp: "2026-10-17T19:39:25-07:00"
      dispatched: "2026-10-17T19:37:37-07:00"
      agent: claude
      findings:
        - kind: defect
          id: BR-1
          severity: Critical
          title: 'A retried inherited register is no longer an inheritance: a refusal goes to pending and a press is not held'
          detail: 'Path: inherit, confirm, register, uncertain, pending, retry, then reply unavailable/owner-conflict. Base: lookup, probing, adopt the first owner, press held with inheriting=true. Head: reconcile, pending, queue_submit not admitted. Reproduced by running a spec against base and head. Cause: pending() and retry (document_session.lua:102-110, 250-270) carry only operation.args, and the stage is cleared at :321. Fix: keep the stage on state.pending, restore it as registering in retry, add transition and settle rows. Otherwise record the change as a deliberate Revision.'
          family: inheritance-stage-lifetime-vs-operation
          round: 1
        - kind: defect
          id: BR-2
          severity: Important
          title: Stage cleared on any matching event, not on operation end; confirm_parent then nil-indexes inheritance.parent
          detail: 'document_session.lua:320-321 clears state.inheritance before the kind dispatch. A matching non-terminal event returns {} at :389 with the operation still alive. A later confirm_parent reply crashes at :393 (reproduced: attempt to index local ''inheritance'' (a nil value)), where base read operation.args.parent. Every case: (a) non-terminal matching event on lookup, confirm_parent or register; (b) changed during an inherited register (:228 clears, :240-244 keeps the op); (c) register going pending (:447). The comment at :156-158 ("alive exactly as long as the operation") is false for (b) and (c). Fix: clear only on paths that end the operation, or guard :393, then fix the comment.'
          family: inheritance-stage-lifetime-vs-operation
          round: 1
        - kind: defect
          id: BR-3
          severity: Important
          title: No test covers pending then retry for an inheritance, or a non-terminal event mid-inheritance
          detail: 'The 26-row table (tests/unit/document_session_spec.lua:773-841) drives only terminal replies plus changed and detach, so both lifetime bugs ship green. Add rows: registering, uncertain, retry, then refused or registered (stage and settle decision); and a stray matching event during confirming, then the real reply.'
          family: transition-table-misses-nonterminal-paths
          round: 1
        - kind: defect
          id: BR-4
          severity: Minor
          title: 'Unlogged behaviour changes: second inherit refused instead of overwriting; changed during register drops the press earlier'
          detail: document_session.lua:283 now refuses an inherit while state.inheritance is set; base overwrote state.inherit. The settle row register, changed then answered now drops at the changed dispatch, not at the reply. Note both in the Log.
          family: undeclared-behavior-change
          round: 1
      recipe: small-diff-review
      isolation: fenced
      blocked: true
    - reviewer_runs:
        - version: 1
          intent:
            disposable_root: true
            id: e45292e8-e9ee-44cb-b98e-6fa87e198333
            repository: github.com/xianxu/parley.nvim
            issue_id: "000380"
            recipe: small-diff-review
            round: 2
            attempt: 1
            agent: claude
            root: /Users/xianxu/Library/Caches/sdlc/review-checkouts/35dbf79454725fbe
            reviewed_head: e4fd6fb1734bcc2be5546291877c8870dbdf16a6
            slot: parley.nvim:4
            requested_at: "2026-10-18T03:03:58.738983Z"
          phase: finished
          pid: 32700
          started_at: "2026-10-18T03:03:58.936545Z"
          finished_at: "2026-10-18T03:05:54.192608Z"
          session_id: f567fff9-53ef-44d1-85a3-c5cc63b5096d
          outcome: returned
      actual_inputs:
        version: 1
        method: active-time-v3-engagement-queue-v1
        repository: github.com/xianxu/parley.nvim
        code_head: e4fd6fb1734bcc2be5546291877c8870dbdf16a6
        tracker_head: 523b683d62de61afb64cdc638abe4be5d54b5a7a
        branch_point: d293e6ec3b878a060f4d02f0c8e0c51a54d4cd8d
        since: "2026-10-17T19:05:38-07:00"
        until: "2026-10-17T19:42:23-07:00"
        brain_root: /Users/xianxu/workspace/brain
        gap_minutes: 15
        commit_weight: 1
        include_assistant: true
        engagements:
            - start: "2026-10-17T19:05:38-07:00"
              end: "2026-10-17T19:42:23-07:00"
              began: "2026-10-17T19:05:38-07:00"
              roots:
                - /Users/xianxu/workspace/worktree/parley.nvim-slot4/parley.nvim
        sources:
            - harness: claude
              id: af31f906-121a-4f29-b30d-46e8e1b30d2a
              slot: parley.nvim:4
              cwd: /Users/xianxu/workspace/worktree/parley.nvim-slot4/parley.nvim
              digest: 83fdb10ffaa65161b2c90dfd06c2314426a302113665337c21a33a2ba19cd47d
              started: "2026-10-16T00:42:14.062Z"
              spawned: false
              bytes: 39450021
              windows:
                - start: "2026-10-17T19:05:38-07:00"
                  end: "2026-10-17T19:42:23-07:00"
        queue_waits:
            - attempt_id: 72129acae4bd7150417711f5816384ee
              slot: parley.nvim:4
              record_digest: 4bfeb7c3213238730a3445767419404abb36db10c60f4e87bb7d96743321d284
              start: "2026-10-18T02:09:31.666007Z"
              end: "2026-10-18T02:34:37.855292Z"
              queue_seconds: 1506.189285
              raw_seconds: 1506.189285
              exact: true
        excluded_brain_sessions: 1
        excluded_brain_minutes: 14.99105
        cuts:
            - dispatched: "2026-10-17T19:37:37-07:00"
              finalized: "2026-10-17T19:39:25-07:00"
              finalizing: false
      "n": 2
      timestamp: "2026-10-17T20:05:55-07:00"
      dispatched: "2026-10-17T20:03:58-07:00"
      agent: claude
      dispose:
        - id: BR-1
          disposition: addressed
          note: pending() copies operation incl. inheritance (:105) and retry passes previous.inheritance (:275); removing that argument fails the settle table and the transition table.
          round: 2
        - id: BR-2
          disposition: addressed
          note: No clearing on a match any more; the stage is captured at :324 and only ends with the operation. The stray-saved-during-confirming test pins it.
          round: 2
        - id: BR-3
          disposition: addressed
          note: New transition rows for uncertain, retried, refused and registered, the stray non-terminal event case, and three retried settle rows. Mutating pending() or retry turns both tests red.
          round: 2
        - id: BR-4
          disposition: addressed
          note: 'The Log''s declared behaviour changes cover both: a second inherit is refused (first hint wins), and changed during the inherited register keeps the stage.'
          round: 2
      findings:
        - kind: defect
          id: BR-5
          severity: Minor
          title: Plan checklist still describes state.inheritance cleared on matching event, and 26 rows
          detail: 'Plan item 1 names state.inheritance and clearing on a matching event, and item 2 says 26 rows. The code holds the stage on the operation or pending record, never clears it on a match, and the table has 29 rows. Instances: Plan item 1 and Plan item 2; the code comments are accurate.'
          family: plan-text-stale-after-rework
          round: 2
      recipe: small-diff-review
      isolation: fenced
      reviewed: e4fd6fb1734bcc2be5546291877c8870dbdf16a6
      blocked: false
---

# Gate ledger — parley.nvim#380 (boundary-review)

Findings this gate raised, the stable ids the binary assigned them, and how
later rounds disposed of them. Generated — edit the gate, not this file.

## Round 1 — 2026-10-17T19:39:25-07:00 (claude) — BLOCKED

### Raised

- **BR-1** [Critical] `inheritance-stage-lifetime-vs-operation` (kind: defect) A retried inherited register is no longer an inheritance: a refusal goes to pending and a press is not held
  Path: inherit, confirm, register, uncertain, pending, retry, then reply unavailable/owner-conflict. Base: lookup, probing, adopt the first owner, press held with inheriting=true. Head: reconcile, pending, queue_submit not admitted. Reproduced by running a spec against base and head. Cause: pending() and retry (document_session.lua:102-110, 250-270) carry only operation.args, and the stage is cleared at :321. Fix: keep the stage on state.pending, restore it as registering in retry, add transition and settle rows. Otherwise record the change as a deliberate Revision.
- **BR-2** [Important] `inheritance-stage-lifetime-vs-operation` (kind: defect) Stage cleared on any matching event, not on operation end; confirm_parent then nil-indexes inheritance.parent
  document_session.lua:320-321 clears state.inheritance before the kind dispatch. A matching non-terminal event returns {} at :389 with the operation still alive. A later confirm_parent reply crashes at :393 (reproduced: attempt to index local 'inheritance' (a nil value)), where base read operation.args.parent. Every case: (a) non-terminal matching event on lookup, confirm_parent or register; (b) changed during an inherited register (:228 clears, :240-244 keeps the op); (c) register going pending (:447). The comment at :156-158 ("alive exactly as long as the operation") is false for (b) and (c). Fix: clear only on paths that end the operation, or guard :393, then fix the comment.
- **BR-3** [Important] `transition-table-misses-nonterminal-paths` (kind: defect) No test covers pending then retry for an inheritance, or a non-terminal event mid-inheritance
  The 26-row table (tests/unit/document_session_spec.lua:773-841) drives only terminal replies plus changed and detach, so both lifetime bugs ship green. Add rows: registering, uncertain, retry, then refused or registered (stage and settle decision); and a stray matching event during confirming, then the real reply.
- **BR-4** [Minor] `undeclared-behavior-change` (kind: defect) Unlogged behaviour changes: second inherit refused instead of overwriting; changed during register drops the press earlier
  document_session.lua:283 now refuses an inherit while state.inheritance is set; base overwrote state.inherit. The settle row register, changed then answered now drops at the changed dispatch, not at the reply. Note both in the Log.

## Round 2 — 2026-10-17T20:05:55-07:00 (claude) — passed

### Disposed

- BR-1 — addressed — pending() copies operation incl. inheritance (:105) and retry passes previous.inheritance (:275); removing that argument fails the settle table and the transition table.
- BR-2 — addressed — No clearing on a match any more; the stage is captured at :324 and only ends with the operation. The stray-saved-during-confirming test pins it.
- BR-3 — addressed — New transition rows for uncertain, retried, refused and registered, the stray non-terminal event case, and three retried settle rows. Mutating pending() or retry turns both tests red.
- BR-4 — addressed — The Log's declared behaviour changes cover both: a second inherit is refused (first hint wins), and changed during the inherited register keeps the stage.

### Raised

- **BR-5** [Minor] `plan-text-stale-after-rework` (kind: defect) Plan checklist still describes state.inheritance cleared on matching event, and 26 rows
  Plan item 1 names state.inheritance and clearing on a matching event, and item 2 says 26 rows. The code holds the stage on the operation or pending record, never clears it on a match, and the table has 29 rows. Instances: Plan item 1 and Plan item 2; the code comments are accurate.

## Open findings

- **BR-5** [Minor] `plan-text-stale-after-rework` (kind: defect) Plan checklist still describes state.inheritance cleared on matching event, and 26 rows
