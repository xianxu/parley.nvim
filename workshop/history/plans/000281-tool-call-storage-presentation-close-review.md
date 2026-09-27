# Boundary Review — parley.nvim#281 (whole-issue close)

| field | value |
|-------|-------|
| issue | 281 — Rethink tool-call storage and streaming presentation |
| repo | parley.nvim |
| issue file | workshop/issues/000281-tool-call-storage-presentation.md |
| boundary | whole-issue close |
| milestone | — |
| window | 32b6ffedf8718f45e8d616f8c69712440bc86382..f4e991a4f5e811f7d5c7bfe8d81fc0c73c596ce0 |
| command | sdlc close --issue 281 |
| reviewer | claude |
| timestamp | 2026-09-27T11:48:58-07:00 |
| verdict | SHIP |

## Review

```verdict
verdict: SHIP
confidence: high
```

**Summary.** This window only touches issue files. There are no code or atlas changes. #281 is a design investigation that ended in an operator decision (option A: keep tool payloads inline). It adds a scope revision to #264 and files two follow-ups, #290 and #291. I checked the design's line citations against the code, and they hold:
- `apply()` at `tool_folds.lua:323` clears folds in one phase and recreates them in the next (~:375-400).
- `clear_uncertainty` is called from `step()` (~:426).
- The runner slices each write to 4096 bytes (`generation_runner.lua:418`).
- The `tool_body` lookahead is at `document/grammar.lua:120`.
- `fence.for_content` is at `fence.lua:54-58`, and the structural-marker early exit is at `:148-154`.
- The result limits are 102400 default and 524288 max (`response_tools.lua:85-86`, `init.lua:891`).
- `insert_tool` builds the whole block as one string and asserts the 64 KB call limit (`response_tools.lua:136-149`).
- Tool calls are decoded only after the response completes (`response_provider.lua:57-72`).

All four `## Done when` clauses are covered. Nothing blocks SHIP. There are two minor notes.

1. **Strengths**
   - The flicker's root cause was established with a headless repro across three ways of appending a block (the table in Findings 1). That repro shows that moving results to separate files (option B) would not fix the reported symptom. This is the finding that decides the design, and it is backed by evidence rather than argued.
   - The design names the conflict with the `transcript-is-the-whole-truth` target, rather than quietly creating a hidden cache.
   - It lists every gap in the image-asset lifecycle as a whole class: prune, drill-in, exchange cut/paste, pandoc export, search, and orphan cleanup (garbage collection).
   - The follow-ups have concrete tests that can fail:
     - #264's regression loop names its tools (`D.attach` → `F.step` → `foldclosed`) and extends to thinking and summary folds (ARCH-PURPOSE).
     - #291's escape round-trip property includes the case where the escape character itself appears in a result.
   - #291 openly reverses a recorded decision ("bounded rather than chased") and explains why: the fix belongs in the serializer instead of each tool (ARCH-DRY).

2. **Critical:** none.

3. **Important:** none.

4. **Minor**
   - **Result inspection isn't stated for A.** `Done when` clause 3 asks for "result inspection" expectations for the chosen design. The Log's coverage note for (3) addresses format, pairing, context rebuild, lifecycle and compatibility. It never says how a user inspects a call's arguments, result, status or errors under A. The implied answer, unchanged folded inline blocks, should be stated in one line.
   - **Ambiguous `dispatcher.lua` path in #290.** Its Spec cites `dispatcher.lua:261-266`. Both `lua/parley/dispatcher.lua` and `lua/parley/tools/dispatcher.lua` exist, and the budget logic is in `tools/dispatcher.lua`. The citation should use the full path.

5. **Test coverage notes.** No code changed, so no tests are needed at this boundary. The scratch repro wasn't committed, which was deliberate; it is recorded as #264's regression test, which must fail before that fix lands. Verification is handed off to #264, #290 and #291 with clauses that can be tested.

6. **Architectural notes**
   - **ARCH-DRY: pass.** #291 puts the escape in the serializer rather than in each tool.
   - **ARCH-PURE: pass.** There is no code in the window. The follow-ups keep fold planning separate from the native fold work.
   - **ARCH-PURPOSE: pass.** The issue's purpose was the design decision, and the follow-ups carry the implementation. #264's revision says to fix the whole class of foldable blocks, not just tool blocks.
   - **Watch in #290:** one append of up to 512 KB in a single scheduler turn could stall the UI. The plan already requires a timing measurement, and that measurement should decide it.

7. **Plan revision recommendations:** none beyond the one-line addition on result inspection above.

```findings
findings:
  - id: new
    severity: Minor
    family: done-when-clause-coverage
    title: |
      Done-when clause 3 names result inspection, but the Log's coverage note does not address it for design A
    detail: |
      The Log item (3) covers the transcript format, id pairing, context rebuild, lifecycle and compatibility. It never states how a user inspects a call's arguments, result, status or errors under A (implied: unchanged folded inline blocks). Add one line to the coverage note.
  - id: new
    severity: Minor
    family: ambiguous-source-citation
    title: |
      #290 cites dispatcher.lua:261-266, but two dispatcher.lua files exist; the budget logic is in lua/parley/tools/dispatcher.lua
    detail: |
      Use the full path so the follow-up's implementer lands on the right file. Every other citation in the window names an unambiguous file.
```
