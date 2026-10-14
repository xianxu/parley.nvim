---
gate: boundary-review
issue: 325
id_prefix: BR
rounds:
    - actual_inputs:
        version: 1
        method: active-time-v3-engagement-v1
        repository: github.com/xianxu/parley.nvim
        code_head: 8a4743ba5cc2bbaf36ee53f48d6386b873fe2e9a
        tracker_head: 4f9645477f7cfaf92ddb4ef5ce15feb0753ba7ae
        branch_point: 2a048860b52c104a51b66e35adc9c62f26a3f7b6
        since: "2026-10-14T09:55:47-07:00"
        until: "2026-10-14T10:44:18-07:00"
        brain_root: /Users/xianxu/workspace/brain
        gap_minutes: 15
        commit_weight: 1
        include_assistant: true
        engagements:
            - start: "2026-10-14T09:55:47-07:00"
              end: "2026-10-14T10:44:18-07:00"
              began: "2026-10-14T09:55:47-07:00"
              roots:
                - /Users/xianxu/workspace/worktree/parley.nvim-slot2/parley.nvim
        sources:
            - harness: codex
              id: 01a13b56-32ec-7310-8650-104071939f2f
              cwd: /Users/xianxu/workspace/worktree/parley.nvim-slot2/parley.nvim
              digest: f971f72c3638899965fef26e53fff674fd7181a4671ee4d52aa15ee3409407dd
              started: "2026-10-14T16:54:39.906Z"
              spawned: false
              bytes: 2601697
              windows:
                - start: "2026-10-14T09:55:47-07:00"
                  end: "2026-10-14T10:44:18-07:00"
        excluded_brain_sessions: 1
        excluded_brain_minutes: 0.04226666666666667
      "n": 1
      timestamp: "2026-10-14T10:47:10-07:00"
      dispatched: "2026-10-14T10:44:59-07:00"
      agent: codex
      findings:
        - kind: defect
          id: BR-1
          severity: Critical
          title: Escaped attachment stems fail send-budget admission
          detail: 'lua/parley/assets.lua:726 returns an encoded path, and read_bounded decodes it, but lua/parley/chat_respond.lua:403 still stats dir .. "/" .. rel directly. A foreground in-memory probe showed read_bounded successfully reading assets/answer (QA)/a.png while build_messages statted assets/answer%20%28QA%29/a.png and emitted an ENOENT omission note. The complete affected caller family is build_messages and build_messages_from_model, both through attach_question_images/asset_size; affected keys include spaces, escaped punctuation, Unicode, and literal percent signs. Centralize validated disk-path resolution in assets and use it for both stat and read, with regression coverage through both builders. ARCH-PURPOSE: the widened grammar must reach every consuming path.'
          family: asset-path-resolution-consistency
          round: 1
        - kind: defect
          id: BR-2
          severity: Important
          title: Done-when omits the revised shrinking contract
          detail: workshop/issues/000325-image-paste-alt-v-in-any-markdown-file-not-only-timestamp-named-chats-sidecar-assets-per-file-for-the-tl-session-file-and-qa-files.md:33 still specifies only PNG saving/link insertion and unchanged chats, whereas Revisions:60 adds large-image shrinking and the implementation produces JPEGs. This family's complete instance in the window is the issue's sole Done-when clause. Update it to distinguish small PNG preservation from eligible large-image conversion, while retaining the chat regression requirement.
          family: acceptance-criteria-contract-alignment
          round: 1
      recipe: small-diff-review
      isolation: fenced
      blocked: true
---

# Gate ledger — parley.nvim#325 (boundary-review)

Findings this gate raised, the stable ids the binary assigned them, and how
later rounds disposed of them. Generated — edit the gate, not this file.

## Round 1 — 2026-10-14T10:47:10-07:00 (codex) — BLOCKED

### Raised

- **BR-1** [Critical] `asset-path-resolution-consistency` (kind: defect) Escaped attachment stems fail send-budget admission
  lua/parley/assets.lua:726 returns an encoded path, and read_bounded decodes it, but lua/parley/chat_respond.lua:403 still stats dir .. "/" .. rel directly. A foreground in-memory probe showed read_bounded successfully reading assets/answer (QA)/a.png while build_messages statted assets/answer%20%28QA%29/a.png and emitted an ENOENT omission note. The complete affected caller family is build_messages and build_messages_from_model, both through attach_question_images/asset_size; affected keys include spaces, escaped punctuation, Unicode, and literal percent signs. Centralize validated disk-path resolution in assets and use it for both stat and read, with regression coverage through both builders. ARCH-PURPOSE: the widened grammar must reach every consuming path.
- **BR-2** [Important] `acceptance-criteria-contract-alignment` (kind: defect) Done-when omits the revised shrinking contract
  workshop/issues/000325-image-paste-alt-v-in-any-markdown-file-not-only-timestamp-named-chats-sidecar-assets-per-file-for-the-tl-session-file-and-qa-files.md:33 still specifies only PNG saving/link insertion and unchanged chats, whereas Revisions:60 adds large-image shrinking and the implementation produces JPEGs. This family's complete instance in the window is the issue's sole Done-when clause. Update it to distinguish small PNG preservation from eligible large-image conversion, while retaining the chat regression requirement.

## Open findings

- **BR-1** [Critical] `asset-path-resolution-consistency` (kind: defect) Escaped attachment stems fail send-budget admission
- **BR-2** [Important] `acceptance-criteria-contract-alignment` (kind: defect) Done-when omits the revised shrinking contract
