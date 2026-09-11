# Boundary Review — parley.nvim#227 (whole-issue close)

| field | value |
|-------|-------|
| issue | 227 — question highlighting vanishes while typing until you leave insert mode |
| repo | parley.nvim |
| issue file | workshop/issues/000227-question-highlighting-vanishes-while-typing-until-you-leave-insert-mode.md |
| boundary | whole-issue close |
| milestone | — |
| window | 555b81a2b0b8cbcbaef556acc382a2cf37c7391d..dcbebfb80eef657d9ad8d0a32606d12d226a817d |
| command | sdlc close --issue 227 |
| reviewer | claude |
| timestamp | 2026-09-10T18:05:17-07:00 |
| verdict | FIX-THEN-SHIP |

## Review

```verdict
verdict: FIX-THEN-SHIP
confidence: high
```

The fix is real, well-designed and genuinely pinned. I verified it rather than trusting the Log: I reproduced five mutations (fail-closed `on_win`, `is_inert` always true, dropped row-count check, dropped `on_reload`, no-op `arm_repair`) and each reddened exactly the tests the plan claims — so every mechanism in the diff has a test that fails without it. I independently re-derived the splice's exactness rule and brute-forced it over 60,000 random edits with a different seed and a wider vocabulary than the shipped property test (including `👂:`, tabs, 5-backtick fences): zero alignment failures, zero false "exact" claims, 22,003 conservative approximations — the error is always in the safe direction. Full `make test` in the repo: 210 spec files PASS, exit 0, confirming the `## Log`'s claim. Every Done-when bullet maps to a delivered test, the Core-concepts table matches the code entity-for-entity, and atlas/TOOLING/traceability are updated. What keeps this off a bare SHIP is one Important gap: the change deliberately puts an O(n) array copy on the keystroke path, and the accounting seam that was built (#170) to catch exactly that kind of regression is blind to it — `replace` computes `work.entries_copied`, and `on_lines` throws the value away.

### 1. Strengths

- **The plan's central correction is the right one and is load-bearing.** Rendering the last-good structure *unchanged* (the Spec as originally written) would have relocated the footnote colour onto the lines being typed; requiring an *aligned* splice instead is what makes fail-open safe. `tests/integration/highlight_typing_spec.lua:150` pins it concretely (footer at row 18, not 16) — that test is the difference between fixing the bug and moving it.
- **The exactness rule is sound, not just green.** `is_inert` partitions the token set exactly: inert tokens `{t, _, d, D, c*}` cannot feed the `🧠:` lookahead or move `footer_start0`, so they can only change later rows through the forward walk — which `converged` checks directly. My independent 60k-edit run found no counterexample. The "lookahead reaches rows *above* the edit" test (`tests/unit/highlight_structure_spec.lua:222`) is the one case the convergence check cannot see, and it is isolated correctly.
- **ARCH-DRY done properly in `highlight_structure.lua`.** `build` and `replace` now share `enter_row`/`leave_row`/`add_marker`/`derive`, so a splice cannot interpret a token sequence differently from a full build — and `reasoning_explicit_of` reuses the module's existing `STRUCTURAL_TOKENS` instead of the second hand-written list it replaced (`lua/parley/highlight_structure.lua:340`).
- **`renderable` was deleted rather than kept alongside `dirty`.** It only ever equalled `not dirty`; removing it collapses a two-boolean constellation into one field (ARCH-ORDER), and the stale-wording sweep left zero references anywhere in `lua/`, `tests/`, `atlas/`, `TOOLING.md`.
- **The deferral seam is the right shape.** `_set_repair_deferral` makes arm/restart/cancel/late-fire *constructed* orderings, and the one real-clock test (`highlight_typing_spec.lua:346`) proves the production wiring — a sample of size one on top of a designed interleaving space, not instead of it. The late-fire-after-teardown and after-detach tests are the two events a caller cannot block, and both are covered.

### 2. Critical findings

None.

### 3. Important findings

**`lua/parley/highlighter.lua:1008` — the splice's O(n) copy is invisible to the work-accounting seam.**
`local ok_splice, replaced, rows, reason = pcall(...)` drops `replace`'s 4th return value, so `work.entries_copied` — the field the plan's own contract defines as "array slots written by the splice" — never reaches `line_reader.record_work`, which sends only `structure_rows_processed = rows` (`:1021`). `rows` is `#new_lines`: 1 for a prose char, 2 for an Enter, regardless of how much the splice actually copies. The perf hard gate (`tests/perf/chat_typing.lua:116`) asserts `structure_rows_processed == 1` for `edit_total`, so it now certifies a path whose real cost it cannot observe, and `make perf`'s new `structure_splice` phase is report-only ("Elapsed timings never gate CI").

*Failure scenario:* someone replaces the shallow two-array copy in `M.replace` with `vim.deepcopy(structure.state_before)` (or reintroduces a rebuild on line-count edits) to fix an aliasing scare. Every unit, integration and arch test stays green — results are identical — and every Enter in a 5,000-line chat silently goes from 0.10 ms to tens of ms. Nothing fails.

*Fix sketch:* capture `work` from the pcall, pass `structure_entries_copied = work and work.entries_copied or 0` into `record_work`, add the key to `WORK_KEYS`/`zero_work` in `tests/perf/chat_typing.lua:6`, and bound it in `assert_hard_gates` (e.g. an Enter's `structure_entries_copied` must not exceed `2 * line_count`, and must be 0 for a fingerprint-identical edit). ~6 lines plus one assertion.

### 4. Minor findings

- `lua/parley/highlighter.lua:967` — `vim.api.nvim__redraw` is a *private* Neovim API called unprotected inside a scheduled callback. If it errors or is renamed, every repair surfaces an error to the user and the repaint is lost. The repo guards other runtime APIs (`vim.uv or vim.loop`); `pcall` this one and degrade to no repaint.
- `lua/parley/highlighter.lua:88` / `tests/integration/highlighting_spec.lua:78` — the repair seam is installed per spec file. PQ-1 named `highlighting_spec.lua`; the *class* is "every spec that edits a parley buffer and pumps the loop". Today's tree is safe — I enumerated the five files touching `_parley_bufs`, and `branch_child_spec`, `fence_containment_spec` and `tests/perf/chat_typing.lua` make only inert edits that never arm a timer — but the next one will re-open it. Consider defaulting `new_deferral` to a manual deferral under `g:parley_test_mode`, making the real clock opt-in (`_set_repair_deferral(nil, ms)` already does that).
- `lua/parley/highlighter.lua:240-283` (ARCH-DRY) — `leave_row` now owns the reasoning transition rules, but `compute_chat_highlights`'s render walk keeps a second hand-written copy (structural-marker termination, `reasoning_end`, `reasoning` + lookahead, blank terminator). They already differ slightly: the render walk's `reasoning_end` branch does not clear `in_reasoning_explicit_end`. Harmless today, but this is the exact drift shape #218 fixed for the fence toggle, and the diff created the shared helper without routing the second copy through it.
- `TOOLING.md:48` — the new sentence leaves a ~110-column line where the surrounding paragraph wraps at ~76.
- `f00b1de "issue #233: chat context by depth-first walk of the tree"` sits inside #227's window: a new issue file for unrelated work committed on this branch. Harmless (tracker artifact, excluded from the diff pathspec) but it will land under #227's merge.

### 5. Test coverage notes

- Mutation-verified this round, each seen red then reverted in a scratch checkout of `dcbebfb`: fail-closed `on_win` → 1 red (`renders an approximate structure and repairs it…`, and *only* that one — the stub-leak the Log describes is genuinely fixed by the cleanup stack); `is_inert` always true → 3 red (shape table, lookahead-above, property); dropped row-count check → 1 red (empty-buffer); dropped `on_reload` → 1 red (checktime); no-op `arm_repair` → 6 red. No claimed fix is unpinned.
- The property test's non-vacuity assertions (`exact >= 150`, `approximate >= 150`) are the right guard — a property test that never reaches a branch proves nothing.
- One structural note: the property test resets `current = want` after every approximate splice, so *chained* approximation (splicing onto an already-stale structure) is never exercised at the unit level. The integration property test (`highlight_typing_spec.lua:271`) fires the repair as soon as the cache goes dirty, so it doesn't cover it either. Production handles it correctly — `current.dirty = current.dirty or reason ~= nil` is sticky — but the module docstring's "`nil` → exact, identical to `build()` of the edited buffer" is only true when the *input* structure was exact. Worth one clause in the contract comment.
- Gap the Important finding names: no automated guard on the new per-keystroke copy cost.

### 6. Architectural notes for upcoming work

- **ARCH-DRY** — pass in `highlight_structure.lua`; flagged above for the render walk's surviving second copy of the reasoning state machine.
- **ARCH-PURE** — pass. The splice is a pure function over `(structure, edit, patterns)`, tested with no IO; the glue (`on_lines`/`on_reload`/`arm_repair`) stays thin, and the one non-deterministic input (the clock) is injected rather than mocked.
- **ARCH-PURPOSE** — pass, and notably so. The plan enumerated the *class* ("every way the structure stops matching its buffer without a scheduled repair") as a seven-row table and swept all of it in the same round: reload, splice-throw, empty-buffer report, failed rebuild, whole-buffer `set_lines`. I probed for a missed sibling and found only one out-of-scope case — a runtime `chat_user_prefix` change invalidates tokens with no edit to trigger a repair, which predates this issue.
- **ARCH-MOCK** — N/A for external services; the deferral fake is the right analogue for the clock: stateful across calls (arm/restart/stop/close), production and test flow share the `new_deferral` boundary, and the real-clock test is the conformance check.
- **ARCH-CONSTRAINTS** — pass on design (budgets declared with measured basis, one repair per burst, restart-never-queue), flagged on enforcement: the declared envelope isn't machine-checked for the splice (the Important finding). One forward note: `resync` runs a synchronous full rebuild *inside* `on_lines`, i.e. on the keystroke path. Reachable today only via the empty-buffer report (`:%d`), so it's bounded — but if a future change widens the resync trigger, that becomes blocking work on a keystroke.
- **ARCH-SECURE** — N/A as claimed; the one input from outside the function (Nvim's `on_lines` range) *is* validated into `"misaligned"` at the boundary rather than trusted, and the row-count check catches Nvim's self-inconsistent empty-buffer report. That's the principle applied, not waved.
- **ARCH-ORDER** — pass. The state × event table is real, the legal states shrank (`renderable` deleted), extent is lexically bounded (≤1 pending repair, closed on teardown, identity-checked on fire), and a failed repair deliberately does not re-arm so a deterministic build bug cannot loop.

### 7. Plan revision recommendations

None. The Core-concepts tables match the code entity-for-entity at the stated paths, the two Revisions entries already record both the aligned-splice reversal and the gate dispositions, and I confirmed all three plan-quality findings (PQ-1 seam in `highlighting_spec.lua`, PQ-2 both traceability entries, PQ-3 the `init.lua:1714`/`:2872` pointers) are genuinely addressed in the tree rather than just in prose.

```findings
findings:
  - id: new
    severity: Important
    family: work-accounting-blind-spot
    title: |
      on_lines discards replace's work, so the splice's O(n) copy is invisible to every gate
    detail: |
      lua/parley/highlighter.lua:1008 captures only (out, rows, reason) from the pcall and
      drops work, so entries_copied never reaches record_work at :1021, which sends only
      structure_rows_processed = #new_lines. The #170 hard gate (tests/perf/chat_typing.lua:116)
      asserts that value is 1 and therefore certifies a path whose real cost it cannot see;
      make perf's new structure_splice phase is report-only. Swap the shallow two-array copy
      in M.replace for vim.deepcopy and every test stays green while an Enter at 5,000 lines
      silently costs tens of ms. Fix: pass structure_entries_copied through record_work, add
      it to WORK_KEYS, and bound it in assert_hard_gates.
  - id: new
    severity: Minor
    family: private-api-unguarded
    title: |
      nvim__redraw is a private API called unprotected inside a scheduled callback
    detail: |
      lua/parley/highlighter.lua:967. If it errors or is renamed, every structure repair
      surfaces an error to the user and the repaint is lost. The repo guards other runtime
      APIs (vim.uv or vim.loop); pcall this one and degrade to no repaint.
  - id: new
    severity: Minor
    family: injected-clock-in-tests
    title: |
      the repair seam is installed per spec file, so the next spec re-opens the real-timer hole
    detail: |
      lua/parley/highlighter.lua:88 and tests/integration/highlighting_spec.lua:78. PQ-1 named
      highlighting_spec.lua; the class is every spec that edits a parley buffer and pumps the
      loop. Today's tree is safe (branch_child_spec, fence_containment_spec and
      tests/perf/chat_typing.lua make only inert edits that never arm a timer) but nothing
      keeps it that way. Default new_deferral to a manual deferral under g:parley_test_mode
      and make the real clock opt-in.
  - id: new
    severity: Minor
    family: duplicated-state-machine
    title: |
      the render walk keeps a second hand-written copy of leave_row's reasoning rules
    detail: |
      lua/parley/highlighter.lua:240-283 re-implements structural-marker termination,
      reasoning_end, reasoning + lookahead and the blank terminator that leave_row
      (highlight_structure.lua:319) now owns. They already differ: the render walk's
      reasoning_end branch does not clear in_reasoning_explicit_end. Harmless today, but this
      is the drift shape #218 fixed for the fence toggle, and this diff created the shared
      helper without routing the second copy through it (ARCH-DRY).
  - id: new
    severity: Minor
    family: unrelated-work-in-window
    title: |
      an unrelated issue file for #233 is committed on #227's branch
    detail: |
      f00b1de adds workshop/issues/000233-chat-context-depth-first-walk-of-the-tree.md inside
      this review window. Harmless (tracker artifact, excluded by the diff pathspec) but it
      will land under #227's merge.
```
