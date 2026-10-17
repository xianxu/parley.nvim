# Boundary Review — parley.nvim#354 (milestone M2)

| field | value |
|-------|-------|
| issue | 354 — Attention finder: a floating list of Alt+Return submissions (waiting / answered / seen), restoring each one's breadcrumb |
| repo | parley.nvim |
| issue file | workshop/issues/000354-attention-finder-a-floating-list-of-alt-return-submissions-waiting-answered-seen-restoring-each-one-s-breadcrumb.md |
| boundary | milestone M2 |
| milestone | M2 |
| window | 75a8c85ef7c44f48296e9d0d9f8ef74d2b28e9af..3c39600b8ba6265429f04c07f0524444ae30499b |
| command | sdlc milestone-close --issue 354 --milestone M2 |
| reviewer | claude |
| isolation | fenced |
| timestamp | 2026-10-16T15:28:33-07:00 |
| verdict | FIX-THEN-SHIP |

## Review

I'm checking whether the finder's cursor-keeping on repaint actually works with float_picker's identity function.

Confirmed a misplaced paragraph in the keybindings atlas. Now running the M2 specs.

Specs produced no summary lines; checking the raw output to see why.

All 66 tests pass. Checking the stray "Error in command line" in the record spec, then probing key guarantees by mutation.

```verdict
verdict: FIX-THEN-SHIP
confidence: high
```

M2 delivers what the plan describes. The changes are:

- a pure `attention_rows`;
- `refresh` and `open` in the `attention` glue, which probe at most 4 at a time and repaint by row identity;
- the `<M-u>` registry entry, its config key and `:ParleyAttention`;
- the fake Couch's `owe` helper;
- a 10-case finder spec and a 5-case rows spec;
- updates to README, the atlas and traceability.

I ran all five mapped specs through the harness (`make test-spec SPEC=ui/attention_finder`): 66 tests, 0 failed, 0 errors.

One Important gap is left. The plan's own named guard is the probe-start capture of pending IDs (PQ-2, ARCH-ORDER). The model enforces it, but no test pins it in the glue that decides *when* the IDs are captured. I moved the capture from probe start into the probe's callback in `lua/parley/attention.lua:175-178`, which brings back the stale-probe bug, and all 66 tests stayed green. I then restored the checkout. Everything else is Minor.

**1. Strengths**
- **A failed or ledger-less probe can never read as answered.** `M.observation` (`lua/parley/attention.lua:138-150`) turns a nil `couch.query` reply, and a reply with a null `Status`, into `observe_failed`. The "no Couch ledger" case is pinned (`tests/integration/attention_finder_spec.lua:546-562`).
- **The cursor stays on its row during the async repaint.** The repaint passes `handle.selected().value` as `update`'s identity argument, which matches float_picker's default `recall_id_fn` (it returns `item.value`, `float_picker.lua:650`).
- **The probe limit is checked against the real fake.** The spec runs 9 entries through a counter wrapped around the real `couch.query` and asserts a peak of exactly 4, then 0 (`attention_finder_spec.lua:564-578`).
- **Rows are pure and tested whole.** Each state's row checks the text, the highlight span, the value and the search text together, and the clock is injected (`tests/unit/attention_rows_spec.lua`).
- **Late results still reach the store.** A probe result that lands after the finder closed still writes to the store, and the real float_picker `update` returns early when closed (`float_picker.lua:1744`).

**2. Critical findings**

None.

**3. Important findings**
- **`declared-ordering-untested` (2nd finding in this family): the probe-start capture has no test in the glue** (`lua/parley/attention.lua:175-178`, ARCH-ORDER).
  - The model test pins the stale probe, but only for a `probed_ids` handed to it directly.
  - Nothing checks that `refresh` captures the IDs *before* `seam.run`.
  - **Rule:** every interleaving listed under the plan's ARCH-ORDER section needs at least one test that drives the *production glue* through that ordering. Model-level tests don't count, because they can't see when the glue captures state.
  - **Sweep of the plan's ARCH-ORDER list:**
    - two editors at once: covered by the store's held-lease specs;
    - an observation after close: covered;
    - a failed probe: covered;
    - the 14-day trim: covered, since it is equivalent to a fold;
    - a stale probe against a newer submit: **uncovered in the glue**.
  - **Fix sketch:** in `attention_finder_spec`, inject a `run` that holds its callback. Open the finder, let the probe for `a.md` start, record a second submit `m2` (owed), fold `m1`, then release the held callback with the earlier reply. Assert that the entry is still waiting with `m2` pending. That test fails under the mutation described above.

**4. Minor findings**
- **Misplaced paragraph** (`atlas/ui/keybindings.md:41-49`): the new `## Attention finder` section was inserted above the file-history sentence "Markdown buffer preparation consults the read-only restoration scope…". That sentence now sits under the wrong heading. Move it back above the new section.
- **Unchecked external claim** (`atlas/ui/keybindings.md:47`): "Couch's own key help lists it via pair#619" asserts pair work this repo can't check. The plan's Revisions say that work was only handed to the TL to file.
- **Plan/code drift on the failure reason:** the plan says `observe_failed` carries "the Couch `Code`". The code records fixed strings instead, because `couch.query` returns nil for any Code other than `ok`, so the Code never reaches `observation`.
- **Step order differs from the plan:** `select` restores the breadcrumb *before* applying `opened` (`attention.lua:211-217`), while the plan orders it open → `opened` → restore. This makes no behavioral difference.
- **Probe limit is per refresh, not global:** opening the finder twice in quick succession starts two refreshes, so up to 8 `couch` processes run at once and probes are duplicated. This is low impact (ARCH-CONSTRAINTS).
- **Write churn:** every `observed` result rewrites the store file, even when nothing changed (all IDs still owed). With 50 waiting entries, that is 50 atomic writes per open.

**5. Test coverage notes**
- Mapped specs: 66 pass. The "Error in command line" in `attention_record_spec` is the expected "no such peer" notification, not a failure.
- I confirmed the gap above by mutation, and restored the checkout afterwards (clean `git status`).
- The plan lists "typeahead" in the strategy. It is covered only by the unit `search_text` assertion, not by a filter driven through the finder. That is acceptable, since the fuzzy matching belongs to float_picker.
- The selection specs pass `run = function() end`, so their refresh never completes. That is fine for testing selection, but none of them exercises a selection that races a repaint.

**6. Architectural notes**

| Principle | Result | Note |
|---|---|---|
| ARCH-DRY | pass | `M.record` now reuses the module-level `Store`. The fake's `owe` and `fold` share one `ledger` helper. Defining highlights locally matches existing modules (float_picker, init). |
| ARCH-PURE | pass | `attention_rows` and `observation` are pure. IO stays in `refresh` and `select`. |
| ARCH-PURPOSE | pass | Every M2 surface in the plan is delivered. The winbar count is out of scope by TL decision. |
| ARCH-MOCK | pass | The stateful registry fake now supports `owe` and `fold`. The conformance script is `scripts/check-couch-registry-conformance.py`. |
| ARCH-CONSTRAINTS | pass, with Minor notes | The picker renders immediately. Probes are async and bounded. The sweep write runs before the picker opens, but a busy lease delays it by at most about 250 ms. |
| ARCH-SECURE | pass | Paths go through `fnameescape`, couch arguments are argv arrays, and the breadcrumb from the persisted store is handed to #353's validating `restore` without the finder reading its fields. |
| ARCH-ORDER | flagged | See the Important finding. The state machine itself is sound: every change goes through `Store.apply` → `Model.transition`. |
| ARCH-FUNERAL | pass | M2 creates nothing durable beyond the existing store. Probes still running after close end when Couch replies. |

When #353 lands, add one integration test using the real `file_history.restore` in place of the injected seam.

**7. Plan revision recommendations**
- Under "building M2": `observe_failed` reasons are fixed strings, because `couch.query` hides Codes other than `ok`.
- Under "building M2": `select` restores the breadcrumb before applying `opened`.

```findings
findings:
  - id: new
    severity: Important
    kind: defect
    family: declared-ordering-untested
    title: |
      The probe-start capture of pending IDs (PQ-2) has no test in the refresh glue
    detail: |
      2nd finding in family declared-ordering-untested. Mutation: in lua/parley/attention.lua:175-178, moving the Store.load()/vim.tbl_keys(entry.pending) capture into the seam.run callback brings back the stale-probe bug, and all 66 mapped specs stay green. Rule: every interleaving in the plan's ARCH-ORDER list needs a test that drives the production glue, not only the pure model. Sweep: two editors (store lease specs), observation after close (covered), failed probe (covered), 14-day trim (same as fold, covered), stale probe vs newer submit (glue UNCOVERED). Fix: in attention_finder_spec, inject a run that holds its callback; while it is held, record and owe m2 and fold m1; then release and assert the entry is still waiting with m2 pending.
  - id: new
    severity: Minor
    kind: defect
    family: doc-section-misplacement
    title: |
      keybindings.md: the Attention finder section was inserted above a file-history sentence, which now sits under the wrong heading
    detail: |
      atlas/ui/keybindings.md:41-49: "Markdown buffer preparation consults the read-only restoration scope..." belongs to File history (Back), but now appears under "## Attention finder". The same section also claims "Couch's own key help lists it via pair#619", which this repo cannot check.
  - id: new
    severity: Minor
    kind: defect
    family: plan-code-drift
    title: |
      observe_failed records fixed reasons, not the Couch Code the plan specifies
    detail: |
      couch.query returns nil for any Code other than ok, so M.observation (lua/parley/attention.lua:138-143) cannot see the Code. Record this in the plan's Revisions, or pass the Code through.
```

<!-- sdlc-review-usage [{"version":1,"intent":{"disposable_root":true,"id":"ac0e7c3b-18f3-40f2-8632-a36f9eb6d313","repository":"github.com/xianxu/parley.nvim","issue_id":"000354","recipe":"milestone-review","round":3,"attempt":1,"agent":"claude","root":"/Users/xianxu/Library/Caches/sdlc/review-checkouts/95ffd20a2dc657d2","reviewed_head":"3c39600b8ba6265429f04c07f0524444ae30499b","slot":"parley.nvim:3","requested_at":"2026-10-16T22:26:05.2624Z"},"phase":"finished","pid":55050,"started_at":"2026-10-16T22:26:05.408673Z","finished_at":"2026-10-16T22:28:33.100648Z","session_id":"8baf142f-7d2d-491b-97f9-e2325ceec64d","outcome":"returned"}] -->

---

## Re-review — 2026-10-16T15:33:53-07:00 (FIX-THEN-SHIP)

| field | value |
|-------|-------|
| issue | 354 — Attention finder: a floating list of Alt+Return submissions (waiting / answered / seen), restoring each one's breadcrumb |
| repo | parley.nvim |
| issue file | workshop/issues/000354-attention-finder-a-floating-list-of-alt-return-submissions-waiting-answered-seen-restoring-each-one-s-breadcrumb.md |
| boundary | milestone M2 |
| milestone | M2 |
| window | 75a8c85ef7c44f48296e9d0d9f8ef74d2b28e9af..e5723e33b319a38509eb28a3bb3942288bad707d |
| command | sdlc milestone-close --issue 354 --milestone M2 |
| reviewer | claude |
| isolation | fenced |
| timestamp | 2026-10-16T15:33:53-07:00 |
| verdict | FIX-THEN-SHIP |

## Review

Now mutation-test BR-8: move the capture into the callback and run the spec.

Finding the test runner so I can revert the BR-8 fix and check the spec goes red.

All 67 tests pass. Next I'm moving the probe-start capture into the callback to check that the BR-8 test fails without the fix.

BR-8's test fails under the mutation and the tree is restored. Now scanning the rest of the M2 diff for new issues.

Checking the plan's ARCH-CONSTRAINTS envelope and the M2 task list against the code.

```verdict
verdict: FIX-THEN-SHIP
confidence: high
```

M2 delivers what the plan describes. The pure `attention_rows.items` builds the finder rows. `attention.observation` refuses to treat a failed or ledger-less probe as an answer. `refresh` caps probes at 4 and captures each entry's pending IDs when its probe starts. `open` and `select` restore the breadcrumb through #353's seam. The keybinding, config key, README, atlas and traceability are all updated. All 67 mapped specs pass (`make test-spec SPEC=ui/attention_finder`, rc=0).

I checked the BR-8 fix by mutation. Moving the `Store.load()`/`vim.tbl_keys` capture into the `seam.run` callback makes "a probe that started before a newer submit leaves that submit waiting" fail, and the other 66 stay green. I then restored the tree and confirmed `git status` was clean.

One thing stands between this and SHIP. Task 5 Step 1 is ticked, and its strategy names a typeahead test and promises that a repaint keeps the cursor on its row. Neither exists. The fake picker ignores `update`'s third argument and supplies its own after-close guard, so the real `float_picker` path is never exercised.

1. **Strengths**
   - `lua/parley/attention.lua:61-75`: `observation` is pure and checks the type of every field it reads (`Status`, `Owed`, `ID`). With no ledger it returns `observe_failed`, never an empty `Owed`. ARCH-SECURE: passes.
   - `lua/parley/attention.lua:102-105`: the capture happens before the probe starts, and the new spec at `tests/integration/attention_finder_spec.lua:175-195` drives the production glue with a held `run`. The mutation test proves it.
   - `tests/helpers/fake_couch.lua:47-63`: the owe and fold edits share one `ledger` helper, and the fake registry keeps state across calls. ARCH-DRY and ARCH-MOCK (for Couch): pass.
   - `lua/parley/attention_rows.lua`: pure, with no IO. The clock is injectable, and the tests run without mocks. ARCH-PURE: passes.

2. **Critical:** none.

3. **Important**
   - **Typeahead and cursor-keeping are untested** (`tests/integration/attention_finder_spec.lua:35-52`; plan Task 5 Step 1). This is the 2nd finding in family `plan-test-strategy-drift`. The rule: every case a ticked strategy line names either maps to a spec that drives the production widget, or a Revisions entry records the drop. Sweeping Task 5's list:
     - The typeahead case is missing.
     - "Keeping the cursor on its row" is asserted nowhere, because the fake `update` drops `next_selection`.
     - The "observation after close" case tests the fake's own `if picker.closed` guard, not `float_picker.lua:1744`.
     - The other cases map to specs.

     Fix sketch: add one spec on the real `float_picker`. Open it, type a filter, let a fold land, then assert the filter holds and the selected value is unchanged. Alternatively, record in Revisions that typeahead is left to `float_picker`'s own specs.

4. **Minor**
   - The `couch status` probes run with no timeout (`attention.lua:105` → `couch.run`). A hung `couch` holds one of the 4 slots indefinitely, and `on_refreshed` never fires. The plan calls these "short runs" but does not bound them (ARCH-CONSTRAINTS, ARCH-ORDER extent).
   - `select` (`attention.lua:136`): if `:edit` raises, `on_done` is never called and `opened` is never applied. Rare, since `hidden` is on by default.
   - The "is bound" test checks the registry and config tables, not that the `<M-u>` mapping actually calls `open`.

5. **Test coverage notes:** every interleaving in the plan's ARCH-ORDER list now has a spec that drives production code: the lease, observation after close, failed probe, stale probe, and trim (the same path as a fold). The unit model specs include 200 seeded event sequences. The only gap is the real-picker integration above.

6. **Architectural notes**
   - ARCH-DRY: pass.
   - ARCH-PURE: pass.
   - ARCH-PURPOSE: pass. Every Done-when surface for M2 is delivered.
   - ARCH-MOCK: Couch passes, with a stateful fake on the same `run` seam. The picker fake is stateless and restates the guard (the Important finding). The live conformance check is staged as the operator's smoke test.
   - ARCH-CONSTRAINTS: concurrency is bounded at 4 and the UI path never waits. Duration is unbounded (Minor).
   - ARCH-SECURE: pass. Commands are built as argv arrays, paths go through `fnameescape`, and replies are type-checked.
   - ARCH-ORDER: pass. Changes go through `Store.apply` → `transition`, and the stale probe is pinned through the glue.
   - ARCH-FUNERAL: pass. M2 creates nothing durable beyond M1's bounded store. Probe processes end when they exit, apart from the timeout gap.

7. **Plan revisions:** add a Revisions entry for M2 that either names the typeahead/cursor spec once it is added, or records that typeahead coverage is left to `float_picker`'s own specs and the Task 5 strategy line is narrowed to match.

```findings
dispose:
  - id: BR-8
    disposition: addressed
    note: |
      Mutation verified: moving the capture into the seam.run callback fails "a probe that started before a newer submit leaves that submit waiting"; the other 66 mapped specs stay green; tree restored.
  - id: BR-9
    disposition: addressed
    note: |
      atlas/ui/keybindings.md: the restoration-scope sentence is back under File history, and the pair#619 line now reads as pending work ("Adding it to Couch's own key help is pair#619").
  - id: BR-10
    disposition: addressed
    note: |
      Plan Revisions (M2 review) records the fixed reasons; lua/parley/couch.lua:41 confirms query returns nil for any Code other than ok, so the Code is not visible to observation.
findings:
  - id: new
    severity: Important
    kind: defect
    family: plan-test-strategy-drift
    title: |
      Task 5's ticked strategy names typeahead and cursor-keeping on repaint, but no spec drives the real float_picker
    detail: |
      2nd finding in the family. Rule: every case a ticked strategy line names maps to a spec driving the production widget, or a Revisions entry records the drop. Sweep of Task 5: typeahead is missing; cursor-keeping is unasserted because the fake update in tests/integration/attention_finder_spec.lua:41 ignores next_selection; the after-close spec tests the fake's own closed guard, not float_picker.lua:1744; the other cases are covered. Fix: one real-float_picker spec (type a filter, land a fold, assert the filter and selection hold), or a Revisions entry narrowing the strategy.
  - id: new
    severity: Minor
    kind: defect
    family: optional-work-on-critical-path
    title: |
      Attention probes have no timeout, so a hung couch holds a slot and on_refreshed never fires
    detail: |
      lua/parley/attention.lua:105 calls couch.query, which uses couch.run with no timeout option. The plan's ARCH-CONSTRAINTS calls these short runs but does not bound their duration or extent. Pass a timeout through couch.run and treat expiry as observe_failed.
```

<!-- sdlc-review-usage [{"version":1,"intent":{"disposable_root":true,"id":"f506e27f-dabe-4cc3-9282-e83de460e837","repository":"github.com/xianxu/parley.nvim","issue_id":"000354","recipe":"milestone-review","round":4,"attempt":1,"agent":"claude","root":"/Users/xianxu/Library/Caches/sdlc/review-checkouts/d236f5864df94f61","reviewed_head":"e5723e33b319a38509eb28a3bb3942288bad707d","slot":"parley.nvim:3","requested_at":"2026-10-16T22:31:01.269806Z"},"phase":"finished","pid":87459,"started_at":"2026-10-16T22:31:01.705126Z","finished_at":"2026-10-16T22:33:52.350666Z","session_id":"beca28fc-9498-4964-8b2f-fbcdad48a6bf","outcome":"returned"}] -->

---

## Re-review — 2026-10-16T15:57:38-07:00 (FIX-THEN-SHIP)

| field | value |
|-------|-------|
| issue | 354 — Attention finder: a floating list of Alt+Return submissions (waiting / answered / seen), restoring each one's breadcrumb |
| repo | parley.nvim |
| issue file | workshop/issues/000354-attention-finder-a-floating-list-of-alt-return-submissions-waiting-answered-seen-restoring-each-one-s-breadcrumb.md |
| boundary | milestone M2 |
| milestone | M2 |
| window | 75a8c85ef7c44f48296e9d0d9f8ef74d2b28e9af..f2b9a172c87bb89e9d1498c2b0f53fd78841c2c6 |
| command | sdlc milestone-close --issue 354 --milestone M2 |
| reviewer | claude |
| isolation | fenced |
| timestamp | 2026-10-16T15:57:38-07:00 |
| verdict | FIX-THEN-SHIP |

## Review

Reviewing the M2 diff; next I'm running the attention specs.

All pass. Now mutation-checking the BR-11 and BR-12 fixes.

Now the mutations: drop the repaint's selection identity (BR-11), and drop the probe timeout (BR-12).

Both fixes go red when reverted. Next I'm checking how the store handles a refused `batch`, and the side-doc scope in the issue.

Checking for existing helpers the side-doc scan duplicates (side folder path, frontmatter type).

```verdict
verdict: FIX-THEN-SHIP
confidence: high
```

M2 does what the issue asks. The finder lists entries straight from the store and then probes Couch, at most 4 at a time with a 5 s timeout. A failed or timed-out probe, or a reply with no ledger, only marks the row `?` and never reads as answered. Selecting an entry opens the file, marks it seen and restores the breadcrumb. Side docs the agent writes show up as answered and leave by the same rule. All five attention spec files pass under `make test-spec SPEC=ui/attention_finder`: finder 17, record 12, model 31, rows 6, store 15.

I tested both prior fixes by reverting them in the checkout:
- **BR-11:** dropping the selection identity from the repaint (`handle.update(items(next_state))`) makes the real-picker spec "keeps the typed filter and the selected row across a live repaint" fail.
- **BR-12:** dropping `{ timeout = seam.timeout }` makes "a probe that outlives its timeout reads as failed" fail.

I restored the file after each revert. One new Important finding should be fixed before shipping. The side-doc scan, added in the last commit, writes its own frontmatter parser and its own side-folder path rule even though the codebase already has both. The copy gives different answers on real input.

**1. Strengths**
- `attention.lua:151–163` turns a probe reply into an event in one place, `observation`. Only a reply that has a `Status` ledger counts as evidence; a nil reply, a null `Status` or a timeout becomes `observe_failed`. This closes the case the plan names as most likely to go wrong.
- The real-`float_picker` spec (`tests/integration/attention_finder_spec.lua`, "keeps the typed filter…") checks something real. A newer row lands above the cursor during a filtered repaint, and Enter still opens the row the operator chose. It fails when the fix is reverted.
- Side-doc discovery and the store write don't race. `discover` reads outside the lease, but the model's `discovered` handler re-checks `entries` and `retired` under the lease (`attention_model.lua:414`), so two editors discovering the same doc are harmless.
- `retired` is bounded at 256 with oldest-first eviction, and a test covers it (`attention_model_spec.lua`, "the retired set stays bounded").
- The store parse covers the new `retired` field, with corruption cases for a scalar set and a string time.

**2. Critical findings:** none.

**3. Important findings**
- **The side-doc scan duplicates two existing helpers, and the copies disagree (ARCH-DRY).**
  - `lua/parley/attention.lua:120–128`: `is_side_doc` hand-parses frontmatter. `parley.frontmatter.parse` already owns that and is what `session_sync.parse_header` uses. The two disagree:
    - `type: side-doc # agent answer` is missed by `is_side_doc`, but `frontmatter.parse` strips the comment.
    - An unclosed fence still matches in `is_side_doc`; `frontmatter.parse` returns nil.
    - A `Type:` key is lower-cased by `frontmatter.parse` but not by `is_side_doc`.
  - `lua/parley/attention.lua:140`: the side folder is rebuilt with `fnamemodify(path, ":r") .. ".side"`. `document_move_plan.side_path` (`lua/parley/document_move_plan.lua:28`) is the existing rule for this.
  - **Fix:**
    - `is_side_doc = function(lines) local fm = require("parley.frontmatter").parse(lines); return fm ~= nil and fm.fields.type == "side-doc" end`
    - `folder = require("parley.document_move_plan").side_path(entry.path)`
    - Add a `# comment` case to the `is_side_doc` spec.

**4. Minor findings**
- **A refused `batch` warns about `nil`.** When all 256 entries are waiting, `handlers.batch` returns `"full"`. The store then warns `256 files are waiting; nil was not recorded` (`attention_store.lua:133`, which reads `event.path` from a batch event that has none). It repeats on every finder open. Name the dropped side doc(s), or say "side docs" when the event is a batch.
- **The plan and atlas don't match the code after the side-doc addition.**
  - The plan's ARCH-CONSTRAINTS still says "Opening the finder reads one file … and renders at once". The finder now renders only after a sweep write, a synchronous scan of up to 256 `.side/` folders, and a batch write; each write can wait out the 10×25 ms busy-lease retry.
  - The atlas says "only new files count, not rewrites". In fact a side doc that existed before its parent entered the finder is discovered if the agent rewrites it, because the check is `mtime > recorded_at`.
  - This is the 2nd finding in family `plan-code-drift`. The rule: a scope addition re-checks every cross-cutting section of the plan (Core concepts state/events, ARCH-CONSTRAINTS, ARCH-ORDER, ARCH-FUNERAL) and the atlas claims, and updates each one the addition changes.
- `discover` uses a strict `mtime.sec > since`, so a side doc written in the same second as the submit is never listed.
- An older parley build reading the new file keeps side entries as plain entries, then drops `retired` when it writes. A later scan by a current build then rediscovers retired docs. This matters only with mixed versions; the format stays `version = 1`.

**5. Test coverage notes**
- Both prior fixes are pinned by specs that fail when the fix is removed.
- Side docs are covered end to end on a real temp filesystem: listing, the before-parent cutoff, seen then swept then retired, and nested discovery on the next open. Rows, model and store each have unit specs.
- Missing: a frontmatter case with a trailing comment or quoting (this would catch the Important finding), and a spec for a refused `batch`.

**6. Architectural notes**
- **ARCH-DRY: flag** (the Important finding).
- **ARCH-PURE: pass, with a note.** The model and rows are pure. The scan's admission rule (which time is "since", the retired and entry checks) is in the IO glue; it could be a pure `discoverable(entry, file_stat)` with the scan as a thin shell.
- **ARCH-PURPOSE: pass.** Every Done-when item is delivered except the operator's live check, which the plan leaves to the TL.
- **ARCH-MOCK: pass.** The fake Couch keeps owed and folded state and gained `owe` and a `delay` mode; production and tests share the `couch.query` seam.
- **ARCH-CONSTRAINTS: pass.** Probes are capped at 4 concurrent with a 5 s timeout. The scan's cost isn't stated anywhere (Minor above).
- **ARCH-SECURE: pass.**
  - The store parse handles `retired` safely.
  - Side-doc reads go through `pcall` and stop at 12 lines.
  - A symlinked `.md` is read but only matched against frontmatter.
- **ARCH-ORDER: pass.** Discovery is idempotent under the lease, and late probes still reach the store after the real picker closes.
- **ARCH-FUNERAL: pass.** Entries are capped at 256 and so is `retired`.

**7. Plan revision recommendations**
- Add a Revisions entry for side docs, or extend the existing one, that:
  - updates ARCH-CONSTRAINTS: opening the finder runs the sweep write, a synchronous scan of at most 256 `.side/` folders reading at most 12 lines per candidate, then one batch write, before it renders;
  - records that discovery reuses `frontmatter.parse` and `document_move_plan.side_path`;
  - states that "new" means `mtime` after the parent entered the finder, so a rewrite of a side doc that predates the parent does count.
- Bring Core concepts in line: add `retired`, `kind`, `parent` and `recorded_at` to the state shape, `discovered` and `batch` to the event list, and the `↳` marker to `attention_rows`.

```findings
dispose:
  - id: BR-11
    disposition: addressed
    note: |
      The real-float_picker spec "keeps the typed filter and the selected row across a live repaint" drives typeahead, cursor-keeping and Enter. Reverting update's third argument fails it (tested in the checkout). The after-close case now also runs on the real picker.
  - id: BR-12
    disposition: addressed
    note: |
      couch.query passes options through to vim.system, and refresh sets timeout 5000. The spec "a probe that outlives its timeout reads as failed" uses the fake's delay mode; removing the timeout fails it (tested in the checkout).
findings:
  - id: new
    severity: Important
    kind: defect
    family: reuse-existing-owner
    title: |
      attention.is_side_doc and discover re-implement frontmatter.parse and document_move_plan.side_path, and disagree with them
    detail: |
      lua/parley/attention.lua:120-128 hand-parses frontmatter. Compared with parley.frontmatter.parse (used by session_sync.parse_header), it misses `type: side-doc # comment`, accepts an unclosed fence, and does not lower-case the key. attention.lua:140 rebuilds the side folder with fnamemodify(":r") instead of document_move_plan.side_path (document_move_plan.lua:28). Fix: use frontmatter.parse(head).fields.type == "side-doc" and side_path(entry.path), and add a spec case with a trailing comment. Rule: a fact the codebase already parses or derives is read through its existing owner.
  - id: new
    severity: Minor
    kind: defect
    family: plan-code-drift
    title: |
      The side-doc addition left the plan's ARCH-CONSTRAINTS and the atlas's "only new files" claim out of date
    detail: |
      This is the 2nd plan-code-drift finding. Rule: a scope addition re-checks every cross-cutting plan section (Core concepts state/events, ARCH-CONSTRAINTS, ARCH-ORDER, ARCH-FUNERAL) and the atlas claims, and updates each it changes. Here, the finder now renders only after a sweep write, a synchronous scan of up to 256 .side folders, and a batch write, but the plan still says "reads one file and renders at once". The atlas says rewrites don't count, yet a side doc that predates its parent's entry is discovered once rewritten (the check is mtime > recorded_at).
  - id: new
    severity: Minor
    kind: defect
    family: warning-names-missing-subject
    title: |
      A refused side-doc batch warns "256 files are waiting; nil was not recorded" on every open
    detail: |
      attention_store.lua:133 formats event.path, which a batch event has no value for. Name the dropped side docs, or say "side docs" when the event is a batch.
```

<!-- sdlc-review-usage [{"version":1,"intent":{"disposable_root":true,"id":"bc58da1e-10da-4ce3-9c36-79be2deb6bc9","repository":"github.com/xianxu/parley.nvim","issue_id":"000354","recipe":"milestone-review","round":5,"attempt":1,"agent":"claude","root":"/Users/xianxu/Library/Caches/sdlc/review-checkouts/07bf68763c799bb2","reviewed_head":"f2b9a172c87bb89e9d1498c2b0f53fd78841c2c6","slot":"parley.nvim:3","requested_at":"2026-10-16T22:53:28.213144Z"},"phase":"finished","pid":30585,"started_at":"2026-10-16T22:53:28.63124Z","finished_at":"2026-10-16T22:57:36.669257Z","session_id":"8f87ae8a-127a-4467-9299-ab502c215238","outcome":"returned"}] -->

---

## Re-review — 2026-10-16T16:10:32-07:00 (FIX-THEN-SHIP)

| field | value |
|-------|-------|
| issue | 354 — Attention finder: a floating list of Alt+Return submissions (waiting / answered / seen), restoring each one's breadcrumb |
| repo | parley.nvim |
| issue file | workshop/issues/000354-attention-finder-a-floating-list-of-alt-return-submissions-waiting-answered-seen-restoring-each-one-s-breadcrumb.md |
| boundary | milestone M2 |
| milestone | M2 |
| window | 75a8c85ef7c44f48296e9d0d9f8ef74d2b28e9af..4fdadd497d3754c4d572a44ed7dc60dc658d1732 |
| command | sdlc milestone-close --issue 354 --milestone M2 |
| reviewer | claude |
| isolation | fenced |
| timestamp | 2026-10-16T16:10:32-07:00 |
| verdict | FIX-THEN-SHIP |

## Review

I've checked the last fix commit against its owners (frontmatter.parse, side_path, async_operation_queue). Next I'll run the attention specs.

Running the attention specs now.

```verdict
verdict: FIX-THEN-SHIP
confidence: high
```

All three open findings are fixed, and the fixes are backed by tests. BR-13: `is_side_doc` now reads frontmatter through `frontmatter.parse`, the side folder comes from `document_move_plan.side_path`, and the probe loop (also hand-rolled) now runs through `async_operation_queue`. BR-14: the plan's Revisions entry and the atlas now describe the real cost of opening the finder and what "new" means. BR-15: a refused batch now says "new side docs were not recorded". I ran the specs `make test-spec SPEC=ui/attention_finder` maps to (5 files, 81 tests): all pass. I then put the old `is_side_doc` back and the spec went red ("reads the side-doc type from frontmatter only"), so the BR-13 regression test catches the bug. Nothing blocks shipping. One new Minor finding: a probe whose start raises is recorded with the wrong failure reason.

1. **Strengths**
   - `lua/parley/attention.lua:115-118`: `is_side_doc` is now two lines over the shared parser. Closed-block, case-folded-key and trailing-comment handling come from the parser instead of being copied. The spec has the comment case and the unclosed-block case.
   - `lua/parley/attention.lua:93-110`: the fix covered the whole class, not just the reported site. The hand-rolled bounded probe loop was replaced by the existing `async_operation_queue`, and pending IDs are still captured when each probe starts (PQ-2 is preserved).
   - `lua/parley/attention_store.lua:133-134` plus `tests/unit/attention_store_spec.lua:129-133`: the batch-warning test would fail against the old "nil was not recorded" text.
   - `atlas/ui/attention_finder.md:17-18`: states the cost of opening and the meaning of "new" (mtime later than the parent's `recorded_at`), which matches `discover`'s `since` logic.

2. **Critical findings:** none.

3. **Important findings:** none.

4. **Minor findings**
   - `lua/parley/attention.lua:97-108`: when `seam.run` raises, for example `vim.system` failing with ENOENT because `couch` isn't on PATH:
     - `async_operation_queue` calls `finish("filesystem operation raised")`.
     - The callback passes that string to `M.observation` as `data`.
     - Indexing a string's `.Status` returns nil, so the entry is recorded as `observe_failed` with reason "no Couch ledger for this file".
     
     That reason is invented and wrong; it should say "couch status unavailable". Fix: in the callback, treat `type(data) ~= "table"` as nil before calling `observation` (or make `observation` do that check), and add a spec where `run` throws.

5. **Test coverage notes:** the frontmatter cases and the batch-warning wording are covered, and both fail without their fixes. The plan's Revisions entry says the capture-point and limit mutations still fail after the queue swap. I did not re-mutate those, but the integration spec passes on the new queue path. No spec covers a `run` that throws (see the Minor finding). No spec covers a parent path with dots or no extension. `side_path` owns that rule, so that is acceptable.

6. **Architectural notes**
   - **ARCH-DRY: pass.** All three re-derived facts now go through their owners.
   - **ARCH-PURE: pass.** `observation`, the model and the rows are pure. `discover` is thin glue around the filesystem.
   - **ARCH-PURPOSE: pass.** The class sweep went beyond the site the finding named.
   - **ARCH-MOCK: pass.** Probes go through the `run` seam with `fake_couch`. No new external call bypasses it.
   - **ARCH-CONSTRAINTS: pass.** The synchronous scan is bounded at 256 folders × 40 head lines, and that budget is now written down.
   - **ARCH-SECURE: flag (Minor, above).** A raised probe start is recorded under a made-up reason. Side-doc frontmatter is parsed by the shared parser, and the file read is wrapped in `pcall`.
   - **ARCH-ORDER: pass.** The queue's `finish` is idempotent, pending IDs are captured at start, and discovery is idempotent under the lease. Probes keep running after the picker closes, but the timeout from BR-12 bounds that.
   - **ARCH-FUNERAL: pass.** `retired` is capped at 256, like entries.

7. **Plan revision recommendations:** none needed. Plan line 103 ("reads one file … renders at once") is superseded by the 2026-10-16 round-3 Revisions entry (line 242), which is the plan's revision mechanism.

```findings
dispose:
  - id: BR-13
    disposition: addressed
    note: |
      is_side_doc uses frontmatter.parse, discover uses side_path; the new comment and unclosed-block spec cases go red when the old is_side_doc is restored (verified by revert).
  - id: BR-14
    disposition: addressed
    note: |
      Plan Revisions (round 3) restates Core concepts, events, ARCH-CONSTRAINTS, ARCH-ORDER and ARCH-FUNERAL; atlas/ui/attention_finder.md:17-18 states the meaning of new and the open cost, matching discover's since logic.
  - id: BR-15
    disposition: addressed
    note: |
      attention_store.lua:133 names "new side docs" for a batch; attention_store_spec asserts that text, which the old nil-path format fails.
findings:
  - id: new
    severity: Minor
    kind: defect
    family: adopted-owner-contract-unchecked
    title: |
      A probe whose start raises is recorded as "no Couch ledger for this file"
    detail: |
      async_operation_queue calls finish("filesystem operation raised") when job.start throws (e.g. vim.system ENOENT with no couch on PATH). attention.lua passes that string to M.observation as data; indexing a string's .Status gives nil, so the entry records an invented reason instead of "couch status unavailable". Treat non-table data as nil before observation, and add a spec where run throws.
```

<!-- sdlc-review-usage [{"version":1,"intent":{"disposable_root":true,"id":"051a742c-2707-4c5c-a870-b3e2112da67c","repository":"github.com/xianxu/parley.nvim","issue_id":"000354","recipe":"milestone-review","round":6,"attempt":1,"agent":"claude","root":"/Users/xianxu/Library/Caches/sdlc/review-checkouts/83fdf9669844bb97","reviewed_head":"4fdadd497d3754c4d572a44ed7dc60dc658d1732","slot":"parley.nvim:3","requested_at":"2026-10-16T23:08:06.558617Z"},"phase":"finished","pid":54291,"started_at":"2026-10-16T23:08:06.889538Z","finished_at":"2026-10-16T23:10:29.694728Z","session_id":"6f405e64-adcf-4089-8c61-c0a593305f4e","outcome":"returned"}] -->
