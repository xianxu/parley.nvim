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
