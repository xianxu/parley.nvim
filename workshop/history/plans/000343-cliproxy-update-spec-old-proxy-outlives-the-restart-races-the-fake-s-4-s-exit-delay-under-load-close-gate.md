---
gate: boundary-review
issue: 343
id_prefix: BR
rounds:
    - reviewer_runs:
        - version: 1
          intent:
            disposable_root: true
            id: 56bbd892-6165-4d06-a400-7e9124a37c14
            repository: github.com/xianxu/parley.nvim
            issue_id: "000343"
            recipe: small-diff-review
            round: 1
            attempt: 1
            agent: claude
            root: /Users/xianxu/Library/Caches/sdlc/review-checkouts/281e18471be36419
            reviewed_head: a3365ebb9598f2eb2c074fa23bd8988f8a89e852
            slot: parley.nvim:3
            requested_at: "2026-10-16T06:51:23.516139Z"
          phase: finished
          pid: 17971
          started_at: "2026-10-16T06:51:24.085341Z"
          finished_at: "2026-10-16T06:52:37.870206Z"
          session_id: cb0d355e-818f-4477-a860-15d83795e288
          outcome: returned
      actual_inputs:
        version: 1
        method: active-time-v3-engagement-v1
        repository: github.com/xianxu/parley.nvim
        code_head: a3365ebb9598f2eb2c074fa23bd8988f8a89e852
        tracker_head: b1fbbd35450064501982e0cfcc3430cf4ca118cc
        branch_point: 30a94402e6a3978a2ce58fbf795dc3eee9389d2d
        since: "2026-10-15T20:29:03-07:00"
        until: "2026-10-15T23:50:10-07:00"
        brain_root: /Users/xianxu/workspace/brain
        gap_minutes: 15
        commit_weight: 1
        include_assistant: true
        engagements:
            - start: "2026-10-15T20:29:03-07:00"
              end: "2026-10-15T20:29:11-07:00"
              began: "2026-10-15T20:29:03-07:00"
              roots:
                - /Users/xianxu/workspace/worktree/parley.nvim-slot4/parley.nvim
            - start: "2026-10-15T23:44:27-07:00"
              end: "2026-10-15T23:50:10-07:00"
              began: "2026-10-15T23:44:27-07:00"
              roots:
                - /Users/xianxu/workspace/worktree/parley.nvim-slot3/parley.nvim
        sources:
            - harness: claude
              id: 996b651e-5e17-47f4-9815-33d9ff25fe0d
              cwd: /Users/xianxu/workspace/worktree/parley.nvim-slot3/parley.nvim
              digest: 87d376e060c035635f70551cef40b21952810ff44f9a9097014e248cc281abef
              started: "2026-10-15T18:27:53.241Z"
              spawned: false
              bytes: 6566591
              windows:
                - start: "2026-10-15T23:44:27-07:00"
                  end: "2026-10-15T23:50:10-07:00"
            - harness: claude
              id: af31f906-121a-4f29-b30d-46e8e1b30d2a
              cwd: /Users/xianxu/workspace/worktree/parley.nvim-slot4/parley.nvim
              digest: 3db7ef153b3c464b249583a5f92aea9fbf1f958d7ee1e9de9d38f12d0de2ba1c
              started: "2026-10-16T00:42:14.062Z"
              spawned: false
              bytes: 2492502
              windows:
                - start: "2026-10-15T20:29:03-07:00"
                  end: "2026-10-15T20:29:11-07:00"
      "n": 1
      timestamp: "2026-10-15T23:52:39-07:00"
      dispatched: "2026-10-15T23:51:23-07:00"
      agent: claude
      findings:
        - kind: defect
          id: BR-1
          severity: Important
          title: SIGTERM-ignoring old proxy is never SIGKILLed; the reap cannot reach parley-spawned proxies
          detail: 'The old managed proxy is spawned by cliproxy.spawn (uv.spawn, lua/parley/cliproxy.lua:680), not fixture_process.spawn, so fixture_process.reap (tests/helpers/fixture_process.lua:61-77) never signals it. after_each''s cliproxy.stop() sends SIGTERM, which it now ignores, so it holds its port until nvim exits and the watchdog fires. False claims: cliproxy_update_spec.lua:45-46 and :482-485, fake_cliproxy:542-543, atlas/providers/cliproxy-managed.md:487-488, and the issue Spec and Core concepts. Fix: record the old pid before update(), SIGKILL it in a guarded teardown, and correct those comments and the atlas.'
          family: teardown-claim-unbacked-by-kill-path
          round: 1
        - kind: defect
          id: BR-2
          severity: Minor
          title: fixture_process.reap doc cites only cliproxy_conformance_spec as a sigterm caller
          detail: openai_tool_loop_spec:89 and stream_integrity_spec:67 also pass signal = "sigterm". It is phrased as an example, so this is a nit.
          family: doc-example-incomplete
          round: 1
      recipe: small-diff-review
      isolation: fenced
      blocked: true
    - reviewer_runs:
        - version: 1
          intent:
            disposable_root: true
            id: f0ddc047-1aa4-4083-b5ae-7fdaf2603bee
            repository: github.com/xianxu/parley.nvim
            issue_id: "000343"
            recipe: small-diff-review
            round: 2
            attempt: 1
            agent: claude
            root: /Users/xianxu/Library/Caches/sdlc/review-checkouts/8affff9517abc49e
            reviewed_head: eec0403b71acd1f29ee4207627c34023e7852f7c
            slot: parley.nvim:3
            requested_at: "2026-10-16T06:55:34.771121Z"
          phase: finished
          pid: 45773
          started_at: "2026-10-16T06:55:35.205246Z"
          finished_at: "2026-10-16T06:58:03.379206Z"
          session_id: 5a6efc96-4f51-4504-8c95-ea8f84086daf
          outcome: returned
      actual_inputs:
        version: 1
        method: active-time-v3-engagement-v1
        repository: github.com/xianxu/parley.nvim
        code_head: eec0403b71acd1f29ee4207627c34023e7852f7c
        tracker_head: b1fbbd35450064501982e0cfcc3430cf4ca118cc
        branch_point: 30a94402e6a3978a2ce58fbf795dc3eee9389d2d
        since: "2026-10-15T20:29:03-07:00"
        until: "2026-10-15T23:54:52-07:00"
        brain_root: /Users/xianxu/workspace/brain
        gap_minutes: 15
        commit_weight: 1
        include_assistant: true
        engagements:
            - start: "2026-10-15T20:29:03-07:00"
              end: "2026-10-15T20:29:11-07:00"
              began: "2026-10-15T20:29:03-07:00"
              roots:
                - /Users/xianxu/workspace/worktree/parley.nvim-slot4/parley.nvim
            - start: "2026-10-15T23:44:27-07:00"
              end: "2026-10-15T23:54:52-07:00"
              began: "2026-10-15T23:44:27-07:00"
              roots:
                - /Users/xianxu/workspace/worktree/parley.nvim-slot3/parley.nvim
        sources:
            - harness: claude
              id: 996b651e-5e17-47f4-9815-33d9ff25fe0d
              cwd: /Users/xianxu/workspace/worktree/parley.nvim-slot3/parley.nvim
              digest: a03419fb70268aaf935daf3cdef909db0c76809d6de86acfc1e4d5b68dafbd57
              started: "2026-10-15T18:27:53.241Z"
              spawned: false
              bytes: 6671737
              windows:
                - start: "2026-10-15T23:44:27-07:00"
                  end: "2026-10-15T23:54:52-07:00"
            - harness: claude
              id: af31f906-121a-4f29-b30d-46e8e1b30d2a
              cwd: /Users/xianxu/workspace/worktree/parley.nvim-slot4/parley.nvim
              digest: 95377247d907079439ff904780d224561ad2e4cb4d6b2fd25b0b95ec9445f540
              started: "2026-10-16T00:42:14.062Z"
              spawned: false
              bytes: 2493128
              windows:
                - start: "2026-10-15T20:29:03-07:00"
                  end: "2026-10-15T20:29:11-07:00"
        cuts:
            - dispatched: "2026-10-15T23:51:23-07:00"
              finalized: "2026-10-15T23:52:39-07:00"
              finalizing: false
      "n": 2
      timestamp: "2026-10-15T23:58:09-07:00"
      dispatched: "2026-10-15T23:55:34-07:00"
      agent: claude
      dispose:
        - id: BR-1
          disposition: addressed
          note: The kill path exists (held pids, kill_held in the case and in after_each) and the spec goes red at :508 without it, verified by mutation. The leftover false prose is raised as a new finding in the same family.
          round: 2
        - id: BR-2
          disposition: addressed
          note: fixture_process.lua:57-58 no longer names a single example caller.
          round: 2
      findings:
        - kind: defect
          id: BR-3
          severity: Important
          title: Comments, atlas and issue Spec still credit "the reap" with SIGKILLing the SIGTERM-ignoring proxy
          detail: '2nd in family. Rule: text naming what ends the SIGTERM-ignoring proxy must name the case''s pid kill (kill_held), never fixture_process.reap, which only signals processes from fixture_process.spawn and never reaches a proxy parley spawned. Instances at head: cliproxy_update_spec.lua:45-46 (the reap() comment justifies SIGKILL by a proxy reap never signals), fake_cliproxy:542-543 "(the spec''s reap)", atlas/providers/cliproxy-managed.md:487-488 "until a SIGKILL reap", the issue Spec sentence "the spec''s reap SIGKILLs it (the shared reap drops sigterm: its only reason was this window)", the issue Core concepts row "(the spec''s reap)", and the Plan item''s rationale. Fix all six in one pass and add a Revisions entry.'
          family: teardown-claim-unbacked-by-kill-path
          round: 2
      recipe: small-diff-review
      isolation: fenced
      blocked: true
    - reviewer_runs:
        - version: 1
          intent:
            disposable_root: true
            id: 9ff1c12f-5bc5-4d65-b495-e838cd044d64
            repository: github.com/xianxu/parley.nvim
            issue_id: "000343"
            recipe: small-diff-review
            round: 3
            attempt: 1
            agent: claude
            root: /Users/xianxu/Library/Caches/sdlc/review-checkouts/11b5b4ff912a9b05
            reviewed_head: 10db2bcdc144b82f823a01f020d0e2e0e2fbcff0
            slot: parley.nvim:3
            requested_at: "2026-10-16T06:59:34.964307Z"
          phase: finished
          pid: 69666
          started_at: "2026-10-16T06:59:35.205788Z"
          finished_at: "2026-10-16T07:05:26.623427Z"
          session_id: dd15fe84-658e-4096-bf46-63613088ae0f
          outcome: returned
      actual_inputs:
        version: 1
        method: active-time-v3-engagement-v1
        repository: github.com/xianxu/parley.nvim
        code_head: 10db2bcdc144b82f823a01f020d0e2e0e2fbcff0
        tracker_head: b1fbbd35450064501982e0cfcc3430cf4ca118cc
        branch_point: 30a94402e6a3978a2ce58fbf795dc3eee9389d2d
        since: "2026-10-15T20:29:03-07:00"
        until: "2026-10-15T23:58:59-07:00"
        brain_root: /Users/xianxu/workspace/brain
        gap_minutes: 15
        commit_weight: 1
        include_assistant: true
        engagements:
            - start: "2026-10-15T20:29:03-07:00"
              end: "2026-10-15T20:29:11-07:00"
              began: "2026-10-15T20:29:03-07:00"
              roots:
                - /Users/xianxu/workspace/worktree/parley.nvim-slot4/parley.nvim
            - start: "2026-10-15T23:44:27-07:00"
              end: "2026-10-15T23:58:59-07:00"
              began: "2026-10-15T23:44:27-07:00"
              roots:
                - /Users/xianxu/workspace/worktree/parley.nvim-slot3/parley.nvim
        sources:
            - harness: claude
              id: 996b651e-5e17-47f4-9815-33d9ff25fe0d
              cwd: /Users/xianxu/workspace/worktree/parley.nvim-slot3/parley.nvim
              digest: 8d9efaf634942c1d2dbcfffc658afdb5592ab5e2f0b5f1cb25ac9b691e874745
              started: "2026-10-15T18:27:53.241Z"
              spawned: false
              bytes: 6746050
              windows:
                - start: "2026-10-15T23:44:27-07:00"
                  end: "2026-10-15T23:58:59-07:00"
            - harness: claude
              id: af31f906-121a-4f29-b30d-46e8e1b30d2a
              cwd: /Users/xianxu/workspace/worktree/parley.nvim-slot4/parley.nvim
              digest: f4e6885084dcf407f3e03b6c6ce56850fb7cd75f885135d68b4fa188f49d6e95
              started: "2026-10-16T00:42:14.062Z"
              spawned: false
              bytes: 2795539
              windows:
                - start: "2026-10-15T20:29:03-07:00"
                  end: "2026-10-15T20:29:11-07:00"
        cuts:
            - dispatched: "2026-10-15T23:51:23-07:00"
              finalized: "2026-10-15T23:52:39-07:00"
              finalizing: false
            - dispatched: "2026-10-15T23:55:34-07:00"
              finalized: "2026-10-15T23:58:09-07:00"
              finalizing: false
      "n": 3
      timestamp: "2026-10-16T00:05:28-07:00"
      dispatched: "2026-10-15T23:59:34-07:00"
      agent: claude
      dispose:
        - id: BR-3
          disposition: addressed
          note: All six instances fixed at head - spec reap comment (cliproxy_update_spec.lua:45-47), fake_cliproxy:542-546, atlas cliproxy-managed.md:487-489, issue Spec, Core concepts row, Plan item - plus a Revisions entry; prose-only, and the kill path itself is pinned by cliproxy_update_spec.lua:509-512.
          round: 3
      findings:
        - kind: defect
          id: BR-4
          severity: Minor
          title: Issue Done-when clause 1 still says the held proxy "then is reaped"
          detail: '3rd in family. Rule: any text saying what ends the SIGTERM-ignoring proxy must name the case''s own pid SIGKILL (kill_held), never "reap", because fixture_process.reap only signals fixture_process.spawn children. Enumeration in this window: the only remaining instance is the "e.g." in Done-when clause 1. All code, atlas and Spec/Plan/Core-concepts text is now correct. Fix: reword to "...until the case SIGKILLs the pids it held", if the flow allows editing Done-when.'
          family: teardown-claim-unbacked-by-kill-path
          round: 3
      recipe: small-diff-review
      isolation: fenced
      reviewed: 10db2bcdc144b82f823a01f020d0e2e0e2fbcff0
      blocked: false
---

# Gate ledger — parley.nvim#343 (boundary-review)

Findings this gate raised, the stable ids the binary assigned them, and how
later rounds disposed of them. Generated — edit the gate, not this file.

## Round 1 — 2026-10-15T23:52:39-07:00 (claude) — BLOCKED

### Raised

- **BR-1** [Important] `teardown-claim-unbacked-by-kill-path` (kind: defect) SIGTERM-ignoring old proxy is never SIGKILLed; the reap cannot reach parley-spawned proxies
  The old managed proxy is spawned by cliproxy.spawn (uv.spawn, lua/parley/cliproxy.lua:680), not fixture_process.spawn, so fixture_process.reap (tests/helpers/fixture_process.lua:61-77) never signals it. after_each's cliproxy.stop() sends SIGTERM, which it now ignores, so it holds its port until nvim exits and the watchdog fires. False claims: cliproxy_update_spec.lua:45-46 and :482-485, fake_cliproxy:542-543, atlas/providers/cliproxy-managed.md:487-488, and the issue Spec and Core concepts. Fix: record the old pid before update(), SIGKILL it in a guarded teardown, and correct those comments and the atlas.
- **BR-2** [Minor] `doc-example-incomplete` (kind: defect) fixture_process.reap doc cites only cliproxy_conformance_spec as a sigterm caller
  openai_tool_loop_spec:89 and stream_integrity_spec:67 also pass signal = "sigterm". It is phrased as an example, so this is a nit.

## Round 2 — 2026-10-15T23:58:09-07:00 (claude) — BLOCKED

### Disposed

- BR-1 — addressed — The kill path exists (held pids, kill_held in the case and in after_each) and the spec goes red at :508 without it, verified by mutation. The leftover false prose is raised as a new finding in the same family.
- BR-2 — addressed — fixture_process.lua:57-58 no longer names a single example caller.

### Raised

- **BR-3** [Important] `teardown-claim-unbacked-by-kill-path` (kind: defect) Comments, atlas and issue Spec still credit "the reap" with SIGKILLing the SIGTERM-ignoring proxy
  2nd in family. Rule: text naming what ends the SIGTERM-ignoring proxy must name the case's pid kill (kill_held), never fixture_process.reap, which only signals processes from fixture_process.spawn and never reaches a proxy parley spawned. Instances at head: cliproxy_update_spec.lua:45-46 (the reap() comment justifies SIGKILL by a proxy reap never signals), fake_cliproxy:542-543 "(the spec's reap)", atlas/providers/cliproxy-managed.md:487-488 "until a SIGKILL reap", the issue Spec sentence "the spec's reap SIGKILLs it (the shared reap drops sigterm: its only reason was this window)", the issue Core concepts row "(the spec's reap)", and the Plan item's rationale. Fix all six in one pass and add a Revisions entry.

## Round 3 — 2026-10-16T00:05:28-07:00 (claude) — passed

### Disposed

- BR-3 — addressed — All six instances fixed at head - spec reap comment (cliproxy_update_spec.lua:45-47), fake_cliproxy:542-546, atlas cliproxy-managed.md:487-489, issue Spec, Core concepts row, Plan item - plus a Revisions entry; prose-only, and the kill path itself is pinned by cliproxy_update_spec.lua:509-512.

### Raised

- **BR-4** [Minor] `teardown-claim-unbacked-by-kill-path` (kind: defect) Issue Done-when clause 1 still says the held proxy "then is reaped"
  3rd in family. Rule: any text saying what ends the SIGTERM-ignoring proxy must name the case's own pid SIGKILL (kill_held), never "reap", because fixture_process.reap only signals fixture_process.spawn children. Enumeration in this window: the only remaining instance is the "e.g." in Done-when clause 1. All code, atlas and Spec/Plan/Core-concepts text is now correct. Fix: reword to "...until the case SIGKILLs the pids it held", if the flow allows editing Done-when.

## Open findings

- **BR-4** [Minor] `teardown-claim-unbacked-by-kill-path` (kind: defect) Issue Done-when clause 1 still says the held proxy "then is reaped"
