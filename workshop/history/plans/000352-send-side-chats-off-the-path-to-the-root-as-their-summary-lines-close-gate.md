---
gate: boundary-review
issue: 352
id_prefix: BR
rounds:
    - reviewer_runs:
        - version: 1
          intent:
            disposable_root: true
            id: d5839a4e-4c6b-4f22-8153-508b7fc8d963
            repository: github.com/xianxu/parley.nvim
            issue_id: "000352"
            recipe: small-diff-review
            round: 1
            attempt: 1
            agent: claude
            root: /Users/xianxu/Library/Caches/sdlc/review-checkouts/3a8b037172fa4dd1
            reviewed_head: 026091672266024816e0fbdd7c03fdb8b055f891
            slot: parley.nvim:3
            requested_at: "2026-10-16T15:20:16.215553Z"
          phase: finished
          pid: 67740
          started_at: "2026-10-16T15:20:16.342231Z"
          finished_at: "2026-10-16T15:23:16.65554Z"
          session_id: 86614bd4-3900-4b90-b552-e914a60d406e
          outcome: returned
      actual_inputs:
        version: 1
        method: active-time-v3-engagement-v1
        repository: github.com/xianxu/parley.nvim
        code_head: 026091672266024816e0fbdd7c03fdb8b055f891
        tracker_head: 664f2061b3e71234519c57ef1c7818c2798c880f
        branch_point: add53f6fde4e02f8238851509683e7e35a5831fd
        since: "2026-10-16T08:11:54-07:00"
        until: "2026-10-16T08:17:27-07:00"
        brain_root: /Users/xianxu/workspace/brain
        gap_minutes: 15
        commit_weight: 1
        include_assistant: true
        engagements:
            - start: "2026-10-16T08:11:54-07:00"
              end: "2026-10-16T08:17:27-07:00"
              began: "2026-10-16T08:11:54-07:00"
              roots:
                - /Users/xianxu/workspace/worktree/parley.nvim-slot3/parley.nvim
        sources:
            - harness: claude
              id: 996b651e-5e17-47f4-9815-33d9ff25fe0d
              cwd: /Users/xianxu/workspace/worktree/parley.nvim-slot3/parley.nvim
              digest: bc78d2fce65dab6e9fb597dd0033c950c70f2738fac25897d6884d6d9caf241f
              started: "2026-10-15T18:27:53.241Z"
              spawned: false
              bytes: 12085760
              windows:
                - start: "2026-10-16T08:11:54-07:00"
                  end: "2026-10-16T08:17:27-07:00"
      "n": 1
      timestamp: "2026-10-16T08:23:17-07:00"
      dispatched: "2026-10-16T08:20:16-07:00"
      agent: claude
      findings:
        - kind: defect
          id: BR-1
          severity: Minor
          title: side_chat_messages restates the summarized branch's placeholder+summary pair
          detail: 'chat_respond.lua:363-367 duplicates the summary pair the summarized branch emits at :980-983 and :1027 (strip_definition_footnote_footer of the summary content). The plan promised that off-path items go through the existing summarized branch; a shared helper would give one source. Instances: those two sites only.'
          family: duplicated-render-path
          round: 1
        - kind: defect
          id: BR-2
          severity: Minor
          title: Plan claims a README config-docs update and role alternation that the code does not deliver
          detail: The checked step says the README config docs were updated, but README.md is not in the diff and has no chat_memory section. The plan's no-summary rule says an assistant note keeps the roles alternating, but chat_respond.lua:376-378 adds it only when there is an answer (the unanswered A3 is followed directly by R2). Record both in Revisions.
          family: plan-claim-unbacked
          round: 1
        - kind: defect
          id: BR-3
          severity: Minor
          title: chat_memory.side_chats silently treats any value other than "full" as "summary"
          detail: side_chats_summarized (chat_respond.lua:346-349) has no warning for an unknown value, so a typo such as "Full" falls back to the default without notice.
          family: config-value-unvalidated
          round: 1
        - kind: defect
          id: BR-4
          severity: Minor
          title: Off-path summary path sends the placeholder even when the question text is blank
          detail: The on-path summarized branch sends the placeholder only when question_content has non-whitespace text; side_chat_messages with a summary sends it unconditionally (chat_respond.lua:363). Only that one site has the difference.
          family: blank-question-guard
          round: 1
      recipe: small-diff-review
      isolation: fenced
      reviewed: 026091672266024816e0fbdd7c03fdb8b055f891
      blocked: false
    - reviewer_runs:
        - version: 1
          intent:
            disposable_root: true
            id: 17692e27-a75d-4f71-a279-d9f522cfbc14
            repository: github.com/xianxu/parley.nvim
            issue_id: "000352"
            recipe: fix-review
            round: 2
            attempt: 1
            agent: claude
            root: /Users/xianxu/Library/Caches/sdlc/review-checkouts/c0d8388e3bd09008
            reviewed_head: 9bff6ff762f7c2424347c92143e2e1dc0e174258
            slot: parley.nvim:3
            requested_at: "2026-10-16T15:26:59.562129Z"
          phase: finished
          pid: 26513
          started_at: "2026-10-16T15:26:59.68764Z"
          finished_at: "2026-10-16T15:27:54.248867Z"
          session_id: 860e4c25-73f0-400b-9c26-180230f44275
          outcome: returned
      actual_inputs:
        version: 1
        method: active-time-v3-engagement-v1
        repository: github.com/xianxu/parley.nvim
        code_head: 9bff6ff762f7c2424347c92143e2e1dc0e174258
        tracker_head: dad5ca040dc4128dd9af55c6d60d1493610da7b9
        branch_point: add53f6fde4e02f8238851509683e7e35a5831fd
        since: "2026-10-16T08:11:54-07:00"
        until: "2026-10-16T08:24:05-07:00"
        brain_root: /Users/xianxu/workspace/brain
        gap_minutes: 15
        commit_weight: 1
        include_assistant: true
        engagements:
            - start: "2026-10-16T08:11:54-07:00"
              end: "2026-10-16T08:24:05-07:00"
              began: "2026-10-16T08:11:54-07:00"
              roots:
                - /Users/xianxu/workspace/worktree/parley.nvim-slot3/parley.nvim
        sources:
            - harness: claude
              id: 996b651e-5e17-47f4-9815-33d9ff25fe0d
              cwd: /Users/xianxu/workspace/worktree/parley.nvim-slot3/parley.nvim
              digest: ce77cd071dcde743faab713782a10ced41f7c72ca6b9cc93cc83f5e0990fe98d
              started: "2026-10-15T18:27:53.241Z"
              spawned: false
              bytes: 12165229
              windows:
                - start: "2026-10-16T08:11:54-07:00"
                  end: "2026-10-16T08:24:05-07:00"
        cuts:
            - dispatched: "2026-10-16T08:20:16-07:00"
              finalized: "2026-10-16T08:23:17-07:00"
              finalizing: true
      "n": 2
      timestamp: "2026-10-16T08:27:55-07:00"
      dispatched: "2026-10-16T08:26:59-07:00"
      agent: claude
      dispose:
        - id: BR-1
          disposition: addressed
          note: M.summary_message (chat_respond.lua:354) is now the single source, used at :372 (off-path) and :1031 (summarized branch).
          round: 2
        - id: BR-2
          disposition: addressed
          note: Revisions records the docs step (atlas plus the config.lua comment, no README config section) and that the omitted-answer note is sent only when there is an answer, as at chat_respond.lua:378-381.
          round: 2
        - id: BR-3
          disposition: addressed
          note: Revisions records that any value other than "full" means "summary", the default, consistent with the rest of chat_memory, where no value is validated. Unchanged by design.
          round: 2
        - id: BR-4
          disposition: addressed
          note: chat_respond.lua:369-371 sends the placeholder only for non-blank questions, matching :903. The test at chat_tree_context_spec.lua:290-295 fails on the old code, and it passes.
          round: 2
      recipe: fix-review
      isolation: fenced
      reviewed: 9bff6ff762f7c2424347c92143e2e1dc0e174258
      blocked: false
---

# Gate ledger — parley.nvim#352 (boundary-review)

Findings this gate raised, the stable ids the binary assigned them, and how
later rounds disposed of them. Generated — edit the gate, not this file.

## Round 1 — 2026-10-16T08:23:17-07:00 (claude) — passed

### Raised

- **BR-1** [Minor] `duplicated-render-path` (kind: defect) side_chat_messages restates the summarized branch's placeholder+summary pair
  chat_respond.lua:363-367 duplicates the summary pair the summarized branch emits at :980-983 and :1027 (strip_definition_footnote_footer of the summary content). The plan promised that off-path items go through the existing summarized branch; a shared helper would give one source. Instances: those two sites only.
- **BR-2** [Minor] `plan-claim-unbacked` (kind: defect) Plan claims a README config-docs update and role alternation that the code does not deliver
  The checked step says the README config docs were updated, but README.md is not in the diff and has no chat_memory section. The plan's no-summary rule says an assistant note keeps the roles alternating, but chat_respond.lua:376-378 adds it only when there is an answer (the unanswered A3 is followed directly by R2). Record both in Revisions.
- **BR-3** [Minor] `config-value-unvalidated` (kind: defect) chat_memory.side_chats silently treats any value other than "full" as "summary"
  side_chats_summarized (chat_respond.lua:346-349) has no warning for an unknown value, so a typo such as "Full" falls back to the default without notice.
- **BR-4** [Minor] `blank-question-guard` (kind: defect) Off-path summary path sends the placeholder even when the question text is blank
  The on-path summarized branch sends the placeholder only when question_content has non-whitespace text; side_chat_messages with a summary sends it unconditionally (chat_respond.lua:363). Only that one site has the difference.

## Round 2 — 2026-10-16T08:27:55-07:00 (claude) — passed

### Disposed

- BR-1 — addressed — M.summary_message (chat_respond.lua:354) is now the single source, used at :372 (off-path) and :1031 (summarized branch).
- BR-2 — addressed — Revisions records the docs step (atlas plus the config.lua comment, no README config section) and that the omitted-answer note is sent only when there is an answer, as at chat_respond.lua:378-381.
- BR-3 — addressed — Revisions records that any value other than "full" means "summary", the default, consistent with the rest of chat_memory, where no value is validated. Unchanged by design.
- BR-4 — addressed — chat_respond.lua:369-371 sends the placeholder only for non-blank questions, matching :903. The test at chat_tree_context_spec.lua:290-295 fails on the old code, and it passes.

## Open findings

(none — every finding has been disposed)
