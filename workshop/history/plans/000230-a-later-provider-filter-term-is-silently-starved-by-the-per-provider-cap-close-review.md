# Boundary Review — parley.nvim#230 (whole-issue close)

| field | value |
|-------|-------|
| issue | 230 — a later provider filter term is silently starved by the per-provider cap |
| repo | parley.nvim |
| issue file | workshop/issues/000230-a-later-provider-filter-term-is-silently-starved-by-the-per-provider-cap.md |
| boundary | whole-issue close |
| milestone | — |
| window | 0f9b3add0e4cd33763435db02622f6dd2f9cf491..f0904b58358c78ab3cd6a809ab8c80011a96d67b |
| command | sdlc close --issue 230 |
| reviewer | claude |
| isolation | checkout |
| timestamp | 2026-10-15T19:53:37-07:00 |
| verdict | FIX-THEN-SHIP |

## Review

Diff read; now checking the picker's provider-default path and running the tests.

Unit suite is all green; running the integration specs this diff touches now.

The scratch-placement failures come from the review checkout's TMPDIR, not the diff. Checking the starter and zero-config failures next.

```verdict
verdict: FIX-THEN-SHIP
confidence: high
```

The change does what the Spec asks. `!N` is parsed on terms and on bare providers, and a malformed count is rejected with a message that names the spec. `curate` now gives each search its own budget, has no hidden limit, keeps series de-duplication global and keeps term order. `diagnose` is pure and is logged once, from the picker's fetch callback. `per_provider` is gone from code, defaults, atlas and specs, except the setup notice that names it. I checked the fix by reverting `lua/parley/cliproxy_catalog.lua` to base: 19 of 77 catalog unit cases and 4 of 56 picker cases go red, and all go green again once the file is restored. The full unit suite passes at head. In the integration suite, `cliproxy_catalog_spec` and the new `live_models_config_spec` pass. Four integration files fail (`scratch_placement`, `starter_config`, `starter_project`, `zero_config`). The diff touches none of them, and the errors all say the test scratch directory is inside the repo checkout. That is caused by this review sandbox, which places TMPDIR inside the checkout and blocks writes outside it; I could not re-run them elsewhere. One Important finding stops a plain SHIP: the shipped default config makes the new diagnostic fire on a catalog that has no gpt-6 model. That is cheap to fix.

**1. Strengths**
- `lua/parley/cliproxy_catalog.lua:123-152`: the parser returns `nil, err` instead of falling back to "no limit". `antigravity!2` resolves to provider `antigravity`, and `codex!2:gpt-5` is rejected rather than half-applied.
- `curate` calls `parse_provider_spec` → `_select` → `pool_for`, and `diagnose` reuses `pool_for` and `matches`. The ranking and ownership rules live in one place. Copying rows before tagging them keeps `curate` free of side effects.
- `agent_picker.lua:368-375`: diagnostics run in the fetch callback, not in `repaint`, so a `<C-a>` toggle doesn't log again. The test at `picker_items_spec.lua:629` pins this through the real `agent_picker` entry point.
- The case from the original report is kept as a guard test, and the 9-row recommended config is pinned exactly and in order (`cliproxy_catalog_spec.lua`, "curate without a hidden limit").
- An old config that still sets `per_provider` gets one visible notice rather than being silently ignored. The test fails with the notice disabled, as the issue log records.

**2. Critical findings**
None.

**3. Important findings**
- `lua/parley/config.lua:154` with `agent_picker.lua:371`: the shipped default `codex:gpt-6,gpt-5!3` names a version, so it will not always exist. On a catalog without gpt-6 (the repo's own `tests/fixtures/cliproxy_catalog_v1.json` capture is one), every catalog refresh logs `"gpt-6" matches no codex model` at WARN level. Refreshes happen on picker open, about once per 10-minute TTL. This is noise from parley's own default, and it is the opposite of "a model can only disappear because the operator asked". Possible fixes:
  - only diagnose providers the user actually set; or
  - skip "matches nothing" for searches that come from the shipped default; or
  - drop `gpt-6` from the default.
  
  Whichever fix is chosen, add a test that the default config against the v1 fixture produces no warnings.

**4. Minor findings**
- `cliproxy_catalog.lua:269-276`: `diagnose` re-implements the match loop instead of sharing a `matches_any(pool, text)` helper with `_select` (small ARCH-DRY nit).
- Rejecting `codex!2:gpt-5` (a provider cap combined with terms) goes beyond the Spec. That's reasonable, but the atlas/config comments don't mention it.
- `M._per_provider_noticed` is per process, so a `setup()` re-run later in the same session never warns again. Fine, just undocumented.
- `README.md` doesn't document `live_models` before or after this change; `config.lua` holds the docs. No gap was introduced.

**5. Test coverage notes**
Each Done-when bullet has a test, and the revert shows they fail without the fix. The integration spec for the setup notice uses the real `parley.setup`. Two things are untested: the default config producing no diagnostics (the Important finding above), and the `antigravity!2:` form (cap with an empty filter). From reading the code, the latter parses as a capped bare provider.

**6. Architectural notes (each principle)**
- **ARCH-DRY:** pass. The only nit is the match loop in `diagnose`.
- **ARCH-PURE:** pass. `parse_provider_spec`, `curate`, `_select` and `diagnose` are pure. Logging sits in the picker's thin shell, and the `diagnose` test checks that its input is not mutated.
- **ARCH-PURPOSE:** pass. Sweeping for `per_provider` finds it only in the deliberate notice and its test. Every caller of `parse_provider_spec` (`curate`, `diagnose`, `_providers_without_models`) handles the `nil` return.
- **ARCH-MOCK:** pass. There are no new external calls; tests swap `cliproxy.fetch_catalog` and `catalog_cached`, which the picker already used.
- **ARCH-CONSTRAINTS:** pass. "No limit" is bounded by series de-duplication, and the uncapped count (22) is measured on a fixture.
- **ARCH-SECURE:** pass. Config strings are parsed into a typed `{text, cap}` value at the boundary. A malformed entry is reported visibly and contributes nothing, rather than being read as "everything".
- **ARCH-ORDER:** pass. The only state kept between events is the one-shot notice flag. Diagnostics are tied to fetch resolution, not to repaint order.
- **ARCH-FUNERAL:** pass. Nothing durable is created; the new fixture is a static test asset.

**7. Plan revision recommendations**
None required. If the Important finding is fixed by changing the default's terms, add a "## Revisions" note recording the new default strings. `starter_config_spec` pins those strings too.

```findings
findings:
  - id: new
    severity: Important
    kind: defect
    family: diagnostics-fire-on-shipped-defaults
    title: |
      Shipped default "codex:gpt-6,gpt-5!3" makes diagnose warn on every catalog refresh when the catalog has no gpt-6
    detail: |
      agent_picker.lua:371 diagnoses the effective providers, including the config.lua:154 default. On a catalog like tests/fixtures/cliproxy_catalog_v1.json (no gpt-6), each refresh (picker open, about every 10 min) logs a WARN '"gpt-6" matches no codex model' that the operator never wrote. Fix: diagnose only user-set providers, or skip "matches nothing" for default searches, or drop gpt-6 from the default; then test that the default config against the v1 fixture yields no diagnostics.
  - id: new
    severity: Minor
    kind: defect
    family: duplicated-match-loop
    title: |
      diagnose re-implements the term-match loop instead of sharing a helper with _select
    detail: |
      cliproxy_catalog.lua:269-276; extract a matches_any(pool, text) helper (ARCH-DRY).
  - id: new
    severity: Minor
    kind: defect
    family: undocumented-parse-rejection
    title: |
      A provider cap combined with terms (codex!2:gpt-5) is rejected, but atlas/config comments do not say so
    detail: |
      Stricter than the Spec and reasonable; document it in atlas/providers/cliproxy-managed.md next to the malformed-count sentence.
```

<!-- sdlc-review-usage [{"version":1,"intent":{"disposable_root":true,"id":"e1c016e3-15c6-4bab-bae5-2d13bf7c566e","repository":"github.com/xianxu/parley.nvim","issue_id":"000230","recipe":"milestone-review","round":1,"attempt":1,"agent":"claude","root":"/Users/xianxu/Library/Caches/sdlc/review-checkouts/e7d2337a8009131c","reviewed_head":"f0904b58358c78ab3cd6a809ab8c80011a96d67b","slot":"parley.nvim:3","requested_at":"2026-10-16T02:44:20.035712Z"},"phase":"finished","pid":20205,"started_at":"2026-10-16T02:44:20.126325Z","finished_at":"2026-10-16T02:53:21.626393Z","session_id":"ca9aa192-6d03-4f42-aa2d-8b7818fa2d66","outcome":"returned"}] -->

---

## Re-review — 2026-10-15T20:01:03-07:00 (SHIP)

| field | value |
|-------|-------|
| issue | 230 — a later provider filter term is silently starved by the per-provider cap |
| repo | parley.nvim |
| issue file | workshop/issues/000230-a-later-provider-filter-term-is-silently-starved-by-the-per-provider-cap.md |
| boundary | whole-issue close |
| milestone | — |
| window | 0f9b3add0e4cd33763435db02622f6dd2f9cf491..d9e812c83ee6fdf62194bd5083ae592f7a187f35 |
| command | sdlc close --issue 230 |
| reviewer | claude |
| isolation | checkout |
| timestamp | 2026-10-15T20:01:03-07:00 |
| verdict | SHIP |

## Review

I've disposed the prior findings against the diff. Next I'll run the tests and revert the BR-1 fix to check that its regression test fails without it.

Bypassing my ad-hoc environment; I'll use the Makefile's test environment instead.

All 23 mapped files pass. Now I'll run the two specs outside that map, then revert the BR-1 fix.

BR-1's test fails without the fix and the tree is restored. Next I'm checking how user `live_models.providers` merges with the defaults.

Overrides are wholesale, so a user list never mixes with the defaults. Now I'm reading the issue's Plan to trace requirements.

Requirements trace cleanly. Last check: any leftover `per_provider` mentions in README, docs, or code.

```verdict
verdict: SHIP
confidence: high
```

All three prior findings are fixed, and I checked each against the pinned code rather than the commit messages. BR-1 is fixed: `M._operator_specs` (`lua/parley/agent_picker.lua:25-29`) drops specs that exactly match a shipped default before `diagnose` runs. The regression test is real. I put back the old call, `diagnose(models, configured)`, and `picker_items_spec` went from 57/0 to 56 passing and 1 failing: "diagnoses only what the operator wrote, never a verbatim shipped default". I then restored the file, and the tree is clean. The test also asserts that its fixture *would* warn on the defaults, so it can't pass by accident. BR-2 is fixed: `diagnose` now calls `M._select` with a cap-1 search (`cliproxy_catalog.lua:269-271`) instead of its own match loop. BR-3 is fixed: the atlas (`atlas/providers/cliproxy-managed.md:166-167`) and the `config.lua:147-148` comment now say that a provider cap beside terms (`codex!2:gpt-5`) is rejected. Every item on the Plan checklist is delivered. All 23 test files mapped to `providers/cliproxy-managed` pass, and so do `starter_config_spec` (7/0) and `agent_picker_options_spec` (6/0). Only one minor doc misplacement is left.

1. **Strengths**
   - `parse_provider_spec` (`cliproxy_catalog.lua:124-153`) turns a spec into a typed value at the boundary. A malformed count returns `nil, err` naming the spec. `curate` then adds nothing for that spec rather than treating it as "no limit" (tested at `cliproxy_catalog_spec.lua` "lets a malformed spec contribute nothing").
   - `curate` is split into `pool_for`, `searches` and `_select`, so `curate` and `diagnose` use the same selection. `curate` still copies rows and has no side effects (ARCH-PURE).
   - Diagnostics are logged once per catalog refresh, in the fetch callback, not on every repaint. Both picker tests check the exact list of warnings.
   - Removing `per_provider` produces one setup notice, which stops a leftover option being ignored silently (`init.lua:559-566`, `live_models_config_spec.lua`).
   - The shipped defaults write their caps out (`codex:gpt-6,gpt-5!3`, `gemini!3`), so the default view stays the same size, and the starter spec pins this.

2. **Critical:** none.

3. **Important:** none.

4. **Minor**
   - `agent_picker.lua:16-18`: the `---@param models / providers / @return` annotations for `_providers_without_models` now sit above the new `_operator_specs` doc block. The new function was inserted between the old function and its doc comment, so LuaLS attaches both sets to `_operator_specs`. Fix: move the new block above line 16, or move the old annotations back down to the function.

5. **Test coverage notes:** Each Done-when has a test: the reported case, uncapped = 22 (the plan's Revisions restate the 17 from the Spec), `!N` on a term and on a bare provider, the 9-row recommended config, de-duplication of a series matched by two terms, rejection messages that name the spec, and diagnose being pure plus the empty-catalog case. The BR-1 revert check is described above. `diagnose` re-sorts the provider's pool for each term (`pool_for` and then `_select`). That doesn't matter, because it runs once per refresh over a small catalog.

6. **Architecture**
   - **ARCH-DRY: pass.** BR-2's duplicate match loop is gone. The shipped defaults are read from the `parley.config` module itself, not restated.
   - **ARCH-PURE: pass.** `parse_provider_spec`, `_select`, `curate` and `diagnose` are pure and tested without IO. Logging stays in the picker callback.
   - **ARCH-PURPOSE: pass.** I swept every consumer of `parse_provider_spec` and every mention of `per_provider`. `curate`, `diagnose`, `_providers_without_models`, config, atlas, the setup notice and the specs all follow the new grammar. The only `per_provider` left in code or docs is the removal notice. The README never mentioned `live_models`, so it needs no update.
   - **ARCH-MOCK: pass.** No new external dependency. The picker tests replace the existing `cliproxy` module seams.
   - **ARCH-CONSTRAINTS: pass.** "No limit" is still bounded by series de-duplication (22 rows across the whole fixture), and the defaults keep explicit caps.
   - **ARCH-SECURE: pass.** Config text is parsed into a typed value at the boundary, and the failure path warns visibly instead of making up a "no limit".
   - **ARCH-ORDER: pass.** The only new state is `_per_provider_noticed`, a show-once flag for the life of the process, which the test resets. Diagnostics are tied to the fetch-resolution event.
   - **ARCH-FUNERAL: pass.** Nothing durable is created: no files or caches, only log lines.
   - Note for later: `_operator_specs` matches exact strings, so an operator who copies a default spec verbatim gets no diagnostics for it. That trade-off is documented in the atlas, and it's acceptable.

7. **Plan revision recommendations:** none. The Core concepts table matches the code: every entity is at its stated path with the stated status, and the PURE entities are tested without IO.

```findings
dispose:
  - id: BR-1
    disposition: addressed
    note: |
      agent_picker.lua:25-29 _operator_specs filters verbatim defaults; reverting to diagnose(models, configured) turns picker_items_spec "diagnoses only what the operator wrote" red (56/1), restored green (57/0).
  - id: BR-2
    disposition: addressed
    note: |
      cliproxy_catalog.lua:269-271 diagnose now calls M._select with a cap-1 single search; the private match loop is gone.
  - id: BR-3
    disposition: addressed
    note: |
      atlas/providers/cliproxy-managed.md:166-167 and config.lua:147-148 now state a provider cap beside terms is rejected; matches parse_provider_spec line 152 and the codex!2:gpt-5 rejection test.
findings:
  - id: new
    severity: Minor
    kind: defect
    family: misplaced-doc-annotation
    title: |
      _operator_specs was inserted between _providers_without_models and its doc annotations
    detail: |
      agent_picker.lua:16-18 param/return annotations for _providers_without_models now precede the _operator_specs block, so LuaLS attaches them to the wrong function. Move the new block above line 16.
```

<!-- sdlc-review-usage [{"version":1,"intent":{"disposable_root":true,"id":"57a8f176-abed-417d-bfe3-1c62859e3183","repository":"github.com/xianxu/parley.nvim","issue_id":"000230","recipe":"milestone-review","round":2,"attempt":1,"agent":"claude","root":"/Users/xianxu/Library/Caches/sdlc/review-checkouts/b241fa65a69aef21","reviewed_head":"d9e812c83ee6fdf62194bd5083ae592f7a187f35","slot":"parley.nvim:3","requested_at":"2026-10-16T02:56:25.191677Z"},"phase":"finished","pid":85113,"started_at":"2026-10-16T02:56:25.420776Z","finished_at":"2026-10-16T03:01:01.830372Z","session_id":"6ba2ee10-b9e8-4d19-824b-efc0eed8e35c","outcome":"returned"}] -->

---

## Re-review — 2026-10-15T20:22:39-07:00 (SHIP)

| field | value |
|-------|-------|
| issue | 230 — a later provider filter term is silently starved by the per-provider cap |
| repo | parley.nvim |
| issue file | workshop/issues/000230-a-later-provider-filter-term-is-silently-starved-by-the-per-provider-cap.md |
| boundary | whole-issue close |
| milestone | — |
| window | 736037b48f7f29cb0c8dd00514507b874fb9b6ba..3646bebb2a5bfe06aed4447122e08f41e137c92b |
| command | sdlc close --issue 230 |
| reviewer | claude |
| isolation | checkout |
| timestamp | 2026-10-15T20:22:39-07:00 |
| verdict | SHIP |

## Review

BR-4's fix is in place. Next I'm running the guard specs that cover it: superseded_comment, single_source_sweeps and picker_items.

```verdict
verdict: SHIP
confidence: high
```

The only open finding, BR-4, is fixed, and it is fixed for the whole class rather than just the one site. In `lua/parley/agent_picker.lua`, `_operator_specs` and its own annotations now sit above line 19, so the `_providers_without_models` doc block (lines 20-30) is directly above that function again. The repo already has a guard for this class across the whole tree, `tests/arch/superseded_comment_spec.lua`. I tested it in the review checkout. With base's `agent_picker.lua` restored, the guard goes red (8/1, `lua/parley/agent_picker.lua:8 — @param models, but the signature is (providers)`). With the head version it is green (9/0). The rest of the window is bookkeeping:
- the issue file gains Core-concepts rows for `_select` and `_operator_specs`. `single_source_sweeps_spec` requires those rows, and both entities exist, `_select` at `cliproxy_catalog.lua:236`.
- Log entries, a lessons.md line, and the gate and review ledgers.

None of it changes `## Spec`, `## Revisions` or `## Done when`, and none of it adds behavior. There is no scope change.

1. **Strengths**
   - `agent_picker.lua:8-30`: each function's annotations sit directly on that function, and `_operator_specs` now has its own `@param`/`@return`.
   - The fix is backed by an existing guard that covers the whole tree, so it does not depend on a new test written for this one spot.
   - The Core-concepts table now names the two entities the earlier rounds added (`_select`, `_operator_specs`), and they match the code: both are PURE, at the paths stated.
   - The new lesson in `workshop/lessons.md` names the real process gap: the full suite was run on a commit before the final one.

2. **Critical findings**: none.

3. **Important findings**: none.

4. **Minor findings**: none.

5. **Test coverage notes**: run in this checkout at head: `superseded_comment_spec` 9/0, `single_source_sweeps_spec` 25/0, `picker_items_spec` 57/0. With the BR-4 fix reverted, `superseded_comment_spec` fails as expected (8/1). I restored the file afterwards.

6. **Architectural notes** (interdiff only)
   - **ARCH-DRY: pass.** The code change only moves a block; nothing is duplicated.
   - **ARCH-PURE: pass.** No logic changed.
   - **ARCH-PURPOSE: pass.** The class `misplaced-doc-annotation` is enforced tree-wide by `superseded_comment_spec`, which passes, so no sibling instance remains.

7. **Plan revision recommendations**: none. The Core-concepts rows added in this window match the code.

```findings
dispose:
  - id: BR-4
    disposition: addressed
    note: |
      agent_picker.lua:8-30 _operator_specs now sits above the _providers_without_models doc block. The class is enforced tree-wide by tests/arch/superseded_comment_spec: red with the base file (8/1, agent_picker.lua:8 @param models vs (providers)), green at head (9/0).
```

<!-- sdlc-review-usage [{"version":1,"intent":{"disposable_root":true,"id":"245bf454-75f2-46e6-aa91-2103420cd7c8","repository":"github.com/xianxu/parley.nvim","issue_id":"000230","recipe":"fix-review","round":3,"attempt":1,"agent":"claude","root":"/Users/xianxu/Library/Caches/sdlc/review-checkouts/eaa73ef30bf6e57d","reviewed_head":"3646bebb2a5bfe06aed4447122e08f41e137c92b","slot":"parley.nvim:3","requested_at":"2026-10-16T03:21:49.812498Z"},"phase":"finished","pid":38149,"started_at":"2026-10-16T03:21:49.977193Z","finished_at":"2026-10-16T03:22:39.073003Z","session_id":"924a5f7b-22ca-4c15-9a0b-82eac31f6211","outcome":"returned"}] -->
