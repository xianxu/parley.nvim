---
gate: plan-quality
issue: 266
id_prefix: PQ
rounds:
    - "n": 1
      timestamp: "2026-09-17T15:15:14-07:00"
      agent: claude
      findings:
        - id: PQ-1
          severity: Important
          title: Task 1.3 Step 3 scopes the turn notify to request_turn/release_turn, the exact exclusion the Architecture section says must not happen
          detail: Architecture states M.transition must notify whenever the turn value differs before and after, "covering request_turn, release_turn and finish_generation in one place", and names finish_generation as the most common release. Task 1.3 Step 3 then wires the notify only after request_turn/release_turn. generation_runner.lua:436 is the only terminal finish_generation caller, so a queued generation parked on a 'waiting' step is never re-armed via generation_runner.lua:498-501 — a silent hang. The finish_generation reducer sketch also sets no result.turn, so the wrapper has no value to compare; say whether the comparison comes from result.turn on all three branches or a State.snapshot read.
          family: wake-on-turn-movement
          round: 1
        - id: PQ-2
          severity: Important
          title: Task 1.3's wake test cannot be red where it is scheduled — nothing refuses a turnless write until 1.4/1.5
          detail: Step 2 expects FAIL with "b never woke after the turn was released", but Task 1.3 precedes both the 'waiting' refusal (1.4) and the machine's request_turn (1.5), so b commits its bytes immediately and the vim.wait assertion passes whether or not the notify exists. Same class as the plan's own routing-rule warning and the 1.4/1.5 ordering note. Either move the wake test after 1.5, or make 1.3's red step assert that a subscriber receives a turn event when the holder's finish_generation lands.
          family: vacuous-red-step
          round: 1
        - id: PQ-3
          severity: Minor
          title: 'Chunk 4 carries pre-renumbering references: "after M2 removes child grants" and Task 4.2''s "after 3.1 is green"'
          detail: Child grants are removed in M3 (Task 3.2b), not M2. Task 4.2's precondition "Remove only after 3.1 is green" is vacuously satisfied before M4 begins and would license removing the open_first/open_last handling at state.lua:32-45 before Task 4.1 removes the exclusion geometry those flags disambiguate; the intended precondition is 4.1.
          family: stale-milestone-refs
          round: 1
        - id: PQ-4
          severity: Minor
          title: Inline full test and implementation bodies plus a bare line-range inventory restate the diff
          detail: Tasks 1.1 and 1.2 carry complete Lua for both the spec and the module, and the closing "Verified-correct facts this plan rests on" is largely a line-number inventory with no claim attached. Both are stale on arrival and cost authoring time the code will repay better. Keep the generated-writer enumeration table — that one is the ARCH-PURPOSE class sweep and is load-bearing — and compress the rest to one strategy line per risky function.
          family: plan-compression
          round: 1
        - id: PQ-5
          severity: Minor
          title: M1's accepted latency cost has no stated bound, and its common waiter is a generation parked in preparing with no provider stream
          detail: Under M1's deliberate over-serialization a second question's provider request does not start until the first generation reaches terminal — unbounded when the holder is in a tool chain (Task 1.6 Step 4 names three indefinite stalls). Task 1.6 Step 4's visibility mitigation is written for the turn-blocked writer; state explicitly that it covers a generation blocked on its preparation write in preparing, since under M1 that is the normal case rather than an edge, and give the accepted latency a bound or say why none applies.
          family: waiter-visibility-envelope
          round: 1
      blocked: true
---

# Gate ledger — parley.nvim#266 (plan-quality)

Findings this gate raised, the stable ids the binary assigned them, and how
later rounds disposed of them. Generated — edit the gate, not this file.

## Round 1 — 2026-09-17T15:15:14-07:00 (claude) — BLOCKED

### Raised

- **PQ-1** [Important] `wake-on-turn-movement` Task 1.3 Step 3 scopes the turn notify to request_turn/release_turn, the exact exclusion the Architecture section says must not happen
  Architecture states M.transition must notify whenever the turn value differs before and after, "covering request_turn, release_turn and finish_generation in one place", and names finish_generation as the most common release. Task 1.3 Step 3 then wires the notify only after request_turn/release_turn. generation_runner.lua:436 is the only terminal finish_generation caller, so a queued generation parked on a 'waiting' step is never re-armed via generation_runner.lua:498-501 — a silent hang. The finish_generation reducer sketch also sets no result.turn, so the wrapper has no value to compare; say whether the comparison comes from result.turn on all three branches or a State.snapshot read.
- **PQ-2** [Important] `vacuous-red-step` Task 1.3's wake test cannot be red where it is scheduled — nothing refuses a turnless write until 1.4/1.5
  Step 2 expects FAIL with "b never woke after the turn was released", but Task 1.3 precedes both the 'waiting' refusal (1.4) and the machine's request_turn (1.5), so b commits its bytes immediately and the vim.wait assertion passes whether or not the notify exists. Same class as the plan's own routing-rule warning and the 1.4/1.5 ordering note. Either move the wake test after 1.5, or make 1.3's red step assert that a subscriber receives a turn event when the holder's finish_generation lands.
- **PQ-3** [Minor] `stale-milestone-refs` Chunk 4 carries pre-renumbering references: "after M2 removes child grants" and Task 4.2's "after 3.1 is green"
  Child grants are removed in M3 (Task 3.2b), not M2. Task 4.2's precondition "Remove only after 3.1 is green" is vacuously satisfied before M4 begins and would license removing the open_first/open_last handling at state.lua:32-45 before Task 4.1 removes the exclusion geometry those flags disambiguate; the intended precondition is 4.1.
- **PQ-4** [Minor] `plan-compression` Inline full test and implementation bodies plus a bare line-range inventory restate the diff
  Tasks 1.1 and 1.2 carry complete Lua for both the spec and the module, and the closing "Verified-correct facts this plan rests on" is largely a line-number inventory with no claim attached. Both are stale on arrival and cost authoring time the code will repay better. Keep the generated-writer enumeration table — that one is the ARCH-PURPOSE class sweep and is load-bearing — and compress the rest to one strategy line per risky function.
- **PQ-5** [Minor] `waiter-visibility-envelope` M1's accepted latency cost has no stated bound, and its common waiter is a generation parked in preparing with no provider stream
  Under M1's deliberate over-serialization a second question's provider request does not start until the first generation reaches terminal — unbounded when the holder is in a tool chain (Task 1.6 Step 4 names three indefinite stalls). Task 1.6 Step 4's visibility mitigation is written for the turn-blocked writer; state explicitly that it covers a generation blocked on its preparation write in preparing, since under M1 that is the normal case rather than an edge, and give the accepted latency a bound or say why none applies.

## Open findings

- **PQ-1** [Important] `wake-on-turn-movement` Task 1.3 Step 3 scopes the turn notify to request_turn/release_turn, the exact exclusion the Architecture section says must not happen
- **PQ-2** [Important] `vacuous-red-step` Task 1.3's wake test cannot be red where it is scheduled — nothing refuses a turnless write until 1.4/1.5
- **PQ-3** [Minor] `stale-milestone-refs` Chunk 4 carries pre-renumbering references: "after M2 removes child grants" and Task 4.2's "after 3.1 is green"
- **PQ-4** [Minor] `plan-compression` Inline full test and implementation bodies plus a bare line-range inventory restate the diff
- **PQ-5** [Minor] `waiter-visibility-envelope` M1's accepted latency cost has no stated bound, and its common waiter is a generation parked in preparing with no provider stream
