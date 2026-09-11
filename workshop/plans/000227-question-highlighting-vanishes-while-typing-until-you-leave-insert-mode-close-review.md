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

---

## Re-review — 2026-09-10T18:31:16-07:00 (SHIP)

| field | value |
|-------|-------|
| issue | 227 — question highlighting vanishes while typing until you leave insert mode |
| repo | parley.nvim |
| issue file | workshop/issues/000227-question-highlighting-vanishes-while-typing-until-you-leave-insert-mode.md |
| boundary | whole-issue close |
| milestone | — |
| window | 555b81a2b0b8cbcbaef556acc382a2cf37c7391d..caa4a510e9cc431750e98ef4599ad1f91bea25b0 |
| command | sdlc close --issue 227 |
| reviewer | claude |
| timestamp | 2026-09-10T18:31:16-07:00 |
| verdict | SHIP |

## Review

```verdict
verdict: SHIP
confidence: high
```

Round 2 fixed what it said it fixed, and I checked each claim by reverting it rather than trusting the Log. In a scratch export of `caa4a51`, I reverted each fix separately and each time its test went red. That covers the observer test in `make test`, the `make perf` hard gate, the unit reference-sharing test, the refusing-redraw test and the harness-default test, so every claimed fix is reachable. The full `make test` on that scratch copy exits 0 with 210 files PASS, and `make perf` exits 0 with the gated counts the Log reports (1 row / 0 copied for `edit_total`; 6 rows and exactly 4,002 / 20,002 copied for `structure_splice`). Nothing Critical or Important remains. Three Minor findings are new: two repeat families from round 2, and a missing lessons entry. None blocks the boundary.

### 1. Strengths

- **BR-4 is fixed for the whole class, not just the site.** Structure work is recorded in exactly two places, `build_structure` (`lua/parley/highlighter.lua:955`) and `on_lines` (`:1038`), and both now carry `structure_entries_copied`. Every LineReader event defaults the field. The gate is exact in both directions (`tests/perf/chat_typing.lua:130`), so a copy that goes unreported again fails it just as an extra copy does. I confirmed that with the M1 mutation: perf aborts with "structure_splice must report exactly the two-array copy".
- **The unit test pins the mechanism, not only the result** (`tests/unit/highlight_structure_spec.lua:173`). It checks that every untouched row is shared by reference (`rawequal`) at 100, 1k and 5k lines. That is the only test that can tell a shallow splice from `vim.deepcopy`, and it went red under M2 while every integration test stayed green, which is exactly the gap round 1 described.
- **The harness signal is chosen from evidence.** I reproduced the probe: inside a spec, `vim.g.parley_test_mode` is nil and `$PARLEY_TEST_MODE` is `"1"`. The env-var design is correct, and `atlas/infra/test_harness.md:37` records why.
- **`WORK_FIELDS` is single-sourced** (`tests/perf/harness.lua:8`). The schema check, `empty_work` and `max_work` all derive from it, and a sample missing the new field is rejected (`perf_chat_typing_spec.lua:48`).
- **The #234 deferral is legitimate.** It has a concrete Spec that includes sweeping the third copy in `chat_parser`, and the render walk's duplicate predates #227 and is separable from the blank-while-typing fix (ARCH-PURPOSE).

### 2. Critical findings

None.

### 3. Important findings

None.

### 4. Minor findings

**a. `lua/parley/file_tracker.lua:10-12` still reads the harness signal this diff shows never reaches a spec.** This is the **2nd finding in family `class-not-instance`**. BR-6's fix moved one reader of "am I under the harness" to `$PARLEY_TEST_MODE` and wrote the rule into the atlas: "signals to spec code travel through the environment, not `g:`". The only other production reader, `file_tracker.is_test_mode()`, still reads `vim.g.parley_test_mode`, which is nil in every spec except `chat_move_spec`. Its guards in `load_data`, `save_data` and `init` are therefore dead across the suite.
  - I saw the effect: after my `make test` run, `…/xdg/data/nvim/parley/file_access.json` held `topic_gen_spec`'s chat paths. That is persisted state shared by specs running in parallel, which none of them set up.
  - The measured class has two production readers (`highlighter.lua:91` and `file_tracker.lua:11`); one was migrated.
  - **Rule:** the harness signal gets exactly one production reader, a single helper keyed on `$PARLEY_TEST_MODE`. Both consumers call it, and a guard in `single_source_sweeps_spec` fails if any other module in `lua/` reads `parley_test_mode` or `PARLEY_TEST_MODE`. After that, delete `tests/minimal_init.vim:24` and `chat_move_spec.lua:5`'s workaround.
  - Turning the guard on may expose specs that silently depended on the leaked persistence, so run the full suite. If it grows, split it out as its own issue.

**b. `5596d22` changes shipping defaults inside #227's window and the tracker never mentions it.** This is the **2nd finding in family `unrelated-work-in-window`**.
  - It changes `lua/parley/config.lua:576` (`max_full_exchanges` 42 → 242, which means more tokens per long-chat request for every user) and `:145` (live-model providers).
  - The commit message says "Not part of #227", but neither the issue nor the plan names it. Unlike BR-8's issue file, it is product code inside the diff pathspec, so the close verdict and the merge will read as covering it.
  - Measured prevalence: 2 riders in a 12-commit window; `f00b1de` is now declared in the Log, `5596d22` is not.
  - **Rule:** every commit between the branch point and HEAD either starts with `#227` or is listed in the issue Log as a rider (sha plus one line). The `#N` commit convention makes this checkable (`git log --format=%s base..HEAD | grep -v '^#227'`).
  - Fix now: declare `5596d22` in the Log, or cherry-pick it to main before merging.

**c. No lessons entry for round 2's findings.** `workshop/lessons.md` is unchanged in `caa4a51`; the #227 entries come from `dcbebfb`, before round 2. AGENTS.md §4 asks for a rule for each mistake a review finds. Two candidates:
  - Equal results cannot tell a shallow splice from a deep copy or a rebuild. A cost added to a gated hot path has to go through the accounting seam, and its test has to pin the mechanism.
  - `g:` variables set in `minimal_init.vim` never reach plenary's per-spec child process.

### 5. Test coverage notes

Mutations run on the scratch copy, each reverted afterwards:

| Mutation | What went red |
|---|---|
| M1: `on_lines` reports 0 copied | the observer test, plus a `make perf` abort |
| M2: `vim.deepcopy` splice | the unit sharing test only |
| M3: `nvim__redraw` unguarded | the refusing-redraw test only |
| M4: harness default removed | the harness-default test only |

- Specs in the neighbourhood pass on HEAD: `highlighting_spec` 47/47 with its per-file install gone, `perf_chat_typing_spec` 13/13, `branch_child_spec` 49/49, `chat_move_spec` and `fence_containment_spec` 2/2 each, arch sweeps 21/21.
- The harness-default test proves the absence of a 250 ms timer with one 600 ms wall-clock wait. That's adequate for an absence claim, and M4 shows it isn't vacuous.

### 6. Architectural notes

- **ARCH-DRY: flag, Minor.** Two harness signals now coexist; that is finding (a). BR-7 remains deferred to #234. `new_counter.observe` (`chat_typing.lua:29`) still lists fields by hand, which is justified because the fields aggregate differently.
- **ARCH-PURE: pass.** The accounting travels as data returned from the pure `replace`; the glue only forwards it.
- **ARCH-PURPOSE: pass** for the work-accounting class, since both record sites are swept. **Flag** for the harness-signal class, which is finding (a).
- **ARCH-MOCK: pass.** Production and tests share the `new_deferral` boundary, and the real-clock test is the conformance check.
- **ARCH-CONSTRAINTS: pass.** The splice envelope is now machine-enforced (exact copy count, no full read, flat row work from 1k to 5k), not just reported.
- **ARCH-SECURE: pass, with a note.** Production code reading `$PARLEY_TEST_MODE` means a stray value in a user's shell would silently disable the repair. It degrades to approximate-until-convergence, never to a blank screen, so the risk is acceptable.
- **ARCH-ORDER: pass.** Under the harness, no repair fires unless the spec arranges it. One undocumented detail: `cache.repair` is fixed when a cache first arms a repair, so swapping the factory only affects caches created afterwards. The current specs all swap before `open()`.

### 7. Plan revision recommendations

- Add a Revisions entry bringing the `replace` contract up to date. Plan line 73 ("`reason == nil` → `out` equals `build(post_edit_lines)`") is missing the clause "provided the input structure was exact" that the code now carries (`highlight_structure.lua:421-424`).
- Add `new_default_deferral` (`lua/parley/highlighter.lua`) and `WORK_FIELDS` (`tests/perf/harness.lua`) to the Integration-points table, using bare, grep-able names (lesson #186).

```findings
dispose:
  - id: BR-1
    disposition: addressed
    note: |
      Per-file install replaced by the harness default that covers highlighting_spec; M4 reddens highlight_typing_spec.lua:375.
  - id: BR-2
    disposition: addressed
    note: |
      Both traceability entries list the new spec (atlas/traceability.yaml:53 and :626).
  - id: BR-3
    disposition: addressed
    note: |
      Issue now cites init.lua:1714 and :2872, both correct at HEAD.
  - id: BR-4
    disposition: addressed
    note: |
      Verified by reverting: 0-copied reporting reddens the observer test and aborts make perf at chat_typing.lua:130; a deepcopy splice reddens the unit sharing test.
  - id: BR-5
    disposition: addressed
    note: |
      Unguarding nvim__redraw reddens the refusing-redraw test (highlight_typing_spec.lua:233).
  - id: BR-6
    disposition: addressed
    note: |
      Harness default keyed on the env var every spec inherits (probe: g is nil, env is 1); removing it reddens the harness-default test.
  - id: BR-7
    disposition: not-addressed
    note: |
      Deferred to issue 234 with a concrete Spec incl. the chat_parser sweep; a separable, acceptable deferral for a Minor, non-blocking.
  - id: BR-8
    disposition: addressed
    note: |
      The issue Log now declares f00b1de as a rider; the family rule is stated in the new finding on 5596d22.
findings:
  - id: new
    severity: Minor
    family: class-not-instance
    title: |
      file_tracker still reads g:parley_test_mode, which this diff proved never reaches a spec
    detail: |
      2nd in family. lua/parley/file_tracker.lua:10-12 guards load_data/save_data/init on vim.g.parley_test_mode, nil in every spec but chat_move_spec; a make test run leaves topic_gen_spec paths in the shared scratch file_access.json. Class measured at 2 production readers of the harness signal (highlighter.lua:91, file_tracker.lua:11), 1 migrated. Rule: one helper keyed on $PARLEY_TEST_MODE is the only production reader, enforced by an arch guard; then drop minimal_init.vim:24 and chat_move_spec.lua:5.
  - id: new
    severity: Minor
    family: unrelated-work-in-window
    title: |
      5596d22 changes shipping config defaults inside the issue window and is undeclared in the tracker
    detail: |
      2nd in family. lua/parley/config.lua:576 max_full_exchanges 42 to 242 and :145 live-model providers ride this issue's close verdict and merge; neither the issue nor the plan names the commit. Prevalence: 2 riders in a 12-commit window, 1 declared. Rule: every commit from branch point to HEAD starts with the issue tag or is listed in the Log as a rider (sha plus one line), checkable via git log subjects; declare it or cherry-pick it to main.
  - id: new
    severity: Minor
    family: review-lesson-unrecorded
    title: |
      round-2 findings (work-accounting blind spot, g: not reaching spec children) have no lessons.md rule
    detail: |
      AGENTS.md section 4 requires review-found mistakes to become lessons; caa4a51 fixed BR-4 and BR-6 without one (the lessons in dcbebfb predate round 2). Candidates: equal results cannot tell a shallow splice from a deep copy, so a cost added to a gated hot path must flow through the accounting seam and be pinned by mechanism; harness signals travel via the environment, not g: variables.
```
