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

## Open findings

- **BR-2** [Important] `invariant-statement-omits-exception` Atlas and target say each generation's writes are one contiguous run and one undo step; pause releases the turn and undo merges only per (generation, grant)
- **BR-3** [Minor] `cheap-guard-before-copy` blocker() and present() snapshot the machine before their cheap checks, on every sync
- **BR-4** [Minor] `table-row-milestone-scope` Core-concepts rows for response_tools and response_session PendingProgress describe M2 behavior without the (M2) tag
