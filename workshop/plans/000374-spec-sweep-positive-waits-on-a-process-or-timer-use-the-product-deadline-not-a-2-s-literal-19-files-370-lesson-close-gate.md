---
gate: boundary-review
issue: 374
id_prefix: BR
rounds:
    - reviewer_runs:
        - version: 1
          intent:
            disposable_root: true
            id: c08f53cd-b76e-49e2-a6cb-d58aab6f450e
            repository: github.com/xianxu/parley.nvim
            issue_id: "000374"
            recipe: small-diff-review
            round: 1
            attempt: 1
            agent: claude
            root: /Users/xianxu/Library/Caches/sdlc/review-checkouts/b35dd15abe443f61
            reviewed_head: 195b203c00f0b39c8e9007e9aa730b7c3e6dfcb8
            slot: parley.nvim:3
            requested_at: "2026-10-17T11:38:51.589203Z"
          phase: finished
          pid: 77938
          started_at: "2026-10-17T11:38:51.868497Z"
          finished_at: "2026-10-17T11:40:35.393212Z"
          session_id: 0fd3f54c-aedb-4405-82a1-54079d340fd0
          outcome: returned
      actual_inputs:
        version: 1
        method: active-time-v3-engagement-v1
        repository: github.com/xianxu/parley.nvim
        code_head: 195b203c00f0b39c8e9007e9aa730b7c3e6dfcb8
        tracker_head: 25c99eb8c9e74f663088e1b0924b109ad764777b
        branch_point: fcc6e18d062a99f7da6c823e9d3080342bdc5211
        since: "2026-10-17T03:37:23-07:00"
        until: "2026-10-17T04:38:21-07:00"
        brain_root: /Users/xianxu/workspace/brain
        gap_minutes: 15
        commit_weight: 1
        include_assistant: true
        engagements:
            - start: "2026-10-17T03:37:23-07:00"
              end: "2026-10-17T04:38:21-07:00"
              began: "2026-10-17T03:37:23-07:00"
              roots:
                - /Users/xianxu/workspace/worktree/parley.nvim-slot3/parley.nvim
        sources:
            - harness: claude
              id: 996b651e-5e17-47f4-9815-33d9ff25fe0d
              cwd: /Users/xianxu/workspace/worktree/parley.nvim-slot3/parley.nvim
              digest: 128b3ce79a7826b9b720bde9ceb6bcc10d6f4302bacf505660b140076a3f24b4
              started: "2026-10-15T18:27:53.241Z"
              spawned: false
              bytes: 23765321
              windows:
                - start: "2026-10-17T03:37:23-07:00"
                  end: "2026-10-17T04:38:21-07:00"
      "n": 1
      timestamp: "2026-10-17T04:40:36-07:00"
      dispatched: "2026-10-17T04:38:51-07:00"
      agent: claude
      findings:
        - kind: defect
          id: BR-1
          severity: Critical
          title: Bare-statement positive waits keep literal bounds, including 2 s waits in the issue's named files
          detail: 'define_spec.lua:143,160,480,760,777,791,809 and skill_invoke_spec.lua:461,546,566,604,659,698 still have vim.wait(2000, pred) followed by an assert on the waited state, so Done-when clause 1 is unmet. Same family, other 2000 ms sites: tasker_run:334, cliproxy_auth:734,779, clipboard_image:385,402,458, cliproxy_recovery_e2e:81,194, cliproxy_login:72,200, cliproxy_conformance:332. Other literals: define:273,304,324; skill_invoke:585,613,626; dispatcher_query:474; float_picker 512-1266; clipboard_image 274-475; cliproxy_catalog 45-443; cliproxy_lifecycle 215-1248; unscoped_kill:363. Use arrival.MS, ideally asserting the wait itself; leave teardown drains and return-false absence waits alone.'
          family: positive-wait-literal-bound
          round: 1
        - kind: defect
          id: BR-2
          severity: Important
          title: Local-assigned positive waits keep literals, though the plan says only two existed and both were converted
          detail: 'Unconverted: dispatcher_query:899, skill_invoke:200,377,414, chat_stop_generation:128, tool_result_evidence:26, tool_process_scope:57, cliproxy_lifecycle:1322, fixture_reaping:62, query_cache:115,127, document_scheduler:19, agentic_document:14, tasker_run:676. Convert each or mark it ''-- bound: <reason>'' (skill_invoke:377/414 fake hrtime, so the bound may matter there), and correct the plan''s claim.'
          family: positive-wait-literal-bound
          round: 1
        - kind: defect
          id: BR-3
          severity: Important
          title: Arch test only sees one-line assert forms, so new bare or local literal positive waits pass
          detail: tests/arch/arrival_budget_spec.lua FORMS match only assert*(vim.wait( on one line; the bare vim.wait(N, function ...) statement and local x = vim.wait(N, ...) forms escape it. Extend the scan to those forms (excluding return-false predicates, with a drain or bound marker for teardown drains), and update the atlas reach sentence.
          family: arch-rule-reach
          round: 1
        - kind: defect
          id: BR-4
          severity: Minor
          title: Plan and atlas overstate coverage ("every positive wait", 275 sites in 93 files)
          detail: Restate the counts and the atlas claim "Each one is bounded by arrival.MS" after the bare and local forms are swept.
          family: doc-claim-from-memory
          round: 1
      recipe: small-diff-review
      isolation: fenced
      blocked: true
    - reviewer_runs:
        - version: 1
          intent:
            disposable_root: true
            id: 50a82fed-553f-4804-ad3d-dbd46e137a79
            repository: github.com/xianxu/parley.nvim
            issue_id: "000374"
            recipe: small-diff-review
            round: 2
            attempt: 1
            agent: claude
            root: /Users/xianxu/Library/Caches/sdlc/review-checkouts/722f70522434ed68
            reviewed_head: 5090035e83e51b875ad3051932a743e5ce3aa88a
            slot: parley.nvim:3
            requested_at: "2026-10-17T12:03:43.712555Z"
          phase: finished
          pid: 22397
          started_at: "2026-10-17T12:03:43.808955Z"
          finished_at: "2026-10-17T12:12:12.750664Z"
          session_id: 52c9f070-e6f8-4380-98cd-5f5c28d8eb60
          outcome: returned
      actual_inputs:
        version: 1
        method: active-time-v3-engagement-v1
        repository: github.com/xianxu/parley.nvim
        code_head: 5090035e83e51b875ad3051932a743e5ce3aa88a
        tracker_head: 25c99eb8c9e74f663088e1b0924b109ad764777b
        branch_point: fcc6e18d062a99f7da6c823e9d3080342bdc5211
        since: "2026-10-17T03:37:23-07:00"
        until: "2026-10-17T05:03:28-07:00"
        brain_root: /Users/xianxu/workspace/brain
        gap_minutes: 15
        commit_weight: 1
        include_assistant: true
        engagements:
            - start: "2026-10-17T03:37:23-07:00"
              end: "2026-10-17T05:03:28-07:00"
              began: "2026-10-17T03:37:23-07:00"
              roots:
                - /Users/xianxu/workspace/worktree/parley.nvim-slot3/parley.nvim
        sources:
            - harness: claude
              id: 996b651e-5e17-47f4-9815-33d9ff25fe0d
              cwd: /Users/xianxu/workspace/worktree/parley.nvim-slot3/parley.nvim
              digest: 9c92d455b4c19e4f8359136e6958a3e0317ca77b4e5633164c2e7b041c427b54
              started: "2026-10-15T18:27:53.241Z"
              spawned: false
              bytes: 24326002
              windows:
                - start: "2026-10-17T03:37:23-07:00"
                  end: "2026-10-17T05:03:28-07:00"
        cuts:
            - dispatched: "2026-10-17T04:38:51-07:00"
              finalized: "2026-10-17T04:40:36-07:00"
              finalizing: false
      "n": 2
      timestamp: "2026-10-17T05:12:29-07:00"
      dispatched: "2026-10-17T05:03:43-07:00"
      agent: claude
      dispose:
        - id: BR-1
          disposition: addressed
          note: define_spec 143/273 and skill_invoke sites now use arrival.MS; only 25 direct literal waits remain, all marked, and I verified the line after each. cliproxy_login 72/200 are correctly absence checks.
          round: 2
        - id: BR-2
          disposition: addressed
          note: dispatcher_query 899, chat_stop_generation 128, fixture_reaping 62, tasker_run 676, cliproxy_lifecycle 1322 use arrival.MS; skill_invoke 377/414 and query_cache 115 carry honest bound markers; the plan's round-2 entry retracts the "only two" claim.
          round: 2
        - id: BR-3
          disposition: addressed
          note: The scan now reads every line that opens a wait (bare, local, asserted). Arch test passes 2/2; the remaining reach gap (a literal through a variable or default) is a different form, raised separately.
          round: 2
        - id: BR-4
          disposition: addressed
          note: Plan Revisions now states that 275/93 covered only the assert form, and the round-2 counts (158/11/11/3) match the 25 marked literals I counted. The leftover atlas overstatement is folded into the new reach finding.
          round: 2
      findings:
        - kind: defect
          id: BR-5
          severity: Important
          title: Literal wait bounds hidden behind a variable or default escape the arch rule (paste_image 3 s, fixture_reaping 6 s)
          detail: 'paste_image_spec.lua:42 waits vim.wait(ms or 3000, pred) on a spawned fake_clipboard (20 positive callers), and fixture_reaping_spec.lua:36 waits vim.wait(ms, ...) with callers at 46/63/78/87/95/103/109 passing 6000. Mutation: a `vim.wait(ms or 2000, p)` wrapper appended to outline_spec still passes the arch test. Every non-literal bound in scope: ms or 3000, ms, budget (arrival-derived), SETTLE_MS and ci.TIMEOUT_MS (product), arrival_ms (session_sync), so these two sites are the whole leak. Also a 3rd instance of positive-wait-literal-bound. The rule to fix: allowlist the bound expression (arrival.MS-derived, a named product deadline, or a reason marker) instead of only denying a digit literal. Then convert or mark the two sites and reword the atlas line "enforces it for every form".'
          family: arch-rule-reach
          round: 2
        - kind: defect
          id: BR-6
          severity: Minor
          title: arrival.MS is hardcoded to 15000 and described as the product's longest deadline, which it is not
          detail: tests/helpers/arrival.lua:15 restates config.lua:501 agentic_submit_timeout_ms instead of reading it (ARCH-DRY). Both arrival.lua:4 and atlas/infra/test_harness.md call it "the product's longest round-trip deadline", but agentic_document.lua:322 uses 3x that value and the sweep needed 2 * arrival.MS for six waits. Read the config value, and write the claim from the code (a grep of _timeout_ms uses).
          family: doc-claim-from-memory
          round: 2
      recipe: small-diff-review
      isolation: fenced
      blocked: true
    - reviewer_runs:
        - version: 1
          intent:
            disposable_root: true
            id: 73ec1b4d-66e0-46fd-a423-5e30b04e9511
            repository: github.com/xianxu/parley.nvim
            issue_id: "000374"
            recipe: small-diff-review
            round: 3
            attempt: 1
            agent: claude
            root: /Users/xianxu/Library/Caches/sdlc/review-checkouts/18de00bbbb01d4dd
            reviewed_head: 354e4d8e2e5f3c8870fbf6e828b5bf554d304b4a
            slot: parley.nvim:3
            requested_at: "2026-10-17T12:16:08.628053Z"
          phase: finished
          pid: 68321
          started_at: "2026-10-17T12:16:08.868012Z"
          finished_at: "2026-10-17T12:17:48.046072Z"
          session_id: fc8fb5bc-6c20-4eff-9d6e-249810ca5bc8
          outcome: returned
      actual_inputs:
        version: 1
        method: active-time-v3-engagement-v1
        repository: github.com/xianxu/parley.nvim
        code_head: 354e4d8e2e5f3c8870fbf6e828b5bf554d304b4a
        tracker_head: 25c99eb8c9e74f663088e1b0924b109ad764777b
        branch_point: fcc6e18d062a99f7da6c823e9d3080342bdc5211
        since: "2026-10-17T03:37:23-07:00"
        until: "2026-10-17T05:15:04-07:00"
        brain_root: /Users/xianxu/workspace/brain
        gap_minutes: 15
        commit_weight: 1
        include_assistant: true
        engagements:
            - start: "2026-10-17T03:37:23-07:00"
              end: "2026-10-17T05:15:04-07:00"
              began: "2026-10-17T03:37:23-07:00"
              roots:
                - /Users/xianxu/workspace/worktree/parley.nvim-slot3/parley.nvim
        sources:
            - harness: claude
              id: 996b651e-5e17-47f4-9815-33d9ff25fe0d
              cwd: /Users/xianxu/workspace/worktree/parley.nvim-slot3/parley.nvim
              digest: d28c8c3d77e5d4f241e866c41be331f52be748a71e7df5b73eb4b67d6ba833e8
              started: "2026-10-15T18:27:53.241Z"
              spawned: false
              bytes: 24588474
              windows:
                - start: "2026-10-17T03:37:23-07:00"
                  end: "2026-10-17T05:15:04-07:00"
        cuts:
            - dispatched: "2026-10-17T04:38:51-07:00"
              finalized: "2026-10-17T04:40:36-07:00"
              finalizing: false
            - dispatched: "2026-10-17T05:03:43-07:00"
              finalized: "2026-10-17T05:12:29-07:00"
              finalizing: false
      "n": 3
      timestamp: "2026-10-17T05:17:48-07:00"
      dispatched: "2026-10-17T05:16:08-07:00"
      agent: claude
      dispose:
        - id: BR-5
          disposition: addressed
          note: derived() at arrival_budget_spec.lua:33 accepts only bounds that derive from arrival or name an _MS deadline; I ran derived() standalone and `ms or 2000` is refused, while the old ^[%d_]+$ rule would have accepted it; paste_image:43 and fixture_reaping:36 now use arrival.MS.
          round: 3
        - id: BR-6
          disposition: addressed
          note: arrival.lua:17 reads require("parley.config").agentic_submit_timeout_ms, which is a top-level key of the returned table (config.lua:501); the "longest deadline" claim is gone from the helper and from atlas/infra/test_harness.md:329.
          round: 3
      findings:
        - kind: defect
          id: BR-7
          severity: Minor
          title: derived() accepts any bound whose text contains "arrival", so `arrival_ms or 2000` and `math.min(arrival.MS, 2000)` pass
          detail: 'This is the 3rd finding in family arch-rule-reach. The fix is a rule for the whole class, not this one site: accept a bound only when the WHOLE expression matches one of the allowed forms, anchored at both ends: ^arrival%.MS$, ^%d+%s*%*%s*arrival%.MS$, ^arrival_ms$ (a child process''s by-value copy), ^[%w_.]*_MS[%s%d+*]*$, or `<param> or arrival.MS`. Anything else needs a reason marker. Evidence: I ran derived() standalone; `arrival_ms or 2000` → true, and `math.min(arrival.MS` (the capture stops at the comma) → true. No live instance in the tree today. The atlas line "allows a bound only when it derives from arrival" (test_harness.md:337) overstates the rule until it is anchored. Instances in this window: just this one predicate (arrival_budget_spec.lua:34).'
          family: arch-rule-reach
          round: 3
      recipe: small-diff-review
      isolation: fenced
      reviewed: 354e4d8e2e5f3c8870fbf6e828b5bf554d304b4a
      blocked: false
---

# Gate ledger — parley.nvim#374 (boundary-review)

Findings this gate raised, the stable ids the binary assigned them, and how
later rounds disposed of them. Generated — edit the gate, not this file.

## Round 1 — 2026-10-17T04:40:36-07:00 (claude) — BLOCKED

### Raised

- **BR-1** [Critical] `positive-wait-literal-bound` (kind: defect) Bare-statement positive waits keep literal bounds, including 2 s waits in the issue's named files
  define_spec.lua:143,160,480,760,777,791,809 and skill_invoke_spec.lua:461,546,566,604,659,698 still have vim.wait(2000, pred) followed by an assert on the waited state, so Done-when clause 1 is unmet. Same family, other 2000 ms sites: tasker_run:334, cliproxy_auth:734,779, clipboard_image:385,402,458, cliproxy_recovery_e2e:81,194, cliproxy_login:72,200, cliproxy_conformance:332. Other literals: define:273,304,324; skill_invoke:585,613,626; dispatcher_query:474; float_picker 512-1266; clipboard_image 274-475; cliproxy_catalog 45-443; cliproxy_lifecycle 215-1248; unscoped_kill:363. Use arrival.MS, ideally asserting the wait itself; leave teardown drains and return-false absence waits alone.
- **BR-2** [Important] `positive-wait-literal-bound` (kind: defect) Local-assigned positive waits keep literals, though the plan says only two existed and both were converted
  Unconverted: dispatcher_query:899, skill_invoke:200,377,414, chat_stop_generation:128, tool_result_evidence:26, tool_process_scope:57, cliproxy_lifecycle:1322, fixture_reaping:62, query_cache:115,127, document_scheduler:19, agentic_document:14, tasker_run:676. Convert each or mark it '-- bound: <reason>' (skill_invoke:377/414 fake hrtime, so the bound may matter there), and correct the plan's claim.
- **BR-3** [Important] `arch-rule-reach` (kind: defect) Arch test only sees one-line assert forms, so new bare or local literal positive waits pass
  tests/arch/arrival_budget_spec.lua FORMS match only assert*(vim.wait( on one line; the bare vim.wait(N, function ...) statement and local x = vim.wait(N, ...) forms escape it. Extend the scan to those forms (excluding return-false predicates, with a drain or bound marker for teardown drains), and update the atlas reach sentence.
- **BR-4** [Minor] `doc-claim-from-memory` (kind: defect) Plan and atlas overstate coverage ("every positive wait", 275 sites in 93 files)
  Restate the counts and the atlas claim "Each one is bounded by arrival.MS" after the bare and local forms are swept.

## Round 2 — 2026-10-17T05:12:29-07:00 (claude) — BLOCKED

### Disposed

- BR-1 — addressed — define_spec 143/273 and skill_invoke sites now use arrival.MS; only 25 direct literal waits remain, all marked, and I verified the line after each. cliproxy_login 72/200 are correctly absence checks.
- BR-2 — addressed — dispatcher_query 899, chat_stop_generation 128, fixture_reaping 62, tasker_run 676, cliproxy_lifecycle 1322 use arrival.MS; skill_invoke 377/414 and query_cache 115 carry honest bound markers; the plan's round-2 entry retracts the "only two" claim.
- BR-3 — addressed — The scan now reads every line that opens a wait (bare, local, asserted). Arch test passes 2/2; the remaining reach gap (a literal through a variable or default) is a different form, raised separately.
- BR-4 — addressed — Plan Revisions now states that 275/93 covered only the assert form, and the round-2 counts (158/11/11/3) match the 25 marked literals I counted. The leftover atlas overstatement is folded into the new reach finding.

### Raised

- **BR-5** [Important] `arch-rule-reach` (kind: defect) Literal wait bounds hidden behind a variable or default escape the arch rule (paste_image 3 s, fixture_reaping 6 s)
  paste_image_spec.lua:42 waits vim.wait(ms or 3000, pred) on a spawned fake_clipboard (20 positive callers), and fixture_reaping_spec.lua:36 waits vim.wait(ms, ...) with callers at 46/63/78/87/95/103/109 passing 6000. Mutation: a `vim.wait(ms or 2000, p)` wrapper appended to outline_spec still passes the arch test. Every non-literal bound in scope: ms or 3000, ms, budget (arrival-derived), SETTLE_MS and ci.TIMEOUT_MS (product), arrival_ms (session_sync), so these two sites are the whole leak. Also a 3rd instance of positive-wait-literal-bound. The rule to fix: allowlist the bound expression (arrival.MS-derived, a named product deadline, or a reason marker) instead of only denying a digit literal. Then convert or mark the two sites and reword the atlas line "enforces it for every form".
- **BR-6** [Minor] `doc-claim-from-memory` (kind: defect) arrival.MS is hardcoded to 15000 and described as the product's longest deadline, which it is not
  tests/helpers/arrival.lua:15 restates config.lua:501 agentic_submit_timeout_ms instead of reading it (ARCH-DRY). Both arrival.lua:4 and atlas/infra/test_harness.md call it "the product's longest round-trip deadline", but agentic_document.lua:322 uses 3x that value and the sweep needed 2 * arrival.MS for six waits. Read the config value, and write the claim from the code (a grep of _timeout_ms uses).

## Round 3 — 2026-10-17T05:17:48-07:00 (claude) — passed

### Disposed

- BR-5 — addressed — derived() at arrival_budget_spec.lua:33 accepts only bounds that derive from arrival or name an _MS deadline; I ran derived() standalone and `ms or 2000` is refused, while the old ^[%d_]+$ rule would have accepted it; paste_image:43 and fixture_reaping:36 now use arrival.MS.
- BR-6 — addressed — arrival.lua:17 reads require("parley.config").agentic_submit_timeout_ms, which is a top-level key of the returned table (config.lua:501); the "longest deadline" claim is gone from the helper and from atlas/infra/test_harness.md:329.

### Raised

- **BR-7** [Minor] `arch-rule-reach` (kind: defect) derived() accepts any bound whose text contains "arrival", so `arrival_ms or 2000` and `math.min(arrival.MS, 2000)` pass
  This is the 3rd finding in family arch-rule-reach. The fix is a rule for the whole class, not this one site: accept a bound only when the WHOLE expression matches one of the allowed forms, anchored at both ends: ^arrival%.MS$, ^%d+%s*%*%s*arrival%.MS$, ^arrival_ms$ (a child process's by-value copy), ^[%w_.]*_MS[%s%d+*]*$, or `<param> or arrival.MS`. Anything else needs a reason marker. Evidence: I ran derived() standalone; `arrival_ms or 2000` → true, and `math.min(arrival.MS` (the capture stops at the comma) → true. No live instance in the tree today. The atlas line "allows a bound only when it derives from arrival" (test_harness.md:337) overstates the rule until it is anchored. Instances in this window: just this one predicate (arrival_budget_spec.lua:34).

## Open findings

- **BR-7** [Minor] `arch-rule-reach` (kind: defect) derived() accepts any bound whose text contains "arrival", so `arrival_ms or 2000` and `math.min(arrival.MS, 2000)` pass
