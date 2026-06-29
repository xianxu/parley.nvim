# Boundary Review — ariadne#152 (whole-issue close)

| field | value |
|-------|-------|
| issue | 152 — issue finder should default to display done items as well |
| repo | parley.nvim |
| issue file | workshop/issues/000152-issue-finder-should-default-to-display-done-items-as-well.md |
| boundary | whole-issue close |
| milestone | — |
| window | ac76f24ecef0c1ed85ea7752b6140508c70b702e..HEAD |
| command | sdlc close --issue 152 |
| reviewer |  |
| timestamp | 2026-06-29T16:24:04-07:00 |
| verdict | SHIP |

## Review

VERDICT: SHIP (confidence: high)

Clean, tightly-scoped change that delivers exactly what #152 specifies: the issue finder now defaults to `all` (done items in `workshop/issues/` visible) and the first `<C-a>` press cycles to `active` (done hidden), preserving the existing toggle. The behavior change is implemented by swapping the meaning of modes 0/1 while keeping the `(view_mode+1)%3` cycle arithmetic and the `view_mode==2` history derivation intact. The view-mode logic was extracted into pure functions per ARCH-PURE, and all verification passes: `make test-spec SPEC=issues/issue-management` → 84 success / 0 fail / 0 error (the 6 new `issue_finder_spec` tests confirmed green directly), and luacheck clean on both changed Lua files. Nothing blocks shipping.

1. **Strengths**
   - Genuine ARCH-PURE extraction: `M.includes_history` / `M.filter_for_view` / `M.VIEW_LABELS` (`lua/parley/issue_finder.lua:22-42`) replace the inline filter block, and `M.open` (`:159-173`) collapses to a thin IO seam (`scan_issues` + one `filter_for_view` call). Verified the functions run headlessly without IO mocks.
   - The pure functions correctly separate concerns: history *exclusion* lives at the scan layer (`include_history`), filtering at `filter_for_view` — so `filter_for_view(0, …)` keeping archived rows is right (mode 0 never scans them anyway, confirmed at `issues.lua:484-491` where `archived=true` is only set for history-dir files).
   - `filter_for_view` returns a fresh list and is explicitly tested for non-mutation (`issue_finder_spec.lua:82-85`).
   - Consumers are consistent: `init.lua:2988` default + comment, atlas doc, and traceability mapping (`spec_test_map.sh list-tests issues/issue-management` now returns `issue_finder_spec.lua`) all updated to the new semantics.

2. **Critical findings** — none.

3. **Important findings** — none.

4. **Minor findings**
   - `workshop/issues/000152-…md:20-21` — the two `## Done when` boxes are left `- [ ]` though both criteria are actually delivered; tick them for accuracy (the close gate reads the `## Plan` boxes, which are all `[x]`, so this is cosmetic).
   - `keybinding_registry.lua:808` desc `"Toggle show done/history"` is slightly imprecise for a tri-state cycle, but it is pre-existing and untouched by this diff — out of scope, noting only.
   - Magic-number coupling: the toggle handler's `(view_mode + 1) % 3` (`issue_finder.lua:291`) hardcodes a mode count that must stay in lockstep with `#VIEW_LABELS`. Pre-existing 3-state pattern, low risk; could derive the modulus from the label table if a 4th mode is ever added.

5. **Test coverage notes** — Strong for the pure layer: 6 tests cover all three modes' filtering, history inclusion per mode, no-mutation, and label order, with a deterministic injected vocabulary (`set_default_for_tests` — DI of a value object, not a behavior mock; this is the established repo seam used by `issues_spec.lua`/`issue_vocabulary_spec.lua`). The only untested path is the `M.open` wiring that combines `include_history` scanning with `filter_for_view` — but that's a 3-line thin seam and an integration concern; acceptable to leave at unit level.

6. **Architectural notes**
   - **ARCH-DRY: PASS** — consolidates the previously-inline labels table and filter loop into single shared pure functions; no new duplication.
   - **ARCH-PURE: PASS** — business logic (mode→filter, mode→history) is now pure and unit-tested; `M.open` is the thin IO/UI glue. Note: `filter_for_view` transitively reads the vocab singleton via `issues_mod.is_open_or_active_status`, so it is pure *modulo* injected configuration — the test injects a vocab rather than mocking behavior, which is the correct and established pattern, not a PURE violation.
   - **ARCH-PURPOSE: PASS** — fulfills the full purpose (default shows done; first toggle hides done) rather than a cheap subset; no deferred "follow-up" that is actually the point. Shadow-sweep of view_mode consumers (issue_finder.lua, init.lua, atlas doc, spec) all derive from the new semantics.

7. **Plan revision recommendations** — none; the plan's Core-concepts-equivalent entries (`VIEW_LABELS`/`includes_history`/`filter_for_view`, all stated PURE) match the code at the stated path, and every Plan step is delivered.

---

## Re-review — 2026-06-29T16:29:09-07:00 (SHIP)

| field | value |
|-------|-------|
| issue | 152 — issue finder should default to display done items as well |
| repo | parley.nvim |
| issue file | workshop/issues/000152-issue-finder-should-default-to-display-done-items-as-well.md |
| boundary | whole-issue close |
| milestone | — |
| window | ac76f24ecef0c1ed85ea7752b6140508c70b702e..HEAD |
| command | sdlc close --issue 152 |
| reviewer |  |
| timestamp | 2026-06-29T16:29:09-07:00 |
| verdict | SHIP |

## Review

I have everything I need. Verified the diff against Spec/Plan, ran the spec suite (84 success / 0 fail / 0 error, including all 6 new `issue_finder_spec` tests green), confirmed the `archived` flag is only set on history-dir files (`issues.lua:484` scans `issues_dir` with `is_archived=false`), and swept every `view_mode` consumer.

VERDICT: SHIP (confidence: high)

This is a clean, tightly-scoped change that delivers exactly what #152 specifies. The default `view_mode` flips from "active" to `all` (done items in `workshop/issues/` now visible on open), and the first `<C-a>` press cycles to `active` (done hidden), preserving the existing toggle. The behavior swap is achieved by remapping the meaning of modes 0/1 while keeping the `(view_mode+1)%3` cycle arithmetic and the `view_mode==2` history derivation intact. View-mode logic is extracted into genuinely pure functions per ARCH-PURE, and I independently re-ran the registered suite plus the 6 new tests — all green. Nothing blocks shipping.

**1. Strengths**
- Genuine ARCH-PURE extraction: `M.includes_history` / `M.filter_for_view` / `M.VIEW_LABELS` (`issue_finder.lua:22-42`) replace the inline filter block, leaving `M.open` (`:158-173`) a thin IO seam (scan + one `filter_for_view` call). The 6 specs run headlessly without IO mocks — confirmed.
- Correct layering of history *exclusion* (scan layer via `include_history`) vs. status *filtering* (`filter_for_view`). I verified at `issues.lua:484` that `scan_dir_issues(issues_dir, …, false)` always tags `archived=false` and only the history dir gets `archived=true` — so `filter_for_view(0,…)` keeping archived rows is harmless (mode 0 never scans them).
- Non-mutation is an explicit contract and explicitly tested (`issue_finder_spec.lua:82-85`).
- Consumer sweep is complete: `init.lua:2988` default+comment, atlas doc (`issue-management.md:17`), traceability (`issue_finder_spec.lua` registered under `issues/issue-management`), and the prompt-title label all derive from the new semantics. The stale `"open+blocked"` fallback was dropped.

**2. Critical findings** — none.

**3. Important findings** — none.

**4. Minor findings**
- Mode constants are spread across functions (`==2` in `includes_history`, `==1` in `filter_for_view`, `%3` in the toggle at `issue_finder.lua:291`, 3-entry `VIEW_LABELS`). A 4th mode would require touching all four in lockstep. Pre-existing tri-state pattern, low risk; could derive the modulus from the label table if ever extended.
- `keybinding_registry.lua:808` desc `"Toggle show done/history"` reads as boolean for a tri-state cycle — pre-existing and untouched by this diff, out of scope, noting only.
- `filter_for_view` doesn't guard `nil all_issues`, but the sole caller always passes an initialized table; not a real defect.

**5. Test coverage notes** — Strong for the pure layer: all three modes' filtering, per-mode history inclusion, no-mutation, and label order, with a deterministic injected vocabulary (`set_default_for_tests` — DI of a value object, the established repo seam, not a behavior mock). The only untested path is the `M.open` wiring that combines `include_history` scanning with `filter_for_view` — a 3-line thin IO seam, acceptable to leave at unit level.

**6. Architectural notes**
- **ARCH-DRY: PASS** — consolidates the inline labels table and filter loop into single shared pure functions; no new duplication.
- **ARCH-PURE: PASS** — mode→filter and mode→history are pure and unit-tested; `M.open` is thin glue. `filter_for_view` transitively reads the vocab singleton via `is_open_or_active_status`, but the test injects a vocab value object rather than mocking behavior — pure *modulo* injected configuration, the correct established pattern.
- **ARCH-PURPOSE: PASS** — delivers the full purpose (default shows done; first toggle hides done; second adds history; third returns), not a cheap subset. Shadow-sweep of all `view_mode` consumers confirms each derives from the new semantics; no deferred "follow-up" that is actually the point.

**7. Plan revision recommendations** — none. The plan's Core-concepts-equivalent entries (`VIEW_LABELS` / `includes_history` / `filter_for_view`, all stated PURE) match the code at the stated paths, and every `## Plan` step (and both `## Done when` boxes, now `[x]`) is delivered.
