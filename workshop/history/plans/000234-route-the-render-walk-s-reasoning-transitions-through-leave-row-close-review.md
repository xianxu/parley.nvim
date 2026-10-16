# Boundary Review — parley.nvim#234 (whole-issue close)

| field | value |
|-------|-------|
| issue | 234 — Route the render walk's reasoning transitions through leave_row |
| repo | parley.nvim |
| issue file | workshop/issues/000234-route-the-render-walk-s-reasoning-transitions-through-leave-row.md |
| boundary | whole-issue close |
| milestone | — |
| window | 4dec7d7dfb20ce53a8de297683a461a28f06adc8..0d857ce217bc60e8aec96af3e47191bcb8f5de8a |
| command | sdlc close --issue 234 |
| reviewer | claude |
| isolation | checkout |
| timestamp | 2026-10-16T06:44:42-07:00 |
| verdict | FIX-THEN-SHIP |

## Review

Checking how fence width is encoded in tokens vs. `classified.fence_len`, since paint and carry now advance with different widths.

Production appears to use the `document_rows` path; checking whether `document/grammar.lua` holds another copy of the reasoning rules.

The sweep missed one copy: `document/grammar.lua:138-145` has its own version of enter_row/leave_row, and that is what the production `document_rows` path reads. Next I'm running the specs.

Running the specs through the project's test harness, which requires an isolated environment.

Running the parity and parser specs individually under the harness environment.

All specs pass. Next, a mutation check that the parity test really catches the footer-verdict regression.

Mutation confirmed: the parity test fails without the fix. Now checking whether any test catches drift in the separate copy in `grammar.lua`.

Restored and clean. Getting line numbers for the findings.

```verdict
verdict: FIX-THEN-SHIP
confidence: high
```

**Summary.** The refactor of `compute_chat_highlights` is correct and does what the plan says. The render walk keeps one `state` table, stepped by the exported `enter_row`/`leave_row`. All hand-written transitions are gone from the walk: structural-kind termination, `🧠:[END]` / `🧠:` / blank, and the question-state assignments. The new parity property test passes (300 documents, seed 234). I reproduced the implementer's mutation in this checkout: limiting the `🧠:` verdict to non-footer rows turns it red (0 passed / 1 failed). Every highlight, parser, document-render and perf spec I ran is green.

The Spec asked for a sweep for other copies of the reasoning rules. That sweep missed one, and it is the copy production actually reads. `lua/parley/document/grammar.lua:139-145` hand-writes enter_row + leave_row line for line: footer reset, `reset_partition`, `advance`, then the `[END]`/`🧠:`/blank rules. It produces `render_before` for the `document_rows` path, which `compute_window_decorations` uses for live buffers. I reintroduced the exact `[END]` drift the issue names into that copy. The parity, highlighter_document, highlighting and highlight_typing specs all stayed green. The class this issue exists to close is therefore still open. This is Important, not Critical: the code shipped here is correct, and nothing observable is broken today.

1. **Strengths**
   - `lua/parley/highlighter.lua:197-217`: one state table, with the streaming overlay clearly labelled as a render-time input rather than a transition rule. The `🧠:` verdict is lifted out of the paint branch so footer rows still feed `leave_row`. That was a real bug, and the parity test found it.
   - `tests/integration/render_walk_parity_spec.lua`: a real property test with non-vacuity bounds (more than 2000 rows, more than 100 reasoning rows). It compares the actual observed paint state against `build`'s `state_before`, not a mock. The mutation check confirms it catches the bug class.
   - `highlight_structure.lua:101-105`: exporting the existing halves instead of writing new helpers keeps `derive` and the render walk on literally the same functions (ARCH-DRY pass for this pair).
   - `chat_parser_tools_spec.lua:690-718`: the intentional difference is pinned on both sides (`🧠:` in a question vs. in an answer), satisfying the last Done-when clause.

2. **Critical findings:** none.

3. **Important findings**
   - **`lua/parley/document/grammar.lua:139-145`: a third copy of the row step survives (ARCH-DRY, ARCH-PURPOSE).**
     - Lines 139-145 restate `enter_row` (footer reset + `reset_partition`) and `leave_row` (`advance` + `[END]` / `🧠:` / blank terminator) by hand.
     - This is the production render-state source: `render_before` → `document_rows` → `render_state`.
     - The Spec says "Sweep for other copies at the same time… fix the class". The sweep looked only at `chat_parser`.
     - **Mutation evidence:** I dropped `r.reasoning_explicit_end=false` from the `[END]` branch, which is the drift #234 names. All four render specs stayed green.
     - **Fix sketch:** have grammar call the shared halves. `enter_row` takes `(row0, footer_start0)` while grammar holds a `s.footer` boolean, so either give `enter_row` an `in_footer` boolean, or move the two halves into `parley.document.lexical` (which both modules already require) so neither has to depend on the other.
     - Then add a parity property test of grammar's `render_before` against `build().state_before` over the same random vocabulary.
     - **Family enumeration in this window/tree:** `highlighter.lua` walk (fixed), `highlight_structure.derive` (source), `document/grammar.lua:139-145` (open), `chat_parser` (documented as intentionally different).

4. **Minor findings**
   - **`highlighter.lua:290`:** the paint condition `line:match("^%s*$") and not in_reasoning_explicit_end` restates `leave_row`'s blank-terminator rule (ARCH-DRY). It could read from the token (`classified.token == blank`), or compare the state before and after `leave_row`.
   - **`highlighter.lua:213`:** `vim.deepcopy(state)` runs on every rendered row in the redraw hot path, even though the shared `lexical.copy_state` exists for exactly this.
   - **Parity coverage gaps:** the parity test drives only the fingerprint-structure path with `streaming=false`. The production `document_rows` path and the streaming overlay (`highlighter.lua:202-204`) are not covered.
   - **`atlas/traceability.yaml:304`:** the parity spec is mapped under `chat/lifecycle`, but it is documented in `atlas/ui/highlights.md`, so `make test-spec SPEC=ui/highlights` does not run it.

5. **Test coverage notes**
   - Ran green under the harness environment:
     - `render_walk_parity_spec`
     - `chat_parser_tools_spec` (38)
     - `highlighter_spec`
     - `highlighter_document_spec`
     - `perf_chat_typing_spec`
     - `comment_render_spec`
     - the `ui/highlights` set: `chat_treesitter`, `fence_containment`, `highlight_typing`, `highlighting`, `highlight_structure`, `render`, `timezone_diagnostics`
   - Mutation on the footer verdict: the parity test goes red, as claimed.
   - Mutation on grammar's `[END]` rule: nothing goes red (the Important finding above).
   - Done-when clause 2 ("the state each paints from equals `state_before`") is asserted only for the fingerprint-structure path.

6. **Architectural notes**
   - **ARCH-DRY:** flagged (grammar copy; minor restatement at `highlighter.lua:290`).
   - **ARCH-PURE:** pass. The transition step is pure, and the walk keeps it separate from painting.
   - **ARCH-PURPOSE:** flagged. The purpose is "one definition of how a row changes state", and the production copy still restates it.
   - Placing the row step in `lexical` would let `grammar`, `highlight_structure` and `highlighter` all consume one module without a new dependency edge.

7. **Plan revision recommendations**
   - Add a `## Revisions` entry. The sweep found `document/grammar.lua`'s render step as an additional copy. Either route it through the shared halves with a parity test, or record why it must differ and pin that with a test, the same way `chat_parser` was handled.

```findings
findings:
  - id: new
    severity: Important
    kind: defect
    family: shared-row-step-single-source
    title: |
      document/grammar.lua:139-145 still hand-writes enter_row/leave_row for the production render_before path
    detail: |
      The Spec required sweeping for other copies of the reasoning rules. grammar.lua restates the footer reset, reset_partition, advance, and the END/reasoning/blank transitions line for line, and its render_before feeds the document_rows path that compute_window_decorations uses for live buffers. Mutation: dropping reasoning_explicit_end=false from grammar's END branch (the exact drift #234 names) leaves the render_walk_parity, highlighter_document, highlighting and highlight_typing specs green. Fix: call the shared halves, moving them into parley.document.lexical or giving enter_row an in_footer boolean, and add a parity property test of grammar render_before against build().state_before. Family: highlighter walk (fixed), derive (source), grammar.lua (open), chat_parser (documented as different).
  - id: new
    severity: Minor
    kind: defect
    family: shared-row-step-single-source
    title: |
      highlighter.lua:290 blank-row paint condition restates leave_row's blank terminator rule
    detail: |
      line:match("^%s*$") and not in_reasoning_explicit_end duplicates leave_row's blank-token rule using line text. It could use classified.token == blank, or the state before and after leave_row.
  - id: new
    severity: Minor
    kind: defect
    family: render-parity-coverage-scope
    title: |
      Parity test covers only the fingerprint-structure path with streaming off
    detail: |
      render_walk_parity_spec passes a build() structure, so the document_rows production path and the streaming overlay at highlighter.lua:202-204 are never compared against state_before.
  - id: new
    severity: Minor
    kind: defect
    family: hot-path-copy-helper
    title: |
      vim.deepcopy per rendered row where lexical.copy_state exists
    detail: |
      highlighter.lua:213 deep-copies the state on every rendered row in the redraw path. The shared lexical.copy_state is the existing helper for this.
  - id: new
    severity: Minor
    kind: defect
    family: traceability-mapping-placement
    title: |
      render_walk_parity_spec mapped under chat/lifecycle rather than ui/highlights
    detail: |
      atlas/ui/highlights.md documents the test, but make test-spec SPEC=ui/highlights does not run it.
```

<!-- sdlc-review-usage [{"version":1,"intent":{"disposable_root":true,"id":"07d3876f-539e-4e4a-9aa7-9a4aa2df7953","repository":"github.com/xianxu/parley.nvim","issue_id":"000234","recipe":"small-diff-review","round":1,"attempt":1,"agent":"claude","root":"/Users/xianxu/Library/Caches/sdlc/review-checkouts/b2ac595aaeb33600","reviewed_head":"0d857ce217bc60e8aec96af3e47191bcb8f5de8a","slot":"parley.nvim:4","requested_at":"2026-10-16T13:41:17.15869Z"},"phase":"finished","pid":77885,"started_at":"2026-10-16T13:41:17.505958Z","finished_at":"2026-10-16T13:44:42.105039Z","session_id":"5264aaae-3960-4232-9000-6bba0165ab12","outcome":"returned"}] -->

---

## Re-review — 2026-10-16T07:09:18-07:00 (SHIP)

| field | value |
|-------|-------|
| issue | 234 — Route the render walk's reasoning transitions through leave_row |
| repo | parley.nvim |
| issue file | workshop/issues/000234-route-the-render-walk-s-reasoning-transitions-through-leave-row.md |
| boundary | whole-issue close |
| milestone | — |
| window | 4dec7d7dfb20ce53a8de297683a461a28f06adc8..82f1c26c445fe64022ccd0c36ef4515b41738037 |
| command | sdlc close --issue 234 |
| reviewer | claude |
| isolation | checkout |
| timestamp | 2026-10-16T07:09:18-07:00 |
| verdict | SHIP |

## Review

Checking how tests run, then running the grammar spec plus a mutation of the shared row step.

Specs are slow; checking the interim output.

Grammar spec is green under the harness. Now the mutation run on the shared row step.

BR-1's rule is now caught (highlight_structure_spec goes red). Next I'm checking that the new grammar parity test catches drift in the grammar's *inputs*, the only part that can still differ.

Both input mutations go red, so the new test does real work. Last step: checking the atlas/doc claims against highlight_structure's build and replace.

```verdict
verdict: SHIP
confidence: high
```

**Verdict: SHIP.** Round 2 fixes BR-1, the only blocking finding, and fixes it for the whole class rather than the one copy. The row step now exists once, as `enter_row` and `leave_row` in `lua/parley/document/lexical.lua:180-203`. Every state walk calls it:
- the document grammar (`grammar.lua:144-146`), which produces the `render_before` that the live-buffer render reads;
- `highlight_structure`'s build, derive and replace (`:112-114`, `:162`, `:242-252`), through a thin adapter;
- the redraw walk in `highlighter.lua` (`:207`, `:317`).

Grepping every writer of `in_reasoning` and `reasoning_explicit_end` under `lua/` leaves only state constructors, the streaming overlay, the deliberately different `chat_parser`, and the grammar's answer-scoped semantic sections; the last now has a comment saying so. The four Minor findings from round 1 were not touched this round. They stay open and do not block.

1. **Strengths**
   - **The rule moved down, not sideways.** Putting the step in `lexical`, which all three walkers already depend on, adds no new dependency. `highlight_structure.enter_row` only converts a row index into the footer boolean (`highlight_structure.lua:73-76`).
   - **The new grammar test catches real drift.** The case in `document_grammar_spec.lua:104-132` compares the grammar's `render_before` with `build`'s `state_before` over 300 random documents. I changed the grammar's inputs in two ways:
     - Passing `in_footer=false`: only this new test went red, so it is the one guarding the footer input.
     - Passing `explicit=false`: this test and two fixed cases went red.
   - **The shared rule has its own pin.** I deleted `reasoning_explicit_end=false` from the `[END]` branch of `lexical.leave_row`, which is the drift #234 is named after. `highlight_structure_spec` ("builds state, footer, and multiple half-open draft ranges") went red.
   - **The lesson is about the right thing.** The `workshop/lessons.md` entry says to sweep by searching for every writer of the state, not by checking the copy the issue happens to name.

2. **Critical findings:** none.

3. **Important findings:** none.

4. **Minor findings** (all carried over from round 1, not new)
   - BR-2: `highlighter.lua:290` still repeats the blank-line terminator rule using the line text.
   - BR-3: the walk's own `document_rows` branch and the streaming overlay (`highlighter.lua:197-205`) are still not compared against `state_before`. The grammar side of that path is now covered.
   - BR-4: `vim.deepcopy` still runs for every row at `highlighter.lua:213`.
   - BR-5: `render_walk_parity_spec` is still listed under `chat/lifecycle` in `atlas/traceability.yaml:304`.

5. **Test coverage notes**
   - **What I ran.** All of `make test-spec SPEC=chat/document` passed, including `document_grammar_spec` (15/15) and `highlighter_document_spec`. I mutated the code in this throwaway checkout and restored it after each run; `git status` was clean afterwards.
   - **Limit of the parity tests.** Both parity tests now run the same shared functions on both sides. That means they check the *inputs* (footer and lookahead verdict), not the transition rules. Only the fixed expectations in `highlight_structure_spec` pin the rules. That is correct for a single shared function, but nothing else catches a change to the rule itself.

6. **Architecture**
   - **ARCH-DRY: pass.** There is one row-step definition, and the remaining restatement is the BR-2 Minor.
   - **ARCH-PURE: pass.** The step is a pure state transition, and painting stays separate from it.
   - **ARCH-PURPOSE: pass.** Every walker that tracks render state now calls the shared step, and `chat_parser` is documented and pinned as intentionally different.
   - **Small wording issue.** The comment at `chat_parser.lua:377` says "highlight_structure's enter_row/leave_row", but they now live in `lexical`. `highlight_structure` re-exports them, so the comment is still accurate.

7. **Plan revisions:** none needed. The Core concepts row for `lexical.enter_row`/`leave_row` and the Log entry for close round 1 match the code.

```findings
dispose:
  - id: BR-1
    disposition: addressed
    note: |
      The step lives only in lexical.lua:180-203; grammar.lua:144-146 calls it. Deleting reasoning_explicit_end=false from the END branch fails highlight_structure_spec. Mutating the grammar's in_footer or explicit inputs fails the new document_grammar_spec random-document case.
  - id: BR-2
    disposition: not-addressed
    note: |
      highlighter.lua:290 is unchanged this round; it still repeats the blank terminator using the line text. Minor, does not block.
  - id: BR-3
    disposition: not-addressed
    note: |
      Partly covered: grammar render_before, the source the document_rows path reads, is now compared against build. The walk's own document_rows branch and the streaming overlay (highlighter.lua:197-205) are still not compared.
  - id: BR-4
    disposition: not-addressed
    note: |
      vim.deepcopy still runs for every row at highlighter.lua:213; unchanged this round.
  - id: BR-5
    disposition: not-addressed
    note: |
      atlas/traceability.yaml:304 still lists render_walk_parity_spec under chat/lifecycle.
```

<!-- sdlc-review-usage [{"version":1,"intent":{"disposable_root":true,"id":"780ece31-aac7-49c0-804d-93c66afcdb30","repository":"github.com/xianxu/parley.nvim","issue_id":"000234","recipe":"small-diff-review","round":2,"attempt":1,"agent":"claude","root":"/Users/xianxu/Library/Caches/sdlc/review-checkouts/c0359a1cbf6467f0","reviewed_head":"82f1c26c445fe64022ccd0c36ef4515b41738037","slot":"parley.nvim:4","requested_at":"2026-10-16T13:54:24.575426Z"},"phase":"finished","pid":58221,"started_at":"2026-10-16T13:54:24.780541Z","finished_at":"2026-10-16T14:09:15.975353Z","session_id":"4d70e364-29ae-492a-9cbf-535605d3b5b5","outcome":"returned"}] -->
