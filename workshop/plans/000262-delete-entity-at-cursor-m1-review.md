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
