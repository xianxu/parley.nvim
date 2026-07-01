# Boundary Review — parley.nvim#158 (whole-issue close)

| field | value |
|-------|-------|
| issue | 158 — bind TAB in issue tracker to switch filter criteria |
| repo | parley.nvim |
| issue file | workshop/issues/000158-bind-tab-in-issue-tracker-to-switch-filter-criteria.md |
| boundary | whole-issue close |
| milestone | — |
| window | c0ca6d8418c75974c2383c762b8caa3f93c4cc8f..HEAD |
| command | sdlc close --issue 158 |
| reviewer | claude |
| timestamp | 2026-07-01T09:59:22-07:00 |
| verdict | FIX-THEN-SHIP |

## Review

I have a complete picture. Let me verify one final thing — the keybindings_spec expectation count and that both specs are green (already confirmed PASS above). Writing the review now.

```verdict
verdict: FIX-THEN-SHIP
confidence: high
```

The #158 change is correct, well-tested, and lint-clean: the tri-state view collapses cleanly to a 2-state `issues ↔ history` partition, `<Tab>` and `<C-a>` are unified behind one `cycle_view_fn` (ARCH-DRY done right), the pure functions match the Spec exactly, and both `issue_finder_spec` and `keybindings_spec` pass. Nothing here is a correctness bug or crash risk. What keeps it from a clean SHIP is one incomplete piece of the implementor's own stated cleanup ("scrub the tri-state model"): a stale comment at the initialization of the very field #158 redefines still describes the old three states. That plus a now-orphaned helper are cheap boundary fixes, not reworks — hence FIX-THEN-SHIP.

## 1. Strengths

- **ARCH-DRY, one handler two keys** — `cycle_view_fn` (`lua/parley/issue_finder.lua:209-217`) is registered under both `<Tab>` (`:305-308`) and `<C-a>` (`:309-312`). This is the correct consolidation the Spec asked for; the old diff had the reopen body inline in `toggle_done`, and this unifies it.
- **Partition logic is clean and nil-safe** — `(issue.archived == true) == want_archived` (`:39`) correctly folds `nil`/`false` into non-archived and reads as a single boolean equality; returns a fresh list, no mutation.
- **Stale-state self-heal** — `(view_mode or 0) % 2` (`:163`) plus `(view_mode + 1) % 2` (`:210`) means a stale in-memory `2` from the pre-#158 tri-state migrates to `0` on next open. Good defensive migration for in-memory format change.
- **Header not hardcoded** — the title interpolates `cycle_view_shortcut.shortcut` (`:221-225`) rather than a literal `<Tab>`, so a rebind stays truthful (ARCH-DRY).
- **Tests tightened, not just retargeted** — the rewrite drops the now-irrelevant `issue_vocabulary` fixture (filter no longer keys on status categories) and adds an explicit nil-`archived` case (`tests/unit/issue_finder_spec.lua`), which is exactly the edge the new `== true` normalization introduces.

## 2. Critical findings

None.

## 3. Important findings

None. (The items below are all non-blocking.)

## 4. Minor findings

- **Stale tri-state comment survives the scrub** — `lua/parley/init.lua:3002`: `view_mode = 0, -- 0=all (default, done visible), 1=active, 2=all+history`. This is the initializer for the exact field #158 redefines, and it still documents the deleted three-state model. Fix to `-- 0=issues (default), 1=history (#158)`. Behaviorally harmless (default `0` is still correct), but it's the one place the "scrub the tri-state model" cleanup missed — the comment now lies about its own field. (ARCH-PURPOSE: this is the only consumer of the model that wasn't brought in line; everything else derives correctly.)
- **Orphaned predicate `is_open_or_active_status`** — `lua/parley/issues.lua:161`. The old `filter_for_view` was its last production caller; after #158 it has zero references (grep confirms only the definition). It's part of a coherent public predicate family (`is_active`/`is_open`/`is_terminal`), so keeping it as a public helper is defensible — but flag it so the operator decides: remove, or leave with a note that it's now API-only. (ARCH-DRY: dead-ish code, not duplication.)
- **Cycle/clamp arithmetic is not pure-extracted** — the `% 2` cycle (`:210`) and self-heal clamp (`:163`) live inside impure `M.open`, so an off-by-one in either is manual-verify-only, uncovered by unit tests. The arithmetic is trivial and the Spec scoped only the three pure functions, so this is optional; a one-line `M.next_view`/`M.normalize_view` extraction would make the migration guarantee testable (ARCH-PURE).
- **`cycle_view_fn` re-implements `M.reopen`** — the defer/reset/reopen dance (`:211-216`) duplicates `M.reopen`'s body minus `initial_index`/`initial_value`. Could be `M.reopen(source_win)` (selection index is meaningless across an issues↔history swap anyway). Pre-existing pattern inherited from the old inline handler; the diff already net-reduces duplication, so this is a nicety.

## 5. Test coverage notes

- Both target specs pass and lint is clean (`0 warnings / 0 errors in 237 files`). `keybindings_spec` now asserts both `<Tab>` and `<C-a>` map to "Cycle view (issues/history)", pinning the registry reword.
- **Heads-up, not a #158 defect:** the full `make test` is currently **red** on `tests/unit/tools_builtin_find_spec.lua` ("treats command substitution text in name as data"). That file is untouched, outside the `c0ca6d8..HEAD` window, and **passes in isolation** (`PlenaryBustedFile` → 4/4 Success) — it's a pre-existing full-suite ordering/shared-state flake, not caused by this branch. But the issue's own **Done-when says "Full suite green,"** which is technically unmet right now for that unrelated reason. Worth a `## Log` note so the close evidence isn't overstated.
- The interactive `<Tab>` keypress remains manual-verify-only (async float-picker); the implementor documented this and it rides the identical `imap_p` path as the working `<C-a>`/`<C-d>`. Confirmed no `<C-i>` binding exists anywhere in the finder, so no `<Tab>`≡`<C-i>` terminal collision.

## 6. Architectural notes for upcoming work

- **ARCH-DRY: PASS** (with the two minor notes above). The two-key unification is the model to keep; if another finder later needs a two-key alias, reuse this `cycle_view_fn` pattern rather than duplicating handlers.
- **ARCH-PURE: PASS** (with note). View-model logic is genuinely pure and IO-free; only the cycle/clamp glue stays in `M.open`. If this file grows more view states, promote the arithmetic to a pure helper.
- **ARCH-PURPOSE: PASS.** Shadow-sweep of the view-mode model: `VIEW_LABELS`, `includes_history`, `filter_for_view`, `M.open`, `config.issue_finder_mappings.cycle_view`, `keybinding_registry`, atlas, and tests all derive from the 2-state model. The sole un-migrated consumer is the `init.lua:3002` comment (documentation, not enforced) — the finding in §4. Purpose fully delivered.
- **Atlas gate: PASS.** New surface (`cycle_view` mapping, `<Tab>` key, 2-state model) is reflected in `atlas/issues/issue-management.md`. The Spec's claim that `atlas/ui/keybindings.md` needs no edit checks out — it lists finder scopes generically with no per-view detail line (confirmed by grep, only line 27 names `issue_finder` as a scope).

## 7. Plan revision recommendations

The plan still matches the code — no `## Revisions` entry required. One optional addendum: the plan's checkbox "scrubbed the #152 tri-state comments" is not fully true (`init.lua:3002` remains), so either fix the comment before close or note the residual in `## Log`.
