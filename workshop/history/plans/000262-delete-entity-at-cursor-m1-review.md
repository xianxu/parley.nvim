# Boundary Review — parley.nvim#262 (milestone M1)

| field | value |
|-------|-------|
| issue | 262 — Delete entity at cursor — markdown section, paragraph, or chat question |
| repo | parley.nvim |
| issue file | workshop/issues/000262-delete-entity-at-cursor.md |
| boundary | milestone M1 |
| milestone | M1 |
| window | 85e116c2da14c941735c7d7e67bb023aaff3aa00..cb17a0a6d7d7e89e5a690e08fade6315992b03e4 |
| command | sdlc milestone-close --issue 262 --milestone M1 |
| reviewer | claude |
| timestamp | 2026-09-16T13:53:02-07:00 |
| verdict | REWORK |

## Review

```verdict
verdict: REWORK
confidence: high
```

The core is genuinely good work: `entity_range` is a clean pure function with 29 no-mock unit assertions plus a malformed-transcript property sweep, the two editor-state hazards (visual anchor, closed folds) are real and pinned by tests, the `outline.lua` fold-onto-the-shared-dialect is byte-faithful, and the parity harness is the right guard for a two-surface design. All 45 assertions in the feature's mapped specs pass, as do `keybinding_agreement`, `keybindings`, `single_source_sweeps`, `starter_config`, `outline` and `outline_parity` (I ran them). What blocks SHIP is that the range has no floor at the chat header: I verified end-to-end that `dae` on line 1 of a real transcript empties the buffer, and `dae` on line 2 deletes the `---` separator so `find_header_end` returns `nil` — after which every later range silently loses its exchange clamp and crosses `💬:` boundaries, which the Spec forbids outright. The parity spec loops `for row = 4, #FIXTURE`, so the three header rows — the only rows where this is reachable — are exactly the ones not covered, while Done-when claims parity "over every cursor row".

## 1. Strengths

- `tests/integration/entity_textobj_spec.lua:118-129` and `:157-169` — the `vae`-anchor and closed-fold cases are pinned by tests that actually reproduce the hazard (single `:normal 10GVjaed`, a real `14,17fold`). These are the two defects a naive spec would have missed, and they are tested at the right layer.
- `lua/parley/entity_range.lua` — the pure/IO split holds: `range(parsed, lines, row, opts)` never sees a buffer, and the specs need zero mocks. The invariant sweep at `tests/unit/entity_range_spec.lua:253-278` (rows `0..#lines+2`, both scopes, both inner values) is the right shape for hand-edited input.
- `lua/parley/starter_config.lua:25-35` — the `object_only` carve-out is narrowly scoped, and `tests/unit/starter_config_spec.lua:39-46` pins the negative (`resolve_ref_gf`, a bare normal-mode key in the same scope, still excluded). That is how a filter widening should be proven.
- `lua/parley/outline.lua:51-60` — I checked the replacement is behaviour-preserving: `("  "):rep(level)` reproduces the old 2/4/6 ladder exactly, `#### Four` was a non-heading before and still is. `outline_spec` (20) and `outline_parity_spec` (15) both green.
- The conformance test genuinely enforces the single source rather than documenting it — `markdown_heading` vs `document/lexical`'s independent byte-scanner over a 20-line corpus that straddles the cap, the required space and indentation.

## 2. Critical findings

**`lua/parley/entity_range.lua:193-219` (and both callers: `lua/parley/entity_textobj.lua:24-38`, `lua/parley/init.lua:4529-4545`) — the range has no header floor.**

Verified on a real prepped chat buffer, both surfaces identical:

| cursor | result |
|---|---|
| line 1 `# topic: probe` | buffer reduced to `{ "" }` — whole transcript gone (`dae` **and** `:ParleyDeleteEntity`) |
| line 2 `- file: probe.md` | deletes `- file:` + `---` + blank; `chat_parser.find_header_end` then returns `nil` |
| line 3 `---` | same range (2..4) |

The header `# topic:` is a valid level-1 heading in the dialect, nothing outranks it, and `exchange_at` returns no bounds above the first exchange, so `section_range` runs to EOF. It compounds: after the `---` is gone I measured `dae` on a `## a heading` *inside an answer* deleting through EOF and swallowing the following `💬: second q` exchange — the one thing the Spec says must never happen ("never crosses the next `💬:`").

Fix sketch: both callers already compute `header_end`; thread it into `range` as `opts.header_end` and (a) return `nil` when `row <= header_end`, (b) floor the `lo`/`hi` of `paragraph_range`/`section_range` at `header_end + 1` when there is no exchange bound. Then change `tests/integration/entity_delete_parity_spec.lua:79,87` to `for row = 1, #FIXTURE` — which is what Done-when already claims — and add a unit case asserting `range(parsed, lines, 1) == nil`.

## 3. Important findings

**`lua/parley/entity_textobj.lua:31-36` / `lua/parley/init.lua:4536-4540` — a chat buffer that doesn't parse degrades silently to unclamped markdown semantics.** `parsed_for` returns `nil` both when the buffer is not a chat and when `find_header_end`/`parse_chat` fails on a chat; the command path does the same. The caller cannot tell the two apart, so `bounds` is `nil` and ranges stop being clamped to the exchange — with no log line. This is reachable in ordinary editing (the header is mid-edit, or after the Critical finding above). Fix: distinguish the two cases and warn/refuse on "chat buffer, no parse" rather than falling through to markdown rules.

**No test exercises the streaming refusal (ARCH-ORDER).** Plan Task 11 Step 4 and the plan's ARCH-ORDER paragraph both commit to it ("Task 11 tests the refusal"), and it is the single documented asymmetry between the two surfaces — the reason the parity claim is scoped to a quiescent document. Nothing in `tests/` touches `replace_user_lines`' raise for these commands. Without it the parity spec's scoping comment is an assertion about untested behaviour.

**ARCH-CONSTRAINTS: the declared envelope is missed and not revised.** `workshop/plans/000262-delete-entity-at-cursor-plan.md:98` declares "target < 16 ms on a 5 000-line transcript … a miss is a finding, not a silent widening". The measurement recorded in Task 13 and in `atlas/chat/entity_delete.md` is 24.7 ms at 5 000 lines. I re-measured independently (parse + range, best of 5): 8.5 ms @ 2 506, **17.0 ms @ 5 008**, 72.1 ms @ 20 002 — same shape, still over budget. Neither the plan's ARCH-CONSTRAINTS block nor the issue records the deviation, and because the perf module was dropped, the atlas numbers cannot be re-checked from the repo when the parser changes. Either revise the budget explicitly (with the operator's acceptance) or take the `document.exchange(doc, row)` escape hatch the plan names.

**`lua/parley/outline.lua:254` — the single-source sweep left a consumer behind (ARCH-DRY / ARCH-PURPOSE shadow-sweep).** `outline.lua` has *two* heading paths; the diff folded the line-based one (`:51-60`) onto `markdown_heading` but the token-based one still hand-restates the dialect cap: `token.heading_level and token.heading_level <= 3`, plus its own `string.rep("  ", level)` ladder. Nothing enforces it — raise `MAX_LEVEL` to 6 and the conformance test would catch `lexical.lua:352` but `outline.lua:254` would silently keep truncating. The plan's Core-concepts table lists the outline consumer as `outline.lua:52-60` only, so the table understates the consumer set. Fix: `token.heading_level <= markdown_heading.MAX_LEVEL`.

## 4. Minor findings

- `ie` has no surface-level test at all, and no test exercises `c` for either object, though Done-when claims `ae`/`ie` "work with every operator (`d`/`y`/`c`/`v` at minimum)". I confirmed `die` and `cae` behave correctly, so this is coverage, not a defect.
- A cursor on a structural marker line (`🤖:`, `🔧:`, `📎:`, `📝:`, `🌿:`) yields no entity and the text object silently does nothing; the atlas dispatch table says "anything else → that paragraph". Worth one line in the atlas.
- The fenced-heading decision is stated in the atlas "Limits" but never pinned by an assertion — plan Task 7 Step 3 asked for the note *and* a test; the corpus entry only feeds the invariant sweep.
- `atlas/chat/entity_delete.md` "Code and tests" omits `tests/integration/entity_delete_parity_spec.lua`.
- `atlas/traceability.yaml:140-149` — no blank line before `chat/lifecycle:` (valid YAML, inconsistent with the file's shape).
- Commit `e007f6c5` (`#262 M2:`) carries unrelated `workshop/parley/` transcript churn (one file re-answered, one renamed/replaced, one scratch chat added) — `side-quest:` or a separate commit per AGENTS.md §12.
- The five-entry dispatch block is duplicated verbatim (comment included) between `init.lua:2778-2786` and `:2986-2994`. Consistent with the file's existing shape, so not a finding — but the two tables are now long enough to deserve the shared constructor `branch_inserters` already demonstrates.

## 5. Test coverage notes

Coverage is strong where the author looked and has a hole exactly where the Critical finding lives. The parity spec is the best artifact in the diff — both surfaces, every row, closed fold in the fixture — but `for row = 4` excludes the header, and that exclusion is the reason a whole-transcript delete shipped green. `markdown_heading` is well covered including the negative cases; `entity_range` has 29 assertions plus the property sweep. Missing: header rows (Critical), the streaming refusal (Important), `ie`/`c` at the surface, and an integration-level assertion that a 📝 at the answer edge actually survives a `daE` (the unit rule is tested; the end-to-end behaviour the operator asked for is not). The parity fixture does contain a 📝 at line 19, so adding one assertion there is cheap.

## 6. Architectural notes for upcoming work

- ARCH-DRY: flag (outline.lua:254, above). ARCH-PURE: pass — the boundary held; no range test needs a buffer. ARCH-PURPOSE: flag — the shadow sweep over "who consumes the heading dialect" found the deferred consumer; note `exporter.lua:539-541` also maps `^## `/`^### ` to `h2`/`h3` independently (pre-existing, out of this diff's scope, but it belongs in the enumeration when levels 4-6 are considered). ARCH-MOCK: N/A, correctly — no external binary or service, Neovim exercised for real. ARCH-CONSTRAINTS: flag (budget). ARCH-SECURE: mostly pass — the property sweep over malformed transcripts is the right instinct, but the silent parse-failure fallback is the untyped-degradation case the principle warns about. ARCH-ORDER: flag (refusal untested); the "holds no state between events" claim is correct and verified. ARCH-FUNERAL: pass — keymaps die with the buffer-local lifecycle, and the specs' `$TMPDIR/claude/parley-test-*` dirs follow the repo's established idiom under the managed scratch root that `make test-clean-env` removes.
- For the follow-up that collapses `ChatPrune`/`ExchangeCut` onto `entity_range`: those two *do* guard the header (`init.lua:4449-4453` errors when `---` is missing). Whatever guard fixes the Critical finding should be the one they inherit, not a third copy.

## 7. Plan revision recommendations

The plan needs a `## Revisions` section (it has none, and the file was rewritten wholesale in this window, 745 lines changed) with:

- **Header floor.** Record that the Spec's section rule, applied literally, takes the transcript header — and what the new floor is. The issue's `## Spec` and `## Done when` need the same sentence, since neither mentions the header today.
- **ARCH-CONSTRAINTS budget.** The declared `< 16 ms @ 5 000 lines` was measured at 24.7 ms (independently re-measured at 17.0 ms best-of-5). State the accepted figure and the basis, or state the escape hatch is now in scope.
- **Core concepts table.** Add the second outline consumer (`outline.lua:254`, token path) to the `outline heading dialect` row; the table currently claims `:52-60` is the whole modification.
- **Task 11/12 artifact name.** `tests/integration/entity_delete_spec.lua` is named in Tasks 11 and 12 and was never created; the traceability entry routes 5 specs, not the 6 Task 12 enumerates. Rename to `entity_delete_parity_spec.lua` or say the refusal test lands there.
- Housekeeping: 66 task checkboxes are all still `- [ ]` while the issue's `## Plan` marks M1 and M2 `[x]`; Task 13's step numbering jumps from Step 2 to Step 6.

---

## Re-review — 2026-09-16T14:06:15-07:00 (REWORK)

| field | value |
|-------|-------|
| issue | 262 — Delete entity at cursor — markdown section, paragraph, or chat question |
| repo | parley.nvim |
| issue file | workshop/issues/000262-delete-entity-at-cursor.md |
| boundary | milestone M1 |
| milestone | M1 |
| window | 8448f249ec0002ca36616b964d6806c77b11f9ab..8448f249ec0002ca36616b964d6806c77b11f9ab |
| command | sdlc milestone-close --issue 262 --milestone M1 |
| reviewer | claude |
| timestamp | 2026-09-16T14:06:15-07:00 |
| verdict | REWORK |

## Review

```verdict
verdict: REWORK
confidence: high
```

**Inspection note first:** the pinned window is degenerate — `base == head == 8448f249`, so `--stat`, `--name-status` and the full diff all return empty. The commands ran cleanly (rc 0); there is nothing in the range. The gate ledger explains why: round 1 recorded `protocol_error: no valid findings block`, registered zero findings, and marked the round `blocked: false`, after which the window advanced to `HEAD..HEAD`. I therefore reviewed the substantive M1 content at `85e116c2..8448f249` (branch point → HEAD), with the rework commit `cb17a0a6..8448f249` read separately.

The rework is careful work and the header-floor rule is the right shape — `parsed.header_end + 1` derived from the parse rather than threaded through `opts`, pinned by three new unit assertions and a parity loop that now starts at row 1. All 32 `entity_range`, 13 `entity_textobj`, 2 parity, 21 `single_source_sweeps`, 33 `keybinding_agreement`, 75 `keybindings`, 7 `starter_config` and 20 `outline` assertions are green (I ran them). What blocks SHIP is that the fix landed on the **instance**, not the **class**: the floor only exists when the buffer was classified a chat by `not_chat`, and `not_chat` fails for five reasons that have nothing to do with the `---`. I reproduced, end to end, a transcript renamed to a non-timestamp filename — classified `markdown`, `ae` map installed, `dae` on line 1 → buffer reduced to `{ "" }`. That is byte-for-byte the failure round 1 called Critical, still shipping.

## 1. Strengths

- `lua/parley/entity_range.lua:203-209` — deriving the floor from `parsed.header_end` instead of accepting round 1's `opts.header_end` sketch is the better call, and the comment says why. The rule is stated once and every path inherits it.
- `tests/integration/entity_textobj_spec.lua:137-150` — the regression asserts line 1 is a **no-op**, not merely that the two surfaces agree. Round 1's own analysis showed parity alone would have stayed green while both surfaces deleted everything; the author read that correctly and wrote the right oracle.
- `lua/parley/entity_textobj.lua:31-46` — `parsed_for` returning `(parsed, status)` with three named cases is the right shape for "not a chat" vs "a chat that will not parse"; the doc comment states the hazard rather than the mechanism.
- `lua/parley/outline.lua:254` now reads `markdown_heading.MAX_LEVEL`, closing the second consumer round 1 found. `outline_spec` (20) still green, so the fold is behaviour-preserving.
- The ARCH-CONSTRAINTS miss is handled exactly as the principle asks — plan `## Revisions` and `atlas/chat/entity_delete.md:80-88` both record 24.7 ms against a 16 ms budget, the independent 17.0 ms re-measure, the operator's basis, and the `document.exchange` escape hatch. No silent widening.

## 2. Critical findings

**`lua/parley/entity_range.lua:206` — the header floor is gated on chat classification, so a transcript that parley classifies `markdown` has no floor and `dae` on line 1 destroys it.**

`floor` is `parsed.header_end + 1`, and `parsed` is non-nil only when the buffer passed `not_chat` / the `_parley_bufs` latch. `not_chat` (`lua/parley/init.lua:1803-1834`) rejects for five reasons unrelated to document shape: file not under a configured chat root, filename not timestamped, fewer than 5 lines, missing `topic` header, missing `file` header. Any of those leaves a file that *is* structurally a transcript classified `markdown`, where `# topic: …` is an ordinary level-1 heading that nothing outranks.

Reproduced end to end (fixture = the `entity_textobj_spec` FIXTURE, written to `<chat_dir>/notes-about-entities.md`):

```
not_chat   -> file does not have timestamp format
latch      -> markdown
has ae map -> 1                      # the text object IS installed
dae @ row 1 -> #lines=1  ""          # whole transcript gone
```

Same result with an intact `---` and a blank `# topic:` (`not_chat -> missing topic header`): `:ParleyDeleteEntity` on line 1 → `#lines=1`, and `dae` on a `## a heading` inside the first answer swallows `💬: second q` through EOF on **both** surfaces. This violates the issue's Done-when ("No range ever starts at or above the header separator") and `atlas/chat/entity_delete.md:37`, which already documents the contract the code doesn't hold.

Fix sketch: the floor must come from the document's own shape, not from whether the buffer was classified a chat. Add a pure `transcript_header_end(lines)` to `markdown_heading` or `entity_range` that recognises the transcript signature (a `# topic:`-shaped line 1 **or** front-matter `---`, plus a `---` terminator — not merely any `---`, which would floor a thematic break in a genuine note) and use it whenever `parsed` is absent. It stays pure and unit-testable. Then extend `tests/unit/entity_range_spec.lua`'s header-floor block with `range(nil, FIXTURE, 1) == nil`, and add an integration case that loads a transcript under a non-timestamp name.

**`lua/parley/init.lua:4534-4545` — the command path's unparsable-header refusal sits inside `if not reason then`, so it is unreachable exactly when it is needed, and the two surfaces diverge.**

When the user edits the `---` away in an open chat the latch still says `chat` but `not_chat` re-evaluates to `"missing header separator"`, so `reason` is truthy, the new guard is skipped entirely, and `parsed_chat` stays `nil` — unclamped markdown semantics with no log line. Reproduced:

```
not_chat -> missing header separator   latch -> chat
:ParleyDeleteEntity @ '## a heading'  -> deletes through EOF, 💬: second q gone
normal dae            (same state)    -> refuses with the warning   ← diverges
```

This is the Important round 1 raised, fixed on the text object and only half-fixed on the command, and it now also breaks the parity claim that `tests/integration/entity_delete_parity_spec.lua` exists to defend. The `if not reason then` structure means chat-ness is asked twice with two different answers; the refusal should hang off the same classification both surfaces use (or, better, become moot once the floor above is document-derived).

## 3. Important findings

**No test exercises the streaming refusal, yet `workshop/plans/000262-delete-entity-at-cursor-plan.md:957` ticks Step 4 `[x]` ("Test the refusal path … must raise").** `grep` over `tests/` for `DeleteEntity|DeleteToEnd|replace_user_lines` refusal returns only the parity spec's two `vim.cmd` calls. This is the single documented asymmetry between the surfaces, named in the issue's Done-when and in the plan's ARCH-ORDER paragraph ("Task 11 tests the refusal"), and it is the scoping premise of the parity spec's header comment. Round 1 raised it; the rework ticked the box instead of writing the test. Either deliver it or untick Step 4 and record the deferral.

**`tests/integration/entity_delete_parity_spec.lua` varies only the cursor row, never the document shape.** The fixture is always a well-formed chat, so every row exercises the same classification branch — which is why both Criticals above are invisible to a green parity run. A parity claim over two surfaces has to vary the inputs that *select* the surfaces' code paths. Cheap fix: parameterise `fresh()` over `{ FIXTURE, FIXTURE_without_separator, FIXTURE_without_file_header }` and loop the existing assertions over all three.

## 4. Minor findings

- `lua/parley/entity_range.lua:88-90` — `section_range`'s `floor` guard is unreachable: `M.range:207` already returns `nil` for `row < floor`, and the `to_end` back-scan (`:255`) starts at `floor`. The second call site (`:257`) omits the argument entirely. Dead guard; drop it or make it the real enforcement point.
- `lua/parley/init.lua:4544` calls `M.parse_chat` bare while `entity_textobj.lua:41` wraps the same call in `pcall` — inconsistent error handling for identical input across the diff.
- Two different warning strings for one condition: `"Parley: entity object needs a readable chat header…"` (`entity_textobj.lua:59`) vs `"DeleteEntity: chat header is unreadable…"` (`init.lua:4542`).
- `README.md:16-20` documents `dae`/`daE`/`yae`/`cae` but not `ie`, `<C-g>k` or `<C-g>K`, which `atlas/ui/keybindings.md` does list.
- The atlas perf figures (`entity_delete.md:80-88`) can't be re-derived from the repo — no perf spec landed, so the numbers go stale silently when `parse_chat` changes.

## 5. Test coverage notes

Coverage grew well where round 1 pointed: the header-floor unit block (3 cases incl. a whole-buffer sweep asserting `r.first > parsed.header_end`), the integration no-op regression over rows 1-3, `die`/`cae`, the edge-📝 survival through `daE`, and the app-profile `object_only` carve-out with its negative (`resolve_ref_gf` still excluded). The `entity_range` property sweep over malformed transcripts remains the best artifact in the diff. The hole is one axis wide and it is the axis both Criticals live on: **every** integration fixture is a valid, chat-classified transcript. Nothing loads a transcript under a non-chat filename, outside a chat root, or with a blank `topic`/`file` header — and those are the states in which the feature deletes the user's file.

## 6. Architectural notes for upcoming work

- **ARCH-DRY — flag.** "Is this a transcript?" is now answered three ways with three different results: `not_chat` (`init.lua:1803`), the `_parley_bufs` latch (`highlighter.lua:1153/1168`), and `parsed.header_end` inside `entity_range`. The heading-dialect consolidation was done properly; this one wasn't started. Cited in Critical 1/2.
- **ARCH-PURE — pass.** `range(parsed, lines, row, opts)` still never sees a buffer; 32 unit assertions run with zero mocks. The recommended `transcript_header_end(lines)` keeps that property.
- **ARCH-PURPOSE — flag.** This is the entry's exact at-review case: round 1 named one site (chat buffers with a parseable header); the class is "every buffer where the object is installed but no parse happened," and that class is enumerable straight off `not_chat`'s five return strings. Fixing the named site while the siblings remain is the instance, not the class.
- **ARCH-MOCK — N/A, correctly.** No external binary or service; Neovim is exercised for real via `prep_chat` + `Document.attach`.
- **ARCH-CONSTRAINTS — pass with note.** The miss is recorded with basis and escape hatch rather than restated. Note only that the measurement is not reproducible from the repo.
- **ARCH-SECURE — flag.** The diff's own framing is right (a transcript is hand-editable, possibly truncated input) and the property sweep is the right instinct, but the degradation is still silent on the markdown-classified path: the code substitutes "this is an ordinary markdown note" for "I could not parse this," and downstream deletes act on that fabricated reading.
- **ARCH-ORDER — flag.** "Holds no state between events because every call re-derives from `(parsed, lines, row)`" is correct and verified. The one unblockable event the plan itself names — a write landing while a response streams — has no test and no seam to inject the ordering, so the green parity run is a sample of size one over the quiescent interleaving only.
- **ARCH-FUNERAL — pass.** No durable artifact; keymaps die with the buffer-local lifecycle (`highlighter.lua:1228`), and the new specs' `$TMPDIR/claude/parley-test-*` roots sit under the tree `make test-clean-env` removes.
- For the follow-up that collapses `ChatPrune`/`ExchangeCut` onto `entity_range`: both already guard the header (`init.lua:4449-4453` errors on a missing `---`). Whichever guard resolves Critical 1 should become the one they inherit, not a fourth restatement.

## 7. Plan revision recommendations

- **Core concepts table, `outline` row (`plan.md:43`).** The Revisions entry acknowledges the second consumer but the table still reads `lua/parley/outline.lua:52-60`. Change to `:52-60, :254` so the table stops understating what was modified.
- **Task 11 Step 4 (`plan.md:957`).** Untick, or deliver the refusal test. A ticked box with no artifact is what let this cross two rounds.
- **New `## Revisions` entry once the Criticals are fixed:** record that the header floor is a property of the *document*, not of chat classification, and enumerate the `not_chat` failure modes it must survive — that enumeration is the class, and writing it down is what stops a third round.
- **ARCH-SECURE paragraph.** It currently promises `range` returns `nil` for malformed input; add that the *floor* must hold for a transcript-shaped buffer the classifier rejected, which is the case Task 7's corpus does not reach.

```findings
findings:
  - id: new
    severity: Critical
    family: guard-gated-on-classification
    title: |
      header floor exists only for chat-classified buffers; dae on line 1 of a markdown-classified transcript empties the file
    detail: |
      entity_range.lua:206 derives floor from parsed.header_end, and parsed is
      non-nil only when not_chat() passed. not_chat rejects for five reasons
      unrelated to document shape (not under a chat root, non-timestamp
      filename, <5 lines, missing topic, missing file header). Reproduced: a
      transcript saved as notes-about-entities.md is classified markdown, the
      ae map is still installed, and dae on line 1 reduces the buffer to a
      single empty line. With a blank "# topic:" both surfaces also delete a
      section through EOF across the next 💬:. Violates the issue Done-when and
      atlas/chat/entity_delete.md:37. Fix: derive the floor from a pure
      transcript_header_end(lines) (topic-shaped line 1 or front matter, plus a
      --- terminator) whenever parsed is absent.
  - id: new
    severity: Critical
    family: guard-gated-on-classification
    title: |
      the command path's unparsable-header refusal is unreachable when not_chat fails, so the two surfaces diverge
    detail: |
      init.lua:4534-4545 puts the new refusal inside `if not reason then`.
      Editing the --- away leaves the latch at "chat" but makes not_chat return
      "missing header separator", so the guard is skipped and parsed_chat stays
      nil -- unclamped markdown semantics, no log line. Reproduced:
      :ParleyDeleteEntity on a heading inside the first answer deletes through
      EOF and swallows the next exchange, while `normal dae` on the identical
      state refuses. Breaks the parity claim the parity spec exists to defend.
  - id: new
    severity: Important
    family: checkbox-without-artifact
    title: |
      plan Task 11 Step 4 is ticked but no test exercises the streaming refusal
    detail: |
      grep over tests/ for DeleteEntity/DeleteToEnd/replace_user_lines finds
      only the parity spec's two vim.cmd calls. The refusal is the single
      documented asymmetry between the surfaces, named in the issue Done-when,
      in the plan's ARCH-ORDER paragraph ("Task 11 tests the refusal") and in
      the parity spec's scoping comment. Deliver it or untick Step 4 and record
      the deferral.
  - id: new
    severity: Important
    family: parity-varies-only-cursor
    title: |
      the parity spec varies only the cursor row, never the document shape, so classification divergence is invisible to it
    detail: |
      tests/integration/entity_delete_parity_spec.lua always builds a
      well-formed chat, so all 24 rows exercise the same classification branch.
      Both Criticals above stay green under it. Parameterise fresh() over a
      valid fixture, one with the --- removed, and one with the `- file:`
      header removed, and loop the existing assertions over all three.
  - id: new
    severity: Minor
    family: unreachable-guard
    title: |
      section_range's floor parameter is dead code
    detail: |
      entity_range.lua:88-90 can never fire: M.range:207 already returns nil
      for row < floor, and the to_end back-scan at :255 starts at floor. The
      second call site (:257) omits the argument. Drop it or make it the real
      enforcement point.
  - id: new
    severity: Minor
    family: inconsistent-error-handling
    title: |
      parse_chat is pcall-wrapped on one surface and bare on the other, with two different warning strings for one condition
    detail: |
      entity_textobj.lua:41 wraps parse_chat in pcall; init.lua:4544 calls
      M.parse_chat bare on identical input. The same "unreadable header"
      condition warns as "Parley: entity object needs a readable chat header…"
      on one surface and "DeleteEntity: chat header is unreadable…" on the
      other.
  - id: new
    severity: Minor
    family: plan-table-understates-code
    title: |
      Core concepts table still names only outline.lua:52-60 as the modified outline consumer
    detail: |
      plan.md:43 reads `lua/parley/outline.lua:52-60`; the diff also changed
      the token path at :254. The Revisions entry records this but the table
      row was never updated, so the table still understates the consumer set.
  - id: new
    severity: Minor
    family: readme-omits-new-surface
    title: |
      README documents dae/daE/yae/cae but not ie, <C-g>k or <C-g>K
    detail: |
      README.md:16-20 covers the outer objects only. atlas/ui/keybindings.md
      lists the full set, so this is a README-side omission of user-typed
      surface introduced in the same range.
  - id: new
    severity: Minor
    family: unreproducible-measurement
    title: |
      the atlas perf figures cannot be re-derived from the repo
    detail: |
      atlas/chat/entity_delete.md:80-88 records 13.6 / 24.7 / 97.8 ms, but no
      perf spec landed, so the numbers go stale silently when parse_chat
      changes.
```

---

## Re-review — 2026-09-16T14:31:20-07:00 (FIX-THEN-SHIP)

| field | value |
|-------|-------|
| issue | 262 — Delete entity at cursor — markdown section, paragraph, or chat question |
| repo | parley.nvim |
| issue file | workshop/issues/000262-delete-entity-at-cursor.md |
| boundary | milestone M1 |
| milestone | M1 |
| window | aa001961ae1584d248ba39e9dabcb6c5d81bf1f0..aa001961ae1584d248ba39e9dabcb6c5d81bf1f0 |
| command | sdlc milestone-close --issue 262 --milestone M1 |
| reviewer | claude |
| timestamp | 2026-09-16T14:31:20-07:00 |
| verdict | FIX-THEN-SHIP |

## Review

```verdict
verdict: FIX-THEN-SHIP
confidence: high
```

**Window note first:** the pinned window is degenerate — base and head are the same commit (`aa001961`), so both required recipes return empty (exit 0, no output). Nothing was unavailable, so this is not a failed inspection; I reviewed the tree at HEAD and the full branch range `85e116c2..HEAD` instead, and verified every claim by execution rather than by reading the diff.

Both round-2 Criticals are genuinely dead, and I confirmed that by reverting each fix in a scratch copy rather than trusting the commit messages. BR-1's header floor now derives from the document's own shape, and reverting that derivation turns two tests red. BR-2's classifier collapse is verified by direct execution: at HEAD both surfaces refuse on a header-edited-away chat; with the fix reverted, `:ParleyDeleteEntity` takes the buffer from 15 lines to 8, swallowing `💬: second q`, while `dae` is a no-op — the exact divergence BR-2 named. What blocks a clean SHIP is that the whole suite stayed green with that BR-2 fix reverted: the fix is correct but unprotected, because the parity spec's new second axis varies the *filename* (classification), not the document shape, and the two shapes BR-4 prescribed (`---` removed, `- file:` removed) were not delivered. Separately, the new `transcript_header_end` validates only line 1 and then delegates to an unbounded `find_header_end` scan, so a markdown note titled `# topic: …` gets its floor set at a thematic break far down the file and `dae` goes silently dead over the whole prefix above it.

## 1. Strengths

- **`lua/parley/entity_range.lua:211-217`** — the floor is *derived* inside `M.range` rather than threaded through `opts`, so no caller can forget it. That is the right shape for the fix, and it holds: reverting the `transcript_header_end` fallback turns both `entity_range_spec` "floors an unparsed transcript from its own shape" and `entity_textobj_spec` "floors a transcript that parley classifies as markdown" red.
- **`tests/unit/entity_range_spec.lua`** — 34 assertions over literal line arrays, zero mocks, no buffer, including a property sweep asserting no inverted or out-of-range result on malformed transcripts. This is genuine ARCH-PURE, not a claim.
- **`tests/integration/entity_textobj_spec.lua:192-217`** — the streaming-refusal test BR-3 asked for is a *real* pin, not a ticked box: I `pcall`-wrapped `replace_user_lines` in a scratch copy and the test went red. The test's own comment scopes its substitution honestly.
- **`lua/parley/init.lua:4534-4539`** — collapsing both surfaces onto one `entity_textobj.parsed_for` is the right structural answer to BR-2; verified by execution as above.
- **`lua/parley/starter_config.lua:25-35`** — the `object_only` carve-out is narrow, and `tests/unit/starter_config_spec.lua` pins it with a *negative* test (`resolve_ref_gf` still excluded), so the fix cannot silently widen the app's key policy.
- **Honest accounting throughout.** `atlas/chat/entity_delete.md:81-92` records the missed ARCH-CONSTRAINTS budget with both measurement runs, the operator's basis, the escape hatch, *and* that no spec guards the numbers plus how to re-derive them. Every suite-state claim in `## Log` checks out: `parley_harness_golden_spec` fails 11/11 at the branch base too (I ran it there), and `perf_document_spec` passes serially.

## 2. Critical findings

None. Both prior Criticals are verified fixed by revert-and-measure.

## 3. Important findings

**I-1 · `lua/parley/chat_parser.lua:75-85` — `transcript_header_end` validates only line 1, then hands the terminator search to an unbounded scan.**
The docstring claims it is the strict sibling that won't floor "a thematic break in a genuine markdown note", but the strictness applies only to the first line. Once line 1 matches `^#%s*topic:`, `find_header_end`'s legacy branch returns the first `---` *anywhere in the file*. Reproduced:

```
note = { "# topic: how to cook", "", "Intro paragraph.", "", "## Step one",
         "prep", "", "---", "", "## Step two", "cook" }
transcript_header_end(note) = 8   →  floor = 9
  row 1 -> nil    row 3 -> nil    row 5 -> nil    row 6 -> nil
  row 10 -> section 10..11
```

`dae` is a dead no-op over lines 1–8, including two real sections and a paragraph. The same shape hits a transcript whose `---` was edited away and is markdown-classified: the floor lands on a `---` inside a fenced block and everything above it goes dead. It fails *closed* (nil, no data loss), which is why this is Important and not Critical. Fix: require the terminator to close a contiguous run of header-shaped lines (`# topic:` / `- key: value` / blank) — the shape `parse_chat_headers` already knows — instead of delegating to the unbounded scan. Secondary ARCH-DRY note at the same site: `^#%s*topic:` is a third place that hardcodes what a transcript header's first line looks like.

**I-2 · `tests/unit/entity_range_spec.lua` — the test for that property pins the weaker claim.** "does not floor a thematic break in a genuine markdown note" uses `{ "# My Note", "prose", "---", "more prose" }`. Line 1 is not topic-shaped, so the test exercises the early-return and never reaches the scan. It reads as if it pins the stated property; it pins only half of it. Add the `# topic: …`-titled note above.

**I-3 · BR-2 has no regression test — REPEAT of family `parity-varies-only-cursor` (2nd finding).**

> **This is the 2nd finding in family `parity-varies-only-cursor`.** Earlier rounds fixed instances. Do NOT fix this instance — state the rule that covers all of them, and fix that.

The rule: **a parity spec must vary every axis along which the two surfaces could disagree, and each axis must be demonstrated to fail when the corresponding fix is removed.** The measured prevalence is 2/2 — round 2 added the classification axis and it still cannot see the shape axis. Evidence: I reverted the BR-2 fix in a git-backed scratch copy and all five parity tests plus all 15 `entity_textobj_spec` tests stayed green, while a direct probe on the same tree showed the surfaces diverging 15 lines → 8. The enumeration the rule implies, for this spec: (a) cursor row — done; (b) buffer classification, chat vs markdown filename — done; (c) document shape, `---` removed and `- file:` removed — **missing**, and (c) is where BR-2 lived. Write the enumeration into the spec as a comment so the next axis is added rather than rediscovered, and adopt the discipline that a fix landing without a red-without-it test is not landed.

## 4. Minor findings

- **`lua/parley/entity_range.lua:91-93`** — `section_range`'s `floor` parameter is still dead. `M.range:215-217` already returns nil for `row < floor` before the call at `:234`, and the `to_end` back-scan at `:262` omits the argument while its loop bound guarantees `i >= floor`. Drop it or make it the enforcement point.
- **`README.md:16-20`** — still documents `dae`/`daE`/`yae`/`cae` only; `ie`, `<C-g>k` and `<C-g>K` remain undocumented user-typed surface. `atlas/ui/keybindings.md:26-31` has the full set.
- **`workshop/plans/…-plan.md:86` and `:937`** — both still describe `DeleteEntity` as using "`ExchangeCut`'s preamble verbatim (`init.lua:4423-4436`)", which is the implementation BR-2 *removed*. REPEAT of `plan-table-understates-code` (2nd). The rule: **a `## Revisions` entry recording a delta must be applied to the plan body it contradicts in the same edit** — Revisions is a changelog, not a patch the reader is expected to apply mentally. BR-7 was this same rule on the Core-concepts table; this is it on Task 11 Step 3 and the Integration-points bullet.
- The gate pinned `base == head`, so the machine-read window contained zero changes. Worth checking before the next boundary — a gate that reviews an empty range passes silently.

## 5. Test coverage notes

Everything green except two documented pre-existing failures, both of which I verified rather than accepted: `parley_harness_golden_spec` fails 11/11 at the branch base too, and `perf_document_spec` fails only under the 8-way parallel target and passes serially (5/5). `make lint`: 0 warnings / 0 errors in 624 files. I also confirmed the parity spec's `markdown-classified` axis is not vacuous — a probe shows `latch=markdown`, `ae`/`ie`/`aE` installed via `setup_markdown_keymaps`, and 8 of 24 rows mutating the buffer under both surfaces. The gap is the shape axis (I-3) and the `transcript_header_end` case (I-2).

One harness observation, out of window but worth knowing: the parity spec silently truncates after two tests, with exit 0 and no failure line, when run outside a git repository. It is not specific to this diff, but it is a green run that reports nothing.

## 6. Architectural notes

- **ARCH-DRY — pass**, one flag folded into I-1. One heading dialect consumed by both `outline` paths and pinned to `document/lexical.lua` by a 20-line conformance corpus; one exchange-span definition; one classifier now shared by both surfaces. `exporter.lua:539-541` still maps `##`/`###` independently, correctly recorded as pre-existing and out of scope.
- **ARCH-PURE — pass.** All dispatch, bounds, blank and 📝 policy are functions over `(parsed, lines, row)`; the unit specs run with no buffer and no mocks. The IO shell is 30 lines in each surface.
- **ARCH-PURPOSE — flag (I-3).** The feature itself is fully delivered, not the easy subset: three objects, two hotkeys, two commands, both buffer types, the app profile. But BR-4 named a class and the round delivered one axis of it; that is the instance, not the class, and it is the second time on this issue.
- **ARCH-MOCK — pass.** No external binary or service; Neovim is exercised for real (real files, real folds, real undo). The one stub is scoped and verified to be a real pin.
- **ARCH-CONSTRAINTS — pass, deviation accepted openly.** Budget declared, missed at 24.7 ms, recorded with both runs and the operator's basis rather than restated. `structural_prefixes()` rebuilds per `M.range` call, which is per-operator, not per-keystroke — inside the envelope.
- **ARCH-SECURE — pass.** No secrets. `M.range` type-checks `lines` and range-checks `row`, and the property sweep plus the guard at `:274` pin that malformed input yields `nil` rather than a fabricated range. I-1 fails closed, which is the right direction.
- **ARCH-ORDER — pass.** No state carried between events; every call re-derives from its arguments. The one unblockable ordering — a stream landing mid-edit — is declared in Done-when, the plan, the parity spec's scope comment, and `atlas/chat/entity_delete.md:93-95`, and is now tested and verified. `entity_textobj.select:73-79` restores `foldenable` before re-raising, so the error path does not strand the option. I-3 is this entry's "tests that observe one interleaving" flag mapped onto the shape axis.
- **ARCH-FUNERAL — pass.** Creates nothing durable; the only new things are buffer-local keymaps, ended by the existing `_parley_bufs` lifecycle (`highlighter.lua:1228`).

## 7. Plan revision recommendations

- **`## Revisions` entry — correct the `transcript_header_end` claim.** The round-2 entry calls it "a strict sibling of `find_header_end`, which returns the first `---` anywhere and would have floored a thematic break in a genuine note." It is strict only about line 1 and then calls that same unbounded scan; a note titled `# topic: …` is floored at its thematic break. Record the actual property and the residual case.
- **Task 11 Step 3 and the Integration-points bullet — update the body, not just Revisions** (per the Minor above).

```findings
dispose:
  - id: BR-1
    disposition: addressed
    note: |
      Verified by revert: dropping the transcript_header_end fallback at entity_range.lua:211-213 turns two tests red.
  - id: BR-2
    disposition: not-addressed
    note: |
      Code verified correct by execution (HEAD refuses; reverted, the command takes 15 lines to 8 while dae is a no-op) but NO test fails without it - the whole suite stayed green on the reverted tree.
  - id: BR-3
    disposition: addressed
    note: |
      Real pin: pcall-wrapping replace_user_lines in a scratch copy turns the refusal test red.
  - id: BR-4
    disposition: not-addressed
    note: |
      The new axis varies filename/classification, not document shape; the --- removed and `- file:` removed shapes are absent, and that is exactly where BR-2 lived.
  - id: BR-5
    disposition: not-addressed
    note: |
      section_range's floor guard at entity_range.lua:91-93 is still unreachable; the second call site at :262 still omits the argument.
  - id: BR-6
    disposition: addressed
    note: |
      One shared parsed_for means one parse site and one pcall; the two message strings remain but each names its own surface, matching ExchangeCut/ExchangePaste convention.
  - id: BR-7
    disposition: addressed
    note: |
      plan.md:43 now reads `lua/parley/outline.lua:52-60` **and `:254`**, and both paths are changed in the diff.
  - id: BR-8
    disposition: not-addressed
    note: |
      README.md:16-20 is unchanged since round 2 - still no ie, <C-g>k or <C-g>K.
  - id: BR-9
    disposition: addressed
    note: |
      atlas/chat/entity_delete.md:89-92 now states no spec guards the numbers and names the re-derivation recipe; tests/perf/chat_typing.lua:13 build_fixture verified to exist.
findings:
  - id: new
    severity: Important
    family: partial-shape-test
    title: |
      transcript_header_end validates only line 1, then delegates to an unbounded find_header_end scan
    detail: |
      chat_parser.lua:79-84 gates on `^#%s*topic:` and then returns the first `---` anywhere in the file.
      Reproduced: for a genuine note `{ "# topic: how to cook", "", "Intro paragraph.", "", "## Step one",
      "prep", "", "---", "", "## Step two", "cook" }` it returns 8, so the floor is 9 and range() returns nil
      for rows 1-8 - dae is silently dead over two real sections and a paragraph. Same shape hits a transcript
      whose --- was edited away. Fails closed (no data loss), hence Important. Fix: require the terminator to
      close a contiguous run of header-shaped lines, the shape parse_chat_headers already knows. ARCH-DRY note
      at the same site: `^#%s*topic:` is a third hardcoding of the transcript first-line shape.
  - id: new
    severity: Important
    family: partial-shape-test
    title: |
      the unit test for that property uses a non-topic-shaped title, so it never reaches the scan
    detail: |
      entity_range_spec "does not floor a thematic break in a genuine markdown note" uses `# My Note`, which
      exits at the line-1 guard. It reads as pinning the stated property but pins only half of it. Add the
      `# topic: ...`-titled fixture.
  - id: new
    severity: Important
    family: parity-varies-only-cursor
    title: |
      REPEAT (2nd) - the parity spec still cannot see the axis BR-2 lived on; state the rule, not the instance
    detail: |
      Measured prevalence 2/2. Evidence: reverting the BR-2 fix in a git-backed scratch left all 5 parity tests
      and all 15 entity_textobj tests green, while a direct probe on that same tree showed the surfaces diverging
      15 lines to 8. RULE - a parity spec must vary every axis along which the two surfaces could disagree, and
      each axis must be demonstrated red-without-its-fix. Enumeration for this spec - (a) cursor row, done;
      (b) classification, done; (c) document shape (--- removed, `- file:` removed), MISSING. Write the
      enumeration into the spec as a comment so the next axis is added rather than rediscovered.
  - id: new
    severity: Minor
    family: plan-table-understates-code
    title: |
      REPEAT (2nd) - plan body still describes the implementation BR-2 removed
    detail: |
      plan.md:86 and :937 both say DeleteEntity uses "ExchangeCut's preamble verbatim (init.lua:4423-4436)";
      the code now uses entity_textobj.parsed_for. The Revisions entry records the delta but the body was not
      updated - the same pattern as BR-7 on the Core-concepts table. RULE - a Revisions entry recording a delta
      must be applied to the plan body it contradicts in the same edit.
  - id: new
    severity: Minor
    family: empty-review-window
    title: |
      the gate pinned base == head, so the machine-read review window contained zero changes
    detail: |
      Both required recipes exit 0 with no output. Reviewed the tree at HEAD and 85e116c2..HEAD instead. Worth
      checking before the next boundary - a gate that reviews an empty range passes silently.
```

---

## Re-review — 2026-09-16T14:51:59-07:00 (FIX-THEN-SHIP)

| field | value |
|-------|-------|
| issue | 262 — Delete entity at cursor — markdown section, paragraph, or chat question |
| repo | parley.nvim |
| issue file | workshop/issues/000262-delete-entity-at-cursor.md |
| boundary | milestone M1 |
| milestone | M1 |
| window | aa001961ae1584d248ba39e9dabcb6c5d81bf1f0..9b8a3ce4c805a5ab78f210377609cf023dae260a |
| command | sdlc milestone-close --issue 262 --milestone M1 |
| reviewer | claude |
| timestamp | 2026-09-16T14:51:59-07:00 |
| verdict | FIX-THEN-SHIP |

## Review

```verdict
verdict: FIX-THEN-SHIP
confidence: high
```

Both round-3 fixes are real and I verified each by revert-and-measure rather than by reading commit prose: reverting the contiguous-run rule in a scratch worktree turns `entity_range_spec` "does not floor a note whose title happens to look like a header" red (1 Fail), and reverting the BR-2 classifier collapse turns the two new `separator-edited-away` parity tests red with exactly the divergence BR-2 named (`surfaces diverge at row 1`). The parity spec now carries the stated RULE and a written axis enumeration, which is the right answer to a 2nd-repeat family. What stops a clean SHIP is that the new strictness went the wrong way for Parley's own artifacts: `transcript_header_end` rejects the header that `defaults.chat_template` writes (four prose lines inside the front matter, plus an escaped `system\_prompt:` key), so a long-template transcript opened markdown-classified has **no floor at all** and `dae` on line 1 takes the header and the first question — the BR-1 failure mode, surviving for a header shape the plugin ships. Four prior findings (BR-5, BR-8, BR-13, BR-14) are untouched by this window and re-dispose as `not-addressed`.

## 1. Strengths

- **`tests/integration/entity_delete_parity_spec.lua:48-62`** — the axis enumeration is written into the spec as a comment with (a)–(e) and an explicit justification for why in-flight generation is *not* an axis. That is the rule, not the instance, and it makes the next axis an addition rather than a rediscovery. Exactly what BR-12 asked for.
- **`tests/integration/entity_delete_parity_spec.lua:80-85`** — the `edit = 3` shape (header mutilated *in the buffer, after classification*) is the insight the on-disk `drop` shapes could not reach, and the implementor found it themselves: mutilating on disk re-classifies the buffer before either surface sees it. Verified red without its fix.
- **`lua/parley/chat_parser.lua:64-75, 88`** — reusing `parse_header_key_value` for the shape test instead of adding a fourth `^#%s*topic:` hardcoding. I swept `lua/` for the pattern: the hardcoding BR-10 named is gone from this path (ARCH-DRY).
- **`tests/unit/entity_range_spec.lua:336-363`** — the replacement fixture is genuinely title-shaped (`# topic: how to cook`), so it reaches the terminator scan rather than exiting at the line-1 guard, and the companion "still floors a real transcript header" pins both the legacy and front-matter positives.
- **Repo-wide measurement holds.** I ran `transcript_header_end` over all 384 chat-shaped tracked `.md` files: 321 agree with `find_header_end`, and every no-floor case is a `workshop/**/plans/*-gate.md` YAML front-matter artifact — **no real transcript in the tree loses its floor**.

## 2. Critical findings

None.

## 3. Important findings

**I-1 · `lua/parley/chat_parser.lua:93-110` — the new shape test rejects the header Parley's own `defaults.chat_template` writes. This is the 3rd finding in family `guard-gated-on-classification`; do not fix this instance — write the enumeration.**

Measured prevalence 3/3 (BR-1 gated on `not_chat`; BR-2 gated on a diverging latch; this one gated on a key-shape predicate). **The rule:** *the header floor must accept every header shape Parley itself can write. Its predicate is not free to be stricter than the writer.* The enumeration that rule implies, and that no test contains today:

| source | shape | `transcript_header_end` today |
|---|---|---|
| `defaults.short_chat_template` (`defaults.lua:89-97`) | front matter, all `key: value` | ✅ 5 |
| `defaults.chat_template` (`defaults.lua:74-87`) | front matter **+ `{{optional_headers}}` + 4 prose lines** | ❌ **nil** |
| legacy `# topic:` / `- file:` / `---` | ✅ 3 |
| front matter written by `init.lua:3922` with any system prompt | `system\_prompt:` after the `_`→`\_` escape at `init.lua:3933` | ❌ **nil** |

Reproduced against the shipped template body:

```
transcript_header_end(long_template_chat) = nil   find_header_end = 10
  entity_range.range(nil, lines, 1) -> paragraph 1..11   (of 14 lines)
```

`dae` on line 1 of such a transcript, opened markdown-classified (`_parley_bufs[buf] ~= "chat"` — the BR-1 scenario), deletes the whole header **and** `💬: hello`. Two independent disqualifiers: `defaults.lua:80-83` are prose inside the front matter, and `system_prompts["default"]` always exists (`config.lua:226-230`) so `{{optional_headers}}` always renders a `system_prompt:` line, which `init.lua:3933`'s blanket `gsub("_", "\\_")` turns into `system\_prompt:` — a key `^([%w_%.%+]+):` cannot match. Fix the rule with a conformance test that renders *every* template in `defaults.lua` through the real renderer and asserts `transcript_header_end ~= nil` for each, so a new template shape fails the suite instead of silently removing the floor. The same enumeration's negative side is also wrong today and belongs in the same test: `{ "# Recipe: soup", "", "---", "", "## Two", "y" }` yields `3`, so rows 1–3 of a genuine note are silently undeletable.

**I-2 (BR-8, re-disposed `not-addressed`) · `README.md:16-20`** — unchanged in this window. Still documents `dae`/`daE`/`yae`/`cae` only; `ie`, `<C-g>k`, `<C-g>K`, `:ParleyDeleteEntity` and `:ParleyDeleteToEnd` are user-typed surface introduced in this issue and appear only in `atlas/ui/keybindings.md:29-33`.

## 4. Minor findings

- **`lua/parley/chat_parser.lua:106`** — `for i = (front_matter and 2 or 2), #lines` is a ternary whose branches are identical. **2nd finding in family `unreachable-guard`** (BR-5 is the 1st and still open). The rule: *a parameter or branch that cannot change the outcome is deleted, not documented.* The enumeration is two sites — this ternary, and `entity_range.lua:86,91-93`'s `floor` parameter, which the row guard at `:214-216` and the floor-anchored back-scan at `:262` already make unreachable, and which the second call site at `:265` omits.
- **`tests/integration/entity_delete_parity_spec.lua:165-169`** — for the `no-separator` and `separator-edited-away` shapes the header test's else-branch asserts `s.drop == 3 or s.edit == 3`, a tautology over the spec's own `SHAPES` literal. **3rd in family `partial-shape-test`.** The rule: *a branch a test takes must assert something about the code, not about the fixture that selected it.* The true, cheap assertion is available and I confirmed it holds: with no `---`, `parsed_for` returns `"unparsable"` and **both** surfaces leave the buffer byte-identical — assert that instead.
- **`atlas/chat/entity_delete.md:41-53`** — the new paragraph swallowed the following one; "In a plain markdown buffer there is no exchange kind…" is now glued to the end of a long line instead of standing as its own paragraph.
- **`atlas/chat/entity_delete.md:37`** — "a transcript header line (at or above the `---`) | nothing" now overstates: after this change that only holds when the `---` closes a contiguous header run.
- **`workshop/plans/000262-delete-entity-at-cursor-plan.md:1049+`** — round 3 added no `## Revisions` entry at all, though it changed rule 6's predicate.

## 5. Test coverage notes

- Suite green at HEAD: `entity_delete_parity_spec` 11/11, `entity_textobj_spec` 15/15, `entity_range_spec` 36/36, both `markdown_heading` specs.
- Both claimed fixes carry genuine regression evidence — I reverted each independently in a `git worktree` scratch and watched the named tests go red (1 Fail for the header rule, 2 Fails for the classifier collapse). No claimed fix in this window is unprotected.
- The gap: there is **no positive-side conformance test** tying `transcript_header_end` to the templates in `defaults.lua`. That is precisely the test that would be red today (I-1), and it is the class of bug this diff shipped.

## 6. Architectural notes

- **ARCH-DRY** — pass on the point BR-10 raised (`parse_header_key_value` is now the single shape definition and the `^#%s*topic:` hardcoding is gone from this path). Minor note: `find_header_end` and `transcript_header_end` now run two near-identical front-matter/legacy terminator walks; one parameterised walk would state the dichotomy once.
- **ARCH-PURE** — pass. `transcript_header_end` and `entity_range` are pure over line arrays; the new unit tests run with zero mocks and no buffer. The parity spec's IO (real buffers, real folds) is deliberate and belongs at that layer.
- **ARCH-PURPOSE** — **flag (I-1).** The shadow-sweep over "what counts as a Parley header" enumerates four writers; two of them the new predicate rejects. The fix answered the *instance* BR-10 named (a note with prose above a thematic break) and did not sweep the class (every shape the writer emits).
- **ARCH-MOCK** — `N/A`, correctly. No external binary or service; Neovim is exercised for real through `Document.attach(buf, { schedule = false })`.
- **ARCH-CONSTRAINTS** — pass for this window. The missed budget stays recorded with both measurement runs, the operator's basis, the escape hatch, and re-derivation instructions at `atlas/chat/entity_delete.md:99-110`. The new scan is O(header length), not O(file), so it adds nothing to the keystroke path.
- **ARCH-SECURE** — pass. `transcript_header_end` parses untrusted buffer text and fails closed to `nil` on every malformed shape; no credential, subprocess or fabricated substitution. The one soft spot is that failing closed here means *removing* a protection rather than adding one — which is what I-1 is.
- **ARCH-ORDER** — pass. The `edit = 3` shape is the real contribution here: it models the state *between* events (classified as chat, then edited into unparsability) rather than a single-shot parse, and both surfaces now read one latch. The documented asymmetry during generation is scoped and justified at `entity_delete_parity_spec.lua:5-8`.
- **ARCH-FUNERAL** — `N/A`: this window creates nothing durable. The only new artifacts are the two gate-ledger sections appended to existing `workshop/plans/*-review.md` / `*-close-gate.md` files, which are archived with the issue.

## 7. Plan revision recommendations

1. `## Revisions` — **2026-09-16 — M1 review round 3.** Rule 6's floor predicate changed: the terminator must now close a *contiguous run of header-shaped lines* (`parse_header_key_value`'s definition), not just be the first `---` below a transcript-shaped title. Record the consequence the code has and the plan does not: a document whose `---` is gone has *no* floor, and ordinary markdown rules are the contract there.
2. Apply that same entry to the body (BR-13's rule): **plan line 86** and **line 937** both still say `M.cmd.DeleteEntity` uses "`ExchangeCut`'s preamble (`init.lua:4423-4436`)". The code at `init.lua:4529-4540` uses `entity_textobj.parsed_for`. Round 2's Revisions entry records that delta; the body it contradicts was never edited.
3. `## Revisions` — record the I-1 enumeration (every `defaults.lua` template must satisfy `transcript_header_end`) as the *rule* the family escalation demands, so the next template addition is covered rather than rediscovered.

```findings
dispose:
  - id: BR-2
    disposition: addressed
    note: |
      init.lua:4529-4540 routes both surfaces through entity_textobj.parsed_for; reverting it in a scratch worktree turned the two separator-edited-away parity tests red ("surfaces diverge at row 1").
  - id: BR-4
    disposition: addressed
    note: |
      SHAPES now has five entries varying document shape on disk and in-buffer; content_for() sizes each sweep correctly.
  - id: BR-5
    disposition: not-addressed
    note: |
      entity_range.lua is not in this window at all; the floor parameter at :86/:91-93 is still unreachable and the :265 call site still omits it.
  - id: BR-8
    disposition: not-addressed
    note: |
      README.md unchanged in this window; ie, <C-g>k, <C-g>K and the two :ParleyDelete* commands are still undocumented there.
  - id: BR-10
    disposition: addressed
    note: |
      The BR-10 fixture now yields nil and rows 1/3/5/10 stay editable; the ^#%s*topic: hardcoding is gone. A sibling gap on the positive side is raised new as I-1.
  - id: BR-11
    disposition: addressed
    note: |
      The new title-shaped fixture reaches the terminator scan - verified red without the contiguous-run change (1 Fail in a scratch worktree).
  - id: BR-12
    disposition: addressed
    note: |
      The rule and the (a)-(e) axis enumeration are written into the spec at :48-62, and the new axis was demonstrated red without its fix.
  - id: BR-13
    disposition: not-addressed
    note: |
      plan.md:86 and :937 still say "ExchangeCut's preamble (init.lua:4423-4436)"; round 3 also added no Revisions entry for the contiguous-run change.
  - id: BR-14
    disposition: not-addressed
    note: |
      Window is non-empty now, but base aa001961 IS the fix commit for BR-1/BR-2/BR-6/BR-7/BR-9, so its content sits in the base tree and those dispositions again had to be verified from the tree rather than the diff.
findings:
  - id: new
    severity: Important
    family: guard-gated-on-classification
    title: |
      transcript_header_end rejects the header defaults.chat_template writes, so a long-template transcript has no floor at all
    detail: |
      3rd finding in this family (prevalence 3/3), so do NOT fix the instance - state the rule and write its enumeration. THE RULE - the header floor must accept every header shape Parley itself can write; its predicate may not be stricter than its writer. Measured - transcript_header_end(long_template_chat) = nil, and entity_range.range(nil, lines, 1) then returns paragraph 1..11 of 14, taking the header AND the first question on one dae in a markdown-classified buffer (the BR-1 scenario). Two independent disqualifiers - defaults.lua:80-83 are prose lines inside the front matter, and init.lua:3933's blanket gsub("_", "\\_") turns the always-present system_prompt key (config.lua:226-230) into system\_prompt, which ^([%w_%.%+]+): cannot match. The enumeration - short_chat_template (passes), chat_template (fails), legacy topic/file/--- (passes), any rendered front matter carrying optional_headers (fails). Fix - a conformance test rendering every defaults.lua template through the real renderer and asserting a non-nil terminator, so a new template shape fails the suite instead of silently removing the floor. Its negative side belongs in the same test - transcript_header_end({"\# Recipe: soup", "", "---", "", "\#\# Two", "y"}) returns 3, so rows 1-3 of a genuine note are undeletable.
  - id: new
    severity: Minor
    family: unreachable-guard
    title: |
      chat_parser.lua:106 - a ternary whose two branches are both 2
    detail: |
      2nd finding in this family (BR-5 is the 1st and still open). THE RULE - a parameter or branch that cannot change the outcome is deleted, not documented. Enumeration - chat_parser.lua:106 `(front_matter and 2 or 2)`, and entity_range.lua:86/:91-93's floor parameter, unreachable because the row guard at :214-216 already returns nil and the only other call site (:265) omits it.
  - id: new
    severity: Minor
    family: partial-shape-test
    title: |
      the header-protection test's else-branch asserts a property of its own SHAPES literal, not of the code
    detail: |
      3rd in this family. entity_delete_parity_spec.lua:165-169 falls into an else-branch for the two shapes with no `---` and asserts `s.drop == 3 or s.edit == 3` - a tautology over the fixture table. THE RULE - a branch a test takes must assert something about the code, not about the fixture that selected it. The true assertion is available and holds - with no separator parsed_for returns "unparsable" and both surfaces leave the buffer byte-identical.
  - id: new
    severity: Minor
    family: docs-edit-mangles-prose
    title: |
      the atlas insert swallowed the following paragraph and left the header table overstated
    detail: |
      atlas/chat/entity_delete.md:41-53 - "In a plain markdown buffer there is no exchange kind..." is now glued onto the end of an over-long line instead of standing as its own paragraph. Separately :37 still says a header line is "at or above the ---" without the new contiguous-run qualifier.
```
