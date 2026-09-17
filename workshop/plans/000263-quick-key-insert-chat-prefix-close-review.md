# Boundary Review — parley.nvim#263 (whole-issue close)

| field | value |
|-------|-------|
| issue | 263 — Quick key to insert the chat question prefix at cursor |
| repo | parley.nvim |
| issue file | workshop/issues/000263-quick-key-insert-chat-prefix.md |
| boundary | whole-issue close |
| milestone | — |
| window | bbe05eef5b576db2cd367cd66e6def5806650111..ac60a055d5cda3847818572a121261318936faf8 |
| command | sdlc close --issue 263 |
| reviewer | claude |
| timestamp | 2026-09-16T21:18:37-07:00 |
| verdict | FIX-THEN-SHIP |

## Review

```verdict
verdict: FIX-THEN-SHIP
confidence: high
```

The diff delivers the restated Done-when cleanly: `<C-g>n`/`<M-n>` opens an empty question after the cursor's exchange, `chat_search` is fully retired (only comments still name it), the pure planner genuinely delegates the seam arithmetic to `exchange_clipboard` so `<C-g>n` and `<C-g>V` cannot drift, and the `<M-…>`-only collision guard is now a whole-keyspace guard with prefix-shadow detection and two plants that bite. I re-ran everything: unit spec 14/14, integration spec 11/11, `keybindings_spec` 78/78, `make lint` 0/0, `make test-integration` 30/30 files green, `make test-unit` green except `parley_harness_golden_spec` (pre-existing golden-payload drift) and a `document_dependencies_spec` parallel-run flake that passes 13/13 standalone — neither touches this diff. I additionally probed header-cursor, EOF, closed-fold and two-press-with-typing shapes by hand; all land correctly. Nothing blocks the boundary. What holds it back from SHIP is one real coverage gap (the "one undo step" clause is asserted for the normal-mode press only, while the mechanism the code credits for it lives on the *insert* path) and one measurably-wrong sentence in newly added atlas prose.

## 1. Strengths

- **`lua/parley/new_question.lua:62-63` — the DRY claim is real, not decorative.** `plan` calls `clipboard.get_paste_line` + `build_paste_lines` rather than re-deriving the seam; I verified the resulting spacing against the paste path in four buffer shapes, including a closed manual fold over a tool block (`8,11fold`, cursor at line 9 → question lands at 13 with correct blanks, cursor col 6).
- **`tests/unit/keybindings_spec.lua:1014-1055` — the plants call the shipped detection.** `owners_by_key`/`collisions`/`prefix_shadows` are written once and the two plant tests run *them*, asserting the offending entry ids rather than `#found > 0`. I confirmed the widened rule is genuinely at 0 collisions / 0 prefix shadows and that all 80 key-bearing registry entries carry modes, so `modes_overlap` isn't silently skipping anyone.
- **Single-source sweep passes end to end.** `<C-g>n`/`<M-n>` derives into the app profile automatically (`starter.options().chat_shortcut_new_question` = `{ "<C-g>n", "<M-n>" }`, `chat_shortcut_search` = `nil`), and the help float renders `<C-g>n  New question after this exchange  (also <M-n>)` — matching the atlas and config claims about key ordering. No hand-maintained restatement left behind.
- **`lua/parley/init.lua:4629-4636`** — writing through `buffer_edit.replace_user_lines` rather than `nvim_buf_set_lines` keeps `tests/arch/buffer_mutation_spec.lua` green (10/10) and is what earns the refusal path.
- **`workshop/lessons.md:3-56`** — six specific, transferable rules from the plan reviews, per AGENTS.md §4.

## 2. Critical findings

None.

## 3. Important findings

**I1 — `tests/integration/new_question_spec.lua:150` — the insert-mode path has no undo assertion, which is the one clause the plan called its only unreadable risk.**
The restated Done-when says "Works from normal **and** insert mode, and is one undo step." `it("is a single undo step")` (line 162) presses in **normal** mode, where `stopinsert` plays no part; `it("works from insert mode")` (line 150) asserts count/content and never undoes. So the `vim.cmd("stopinsert")` at `lua/parley/init.lua:2809` — whose comment credits it with keeping the edit out of the surrounding insert session's undo block — has no test that fails without it. I checked the counterfactual: a buffer-local insert mapping calling `parley.cmd.NewQuestion()` with no `stopinsert`, driven by real `<M-n>` keystrokes after typing `XY` in an insert session, restores byte-identically on a single `u`. The undo scope appears to come from `document.apply_user`'s user transaction, not from the `stopinsert`.
*Fix:* add to the insert-mode case — snapshot `before`, press, `vim.cmd("stopinsert")`, `vim.cmd("silent normal! u")`, `assert.same(before, body(buf))`. I ran exactly that against the shipped mapping and it passes. Keep `stopinsert` (it mirrors the existing house idiom at `init.lua:2599`, `branch_ref`'s `i` handler) but soften the comment to "mirrors branch_ref" rather than asserting an undo mechanism the tests don't demonstrate.

**I2 — `atlas/ui/keybindings.md:136-139` — "the one place the portable key does not lead" is measurably false, and the same paragraph disproves it.**
Three registry entries lead with `<C-g>` over an `<M-…>` twin: `outline` (`keybinding_registry.lua:531`, `{ "<C-g>t", "<M-t>" }`), `chat_drill_in` (`:741`, `{ "<C-g>q", "<M-q>" }`) and now `new_question` (`:664`). Only `open_file` (`:428`) and `branch_ref` (`:545`) lead with the alt key. The new sentence claims uniqueness and then names `outline` as "the same shape" two lines later. On a page whose own next sentence says "a rule page that does not record its own exceptions is the drift #214 removed", a *wrong* exception count is that same drift.
*Fix:* "…its entry is one of three where the portable key does not lead (`outline` `<C-g>t`/`<M-t>`, `chat_drill_in` `<C-g>q`/`<M-q>`)…". `lua/parley/config.lua:376` carries the same phrasing scoped to the entry; it reads defensibly there, but worth aligning.

## 4. Minor findings

- **ARCH-DRY — `lua/parley/init.lua:4606-4623` is the 4th verbatim copy** of the `not_chat` → `find_header_end` → `parse_chat` preamble (`:4276`, `:4443`, `:4575`). Worth extracting a `chat_context(name)` returning `buf, lines, header_end, parsed_chat` or a reason string; the fourth copy is where you stop paying the DRY tax later.
- **Error-handling inconsistency — `init.lua:4629-4636` pcalls `replace_user_lines` and logs a warning; the other 12 call sites (e.g. `:4595` `ExchangePaste`, `:4557` `delete_entity_range`) let the refusal raise a bare Lua error at the user.** The new one is the better UX; the siblings now diverge from it.
- **`tests/integration/new_question_spec.lua:239` stubs the *verdict*, not just the seam.** It replaces `buffer_edit.capture_user` with `function() return nil, "..." end`. The plan's Task 4 case 9 prescribed building real guarded state via `document.capture_user` (per `document_user_guards_spec`). What ships proves `NewQuestion` catches and reports a refusal — not that a live generation produces one. No `## Revisions` entry records the substitution.
- **`workshop/plans/…-plan.md:989` — the literal `--verified` string is stale**: "unit 15/15 + integration 10/10 green; make test full suite green". Measured 14/14 and 11/11, and `make test-unit` is *not* green (`parley_harness_golden_spec`, pre-existing, acknowledged in the Log). Correct it before `sdlc close` so the close evidence is true.
- **`atlas/ui/keybindings.md:140-141` — the inserted paragraph swallowed a pre-existing sentence.** "…is the drift #214 removed. `<C-g>` is / the prefix surface for everything else." belongs to the previous paragraph's thought; split it back out.
- **Header-cursor behavior is undocumented.** With the cursor in the front matter the new question lands *above* the first exchange (verified). That is correct `<C-g>V` parity, but the atlas says only "after the exchange the cursor is in" — one clause would close it.

## 5. Test coverage notes

The unit spec is genuinely PURE (no buffer, no mocks, runs in 14/14 without IO) and walks the real branch axis — cursor location × prefix shape — including a `%-Q.:` magic-character prefix and a tab-separated prefix. The integration spec's independent `vim.startswith` oracle and its on-disk fixture (needed for real undo history) are both right, and the `vim.cmd` spy that outlives the scheduled `startinsert!` is the correct idiom here. The gaps are I1 (insert-mode undo) and the stubbed refusal verdict. Two untested-but-correct behaviors worth pinning cheaply if you're in there: the header-cursor placement, and the magic-prefix case at integration level (the integration override uses `>>`, which is not pattern-magic).

## 6. Architectural notes

- **ARCH-DRY** — flag (minor, M1/M4-preamble above); the core delegation to `exchange_clipboard` is exemplary.
- **ARCH-PURE** — pass. `new_question.lua` is a pure plan value; `M.cmd.NewQuestion` is the only IO, and it injects `M.config.chat_user_prefix` into the planner rather than letting the planner reach for config.
- **ARCH-PURPOSE** — pass. The shadow-sweep is clean: config, registry, help float, app profile and the guard all derive from the registry; nothing restates the chord by hand. The guard generalization answers the *class* (every chord + prefix delay) rather than the `<C-g>n` instance.
- **ARCH-MOCK** — N/A (no external binary or service); noted above that the one double in the diff fakes an internal verdict.
- **ARCH-CONSTRAINTS** — pass. Keystroke path; one buffer read + one `parse_chat` + one range write per press, identical in shape to `ExchangePaste`. Nothing lands on the per-keystroke typing budget.
- **ARCH-SECURE** — pass. `user_prefix` is compared with `string.sub` and never reaches a Lua-pattern position; the magic-prefix unit case pins it. No credentials, no untrusted external input.
- **ARCH-ORDER** — pass with the I1 caveat. The planner carries no state between events; the shell's one interleaving that matters (a streaming write owning the region) is routed through `buffer_edit`'s provenance token and refuses visibly. The second-press interleaving resolves to the focus branch by construction and is tested at both levels.
- **ARCH-FUNERAL** — pass. The only bytes written are question lines inside a transcript the user already owns; no new file family, cache, log or handle.

## 7. Plan revision recommendations

- `workshop/plans/000263-new-question-chord-plan.md` § Task 4 — a `## Revisions` entry recording that case 9 shipped as a `buffer_edit.capture_user` stub rather than the prescribed real `document.capture_user` state, and why.
- Same file § Task 7 Step 5 — correct the `--verified` counts (14/14 unit, 11/11 integration) and drop "make test full suite green", replacing it with the pre-existing-failure note the issue's `## Log` already carries.
- Same file § Task 4 case 5 / § Risks item 1 — the case as written derives from case 1 (normal mode) and therefore never judged the `stopinsert` decision it claims to judge; restate it as an insert-mode case.

```findings
findings:
  - id: new
    severity: Important
    family: acceptance-clause-untested
    title: |
      The "one undo step" Done-when clause is asserted only for the normal-mode press
    detail: |
      tests/integration/new_question_spec.lua:162 undoes after a NORMAL-mode press, where the
      insert-path stopinsert (lua/parley/init.lua:2809) plays no part; the insert-mode case at
      :150 never undoes. Measured counterfactual: an insert mapping without stopinsert, driven
      by real <M-n> keystrokes after typed text, restores identically on a single u — so the
      mechanism the comment credits has no test that fails without it. Add the undo assertion
      to the insert-mode case (verified passing against the shipped mapping) and soften the
      comment to cite the existing branch_ref idiom at init.lua:2599.
  - id: new
    severity: Important
    family: doc-claim-contradicts-code
    title: |
      atlas claims the new entry is "the one place" the portable key does not lead; it is the third
    detail: |
      atlas/ui/keybindings.md:136-139. Three registry entries lead with <C-g> over an <M-> twin:
      outline (keybinding_registry.lua:531), chat_drill_in (:741) and new_question (:664); only
      open_file (:428) and branch_ref (:545) lead with the alt key. The same paragraph names
      outline as "the same shape" two lines after claiming uniqueness. lua/parley/config.lua:376
      carries the same phrasing scoped to the entry.
  - id: new
    severity: Minor
    family: duplicated-command-preamble
    title: |
      NewQuestion is the fourth verbatim copy of the not_chat/find_header_end/parse_chat preamble
    detail: |
      lua/parley/init.lua:4606-4623 repeats :4276 (Prune), :4443 (ExchangeCut) and :4575
      (ExchangePaste). ARCH-DRY: extract a chat_context(name) helper returning
      buf, lines, header_end, parsed_chat or a reason string.
  - id: new
    severity: Minor
    family: inconsistent-refusal-ux
    title: |
      NewQuestion catches the buffer_edit refusal and warns; the other 12 call sites let it raise
    detail: |
      lua/parley/init.lua:4629-4636 pcalls replace_user_lines; :4595 (ExchangePaste),
      :4557 (delete_entity_range) and the rest surface a bare Lua error instead. The new
      behavior is the better one; the siblings now diverge from it.
  - id: new
    severity: Minor
    family: stubbed-verdict-not-seam
    title: |
      The streaming-refusal test stubs capture_user's verdict rather than building real guarded state
    detail: |
      tests/integration/new_question_spec.lua:239 replaces buffer_edit.capture_user with a
      function returning nil. The plan's Task 4 case 9 prescribed driving document.capture_user
      per document_user_guards_spec. What ships proves the catch-and-report path, not that a
      live generation produces the refusal. No Revisions entry records the substitution.
  - id: new
    severity: Minor
    family: stale-close-evidence
    title: |
      The plan's literal --verified string states counts and a suite status that are not true
    detail: |
      workshop/plans/000263-new-question-chord-plan.md:989 says "unit 15/15 + integration 10/10
      green; make test full suite green". Measured: unit 14/14, integration 11/11, and
      tests/unit/parley_harness_golden_spec.lua fails (pre-existing golden drift, acknowledged
      in the issue Log). Correct before sdlc close.
  - id: new
    severity: Minor
    family: prose-continuity
    title: |
      The inserted atlas paragraph swallowed a pre-existing sentence
    detail: |
      atlas/ui/keybindings.md:140-141 — "`<C-g>` is the prefix surface for everything else."
      now trails the #263 exception paragraph instead of the alt-family paragraph it belongs to.
  - id: new
    severity: Minor
    family: undocumented-branch
    title: |
      Header-cursor placement is neither tested nor documented
    detail: |
      With the cursor in the front matter the new question lands above the first exchange
      (verified by hand). That is correct <C-g>V parity, but atlas/chat/lifecycle.md:6 says only
      "after the exchange at the cursor". One clause plus one test case would close it.
```

---

## Re-review — 2026-09-16T21:38:56-07:00 (FIX-THEN-SHIP)

| field | value |
|-------|-------|
| issue | 263 — Quick key to insert the chat question prefix at cursor |
| repo | parley.nvim |
| issue file | workshop/issues/000263-quick-key-insert-chat-prefix.md |
| boundary | whole-issue close |
| milestone | — |
| window | bbe05eef5b576db2cd367cd66e6def5806650111..c9d39d6379f82c9232ea42cb24421899197a9e22 |
| command | sdlc close --issue 263 |
| reviewer | claude |
| timestamp | 2026-09-16T21:38:56-07:00 |
| verdict | FIX-THEN-SHIP |

## Review

```verdict
verdict: FIX-THEN-SHIP
confidence: high
```

All eight round-1 findings are disposed `addressed`, and I verified each against the code rather than the commit message: the integration spec is now parameterized over `{"n","i"}` with an undo assertion in both (14/14 green, measured); the 3–3 `<C-g>`/alt split is true against the registry (`outline`:531, `new_question`:665, `chat_drill_in`:742 vs `open_file`:428, `branch_ref`:545, `chat_prune` at `config.lua:414`); `chat_context(what)` is extracted and all four commands migrated with prune/cut/paste/textobj specs green; the swallowed atlas sentence is back at `keybindings.md:137`; header-cursor placement is both tested and documented; and the corrected `--verified` string matches what I measured (unit 14/14, integration 14/14, lint 0/0 over 627 files, `parley_harness_golden_spec` 11/11 red and `perf_document_spec` red — both untouched by this diff). I independently re-ran the BR-1 counterfactual with **real** `<M-n>` keystrokes from a genuine insert session after typed text: one `u` restores identically with and without `stopinsert`, so the softened comment at `init.lua:2806-2812` is accurate rather than merely plausible. Every restated Done-when clause is delivered. What blocks a clean SHIP is not behavior — it is that the durable plan is archived in a state that contradicts the work: 40 of 40 checkboxes unticked, against a house convention of 66/66, 34/34, 8/8 on the last four plans that carried them.

## 1. Strengths

- **`lua/parley/new_question.lua:1-89` is a textbook pure core.** It takes `(parsed_chat, lines, cursor_line, header_end, user_prefix)` and returns a value; the unit spec runs with no buffer, no mocks, no IO (verified: 14/14 requiring only `parley.new_question` + `chat_parser`). The insertion point and blank-line seam are delegated to `exchange_clipboard`, so `<C-g>n` and `<C-g>V` cannot drift on spacing. ARCH-PURE and ARCH-DRY both land.
- **The widened shadowing guard actually bites.** `tests/unit/keybindings_spec.lua:1017-1052` runs the *production* `collisions()`/`prefix_shadows()` from both the clean-registry assertion and the plants, asserts the offender by name rather than `#found > 0`, and canonicalizes through `keytrans ∘ replace_termcodes`. I confirmed the guard would have caught the original `<C-g>n` double-bind (same scope `chat`, overlapping modes). 78/78 green. This is the ARCH-PURPOSE class fix the issue named, not the instance.
- **Round-1 dispositions consistently answered the class.** BR-1 became a mode parameterization rather than one added case; BR-3 migrated all four preamble copies rather than the new one; BR-2 corrected atlas *and* `config.lua` *and* the registry comment. That is the right reflex.
- **Edge behavior is robust.** I probed EOF with no trailing blank, a trailing-blank cursor, a missing `---` separator, a branch-only chat, a `🔒:` cursor, an empty question as the last exchange, and a `%d:` pattern-magic prefix. No crash, no corruption, correct refusal on the broken header, and `<C-g>V` parity in every fallback (`ARCH-SECURE`: `user_prefix` is `sub()`-compared, never pattern-interpolated).
- **`init.lua:4622-4626`** states the `plan.row` invariant as an `assert` with a comment explaining why `nvim_win_set_cursor`'s own error would not say so. Cheap, readable, correct.

## 2. Critical findings

None.

## 3. Important findings

**I1 — `workshop/plans/000263-new-question-chord-plan.md`: the plan archives with 0 of 40 steps ticked.**

> **This is the 2nd finding in family `stale-close-evidence`.** Earlier rounds fixed instances (BR-6, the `--verified` string). Do NOT fix this instance alone — state the rule that covers all of them and fix that.

Measured: 40 `- [ ]`, 0 `- [x]` in the plan; the issue's `## Plan` is 6/6 ticked. House convention on the last four plans carrying checkboxes: `000262` 66/66, `000254` 34/34, `000247` 7/7, `000245` 8/8, all ticked, none unticked. Every one of the 40 steps is in fact delivered (I verified Task 1's retirement by grep, Tasks 2–5 by running their specs, Task 6's four atlas edits by diff, Task 7's suite/lint by re-running). So the plan is archived asserting the opposite of what shipped.

**The rule that covers the family:** *close-time artifacts are reconciled against the run that just happened, in the same commit as the close — not carried forward from when they were written.* The enumeration is small and writable now: (a) the `--verified` string is built from the terminal output of the final run, never from the plan (BR-6's instance); (b) every checkbox in the durable plan is ticked, or struck with a one-line reason if deliberately skipped; (c) the issue `## Plan` and the durable plan agree on what was done. Plan Step 4 at `:980` is literally *"Reconcile the issue before closing"* — it is unticked, and it is the step that would have caught the other 39. Sweeping all three in this round is the fix; ticking the boxes alone is the instance again.

## 4. Minor findings

**M1 — the insert-mode test measurably runs in normal mode.** `tests/integration/new_question_spec.lua:156-183`.

> **This is the 2nd finding in family `acceptance-clause-untested`.** Do NOT fix this instance — state the rule.

`vim.cmd("startinsert")` inside a busted `it()` only takes effect on return to the main loop. I probed it directly: `MODE_AFTER_STARTINSERT=[n]`, `MODE_AFTER_MAPARG=[n]`. So the `"i"` iteration drives the insert-mode *callback* while the editor sits in normal mode — the `stopinsert` inside it is a no-op and there is no insert-session undo block to fold into. The behavior is nonetheless correct: driving real keys (`nvim_feedkeys(replace_termcodes("A XYZ<M-n>"), "x", false)`) from a genuine insert session, one `u` removes exactly the new question and leaves the typed text, with and without `stopinsert`. **The rule:** *a test whose label names a mode or state must establish that state, not just select the code path associated with it — assert the precondition (`assert.equals("i", vim.fn.mode())`) or drive it with `nvim_feedkeys(..., "x", false)`, which is verified to work here.* The enumeration is any spec in this tree that sets up a mode with `vim.cmd` and then calls a callback directly.

**M2 — the `chat_context` extraction is migrated three-quarters of the way, and a second exchange-containment scan was added alongside it.** `lua/parley/init.lua:4308` computes `ctx.cursor_line`, but only `NewQuestion` consumes it; `ChatPrune:4320`, `ExchangeCut:4482` and `ExchangePaste:4592` each re-read `nvim_win_get_cursor(0)[1]`. Separately, `lua/parley/new_question.lua:44-52` (`exchange_at`) re-implements the containment scan at `exchange_clipboard.lua:67-74` (`get_paste_line`'s first loop) — same `get_exchange_line_range` bounds, same `>= first and <= last` test, and `plan()` calls both, so a future change to one definition silently splits the focus branch from the insertion point inside the module whose stated purpose is one definition of exchange extent.

> **This is the 2nd finding in family `duplicated-command-preamble`.** Do NOT fix these two sites alone — state the rule.

**The rule:** *when a block is extracted into a shared helper, every caller consumes every field the helper now owns, and any new derivation of a concept the owning module already computes calls that module.* The enumeration here is three lines (`:4320`, `:4482`, `:4592` → `ctx.cursor_line`) plus one extraction (`exchange_clipboard.exchange_index_at(parsed_chat, cursor_line, total_lines)`, consumed by `get_paste_line` and `new_question.exchange_at`).

**M3 —** `assert(plan.row, …)` at `init.lua:4624` runs *after* the buffer write, so an (unreachable) nil row would leave a half-applied edit plus a bare Lua error. Moving it above the write costs nothing.

## 5. Test coverage notes

- Unit 14/14, integration 14/14, keybindings 78/78, lint 0/0 across 627 files — all re-run from this window, all matching the corrected `--verified` string at plan `:989`.
- `parley_harness_golden_spec` (11/11 red) and `perf_document_spec` (dies silently mid-run) are the only suite failures; neither touches a file in this diff (`scripts/parley_harness`, `golden_fixture`, the `parser → build_messages → prepare_payload` chain are all outside the changed set), so the pre-existing claim holds.
- **`ExchangeCut` and `ExchangePaste` have no spec of their own** — `grep -rln "ExchangeCut\|ExchangePaste\|ChatPrune" tests/` returns only `topic_gen_spec.lua` (prune). This diff refactored all three through `chat_context`. The gap is pre-existing, not introduced, and the four neighbouring specs I ran are green — but it is the reason a preamble refactor at a close boundary had to be verified by inference rather than by a test.
- The streaming-refusal case remains a double at the `buffer_edit` seam. Correctly labelled, correctly justified with the two measured dead ends, and correctly handed to #265 with the `chat_pending_spec` helper problem named.

## 6. Architectural notes

- **ARCH-DRY** — flag, see M2 (two sites). Otherwise strong: the seam arithmetic is genuinely single-sourced.
- **ARCH-PURE** — pass. Pure planner, thin shell, unit spec with no IO. Exemplary.
- **ARCH-PURPOSE** — pass. Shadow-sweep run: all nine restated Done-when clauses derive from the source. `chat_search` retirement is complete (4 residual mentions, all historical comments; README carries no `<C-g>` surface at all, so the README gate is N/A). The guard generalization is the class the issue named, not the instance.
- **ARCH-MOCK** — N/A, correctly declared. No external binary or service; the integration spec drives the real editor.
- **ARCH-CONSTRAINTS** — pass. One full-buffer read + one `parse_chat` + one range write, on a chord and not on a keystroke path; identical in shape to `ExchangePaste`, which already ships. No new budget.
- **ARCH-SECURE** — pass. `user_prefix` is operator config compared with `sub()`; verified against a `%d:` prefix end-to-end. Nothing leaves the buffer. Minor residue: `logger.warning("NewQuestion stopped: " .. tostring(err))` surfaces a raw Lua error string — that is #265's surface.
- **ARCH-ORDER** — pass with the M1 caveat. The planner holds no state; the shell's one interleaving (a response streaming into the target region) is enumerated and routed through `buffer_edit`'s provenance guard, and the second-press case is a deliberate rule rather than an ordering accident. The refusal path is tested through a double, which is honestly labelled.
- **ARCH-FUNERAL** — pass. Nothing durable is created; the only bytes written live and die with a transcript the user already owns. The two new `workshop/plans/000263-*-{close-gate,close-review}.md` artifacts follow the existing archive-to-`workshop/history/` routine.

## 7. Plan revision recommendations

Add to `workshop/plans/000263-new-question-chord-plan.md` `## Revisions`:

- **`2026-09-16 — close round 2: checklist reconciled`** — tick all 40 steps (or strike with a reason), and record the family rule from I1: close-time artifacts are reconciled against the final run in the closing commit, covering (a) `--verified` built from that run's output, (b) every plan checkbox ticked or struck, (c) issue `## Plan` and durable plan in agreement. Note that Step 4 at `:980` ("Reconcile the issue before closing") was itself the unticked step that would have caught the other 39.
- **`Task 4 — insert-mode fidelity`** — record that `vim.cmd("startinsert")` inside a busted `it()` does not change `mode()` (measured: `mode()` returns `n`), that the `{"n","i"}` parameterization therefore exercises the `i` *mapping* and not insert *state*, and that `nvim_feedkeys(replace_termcodes("A XYZ<M-n>"), "x", false)` is the verified seam for the real thing. Include the measured result that one `u` restores identically with and without `stopinsert` even after typed text, so the claim is on the record rather than only in the commit body.
- **`Chunk 1/2 — ARCH-DRY residue`** — record the M2 enumeration (`ctx.cursor_line`'s three stale re-readers; `exchange_at` vs `get_paste_line`'s scan) and the rule, so the next extraction migrates every caller in the same round.

---

## Re-review — 2026-09-16T21:55:37-07:00 (REWORK)

| field | value |
|-------|-------|
| issue | 263 — Quick key to insert the chat question prefix at cursor |
| repo | parley.nvim |
| issue file | workshop/issues/000263-quick-key-insert-chat-prefix.md |
| boundary | whole-issue close |
| milestone | — |
| window | bbe05eef5b576db2cd367cd66e6def5806650111..62c7f2927cebf248284c907cc5f75a11a69f3542 |
| command | sdlc close --issue 263 |
| reviewer | claude |
| timestamp | 2026-09-16T21:55:37-07:00 |
| verdict | REWORK |

## Review

```verdict
verdict: REWORK
confidence: high
```

This diff delivers the feature well — a genuinely pure planner (`lua/parley/new_question.lua`, 14/14 unit cases with no buffer), a thin IO shell that inherits the streaming refusal from `buffer_edit`, a widened chord-collision guard whose plants call the *production* detection function (78/78), and a 15/15 integration spec that drives real keymaps and a real insert session. All eight round-1 findings were substantively worked. What blocks SHIP is that **this diff turns an existing in-tree guard red and the close evidence says the suite is otherwise green**: `tests/arch/superseded_comment_spec.lua` passes 9/9 at base `bbe05eef` and fails 8/9 at head (measured in a detached worktree), because the round-2 `exchange_index_at` extraction was inserted *between* `get_paste_line`'s doc block and `get_paste_line`. That is the same `prose-continuity` rule BR-7 raised, recurring in code — and the plan's literal `--verified` string is stale for the second consecutive round, so `sdlc close` would record a false suite status. Both fixes are minutes of work; one re-run should clear the gate.

**1. Strengths**

- `lua/parley/new_question.lua:44-48` — the round-2 sweep is real: `exchange_index_at` is now the single owner of "which exchange is the cursor in", consumed by both `get_paste_line` and the planner. `exchange_clipboard_spec` 31/31, `entity_range_spec` 47/47, `topic_gen_spec` 9/9 all green after the refactor (verified in the full suite run).
- `tests/unit/keybindings_spec.lua:975-1055` — the widened guard is the right shape: one `owners_by_key`/`collisions`/`prefix_shadows` triple shared by the guards *and* by the plants, `modes_overlap` added so `{o,x}` text objects and normal-only `gf`/`gP` don't become false positives, canonicalization via `keytrans ∘ replace_termcodes`, and the plant asserts the offender by name rather than `#found > 0`. Measured 0 collisions / 0 prefix shadows, both plants biting.
- `tests/integration/new_question_spec.lua:250-277` — the `nvim_feedkeys("A XYZ" .. key)` case, added after measuring that `vim.cmd("startinsert")` in a busted `it()` does not change `mode()`. That measurement is the difference between testing a mapping and testing a mode, and it's recorded in `workshop/lessons.md`.
- `tests/integration/new_question_spec.lua:96-109` — the question-count oracle is a plain `vim.startswith` scan, never a re-parse, so the expectation cannot agree with the code under test (#262 lesson applied).
- `lua/parley/init.lua:2805-2812` — the softened `stopinsert` comment now says what the line actually is (house idiom mirroring `branch_ref`'s `i` handler at `init.lua:2598`) instead of crediting it with the undo scope it does not provide. Verified: `branch_ref`'s handler is byte-for-byte that idiom.

**2. Critical findings**

- `lua/parley/exchange_clipboard.lua:58` — `get_paste_line`'s doc block (`@param header_end`, `@return number line number to insert after`) is stranded above `M.exchange_index_at` (line 76); `get_paste_line` itself (line 86) now has no doc at all, and lua-ls reads `exchange_index_at` as taking a `header_end` it does not take and returning two values. **The tree's own arch guard catches this and is red:** `tests/arch/superseded_comment_spec.lua` → *"an annotation block was separated from the function it documents … lua/parley/exchange_clipboard.lua:58 — @param header_end, but the signature is (parsed_chat, cursor_line, total_lines)"*. Measured 9/9 at `bbe05eef`, 8/9 at `62c7f292`. Fix: move lines 58-65 down to sit immediately above line 86. See the family note in §7 — the *rule*, not this site, is the deliverable.

**3. Important findings**

- `workshop/plans/000263-new-question-chord-plan.md:26` — `chat_context` is listed under **"### Pure entities (the conceptual core)"**, but it calls `nvim_get_current_buf`, `nvim_buf_get_name`, `nvim_buf_get_lines`, `nvim_win_get_cursor` and `M.logger.warning/error` (`lua/parley/init.lua:4278-4310`). It cannot be exercised without a real buffer, window and logger — it belongs in the "Integration points" table two sections down, alongside `M.cmd.NewQuestion`. The review protocol nominally calls a PURE/code contradiction Critical; I'm calling it Important because no test was written against the wrong classification, so the harm is confined to the plan misleading downstream work about what is unit-testable. Fix: move the row and add a `## Revisions` line.

**4. Minor findings**

- `lua/parley/chat_respond.lua:1700` (`M.respond`) and `:1917` (`M.respond_all`) still carry the `not_chat` → warning → `find_chat_header_end` → error → `parse_chat` (+ cursor, in `respond_all`) preamble verbatim; `chat_context` is file-local to `init.lua` so they cannot consume it. **3rd finding in family `duplicated-command-preamble`** — see §7.
- `atlas/ui/keybindings.md:136-145` asserts a measured count ("the split is even… three entries lead with `<C-g>`… three lead with the alt key") with no test pinning it. I verified the claim is currently true (config.lua:384/391/396/414/417/465), but it is still a hand-maintained restatement of the registry — which is exactly what produced BR-2. **2nd finding in family `doc-claim-contradicts-code`** — see §7.
- `lua/parley/exchange_clipboard.lua:87-90` calls `get_exchange_line_range` twice for the found index (once inside `exchange_index_at`, once after). Harmless on a chord path; noting only because a `{ nearest = true }` option, which the plan already names as the next extension, would remove it.

**5. Test coverage notes**

Measured this session: `tests/unit/new_question_spec.lua` 14/14, `tests/integration/new_question_spec.lua` 15/15, `tests/unit/keybindings_spec.lua` 78/78, `make lint` 0 warnings / 0 errors across 627 files — all as claimed. Full `make test-unit`: only `parley_harness_golden_spec.lua` fails (confirmed pre-existing, unrelated to this diff). Full `make test-integration`: `perf_ownership_spec.lua` fails under the 8-way fan-out and passes 3/3 alone (the known parallel-flake class), and `tests/arch/superseded_comment_spec.lua` fails for the reason in §2. Coverage of the feature itself is good; the gap is that `ExchangeCut`/`ExchangePaste` still have no spec of their own, so the `chat_context` migration was verified only through neighbouring specs — already recorded in the plan and routed to #265.

**6. Architectural notes**

- **ARCH-DRY** — pass on the new code (`exchange_index_at` and `chat_context` both landed, all four `init.lua` callers consume `ctx.cursor_line`, verified by grep); flagged for the two `chat_respond.lua` siblings in §4.
- **ARCH-PURE** — pass on `new_question.lua` (unit spec needs no buffer and no mocks); flagged for the plan's misclassification of `chat_context` in §3.
- **ARCH-PURPOSE** — pass. Shadow-sweep run: the registry is the single source and every consumer derives (keymaps via `prep_chat`, `<C-g>?` help via `resolve_keys`, the app profile via `starter_config_spec`, which passes). `chat_search` is fully retired — zero references outside `workshop/` and explanatory comments. The generalized guard is the class fix the issue's Done-when asked for, not the instance.
- **ARCH-MOCK** — N/A. No external binary or service; the integration spec drives the real editor.
- **ARCH-CONSTRAINTS** — pass. Chord path, one full-buffer read + one `parse_chat` + one range write, same shape as `<C-g>V` and `<C-g>k`; no per-keystroke cost added.
- **ARCH-SECURE** — pass. `chat_user_prefix` is operator config, compared via `string.sub`, never interpolated into a Lua pattern; the `%-Q.:` magic-character case is pinned in both the unit and integration specs.
- **ARCH-ORDER** — pass. The planner carries no state between events; the shell's only interleaving event (a response streaming into the target region) is governed by ignore-with-visible-error and tested. `assert(plan.row)` now precedes the write, so an unreachable nil cannot leave a half-applied edit.
- **ARCH-FUNERAL** — pass. Creates nothing durable beyond question lines inside a transcript the user already owns; the plan's reasoned exemption is accurate.

**7. Plan revision recommendations**

- **`## Revisions` — `prose-continuity`, 2nd occurrence, and the rule it forces.** BR-7 fixed the atlas sentence; the same rule broke in code one commit later. The rule: *an insertion never lands between a doc/comment block and the symbol it documents — when you add a definition above an existing one, the existing one's block moves with it.* Measured prevalence in this issue: 2 (atlas round 1, `exchange_clipboard.lua:58` now); `config.lua:372-384` and `init.lua:4313` got it right, so the class is 2-of-4 insertion sites. Critically, the **code half of this rule already has a mechanical enforcer** (`tests/arch/superseded_comment_spec.lua`) — the class is closed not by a careful eye but by running the guard, which is the same failure §2 and BR-6 share. The markdown half has no enforcer; note that explicitly rather than relying on discipline.
- **`## Revisions` — `chat_context` is an integration point, not a pure entity.** Move the row from the Pure entities table to Integration points and say what it wraps (current buffer, cursor, logger).
- **`## Revisions` — `duplicated-command-preamble`, 3rd occurrence.** The rule that covers all three: *the preamble has exactly one owner; a module that cannot reach the owner is a boundary that gets written down, not a silent exception.* Measured prevalence: 4 sites migrated in `init.lua`, 2 unmigrated in `chat_respond.lua` (`:1700`, `:1917`), 1 partial in `exporter.lua:965`, 1 deliberate divergence in `delete_entity_range` (`init.lua:4547`, uses `entity_textobj.parsed_for` for text-object parity — correctly excluded). Decide once: either lift `chat_context` into a small shared module both consume, or record the init.lua boundary and the parity exception in the plan so a 7th copy doesn't reopen the family.
- **`## Revisions` — `doc-claim-contradicts-code`, 2nd occurrence.** The rule chosen after BR-2 was manual ("run a script against the source of truth before it ships"); the family's own history says manual discipline is what failed. The class fix is one `keybindings_spec` case that derives the lead split from the registry and fails when a seventh pair is added.
- **`workshop/plans/000263-new-question-chord-plan.md:998`** — delete the frozen `--verified` literal from the plan entirely rather than correcting it a third time. `lessons.md` already states the rule ("build the `--verified` string from the run you just did, never from the plan"); a stored literal is a hand-maintained restatement that will keep drifting.

```findings
dispose:
  - id: BR-1
    disposition: addressed
    note: |
      Integration spec is parameterized over {"n","i"} (both undo cases pass, 15/15 measured), plus a real nvim_feedkeys insert session; init.lua:2805 comment no longer credits stopinsert and cites branch_ref's i handler, which exists at init.lua:2598.
  - id: BR-2
    disposition: addressed
    note: |
      Verified against config.lua/registry: <C-g>-leading = outline, chat_drill_in, new_question; alt-leading = open_file, branch_ref, chat_prune. The 3-3 claim is now true in atlas, config.lua and the registry comment.
  - id: BR-3
    disposition: addressed
    note: |
      chat_context(what) at init.lua:4278; ChatPrune, ExchangeCut, ExchangePaste and NewQuestion all consume it including ctx.cursor_line (grep-verified, no nvim_win_get_cursor left in the four).
  - id: BR-4
    disposition: addressed
    note: |
      Accepted-and-tracked rather than changed: divergence remains in-tree by explicit decision, filed as parley.nvim#265 (issue file exists) with the real-generation fixture the proper test needs.
  - id: BR-5
    disposition: addressed
    note: |
      Test is relabelled as a double at tests/integration/new_question_spec.lua:282-296 with the measured reasons both realer routes fail, and the plan's Revisions records the substitution.
  - id: BR-6
    disposition: not-addressed
    note: |
      Corrected to "integration 14/14" but round 2 added a 15th case; measured 15/15. It also still omits the tests/arch/superseded_comment_spec.lua failure this diff introduces, and the issue Log's "everything else in make test-unit / make test-integration passes" is false for the same reason.
  - id: BR-7
    disposition: addressed
    note: |
      "`<C-g>` is the prefix surface for everything else." is back with the alt-family paragraph at atlas/ui/keybindings.md:135-136. The same rule recurs in code — raised separately below, not re-raised here.
  - id: BR-8
    disposition: addressed
    note: |
      Integration case "opens above the first exchange when the cursor is in the header" passes, and atlas/chat/lifecycle.md:21-24 names it as get_paste_line's header fallback.
findings:
  - id: new
    severity: Critical
    family: prose-continuity
    title: |
      The exchange_index_at insertion orphaned get_paste_line's doc block, turning tests/arch/superseded_comment_spec.lua red
    detail: |
      lua/parley/exchange_clipboard.lua:58 — get_paste_line's @param/@return block now sits above M.exchange_index_at (:76) and get_paste_line (:86) has no doc at all. Measured: the arch spec passes 9/9 at base bbe05eef and fails 8/9 at head 62c7f292, reporting "@param header_end, but the signature is (parsed_chat, cursor_line, total_lines)". This is the 2nd finding in family prose-continuity (BR-7 was the atlas instance). Do not just move this block — state the rule (an insertion never lands between a doc block and the symbol it documents; the added definition carries the displaced block with it) and note that the code half is already mechanically enforced by superseded_comment_spec while the markdown half has no enforcer.
  - id: new
    severity: Important
    family: pure-classification-drift
    title: |
      chat_context is listed under the plan's "Pure entities" table but reads the current buffer, window and logger
    detail: |
      workshop/plans/000263-new-question-chord-plan.md:26 places chat_context in "### Pure entities (the conceptual core)". lua/parley/init.lua:4278-4310 calls nvim_get_current_buf, nvim_buf_get_name, nvim_buf_get_lines, nvim_win_get_cursor and M.logger.warning/error — it cannot run without a real buffer, window and logger. It belongs in the "Integration points" table with M.cmd.NewQuestion. No test was written against the wrong classification, which is why this is Important rather than Critical; fix the row plus a ## Revisions entry.
  - id: new
    severity: Minor
    family: duplicated-command-preamble
    title: |
      chat_respond.M.respond and M.respond_all still carry the preamble verbatim, outside chat_context's reach
    detail: |
      3rd finding in family duplicated-command-preamble. lua/parley/chat_respond.lua:1717-1735 (M.respond) and :1918-1930 (M.respond_all) repeat not_chat -> warning, find_chat_header_end -> error, parse_chat (+ cursor in respond_all). chat_context is file-local to init.lua so they cannot consume it. Measured prevalence: 4 migrated in init.lua, 2 unmigrated in chat_respond.lua, 1 partial in exporter.lua:965, 1 deliberate divergence in delete_entity_range (init.lua:4547, entity_textobj parity — correctly excluded). Do not fix these two sites; decide the rule — one owner in a shared module, or a written-down boundary explaining why init.lua's helper stops at init.lua.
  - id: new
    severity: Minor
    family: doc-claim-contradicts-code
    title: |
      The corrected 3-3 lead split is still a hand-maintained restatement of the registry with no enforcing test
    detail: |
      2nd finding in family doc-claim-contradicts-code. atlas/ui/keybindings.md:136-145 (and the same phrasing in config.lua:372-383 and keybinding_registry.lua:657-663) asserts a count I verified as currently true, but nothing derives it — grep of keybindings_spec.lua and keybinding_agreement_spec.lua finds no case pinning it. The rule adopted after BR-2 was manual ("run a script before it ships"); the family's history is that manual discipline is what failed. The class fix is one spec case deriving the lead split from the registry so a seventh pair fails the suite instead of drifting the page.
```

---

## Re-review — 2026-09-16T22:22:40-07:00 (FIX-THEN-SHIP)

| field | value |
|-------|-------|
| issue | 263 — Quick key to insert the chat question prefix at cursor |
| repo | parley.nvim |
| issue file | workshop/issues/000263-quick-key-insert-chat-prefix.md |
| boundary | whole-issue close |
| milestone | — |
| window | bbe05eef5b576db2cd367cd66e6def5806650111..859d2c7893c8e069c3f5c17679714c72c9103e22 |
| command | sdlc close --issue 263 |
| reviewer | claude |
| timestamp | 2026-09-16T22:22:40-07:00 |
| verdict | FIX-THEN-SHIP |

## Review

```verdict
verdict: FIX-THEN-SHIP
confidence: high
```

Round 3's blocking regression is genuinely gone: `tests/arch/superseded_comment_spec.lua` is **9/9** at head (I ran it), `exchange_index_at` now carries its own complete `@param`/`@return` block *before* `get_paste_line`'s rather than inside it, and the two class fixes the round promised both landed — `lua/parley/chat_context.lua` is now the one owner of the `not_chat → find_header_end → parse_chat` sequence reachable from any module (I swept the tree: exactly one file matches that co-occurrence, and `chat_respond.respond`/`respond_all` really do consume it with their wording and their interleave preserved), and the 3–3 lead split is derived from the registry by `keybindings_spec` with a plant proving the derivation reads `keys[1]`. Measured myself: unit 14/14, integration 15/15, keybindings **80/80**, superseded_comment 9/9, chat_respond 27/27, batch_respond 16/16, batch_lifecycle 10/10, lint 0/0 across **628** files; the only unit failure in the full suite is the pre-existing `parley_harness_golden_spec` (11 fails, `build_payload` path this diff does not touch), and the only integration failure is `perf_ownership_spec` dying silently under 8-way parallelism — it passes 3/3 serially, twice. Nothing here is a correctness bug. What holds it back from SHIP: the new shared module is invisible to `atlas/` and `atlas/traceability.yaml`, the rule that finally ended the `duplicated-command-preamble` family is prose with no enforcer (the family's 4th appearance, and the round-3 remedy for the *other* repeating family was explicitly "a repeating claim gets an enforcing spec"), no test touches any error branch of the 6 refactored call sites, and the plan's literal `--verified` string has gone stale again.

## 1. Strengths

- **`lua/parley/new_question.lua` is genuinely pure.** The unit spec runs with no buffer, no window, no mocks — it builds `lines`/`parsed_chat` straight from `chat_parser` and reads the plan back as a value (`tests/unit/new_question_spec.lua:24`). The "apply the plan to a copy and read `row` back" case (`:75-88`) checks the post-condition against resulting text rather than the planner's own arithmetic. ARCH-PURE passes cleanly.
- **The off-by-one trap is documented in the assertion itself.** `tests/unit/new_question_spec.lua:60-71` explains why `p.row <= exchanges[2].question.line_start` is `<=` and not `<`, and why "fixing" it destroys the blank-line seam. That comment is worth more than the assertion.
- **The two-phase split of `chat_context` is the right call and the reason is written down.** `lua/parley/chat_context.lua:11-16` names the exact interleave (`respond_all`'s batch precondition between the gates) that a monolithic `resolve` would have reordered. I diffed the migrated control flow against base — the message ordering is preserved verbatim at all six sites.
- **The widened shadowing guard shares one detection function with its plants.** `owners_by_key`/`collisions`/`prefix_shadows` are called by both the guards and both plant tests (`tests/unit/keybindings_spec.lua:1006-1012, 1033-1041`), and the collision plant asserts the offender by name rather than `#found > 0`. This is the ARCH-MOCK/ARCH-DRY failure mode the plan review warned about, avoided.
- **The EOF-append path is correct even though nothing tests it.** I probed it in a scratch spec: cursor on the last line of the last exchange routes through `buffer_edit.replace_user_lines`'s `first == count` special branch (which prepends `"\n"` and anchors at end-of-buffer), and `plan.row` still lands on the question line; a second press focuses rather than duplicating. Confirmed-good ground.

## 2. Critical findings

None.

## 3. Important findings

**I1 — the rule that ends `duplicated-command-preamble` is prose only; nothing stops a fifth copy.** (`lua/parley/chat_context.lua:18-24`, `workshop/plans/000263-new-question-chord-plan.md:1245`) — **This is the 4th finding in family `duplicated-command-preamble`.** Rounds 1–3 each fixed what the finding named: round 1 extracted a file-local helper (4 sites), round 2 swept the fields it owned, round 3 promoted it to a module and migrated the 2 remaining sites. The sweep is now genuinely complete — I measured it, and exactly one file in `lua/` contains `not_chat(` with `find_header_end(`/`parse_chat(` inside the next 25 lines. But the *rule* ("it is written out nowhere else") is a sentence in a module header, and the same round explicitly rejected manual discipline as a remedy for the other repeating family: *"the rule adopted then was manual ('run a probe before the sentence ships'), and manual discipline is exactly what produced the wrong count in the first place"* (`tests/unit/keybindings_spec.lua:1046-1051`). Apply that standard here. Fix: one case in `tests/arch/single_source_sweeps_spec.lua`, in the genre that file already uses — `git ls-files 'lua/**/*.lua'`, scan for the co-occurrence window, assert the match set is exactly `{lua/parley/chat_context.lua}`, with `lua/parley/exporter.lua` (partial: `not_chat` + read, no header/parse) and `delete_entity_range` (routes through `entity_textobj.parsed_for`) named as the recorded exclusions. I verified such a sweep lands **green** today, so it is a cheap write, not a new rework. Cites ARCH-DRY, ARCH-PURPOSE (a hand-maintained restatement of the model is a deferred consumer).

**I2 — `lua/parley/chat_context.lua` is a new cross-module surface with no atlas entry and no traceability row.** The same diff added `lua/parley/new_question.lua` to `atlas/traceability.yaml` under *both* `chat/lifecycle` and `ui/keybindings` (`atlas/traceability.yaml:154, 1079`), and added its tests. `chat_context.lua` — now depended on by four `init.lua` commands and two `chat_respond.lua` entry points, with a stated two-phase contract — appears in no atlas file and in no traceability list (`grep -rln chat_context atlas/ tests/` returns nothing). Per AGENTS.md §8 this is new architectural surface and new terminology ("the chat-entry sequence has one owner"). Fix: a short section in `atlas/chat/lifecycle.md` (or a new `atlas/chat/entry_sequence.md` linked from `atlas/index.md`) naming the owner, the two phases, why the caller keeps the wording, and the recorded exclusions; plus `lua/parley/chat_context.lua` under the `code:` list of whichever doc covers it. The existing sweep only enforces routing for *added specs*, so nothing caught this.

**I3 — no test exercises any error branch of the six migrated call sites, and the invariant that justifies the two-phase shape is unasserted.** `grep -rn "does not look like a chat file\|chat header unavailable\|Batch not started\|could not find header separator" tests/` returns nothing. The round-3 refactor rewrote exactly those branches in `chat_respond.respond` (`lua/parley/chat_respond.lua:1717-1729`) and `respond_all` (`:1914-1925`), and `chat_context.lua:11-16` states a specific guarantee — *"a chat with no `---` AND an active batch would start reporting the header instead of the batch"* — that no fixture enters. **This is the 2nd finding in family `acceptance-clause-untested`.** Do not fix the one site: the rule is that a clause stated as a guarantee (a Done-when bullet, a module-header invariant, a comment saying "otherwise X would happen") gets an assertion or gets deleted, and the enumeration for this round is (a) that message-ordering invariant, (b) `not_chat` and `no_header` for each of the six callers, (c) `resolve`'s `kind` discriminator, which is the only thing keeping `init.lua`'s `chat_context(what)` from logging a warning where it should log an error. A `tests/unit/chat_context_spec.lua` driving `chat_buffer`/`parse`/`resolve` against a non-chat buffer and a header-less chat covers (a)+(c) directly and is the natural home for the enumeration. BR-1's fix set the precedent by parameterizing rather than adding the missing case — same move here.

## 4. Minor findings

- **M1 — `lua/parley/exchange_clipboard.lua:61` claims "The single owner of 'which exchange is the cursor in'"; two other live functions answer it.** **This is the 3rd finding in family `doc-claim-contradicts-code`.** Do not edit this one sentence. The rule, which BR-2's own lesson already states (`workshop/lessons.md:112-119` — *"any sentence asserting 'the only', 'the first', 'always' or a number gets a script run against the source of truth before it ships"*), is that an absolute claim is a grep-checkable assertion and must be either scoped or enforced. Enumeration for this round, both introduced by this diff after that lesson was written: (a) `exchange_clipboard.lua:61` — `parley.find_exchange_at_line` (`init.lua:4125`, semantic-start..margin, component-aware, consumed by `ChatPrune`, `ExchangeCut`, `chat_respond.respond`) and `chat_parser.find_exchange_at_line` (`chat_parser.lua:277`, semantic-start..`answer.line_end`, consumed by `entity_range`) both answer the same English question with different boundaries, so the claim is true only *within* `exchange_clipboard`; scope the sentence or say why three boundary conventions are correct. (b) `workshop/plans/000263-new-question-chord-plan.md:71` still reads *"Insert mode leaves insert first (`stopinsert`) so the buffer write is not folded into the surrounding insert session's undo block"* — the mechanism the same document retracts at `:1117-1122` on measured evidence, and which `init.lua:2806-2812` no longer claims. A reader of the plan body hits the retracted version first.
- **M2 — `chat_context.parse` trusts that `handle.win` displays `handle.buf`.** It reads `nvim_win_get_cursor(handle.win)` against lines from `handle.buf` with no check that they correspond. Unreachable today (every caller passes the current pair), but the module is now the shared entry point and the next caller may not.
- **M3 — removing `chat_shortcut_search` is silent for an operator who set it.** No deprecation path; `config.lua:17` ("options might get deprecated") makes this house practice, and `atlas/ui/keybindings.md:41-43` documents the retirement, so this is a note rather than a gap — but the stale key is ignored without a warning while `<C-g>n` quietly changes meaning.
- **M4 — the flaky-spec note in the issue Log names the wrong member of the class.** The Log/plan name `perf_document_spec`; in my full run `perf_document_spec` passed and `perf_ownership_spec` died silently instead (3/3 serially, twice). Same "silent death under parallel load" class, different file — worth saying "the perf specs" rather than naming one.

## 5. Test coverage notes

- The integration spec's 15 cases walk every plan branch that matters and use an independent oracle (`vim.startswith` scan, never a re-parse) — that discipline is the right one and it holds throughout.
- Not covered, and correct anyway (I verified by probe): cursor inside the **last** exchange, which is the only path through `replace_user_lines`'s `first == count` branch. One case pressing the chord at `{13, 0}` on the existing `FIXTURE` would pin it; the fixture is already there.
- Not covered: the `focus` branch takes **no** write and therefore no `capture_user`, so it performs no streaming-refusal check. Benign today (an empty unanswered question cannot be a generation target), but the ARCH-ORDER claim in `atlas/chat/lifecycle.md` ("refuses visibly while a response is streaming into the region") is only true of the `insert` branch and the normalizing half of `focus`.
- The refusal test is still a stub of `buffer_edit.capture_user`, correctly labelled as a double with the measured reasons the two realer routes fail — disposed in round 1, left as-is, and `#265` carries the real fixture.

## 6. Architectural notes

Worked through each marker on the diff:

- **ARCH-DRY** — *flag*, see I1. The consolidation itself is done and measured; the enforcement is not. Secondary note: three live "which exchange is at this line" functions with three boundary conventions (M1a) is a real long-term hazard even though each is individually justified — worth one atlas paragraph naming the three and when to reach for which, more than worth another extraction.
- **ARCH-PURE** — pass. `new_question.lua` takes `(parsed_chat, lines, cursor_line, header_end, user_prefix)` and returns a value; its spec runs with no IO. `M.cmd.NewQuestion` is a thin shell: resolve context, plan, apply, place cursor. `chat_context` is correctly classified as a boundary after BR-10.
- **ARCH-PURPOSE** — pass on the feature, *flag* on the rule. The shadow-sweep is complete: I enumerated every consumer of the sequence and each derives from `chat_context`. What remains hand-maintained is the *rule about the sweep*, which is I1.
- **ARCH-MOCK** — N/A and correctly argued. No external binary or service; the integration spec drives a real prepped buffer from a real on-disk file rather than a double, and the one stub is labelled as such with evidence.
- **ARCH-CONSTRAINTS** — pass. Keystroke path; one buffer read + one `parse_chat` + one range write per press, the same shape as `ExchangePaste` on the same chord surface. Nothing lands on the per-keystroke path. The plan's envelope section states this with the right basis.
- **ARCH-SECURE** — pass, and well-handled. `user_prefix` is operator config and reaches only `string.sub`/equality, never a pattern position; `tests/unit/new_question_spec.lua:141` pins a `%-Q.:` prefix. The `#214 BR-34` cross-reference in the module header is the right pointer.
- **ARCH-ORDER** — pass with the M1b/coverage caveats. The command carries no state between events; the ordering guarantee it *does* make (refuse rather than corrupt mid-stream) comes from `buffer_edit`'s provenance capture, and `assert(plan.row)` now sits above the write where it can actually prevent a half-applied edit. The one real ordering statement in the tree — `chat_context`'s message-interleave invariant — is untested (I3).
- **ARCH-FUNERAL** — pass. Nothing durable is created; the plan's Residue section argues it rather than writing a bare `N/A`, which is the right form.

## 7. Plan revision recommendations

The plan is otherwise in agreement with the code (all 40 steps ticked; every Core-concepts row verified present at its stated path with its stated kind). Two entries needed:

1. **`## Revisions` — close round 4, the `--verified` string.** Record that `:1005` was stale a second time and what replaces it. Better: delete the literal string from the plan entirely and replace it with "build `--verified` from the closing run", which is the rule `workshop/lessons.md:158-164` already adopted. The plan keeping a literal count is the artifact that keeps violating it.
2. **`## Revisions` — close round 4, the retracted `stopinsert` mechanism.** `:71` still states the undo-block rationale that `:1117-1122` retracts. Either correct `:71` in place with a `(superseded — see Revisions)` marker (the form used for the BR-10 table fix at `:63`) or strike it.

```findings
dispose:
  - id: BR-6
    disposition: not-addressed
    note: |
      Round 1 corrected 15/15->14/14; rounds 2-3 then drifted it again. plan:1005 says "integration 14/14 ... 627 files"; measured at head: integration 15/15, lint 628 files, keybindings 80/80. 2nd in family stale-close-evidence, so the fix is the class: the plan should not carry a literal count at all (lessons.md:158-164 already says build --verified from the closing run) -- delete the literal, keep the rule.
  - id: BR-9
    disposition: addressed
    note: |
      Verified: exchange_index_at carries its own complete @param/@return block placed before get_paste_line's; tests/arch/superseded_comment_spec.lua runs 9/9 at head (was 8/9 at 62c7f292). Rule written at lessons.md:6-12. Gap noted only: the lesson states the verification rule ("run the arch suite after any edit that relocates code") but not the structural rule the finding asked for, and does not record that the markdown half of prose-continuity has no enforcer.
  - id: BR-10
    disposition: addressed
    note: |
      chat_buffer/parse/resolve moved to the "Integration points" table (plan:74-80) with chat_context.lua listed and each function's boundary named; the Pure-entities bullet at plan:63 records the correction inline and the round-3 Revisions entry names BR-10.
  - id: BR-11
    disposition: addressed
    note: |
      Rule chosen and applied: one owner in a shared module (lua/parley/chat_context.lua), two-phase because respond_all interleaves its batch precondition. Both chat_respond sites migrated with wording and message ordering preserved verbatim (diffed against base); chat_respond 27/27, batch_respond 16/16, batch_lifecycle 10/10. Swept tree-wide: exactly one file now contains the not_chat/find_header_end/parse_chat co-occurrence. See new finding on enforcement.
  - id: BR-12
    disposition: addressed
    note: |
      keybindings_spec.lua:1055-1092 derives the split from the registry and pins both sides, plus a case that flips one entry's key order to prove the derivation reads keys[1] rather than membership; keybindings 80/80. keybinding_registry.lua:1264 confirms help renders keys[1].
findings:
  - id: new
    severity: Important
    family: duplicated-command-preamble
    title: |
      The rule that ends this family is prose in a module header; nothing stops a fifth copy
    detail: |
      4th finding in this family. The sweep is genuinely complete -- I measured it, exactly one file in lua/ contains not_chat( with find_header_end(/parse_chat( within 25 lines. But "it is written out nowhere else" (chat_context.lua:22-24, plan:1245) is a sentence, and the same round rejected manual discipline as a remedy for doc-claim-contradicts-code. Do not fix another instance: add one case to tests/arch/single_source_sweeps_spec.lua asserting the match set is exactly {lua/parley/chat_context.lua}, with exporter.lua (partial) and delete_entity_range (entity_textobj.parsed_for) as the recorded exclusions. I confirmed such a sweep lands green today. ARCH-DRY, ARCH-PURPOSE.
  - id: new
    severity: Important
    family: new-surface-not-in-atlas
    title: |
      lua/parley/chat_context.lua has no atlas entry and no traceability row
    detail: |
      The same diff routed lua/parley/new_question.lua into atlas/traceability.yaml under both chat/lifecycle and ui/keybindings and documented it in atlas/chat/lifecycle.md. chat_context.lua -- now depended on by four init.lua commands and two chat_respond.lua entry points, with a stated two-phase contract and a new repo-wide convention -- appears in no atlas file and no traceability list (grep -rln chat_context atlas/ tests/ is empty). AGENTS.md section 8. The existing sweep only enforces routing for added specs, so nothing caught it.
  - id: new
    severity: Important
    family: acceptance-clause-untested
    title: |
      No test enters any error branch of the six migrated call sites, and the invariant justifying the two-phase split is unasserted
    detail: |
      2nd finding in this family. grep for "does not look like a chat file", "chat header unavailable", "Batch not started", "could not find header separator" across tests/ returns nothing -- yet those branches are exactly what round 3 rewrote. chat_context.lua:11-16 states a specific guarantee (a header-less chat with an active batch must report the batch, not the header) that no fixture enters. Do not add the one missing case: the rule is that a clause stated as a guarantee gets an assertion or gets deleted, and this round's enumeration is (a) that ordering invariant, (b) not_chat and no_header for each of the six callers, (c) resolve's `kind` discriminator, which is the only thing keeping init.lua's chat_context(what) from logging a warning where it should log an error. A tests/unit/chat_context_spec.lua covers (a) and (c) directly.
  - id: new
    severity: Minor
    family: doc-claim-contradicts-code
    title: |
      Two absolute claims introduced by this diff after the lesson that bans unchecked absolutes
    detail: |
      3rd finding in this family. State the rule, do not patch the sentence: an absolute claim is a grep-checkable assertion and must be scoped or enforced (lessons.md:112-119, written in this same diff). Enumeration: (a) exchange_clipboard.lua:61 "The single owner of 'which exchange is the cursor in'" -- parley.find_exchange_at_line (init.lua:4125) and chat_parser.find_exchange_at_line (chat_parser.lua:277) both answer it with different boundary conventions and are consumed by ChatPrune, ExchangeCut, chat_respond.respond and entity_range; the claim is true only within exchange_clipboard. (b) plan:71 still states that stopinsert keeps the write out of the surrounding insert session's undo block -- the mechanism the same document retracts at :1117-1122 on measured evidence and that init.lua:2806-2812 no longer claims.
  - id: new
    severity: Minor
    family: shared-entrypoint-unchecked-pairing
    title: |
      chat_context.parse reads the cursor from handle.win without checking it displays handle.buf
    detail: |
      lua/parley/chat_context.lua:44-56 pairs lines from handle.buf with nvim_win_get_cursor(handle.win). Every caller today passes the current buffer/window pair so it is unreachable, but this is now the shared entry point for six call sites and the next caller may pass a buf without its window.
```
