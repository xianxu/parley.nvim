---
gate: boundary-review
issue: 266
id_prefix: BR
rounds:
    - "n": 1
      timestamp: "2026-09-17T19:53:17-07:00"
      agent: sdlc
      findings:
        - id: BR-1
          severity: Minor
          title: Inline full test and implementation bodies plus a bare line-range inventory restate the diff
          detail: |-
            Tasks 1.1 and 1.2 carry complete Lua for both the spec and the module, and the closing "Verified-correct facts this plan rests on" is largely a line-number inventory with no claim attached. Both are stale on arrival and cost authoring time the code will repay better. Keep the generated-writer enumeration table — that one is the ARCH-PURPOSE class sweep and is load-bearing — and compress the rest to one strategy line per risky function.
            (carried from plan-quality PQ-4, deferred to the boundary review)
          family: plan-compression
          round: 1
      boundary: '*'
      no_cap: true
      blocked: false
    - "n": 2
      timestamp: "2026-09-17T19:53:17-07:00"
      agent: claude
      boundary: M1
      blocked: false
      protocol_error: no valid findings block
    - "n": 3
      timestamp: "2026-09-17T20:16:37-07:00"
      agent: claude
      dispose:
        - id: BR-1
          disposition: withdrawn
          note: Overtaken by execution. Tasks 1.1 and 1.2 are done, so their inline bodies are sunk cost, and rewriting executed tasks would break the append-Revisions-don't-overwrite rule (AGENTS.md section 1). Chunks 3-4 already carry signatures and strategy lines, not bodies, and the facts section now tells readers to verify before trusting.
          round: 3
      findings:
        - id: BR-2
          severity: Important
          title: Atlas and target say each generation's writes are one contiguous run and one undo step; pause releases the turn and undo merges only per (generation, grant)
          detail: 'atlas/chat/ownership.md:13 and transcript-is-the-whole-truth.md:117-121. Release on pause (generation.lua:97, :404, :412), now effective through the C1 fix, splits a resumed generation''s writes around another generation''s run. editor.lua:196-199 merges undo only within one (epoch, generation, grant), so a main grant plus a completion grant is already several steps; the plan''s Target reconciliation section says so. Restate as: no undo step mixes generations; contiguous while held without interruption; a pause starts a new run. Sweep every statement of the claim.'
          family: invariant-statement-omits-exception
          round: 3
        - id: BR-3
          severity: Minor
          title: blocker() and present() snapshot the machine before their cheap checks, on every sync
          detail: 'generation_runner.lua:67-68 snapshots before checking turn_status, and :110 calls present(s) unconditionally, which snapshots before comparing its key. That adds two snapshots per step, per provider delta and per document notification, including for the turn holder. Same rule as round-1 I5, which was fixed only at the coordinator: run constant-time checks before any snapshot or copy on per-chunk paths.'
          family: cheap-guard-before-copy
          round: 3
        - id: BR-4
          severity: Minor
          title: Core-concepts rows for response_tools and response_session PendingProgress describe M2 behavior without the (M2) tag
          detail: Plan lines 103 and 105 are marked modified with append-only insertion and the tool-to-pending edge, neither of which exists at M1. The sequence row already uses the (M2) tag for this situation.
          family: table-row-milestone-scope
          round: 3
      boundary: M1
      blocked: true
    - "n": 4
      timestamp: "2026-09-17T20:30:15-07:00"
      agent: claude
      dispose:
        - id: BR-2
          disposition: addressed
          note: Pause and per-grant exceptions are now carried at atlas/chat/ownership.md:12-17, the target's Revision 2 and the plan's Decisions entry; README:52 was already exact. Supported by generation_turn_spec.lua:446. The new "unconditionally" sentence is raised separately below in the same family.
          round: 4
        - id: BR-3
          disposition: addressed
          note: blocker checks turn_status and doc.turn first (generation_runner.lua:72); phases read via O(1) G.phase (generation.lua:218); sync presents only when blocked_key changes (:116-117). Behavior-preserving since present was already key-deduped. Remaining per-sync snapshots were present at base.
          round: 4
        - id: BR-4
          disposition: addressed
          note: Plan rows at :103 and :105 now carry the (M2) tag. Stale milestone references elsewhere in the plan are raised separately below in the same family.
          round: 4
      findings:
        - id: BR-5
          severity: Important
          title: Target says no undo step is a partial slice "unconditionally"; a human edit between 4 KiB slices splits one write
          detail: '2nd finding in this family; the BR-2 fix introduced it. transcript-is-the-whole-truth.md:145-146 and :120, plan :717-718, atlas/chat/ownership.md:15. editor.lua:67 clears undo_receipt on every observed edit, and a scratch spec confirmed it: 9000 bytes plus a disjoint human edit after the first slice undoes as 9000 to 4096 to 0. Rule to apply: derive undo-grouping claims from can_join_undo (editor.lua:194-202) and every undo_receipt clear (:67, :132, :179, :268). Only "no undo step mixes two generations" is unconditional; one step per run and no partial slice both require that no human edit lands mid-run. Sweep all four sites.'
          family: invariant-statement-omits-exception
          round: 4
        - id: BR-6
          severity: Minor
          title: Plan milestone references are stale after the M1/M2 merge renumbered them
          detail: '2nd finding in this family. Plan :669 closes Chunk 3 (now M2) with --milestone M3; :675 says "after M3 (Task 3.2b)" but means M2; :690 commits as "#266 M4:" for Chunk 4 (now M3); :510 says "M2-M4". Rule: every milestone reference in the plan must match the issue''s current Plan tags. After a renumbering, grep M[0-9] across the whole plan and reconcile each hit; leave the Estimate section''s historical item order as written.'
          family: table-row-milestone-scope
          round: 4
      boundary: M1
      blocked: true
    - "n": 5
      timestamp: "2026-09-17T21:02:59-07:00"
      agent: claude
      dispose:
        - id: BR-5
          disposition: addressed
          note: Target :120 and :145-146 struck; round-3 Revision defends only "no undo step mixes two generations" and points to atlas/chat/ownership.md:28-43, verified against editor.lua:194-202 and clears :67/:132/:179/:268; plan :717-718 struck; exception pinned at generation_turn_spec.lua:509. Sibling sentences at plan :709-715 and README :50-52 raised separately.
          round: 5
        - id: BR-6
          disposition: addressed
          note: Plan :510, :669, :675, :690 and eight more references now match M1 = Chunks 1-2, M2 = Chunk 3, M3 = Chunk 4. Two stale referents at :459/:461 are raised separately.
          round: 5
      findings:
        - id: BR-7
          severity: Minor
          title: Plan Target reconciliation and README still state turn/undo grouping without the pause and intervening-edit exceptions
          detail: '3rd finding in this family. Rule: turn handover and undo grouping are each stated once, in atlas/chat/ownership.md; every other live (non-Revisions) sentence states only an unconditional property ("answers are written one at a time", "no undo step mixes two answers") or names the exceptions or points there. Enforce with one grep over workshop/plans, workshop/targets, atlas and README for undo (entry|step), contiguous, one run, partial (slice|chunk), per (generation, grant), lifetime and finishes; each hit must be unconditional, a pointer, or struck. Measured at HEAD: about 20 hits, 3 live residuals. Plan :709-711 says lifetime-held means contiguous (a pause yields the turn). Plan :714-715 says "the guarantee is one undo entry per (generation, grant) run" (only while nothing intervenes). README :50-52 says a later answer appears "once the earlier one finishes" (a pause hands the turn over first; the README''s next paragraph documents that pause).'
          family: invariant-statement-omits-exception
          round: 5
        - id: BR-8
          severity: Minor
          title: Plan Task 1.6 Step 4 still uses the milestone numbering from before the merge
          detail: '3rd finding in this family. Plan :461 says "it is why M2 exists", meaning the preparation deferral, now Chunk 2 of M1; the current M2 (ordered append) does not bound that latency. Plan :459 says "Under M1 the normal waiter is a generation parked in preparing", which describes the M1 before the merge. Rule: when plan prose refers to a milestone''s content, name the chunk or task (those ids stay stable); M-labels renumber. After a renumbering, check what each M[0-9] hit refers to, not only its spelling. Measured: about 40 M-hits outside Revisions, 2 with stale referents.'
          family: table-row-milestone-scope
          round: 5
      boundary: M1
      blocked: false
    - "n": 6
      timestamp: "2026-09-18T10:27:24-07:00"
      agent: claude
      findings:
        - id: BR-9
          severity: Important
          title: Undo-grouping bullet "Undo never strands a pair apart from the text" is unconditional and falsified by an edit while tools run
          detail: 'This is the 4th finding in family invariant-statement-omits-exception; earlier rounds fixed instances, so fix it at the rule. Evidence: atlas/chat/ownership.md:47-50. In a scratch test (text, one-call round, a human edit on another line before the result), the first undo left TEXT<call1> with its result removed, because Editor:observe clears undo_receipt on any edit (editor.lua:67). No test drives undo across a tool round, although Done-when asks for a multi-call round. Rule: only claims that follow from the identity check alone may be stated without a condition. Every other undo claim, including new bullets, goes under the Conditional bullet, names the event that splits it on its own path, and ships with a test that drives that event (like the BR-5 test). Fix: move the tool-round bullet under Conditional. Add a test with an edit during a round, and one with two generations each running a multi-call round where no undo step mixes them. Measured prevalence: 4 findings across M1 rounds 2-4 and this M2 round.'
          family: invariant-statement-omits-exception
          round: 6
        - id: BR-10
          severity: Important
          title: Atlas still says an unknown outcome prevents continuation, including on the rewritten tool_use.md
          detail: 'atlas/providers/tool_use.md:195-199 ("an unknown outcome prevents continuation ... a later known outcome and positive cleanup can settle it") contradicts step 4 on the same page, and atlas/providers/architecture.md:46 repeats it. Leftover wording in the same class: tool_use.md:185 "known results"; tool_execution.md:5 "transcript slot"; tools/serialize.lua:6 "result slots"; plan Core concepts :113 (begin_round/pump) and :86 ("adapter''s round state"). Rule: sweep by grepping the superseded claim''s wording across atlas, README, code comments and the plan''s Core concepts, not only the pages the plan named.'
          family: behavior-change-sweep-by-claim
          round: 6
        - id: BR-11
          severity: Important
          title: Continuing past an unknown outcome lets a same-path retry queue forever behind the unknown call's held claims
          detail: 'generation.lua:390-399 now resolves an unknown tool on cleanup and the round continues. tools/operation.lua:103-105 releases claims only for known, cancelled or rejected outcomes. scheduler.lua:107 marks the record unknown, and resources.lua:84-92 available() still counts it as holding its claims and against per_generation/per_document capacity. A model retrying write_file on the same path therefore queues with no timeout. That is a call that never reports, so the round never continues and the generation keeps the document''s write turn until the user stops it. Before M2 an unknown outcome paused instead. Fix: fail fast with an error result when the only blocker is a held claim, or record an operator decision and say so in the error text. Add a test for the retry.'
          family: unconfirmed-outcome-permitted-actions
          round: 6
        - id: BR-12
          severity: Minor
          title: Target revision now accepts that Stop drops tool pairs whose tools already ran; logged as still to raise with the operator
          detail: workshop/targets/transcript-is-the-whole-truth.md, 2026-09-18 revision. Before M2 a call block was written before its tool started. Now a held pair whose tool has run is lost on Stop. Get explicit operator acknowledgment before the issue closes.
          family: target-narrowing-unratified
          round: 6
        - id: BR-13
          severity: Minor
          title: '"Running tools: N of N finished" also shows while the round waits on a tool''s cleanup or on writes held behind a call that never reports'
          detail: tools(s) counts outcomes, but continuation also needs cleanup, so a round stuck on cleanup reads as finished yet never continues. M1 said a stall must be visible, not mysterious; consider a distinct note for waiting on cleanup.
          family: stall-visibility
          round: 6
      boundary: M2
      recipe: milestone-review
      blocked: true
---

# Gate ledger — parley.nvim#266 (boundary-review)

Findings this gate raised, the stable ids the binary assigned them, and how
later rounds disposed of them. Generated — edit the gate, not this file.

## Round 1 — 2026-09-17T19:53:17-07:00 (sdlc) — passed

### Raised

- **BR-1** [Minor] `plan-compression` Inline full test and implementation bodies plus a bare line-range inventory restate the diff
  Tasks 1.1 and 1.2 carry complete Lua for both the spec and the module, and the closing "Verified-correct facts this plan rests on" is largely a line-number inventory with no claim attached. Both are stale on arrival and cost authoring time the code will repay better. Keep the generated-writer enumeration table — that one is the ARCH-PURPOSE class sweep and is load-bearing — and compress the rest to one strategy line per risky function.
  (carried from plan-quality PQ-4, deferred to the boundary review)

## Round 2 — 2026-09-17T19:53:17-07:00 (claude) — passed

**Protocol error:** no valid findings block — this round contributed no findings.

## Round 3 — 2026-09-17T20:16:37-07:00 (claude) — BLOCKED

### Disposed

- BR-1 — withdrawn — Overtaken by execution. Tasks 1.1 and 1.2 are done, so their inline bodies are sunk cost, and rewriting executed tasks would break the append-Revisions-don't-overwrite rule (AGENTS.md section 1). Chunks 3-4 already carry signatures and strategy lines, not bodies, and the facts section now tells readers to verify before trusting.

### Raised

- **BR-2** [Important] `invariant-statement-omits-exception` Atlas and target say each generation's writes are one contiguous run and one undo step; pause releases the turn and undo merges only per (generation, grant)
  atlas/chat/ownership.md:13 and transcript-is-the-whole-truth.md:117-121. Release on pause (generation.lua:97, :404, :412), now effective through the C1 fix, splits a resumed generation's writes around another generation's run. editor.lua:196-199 merges undo only within one (epoch, generation, grant), so a main grant plus a completion grant is already several steps; the plan's Target reconciliation section says so. Restate as: no undo step mixes generations; contiguous while held without interruption; a pause starts a new run. Sweep every statement of the claim.
- **BR-3** [Minor] `cheap-guard-before-copy` blocker() and present() snapshot the machine before their cheap checks, on every sync
  generation_runner.lua:67-68 snapshots before checking turn_status, and :110 calls present(s) unconditionally, which snapshots before comparing its key. That adds two snapshots per step, per provider delta and per document notification, including for the turn holder. Same rule as round-1 I5, which was fixed only at the coordinator: run constant-time checks before any snapshot or copy on per-chunk paths.
- **BR-4** [Minor] `table-row-milestone-scope` Core-concepts rows for response_tools and response_session PendingProgress describe M2 behavior without the (M2) tag
  Plan lines 103 and 105 are marked modified with append-only insertion and the tool-to-pending edge, neither of which exists at M1. The sequence row already uses the (M2) tag for this situation.

## Round 4 — 2026-09-17T20:30:15-07:00 (claude) — BLOCKED

### Disposed

- BR-2 — addressed — Pause and per-grant exceptions are now carried at atlas/chat/ownership.md:12-17, the target's Revision 2 and the plan's Decisions entry; README:52 was already exact. Supported by generation_turn_spec.lua:446. The new "unconditionally" sentence is raised separately below in the same family.
- BR-3 — addressed — blocker checks turn_status and doc.turn first (generation_runner.lua:72); phases read via O(1) G.phase (generation.lua:218); sync presents only when blocked_key changes (:116-117). Behavior-preserving since present was already key-deduped. Remaining per-sync snapshots were present at base.
- BR-4 — addressed — Plan rows at :103 and :105 now carry the (M2) tag. Stale milestone references elsewhere in the plan are raised separately below in the same family.

### Raised

- **BR-5** [Important] `invariant-statement-omits-exception` Target says no undo step is a partial slice "unconditionally"; a human edit between 4 KiB slices splits one write
  2nd finding in this family; the BR-2 fix introduced it. transcript-is-the-whole-truth.md:145-146 and :120, plan :717-718, atlas/chat/ownership.md:15. editor.lua:67 clears undo_receipt on every observed edit, and a scratch spec confirmed it: 9000 bytes plus a disjoint human edit after the first slice undoes as 9000 to 4096 to 0. Rule to apply: derive undo-grouping claims from can_join_undo (editor.lua:194-202) and every undo_receipt clear (:67, :132, :179, :268). Only "no undo step mixes two generations" is unconditional; one step per run and no partial slice both require that no human edit lands mid-run. Sweep all four sites.
- **BR-6** [Minor] `table-row-milestone-scope` Plan milestone references are stale after the M1/M2 merge renumbered them
  2nd finding in this family. Plan :669 closes Chunk 3 (now M2) with --milestone M3; :675 says "after M3 (Task 3.2b)" but means M2; :690 commits as "#266 M4:" for Chunk 4 (now M3); :510 says "M2-M4". Rule: every milestone reference in the plan must match the issue's current Plan tags. After a renumbering, grep M[0-9] across the whole plan and reconcile each hit; leave the Estimate section's historical item order as written.

## Round 5 — 2026-09-17T21:02:59-07:00 (claude) — passed

### Disposed

- BR-5 — addressed — Target :120 and :145-146 struck; round-3 Revision defends only "no undo step mixes two generations" and points to atlas/chat/ownership.md:28-43, verified against editor.lua:194-202 and clears :67/:132/:179/:268; plan :717-718 struck; exception pinned at generation_turn_spec.lua:509. Sibling sentences at plan :709-715 and README :50-52 raised separately.
- BR-6 — addressed — Plan :510, :669, :675, :690 and eight more references now match M1 = Chunks 1-2, M2 = Chunk 3, M3 = Chunk 4. Two stale referents at :459/:461 are raised separately.

### Raised

- **BR-7** [Minor] `invariant-statement-omits-exception` Plan Target reconciliation and README still state turn/undo grouping without the pause and intervening-edit exceptions
  3rd finding in this family. Rule: turn handover and undo grouping are each stated once, in atlas/chat/ownership.md; every other live (non-Revisions) sentence states only an unconditional property ("answers are written one at a time", "no undo step mixes two answers") or names the exceptions or points there. Enforce with one grep over workshop/plans, workshop/targets, atlas and README for undo (entry|step), contiguous, one run, partial (slice|chunk), per (generation, grant), lifetime and finishes; each hit must be unconditional, a pointer, or struck. Measured at HEAD: about 20 hits, 3 live residuals. Plan :709-711 says lifetime-held means contiguous (a pause yields the turn). Plan :714-715 says "the guarantee is one undo entry per (generation, grant) run" (only while nothing intervenes). README :50-52 says a later answer appears "once the earlier one finishes" (a pause hands the turn over first; the README's next paragraph documents that pause).
- **BR-8** [Minor] `table-row-milestone-scope` Plan Task 1.6 Step 4 still uses the milestone numbering from before the merge
  3rd finding in this family. Plan :461 says "it is why M2 exists", meaning the preparation deferral, now Chunk 2 of M1; the current M2 (ordered append) does not bound that latency. Plan :459 says "Under M1 the normal waiter is a generation parked in preparing", which describes the M1 before the merge. Rule: when plan prose refers to a milestone's content, name the chunk or task (those ids stay stable); M-labels renumber. After a renumbering, check what each M[0-9] hit refers to, not only its spelling. Measured: about 40 M-hits outside Revisions, 2 with stale referents.

## Round 6 — 2026-09-18T10:27:24-07:00 (claude) — BLOCKED

### Raised

- **BR-9** [Important] `invariant-statement-omits-exception` Undo-grouping bullet "Undo never strands a pair apart from the text" is unconditional and falsified by an edit while tools run
  This is the 4th finding in family invariant-statement-omits-exception; earlier rounds fixed instances, so fix it at the rule. Evidence: atlas/chat/ownership.md:47-50. In a scratch test (text, one-call round, a human edit on another line before the result), the first undo left TEXT<call1> with its result removed, because Editor:observe clears undo_receipt on any edit (editor.lua:67). No test drives undo across a tool round, although Done-when asks for a multi-call round. Rule: only claims that follow from the identity check alone may be stated without a condition. Every other undo claim, including new bullets, goes under the Conditional bullet, names the event that splits it on its own path, and ships with a test that drives that event (like the BR-5 test). Fix: move the tool-round bullet under Conditional. Add a test with an edit during a round, and one with two generations each running a multi-call round where no undo step mixes them. Measured prevalence: 4 findings across M1 rounds 2-4 and this M2 round.
- **BR-10** [Important] `behavior-change-sweep-by-claim` Atlas still says an unknown outcome prevents continuation, including on the rewritten tool_use.md
  atlas/providers/tool_use.md:195-199 ("an unknown outcome prevents continuation ... a later known outcome and positive cleanup can settle it") contradicts step 4 on the same page, and atlas/providers/architecture.md:46 repeats it. Leftover wording in the same class: tool_use.md:185 "known results"; tool_execution.md:5 "transcript slot"; tools/serialize.lua:6 "result slots"; plan Core concepts :113 (begin_round/pump) and :86 ("adapter's round state"). Rule: sweep by grepping the superseded claim's wording across atlas, README, code comments and the plan's Core concepts, not only the pages the plan named.
- **BR-11** [Important] `unconfirmed-outcome-permitted-actions` Continuing past an unknown outcome lets a same-path retry queue forever behind the unknown call's held claims
  generation.lua:390-399 now resolves an unknown tool on cleanup and the round continues. tools/operation.lua:103-105 releases claims only for known, cancelled or rejected outcomes. scheduler.lua:107 marks the record unknown, and resources.lua:84-92 available() still counts it as holding its claims and against per_generation/per_document capacity. A model retrying write_file on the same path therefore queues with no timeout. That is a call that never reports, so the round never continues and the generation keeps the document's write turn until the user stops it. Before M2 an unknown outcome paused instead. Fix: fail fast with an error result when the only blocker is a held claim, or record an operator decision and say so in the error text. Add a test for the retry.
- **BR-12** [Minor] `target-narrowing-unratified` Target revision now accepts that Stop drops tool pairs whose tools already ran; logged as still to raise with the operator
  workshop/targets/transcript-is-the-whole-truth.md, 2026-09-18 revision. Before M2 a call block was written before its tool started. Now a held pair whose tool has run is lost on Stop. Get explicit operator acknowledgment before the issue closes.
- **BR-13** [Minor] `stall-visibility` "Running tools: N of N finished" also shows while the round waits on a tool's cleanup or on writes held behind a call that never reports
  tools(s) counts outcomes, but continuation also needs cleanup, so a round stuck on cleanup reads as finished yet never continues. M1 said a stall must be visible, not mysterious; consider a distinct note for waiting on cleanup.

## Open findings

- **BR-7** [Minor] `invariant-statement-omits-exception` Plan Target reconciliation and README still state turn/undo grouping without the pause and intervening-edit exceptions
- **BR-8** [Minor] `table-row-milestone-scope` Plan Task 1.6 Step 4 still uses the milestone numbering from before the merge
- **BR-9** [Important] `invariant-statement-omits-exception` Undo-grouping bullet "Undo never strands a pair apart from the text" is unconditional and falsified by an edit while tools run
- **BR-10** [Important] `behavior-change-sweep-by-claim` Atlas still says an unknown outcome prevents continuation, including on the rewritten tool_use.md
- **BR-11** [Important] `unconfirmed-outcome-permitted-actions` Continuing past an unknown outcome lets a same-path retry queue forever behind the unknown call's held claims
- **BR-12** [Minor] `target-narrowing-unratified` Target revision now accepts that Stop drops tool pairs whose tools already ran; logged as still to raise with the operator
- **BR-13** [Minor] `stall-visibility` "Running tools: N of N finished" also shows while the round waits on a tool's cleanup or on writes held behind a call that never reports
