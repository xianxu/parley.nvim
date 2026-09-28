# Boundary Review — parley.nvim#293 (milestone M2)

| field | value |
|-------|-------|
| issue | 293 — writer_folds tool test flakes: tool round continuation sometimes misses the 5s wait |
| repo | parley.nvim |
| issue file | workshop/issues/000293-writer-folds-tool-test-flake.md |
| boundary | milestone M2 |
| milestone | M2 |
| window | 267dcb372e9d48160bc767cc2bf8698e10abd2c9..b7b2c22c1fd14201f7c261d964642ce8e88b3ee3 |
| command | sdlc milestone-close --issue 293 --milestone M2 |
| reviewer | claude |
| timestamp | 2026-09-27T20:35:31-07:00 |
| verdict | SHIP |

## Review

```verdict
verdict: SHIP
confidence: high
```

M2 does what the plan asked. `sequence.lua`'s `combine` and `combine_projection` now pass stored summaries straight into the supplied combines. Before, each call copied both operands and the result. I checked the two shipped combines myself. `grammar.merge_summary` (`lua/parley/document/grammar.lua:47`) builds a new `{flags={}}` and only reads its operands. `projection.combine` (`lua/parley/document/projection.lua:8`) builds a new table the same way. Neither shares a nested table with its inputs, so the purity contract holds for real. I also looked for anything that writes into a stored summary afterwards and found nothing. `M.summary` (line 561) and `may_match` (line 691) still copy before a summary leaves the sequence, so no caller receives an aliased summary. I ran both specs at HEAD `b7b2c22c`: `document_sequence_spec` passes 36/0/0, and `repair_work_budget_spec` passes its now-enabled summary-budget case, with the M3 case still pending as planned. Nothing blocks SHIP.

1. **Strengths**
   - The purity contract matches what the shipped combines actually do. Neither aliases its output to its operands, even at the nested level.
   - `document_sequence_spec.lua:16` checks the observable effect: an operand that is identical to an earlier combine output. It is not a mock. With the old copying code every operand is a fresh copy, so `reused` would stay 0 and the test would fail. It is a real regression test.
   - The property test (`:36`) keeps the checks that `copy()` used to make at runtime (at most 256 values, scalar keys, plain value types). It moves them into a seeded, reproducible check and adds checks that operands are not mutated and the output is a fresh table. This is the PQ-2 invariant move written into the plan.
   - The budget is measured by counting work, not wall time (`repair_work_budget_spec.lua`), so it can't flake. The Log records 483057 → 26224 values copied against a budget of 96000.
   - The atlas (`atlas/chat/document.md:82`) and traceability were updated in the same range.

2. **Critical:** none.

3. **Important:** none.

4. **Minor**
   - The plan says the new contract is "documented on `sequence.new`". It actually lives on the private `combine` helper (`sequence.lua:27`), and `M.new` (`:182`) has no doc saying callers must supply pure, fresh-returning combines. Add a one-line note at `M.new`.
   - The property test checks `out ~= a` only at the top level; it doesn't check that nested tables aren't shared. Today's implementations are safe, but a future combine that returns `{flags=a.flags}` would pass the test and create an alias.
   - `random_projection` uses the grammar's flag names, not the real projection keys (`exchange`, `answer`, …). That's harmless because `projection.combine` doesn't care which keys it gets, but the test would read more clearly with realistic keys.

5. **Test coverage notes**
   - The "no copy" and "pure" properties are each tested, and so is the end-to-end budget. Since the runtime check is gone, a user-supplied impure combine is now a silent-aliasing risk. Today the only `S.new` callers are `structure.lua` and the tests.

6. **Architecture**
   - ARCH-DRY: pass. `plain()` in the test deliberately restates what `copy()` checks. It is a test oracle, not duplicated production logic.
   - ARCH-PURE: pass. The sequence and both combines are pure.
   - ARCH-PURPOSE: pass. Both consumers (`combine`, `combine_projection`) and both shipped implementations are covered. The remaining metadata copies are a declared non-goal, logged with measurements.
   - ARCH-MOCK: N/A. No external dependency.
   - ARCH-CONSTRAINTS: pass. The budget is enforced by a counter test, and the claimed speedup is measured in the Log.
   - ARCH-SECURE: pass. Untrusted shapes still enter through `copy()` at summarize/insert/update (lines 155–158, 469–472). Combine outputs come from values already bounded and typed on the way in, and grammar flag keys are token kinds, a finite set.
   - ARCH-ORDER: N/A. No new state is carried between events; this changes a pure fold.
   - ARCH-FUNERAL: N/A. It creates nothing durable. Fewer in-memory copies are made, and each dies with its node.

7. **Plan revisions:** none required. The new `_VIEWPORT_MARGIN` row in the Core concepts table fixes a gap from M1, when that seam was added; it is not new scope. Optionally, fix the "documented on `sequence.new`" wording, or add the doc line at `M.new`.

```findings
findings:
  - id: new
    severity: Minor
    family: doc-overclaims-guarantee
    title: |
      Plan says the combine purity contract is documented on sequence.new; it is only on the private helper
    detail: |
      This is the 2nd finding in family doc-overclaims-guarantee. Rule: a contract the plan says is "documented on X" must appear at X, the public entry point callers read. Add a one-line purity requirement to the M.new header (sequence.lua:182) instead of rewording the plan.
  - id: new
    severity: Minor
    family: purity-test-shallow-alias
    title: |
      Purity property test checks only top-level freshness, not nested aliasing of combine outputs
    detail: |
      document_sequence_spec.lua checks out ~= a and out ~= b; a combine that returns {flags=a.flags} would pass and alias stored summaries. Walk out and assert no nested table is also reachable from a or b.
```
