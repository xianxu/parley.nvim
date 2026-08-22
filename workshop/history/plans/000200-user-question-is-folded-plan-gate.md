---
gate: plan-quality
issue: 200
id_prefix: PQ
rounds:
    - "n": 1
      timestamp: "2026-08-20T10:22:40-07:00"
      agent: claude
      findings:
        - id: PQ-1
          severity: Critical
          title: Span clear deletes user folds inside an exchange, breaking an existing passing test
          detail: 'Task 2''s clear_folds_in_span spans exchange_start..last_nonempty_block_end, which includes trailing answer prose. For the fixture in tests/integration/tool_folds_spec.lua:57 that span is lines 6..26 (verified via from_parsed_chat: block 7 text, rows 25..26), so the user fold created at :64 is deleted and the assertions at :76-77 fail. The plan predicts the pre-existing suite passes and never names this test. It is also an unstated ownership-contract change from "Parley owns folds at projected start rows" to "Parley owns every fold in an exchange span".'
          round: 1
        - id: PQ-2
          severity: Important
          title: Corpus harness oracle contradicts the Task 9 fix; the adversarial fixture cannot pass
          detail: Task 4's harness classifies marker lines by raw regex over file text and asserts foldclosed == -1 for questions, == i for markers. Task 10's fixture puts them inside a tool body, where after Task 9 they are content inside the enclosing tool_result fold — so the in-body question is folded and the in-body marker reports the outer fold's start row. Both assertions fail, yet Task 10 Step 3 predicts PASS. The oracle must derive the structural-marker set from the fence grammar or the parsed model.
          round: 1
        - id: PQ-3
          severity: Important
          title: Claim that chat_parser does not model fences is false; Task 9 adds a second parallel tracker
          detail: lua/parley/chat_parser.lua:455-469 already tracks cb_state.tool_fence_len with same-length matching plus a tool_body_complete auto-transition at :428/:440. Task 9 introduces tool_fence_len/tool_awaiting_fence locals in parse_chat alongside it, with a different open pattern and a different close test, so two state machines track the same fences and can disagree. The Done-when that chat_parser derives from parley.fence is unmet while cb_append_line restates the grammar, and converting it changes parsing behavior on existing transcripts.
          round: 1
        - id: PQ-4
          severity: Important
          title: Anchor-only verification does not defend the not-swallowed half of the stated invariant
          detail: verify_anchors inspects only start_0 and ranges_fit only checks end_0 < line_count, so drift confined to an exchange's last block leaves anchors correct while end_0 overshoots into the next exchange's question line. The Spec Done-when explicitly covers swallowing, so filing the whole-range check as a future extension defers the stated purpose. Rejecting any range whose interior classifies as user is a one-line guard.
          round: 1
        - id: PQ-5
          severity: Important
          title: Per-chunk O(span) fold clearing lands on the streaming hot path with no perf note
          detail: lua/parley/chat_respond.lua:1743 wraps every streamed chunk write in with_exchange_update, so each chunk now runs two full-span walks that set the cursor and call foldlevel once per row per window, where delete_projected_folds was O(number of ranges). For a long tool-loop answer this is quadratic in answer length on the path make perf gates, and the plan does not mention the cost or the mitigation.
          round: 1
        - id: PQ-6
          severity: Minor
          title: serialize parse_call and parse_result still restate the fence grammar
          detail: Task 7 converts only fence_for and longest_backtick_run. The reader-side %1 backreference matchers at lua/parley/tools/serialize.lua:85-88 and :135 remain a hand-maintained restatement, which the ARCH-PURPOSE shadow-sweep counts as a deferred consumer.
          round: 1
        - id: PQ-7
          severity: Minor
          title: fence is a scanner over arbitrary model output but is tested with three hand-picked strings
          detail: Name a property or round-trip guard over generated and malformed bodies — open_len(for_content(s)) exceeds the longest backtick run in s, and render_result then parse_result round-trips content — rather than three literals that are blind to the malformed-input class.
          round: 1
        - id: PQ-8
          severity: Minor
          title: Corpus is 11 in-repo transcripts, not 127, and the harness globs at load time
          detail: The 127 figure is the operator's iCloud chat_dir; workshop/parley/*.md has 11 tracked files, and the working tree currently has one deleted plus two untracked. Generating one it() per globbed file makes the suite's shape vary with the working tree; state the in-repo count and pin the adversarial fixture as the real coverage.
          round: 1
        - id: PQ-9
          severity: Minor
          title: Plan states no non-goals; markdown fences in answer prose stay fence-naive
          detail: Task 9 only suppresses structural markers inside tool_use and tool_result bodies, so a question marker inside an ordinary triple-backtick block in answer prose still forks an exchange. That is a reasonable scope boundary but should be written down as a deliberate non-goal with its reason.
          round: 1
      blocked: true
    - "n": 2
      timestamp: "2026-08-20T15:09:42-07:00"
      agent: claude
      dispose:
        - id: PQ-1
          disposition: addressed
          note: Contract change now explicit and operator-decided; both encoding tests tabulated, :57 converted, :39 dispositioned by running rather than prediction.
          round: 2
        - id: PQ-2
          disposition: addressed
          note: Oracle walks the parsed exchange model; FOLDABLE exported from fold_projection instead of restated.
          round: 2
        - id: PQ-3
          disposition: addressed
          note: Verified chat_parser.lua:459-470 matches the corrected account; Task 9 converts the existing tracker and has the main loop consult it, adding no second tracker.
          round: 2
        - id: PQ-4
          disposition: addressed
          note: verify_anchors now scans each range's interior for a user classification in the same pass.
          round: 2
        - id: PQ-5
          disposition: addressed
          note: foldlevel probe plus applied-range memo, pinned by an observer-phase test and measured against tests/perf/chat_typing.lua.
          round: 2
        - id: PQ-6
          disposition: addressed
          note: Task 7 Step 3b converts the reader-side matchers at serialize.lua:88, :90, :135.
          round: 2
        - id: PQ-7
          disposition: addressed
          note: Property case over malformed backtick bodies plus a serialize round-trip replace the three literals as the real guard.
          round: 2
        - id: PQ-8
          disposition: addressed
          note: Count corrected to 10 tracked in-repo files; Task 10 Step 2's snippet still shows the old glob and should extend the git ls-files list instead.
          round: 2
        - id: PQ-9
          disposition: addressed
          note: Non-goals section states the answer-prose boundary with its reason, plus fold persistence and tilde fences.
          round: 2
      blocked: false
content_hash: abe79a1954d593a806428a72e361122dbd73e1d4a096f0e8ffa11c0fd24347b4
---

# Gate ledger — parley.nvim#200 (plan-quality)

Findings this gate raised, the stable ids the binary assigned them, and how
later rounds disposed of them. Generated — edit the gate, not this file.

## Round 1 — 2026-08-20T10:22:40-07:00 (claude) — BLOCKED

### Raised

- **PQ-1** [Critical] Span clear deletes user folds inside an exchange, breaking an existing passing test
  Task 2's clear_folds_in_span spans exchange_start..last_nonempty_block_end, which includes trailing answer prose. For the fixture in tests/integration/tool_folds_spec.lua:57 that span is lines 6..26 (verified via from_parsed_chat: block 7 text, rows 25..26), so the user fold created at :64 is deleted and the assertions at :76-77 fail. The plan predicts the pre-existing suite passes and never names this test. It is also an unstated ownership-contract change from "Parley owns folds at projected start rows" to "Parley owns every fold in an exchange span".
- **PQ-2** [Important] Corpus harness oracle contradicts the Task 9 fix; the adversarial fixture cannot pass
  Task 4's harness classifies marker lines by raw regex over file text and asserts foldclosed == -1 for questions, == i for markers. Task 10's fixture puts them inside a tool body, where after Task 9 they are content inside the enclosing tool_result fold — so the in-body question is folded and the in-body marker reports the outer fold's start row. Both assertions fail, yet Task 10 Step 3 predicts PASS. The oracle must derive the structural-marker set from the fence grammar or the parsed model.
- **PQ-3** [Important] Claim that chat_parser does not model fences is false; Task 9 adds a second parallel tracker
  lua/parley/chat_parser.lua:455-469 already tracks cb_state.tool_fence_len with same-length matching plus a tool_body_complete auto-transition at :428/:440. Task 9 introduces tool_fence_len/tool_awaiting_fence locals in parse_chat alongside it, with a different open pattern and a different close test, so two state machines track the same fences and can disagree. The Done-when that chat_parser derives from parley.fence is unmet while cb_append_line restates the grammar, and converting it changes parsing behavior on existing transcripts.
- **PQ-4** [Important] Anchor-only verification does not defend the not-swallowed half of the stated invariant
  verify_anchors inspects only start_0 and ranges_fit only checks end_0 < line_count, so drift confined to an exchange's last block leaves anchors correct while end_0 overshoots into the next exchange's question line. The Spec Done-when explicitly covers swallowing, so filing the whole-range check as a future extension defers the stated purpose. Rejecting any range whose interior classifies as user is a one-line guard.
- **PQ-5** [Important] Per-chunk O(span) fold clearing lands on the streaming hot path with no perf note
  lua/parley/chat_respond.lua:1743 wraps every streamed chunk write in with_exchange_update, so each chunk now runs two full-span walks that set the cursor and call foldlevel once per row per window, where delete_projected_folds was O(number of ranges). For a long tool-loop answer this is quadratic in answer length on the path make perf gates, and the plan does not mention the cost or the mitigation.
- **PQ-6** [Minor] serialize parse_call and parse_result still restate the fence grammar
  Task 7 converts only fence_for and longest_backtick_run. The reader-side %1 backreference matchers at lua/parley/tools/serialize.lua:85-88 and :135 remain a hand-maintained restatement, which the ARCH-PURPOSE shadow-sweep counts as a deferred consumer.
- **PQ-7** [Minor] fence is a scanner over arbitrary model output but is tested with three hand-picked strings
  Name a property or round-trip guard over generated and malformed bodies — open_len(for_content(s)) exceeds the longest backtick run in s, and render_result then parse_result round-trips content — rather than three literals that are blind to the malformed-input class.
- **PQ-8** [Minor] Corpus is 11 in-repo transcripts, not 127, and the harness globs at load time
  The 127 figure is the operator's iCloud chat_dir; workshop/parley/*.md has 11 tracked files, and the working tree currently has one deleted plus two untracked. Generating one it() per globbed file makes the suite's shape vary with the working tree; state the in-repo count and pin the adversarial fixture as the real coverage.
- **PQ-9** [Minor] Plan states no non-goals; markdown fences in answer prose stay fence-naive
  Task 9 only suppresses structural markers inside tool_use and tool_result bodies, so a question marker inside an ordinary triple-backtick block in answer prose still forks an exchange. That is a reasonable scope boundary but should be written down as a deliberate non-goal with its reason.

## Round 2 — 2026-08-20T15:09:42-07:00 (claude) — passed

### Disposed

- PQ-1 — addressed — Contract change now explicit and operator-decided; both encoding tests tabulated, :57 converted, :39 dispositioned by running rather than prediction.
- PQ-2 — addressed — Oracle walks the parsed exchange model; FOLDABLE exported from fold_projection instead of restated.
- PQ-3 — addressed — Verified chat_parser.lua:459-470 matches the corrected account; Task 9 converts the existing tracker and has the main loop consult it, adding no second tracker.
- PQ-4 — addressed — verify_anchors now scans each range's interior for a user classification in the same pass.
- PQ-5 — addressed — foldlevel probe plus applied-range memo, pinned by an observer-phase test and measured against tests/perf/chat_typing.lua.
- PQ-6 — addressed — Task 7 Step 3b converts the reader-side matchers at serialize.lua:88, :90, :135.
- PQ-7 — addressed — Property case over malformed backtick bodies plus a serialize round-trip replace the three literals as the real guard.
- PQ-8 — addressed — Count corrected to 10 tracked in-repo files; Task 10 Step 2's snippet still shows the old glob and should extend the git ls-files list instead.
- PQ-9 — addressed — Non-goals section states the answer-prose boundary with its reason, plus fold persistence and tilde fences.

## Open findings

(none — every finding has been disposed)
