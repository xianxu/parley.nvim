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

## Open findings

- **BR-5** [Important] `invariant-statement-omits-exception` Target says no undo step is a partial slice "unconditionally"; a human edit between 4 KiB slices splits one write
- **BR-6** [Minor] `table-row-milestone-scope` Plan milestone references are stale after the M1/M2 merge renumbered them
