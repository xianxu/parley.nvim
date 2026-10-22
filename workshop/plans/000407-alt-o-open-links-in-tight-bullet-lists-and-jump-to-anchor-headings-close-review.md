# Boundary Review — parley.nvim#407 (whole-issue close)

| field | value |
|-------|-------|
| issue | 407 — Alt+O: open links in tight bullet lists, and jump to #anchor headings |
| repo | parley.nvim |
| issue file | workshop/issues/000407-alt-o-open-links-in-tight-bullet-lists-and-jump-to-anchor-headings.md |
| boundary | whole-issue close |
| milestone | — |
| window | 220b67af621c39fce796dc9a901b81d4d33c8d50..97b6fdd13e633765a7eeafe6437f8044d725de6a |
| command | sdlc close --issue 407 |
| reviewer | codex (openai; author openai) |
| isolation | fenced |
| timestamp | 2026-10-21T13:06:20-07:00 |
| verdict | REWORK |

## Review

```verdict
verdict: REWORK
confidence: high
```

The main paths work: tight/loose/nested lists, anchor jumps, unknown-anchor notices, and Normal/Insert mode are covered. The mapped suite passed 415 tests with scratch outside the checkout. Additional read-only probes exposed three correctness gaps: incompatible heading slugs, incorrect fence containment, and bullet ranges that include links outside the item.

```findings
findings:
  - id: new
    severity: Critical
    family: heading-anchor-normalization
    title: |
      GitHub-style anchors fail for whitespace and formatted headings
    detail: |
      lua/parley/markdown_heading.lua:31-35 slugs raw Markdown without trimming heading whitespace or extracting rendered text. Probes return nil for fragment "target" against "# Target ", "# _Target_", "# [Target](file.md)", and "# <em>Target</em>". The whitespace conversion also turns tabs into hyphens rather than removing them. These are all instances in the new normalization pipeline: whitespace trimming/conversion and inline-markup removal. Normalize heading content before slugging, preserve literal underscores appropriately, and add regressions for these cases and their duplicate suffixes. ARCH-PURPOSE: the documented GitHub-style anchor contract is not yet fulfilled.
  - id: new
    severity: Critical
    family: fence-containment
    title: |
      Anchor lookup treats shorter or different fence delimiters as closers
    detail: |
      lua/parley/markdown_heading.lua:28 uses document.lexical.code_block_memo, whose boolean toggle ignores opener character and length. For lines {"````md", "```", "# Fake", "````", "# Real"}, anchor_row returns row 3 for "fake" and nil for "real": it exposes a code example and hides the actual heading. All affected delimiter classes are shorter backtick closers, shorter tilde closers, and mixed backtick/tilde delimiters; the new anchor lookup consumes the shared memo for all of them. Correct the shared fence-state implementation, retaining the existing partition policy, and add regressions for false headings inside and real headings after each case. ARCH-DRY: repair the shared implementation rather than adding an anchor-only fence parser.
  - id: new
    severity: Critical
    family: navigation-item-boundaries
    title: |
      A dedented fenced block lets a bullet absorb an outside paragraph
    detail: |
      lua/parley/entity_range.lua:419-428 skips boundary detection on a fence opener because that row is already marked in_code. For {"- Chosen prose", "", "```md", "sample", "```", "[outside](outside.md)"}, navigation_range at row 1 returns rows 1-6, and reference_candidates.collect returns the outside link as its sole candidate. Alt+O therefore opens a reference outside the selected item. The same probe reproduces with tilde fences; the shared branch affects all three accepted bullet markers (-, +, *). Detect a dedented block boundary before skipping fenced contents, while retaining genuinely indented fences inside items. Add range and mapped navigation regressions for both fence styles. ARCH-PURPOSE: item navigation must remain confined to its enclosing item.
```

1. **Strengths**

   - Navigation changes leave editing ranges on the existing path; a unit assertion pins that separation.
   - File/fragment splitting precedes `.md` validation, and cursor movement checks destination arrival.
   - Native tests exercise real mappings in both Normal and Insert mode, including same-file jumps.
   - README, atlas guidance, and traceability were updated.

2. **Critical findings**

   The three findings above block shipping. Heading normalization differs from [GitHub’s documented section-link rules](https://docs.github.com/en/get-started/writing-on-github/getting-started-with-writing-and-formatting-on-github/basic-writing-and-formatting-syntax#section-links). Fence matching must retain opener character and minimum length, as specified by [GFM](https://github.github.com/gfm/#fenced-code-blocks).

3. **Important findings**

   None separately raised.

4. **Minor findings**

   None.

5. **Test coverage notes**

   `make -k test-spec SPEC=context/file_references TEST_ENV_ROOT=/Volumes/TestScratch/parley-review-407-tests` passed **415 tests**, including all **26 native navigation tests**. `git diff --check` passed.

   The initial run’s in-checkout scratch location caused an unrelated `src:` fixture failure through parent-repository discovery; the external-scratch rerun passed. Current tests omit the three reproduced failure families. No tracked files were modified.

6. **Architectural notes**

   - **ARCH-DRY — flag:** fix fence semantics in the shared helper.
   - **ARCH-PURE — pass:** heading lookup and range decisions remain pure; editor effects stay in the navigation shell.
   - **ARCH-PURPOSE — flag:** anchor compatibility and enclosing-item boundaries remain incomplete.
   - **ARCH-EVOLVE — pass:** no persisted-format reader/writer changes.

7. **Plan revision recommendations**

   Add a `## Revisions` entry reopening verification for heading-content normalization, delimiter-aware fence containment, and dedented-fence item boundaries. Require regressions for each enumerated family before marking those plan items complete again.

<!-- sdlc-review-usage [{"version":1,"intent":{"disposable_root":true,"id":"82ab64a5-f261-4af6-9b8f-6e994ebdd019","repository":"github.com/xianxu/parley.nvim","issue_id":"000407","recipe":"small-diff-review","round":1,"attempt":1,"agent":"codex","root":"/Volumes/TestScratch/review-checkouts/a1538422336d9009","reviewed_head":"97b6fdd13e633765a7eeafe6437f8044d725de6a","slot":"parley.nvim:2","requested_at":"2026-10-21T20:03:01.342784Z"},"phase":"finished","pid":95352,"started_at":"2026-10-21T20:03:01.450449Z","finished_at":"2026-10-21T20:06:19.838619Z","session_id":"01a1600f-5bde-7221-aef6-4347e72104db","outcome":"returned"}] -->

---

## Re-review — 2026-10-21T16:34:57-07:00 (REWORK)

| field | value |
|-------|-------|
| issue | 407 — Alt+O: open links in tight bullet lists, and jump to #anchor headings |
| repo | parley.nvim |
| issue file | workshop/issues/000407-alt-o-open-links-in-tight-bullet-lists-and-jump-to-anchor-headings.md |
| boundary | whole-issue close |
| milestone | — |
| window | 220b67af621c39fce796dc9a901b81d4d33c8d50..2222dd74e8451675e1252eda02b9b433a93ade62 |
| command | sdlc close --issue 407 |
| reviewer | codex (openai; author openai) |
| isolation | fenced |
| timestamp | 2026-10-21T16:34:57-07:00 |
| verdict | REWORK |

## Review

```verdict
verdict: REWORK
confidence: high
```

The mapped suite passes, and regression tests detect removal of the prior repairs. BR-2 and the specific BR-3 fence defect are addressed. Shipping remains blocked by incomplete heading normalization under BR-1 and another enclosing-item boundary defect.

Done-when: current — it still covers list navigation, GitHub-style anchor jumps, unknown-anchor notices, and plain-link compatibility.

```findings
dispose:
  - id: BR-1
    disposition: not-addressed
    note: |
      The original examples now pass, and loading the pre-repair heading module makes five current tests fail. However, rendered-content normalization remains incomplete at lua/parley/markdown_heading.lua:104-106,149-151: anchor_row({"# <em title=\"> more\">Target</em>"}, "target") returns nil and accepts "moretarget"; "# &#84;arget" accepts "84arget" instead of "target". Their normalized duplicate suffixes also fail. Complete the rendered-text rule across quoted HTML attributes and character references, preserving code/escaped-text controls, and add regression cases. ARCH-PURPOSE.
  - id: BR-2
    disposition: addressed
    note: |
      The shared memo retains opener character/width and accepts only sufficient-length matching closers with whitespace-only suffixes. Current lexical tests pass 10/10; loading the pre-repair lexical module makes six tests fail, including shorter, mixed-character and invalid-suffix delimiters. Anchor-consumer and partition tests pass.
  - id: BR-3
    disposition: addressed
    note: |
      Opening-fence boundary detection now precedes fenced-content exclusion. Current range tests pass 84/84; loading the pre-repair range module fails all six bullet-marker/fence-style regressions. Native Normal/Insert mapping tests cover both fence styles, and indented-fence controls retain the inside link.
findings:
  - id: new
    severity: Critical
    kind: defect
    family: navigation-item-boundaries
    title: |
      Bullet navigation still absorbs links after outside Markdown blocks
    detail: |
      lua/parley/entity_range.lua:425-430 uses the editing dialect's column-zero, level-1–3 heading predicate and otherwise requires a preceding blank. For {"- Chosen prose", "#### Outside", "[outside](outside.md)"}, navigation_range returns bullet rows 1–3 and reference_candidates.collect returns outside.md as its sole candidate. Empty ATX headings, one-space-indented outside headings, thematic breaks and block quotes also reproduce containment failures. A sweep of three bullet markers, six heading levels, zero/one-space indentation and empty/nonempty headings fails 63/72 cases. This is the 2nd finding in family `navigation-item-boundaries`. Earlier rounds fixed instances. Do NOT fix this instance alone: state and enforce the rule that an outside block opener ends the item, enumerate the supported block classes and indentation ownership, and sweep them with range and mapped negative tests. Reuse navigation block classification without changing editing textobjects. ARCH-PURPOSE, ARCH-DRY.
```

1. **Strengths**

   - Fence repair lives in the shared lexical owner; public delimiter return shape remains covered.
   - Pure range and heading decisions remain separate from editor effects.
   - Native tests exercise real Alt+O mappings in Normal and Insert modes, including same-file jumps.
   - README and atlas updates cover the new navigation behavior.

2. **Critical findings**

   - **BR-1 remains open:** HTML stripping stops at a quoted `>`, and character references reach slugging undecoded. Both violate rendered-heading normalization. The relevant contracts are documented in [GitHub’s section-link rules](https://docs.github.com/en/get-started/writing-on-github/getting-started-with-writing-and-formatting-on-github/basic-writing-and-formatting-syntax#section-links), [GFM raw HTML](https://github.github.com/gfm/#raw-html), and [character references](https://github.github.com/gfm/#entity-and-numeric-character-references).
   - **New containment finding:** outside block openers can leave unrelated links owned by the preceding bullet. Fix the boundary classification rule and test its enumerated classes.

3. **Important findings**

   None separately raised.

4. **Minor findings**

   None.

5. **Test coverage notes**

   - `make -k test-spec SPEC=context/file_references TEST_ENV_ROOT=/Volumes/TestScratch/parley407-review-verification` passed **441 tests**, including **30 native mapping tests**.
   - In-memory pre-repair module substitution produced **5 heading, 6 lexical, and 6 range failures** against current tests.
   - The initial default-scratch run had two `src:` fixture failures; the external-scratch rerun passed.
   - Pinned-range `git diff --check` passed. No tracked files changed.
   - Existing tests omit the remaining normalization and block-boundary cases.

6. **Architectural notes for upcoming work**

   - **ARCH-DRY — flag:** navigation and occurrence scanning disagree on block boundaries; consolidate navigation classification.
   - **ARCH-PURE — pass:** decisions remain pure; editor effects stay at the boundary.
   - **ARCH-PURPOSE — flag:** rendered-heading compatibility and enclosing-item confinement remain incomplete.
   - **ARCH-MOCK — pass:** no new external service dependency; editor behavior uses real embedded Neovim.
   - **ARCH-CONSTRAINTS — pass:** command-time scanning; no new background work or fan-out.
   - **ARCH-SECURE — pass:** no new credential surface; missing anchors produce visible notices.
   - **ARCH-ORDER — pass:** destination arrival guards cursor movement; same-file restoration has regression coverage.
   - **ARCH-FUNERAL — pass:** new navigation values are transient; fixtures have cleanup.
   - **ARCH-EVOLVE — pass:** no persisted-format changes.

7. **Plan revision recommendations**

   Add `## Revisions` entries reopening:

   - **Heading normalization:** enumerate rendered inline forms, including quoted HTML attributes and character references, with duplicate and literal/code controls.
   - **Item boundaries:** enumerate outside block openers and indentation ownership; require negative mapped tests alongside range tests.

   Add explicit PURE/INTEGRATION classifications to the Core concepts table.

<!-- sdlc-review-usage [{"version":1,"intent":{"disposable_root":true,"id":"95a3ee9a-b4ed-4cc6-87d5-8bc8479c1233","repository":"github.com/xianxu/parley.nvim","issue_id":"000407","recipe":"milestone-review","round":2,"attempt":1,"agent":"codex","root":"/Volumes/TestScratch/review-checkouts/32b04cd88f21d5d0","reviewed_head":"2222dd74e8451675e1252eda02b9b433a93ade62","slot":"parley.nvim:2","requested_at":"2026-10-21T23:31:16.075406Z"},"phase":"finished","pid":81888,"started_at":"2026-10-21T23:31:16.246311Z","finished_at":"2026-10-21T23:34:57.235616Z","session_id":"01a160ce-040d-7750-89ca-cb7ffaa18c74","outcome":"returned"}] -->

---

## Re-review — 2026-10-21T20:03:27-07:00 (REWORK)

| field | value |
|-------|-------|
| issue | 407 — Alt+O: open links in tight bullet lists, and jump to #anchor headings |
| repo | parley.nvim |
| issue file | workshop/issues/000407-alt-o-open-links-in-tight-bullet-lists-and-jump-to-anchor-headings.md |
| boundary | whole-issue close |
| milestone | — |
| window | 220b67af621c39fce796dc9a901b81d4d33c8d50..fd85af66acd406f68f6f7dc65cb59bc85a6357df |
| command | sdlc close --issue 407 |
| reviewer | codex (openai; author openai) |
| isolation | fenced |
| timestamp | 2026-10-21T20:03:27-07:00 |
| verdict | REWORK |

## Review

```verdict
verdict: REWORK
confidence: high
```

The shared navigation boundary rule resolves BR-4, and the narrowed HTML/entity scope is consistently documented and regression-tested. BR-1 remains blocking: supported Markdown emphasis, code spans, and inline links still produce incorrect anchors and duplicate suffixes.

```findings
dispose:
  - id: BR-1
    disposition: not-addressed
    note: |
      The HTML/entity dispute is supported: the revised Spec excludes those forms, and the current heading tests pass 15/15; loading the pre-correction module makes the unsupported-HTML regression fail. However, supported Markdown normalization remains incorrect at lua/parley/markdown_heading.lua:49-137. Headings "# _one _two_ three_", "# _Target __more___", "# ` a ` b", and "# [Target](file.md \"(title\")" fail their rendered-text anchors and duplicate suffixes: all eight checks fail. Retain BR-1 for these in-scope cases; ARCH-PURPOSE.
  - id: BR-4
    disposition: addressed
    note: |
      Shared markdown_blocks metadata now supplies block classes and content indentation to navigation_range. The 72-case heading boundary sweep passes at HEAD; loading the pre-fix range module in memory reproduces 63/72 failures. Current range tests pass 256/256 and native mapping tests pass 48/48, including outside-block negatives.
  - id: BR-2
    disposition: addressed
    note: |
      Previously accepted correction remains intact: shared fence state retains opener character and width and requires a matching whitespace-only closer. Current lexical tests pass 10/10, with heading-consumer false-closer regressions also passing.
  - id: BR-3
    disposition: addressed
    note: |
      Previously accepted correction remains intact through the shared fence-opener metadata. Range and native mapping regressions retain dedented-fence exclusion and indented-fence ownership.
```

Done-when: current — the acceptance criteria still cover the revised feature; the Spec explicitly limits which heading forms participate.

### 1. Strengths

- Shared block classification avoids duplicating navigation grammar and preserves editing textobjects.
- The containment tests cover all three bullet markers, six heading levels, indentation, nested ownership, and mapped negative cases.
- README and atlas describe the new navigation behavior and narrowed anchor scope consistently.
- Heading lookup remains directly testable without editor IO; all 15 existing heading tests also pass under standalone LuaJIT.

### 2. Critical findings

**BR-1 — Supported Markdown normalization remains incomplete.**  
[markdown_heading.lua:49](/Volumes/TestScratch/review-checkouts/1f88525da1432c80/lua/parley/markdown_heading.lua:49), especially lines 91–96 and 113–130.

| Heading content | Expected anchor |
|---|---|
| `_one _two_ three_` | `one-two-three` |
| `_Target __more___` | `target-more` |
| `` ` a ` b `` | `a-b` |
| `[Target](file.md "(title")` | `target` |

These are supported emphasis, code-span, and inline-link forms under the [GFM rules](https://github.github.com/gfm/#inlines). Standalone probes fail all four anchors. Appending equivalent plain headings makes lookup select the later heading, while all four expected `-1` anchors remain missing: **8/8 failures**.

The underscore pass loses nested delimiter ownership, code spans retain padding that rendering removes, and destination matching counts parentheses inside quoted titles. Repair the normalization rule across these supported constructs, then test both normalized anchors and duplicate numbering. This continues **BR-1**, family `heading-anchor-normalization`, rather than introducing another finding. **ARCH-PURPOSE.**

### 3. Important findings

None newly raised.

### 4. Minor findings

None.

### 5. Test coverage notes

- Passed: native navigation **48/48**, ranges **256/256**, lexical **10/10**, heading **15/15**, candidates **22/22**.
- BR-4 counterfactual: **0/72** failures at HEAD versus **63/72** with the pre-fix range module loaded in memory.
- Narrowed-scope counterfactual: the existing unsupported-HTML regression fails without the correction.
- `make -k test-spec SPEC=context/file_references` exited **2**, twice, with two existing `src:` opening tests failing. Their scratch fixtures are beneath this checkout’s Git root, causing the existing resolver to choose Git-root resolution instead of configured `src_root`. No complete green mapped run is claimed.
- Range whitespace checks passed.

### 6. Architectural notes

- **ARCH-DRY — pass:** block vocabulary and fence ownership are shared.
- **ARCH-PURE — pass:** range, block, destination, and heading decisions remain pure; editor effects stay at the boundary.
- **ARCH-PURPOSE — flag:** BR-1 still violates the supported Markdown anchor contract.
- **ARCH-MOCK — pass:** no new external dependency; native tests exercise real editor mappings.
- **ARCH-CONSTRAINTS — pass:** command-time scans; no new background work or fan-out.
- **ARCH-SECURE — pass:** no new command interpolation or credential handling.
- **ARCH-ORDER — pass:** destination identity is checked before jumping; same-file jumps retain their cursor.
- **ARCH-FUNERAL — pass:** new working values expire with the invocation.
- **ARCH-EVOLVE — pass:** no persisted format changes.

Core-concept entities exist at their documented paths, and their classifications match the implementation.

### 7. Plan revision recommendations

Add a `## Revisions` entry reopening BR-1 verification for nested emphasis, code-span normalization, and quoted inline-link destinations. Enumerate those supported grammar classes and require regressions for first occurrences and normalized duplicates before marking normalization complete.

<!-- sdlc-review-usage [{"version":1,"intent":{"disposable_root":true,"id":"7bc92e0c-3066-43e2-adb7-8575fe9c3115","repository":"github.com/xianxu/parley.nvim","issue_id":"000407","recipe":"milestone-review","round":3,"attempt":1,"agent":"codex","root":"/Volumes/TestScratch/review-checkouts/1f88525da1432c80","reviewed_head":"fd85af66acd406f68f6f7dc65cb59bc85a6357df","slot":"parley.nvim:2","requested_at":"2026-10-22T02:58:11.470274Z"},"phase":"finished","pid":27169,"started_at":"2026-10-22T02:58:11.666531Z","finished_at":"2026-10-22T03:03:26.70307Z","session_id":"01a1618b-75f6-7e32-998c-780f11583d59","outcome":"returned"}] -->
