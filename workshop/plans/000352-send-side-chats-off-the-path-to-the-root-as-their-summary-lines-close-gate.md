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

## Open findings

- **BR-1** [Minor] `duplicated-render-path` (kind: defect) side_chat_messages restates the summarized branch's placeholder+summary pair
- **BR-2** [Minor] `plan-claim-unbacked` (kind: defect) Plan claims a README config-docs update and role alternation that the code does not deliver
- **BR-3** [Minor] `config-value-unvalidated` (kind: defect) chat_memory.side_chats silently treats any value other than "full" as "summary"
- **BR-4** [Minor] `blank-question-guard` (kind: defect) Off-path summary path sends the placeholder even when the question text is blank
