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
    - "n": 7
      timestamp: "2026-09-18T10:47:42-07:00"
      agent: claude
      dispose:
        - id: BR-9
          disposition: addressed
          note: ownership.md:47-58 moves the tool-round claim under the conditional bullet and states the rule on the page; generation_turn_spec adds an edit-during-round test and a two-generation multi-call-round never-mix test, both green at HEAD.
          round: 7
        - id: BR-10
          disposition: addressed
          note: tool_use.md:185 and :195-205, architecture.md:46, tool_execution.md:5, serialize.lua:6 and plan Core concepts :83,:86,:113 corrected; grep over atlas, README, lua and plan finds no residual prevents-continuation, slot or begin_round wording.
          round: 7
        - id: BR-11
          disposition: addressed
          note: resources.lua quarantined refuses own-generation self-blocked requests at admit and pump; scheduler refuses via ledger reject and pumps after every outcome. Scratch revert of both files to c2207117 makes the new chat_async_tools_spec case fail; green with the fix.
          round: 7
        - id: BR-12
          disposition: not-addressed
          note: Still awaiting operator acknowledgment; correctly deferred to issue close and logged in the issue. Non-blocking at this milestone.
          round: 7
        - id: BR-13
          disposition: addressed
          note: tools snapshot counts settled apart from finished; tools_message says it is waiting on cleanup once every outcome is in; the present key includes settled. Pinned by chat_presentation_spec and generation_spec.
          round: 7
      findings:
        - id: BR-14
          severity: Minor
          title: 'A tool queued behind another answer''s unknown effect reads "Running tools: 0 of 1 finished" while holding the write turn indefinitely'
          detail: 'This is the 2nd finding in family stall-visibility, so the rule is stated rather than just this instance. Rule: every indefinite wait a generation can sit in must be named in presentation with what it waits on and what ends it. Enumeration: turn wait (named, with :ParleyStop), tool running (counted), cleanup wait (named, from BR-13), stale-input pause (named, with ChatResumeResponse), and resource-queued behind another generation''s unknown effect (NOT named). In that last case the waiting generation holds the document''s write turn, so every later answer shows "Waiting for the answer to line N (running tools)" until someone runs :ParleyToolOperations or stops it. The only hint is one WARN five seconds after the original unknown outcome. Before M2 the originating answer paused visibly; now it completes, and the stall surfaces in a different answer. In the same family, the model-facing refusal (scheduler.lua:103-105) blames "the same resource" even when own unknowns only fill per-generation capacity, and does not name the reconcile command. Fix sketch: pass the resource admission status (queued) through to the tools snapshot, show a note naming the held resource and :ParleyToolOperations, and word the refusal by its actual cause.'
          family: stall-visibility
          round: 7
      boundary: M2
      recipe: milestone-review
      blocked: false
    - "n": 8
      timestamp: "2026-09-18T11:58:22-07:00"
      agent: claude
      findings:
        - id: BR-15
          severity: Important
          title: A tool refused at start during flushing is written as an unknown failure, not as cancelled by the user
          detail: 'generation_runner.lua:306-313 answers a start_child still queued when Stop lands with cancelled_before_effect and a bare `true` blob. insert_tool passes it on, and response_tools.lua:42-47 settled() renders any result without an identity as failure_text(''unknown''). Scratch reproduction with the response_tools_spec harness (round declared, Runner.cancel, then drain): producer started 0 tools, yet the transcript reads "The tool call failed: it ended without reporting a result, so it may have partly taken effect." This contradicts the README, atlas/chat/ownership.md:65, tool_use.md:184 and the target, which all promise a "cancelled by the user" result. Same class, second instance: a tool queued in the scheduler at Stop. producer.cancel clears r.events (producer.lua:171) before service:cancel, so the known "cancelled before execution" outcome is dropped (:130), and the machine writes "Cancelled by the user while running; it may have partly taken effect" for a tool that never ran. Fix the class in one round: render from the outcome kind the machine records (put outcome on the insert_tool effect) instead of defaulting to unknown, and carry never-started evidence through the supervisor handoff. Add a test for each path.'
          family: result-text-weaker-than-evidence
          round: 8
        - id: BR-16
          severity: Minor
          title: Flush guarantee statements describe the machine alone, and the "remaining ways to lose a pair" list is incomplete
          detail: 'This is the 5th finding in this family, so fix the rule, not the instance. Target :206-208 and tool_use.md:184 say "a tool finished by the time its pair is reached gets its real result". In the full system the Stop cancels every running tool, the producer cuts off its callbacks (producer.lua:171, response_tools maybe_resolve), and only outcomes that arrived before the Stop are real, which matters most for a stopped answer waiting behind another. Target :212-213 says the remaining ways to lose a pair are "a second Stop, reload, or an edit that revokes the answer". Every stop() reachable from flushing also includes a failed write (generation.lua:342), a failed insert (:396), a failed gap write (:296) and an overflow (:468). Rule: a sentence stating what a mechanism guarantees, or listing how it can fail, must be derived from the composed system''s enumeration (every stop() reachable from the phase, plus the adapter''s cancel semantics), marked as non-exhaustive, or point to the one place that enumerates. Measured prevalence: 5 findings across M1 rounds 2-5, M2 and this M3 round.'
          family: invariant-statement-omits-exception
          round: 8
        - id: BR-17
          severity: Minor
          title: The flushing note names the answer it waits behind but not what ends the wait
          detail: 'This is the 3rd finding in this family. The M2 round already stated the rule: every indefinite wait a generation can sit in is named in presentation with what it waits on AND what ends it. chat_presentation.lua:59-61 flushing_message omits the escape (a second :ParleyStop drops the rest, or stop the answer ahead), although waiting_message names :ParleyStop and the answer ahead can hang. Fix at the rule: build every wait note from one composer that requires an escape clause, and add a unit test that walks each phase the session presents while blocked (waiting, running tools, cleanup, flushing, paused) and asserts that an escape is named.'
          family: stall-visibility
          round: 8
        - id: BR-18
          severity: Minor
          title: :ParleyToolOperations still speaks of quarantine that M3 removed for crashed tools
          detail: 'This is the 2nd finding in this family. tool_operations.lua:21 prompts "Esc keeps quarantine" and :29 says "Resources remain reserved until cleanup is confirmed". A crashed tool whose process has ended (listed until its generation closes) holds nothing, and its cleanup is already confirmed. The M2 rule swept atlas, README, code comments and the plan. It must also cover user-visible strings (prompts, notifications, model-facing results): `git grep -i quarantin lua/` finds this one. Measured: 1 residual site (2 strings) after the M3 sweep.'
          family: behavior-change-sweep-by-claim
          round: 8
        - id: BR-19
          severity: Minor
          title: The plan's ARCH-ORDER phase line omits flushing; Chunk 3b steps are unticked
          detail: Plan :129-130 still lists preparing, requesting, executing_tools, draining, finalizing and terminal, plus stopping; it has no executing_tools to flushing to stopping arrow, although that section calls itself "the design". Chunk 3b's step checkboxes are all unticked while the issue marks the work done. Add a Revisions entry extending the phase line with flushing's entry and exits, and tick the steps.
          family: design-enumeration-lags-code
          round: 8
      boundary: M3
      recipe: milestone-review
      blocked: true
    - "n": 9
      timestamp: "2026-09-18T12:32:53-07:00"
      agent: claude
      dispose:
        - id: BR-15
          disposition: addressed
          note: 'Both instances fixed and each pinned by a test that fails without it (scratch-worktree reverts): generation.lua:418-419 + generation_spec "records a tool refused before it ran during the flush"; producer.lua:177-178 + tool_producer_spec "settles a cancelled tool that never started by its own outcome"; plus end-to-end response_tools_spec asserting zero producer starts and the rendered text. Residual: the third claimed mechanism (insert_tool outcome field) is unreachable — raised separately.'
          round: 9
        - id: BR-16
          disposition: addressed
          note: atlas/providers/tool_use.md:191-219 now states the flush's per-tool results and its early exits once; I re-enumerated every stop() in generation.lua and the reachable set matches exactly. The target withdraws the two incomplete sentences by Revision and points there, and lessons.md records the composed-system rule.
          round: 9
        - id: BR-17
          disposition: addressed
          note: chat_presentation.lua:57-60 wait_note asserts an escape clause, so a wait note cannot be written without one; chat_presentation_spec walks every note. Reverting flushing_message to a bare string reds two tests in a scratch copy.
          round: 9
        - id: BR-18
          disposition: addressed
          note: tool_operations.lua:21,30 reworded and the resource sentence conditioned on physical_resolved; `git grep -i quarantin lua/` now returns only operation.lua:105, a comment stating it is not a quarantine. The two remaining atlas hits are file-descriptor quarantine, an unrelated concept.
          round: 9
        - id: BR-19
          disposition: addressed
          note: Plan :131-134 adds executing_tools → flushing → stopping with its entry and exits and points at the single statement; Chunk 3b steps are ticked; a Revisions entry records the round-1 response.
          round: 9
      findings:
        - id: BR-20
          severity: Minor
          title: The insert_tool `outcome` field and settled()'s third parameter have no reachable consumer, and the second caller was not updated
          detail: 'generation.lua:129 adds `outcome` to the insert_tool effect, generation_runner.lua:521 forwards it as ctx.outcome, and response_tools.lua:43,144 renders from it. The branch is unreachable: a cancelled_before_effect during a flush already sets child.cancelled=''queued'' (generation.lua:419), which routes to ctx.failure, and every other blob reaching settled() carries identity. Evidence - reverting both hunks leaves the whole providers/tool_use key green (617/617); planting an assert in the branch and running the full suite in a scratch worktree fires it in none of 213 unit + 161 integration spec files. The plan''s round-1 Revisions entry credits this as mechanism (3) of the BR-15 fix. Separately, continue_round still calls settled(c,ctx.results[i]) with no outcome (response_tools.lua:193), so the function''s own comment "One function for both readers, so the transcript and the wire cannot differ" is false the moment the branch becomes reachable. Rule: a mechanism a fix claims must have a consumer a test enters, and a shared renderer that gains an input must gain it at every call site. Either delete the plumbing and correct the plan bullet, or make it the mechanism, pass it from continue_round too, and cover it.'
          family: fix-without-reachable-consumer
          round: 9
        - id: BR-21
          severity: Minor
          title: README restates what a Stop writes instead of pointing at the single statement created this round
          detail: 'This is the 6th finding in this family. Earlier rounds fixed instances; this round finally stated the rule (lessons.md, and atlas/providers/tool_use.md:191-219 "Stop during a tool round"). Do NOT fix this instance by rewording README - apply the rule that was just written. README.md:73-77 says a Stop "writes every call with its result - or a ''cancelled by the user'' error" and that "a second :ParleyStop drops the rest". Neither is derived from the composed system the new section enumerates: a tool queued in the scheduler is written with the scheduler''s own "Tool cancelled before execution" (tool_use.md:203, verified through producer.cancel -> service:cancel -> cancelled_before_effect -> outcome ''known''), and a second Stop is one of four early exits. The rule''s own remedy - "point to the one place that enumerates" - has been applied to ownership.md and the target but not to the one user-facing page. Extend the rule''s scope to README and user-visible strings, and sweep. Measured prevalence: 6 findings across M1 rounds 2-5, M2, and M3 rounds 1-2.'
          family: invariant-statement-omits-exception
          round: 9
        - id: BR-22
          severity: Minor
          title: The "queued in the scheduler, never run" row is asserted only at the producer seam, never as transcript text
          detail: 'tool_use.md:203 states a composed-system outcome - a tool the scheduler never started is written into the transcript as "Tool cancelled before execution". The only test is tool_producer_spec "settles a cancelled tool that never started by its own outcome", which asserts the producer callback, not the rendered block; no spec drives that case through response_tools into the buffer. This is the exact case BR-15 named as its second instance, so the fix''s end-to-end effect rests on my reading of the composition rather than on an oracle. Rule - a row of a behavior table that states composed-system output needs a test at the composition, not only at the seam whose contract changed. Cheapest fix: in response_tools_spec, a fake producer whose cancel delivers a known "cancelled before execution" outcome instead of the supervisor handoff, asserting the written result text.'
          family: composed-claim-tested-at-one-seam
          round: 9
      boundary: M3
      recipe: milestone-review
      blocked: false
    - "n": 10
      timestamp: "2026-09-18T14:54:00-07:00"
      agent: claude
      dispose:
        - id: BR-1
          disposition: withdrawn
          note: Already withdrawn in round 3 and not re-raised; nothing in this window revives it.
          round: 10
      findings:
        - id: BR-23
          severity: Minor
          title: Plan Core concepts still says state.lua's `writable`/`resolve` are unchanged, which M4 falsified
          detail: |-
            This is the 3rd finding in family `behavior-change-sweep-by-claim`. Do NOT fix only this instance.
            The rule exists already (lessons.md:3102-3106, BR-10): sweep the superseded CLAIM across atlas,
            README, code comments AND the plan's own Core concepts. M4's new lesson (lessons.md:3137-3142)
            restates the same rule with a different scope — it adds `tests/manual/` and `docs/` but drops the
            plan's Core concepts, and the dropped item is exactly what leaked. Fix at the rule: state the sweep
            scope ONCE as one enumerated list (atlas/, README.md, docs/, tests/manual/, code comments,
            user-visible strings, and the plan outside `## Revisions`), and derive the grep terms mechanically
            from the identifiers the diff removes (`git diff BASE..HEAD | grep '^-'`) rather than from memory.
            Measured at HEAD: plan :88 "`writable`/`resolve` are **not** changed, deliberately" — state.lua's
            `writable` is deleted and `resolve` lost `result.slots` and the `'patch range required'` rejection;
            1 live residual, atlas/README/lua/tests-manual all clean under that grep. Lesser site of the same
            class, an identifier rather than a claim: generation_runner.lua:439 still calls the answer's own
            grant `parent`. Plan fix is a `## Revisions` entry, not an overwrite.
          family: behavior-change-sweep-by-claim
          round: 10
        - id: BR-24
          severity: Minor
          title: Disjointness — the invariant that replaced reclaim_tail's overlap scan — is asserted at no seam that composes events
          detail: |-
            This is the 2nd finding in family `composed-claim-tested-at-one-seam`, so the rule, not the instance.
            Rule: when a runtime guard is deleted because an invariant makes it dead, that invariant becomes the
            guard, and it is tested by driving SEQUENCES of the production transitions and asserting it after
            every step — not by testing each transition's local contract. state.lua:243-244 and
            atlas/chat/document.md:91-93 now assert "no other live grant can cover g.last" / "disjoint from every
            other live grant"; it composes acquire's overlap refusal, observed_edit's revocation, `move`'s
            endpoint mapping, `successor_finish` and `reclaim_tail`. Tests cover only the acquire seam
            (document_state_spec:33) and single-edit revocations (:38-47). I verified by case analysis that the
            invariant holds at HEAD, so nothing is broken — but a future change to `move` or to owner selection
            would now silently let reclaim_tail narrow onto a tail another grant covers, where the deleted scan
            failed closed. Cheap fix: assert pairwise disjointness of live grants after each step of the existing
            seeded interleaving loop (document_write_plan_spec:178), and add reclaim_tail/successor_finish and
            owned boundary insertions to that event mix.
          family: composed-claim-tested-at-one-seam
          round: 10
      boundary: M4
      recipe: milestone-review
      blocked: false
    - "n": 11
      timestamp: "2026-09-18T15:17:32-07:00"
      agent: claude
      dispose:
        - id: BR-7
          disposition: addressed
          note: README:50-52 now says "finishes or pauses"; plan Target reconciliation strikes the lifetime/undo-entry sentences with a pointer to ownership.md; the family grep over README, atlas and target finds no live residual.
          round: 11
        - id: BR-8
          disposition: addressed
          note: Plan :459 struck with its Chunk-2 note, and :461 now reads "why Chunk 2 (the preparation deferral) exists".
          round: 11
        - id: BR-12
          disposition: addressed
          note: Operator decision logged 2026-09-18 ("Stop flushes the tool round, it does not drop it"), implemented in M3; the target revision "the gap closed" replaces the narrowing.
          round: 11
        - id: BR-14
          disposition: withdrawn
          note: 'Overtaken by M3''s operator decision: an unknown outcome releases its claims once its process ends (operation.lua:103-108, scheduler.lua:80-87), the self-quarantine refusal text is gone, and every tools note names :ParleyStop via wait_note. A new visibility gap in the same family is raised separately.'
          round: 11
        - id: BR-20
          disposition: addressed
          note: insert_tool carries no outcome (generation.lua:125-127), the runner passes only ctx.failure/ctx.result (generation_runner.lua:518-522), settled() takes two parameters, and plan mechanism (3) is struck by a Revision.
          round: 11
        - id: BR-21
          disposition: addressed
          note: README:73-77 now points at tool_use.md#stop-during-a-tool-round instead of paraphrasing what a Stop writes.
          round: 11
        - id: BR-22
          disposition: addressed
          note: response_tools_spec:479-490 drives the queued-in-scheduler case through the runner and asserts the rendered "Tool cancelled before execution" result text.
          round: 11
        - id: BR-23
          disposition: addressed
          note: Plan :88 struck with a pointer to the M4 Revision; no `parent` identifier remains in generation_runner, response_tools or state; lessons.md:3137-3152 states the sweep scope once, with terms taken from the diff.
          round: 11
        - id: BR-24
          disposition: addressed
          note: document_state_spec:110-154 checks disjointness after each of 80 steps over 40 seeds. In a scratch copy, planting "human edits revoke nothing" at state.lua:260 made it fail; document_write_plan_spec gains the same assertion.
          round: 11
      findings:
        - id: BR-25
          severity: Minor
          title: An output receipt erases the tools note, so an answer that gets the turn after being held shows no status while its tools run or clean up
          detail: 'This is the 4th finding in family stall-visibility, so the fix is the rule, not the instance. Rule: a wait note is state, not an event; re-show it after anything that clears the status line. What clears it: output write receipts (response_session.lua:195-196 calls s.pending:written, which hides the extmark and drops any pending progress update, chat_pending.lua:166-170); provider progress is already suppressed while s.note is set, and the playful spinner is inactive once released. changed() re-presents only when the note string changes (response_session.lua:211), so s.note stays set while nothing shows. Confirmed with a scratch integration test: answer B (text plus two tool calls) held behind A; after A finishes, B''s text and its first call block land, both tools still run, and the parley_chat_pending namespace has no extmark. Re-showing s.note after written makes "Running tools: 0 of 2 finished" appear. Worst case: all outcomes arrived while B was held and one cleanup hangs; B holds the turn and shows nothing while every other answer reads "Waiting for the answer to line N (running tools)". This contradicts atlas/chat/response_progress.md ("While the round runs, the status line counts them") and tests/manual/chat-concurrency.md ("a tool still running shows only in the pending line"). The BR-17 test exercised the composer''s strings, not the composed session; add the held-answer case to response_session_spec as the regression test.'
          family: stall-visibility
          round: 11
      recipe: milestone-review
      blocked: false
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

## Round 7 — 2026-09-18T10:47:42-07:00 (claude) — passed

### Disposed

- BR-9 — addressed — ownership.md:47-58 moves the tool-round claim under the conditional bullet and states the rule on the page; generation_turn_spec adds an edit-during-round test and a two-generation multi-call-round never-mix test, both green at HEAD.
- BR-10 — addressed — tool_use.md:185 and :195-205, architecture.md:46, tool_execution.md:5, serialize.lua:6 and plan Core concepts :83,:86,:113 corrected; grep over atlas, README, lua and plan finds no residual prevents-continuation, slot or begin_round wording.
- BR-11 — addressed — resources.lua quarantined refuses own-generation self-blocked requests at admit and pump; scheduler refuses via ledger reject and pumps after every outcome. Scratch revert of both files to c2207117 makes the new chat_async_tools_spec case fail; green with the fix.
- BR-12 — not-addressed — Still awaiting operator acknowledgment; correctly deferred to issue close and logged in the issue. Non-blocking at this milestone.
- BR-13 — addressed — tools snapshot counts settled apart from finished; tools_message says it is waiting on cleanup once every outcome is in; the present key includes settled. Pinned by chat_presentation_spec and generation_spec.

### Raised

- **BR-14** [Minor] `stall-visibility` A tool queued behind another answer's unknown effect reads "Running tools: 0 of 1 finished" while holding the write turn indefinitely
  This is the 2nd finding in family stall-visibility, so the rule is stated rather than just this instance. Rule: every indefinite wait a generation can sit in must be named in presentation with what it waits on and what ends it. Enumeration: turn wait (named, with :ParleyStop), tool running (counted), cleanup wait (named, from BR-13), stale-input pause (named, with ChatResumeResponse), and resource-queued behind another generation's unknown effect (NOT named). In that last case the waiting generation holds the document's write turn, so every later answer shows "Waiting for the answer to line N (running tools)" until someone runs :ParleyToolOperations or stops it. The only hint is one WARN five seconds after the original unknown outcome. Before M2 the originating answer paused visibly; now it completes, and the stall surfaces in a different answer. In the same family, the model-facing refusal (scheduler.lua:103-105) blames "the same resource" even when own unknowns only fill per-generation capacity, and does not name the reconcile command. Fix sketch: pass the resource admission status (queued) through to the tools snapshot, show a note naming the held resource and :ParleyToolOperations, and word the refusal by its actual cause.

## Round 8 — 2026-09-18T11:58:22-07:00 (claude) — BLOCKED

### Raised

- **BR-15** [Important] `result-text-weaker-than-evidence` A tool refused at start during flushing is written as an unknown failure, not as cancelled by the user
  generation_runner.lua:306-313 answers a start_child still queued when Stop lands with cancelled_before_effect and a bare `true` blob. insert_tool passes it on, and response_tools.lua:42-47 settled() renders any result without an identity as failure_text('unknown'). Scratch reproduction with the response_tools_spec harness (round declared, Runner.cancel, then drain): producer started 0 tools, yet the transcript reads "The tool call failed: it ended without reporting a result, so it may have partly taken effect." This contradicts the README, atlas/chat/ownership.md:65, tool_use.md:184 and the target, which all promise a "cancelled by the user" result. Same class, second instance: a tool queued in the scheduler at Stop. producer.cancel clears r.events (producer.lua:171) before service:cancel, so the known "cancelled before execution" outcome is dropped (:130), and the machine writes "Cancelled by the user while running; it may have partly taken effect" for a tool that never ran. Fix the class in one round: render from the outcome kind the machine records (put outcome on the insert_tool effect) instead of defaulting to unknown, and carry never-started evidence through the supervisor handoff. Add a test for each path.
- **BR-16** [Minor] `invariant-statement-omits-exception` Flush guarantee statements describe the machine alone, and the "remaining ways to lose a pair" list is incomplete
  This is the 5th finding in this family, so fix the rule, not the instance. Target :206-208 and tool_use.md:184 say "a tool finished by the time its pair is reached gets its real result". In the full system the Stop cancels every running tool, the producer cuts off its callbacks (producer.lua:171, response_tools maybe_resolve), and only outcomes that arrived before the Stop are real, which matters most for a stopped answer waiting behind another. Target :212-213 says the remaining ways to lose a pair are "a second Stop, reload, or an edit that revokes the answer". Every stop() reachable from flushing also includes a failed write (generation.lua:342), a failed insert (:396), a failed gap write (:296) and an overflow (:468). Rule: a sentence stating what a mechanism guarantees, or listing how it can fail, must be derived from the composed system's enumeration (every stop() reachable from the phase, plus the adapter's cancel semantics), marked as non-exhaustive, or point to the one place that enumerates. Measured prevalence: 5 findings across M1 rounds 2-5, M2 and this M3 round.
- **BR-17** [Minor] `stall-visibility` The flushing note names the answer it waits behind but not what ends the wait
  This is the 3rd finding in this family. The M2 round already stated the rule: every indefinite wait a generation can sit in is named in presentation with what it waits on AND what ends it. chat_presentation.lua:59-61 flushing_message omits the escape (a second :ParleyStop drops the rest, or stop the answer ahead), although waiting_message names :ParleyStop and the answer ahead can hang. Fix at the rule: build every wait note from one composer that requires an escape clause, and add a unit test that walks each phase the session presents while blocked (waiting, running tools, cleanup, flushing, paused) and asserts that an escape is named.
- **BR-18** [Minor] `behavior-change-sweep-by-claim` :ParleyToolOperations still speaks of quarantine that M3 removed for crashed tools
  This is the 2nd finding in this family. tool_operations.lua:21 prompts "Esc keeps quarantine" and :29 says "Resources remain reserved until cleanup is confirmed". A crashed tool whose process has ended (listed until its generation closes) holds nothing, and its cleanup is already confirmed. The M2 rule swept atlas, README, code comments and the plan. It must also cover user-visible strings (prompts, notifications, model-facing results): `git grep -i quarantin lua/` finds this one. Measured: 1 residual site (2 strings) after the M3 sweep.
- **BR-19** [Minor] `design-enumeration-lags-code` The plan's ARCH-ORDER phase line omits flushing; Chunk 3b steps are unticked
  Plan :129-130 still lists preparing, requesting, executing_tools, draining, finalizing and terminal, plus stopping; it has no executing_tools to flushing to stopping arrow, although that section calls itself "the design". Chunk 3b's step checkboxes are all unticked while the issue marks the work done. Add a Revisions entry extending the phase line with flushing's entry and exits, and tick the steps.

## Round 9 — 2026-09-18T12:32:53-07:00 (claude) — passed

### Disposed

- BR-15 — addressed — Both instances fixed and each pinned by a test that fails without it (scratch-worktree reverts): generation.lua:418-419 + generation_spec "records a tool refused before it ran during the flush"; producer.lua:177-178 + tool_producer_spec "settles a cancelled tool that never started by its own outcome"; plus end-to-end response_tools_spec asserting zero producer starts and the rendered text. Residual: the third claimed mechanism (insert_tool outcome field) is unreachable — raised separately.
- BR-16 — addressed — atlas/providers/tool_use.md:191-219 now states the flush's per-tool results and its early exits once; I re-enumerated every stop() in generation.lua and the reachable set matches exactly. The target withdraws the two incomplete sentences by Revision and points there, and lessons.md records the composed-system rule.
- BR-17 — addressed — chat_presentation.lua:57-60 wait_note asserts an escape clause, so a wait note cannot be written without one; chat_presentation_spec walks every note. Reverting flushing_message to a bare string reds two tests in a scratch copy.
- BR-18 — addressed — tool_operations.lua:21,30 reworded and the resource sentence conditioned on physical_resolved; `git grep -i quarantin lua/` now returns only operation.lua:105, a comment stating it is not a quarantine. The two remaining atlas hits are file-descriptor quarantine, an unrelated concept.
- BR-19 — addressed — Plan :131-134 adds executing_tools → flushing → stopping with its entry and exits and points at the single statement; Chunk 3b steps are ticked; a Revisions entry records the round-1 response.

### Raised

- **BR-20** [Minor] `fix-without-reachable-consumer` The insert_tool `outcome` field and settled()'s third parameter have no reachable consumer, and the second caller was not updated
  generation.lua:129 adds `outcome` to the insert_tool effect, generation_runner.lua:521 forwards it as ctx.outcome, and response_tools.lua:43,144 renders from it. The branch is unreachable: a cancelled_before_effect during a flush already sets child.cancelled='queued' (generation.lua:419), which routes to ctx.failure, and every other blob reaching settled() carries identity. Evidence - reverting both hunks leaves the whole providers/tool_use key green (617/617); planting an assert in the branch and running the full suite in a scratch worktree fires it in none of 213 unit + 161 integration spec files. The plan's round-1 Revisions entry credits this as mechanism (3) of the BR-15 fix. Separately, continue_round still calls settled(c,ctx.results[i]) with no outcome (response_tools.lua:193), so the function's own comment "One function for both readers, so the transcript and the wire cannot differ" is false the moment the branch becomes reachable. Rule: a mechanism a fix claims must have a consumer a test enters, and a shared renderer that gains an input must gain it at every call site. Either delete the plumbing and correct the plan bullet, or make it the mechanism, pass it from continue_round too, and cover it.
- **BR-21** [Minor] `invariant-statement-omits-exception` README restates what a Stop writes instead of pointing at the single statement created this round
  This is the 6th finding in this family. Earlier rounds fixed instances; this round finally stated the rule (lessons.md, and atlas/providers/tool_use.md:191-219 "Stop during a tool round"). Do NOT fix this instance by rewording README - apply the rule that was just written. README.md:73-77 says a Stop "writes every call with its result - or a 'cancelled by the user' error" and that "a second :ParleyStop drops the rest". Neither is derived from the composed system the new section enumerates: a tool queued in the scheduler is written with the scheduler's own "Tool cancelled before execution" (tool_use.md:203, verified through producer.cancel -> service:cancel -> cancelled_before_effect -> outcome 'known'), and a second Stop is one of four early exits. The rule's own remedy - "point to the one place that enumerates" - has been applied to ownership.md and the target but not to the one user-facing page. Extend the rule's scope to README and user-visible strings, and sweep. Measured prevalence: 6 findings across M1 rounds 2-5, M2, and M3 rounds 1-2.
- **BR-22** [Minor] `composed-claim-tested-at-one-seam` The "queued in the scheduler, never run" row is asserted only at the producer seam, never as transcript text
  tool_use.md:203 states a composed-system outcome - a tool the scheduler never started is written into the transcript as "Tool cancelled before execution". The only test is tool_producer_spec "settles a cancelled tool that never started by its own outcome", which asserts the producer callback, not the rendered block; no spec drives that case through response_tools into the buffer. This is the exact case BR-15 named as its second instance, so the fix's end-to-end effect rests on my reading of the composition rather than on an oracle. Rule - a row of a behavior table that states composed-system output needs a test at the composition, not only at the seam whose contract changed. Cheapest fix: in response_tools_spec, a fake producer whose cancel delivers a known "cancelled before execution" outcome instead of the supervisor handoff, asserting the written result text.

## Round 10 — 2026-09-18T14:54:00-07:00 (claude) — passed

### Disposed

- BR-1 — withdrawn — Already withdrawn in round 3 and not re-raised; nothing in this window revives it.

### Raised

- **BR-23** [Minor] `behavior-change-sweep-by-claim` Plan Core concepts still says state.lua's `writable`/`resolve` are unchanged, which M4 falsified
  This is the 3rd finding in family `behavior-change-sweep-by-claim`. Do NOT fix only this instance.
  The rule exists already (lessons.md:3102-3106, BR-10): sweep the superseded CLAIM across atlas,
  README, code comments AND the plan's own Core concepts. M4's new lesson (lessons.md:3137-3142)
  restates the same rule with a different scope — it adds `tests/manual/` and `docs/` but drops the
  plan's Core concepts, and the dropped item is exactly what leaked. Fix at the rule: state the sweep
  scope ONCE as one enumerated list (atlas/, README.md, docs/, tests/manual/, code comments,
  user-visible strings, and the plan outside `## Revisions`), and derive the grep terms mechanically
  from the identifiers the diff removes (`git diff BASE..HEAD | grep '^-'`) rather than from memory.
  Measured at HEAD: plan :88 "`writable`/`resolve` are **not** changed, deliberately" — state.lua's
  `writable` is deleted and `resolve` lost `result.slots` and the `'patch range required'` rejection;
  1 live residual, atlas/README/lua/tests-manual all clean under that grep. Lesser site of the same
  class, an identifier rather than a claim: generation_runner.lua:439 still calls the answer's own
  grant `parent`. Plan fix is a `## Revisions` entry, not an overwrite.
- **BR-24** [Minor] `composed-claim-tested-at-one-seam` Disjointness — the invariant that replaced reclaim_tail's overlap scan — is asserted at no seam that composes events
  This is the 2nd finding in family `composed-claim-tested-at-one-seam`, so the rule, not the instance.
  Rule: when a runtime guard is deleted because an invariant makes it dead, that invariant becomes the
  guard, and it is tested by driving SEQUENCES of the production transitions and asserting it after
  every step — not by testing each transition's local contract. state.lua:243-244 and
  atlas/chat/document.md:91-93 now assert "no other live grant can cover g.last" / "disjoint from every
  other live grant"; it composes acquire's overlap refusal, observed_edit's revocation, `move`'s
  endpoint mapping, `successor_finish` and `reclaim_tail`. Tests cover only the acquire seam
  (document_state_spec:33) and single-edit revocations (:38-47). I verified by case analysis that the
  invariant holds at HEAD, so nothing is broken — but a future change to `move` or to owner selection
  would now silently let reclaim_tail narrow onto a tail another grant covers, where the deleted scan
  failed closed. Cheap fix: assert pairwise disjointness of live grants after each step of the existing
  seeded interleaving loop (document_write_plan_spec:178), and add reclaim_tail/successor_finish and
  owned boundary insertions to that event mix.

## Round 11 — 2026-09-18T15:17:32-07:00 (claude) — passed

### Disposed

- BR-7 — addressed — README:50-52 now says "finishes or pauses"; plan Target reconciliation strikes the lifetime/undo-entry sentences with a pointer to ownership.md; the family grep over README, atlas and target finds no live residual.
- BR-8 — addressed — Plan :459 struck with its Chunk-2 note, and :461 now reads "why Chunk 2 (the preparation deferral) exists".
- BR-12 — addressed — Operator decision logged 2026-09-18 ("Stop flushes the tool round, it does not drop it"), implemented in M3; the target revision "the gap closed" replaces the narrowing.
- BR-14 — withdrawn — Overtaken by M3's operator decision: an unknown outcome releases its claims once its process ends (operation.lua:103-108, scheduler.lua:80-87), the self-quarantine refusal text is gone, and every tools note names :ParleyStop via wait_note. A new visibility gap in the same family is raised separately.
- BR-20 — addressed — insert_tool carries no outcome (generation.lua:125-127), the runner passes only ctx.failure/ctx.result (generation_runner.lua:518-522), settled() takes two parameters, and plan mechanism (3) is struck by a Revision.
- BR-21 — addressed — README:73-77 now points at tool_use.md#stop-during-a-tool-round instead of paraphrasing what a Stop writes.
- BR-22 — addressed — response_tools_spec:479-490 drives the queued-in-scheduler case through the runner and asserts the rendered "Tool cancelled before execution" result text.
- BR-23 — addressed — Plan :88 struck with a pointer to the M4 Revision; no `parent` identifier remains in generation_runner, response_tools or state; lessons.md:3137-3152 states the sweep scope once, with terms taken from the diff.
- BR-24 — addressed — document_state_spec:110-154 checks disjointness after each of 80 steps over 40 seeds. In a scratch copy, planting "human edits revoke nothing" at state.lua:260 made it fail; document_write_plan_spec gains the same assertion.

### Raised

- **BR-25** [Minor] `stall-visibility` An output receipt erases the tools note, so an answer that gets the turn after being held shows no status while its tools run or clean up
  This is the 4th finding in family stall-visibility, so the fix is the rule, not the instance. Rule: a wait note is state, not an event; re-show it after anything that clears the status line. What clears it: output write receipts (response_session.lua:195-196 calls s.pending:written, which hides the extmark and drops any pending progress update, chat_pending.lua:166-170); provider progress is already suppressed while s.note is set, and the playful spinner is inactive once released. changed() re-presents only when the note string changes (response_session.lua:211), so s.note stays set while nothing shows. Confirmed with a scratch integration test: answer B (text plus two tool calls) held behind A; after A finishes, B's text and its first call block land, both tools still run, and the parley_chat_pending namespace has no extmark. Re-showing s.note after written makes "Running tools: 0 of 2 finished" appear. Worst case: all outcomes arrived while B was held and one cleanup hangs; B holds the turn and shows nothing while every other answer reads "Waiting for the answer to line N (running tools)". This contradicts atlas/chat/response_progress.md ("While the round runs, the status line counts them") and tests/manual/chat-concurrency.md ("a tool still running shows only in the pending line"). The BR-17 test exercised the composer's strings, not the composed session; add the held-answer case to response_session_spec as the regression test.

## Open findings

- **BR-25** [Minor] `stall-visibility` An output receipt erases the tools note, so an answer that gets the turn after being held shows no status while its tools run or clean up
