---
gate: boundary-review
issue: 378
id_prefix: BR
rounds:
    - reviewer_runs:
        - version: 1
          intent:
            disposable_root: true
            id: 5b047517-8f9e-495a-8b23-81f666b90435
            repository: github.com/xianxu/parley.nvim
            issue_id: "000378"
            recipe: small-diff-review
            round: 1
            attempt: 1
            agent: claude
            root: /Users/xianxu/Library/Caches/sdlc/review-checkouts/b7b4b935a6c17475
            reviewed_head: 213d9d26757a1c0ff7a4ed6fab24dd9923373af3
            slot: parley.nvim:4
            requested_at: "2026-10-17T22:16:18.626419Z"
          phase: finished
          pid: 50918
          started_at: "2026-10-17T22:16:18.727755Z"
          finished_at: "2026-10-17T22:19:42.673855Z"
          session_id: 9366349a-6649-4736-a7ca-2b08caaea425
          outcome: returned
      actual_inputs:
        version: 1
        method: active-time-v3-engagement-v1
        repository: github.com/xianxu/parley.nvim
        code_head: 213d9d26757a1c0ff7a4ed6fab24dd9923373af3
        tracker_head: 5489fe2476146823488f074cd558afedbe2017dc
        branch_point: e37e950a9e8697dfae7b3087e97b713844852804
        since: "2026-10-17T14:45:11-07:00"
        until: "2026-10-17T14:56:05-07:00"
        brain_root: /Users/xianxu/workspace/brain
        gap_minutes: 15
        commit_weight: 1
        include_assistant: true
        engagements:
            - start: "2026-10-17T14:45:11-07:00"
              end: "2026-10-17T14:56:05-07:00"
              began: "2026-10-17T14:45:11-07:00"
              roots:
                - /Users/xianxu/workspace/worktree/parley.nvim-slot4/parley.nvim
        sources:
            - harness: claude
              id: af31f906-121a-4f29-b30d-46e8e1b30d2a
              slot: parley.nvim:4
              cwd: /Users/xianxu/workspace/worktree/parley.nvim-slot4/parley.nvim
              digest: 07c43ee248f3a9f8e076da10d09f8b2341f8ab61073f4591420fd7b957136015
              started: "2026-10-16T00:42:14.062Z"
              spawned: false
              bytes: 35818101
              windows:
                - start: "2026-10-17T14:45:11-07:00"
                  end: "2026-10-17T14:56:05-07:00"
      "n": 1
      timestamp: "2026-10-17T15:19:44-07:00"
      dispatched: "2026-10-17T15:16:18-07:00"
      agent: claude
      findings:
        - kind: defect
          id: BR-1
          severity: Important
          title: 'confirm_parent executor skips the queued-submit flush: Alt+Return is dropped and the side doc stays move-busy'
          detail: 'agentic_document.lua:301-308 copies the lookup callback but drops its tail (queued_submit flush at :296, ensure_retry). If Alt+Return is pressed during the inherit lookup (queued_submit set at :540-541) and confirm_parent then refuses, nothing is sent or registered and queued_submit stays true. Reproduced through the real opener with a forgotten parent and 0.4 s lookup delay: phase plain, sends 0, child absent, move_membership(side) refused with "finish the pending document operation before moving". Fix: route confirm_parent through the shared lookup/register executor branch (args { effect.parent.path }, cache write lookup-only) and add an integration case. Family in window: this one duplicated callback (ARCH-DRY).'
          family: effect-executor-shared-tail
          round: 1
        - kind: defect
          id: BR-2
          severity: Important
          title: Missing parent identity refusal from the Done-when clause has no test
          detail: 'Done-when requires tests for missing, stale and unavailable identity. Stale is unit-tested and unavailable is integration-tested, but nothing covers an unregistered parent (agentic_document.lua:493 returns false). Add an integration case: parent with no registration, Alt+o to parent.side/child.md, child stays absent and sends stay 0.'
          family: done-when-state-coverage
          round: 1
        - kind: defect
          id: BR-3
          severity: Minor
          title: Atlas says every unconfirmed inherit shows the not-inherited band, but two paths show other bands
          detail: 'atlas/modes/session_sync.md:228-229. An unavailable child lookup shows "Couch unavailable: agentic state unknown" (document_session.lua:372). A refused inherited register followed by an absent lookup shows an empty band (:374-377 then :367-368). The plan''s malformed integration case was meant to assert the band and does not. Reword the atlas or route these paths to NOT_INHERITED.'
          family: doc-claim-unverified
          round: 1
      recipe: small-diff-review
      isolation: fenced
      blocked: true
    - reviewer_runs:
        - version: 1
          intent:
            disposable_root: true
            id: cb08d1bd-e305-4776-b4c4-4e7618afd6c2
            repository: github.com/xianxu/parley.nvim
            issue_id: "000378"
            recipe: small-diff-review
            round: 2
            attempt: 1
            agent: claude
            root: /Users/xianxu/Library/Caches/sdlc/review-checkouts/2a5f7833ed0ae6c5
            reviewed_head: 45c6e06bbdf9cdd62699691fce3ef8fd6d1789ba
            slot: parley.nvim:4
            requested_at: "2026-10-17T22:42:55.511849Z"
          phase: finished
          pid: 38869
          started_at: "2026-10-17T22:42:55.606101Z"
          finished_at: "2026-10-17T22:46:55.702904Z"
          session_id: eb3fc06a-6ab4-4b87-a2e8-391eb1d68a3c
          outcome: returned
      actual_inputs:
        version: 1
        method: active-time-v3-engagement-queue-v1
        repository: github.com/xianxu/parley.nvim
        code_head: 45c6e06bbdf9cdd62699691fce3ef8fd6d1789ba
        tracker_head: 5489fe2476146823488f074cd558afedbe2017dc
        branch_point: e37e950a9e8697dfae7b3087e97b713844852804
        since: "2026-10-17T14:45:11-07:00"
        until: "2026-10-17T15:23:30-07:00"
        brain_root: /Users/xianxu/workspace/brain
        gap_minutes: 15
        commit_weight: 1
        include_assistant: true
        engagements:
            - start: "2026-10-17T14:45:11-07:00"
              end: "2026-10-17T15:23:30-07:00"
              began: "2026-10-17T14:45:11-07:00"
              roots:
                - /Users/xianxu/workspace/worktree/parley.nvim-slot4/parley.nvim
        sources:
            - harness: claude
              id: af31f906-121a-4f29-b30d-46e8e1b30d2a
              slot: parley.nvim:4
              cwd: /Users/xianxu/workspace/worktree/parley.nvim-slot4/parley.nvim
              digest: 7716881cfe9d947cc2f52f12ab05d08f17b5df79396db6961a40f8b3ab4dfcf7
              started: "2026-10-16T00:42:14.062Z"
              spawned: false
              bytes: 36074492
              windows:
                - start: "2026-10-17T14:45:11-07:00"
                  end: "2026-10-17T15:23:30-07:00"
        queue_waits:
            - attempt_id: 62c10c7b258e550651a556846e7cf5ec
              slot: parley.nvim:4
              record_digest: d4ed512e3d97c525c0597dd57dd1091471e51d18cf9f084979d329fd5b28af4a
              start: "2026-10-17T21:56:11.047764Z"
              end: "2026-10-17T22:13:24.985044Z"
              queue_seconds: 1033.93728
              raw_seconds: 1033.93728
              exact: true
        cuts:
            - dispatched: "2026-10-17T15:16:18-07:00"
              finalized: "2026-10-17T15:19:44-07:00"
              finalizing: false
      "n": 2
      timestamp: "2026-10-17T15:46:57-07:00"
      dispatched: "2026-10-17T15:42:55-07:00"
      agent: claude
      dispose:
        - id: BR-1
          disposition: addressed
          note: confirm_parent now uses the shared executor tail; reverting agentic_document.lua to 213d9d26's separate branch makes the "parent can no longer be confirmed" integration case fail (6/7), so the regression test is live.
          round: 2
        - id: BR-2
          disposition: addressed
          note: The integration case "offers nothing to inherit from a parent with no registration" asserts the child stays absent with 0 sends; without the not-parent guard, parent.File would throw in the Alt+o callback.
          round: 2
        - id: BR-3
          disposition: addressed
          note: atlas/modes/session_sync.md:228-233 now names the NOT_INHERITED band for an unconfirmed parent and the Couch unavailable band for an unanswered child lookup, and drops the false "every" claim; the adoption comment at document_session.lua:375-376 matches the code.
          round: 2
      findings:
        - kind: defect
          id: BR-4
          severity: Important
          title: A press queued during inheritance submits to the pane actor after a stale or unavailable parent refusal
          detail: 'This is the 2nd finding in family effect-executor-shared-tail. Rule: the shared executor tail must flush a queued press only when the model says the operation that admitted it still authorizes it; it must not infer that from operation == nil. Today a confirm_parent refusal (document_session.lua:346-347) leaves no operation, so the tail (agentic_document.lua:298-301) calls M.submit, own_slot resolves parley.nvim:1, and the doc registers and sends there. Probe through the real opener: a stale parent (re-registered to ops:9 while the buffer showed ops:0) gave sends=1 to parley.nvim:1, and an unavailable parent check gave the same. That violates the Done-when rule that stale or unavailable identity cannot silently guess ownership (ARCH-PURPOSE, ARCH-PURE). Fix: have the model emit a decision such as drop_queued on stale or unavailable refusals (and decide the absent-parent case on purpose), then add integration cases asserting 0 sends and no registration. Instances in the window: the confirm_parent refusal branch, which is exposed; and the re-lookup after a refused inherited register (document_session.lua:376-379), which is not exposed because its absent fallback is the ordinary unregistered submit.'
          family: effect-executor-shared-tail
          round: 2
        - kind: defect
          id: BR-5
          severity: Minor
          title: The new side-inherit integration spec is not mapped in atlas/traceability.yaml
          detail: tests/integration/agentic_document_side_inherit_spec.lua is missing from the modes/session_sync tests list (atlas/traceability.yaml:803-822), so make test-spec SPEC=modes/session_sync skips it. Its sibling specs agentic_document_owned_move_spec and agentic_document_lifetime_spec are listed. This is the only instance in the window.
          family: traceability-mapping
          round: 2
      recipe: small-diff-review
      isolation: fenced
      blocked: true
    - reviewer_runs:
        - version: 1
          intent:
            disposable_root: true
            id: fb2c200a-b303-45f0-bbb3-1bf281292577
            repository: github.com/xianxu/parley.nvim
            issue_id: "000378"
            recipe: small-diff-review
            round: 3
            attempt: 1
            agent: claude
            root: /Users/xianxu/Library/Caches/sdlc/review-checkouts/e73b8a933dc21ef1
            reviewed_head: d5fe338844805de44ca981df5df6f3cee2092e1b
            slot: parley.nvim:4
            requested_at: "2026-10-17T23:16:07.491955Z"
          phase: finished
          pid: 56231
          started_at: "2026-10-17T23:16:07.58833Z"
          finished_at: "2026-10-17T23:21:56.676757Z"
          session_id: 6cf28373-b7fa-4521-8667-d56ea22ffb35
          outcome: returned
      actual_inputs:
        version: 1
        method: active-time-v3-engagement-queue-v1
        repository: github.com/xianxu/parley.nvim
        code_head: d5fe338844805de44ca981df5df6f3cee2092e1b
        tracker_head: 5489fe2476146823488f074cd558afedbe2017dc
        branch_point: e37e950a9e8697dfae7b3087e97b713844852804
        since: "2026-10-17T14:45:11-07:00"
        until: "2026-10-17T15:50:33-07:00"
        brain_root: /Users/xianxu/workspace/brain
        gap_minutes: 15
        commit_weight: 1
        include_assistant: true
        engagements:
            - start: "2026-10-17T14:45:11-07:00"
              end: "2026-10-17T15:50:33-07:00"
              began: "2026-10-17T14:45:11-07:00"
              roots:
                - /Users/xianxu/workspace/worktree/parley.nvim-slot4/parley.nvim
        sources:
            - harness: claude
              id: af31f906-121a-4f29-b30d-46e8e1b30d2a
              slot: parley.nvim:4
              cwd: /Users/xianxu/workspace/worktree/parley.nvim-slot4/parley.nvim
              digest: 85fa2333b348de67d7473af1c499613b50b1ede1eb0ab5113811416bf192d8e1
              started: "2026-10-16T00:42:14.062Z"
              spawned: false
              bytes: 36397324
              windows:
                - start: "2026-10-17T14:45:11-07:00"
                  end: "2026-10-17T15:50:33-07:00"
        queue_waits:
            - attempt_id: 62c10c7b258e550651a556846e7cf5ec
              slot: parley.nvim:4
              record_digest: d4ed512e3d97c525c0597dd57dd1091471e51d18cf9f084979d329fd5b28af4a
              start: "2026-10-17T21:56:11.047764Z"
              end: "2026-10-17T22:13:24.985044Z"
              queue_seconds: 1033.93728
              raw_seconds: 1033.93728
              exact: true
            - attempt_id: eaba18752e953dd38f7e8889baa36ace
              slot: parley.nvim:4
              record_digest: d42066f36c08ed5376982b8699729746bd79b3f438eb32d03dd3aac72ef22dff
              start: "2026-10-17T22:24:32.38126Z"
              end: "2026-10-17T22:39:57.534625Z"
              queue_seconds: 925.153365
              raw_seconds: 925.153365
              exact: true
        cuts:
            - dispatched: "2026-10-17T15:16:18-07:00"
              finalized: "2026-10-17T15:19:44-07:00"
              finalizing: false
            - dispatched: "2026-10-17T15:42:55-07:00"
              finalized: "2026-10-17T15:46:57-07:00"
              finalizing: false
      "n": 3
      timestamp: "2026-10-17T16:22:05-07:00"
      dispatched: "2026-10-17T16:16:07-07:00"
      agent: claude
      dispose:
        - id: BR-4
          disposition: addressed
          note: Model emits drop_queued on confirm_parent refusal, inheriting lookup absent/unavailable; mutation removing the shell handler fails both new integration cases with sends=1 to parley.nvim:1.
          round: 3
        - id: BR-5
          disposition: addressed
          note: atlas/traceability.yaml:816 lists the spec; spec_test_map list-tests modes/session_sync returns it and test-spec ran it (8 pass).
          round: 3
      findings:
        - kind: defect
          id: BR-6
          severity: Important
          title: Inheritance cancelled by a changed event (or a stale witness) never drops the queued press; a later lookup tail re-aims it at the pane actor
          detail: '3rd finding in this family. Rule to fix: the shell flushes a queued press only on an explicit model effect authorizing it (e.g. flush_queued), never by inferring from operation == nil; or move the queue flag into the model so every transition that ends an admitting operation decides it. Probe (pure model): inherit, then lookup absent, then confirm_parent; then changed returns only cancel, phase unknown, no drop_queued (document_session.lua:168-191). The shell cancels the request, so the tail never runs and queued_submit stays true: migration_busy is stuck, and the next lookup completion flushes via agentic_document.lua:300-303 to M.submit and own_slot (pane actor); a deliberate press in between leaves the queue armed, so a second send can follow. Trigger: BufReadPost/FileChangedShellPost with changed content during inheritance (agentic_document.lua:455). Enumerated endings: (1) confirm_parent reply, covered; (2) inheriting lookup absent/unavailable, covered; (3) refused inherited register then re-lookup absent, covered; (4) changed cancelling lookup/confirm_parent, NOT covered; (5) stale witness on lookup/confirm_parent at document_session.lua:286-288 returns an empty list and the tail flushes, NOT covered; (6) inherited register going to pending flushes into a retry resubmit to the inherited owner, which should be decided explicitly. The atlas claim that anything else drops the press (session_sync.md:232) is false for cases 4 and 5. Add unit cases for 4 and 5 and one integration case (file reload during inheritance, assert 0 sends).'
          family: effect-executor-shared-tail
          round: 3
      recipe: small-diff-review
      isolation: fenced
      blocked: true
    - reviewer_runs:
        - version: 1
          intent:
            disposable_root: true
            id: 9afda979-bd13-4305-b99e-cddbf19b2849
            repository: github.com/xianxu/parley.nvim
            issue_id: "000378"
            recipe: milestone-review
            round: 4
            attempt: 1
            agent: claude
            root: /Users/xianxu/Library/Caches/sdlc/review-checkouts/b7f729e07ea1a96d
            reviewed_head: d4ecabfb8cd3d7cd39c8e720e81d6c87e9d63adb
            slot: parley.nvim:4
            requested_at: "2026-10-18T00:02:52.834352Z"
          phase: finished
          pid: 14143
          started_at: "2026-10-18T00:02:53.179849Z"
          finished_at: "2026-10-18T00:12:42.469879Z"
          session_id: 31087a73-f76b-4c0a-b1a6-b7ce0f25a749
          outcome: returned
      actual_inputs:
        version: 1
        method: active-time-v3-engagement-queue-v1
        repository: github.com/xianxu/parley.nvim
        code_head: d4ecabfb8cd3d7cd39c8e720e81d6c87e9d63adb
        tracker_head: 5489fe2476146823488f074cd558afedbe2017dc
        branch_point: e37e950a9e8697dfae7b3087e97b713844852804
        since: "2026-10-17T14:45:11-07:00"
        until: "2026-10-17T16:28:53-07:00"
        brain_root: /Users/xianxu/workspace/brain
        gap_minutes: 15
        commit_weight: 1
        include_assistant: true
        engagements:
            - start: "2026-10-17T14:45:11-07:00"
              end: "2026-10-17T16:28:53-07:00"
              began: "2026-10-17T14:45:11-07:00"
              roots:
                - /Users/xianxu/workspace/worktree/parley.nvim-slot4/parley.nvim
        sources:
            - harness: claude
              id: af31f906-121a-4f29-b30d-46e8e1b30d2a
              slot: parley.nvim:4
              cwd: /Users/xianxu/workspace/worktree/parley.nvim-slot4/parley.nvim
              digest: 8e283826e5e8e37163d571995c3a6738b49811eb6a589411632cdb2a2b84e4ba
              started: "2026-10-16T00:42:14.062Z"
              spawned: false
              bytes: 36847498
              windows:
                - start: "2026-10-17T14:45:11-07:00"
                  end: "2026-10-17T16:28:53-07:00"
        queue_waits:
            - attempt_id: 62c10c7b258e550651a556846e7cf5ec
              slot: parley.nvim:4
              record_digest: d4ed512e3d97c525c0597dd57dd1091471e51d18cf9f084979d329fd5b28af4a
              start: "2026-10-17T21:56:11.047764Z"
              end: "2026-10-17T22:13:24.985044Z"
              queue_seconds: 1033.93728
              raw_seconds: 1033.93728
              exact: true
            - attempt_id: eaba18752e953dd38f7e8889baa36ace
              slot: parley.nvim:4
              record_digest: d42066f36c08ed5376982b8699729746bd79b3f438eb32d03dd3aac72ef22dff
              start: "2026-10-17T22:24:32.38126Z"
              end: "2026-10-17T22:39:57.534625Z"
              queue_seconds: 925.153365
              raw_seconds: 925.153365
              exact: true
            - attempt_id: 80cdb881d55f99f6b397a8173f7583c3
              slot: parley.nvim:4
              record_digest: dfeb21d1436e3ce4401e1ac7cf7c60e0ca5de833ee5bc5f0533ec4fb82adde42
              start: "2026-10-17T22:50:40.81825Z"
              end: "2026-10-17T23:13:14.862552Z"
              queue_seconds: 1354.044302
              raw_seconds: 1354.044302
              exact: true
        cuts:
            - dispatched: "2026-10-17T15:16:18-07:00"
              finalized: "2026-10-17T15:19:44-07:00"
              finalizing: false
            - dispatched: "2026-10-17T15:42:55-07:00"
              finalized: "2026-10-17T15:46:57-07:00"
              finalizing: false
            - dispatched: "2026-10-17T16:16:07-07:00"
              finalized: "2026-10-17T16:22:05-07:00"
              finalizing: false
      "n": 4
      timestamp: "2026-10-17T17:12:43-07:00"
      dispatched: "2026-10-17T17:02:52-07:00"
      agent: claude
      dispose:
        - id: BR-6
          disposition: addressed
          note: Model owns state.queued; dispatch settles once per ending (document_session.lua:175-195); shell flushes only on flush_queued. Unit table covers changed/detach/pending/refusals; reverting the inheriting guard turns it red (45/46).
          round: 4
      recipe: milestone-review
      isolation: fenced
      reviewed: d4ecabfb8cd3d7cd39c8e720e81d6c87e9d63adb
      blocked: false
---

# Gate ledger — parley.nvim#378 (boundary-review)

Findings this gate raised, the stable ids the binary assigned them, and how
later rounds disposed of them. Generated — edit the gate, not this file.

## Round 1 — 2026-10-17T15:19:44-07:00 (claude) — BLOCKED

### Raised

- **BR-1** [Important] `effect-executor-shared-tail` (kind: defect) confirm_parent executor skips the queued-submit flush: Alt+Return is dropped and the side doc stays move-busy
  agentic_document.lua:301-308 copies the lookup callback but drops its tail (queued_submit flush at :296, ensure_retry). If Alt+Return is pressed during the inherit lookup (queued_submit set at :540-541) and confirm_parent then refuses, nothing is sent or registered and queued_submit stays true. Reproduced through the real opener with a forgotten parent and 0.4 s lookup delay: phase plain, sends 0, child absent, move_membership(side) refused with "finish the pending document operation before moving". Fix: route confirm_parent through the shared lookup/register executor branch (args { effect.parent.path }, cache write lookup-only) and add an integration case. Family in window: this one duplicated callback (ARCH-DRY).
- **BR-2** [Important] `done-when-state-coverage` (kind: defect) Missing parent identity refusal from the Done-when clause has no test
  Done-when requires tests for missing, stale and unavailable identity. Stale is unit-tested and unavailable is integration-tested, but nothing covers an unregistered parent (agentic_document.lua:493 returns false). Add an integration case: parent with no registration, Alt+o to parent.side/child.md, child stays absent and sends stay 0.
- **BR-3** [Minor] `doc-claim-unverified` (kind: defect) Atlas says every unconfirmed inherit shows the not-inherited band, but two paths show other bands
  atlas/modes/session_sync.md:228-229. An unavailable child lookup shows "Couch unavailable: agentic state unknown" (document_session.lua:372). A refused inherited register followed by an absent lookup shows an empty band (:374-377 then :367-368). The plan's malformed integration case was meant to assert the band and does not. Reword the atlas or route these paths to NOT_INHERITED.

## Round 2 — 2026-10-17T15:46:57-07:00 (claude) — BLOCKED

### Disposed

- BR-1 — addressed — confirm_parent now uses the shared executor tail; reverting agentic_document.lua to 213d9d26's separate branch makes the "parent can no longer be confirmed" integration case fail (6/7), so the regression test is live.
- BR-2 — addressed — The integration case "offers nothing to inherit from a parent with no registration" asserts the child stays absent with 0 sends; without the not-parent guard, parent.File would throw in the Alt+o callback.
- BR-3 — addressed — atlas/modes/session_sync.md:228-233 now names the NOT_INHERITED band for an unconfirmed parent and the Couch unavailable band for an unanswered child lookup, and drops the false "every" claim; the adoption comment at document_session.lua:375-376 matches the code.

### Raised

- **BR-4** [Important] `effect-executor-shared-tail` (kind: defect) A press queued during inheritance submits to the pane actor after a stale or unavailable parent refusal
  This is the 2nd finding in family effect-executor-shared-tail. Rule: the shared executor tail must flush a queued press only when the model says the operation that admitted it still authorizes it; it must not infer that from operation == nil. Today a confirm_parent refusal (document_session.lua:346-347) leaves no operation, so the tail (agentic_document.lua:298-301) calls M.submit, own_slot resolves parley.nvim:1, and the doc registers and sends there. Probe through the real opener: a stale parent (re-registered to ops:9 while the buffer showed ops:0) gave sends=1 to parley.nvim:1, and an unavailable parent check gave the same. That violates the Done-when rule that stale or unavailable identity cannot silently guess ownership (ARCH-PURPOSE, ARCH-PURE). Fix: have the model emit a decision such as drop_queued on stale or unavailable refusals (and decide the absent-parent case on purpose), then add integration cases asserting 0 sends and no registration. Instances in the window: the confirm_parent refusal branch, which is exposed; and the re-lookup after a refused inherited register (document_session.lua:376-379), which is not exposed because its absent fallback is the ordinary unregistered submit.
- **BR-5** [Minor] `traceability-mapping` (kind: defect) The new side-inherit integration spec is not mapped in atlas/traceability.yaml
  tests/integration/agentic_document_side_inherit_spec.lua is missing from the modes/session_sync tests list (atlas/traceability.yaml:803-822), so make test-spec SPEC=modes/session_sync skips it. Its sibling specs agentic_document_owned_move_spec and agentic_document_lifetime_spec are listed. This is the only instance in the window.

## Round 3 — 2026-10-17T16:22:05-07:00 (claude) — BLOCKED

### Disposed

- BR-4 — addressed — Model emits drop_queued on confirm_parent refusal, inheriting lookup absent/unavailable; mutation removing the shell handler fails both new integration cases with sends=1 to parley.nvim:1.
- BR-5 — addressed — atlas/traceability.yaml:816 lists the spec; spec_test_map list-tests modes/session_sync returns it and test-spec ran it (8 pass).

### Raised

- **BR-6** [Important] `effect-executor-shared-tail` (kind: defect) Inheritance cancelled by a changed event (or a stale witness) never drops the queued press; a later lookup tail re-aims it at the pane actor
  3rd finding in this family. Rule to fix: the shell flushes a queued press only on an explicit model effect authorizing it (e.g. flush_queued), never by inferring from operation == nil; or move the queue flag into the model so every transition that ends an admitting operation decides it. Probe (pure model): inherit, then lookup absent, then confirm_parent; then changed returns only cancel, phase unknown, no drop_queued (document_session.lua:168-191). The shell cancels the request, so the tail never runs and queued_submit stays true: migration_busy is stuck, and the next lookup completion flushes via agentic_document.lua:300-303 to M.submit and own_slot (pane actor); a deliberate press in between leaves the queue armed, so a second send can follow. Trigger: BufReadPost/FileChangedShellPost with changed content during inheritance (agentic_document.lua:455). Enumerated endings: (1) confirm_parent reply, covered; (2) inheriting lookup absent/unavailable, covered; (3) refused inherited register then re-lookup absent, covered; (4) changed cancelling lookup/confirm_parent, NOT covered; (5) stale witness on lookup/confirm_parent at document_session.lua:286-288 returns an empty list and the tail flushes, NOT covered; (6) inherited register going to pending flushes into a retry resubmit to the inherited owner, which should be decided explicitly. The atlas claim that anything else drops the press (session_sync.md:232) is false for cases 4 and 5. Add unit cases for 4 and 5 and one integration case (file reload during inheritance, assert 0 sends).

## Round 4 — 2026-10-17T17:12:43-07:00 (claude) — passed

### Disposed

- BR-6 — addressed — Model owns state.queued; dispatch settles once per ending (document_session.lua:175-195); shell flushes only on flush_queued. Unit table covers changed/detach/pending/refusals; reverting the inheriting guard turns it red (45/46).

## Open findings

(none — every finding has been disposed)
