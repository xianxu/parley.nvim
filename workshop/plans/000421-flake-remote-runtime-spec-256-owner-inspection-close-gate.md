---
gate: boundary-review
issue: 421
id_prefix: BR
rounds:
    - reviewer_runs:
        - version: 1
          intent:
            disposable_root: true
            id: 70c4199e-de4f-4e81-8118-ba62da723ce1
            repository: github.com/xianxu/parley.nvim
            issue_id: "000421"
            recipe: small-diff-review
            round: 1
            attempt: 1
            agent: claude
            root: /Volumes/TestScratch/review-checkouts/14125556c1561589
            reviewed_head: 71c8a0b3afb8eaebbe60fa1752197f5dcc965dcd
            slot: parley.nvim:1
            requested_at: "2026-10-24T03:26:52.989185Z"
          phase: finished
          pid: 77409
          started_at: "2026-10-24T03:26:53.162809Z"
          finished_at: "2026-10-24T03:31:39.016955Z"
          session_id: 554b29a8-aebd-486a-9591-121de802d614
          outcome: returned
      actual_inputs:
        version: 1
        method: active-time-v3-engagement-queue-v1
        repository: github.com/xianxu/parley.nvim
        code_head: 71c8a0b3afb8eaebbe60fa1752197f5dcc965dcd
        tracker_head: 71d3cb6555a0ef8fbbb3e86eca175ea398a693be
        branch_point: cd5fc8bfd2f4f6cef5b22cc94ce912e48fa8c5a1
        since: "2026-10-23T15:07:22-07:00"
        until: "2026-10-23T20:26:21-07:00"
        brain_root: /Users/xianxu/workspace/brain
        gap_minutes: 15
        commit_weight: 1
        include_assistant: true
        engagements:
            - start: "2026-10-23T15:07:22-07:00"
              end: "2026-10-23T20:26:21-07:00"
              began: "2026-10-23T15:07:22-07:00"
              roots:
                - /Users/xianxu/workspace/worktree/parley.nvim-slot1/parley.nvim
        sources:
            - harness: claude
              id: d993777e-4c43-455a-b373-52b1dc0fc833
              slot: parley.nvim:1
              cwd: /Users/xianxu/workspace/worktree/parley.nvim-slot1/parley.nvim
              digest: 2f977854d588157f804cbcc1f4641ba54ec140bdf0eebacf39ce50fa9f5ca0de
              started: "2026-10-23T07:59:20.816Z"
              spawned: false
              bytes: 9041789
              windows:
                - start: "2026-10-23T15:07:22-07:00"
                  end: "2026-10-23T20:26:21-07:00"
        queue_waits:
            - attempt_id: 44226e05860240b995e99ac846f419c4
              slot: parley.nvim:1
              record_digest: 60b73188a3e4ac306980b22f07d56e98961ad6dc2aa3ea026038c44e104af365
              start: "2026-10-23T22:24:21.125924Z"
              end: "2026-10-23T23:48:53.021167Z"
              queue_seconds: 5071.895243
              raw_seconds: 5071.895243
              exact: true
            - attempt_id: b85f2f86e9abd088beae56407b8ebb57
              slot: parley.nvim:1
              record_digest: 6d3ff720a301320259a132c003a0ebba9b6c47c3b2444bc0d3506ae90ec915cf
              start: "2026-10-23T23:52:57.905114Z"
              end: "2026-10-24T00:24:45.118057Z"
              queue_seconds: 1907.212943
              raw_seconds: 1907.212943
              exact: true
            - attempt_id: c3313d288aa5a59d6f5ee642ef708bfe
              slot: parley.nvim:1
              record_digest: 087fdff9e57c4f74f88f965f2df849156eedb9c79d96069e99a1fffa7e50cb41
              start: "2026-10-24T00:30:49.109361Z"
              end: "2026-10-24T00:55:34.871897Z"
              queue_seconds: 1485.762536
              raw_seconds: 1485.762536
              exact: true
            - attempt_id: 36c10d10c54944ae364dfb14ad896609
              slot: parley.nvim:1
              record_digest: dcda74a41fe80bfa309cbad5d4d30aad9f8669c694eb3fa0a05fe3e6afe6ac5a
              start: "2026-10-24T02:24:25.082221Z"
              end: "2026-10-24T02:30:05.505217Z"
              queue_seconds: 340.422996
              raw_seconds: 340.422996
              exact: true
            - attempt_id: f8da46eb842a3daa6ee4fe9e432f6ea3
              slot: parley.nvim:1
              record_digest: e80545d07fbb1baafa998189de05a4ccd382998a5ee19c3b4a42f1f78fd1131a
              start: "2026-10-24T02:42:22.521425Z"
              end: "2026-10-24T03:18:33.925494Z"
              queue_seconds: 2171.404069
              raw_seconds: 2171.404069
              exact: true
      "n": 1
      timestamp: "2026-10-23T20:31:39-07:00"
      dispatched: "2026-10-23T20:26:52-07:00"
      agent: claude
      reviewer: claude (anthropic; author anthropic)
      findings:
        - id: BR-1
          severity: Important
          title: 'Done when omits the TL-approved #430 fold (close #430, unregister its two cases)'
          detail: 'Revision 1 folds #430 into #421 and says close #430 with #421 and unregister its cases, but Done when only covers this issue''s own registered pair. #430 is still status open with flake_tests registered. Add a Done-when clause so the close gate checks it. This is the only Revision without a Done-when clause in this window.'
          family: done-when-tracks-revisions
          round: 1
        - id: BR-2
          severity: Minor
          title: deadline_timer_spec's blind-spot list omits vim.defer_fn and vim.fn.timer_start deadlines
          detail: The lint matches only ':start(' so a raw vim.defer_fn(fn, deadline_ms) or timer_start deadline (same stale-clock bug; helper.defer_deadline exists) passes silently. The comment at deadline_timer_spec.lua:9-12 claims to list what it cannot see but omits these. Either extend the patterns or list them.
          family: lint-scope-claims-complete
          round: 1
        - id: BR-3
          severity: Minor
          title: 'ARCH-DRY: remaining-ms computation plus start_deadline repeated at three sites'
          detail: remote_runtime.lua:113, remote_process.lua:144 and document_registry.lua:174 each compute math.max(1, math.ceil(deadline - now)) and call start_deadline. A helper.start_absolute_deadline(timer, deadline_ms, cb) would consolidate them. Separately, the 1.2 s loop-blocking busy-wait is duplicated in remote_process_spec.lua:203 and remote_runtime_spec.lua:275.
          family: absolute-deadline-arming-helper
          round: 1
      recipe: small-diff-review
      isolation: fenced
      blocked: true
    - reviewer_runs:
        - version: 1
          intent:
            disposable_root: true
            id: f9b00369-9a8f-477b-86a9-e6d340218cbf
            repository: github.com/xianxu/parley.nvim
            issue_id: "000421"
            recipe: small-diff-review
            round: 2
            attempt: 1
            agent: claude
            root: /Volumes/TestScratch/review-checkouts/3f930041cb365acd
            reviewed_head: 5cdcfa828869c68e4fc4aec0094f9f8a9ba0dd39
            slot: parley.nvim:1
            requested_at: "2026-10-24T03:37:42.384858Z"
          phase: finished
          pid: 44378
          started_at: "2026-10-24T03:37:42.474786Z"
          finished_at: "2026-10-24T03:42:23.81854Z"
          session_id: 2c59b402-cf49-4de0-9689-be642dc39aac
          outcome: returned
      actual_inputs:
        version: 1
        method: active-time-v3-engagement-queue-v1
        repository: github.com/xianxu/parley.nvim
        code_head: 5cdcfa828869c68e4fc4aec0094f9f8a9ba0dd39
        tracker_head: 709f4f62b039095823ecddebc60103ae02d0cc04
        branch_point: cd5fc8bfd2f4f6cef5b22cc94ce912e48fa8c5a1
        since: "2026-10-23T15:07:22-07:00"
        until: "2026-10-23T20:36:53-07:00"
        brain_root: /Users/xianxu/workspace/brain
        gap_minutes: 15
        commit_weight: 1
        include_assistant: true
        engagements:
            - start: "2026-10-23T15:07:22-07:00"
              end: "2026-10-23T20:36:53-07:00"
              began: "2026-10-23T15:07:22-07:00"
              roots:
                - /Users/xianxu/workspace/worktree/parley.nvim-slot1/parley.nvim
        sources:
            - harness: claude
              id: d993777e-4c43-455a-b373-52b1dc0fc833
              slot: parley.nvim:1
              cwd: /Users/xianxu/workspace/worktree/parley.nvim-slot1/parley.nvim
              digest: 7534d3ef50e81a0ac813b7f066204af343c404bb31218e804965c6a883a1a28c
              started: "2026-10-23T07:59:20.816Z"
              spawned: false
              bytes: 9351687
              windows:
                - start: "2026-10-23T15:07:22-07:00"
                  end: "2026-10-23T20:36:53-07:00"
        queue_waits:
            - attempt_id: 44226e05860240b995e99ac846f419c4
              slot: parley.nvim:1
              record_digest: 60b73188a3e4ac306980b22f07d56e98961ad6dc2aa3ea026038c44e104af365
              start: "2026-10-23T22:24:21.125924Z"
              end: "2026-10-23T23:48:53.021167Z"
              queue_seconds: 5071.895243
              raw_seconds: 5071.895243
              exact: true
            - attempt_id: b85f2f86e9abd088beae56407b8ebb57
              slot: parley.nvim:1
              record_digest: 6d3ff720a301320259a132c003a0ebba9b6c47c3b2444bc0d3506ae90ec915cf
              start: "2026-10-23T23:52:57.905114Z"
              end: "2026-10-24T00:24:45.118057Z"
              queue_seconds: 1907.212943
              raw_seconds: 1907.212943
              exact: true
            - attempt_id: c3313d288aa5a59d6f5ee642ef708bfe
              slot: parley.nvim:1
              record_digest: 087fdff9e57c4f74f88f965f2df849156eedb9c79d96069e99a1fffa7e50cb41
              start: "2026-10-24T00:30:49.109361Z"
              end: "2026-10-24T00:55:34.871897Z"
              queue_seconds: 1485.762536
              raw_seconds: 1485.762536
              exact: true
            - attempt_id: 36c10d10c54944ae364dfb14ad896609
              slot: parley.nvim:1
              record_digest: dcda74a41fe80bfa309cbad5d4d30aad9f8669c694eb3fa0a05fe3e6afe6ac5a
              start: "2026-10-24T02:24:25.082221Z"
              end: "2026-10-24T02:30:05.505217Z"
              queue_seconds: 340.422996
              raw_seconds: 340.422996
              exact: true
            - attempt_id: f8da46eb842a3daa6ee4fe9e432f6ea3
              slot: parley.nvim:1
              record_digest: e80545d07fbb1baafa998189de05a4ccd382998a5ee19c3b4a42f1f78fd1131a
              start: "2026-10-24T02:42:22.521425Z"
              end: "2026-10-24T03:18:33.925494Z"
              queue_seconds: 2171.404069
              raw_seconds: 2171.404069
              exact: true
        cuts:
            - dispatched: "2026-10-23T20:26:52-07:00"
              finalized: "2026-10-23T20:31:39-07:00"
              finalizing: false
      "n": 2
      timestamp: "2026-10-23T20:42:25-07:00"
      dispatched: "2026-10-23T20:37:42-07:00"
      agent: claude
      reviewer: claude (anthropic; author anthropic)
      dispose:
        - id: BR-1
          disposition: addressed
          note: Done when now has the Revision 1 (#430 fold) and Revision 2 clauses (issue file, Done when section); whether the tracker card was updated is noted separately because the in-repo mirror is stale.
          round: 2
        - id: BR-2
          disposition: addressed
          note: STARTS now includes vim.defer_fn and timer_start; a revert control that added vim.defer_fn(fn, deadline_ms) to oauth.lua failed the lint.
          round: 2
        - id: BR-3
          disposition: addressed
          note: helper.start_absolute_deadline is used at remote_runtime:113, remote_process:144 and document_registry:130; the busy-wait is now tests/helpers/loop_clock.block; reverting remote_runtime to a raw timer:start failed its blocked-loop case and the lint.
          round: 2
      findings:
        - kind: unverifiable
          id: BR-4
          severity: Minor
          title: 'The #430 card mirror still shows status open with both flake_tests registered, but the Log says they were unregistered'
          detail: 'I read the head copy of workshop/issues/000430-endpoint-deadline-startup-flake.md (frontmatter lines 3 and 11). The card_mirror hash is unchanged since the base commit, and the issue-cards/tracker store is not in this checkout (issue-tracker.json points only at the migrate root 41de715a). Evidence that would settle it: the tracker card for #430 showing flake_tests removed and its status, or a refreshed mirror. Only instance in this window.'
          family: log-claims-match-tracker-state
          round: 2
      recipe: small-diff-review
      isolation: fenced
      reviewed: 5cdcfa828869c68e4fc4aec0094f9f8a9ba0dd39
      blocked: false
---

# Gate ledger — parley.nvim#421 (boundary-review)

Findings this gate raised, the stable ids the binary assigned them, and how
later rounds disposed of them. Generated — edit the gate, not this file.

## Round 1 — 2026-10-23T20:31:39-07:00 (claude) — BLOCKED

### Raised

- **BR-1** [Important] `done-when-tracks-revisions` Done when omits the TL-approved #430 fold (close #430, unregister its two cases)
  Revision 1 folds #430 into #421 and says close #430 with #421 and unregister its cases, but Done when only covers this issue's own registered pair. #430 is still status open with flake_tests registered. Add a Done-when clause so the close gate checks it. This is the only Revision without a Done-when clause in this window.
- **BR-2** [Minor] `lint-scope-claims-complete` deadline_timer_spec's blind-spot list omits vim.defer_fn and vim.fn.timer_start deadlines
  The lint matches only ':start(' so a raw vim.defer_fn(fn, deadline_ms) or timer_start deadline (same stale-clock bug; helper.defer_deadline exists) passes silently. The comment at deadline_timer_spec.lua:9-12 claims to list what it cannot see but omits these. Either extend the patterns or list them.
- **BR-3** [Minor] `absolute-deadline-arming-helper` ARCH-DRY: remaining-ms computation plus start_deadline repeated at three sites
  remote_runtime.lua:113, remote_process.lua:144 and document_registry.lua:174 each compute math.max(1, math.ceil(deadline - now)) and call start_deadline. A helper.start_absolute_deadline(timer, deadline_ms, cb) would consolidate them. Separately, the 1.2 s loop-blocking busy-wait is duplicated in remote_process_spec.lua:203 and remote_runtime_spec.lua:275.

## Round 2 — 2026-10-23T20:42:25-07:00 (claude) — passed

### Disposed

- BR-1 — addressed — Done when now has the Revision 1 (#430 fold) and Revision 2 clauses (issue file, Done when section); whether the tracker card was updated is noted separately because the in-repo mirror is stale.
- BR-2 — addressed — STARTS now includes vim.defer_fn and timer_start; a revert control that added vim.defer_fn(fn, deadline_ms) to oauth.lua failed the lint.
- BR-3 — addressed — helper.start_absolute_deadline is used at remote_runtime:113, remote_process:144 and document_registry:130; the busy-wait is now tests/helpers/loop_clock.block; reverting remote_runtime to a raw timer:start failed its blocked-loop case and the lint.

### Raised

- **BR-4** [Minor] `log-claims-match-tracker-state` (kind: unverifiable) The #430 card mirror still shows status open with both flake_tests registered, but the Log says they were unregistered
  I read the head copy of workshop/issues/000430-endpoint-deadline-startup-flake.md (frontmatter lines 3 and 11). The card_mirror hash is unchanged since the base commit, and the issue-cards/tracker store is not in this checkout (issue-tracker.json points only at the migrate root 41de715a). Evidence that would settle it: the tracker card for #430 showing flake_tests removed and its status, or a refreshed mirror. Only instance in this window.

## Open findings

- **BR-4** [Minor] `log-claims-match-tracker-state` (kind: unverifiable) The #430 card mirror still shows status open with both flake_tests registered, but the Log says they were unregistered
