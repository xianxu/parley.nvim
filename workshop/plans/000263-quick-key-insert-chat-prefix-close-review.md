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
