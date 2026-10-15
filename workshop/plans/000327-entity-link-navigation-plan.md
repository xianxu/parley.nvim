# Enclosing-Entity Link Navigation Implementation Plan

> **For agentic workers:** Consult AGENTS.md Section 3 (Subagent Strategy) to determine the appropriate execution approach: use superpowers-subagent-driven-development (if subagents are suitable per AGENTS.md) or superpowers-executing-plans to implement this plan. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Alt+o follows the sole link/reference in the current entity, or lets the operator choose among several, after direct-reference handling finds no match.

**Architecture:** Add a navigation entry to the existing pure entity-range module, keeping delete/text-object behavior stable. Consolidate reusable reference enumeration in one pure module and delegate selected occurrences to the existing opening/resolution chain. Keep buffer snapshots, picker UI and mode restoration in the editor boundary.

**Tech Stack:** Lua, Neovim, existing entity_range/markdown_heading/artifact_ref parsers, vim.ui.select, Plenary, existing filesystem-backed fake_sdlc.

## Core concepts

| Name | Kind | Lives in | Status |
|---|---|---|---|
| Navigation entity range | PURE | lua/parley/entity_range.lua navigation_range | New entry; existing range behavior retained |
| Reference occurrences | PURE | lua/parley/reference_candidates.lua | New; canonical Markdown/closed-@@/branch enumeration plus artifact_ref.iter_refs reuse |
| Picker completion model | PURE | lua/parley/reference_candidates.lua begin_selection/finish_selection | New; pending to settled, one open at most |
| Markdown cursor link parser | PURE | lua/parley/issues.lua parse_md_link_at_cursor | Modified to derive from shared Markdown occurrences |
| Legacy @@/branch parsers | PURE | lua/parley/init.lua _parse_at_reference/_parse_branch_ref | Modified to derive from canonical occurrence helpers; public behavior pinned |
| Alt+o editor boundary | INTEGRATION | lua/parley/init.lua OpenFileUnderCursor | Modified; snapshots buffer, shows picker, reuses existing openers and resolver |

The navigation range owns numbered-item containment; it is not another parser inside the command. Existing entity_range.range remains the source for heading/paragraph behavior and existing text-object/delete users. Reference occurrences hold row and byte spans, not resolved filesystem objects. Selecting one occurrence may use current IO helpers; enumerating never opens files or runs sdlc. The picker model receives plain origin/current snapshots, with no Vim calls.

## Product decisions

- Existing direct Parley references keep their behavior. A directly under-cursor artifact ref is checked with artifact_ref.parse_ref_at_cursor before entity lookup, so an enclosing answer link cannot steal an issue jump.
- Heading selection means the heading row owns its section through the next real heading of equal/higher rank, including deeper subsections, as entity_range already defines.
- Numbered items use column-zero `^%d+%.%s`, matching ops opinstr.py. Duplicate numbers are valid boundaries. Continuation lines and interior blank lines belong; trailing blanks do not. The next numbered anchor or real heading ends the item. Indented nested items are content of the outer item.
- Ignore numbered anchors/headings/links inside fenced code. Reuse the existing fence memo and chat exchange/header bounds, rather than recognizing structural markers independently.
- Anywhere inside a numbered item uses that item first. Otherwise use the current entity_range behavior (heading on heading row, paragraph on body text); do not expand all body prose to its parent section.
- Count reference occurrences, preserving document order. A Markdown link is one occurrence even when its label/destination contains another reference spelling. Repeated links to the same target still count as multiple occurrences.
- One occurrence opens immediately; several use vim.ui.select with label/target and source row; none preserves sdlc-resolve then gf. Cancellation is a no-op.
- Reuse current destination policy, including missing-target diagnostics, relative resolution, src/branch/@@ handling, artifact resolution, and fallback for other Markdown destinations. This issue does not change URL/fragment parsing or fix #323.
- Navigation remains explicit Alt+o; no new autocmd, key binding, setting, timer or watcher.

## Interfaces and decisions

### Range

`entity_range.navigation_range(parsed, lines, row, opts)` returns `{kind, first, last}` or nil, using 1-based inclusive rows. First find a containing top-level numbered item within the current header/exchange bounds and outside code. Trim its trailing blanks. If none contains row, delegate to existing entity range. Share private boundary/fence context with range when necessary; run the complete existing range/delete parity suite to pin behavior.

Example: `{'1. question', '', 'continued → [answer](qa/a.md)', '', '1. next'}` has numbered range `[1,3]` for rows 1–3; row 4 is outside it.

### Occurrences

`reference_candidates.markdown_links(line)` returns the same `{text,url,start_col,end_col}` records the current issues parser recognizes, in byte order. `parse_md_link_at_cursor` searches this list; no duplicate Markdown regex remains in issues.lua.

`at_references(line)` returns closed canonical @@ spans/content; the legacy closest-reference function derives its old distance behavior from these spans. `branch_ref(line,prefix)` contains the old branch-line parser logic with explicit prefix. Keep whole-line @@ legacy forms through the existing opener.

`collect(lines, range, opts)` returns `{kind,row,col,end_col,label,target,fallback_col}` occurrences. `col` is zero-based and points inside the recognized span; `fallback_col` points at the destination for the existing gf fallback when needed. Recognize Markdown links first, then nonoverlapping @@/branch/artifact references using the canonical helpers and artifact_ref.iter_refs. Fence masking comes from the same lexical memo as range construction. No target existence or external resolution during collection.

### Picker completion

State: `{tag='pending',origin={buf,win,tick,generation},items}` or `{tag='settled'}`. The editor owns one monotonically increasing command generation (constant-space scalar), invalidating older invocations.

`begin_selection(origin,items)` returns pending state. `finish_selection(state,event)` returns new state and an effect `{kind='open',item}` or `{kind='none'}`. Event contains the selected index (nil for cancel) and a plain current origin snapshot.

| State/event | Next state | Effect |
|---|---|---|
| pending + valid index, same buffer/window/tick/generation | settled | open that occurrence once |
| pending + cancel, changed/deleted origin, stale generation, invalid index | settled | none |
| settled + any later callback | settled | none |

Only the transition function changes this model. Test duplicate, cancellation, edit, window/buffer switch, deletion and superseded-callback sequences directly. Source edits while the picker is open invalidate the snapshot; no stale link is opened. No callback keeps a global per-buffer table.

### Editor chain and mode

1. Run the existing open_reference_under_cursor chain; opened/failed remain terminal.
2. If none, detect a direct artifact reference and retain the current resolver/gf branch for it.
3. Otherwise capture one buffer snapshot, obtain navigation_range and collect occurrences.
4. None: unchanged resolver/gf fallback at the original cursor.
5. One: dispatch the selected kind/span/target, never replay the whole source line through legacy nearest/leading-reference selection. Markdown passes only its selected span through existing link openers; @@ passes only its selected closed span through the existing path opener; branch passes its selected branch line. Artifact goes directly to the artifact opener. Unhandled Markdown falls through at its destination column. Do not recursively invoke entity discovery.
6. Several: show picker and return pending. Apply the pure completion model before any opening effect.
7. Restore Insert mode only after a handled candidate completes, not while a picker is open. Cancellation restores the prior mode only if the original active source still matches. Native resolver/gf retains its existing normal-mode landing behavior.

All selected paths still pass through existing expand_path/backtick refusal and argument-safe resolver seams. For failed selection opening, preserve the source cursor when no navigation occurred. No failure on a recognized local link falls through to a second unrelated target. The selection snapshot remains authoritative through asynchronous resolution: artifact_ref.goto_ref_at_cursor accepts an optional is_current predicate, checks it before scheduled result dispatch and immediately before family-picker opening effects, and settles the family callback once. Entity-selected resolution supplies the source buffer/window/changedtick/generation predicate; direct legacy commands retain their existing behavior when no predicate is supplied. Controlled delayed resolver/family-picker tests assert no open after origin invalidation.

## Architecture and operating envelope

- ARCH-DRY: entity_range/markdown_heading/fence memo own structural boundaries; one occurrence scanner owns Markdown/@@/branch syntax; artifact_ref owns artifact shapes; existing opening helpers own IO.
- ARCH-PURE: rows/spans, occurrence choice and completion decisions consume values only. Editor state and file/process/UI effects remain at the integration boundary.
- ARCH-PURPOSE: cover every row of multi-line bullets, headings, ambiguity, direct priority and unchanged zero-result fallback; no heading-only subset.
- ARCH-MOCK: no new external dependency. Resolver integration reuses tests/fixtures/fake_sdlc and temporary files. Picker tests retain a selection callback and controllably deliver choices/cancel/late results; a real headless input smoke and operator stage check cover wiring.
- ARCH-CONSTRAINTS: explicit command path, not per keystroke. One line snapshot and linear scans in buffer/entity text; memory proportional to snapshot and occurrences. Resolve/open only the chosen occurrence; no subprocess per candidate, network fan-out, caches or synchronous file-tree scan. Exercise a 5,000-line fixture to pin one enumeration/open behavior without wall-time assertions.
- ARCH-SECURE: Markdown is operator/agent-authored untrusted text. Parse malformed/truncated spans to no candidate; never eval/interpolate destinations as shell code. Existing refusal and argv helpers remain in every opening path; temp tests cannot reach real user files.
- ARCH-ORDER: pending/settled completion model above handles stale, duplicate and canceled callbacks; no retry of an uncertain open. Entity-selected resolver and secondary family-picker effects revalidate the same origin through an optional artifact_ref predicate. A canceled/invalid entity picker never triggers fallback.
- ARCH-FUNERAL: creates no persistent runtime artifact, timer or watcher. Snapshot/occurrence arrays and callback model die when selection completes/cancels; only the constant-space generation scalar remains. Existing selected-open behavior owns any forward chat creation, as before.

## Execution steps (one atomic close boundary)

### 1. Range and parser ownership

Files: modify lua/parley/entity_range.lua and lua/parley/issues.lua; create lua/parley/reference_candidates.lua; modify the two legacy pure parser wrappers in lua/parley/init.lua. Tests: tests/unit/entity_range_spec.lua, new tests/unit/reference_candidates_spec.lua, existing tests/unit/parse_at_reference_spec.lua and Markdown-link parser tests.

- [x] navigation_range: adversarial item/heading/fence/transcript boundaries, asserting containment and existing editing-range parity over every row.
- [x] markdown_links/at_references/branch_ref/collect: malformed and overlapping reference spans, asserting canonical byte spans, occurrence identity/order and fence exclusion; legacy parser wrappers retain existing characterization tests.
- [x] Run mapped entity/navigation/parser tests red; implement shared pure functions and derive old parser consumers; rerun existing range/text-object/delete parity and cursor-parser tests green.
- [x] Commit the pure ownership change with its tests.

### 2. Opening and picker integration

Files: modify lua/parley/init.lua; extend tests/integration/open_reference_spec.lua; unit-test picker completion in tests/unit/reference_candidates_spec.lua.

- [x] OpenFileUnderCursor: drive enclosing-entity versus direct-reference precedence through real editor state and temporary targets; assert exact selected destination and no forbidden fallback.
- [x] finish_selection: adversarial completion sequences against a value-based origin, asserting at most one effect and none after invalidation. artifact_ref.goto_ref_at_cursor: delay resolution and family selection across origin changes, asserting no stale or duplicate open.
- [x] Integrate the after-direct-reference branch with existing open helpers and resolver; avoid recursion and per-candidate IO. Preserve source-relative paths, missing-target diagnostics and Normal/Insert policy in chat and plain Markdown.
- [x] Run integration tests with the filesystem-backed fake_sdlc and temporary targets. Drive Alt+o with real child-Neovim input for heading and multi-line item. Verify picker cancellation leaves cursor/buffer untouched and no hidden fallback occurs.
- [x] Commit the integrated feature and tests.

### 3. Verification and delivery

Files: atlas/context/file_references.md and atlas/chat/entity_delete.md, atlas/traceability.yaml, README.md, issue Log/Done when. Update these existing indexed atlas files; add no duplicate navigation page.

- [x] Document entity lookup, ambiguity picker and priority in the existing navigation atlas and README; map every new test. Run make -k targeted tests plus luacheck/git diff --check.
- [x] Push PR and run `sdlc local-check run --name suite`; preserve/report every failure, including known packaging intermittency, without ending the remaining test run early.
- [x] Obtain boundary review through sdlc close; fix the complete class of any findings. No separate duplicate review.
- [ ] Obtain hub approval to touch :0 unless already granted, then run sdlc stage --build from this worker slot for the required real-editor Alt+o check. Wait for the operator confirmation through the hub before landing. Then integrate main, land on SHIP, clear stage and report the PR/verified merge hash to the hub.

## Validation commands

Read atlas/traceability.yaml and extend its existing navigation/entity mappings. Run `make -k test-spec SPEC=context/file_references` and `make -k test-spec SPEC=chat/entity_delete`; use a temporary map for a single-file diagnostic rather than changing product mapping to skip tests. Full final run: `sdlc local-check run --name suite`. Lua lint: `luacheck lua/parley/entity_range.lua lua/parley/reference_candidates.lua lua/parley/issues.lua lua/parley/init.lua tests/unit/reference_candidates_spec.lua tests/integration/open_reference_spec.lua`.

Expected: red before new helpers/wiring; green after implementation, unchanged old cursor/reference/entity/delete tests, one resolve/open per selected occurrence, no resolve on canceled or stale selection. A pure decision test must not spawn or mutate editor state.

## Revisions

- 2026-10-14 — initial plan. Navigation-only entity entry chosen over changing the existing entity-range dispatch for all text-object/delete consumers; both are viable, but the latter broadens the editing UX beyond this navigation request. Full flow expected because shared parsing, pure selection logic and editor integration exceed the 100-added-code-line quick shell; no artificial milestone split.

- 2026-10-14 — resumed after #330 and #331 landed. Clarify worker-owned staging and mandatory real-editor acceptance before merge, following the current tl-worker contract. Navigation design is unchanged; approval remains pending.

- 2026-10-15 — plan-quality PQ-1/PQ-2/PQ-3: preserve selected occurrence identity instead of replaying legacy nearest/leading selection, carry optional origin validation through artifact resolution and family selection, and replace prose test inventories with function-level adversarial strategies. Verified the existing resolver had no lifecycle guard; corrected that claim. Product scope and staging/acceptance boundary remain as approved.

- 2026-10-15 — BR-1 class navigation-entity-boundaries: numbered navigation must not inherit paragraph walls. Ordinary Markdown retains all structural-looking continuations; transcript/header-shaped documents additionally stop at canonical user/assistant turns, keeping other annotations as item content. Prefix sweep also found chat-looking fenced samples resetting the plain-Markdown memo. lexical.code_block_memo gains an optional fourth partitioned boolean (nil preserves existing consumers); navigation requests false only for plain Markdown. navigation_range returns the chosen memo as a second result so collection shares it exactly. Range and command tests sweep default/configured prefixes, fenced samples and real transcript protection; editing semantics and transcript memo defaults remain unchanged.

- 2026-10-15 — BR-2 external-dependency-conformance: extend the opt-in maintainer check beyond help discovery to real versus fake resolve argv and consumed files/path/kind/milestone responses, plus missing-reference failure. Use temporary Git repositories and committed vocabulary with no real tracker writes or network. Run after runner/fake changes and before closing such work (ARCH-MOCK). Product behavior and live acceptance sequencing stay unchanged.
