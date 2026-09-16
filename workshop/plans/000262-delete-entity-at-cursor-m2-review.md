# Boundary Review — parley.nvim#262 (milestone M2)

| field | value |
|-------|-------|
| issue | 262 — Delete entity at cursor — markdown section, paragraph, or chat question |
| repo | parley.nvim |
| issue file | workshop/issues/000262-delete-entity-at-cursor.md |
| boundary | milestone M2 |
| milestone | M2 |
| window | 0d0b3801fca2a28f82ccb692aa97cee354b93cea..0d0b3801fca2a28f82ccb692aa97cee354b93cea |
| command | sdlc milestone-close --issue 262 --milestone M2 |
| reviewer | claude |
| timestamp | 2026-09-16T15:13:11-07:00 |
| verdict | FIX-THEN-SHIP |

## Review

```verdict
verdict: FIX-THEN-SHIP
confidence: high
```

The M2 surface is genuinely good engineering — `entity_range` stays pure (38 unit assertions, zero mocks), both surfaces route through one range function and one classifier, the parity spec now sweeps five axes with the newest one demonstrated red without its fix, and the two editor-state hazards (visual anchor, closed folds) are pinned by tests that actually reproduce them. I ran the feature's mapped specs: entity_range 38/38, entity_textobj 15/15, parity 11/11, starter_config 7/7, keybinding_agreement 33/33 — all green. Nothing blocks on correctness of the delivered code. What holds SHIP back is four things the gate is supposed to catch and didn't: **the pinned M2 window is empty** (base == head == `0d0b3801`; the entire M2 deliverable landed at `e007f6c5`/`49064ec4`/`cb17a0a6`, four commits *before* the base), so the mandatory fresh-eyes review at this boundary nominally reviews zero changes; the README omission `BR-8` raised twice and disposed `not-addressed` twice is still open while plan Task 14 Step 3 sits ticked; the plan body still claims reuse and a file set the code does not match; and `dae` inside a fenced block that contains a blank line silently leaves an unterminated fence — a case plan Task 7 Step 3 was ticked for and neither wired, tested, nor documented.

## 1. Strengths

- `lua/parley/entity_range.lua:196-277` — the pure core holds. `range(parsed, lines, row, opts)` never touches a buffer, so all six rules are unit-testable without nvim state, and the final guard at `:273` (`first > last or first < floor or last > #lines`) is a genuine post-condition rather than a restatement of the walk. The malformed-input sweep at `tests/unit/entity_range_spec.lua:420` (rows `0..#lines+2`, both scopes, both inner values, over empty/header-only/fenced fixtures) is the right shape for hand-edited transcripts.
- `tests/integration/entity_delete_parity_spec.lua:47-76` — the axis enumeration is written into the spec as a rule with a stated reason for the one axis deliberately excluded (in-flight generation). This is exactly the correction the `parity-varies-only-cursor` family asked for, and the `separator-edited-away` shape at `:75` is the axis the two earlier on-disk shapes structurally could not see.
- `lua/parley/entity_textobj.lua:31-46` + `lua/parley/init.lua:4536-4541` — one classifier, called from both surfaces, returning a three-valued status instead of collapsing "not a chat" and "chat that won't parse" into one `nil`. The command path no longer re-asks `not_chat`, which is what made the two surfaces disagree.
- `lua/parley/starter_config.lua:25-46` — the `object_only` carve-out is narrowly argued (a text object cannot claim a bare key, so the family filter's *intent* doesn't reach it) and the negative is pinned at `tests/unit/starter_config_spec.lua` — `resolve_ref_gf`, a bare normal-mode key in the same scope, is still excluded. That is how a filter widening should be proven.
- I verified the closed-fold claim end-to-end rather than taking it on trust: with a closed fold at 14–17, `dae` at rows 15/16/17 deletes exactly 15–18 (4 lines) and rows 13/14/18 are correct no-ops. `G` is not snapping and the visual selection is not being extended to the fold.

## 2. Critical findings

None.

## 3. Important findings

**`README.md:13-20` — the new user-typed surface is still half-documented. (2nd in family `readme-omits-new-surface`.)** README covers `dae`, `daE`, `yae`, `cae`. Absent: `ie` (`config.lua:388`), `<C-g>k` / `<C-g>K` (`config.lua:390-391`), and `:ParleyDeleteEntity` / `:ParleyDeleteToEnd` (`init.lua:4556,4560`) — even though README already documents other commands in that register (`:ParleyStop`, `:ParleyChatResumeResponse`, `:ParleyToolOperations`). Plan Task 14 Step 3 ("Grep the README for the new keys and add them") is `[x]`; the issue `## Plan` M2 row claims "the atlas/README keys". `BR-8` was disposed `not-addressed` at round 3 and again at round 4, and the M1 close commit `0d0b3801` does not touch `README.md`.

Because this is a repeat, do not just add the missing line. **The rule:** *every registry entry carrying a `config_key` and every `M.cmd.*` a milestone introduces must be reachable from README before that milestone closes.* The enumeration is mechanical and should be the artifact — the new ids are exactly `keybinding_registry.entries` whose `config_key` appears in the branch diff of `lua/parley/config.lua`, plus the `M.cmd.` symbols added to `lua/parley/init.lua`. Ship that check (a spec alongside `single_source_sweeps_spec.lua`, which already owns "every spec this branch ADDED is routed somewhere" — the identical shape), not the paragraph.

**`workshop/plans/000262-delete-entity-at-cursor-plan.md:7,43-91,937` — the plan body describes a tree that does not exist. (3rd in family `plan-table-understates-code`.)** Three live instances:
- `:7` states `entity_range` "reuses the tested primitives (`exchange_clipboard.get_exchange_line_range`, `question_tags.semantic_start`, `highlight_structure.code_block_memo`)". Two of three are true; `grep -n 'highlight_structure\|code_block_memo' lua/parley/entity_range.lua` returns nothing. No Revisions entry records the drop.
- The Integration-points table (`:76-82`) omits `lua/parley/starter_config.lua` and `tests/unit/starter_config_spec.lua`, a behavioral change to the packaged app shipped at `49064ec4` with its own test — the one change in this branch that alters what end users receive.
- `BR-13`'s instance is untouched: `:86` and `:937` still say "ExchangeCut's preamble verbatim (`init.lua:4423-4436`)"; `M.cmd.ExchangeCut` is now at `init.lua:4439` and the handler at `:4529` uses `entity_textobj.parsed_for`.

`BR-13` already stated the rule ("a Revisions entry recording a delta must be applied to the plan body it contradicts in the same edit") and the family repeated anyway, which says the rule is not enforceable by intention. **The enforceable form:** the Core-concepts table is a claim about the tree, so verify it mechanically — every path in `git diff --name-only <branch-point>..HEAD -- 'lua/**' 'tests/**'` must appear in the table, and every `file.lua` / `file.lua:N` the plan names must resolve. That check belongs in the close gate, not in a reviewer's eyes.

**`lua/parley/entity_range.lua:52-62` — the paragraph walk has no fence wall, so `dae` can leave an unterminated code fence.** Reproduced on a real parsed transcript:

```
10  ```lua        →  range(…, 10) = paragraph 10..12
11  local a = 1   →  range(…, 11) = paragraph 10..12
12  (blank)
13  local b = 2   →  range(…, 13) = paragraph 13..15
14  ```           →  range(…, 14) = paragraph 13..15
```

`dae` at row 10 deletes the opener and its first stanza, leaving a bare closing ` ``` ` — every following line of the transcript then renders as code until the next fence. `u` recovers it and `dap` behaves the same way in plain markdown, which is why this is Important and not Critical — but the issue explicitly ruled that strict `dap` parity is a bug in a transcript and added extra walls for headings and structural markers, and a fence is the same class.

Plan Task 7 Step 3 is `[x]` and required "Either wire the memo into `is_wall`/`section_range` **or** add a test pinning the current behavior and a one-line note in the atlas page. Do not leave it unstated." The atlas note exists for the *heading*-in-fence case only (`atlas/chat/entity_delete.md`, "Limits"); no test pins either behavior — the only fenced fixture, `entity_range_spec.lua:416`, asserts solely that the range is not inverted or out of range. So the step is a `checkbox-without-artifact` instance (2nd in that family) as well. Fix: add `highlight_structure.code_block_memo` as a wall in `is_wall`, or state the fence-splitting limit in the atlas and pin both behaviors with a test.

**The pinned review window is empty. (2nd in family `empty-review-window`.)** Both required recipes exit 0 with no output:

```
git diff --stat 0d0b3801 0d0b3801 -- …   → (empty)
git diff --name-status 0d0b3801 0d0b3801 -- … → (empty)
```

M2's entire deliverable is at `e007f6c5` (text objects, commands, registry, config), `49064ec4` (packaged app) and `cb17a0a6` (parity spec, atlas, README) — all *ancestors* of the base, because M1 and M2 were implemented together and M1 closed last, at `0d0b3801`. I reviewed `85e116c2..HEAD` and the tree at HEAD instead; every finding above is therefore located outside the range the gate pinned.

`BR-14` raised this at M1 round 3 (base == head) and again at round 4 (base *was* the fix commit, so dispositions had to be verified from the tree). Measured prevalence: 3 of the 4 rounds on this issue could not do their verification from the pinned diff. **The rule:** *a boundary's `BASE_SHA` must be the parent of the milestone's own first commit, not the previous boundary's tip — and when the computed range is empty, the gate must refuse to record a verdict rather than accept one over zero changes.* The current derivation is only correct when milestones close in the order they are implemented; this issue implemented M1+M2 together and closed M1 last, which is ordinary and will recur.

## 4. Minor findings

- `atlas/chat/entity_delete.md` "Limits" — the ARCH-CONSTRAINTS numbers (13.6 / 24.7 / 97.8 ms) live only as prose, and the page says so itself ("No perf spec guards these numbers … they go stale silently if `parse_chat` changes"). 2nd in family `unreproducible-measurement`. The rule: a declared envelope gets an executable check or the declaration is deleted — a prose number that can't be re-derived by the suite is a claim, not a measurement. The page does record the re-derivation recipe (`tests.perf.chat_typing.build_fixture(n)`), so the cheap fix is to make that recipe a spec with a wide assertion rather than to re-measure by hand.
- `tests/integration/entity_delete_parity_spec.lua:78,131-151` — `shape` is a module-level upvalue mutated inside each `it` body and read by `fresh()`. Correct only because busted runs the bodies sequentially; pass the shape through `fresh(s)` instead.
- `lua/parley/entity_range.lua:243` — `structural_prefixes(opts.config)` re-`require`s `document.lexical` and rebuilds the pattern table on every paragraph dispatch. Negligible beside the whole-buffer `parse_chat`, noted only because this is a keystroke path.
- `lua/parley/keybinding_registry.lua:493` — `help_desc` for the inner object reads "die/yie/cie"; the outer reads "dae/yae/cae" but the to-end one reads only "(daE)". Cosmetic inconsistency in `:ParleyKeyBindings` output.

## 5. Test coverage notes

Coverage is strong where it matters and the tests pin behavior rather than restating the implementation. `entity_textobj_spec` covers the two hazards, `die`/`cae`, the streaming refusal via the `buffer_edit` seam, the markdown-classified floor, the packaged-app profile, and the edge-📝 survival through `daE` — the exact set the M1 rounds asked for. The parity spec's five shapes × every row × two scopes is the right guard for a two-surface design.

The one real gap is the fenced-block class (Important #3): the only fenced fixture is in the invariant sweep, which asserts a *property* (not inverted, in range) and would stay green under any fence behavior at all, including the unterminated-fence outcome above. That is the same shape as the `partial-shape-test` family — a test whose assertion cannot distinguish the behavior it is nominally covering.

## 6. Architectural notes

- **ARCH-DRY — pass.** One heading dialect in `markdown_heading.lua`, consumed by `entity_range` and by *both* `outline.lua` paths (`:57` and `:254`), and pinned against `document/lexical.lua`'s independent byte-scanner by a 20-line conformance corpus. One exchange-span definition (`exchange_clipboard.get_exchange_line_range`), one classifier (`parsed_for`) shared by both surfaces, keymaps through the registry. `exporter.lua:539-541` still restates `^## `/`^### ` independently, but it is pre-existing and recorded in the issue `## Log` as part of the widening enumeration — deferred, not hidden.
- **ARCH-PURE — pass.** The pure/IO split is the cleanest thing in this diff: `range()` takes `(parsed, lines, row, opts)` and returns a value; the IO shell is `entity_textobj.select` (cursor, fold, visual state) and `delete_entity_range` (buffer_edit). 38 unit assertions run with zero mocks.
- **ARCH-PURPOSE — flag (Important #1).** The purpose is "one uniform delete across three kinds and two scopes, **reachable by a discoverable key**." The keys and commands ship and the app profile carve-out ships; the discoverability half is where it stops short — three of five keys and both commands exist only in the atlas and in `:ParleyKeyBindings`, not where a user reading the project first lands. Shadow-sweep of the single-source dialect: consumers are `entity_range`, `outline` (both paths), `document/lexical` (enforced by conformance) — complete for this change.
- **ARCH-MOCK — N/A, correctly.** No external binary or service. Neovim is exercised for real via `D.attach(buf, {schedule=false})` on real buffers; the streaming refusal is injected at the in-process `buffer_edit` seam, which is the right boundary for an in-process dependency.
- **ARCH-CONSTRAINTS — flag (Minor).** Envelope declared (keystroke path, <16 ms @ 5 000 lines), measured, missed, and recorded as an accepted deviation with the operator's basis rather than silently widened — that part is exemplary. What's missing is any executable guard, so the envelope is documentation.
- **ARCH-SECURE — pass.** The transcript is the untrusted input and is treated as such: `parse_chat` is `pcall`ed, failure degrades to a *visible refusal with a message* rather than to unclamped markdown semantics, and the property sweep asserts no inverted or out-of-range result over malformed shapes. No secrets. Tests write under `$TMPDIR/claude/…`, never real user state.
- **ARCH-ORDER — pass.** `entity_range` holds no state between events because every call re-derives from `(parsed, lines, row)` and returns a value; there is no cache to invalidate. The one unblockable event — a response streaming into the exchange being edited — is named, handled (the command path inherits `replace_user_lines`' refusal, the native path is an ordinary user edit through `document/user_edits.lua`), tested (`entity_textobj_spec.lua:196`), and its asymmetry is the explicit scope boundary of the parity claim. The axis enumeration is written where the next reader will find it.
- **ARCH-FUNERAL — pass.** Creates nothing durable: keymaps are buffer-local and collected by the existing `M._parley_bufs` unload path; ranges are values; deleted text lives in Vim's own register/undo lifecycle. No new file family, log, or cache.

## 7. Plan revision recommendations

The plan needs one `## Revisions` entry covering the three contradictions in Important #2 together (they are one class, per ARCH-PURPOSE — record the class, not three bullets):

> ### 2026-09-16 — M2 boundary review: the plan body's claims about the tree
> - **`highlight_structure.code_block_memo` was never wired in.** The Architecture paragraph (`:7`) lists it among the reused primitives; `entity_range.lua` does not reference it. The fenced-block cases (heading-in-fence, and a fence split by an interior blank line) are therefore unhandled — see the fence finding.
> - **The Integration-points table omits `starter_config.lua`.** `49064ec4` carved `object_only` out of the app's family filter and added `tests/unit/starter_config_spec.lua`; it is the only change in this branch that alters what packaged-app users receive, and the table does not list it.
> - **`:86` / `:937` still describe the implementation BR-2 removed** (`ExchangeCut`'s preamble at `init.lua:4423-4436`); both handlers now go through `entity_textobj.parsed_for`, and `ExchangeCut` has moved to `:4439`.
> - **Rule, third repeat in this family:** the Core-concepts table and Architecture paragraph are claims about the tree, so they are verified mechanically at the close gate — every path in the branch's `lua/**`/`tests/**` diff appears in the table, and every path the plan names resolves — rather than maintained by intention.

Plan Task 7 Step 3 and Task 14 Step 3 should be **un-ticked** until their artifacts exist (the fence test/note and the README keys respectively), or the deferral recorded in the same Revisions entry.

```findings
findings:
  - id: new
    severity: Important
    family: readme-omits-new-surface
    title: |
      README still omits ie, <C-g>k, <C-g>K and both :ParleyDelete* commands while plan Task 14 Step 3 is ticked
    detail: |
      2nd finding in this family; BR-8 was also disposed not-addressed at M1 rounds 3 and 4 and the M1 close
      commit 0d0b3801 does not touch README.md. README.md:13-20 covers dae/daE/yae/cae only, though README
      already documents peer commands (:ParleyStop, :ParleyToolOperations). Do NOT just add the missing line.
      THE RULE: every registry entry carrying a config_key and every M.cmd.* a milestone introduces must be
      reachable from README before that milestone closes. The enumeration is mechanical - registry entries whose
      config_key appears in the branch diff of lua/parley/config.lua, plus M.cmd. symbols added to init.lua -
      so ship the check (a spec beside single_source_sweeps_spec.lua, which already owns the identically shaped
      "every spec this branch ADDED is routed somewhere" sweep), not the paragraph.
  - id: new
    severity: Important
    family: plan-table-understates-code
    title: |
      plan body claims a reuse and a file set the tree does not have - three live instances
    detail: |
      3rd finding in this family (BR-7, BR-13, this). Instances - plan.md:7 says entity_range reuses
      highlight_structure.code_block_memo and it references it nowhere; the Integration-points table omits
      lua/parley/starter_config.lua and tests/unit/starter_config_spec.lua, the only change in the branch that
      alters what packaged-app users receive; and BR-13's instance is untouched, with :86 and :937 still naming
      "ExchangeCut's preamble (init.lua:4423-4436)" when ExchangeCut is at :4439 and the handler at :4529.
      BR-13 already stated the rule as an intention and the family repeated, so the enforceable form is
      mechanical - at the close gate, every path in git diff --name-only branch-point..HEAD over lua/ and tests/
      must appear in the Core-concepts table, and every file or file:line the plan names must resolve.
  - id: new
    severity: Important
    family: range-splits-a-structure
    title: |
      the paragraph walk has no fence wall, so dae inside a code block leaves an unterminated fence
    detail: |
      Reproduced on a real parsed transcript - with lines 10..14 = ```lua / local a = 1 / blank / local b = 2 /
      ```, range(parsed, lines, 10) returns paragraph 10..12, so dae deletes the opener and its first stanza and
      leaves a bare closing fence; every following line then renders as code. Undo recovers it and dap behaves
      the same in plain markdown, hence Important not Critical - but the issue explicitly ruled strict dap parity
      a bug in a transcript and already added walls for headings and structural markers, and a fence is the same
      class. Plan Task 7 Step 3 is ticked and required EITHER wiring highlight_structure.code_block_memo into
      is_wall/section_range OR a test pinning current behavior plus an atlas note; the atlas note covers only
      heading-in-fence and no test pins either (entity_range_spec.lua:416 asserts only not-inverted/in-range, so
      it would stay green under any fence behavior). That also makes it the 2nd checkbox-without-artifact.
  - id: new
    severity: Important
    family: empty-review-window
    title: |
      the M2 boundary pinned base == head, so the whole milestone sits outside the reviewed range
    detail: |
      2nd finding in this family; BR-14 raised it at M1 round 3 and again at round 4. Both required recipes exit
      0 with no output at base == head == 0d0b3801, and M2's entire deliverable (e007f6c5, 49064ec4, cb17a0a6)
      predates that base because M1 and M2 were implemented together and M1 closed last. Measured prevalence -
      3 of 4 rounds on this issue could not verify from the pinned diff. Do NOT re-derive the window by hand.
      THE RULE - a boundary's BASE_SHA must be the parent of the milestone's own first commit rather than the
      previous boundary's tip, and a gate whose computed range is empty must refuse to record a verdict instead
      of accepting one over zero changes. The current derivation is correct only when milestones close in the
      order they were implemented, which is not what happened here and will recur.
  - id: new
    severity: Minor
    family: unreproducible-measurement
    title: |
      the ARCH-CONSTRAINTS numbers exist only as atlas prose, with no spec guarding them
    detail: |
      2nd in this family. atlas/chat/entity_delete.md states 13.6 / 24.7 / 97.8 ms and then says itself that no
      perf spec guards them, so they go stale silently when parse_chat changes. The rule - a declared operating
      envelope gets an executable check or the declaration is deleted; a prose number that the suite cannot
      re-derive is a claim, not a measurement. The page already records the recipe
      (tests.perf.chat_typing.build_fixture(n)), so turning that recipe into a spec with a wide assertion is the
      cheap fix.
  - id: new
    severity: Minor
    family: shared-mutable-test-fixture
    title: |
      the parity spec mutates a module-level `shape` upvalue that fresh() reads
    detail: |
      tests/integration/entity_delete_parity_spec.lua:78 declares `shape` at module scope and each it() body
      assigns it before looping; fresh() reads it. Correct only because busted runs the bodies sequentially.
      Pass the shape through fresh(s) instead.
  - id: new
    severity: Minor
    family: inconsistent-error-handling
    title: |
      help_desc strings for the entity family list operators inconsistently
    detail: |
      keybinding_registry.lua:483 reads "dae/yae/cae" and :493 "die/yie/cie", but :503 lists only "(daE)".
      Cosmetic inconsistency in the :ParleyKeyBindings output for one family.
```

---

## Re-review — 2026-09-16T15:35:51-07:00 (FIX-THEN-SHIP)

| field | value |
|-------|-------|
| issue | 262 — Delete entity at cursor — markdown section, paragraph, or chat question |
| repo | parley.nvim |
| issue file | workshop/issues/000262-delete-entity-at-cursor.md |
| boundary | milestone M2 |
| milestone | M2 |
| window | f53af775adab1355c5b1ba31e08017be9cebd83f..f53af775adab1355c5b1ba31e08017be9cebd83f |
| command | sdlc milestone-close --issue 262 --milestone M2 |
| reviewer | claude |
| timestamp | 2026-09-16T15:35:51-07:00 |
| verdict | FIX-THEN-SHIP |

## Review

```verdict
verdict: FIX-THEN-SHIP
confidence: high
```

The M2 fence fix is real work with real evidence: I reverted it in a scratch worktree at `f53af775` and 4 of the 5 new fence cases go red, so BR-21's regression is genuinely pinned, and the suite I ran is green (entity_range 43/43, entity_textobj 15/15, parity 11/11, starter_config 7/7, single_source_sweeps 21/21, keybinding_agreement 33/33, outline 20/20, heading conformance 1/1). What holds SHIP back is that two of the three fixes landed on the site rather than the class the prior round named. The fence wall recognizes only column-zero backtick fences while `code_block_memo` — called eleven lines below it, in the same commit — recognizes `~~~` and indented fences too, so `dae` on a `~~~lua` opener still returns `paragraph 10..12` and still leaves a bare `~~~` closer: BR-21's exact failure, one fence flavor over. And BR-20's "every file:line the plan names must resolve" fixed `:87` and `:938` while `:53` and `:852` still carry three stale refs. The pinned window was empty for the third round running (base == head == `f53af775`, both recipes exit 0 silently), so none of this came from the diff the gate handed me.

## 1. Strengths

- `lua/parley/entity_range.lua:225-231,249` — the fix is argued at the right level. The commit message's reasoning is correct and I confirmed it: `is_wall` alone guards only the paragraph walk, so `dae` on a `# heading` in a code sample would still have built a section crossing the closing fence. Wiring `code_block_memo` into the section branch as well is what makes it a rule instead of a patch, and it aligns with `outline.lua:32`, whose citation resolves.
- Regression evidence is real, not asserted. Scratch revert at `f53af775` → `entity_range code fences` fails 4/5 (`treats a fence line as a wall`, `keeps a range inside the fence from swallowing the fence`, `treats a heading inside a fence as content`, `to_end from inside a fence`). This is the standard a behavior-changing disposition is supposed to meet.
- `tests/unit/entity_range_spec.lua:410-481` builds its fixtures through the real `parse_chat`, so the fence cases break if the parser's shape moves — the same discipline the rest of the file already had.
- ARCH-CONSTRAINTS was not quietly widened by this change. I measured it: `code_block_memo` costs 0.79 ms/call on a 5 000-line buffer against `parse_chat`'s 29.6 ms on this machine — ~2.7% on top of a cost the operator already accepted.
- `lua/parley/starter_config.lua` + `tests/unit/starter_config_spec.lua` (from `49064ec4`, still the only change in this branch that alters what packaged-app users receive) remains pinned by a negative: `resolve_ref_gf`, a bare normal-mode key in the same scope, is still excluded by the filter.

## 2. Critical findings

None.

## 3. Important findings

**`lua/parley/entity_range.lua:61` vs `:230` — the wall and the memo use two different definitions of "fence", added in the same commit. (2nd in family `range-splits-a-structure`.)**

`is_wall` calls `fence.open_len` = `lexical.ordinary_open_len` (`document/lexical.lua:275`), which matches `^(`+)([^`]*)$` — column-zero backticks only. Eleven lines below, `code_block_memo` builds `in_code` from `lexical.is_fence_delim(line, true)` (`document/lexical.lua:212`), which matches `^%s*(`+)` **and** `^%s*(~+)`. So inside a `~~~` or an indented block the memo says "in code" while the paragraph walk sees no wall. Reproduced on real parsed transcripts:

```
~~~lua / local a = 1 / (blank) / local b = 2 / ~~~   at rows 10..14
  range(parsed, lines, 10) -> paragraph 10..12     <- BR-21 verbatim
  range(parsed, lines, 14) -> paragraph 13..15     <- deletes the closer AND the line after it
   ```lua  (three-space indent, as inside a list item)
  range(parsed, lines, 10) -> paragraph 10..12
```

Both cases leave an unterminated fence and render the rest of the transcript as code — the exact consequence BR-21 named. Same severity reasoning as BR-21 (undo recovers it), so Important, not Critical.

Because this is a repeat, **do not add a tilde branch to `is_wall`**. **The rule:** *`entity_range` must consume ONE fence-delimiter predicate, and it must be the same one `code_block_memo` uses to build `in_code`* — `lexical.is_fence_delim` — so a line the memo counts as a fence is necessarily a wall and the two cannot drift. Concretely: drop the `require("parley.fence").open_len` call and test `lexical.is_fence_delim(line, true)`, which also removes the only `require` sitting inside a per-line loop. The parity spec cannot catch this class (both surfaces share the range function and agree on the wrong answer), so the guard belongs in `entity_range_spec` — parameterize the existing `code fences` block over `{"```", "~~~", "   ```"}` rather than adding a second literal fixture.

## 4. Minor findings

- `atlas/chat/entity_delete.md:94-95` and `lua/parley/entity_range.lua:10` both now say something the code does not do: the atlas claims a `# heading` inside a fence "is content rather than a section" (measured: `range(...)` returns `nil` on it — a no-op, neither section nor content, and the Precedence table gained a row for fence lines but not for this case), and the module docstring still opens "Five rules, each stated once" over six numbered rules with the fence rule not enumerated at all.
- `workshop/plans/000262-delete-entity-at-cursor-plan.md` was edited for the M2 review (`:7`, `:82`, `:87`, `:797`, `:938`, the struck-through open item) with no `## Revisions` entry recording the deltas, which AGENTS.md §1 requires for an in-stream plan revision. The issue `## Log` carries the narrative, so nothing is lost — but the plan's own history says the last change was M1 round 2.

## 5. Test coverage notes

- The fence block is the right shape and demonstrated red. One assertion in it is weaker than its name: `to_end from inside a fence still stops at the exchange bound` asserts `r.last <= #lines`, which is `M.range`'s own post-condition at `:289` restated and cannot fail for the reason the title gives. It went red without the fix on its *other* assertion (`r.first >= 11`), so it is not dead — but `assert.equals(bounds.last, r.last)` is what the title claims.
- The parity fixture (`entity_delete_parity_spec.lua:15-42`) carries a ```` ```json ```` block at 15–17 inside the closed fold, so the backtick-fence behavior change is swept across all five shapes. No tilde or indented fence anywhere in the branch's fixtures — which is why the divergence above shipped green.
- No coverage of `~~~`/indented fences in `entity_range_spec`; see the Important finding.

## 6. Architectural notes for upcoming work

- **ARCH-DRY — flag.** Two fence-delimiter definitions inside one function, introduced together. The repo already paid for this once: `fence.lua:9-14` documents #200, where this exact rule had three independent implementations and `answer_structure` closed on any ≥3-backtick run. `lexical.is_fence_delim` is the incumbent single source; `entity_range` should derive from it.
- **ARCH-PURE — pass.** `range(parsed, lines, row, opts)` still takes no buffer; `code_block_memo` is pure over `(lines, patterns)`. 43 unit assertions, zero mocks. The boundary has not leaked.
- **ARCH-PURPOSE — flag.** Three dispositions this round fixed the named site rather than the enumerable class: the fence wall (backticks, not every fence the memo recognizes), the plan's stale refs (`:87`/`:938` fixed, `:53`/`:852` not), and the README (prose repaired, the mechanical check the finding asked for not shipped — nothing new under `tests/arch/`). The README prose is now correct and I am disposing it as such, but the family stays live by hand-maintenance.
- **ARCH-MOCK — N/A, pass.** No external binary or service; Neovim is exercised for real through `D.attach(buf, {schedule=false})`.
- **ARCH-CONSTRAINTS — pass, measured.** 0.79 ms added per invocation at 5 000 lines. Worth knowing for later: `in_code` is built unconditionally at `:230`, before dispatch, though only the section branch at `:249` reads it — a `heading.level(lines[row])` guard would make it free on the question and paragraph paths. Not worth a finding at this cost; worth it if the memo ever gets more expensive.
- **ARCH-SECURE — pass.** The new input path is pure and total over arbitrary lines; `is_blank` short-circuits `nil` before `fence.open_len` sees it, and the malformed-transcript property sweep (`entity_range_spec.lua:482+`, rows `0..#lines+2` over empty/header-only/fenced fixtures) covers hand-edited input.
- **ARCH-ORDER — pass.** The memo is rebuilt per call, so there is no cache to invalidate and no state carried between events. The one documented surface asymmetry (streaming refusal on the command path only) is unchanged.
- **ARCH-FUNERAL — pass.** Creates nothing durable; the memo dies with its scope.

## 7. Plan revision recommendations

- Add a `### 2026-09-16 — M2 boundary review (FIX-THEN-SHIP → fixes applied)` entry recording the four deltas already made to the body (the `fence.open_len`/`code_block_memo` reuse now real, `starter_config.lua` added to Integration points, the `ExchangeCut` ref correction, Task 7 Step 3 resolved rather than deferred) plus this round's fence-predicate unification.
- Correct `:53` (`ChatPrune` is `init.lua:4271`, `ExchangeCut` is `:4439`) and `:852` (the visual-mode idiom is `init.lua:2812-2819`; `:2803` is `chat_search`). Then ship the mechanical form BR-20 asked for, so the fifth round does not find a sixth stale ref.
- `atlas/chat/entity_delete.md` Limits: replace "a `# heading` inside a fenced block is content rather than a section" with what the code does — `dae` on it is a no-op — and add the row to the Precedence table.

```findings
dispose:
  - id: BR-19
    disposition: addressed
    note: |
      README.md:17-24 now covers ae/ie/aE, dae/yae/cae, Ctrl+g k, Ctrl+g K and both :ParleyDelete* commands - all five config_keys and both M.cmd symbols reachable; the enforcing check was NOT shipped, so the family stays hand-maintained (see ARCH-PURPOSE note).
  - id: BR-20
    disposition: not-addressed
    note: |
      Two of four instances fixed (:87/:938 -> 4439, starter_config added to the table, code_block_memo reuse now real); plan.md:53 still says ChatPrune init.lua:4255 (actual 4271) and ExchangeCut init.lua:4423 (actual 4439), and :852 cites init.lua:2803 as chat_exchange_cut when that line is chat_search.
  - id: BR-21
    disposition: addressed
    note: |
      Verified red without the fix in a scratch worktree at f53af775 - 4 of 5 new fence cases fail. The backtick instance is fixed with genuine regression evidence; the tilde/indented sibling is raised separately.
  - id: BR-22
    disposition: not-addressed
    note: |
      Window is base == head == f53af775 - both required recipes exit 0 with no output, for the third round running. A correct prev-boundary..HEAD range (0d0b3801..f53af775) would have been non-empty here, so the derivation is pinning base to HEAD, not just mis-ordering milestones. Prevalence now 4 of 6 rounds on this issue.
  - id: BR-23
    disposition: not-addressed
    note: |
      No perf spec added; atlas/chat/entity_delete.md still states the numbers and then says nothing guards them. I re-measured independently (parse_chat 29.6 ms, code_block_memo 0.79 ms at 5000 lines) - same shape, still unreproducible by the suite.
  - id: BR-24
    disposition: not-addressed
    note: |
      entity_delete_parity_spec.lua:78 still declares `local shape = SHAPES[1]` at module scope with each it() assigning it and fresh() reading it.
  - id: BR-25
    disposition: not-addressed
    note: |
      keybinding_registry.lua:483/493/503 unchanged - "dae/yae/cae", "die/yie/cie", then "(daE)" alone.
findings:
  - id: new
    severity: Important
    family: range-splits-a-structure
    title: |
      the fence wall recognizes only column-zero backticks while code_block_memo recognizes ~~~ and indented fences, so BR-21 still reproduces one fence flavor over
    detail: |
      2nd finding in family range-splits-a-structure. entity_range.lua:61 walls on fence.open_len (lexical.ordinary_open_len, pattern ^(`+)([^`]*)$, column zero, backticks only); entity_range.lua:230 builds in_code from code_block_memo, which uses lexical.is_fence_delim(line, true) - ^%s*(`+) plus ^%s*(~+). Two definitions of one fact, added in the same commit. Measured on real parsed transcripts - with rows 10..14 = ~~~lua / local a = 1 / blank / local b = 2 / ~~~, range(parsed, lines, 10) returns paragraph 10..12 and range(parsed, lines, 14) returns paragraph 13..15, so dae leaves a bare ~~~ and the rest of the transcript renders as code; a three-space-indented ``` opener gives the identical 10..12. Same undo-recoverable severity reasoning BR-21 carried. Do NOT add a tilde branch to is_wall. THE RULE - entity_range must consume ONE fence-delimiter predicate, and it must be the one code_block_memo uses (lexical.is_fence_delim), so a line the memo counts as a fence is necessarily a wall; that also removes the only require sitting inside a per-line loop. The parity spec structurally cannot see this axis (both surfaces share the range function and agree on the wrong answer), so the guard goes in entity_range_spec - parameterize the existing code fences block over the three delimiter shapes rather than adding a second fixture. fence.lua:9-14 records that this exact rule already had three independent implementations once (#200).
  - id: new
    severity: Minor
    family: docs-edit-mangles-prose
    title: |
      the fence docs describe behavior the code does not have, in both the atlas page and the module docstring
    detail: |
      2nd finding in family docs-edit-mangles-prose. atlas/chat/entity_delete.md:94-95 says a "# heading" inside a fenced block "is content rather than a section"; measured, range() returns nil on that row - a no-op, neither section nor content - and the Precedence table gained a row for fence lines but none for this case. entity_range.lua:10 still opens "Five rules, each stated once" over six numbered rules, and the fence rule is not enumerated among them. THE RULE the family points at - a docs edit that accompanies a behavior change must be read back against the behavior, not just inserted; both sites here were written from the intent rather than from what range() returns.
  - id: new
    severity: Minor
    family: plan-table-understates-code
    title: |
      the plan body was edited for the M2 review with no "## Revisions" entry recording the deltas
    detail: |
      4th finding in family plan-table-understates-code. plan.md:7, :82, :87, :797, :938 and the struck-through open item 3 all changed at f53af775; the plan's Revisions section still ends at "M1 boundary review round 2". AGENTS.md section 1 requires an appended Revisions entry (timestamp, reason, delta) rather than an overwrite. The issue "## Log" carries the narrative so nothing is lost, which is why this is Minor - but the plan's own history now misstates when it last moved, and BR-13 already stated the Revisions/body consistency rule for the opposite direction.
```

---

## Re-review — 2026-09-16T16:04:38-07:00 (REWORK)

| field | value |
|-------|-------|
| issue | 262 — Delete entity at cursor — markdown section, paragraph, or chat question |
| repo | parley.nvim |
| issue file | workshop/issues/000262-delete-entity-at-cursor.md |
| boundary | milestone M2 |
| milestone | M2 |
| window | f53af775adab1355c5b1ba31e08017be9cebd83f..8c2e3150c3c3ed44952742749cc2e6cc073adee2 |
| command | sdlc milestone-close --issue 262 --milestone M2 |
| reviewer | claude |
| timestamp | 2026-09-16T16:04:38-07:00 |
| verdict | REWORK |

## Review

```verdict
verdict: REWORK
confidence: high
```

The BR-26 fix itself is clean and genuinely verified — `is_wall` now consumes `lexical.is_fence_delim(line, true)`, the same predicate `code_block_memo` uses, and I confirmed the new spec goes red (43 pass / 1 fail) when I scratch-revert that one line. But the fix is the *instance*, not the class: `entity_range` classifies a line at five sites and only one of them (`:253`) consults the in-code memo, so `section_range`'s forward scan still treats a `# heading` **inside** a fenced block as a section terminator. Measured on a real parse, `dae` on `## Section` returns `section 8..10` where row 10 is the opening ` ```lua ` — the deleted range takes the opener and leaves the closer, which is the exact corruption BR-21 and BR-26 were each raised for. That is the third instance of `range-splits-a-structure`. Separately, the milestone's own flagship guard, `tests/integration/entity_delete_parity_spec.lua`, exits 1 without ever printing a busted summary — 6 of 6 runs, including serial single-file runs under the repo's `make test-spec` with a clean `TEST_ENV_ROOT` — while the plan ticks both "Run it and watch it pass" and `make test` as done. Those two block the boundary.

---

### 1. Strengths

- **`lua/parley/entity_range.lua:61-65` is the right shape of fix.** One predicate, with the comment naming *why* two predicates was the bug — the note that stops a fourth implementation, in the spirit of `fence.lua:9-14` (ARCH-DRY pass on this axis).
- **`tests/unit/entity_range_spec.lua:479-481` asserts the agreement, not the implementation.** It first asserts `lexical.is_fence_delim(delim, true)` is non-nil for each shape, then asserts the wall — so the test pins the *invariant* ("what the memo sees, the wall walls") rather than restating `is_wall`'s body. Verified red without the fix.
- **`atlas/chat/entity_delete.md:100-104` names the concrete failure mode**, not just the new rule — a reader learns what breaks, which is the useful half.
- **The plan's file-set half of BR-20 is now genuinely swept.** All 16 paths in `git diff --name-only 85e116c2..HEAD -- lua/ tests/` resolve somewhere in the plan, including `starter_config.lua` + its spec at `plan.md:82` — the only branch change that alters what packaged-app users receive.
- **`entity_range` is really PURE.** 44 unit tests, zero mocks, run against literal line arrays with no buffer (ARCH-PURE pass — I ran them).

### 2. Critical findings

**C1 — `tests/integration/entity_delete_parity_spec.lua` never completes; its pass is recorded but not real.** *(2nd in family `checkbox-without-artifact`.)*

Measured, 6 runs:

| invocation | env | result |
|---|---|---|
| `make test-spec SPEC=chat/entity_delete` ×3 | default, then fresh `TEST_ENV_ROOT` | exit 1 after 1 / 3 / 6 of 11 tests |
| raw nvim + make-equivalent env ×2 | fresh state dir | exit 1 after 6 / 6 tests, **stderr empty** |
| same, `for row = 1, 4` | fresh | exit 1 after 4 tests |

No `Fail` line, no `Tests Failed. Exit: 1` summary, no crash report in `~/Library/Logs/DiagnosticReports`. nvim exits 1 silently at a nondeterministic point, so the last two `SHAPES` — including `separator-edited-away`, which the M1 round-2 rework added as "the axis BR-2 actually lived on" — and the `never reaches into a header` test never execute. `RUN_SPEC` keys on exit status, so `make test` counts this file FAIL: `make test-integration` on the branch reports it in `=== Failed integration test files ===`. `plan.md` Task 13 Step 2 and Task 15 Step 1 are both `- [x]`.

Calibration: this environment has pre-existing failures (`async_builtin_spec` fails on `main` too; `parley_harness_golden_spec` fails on `main` — neither is this branch's). But `entity_range_spec` and `entity_textobj_spec` pass cleanly here with proper summaries, and the parity spec failed 6/6 including serial runs, so this is not the same flakiness.

Fix sketch — the spec creates ~660 buffers and ~660 files in one process with no teardown (`run()` at `:120-125` calls `fresh()` twice per row and never wipes the buffer; `fresh()` calls `parley.setup()` each time). Give `fresh()` a matching teardown (`bwipeout!` the previous buf, reuse one `parley.setup()`), and make the spec's own exit status part of the evidence: a boundary may not record "watched it pass" for a file whose runner exits non-zero. `base_tmp_dir` at `:16` also hardcodes a `"/claude/"` path segment — an agent-sandbox artifact that has no business in a committed spec.

### 3. Important findings

**I1 — a section range still ends on an opening fence: `section_range` and the `to_end` backward scan read `heading.level` with no in-code filter.** *(3rd in family `range-splits-a-structure`.)*

Per the escalation rule I am **not** naming an instance to patch. The rule:

> `entity_range.range` must classify each row **once** per call, and every walk must consume that one classification. A row is `blank` / `heading` / `fence` / `marker` / `text`, and `in_code[row]` demotes a `heading` to `text`. `is_wall`, `section_range`'s forward scan, and the `to_end` backward scan all read it; no walk may call `heading.level` or a fence predicate directly.

The enumeration the rule implies, all in `lua/parley/entity_range.lua`: `:58` (`heading.level`, in `is_wall`), `:65` (fence, in `is_wall`), `:99` and `:108` (`heading.level`, in `section_range`), `:282` (`heading.level`, in the `to_end` backward scan). Only `:253` consults `in_code`, and it gates only the *cursor* row. BR-21 was site `:58`/`:65` missing the fence; BR-26 was `:65` using a different fence predicate from `:234`; this is `:108` and `:282` using a different heading predicate from `:253`. Same rule, third occurrence.

Measured (real `chat_parser.parse_chat`, both classifications):

```
chat:      ## Section / prose / ```lua / # inner heading / code / ``` / tail
           range(parsed, lines, 8)               -> section 8..10   ← row 10 is ```lua
           range(parsed, lines, 8, {inner=true}) -> section 9..10   ← ie splits it too
markdown:  # Top / alpha / "" / ```lua / # fake / code / ``` / omega
           range(nil, lines, 1)                  -> section 1..4    ← row 4 is ```lua
to_end:    the backward scan at :282 latches onto an in-fence `## fake heading`
           and returns 8..9 where the correct answer is 8..#lines
```

`dae` on that heading leaves a bare closing fence and the rest of the transcript renders as code. `atlas/chat/entity_delete.md:94` states the contract this violates: *"A fence line is never deleted, a range never spans one."*

Guard, at the rule's level rather than per-flavour: extend the existing `entity_range invariants` property test (`entity_range_spec.lua`, "never returns an out-of-range or inverted range") over a fenced fixture and assert that **no returned range contains an odd number of `is_fence_delim` lines**, for every row × `{scope, inner}`. That single invariant would have caught BR-21, BR-26 and I1. The parity spec structurally cannot see any of them — both surfaces share the range function and agree on the wrong answer.

### 4. Minor findings

- `tests/unit/entity_range_spec.lua:486` — dead expression: `body[10]` is computed as `delim:gsub("%S+$",""):gsub("^%s*","") ~= "" and "```" or delim` and then immediately overwritten at `:488`. *(3rd in family `unreachable-guard`; the rule that covers all three: no line in the diff may have zero consumers — the same lens that caught BR-5's dead `floor` parameter and BR-16's both-branches-identical ternary. Delete the computed initializer and build `body[10]` once.)*
- `lua/parley/entity_range.lua:65` — the `require` is still inside `is_wall`, i.e. inside the per-line paragraph walk. BR-26's rule asked for it to move to the module top alongside `heading` at `:31`; the predicate changed but the placement did not.

### 5. Test coverage notes

- The new fence-flavour test is real regression evidence (verified red). Good.
- `entity_range_spec`'s "treats a heading inside a fence as content, not a section" asserts `r == nil or r.kind ~= "section"` — `nil` satisfies it, which is why it passes while BR-27's prose is wrong, and it only ever puts the **cursor on** the in-fence heading. It never starts a section *outside* the fence, which is the hole I1 lives in.
- Nothing in the suite asserts the `to_end` backward scan against an in-fence heading.
- Five of the parity spec's eleven cases have never executed (C1).

### 6. Architectural notes for upcoming work

- **ARCH-DRY — flag.** The fence predicate is now single-sourced (good), but "is this line a structural heading" is still stated two ways: in-code-aware at `:253`, raw at `:99`/`:108`/`:282`. See I1.
- **ARCH-PURE — pass.** No IO leaked into `entity_range`; the new test runs with no mocks and no buffer.
- **ARCH-PURPOSE — flag.** This round answered BR-26 at the site it named and left the enumerable sibling (`section_range`'s scan) in the tree. The ledger's own `family:` slug was reporting the class; the enumeration was not written. See I1 for the enumeration.
- **ARCH-MOCK — N/A/pass.** No external binary or service; Neovim is exercised for real.
- **ARCH-CONSTRAINTS — flag (minor).** Keystroke path; the `require`-per-line at `:65` is bounded by paragraph length so it is not hot, but it is avoidable. The declared envelope remains unguarded (BR-23).
- **ARCH-SECURE — pass.** Buffer text is the untrusted input; malformed/unbalanced fences degrade to `nil` (a no-op) rather than a crash, and `:293` re-checks bounds and inversion before returning.
- **ARCH-ORDER — pass.** `entity_range` carries no state between events; `is_fence_delim` is a pure function of one line. `in_code` is rebuilt per call, so there is no cache to invalidate.
- **ARCH-FUNERAL — pass.** The diff creates no durable artifact. (C1's spec creating ~660 files per run is a residue question, but scoped to a temp dir the harness wipes.)

### 7. Plan revision recommendations

`workshop/plans/000262-delete-entity-at-cursor-plan.md` needs a `## Revisions` entry — the section still ends at *"M1 boundary review round 2"* while the body moved at `f53af775` (`:7, :82, :87, :797, :938`, open item 3) and again in this window (`:978-981`). Append one entry covering both, and fold in these deltas:

1. **`:7` now names a primitive that is no longer reused.** It lists `fence.open_len` among what `entity_range` "reuses"; `a3fcf7ea` removed the only `fence.open_len` call. Replace with `document.lexical.is_fence_delim`, and say that the memo and the wall must name the *same* predicate.
2. **`:53` still cites `ChatPrune (init.lua:4255)` and `ExchangeCut (init.lua:4423)`.** Actual: `4271` and `4439`. The same two symbols were corrected at `:87`/`:938` in this round and missed here — the instance-not-class pattern inside the plan itself.
3. **`:852` cites `init.lua:2803-2812 (chat_exchange_cut)`.** Line 2803 is `chat_search`; the `chat_exchange_cut` idiom is at `2812-2819`.
4. **Task 13 Steps 1-2 and Task 15 Step 1 must be un-ticked** until the parity spec exits 0 (C1). A `- [x]` whose runner returns 1 is the `checkbox-without-artifact` rule.
5. **Record the fence rule as the rule, not the instance** — amend the "Five rules" list (which is six rules in both the plan and `entity_range.lua:10`) to state the single-classification rule from I1, so the next reader inherits the class rather than the three patched sites.

```findings
dispose:
  - id: BR-20
    disposition: not-addressed
    note: |
      File-set half now holds (all 16 branch lua/tests paths resolve; starter_config row at plan.md:82); file:line half does not - plan.md:53 still says ChatPrune init.lua:4255 (4271) and ExchangeCut init.lua:4423 (4439), :852 cites init.lua:2803 as chat_exchange_cut (that line is chat_search), and this round created a new instance: :7 still lists fence.open_len as a reused primitive after a3fcf7ea removed its only call.
  - id: BR-22
    disposition: not-addressed
    note: |
      Empty-range half no longer reproduces (f53af775..8c2e3150 is 6 files), but base is still the previous round's tip, so M2's actual deliverable (e007f6c5, 49064ec4, cb17a0a6) remains outside every M2 window - the parity-spec defect I raise this round lives in cb17a0a6 and has therefore never been in a reviewed range. Prevalence 4 of 7 rounds.
  - id: BR-23
    disposition: not-addressed
    note: |
      No perf spec; atlas:105-116 still carries 13.6/24.7/97.8 ms plus its own admission that nothing guards them. The plan now records the drop as an explicit operator call (Task 13, "Perf module: dropped, measured instead"), so it is a documented residual rather than an oversight - but the declaration is neither guarded nor deleted.
  - id: BR-24
    disposition: not-addressed
    note: |
      entity_delete_parity_spec.lua:78 still declares `local shape = SHAPES[1]` at module scope with fresh() reading it; newly relevant because that spec now aborts nondeterministically and module-scope shared state is what makes such an abort hard to localize.
  - id: BR-25
    disposition: not-addressed
    note: |
      keybinding_registry.lua:483/493/503 unchanged - "dae/yae/cae", "die/yie/cie", then "(daE)" alone.
  - id: BR-26
    disposition: addressed
    note: |
      entity_range.lua:65 now calls lexical.is_fence_delim(line, true), the same predicate and tildes flag code_block_memo uses at :234-235; scratch-reverting that one line turns entity_range_spec red (43 pass / 1 fail), so the regression evidence is real. Residual: the require still sits inside the per-line is_wall loop, which the rule asked to remove.
  - id: BR-27
    disposition: not-addressed
    note: |
      atlas:94-95 unchanged - still says a "# heading" inside a fence "is content rather than a section" where range() returns nil; entity_range.lua:10 still opens "Five rules, each stated once" over six rules and still omits the fence rule. The added paragraph at atlas:100-104 is accurate but sits above the two sentences the finding named.
  - id: BR-28
    disposition: not-addressed
    note: |
      This window edits plan.md:978-981 and the Revisions section still ends at "M1 boundary review round 2"; no entry for the f53af775 edits either.
findings:
  - id: new
    severity: Critical
    family: checkbox-without-artifact
    title: |
      the parity spec - the milestone's named best guard - exits 1 without completing, while the plan ticks it as passing
    detail: |
      2nd finding in family checkbox-without-artifact. tests/integration/entity_delete_parity_spec.lua exits 1 with an EMPTY stderr and no busted summary, aborting after a nondeterministic subset of its 11 tests. Measured 6 of 6 runs - `make test-spec SPEC=chat/entity_delete` stopped after 1, 3 and 6 tests (the third with a fresh TEST_ENV_ROOT), a make-equivalent raw invocation stopped after 6 twice, and a variant limited to `for row = 1, 4` stopped after 4. No crash report in ~/Library/Logs/DiagnosticReports. So the last two SHAPES - including `separator-edited-away`, added by the M1 round-2 rework as "the axis BR-2 actually lived on" - and the `never reaches into a header` test have never executed. RUN_SPEC keys on exit status, so `make test-integration` on this branch lists the file under "Failed integration test files"; plan.md Task 13 Step 2 ("Run it and watch it pass") and Task 15 Step 1 (`make test`) are both ticked. Calibration - this environment has pre-existing failures (async_builtin_spec and parley_harness_golden_spec fail on main too, neither is this branch's), but entity_range_spec and entity_textobj_spec pass cleanly here with proper summaries. THE RULE - a boundary may not record "watched it pass" for a spec file whose runner exits non-zero; the exit status is the evidence, not the Success lines that precede the abort. Likely cause to start from: run() at :120-125 calls fresh() twice per row and never wipes the buffer, so one process accumulates ~660 buffers, ~660 files and ~660 parley.setup() calls with no teardown. Also note base_tmp_dir at :16 hardcodes a "/claude/" path segment - an agent-sandbox artifact that should not be in a committed spec.
  - id: new
    severity: Important
    family: range-splits-a-structure
    title: |
      section_range and the to_end backward scan read heading.level with no in-code filter, so a section range ends ON the opening fence
    detail: |
      3rd finding in family range-splits-a-structure. Do NOT patch section_range alone. THE RULE - entity_range.range must classify each row ONCE per call and every walk must consume that one classification - blank / heading / fence / marker / text, with in_code[row] demoting a heading to text - so that is_wall, section_range's forward scan and the to_end backward scan cannot disagree. The enumeration the rule implies, all in lua/parley/entity_range.lua - :58 (heading.level in is_wall), :65 (fence in is_wall), :99 and :108 (heading.level in section_range), :282 (heading.level in the to_end backward scan). Only :253 consults in_code, and only for the cursor row. BR-21 was :58/:65 missing the fence; BR-26 was :65 using a different fence predicate from :234; this is :108 and :282 using a different heading predicate from :253. Measured with real chat_parser.parse_chat - chat buffer `## Section / prose / ```lua / # inner heading / code / ``` / tail` gives range(parsed, lines, 8) -> section 8..10 where row 10 is the ```lua opener, and {inner=true} gives 9..10; plain markdown `# Top / alpha / "" / ```lua / # fake / code / ``` / omega` gives range(nil, lines, 1) -> section 1..4, again ending on the opener. dae there leaves a bare closing fence and the rest of the transcript renders as code - the same corruption and the same undo-recoverable severity BR-21 carried. Separately the to_end backward scan at :282 latches onto an in-fence heading and returned 8..9 where the correct answer was 8..#lines. This contradicts atlas/chat/entity_delete.md:94, which states "A fence line is never deleted, a range never spans one". GUARD at the rule's level, not per flavour - extend the existing `entity_range invariants` property test over a fenced fixture and assert that no returned range contains an ODD number of is_fence_delim lines, for every row x {scope, inner}; that one invariant catches BR-21, BR-26 and this at once. The parity spec structurally cannot see any of them - both surfaces share the range function and agree on the wrong answer.
  - id: new
    severity: Minor
    family: unreachable-guard
    title: |
      dead assignment in the new fence-flavour test - body[10] is computed and then immediately overwritten
    detail: |
      3rd finding in family unreachable-guard. tests/unit/entity_range_spec.lua:486 initializes body[10] to `delim:gsub("%S+$", ""):gsub("^%s*", "") ~= "" and "```" or delim`, which :488 discards. THE RULE covering BR-5 (section_range's dead floor parameter), BR-16 (a ternary whose two branches are both 2) and this - no line in the diff may have zero consumers; a value that nothing reads is either a missing call site or dead code, and review should resolve which before the boundary. Here it is dead code: delete the computed initializer and build body[10] once.
```
