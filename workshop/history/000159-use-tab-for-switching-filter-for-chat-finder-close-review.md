# Boundary Review — parley.nvim#159 (whole-issue close)

| field | value |
|-------|-------|
| issue | 159 — use TAB for switching filter for chat finder |
| repo | parley.nvim |
| issue file | workshop/issues/000159-use-tab-for-switching-filter-for-chat-finder.md |
| boundary | whole-issue close |
| milestone | — |
| window | cbea0854e1133344d7214bbcc119ae9aa1ee02a3..HEAD |
| command | sdlc close --issue 159 |
| reviewer | claude |
| timestamp | 2026-07-01T10:23:22-07:00 |
| verdict | FIX-THEN-SHIP |

## Review

I have everything I need. Both specs pass (20/20 keybindings, 34/34 chat_finder_logic), lint is clean, and I've verified the direction wiring, header, config, registry, and atlas justification against the Spec/Plan.

```verdict
verdict: FIX-THEN-SHIP
confidence: high
```

This is a clean, well-scoped DRY refactor that fully delivers the issue's purpose: `<Tab>`/`<S-Tab>` now cycle the chat-finder recency filter as aliases for `<C-a>`/`<C-s>`, the two near-identical inline handlers collapse into one `make_recency_cycle(direction)` factory, the counterintuitive-but-intentional direction mapping is preserved verbatim, and config/registry/help/header/logic-spec all move in lockstep. The only thing keeping this from a clean SHIP is a cheap, non-blocking test gap: the new mapping *functions* are asserted only by key string and list position — nothing invokes them to confirm `<Tab>` actually cycles in the "previous"/left direction and `<S-Tab>` in "next"/right, which is exactly the regression a left/right-factory swap would introduce.

**1. Strengths**
- ARCH-DRY done exactly as speced: `chat_finder.lua:697-717` — one factory, four keys, with a comment citing the marker. The two ~18-line inline bodies are gone.
- Direction preserved faithfully: `recency_left_fn = make_recency_cycle("previous")` → `<C-a>`/`<Tab>`; `recency_right_fn = make_recency_cycle("next")` → `<C-s>`/`<S-Tab>` (`chat_finder.lua:716-717, 942-959`) matches the pre-diff `<C-a>`→"previous"/`<C-s>`→"next" wiring.
- ARCH-PURE respected: the pure `_cycle_chat_finder_recency` core is untouched and stays directly unit-tested; the new code is thin glue.
- Back-compat honored end-to-end — `next_recency`/`previous_recency` config keys, mappings, and registry entries all retained; new keys are additive (`config.lua:493-498`).
- Header now surfaces the natural keys in the same slot order as before (`chat_finder.lua:681-686`), so no direction-label drift.

**2. Critical findings**
None.

**3. Important findings**
- **Missing fn-behavior test for the new (and existing) recency-cycle mappings** — `tests/unit/chat_finder_logic_spec.lua:491-511` asserts `mappings[5].key == "<Tab>"` / `[7] == "<S-Tab>"` but never calls `mappings[5].fn(...)` / `mappings[7].fn(...)` to confirm they cycle in the correct direction. A swap of `recency_left_fn`/`recency_right_fn` (the exact hazard of this DRY refactor) would ship green. This is cheap to close: the harness already invokes mapping fns synchronously with a no-op `close_fn` (see the move test at `chat_finder_logic_spec.lua:600`), and the direction-critical state mutation (`recency_index`/`show_all`) happens *before* the async `vim.defer_fn` reopen (`chat_finder.lua:706-713`) — so a test can invoke `mappings[5].fn(item, function() end)` and assert `_parley._chat_finder.recency_index`/`show_all` moved in the "previous" direction (and `mappings[7].fn` in "next"), no defer-pumping needed. Non-blocking at the gate, but it's the one assertion that would defend the refactor.

**4. Minor findings**
- Atlas asymmetry with #158 (`atlas/issues/issue-management.md:20` documents the IssueFinder `<Tab>` per-key, but `atlas/ui/pickers.md:25` stays feature-level for the Chat Finder). This is consistent with the Chat Finder never having had per-key atlas detail, so no update is required — but if per-key documentation is a convention you want mirrored across finders, that's a future cleanup, not this issue's scope.
- Index-position mapping assertions (`mappings[3..7]`) are brittle to future reordering, but they're a reasonable regression pin for now.

**5. Test coverage notes**
- Pure core: `_cycle_chat_finder_recency` "previous"→"next" transitions are directly tested (`chat_finder_logic_spec.lua:211-225`). Good.
- Wiring: header title (all 4 assertions updated to `<Tab>/<S-Tab>`), mapping key/order, and registry help lines (`<Tab>`/`<S-Tab>` present) are covered and green.
- Gap: the direction-correctness of the new mapping *fns* (Important finding above). The plan explicitly accepts the async-reopen glue as manual-verify (documented in `## Log`), which is fair — but the *synchronous* direction mutation is testable and isn't tested.
- Verified locally: `keybindings_spec` 20/20, `chat_finder_logic_spec` 34/34, luacheck 0/0 on the three changed lua files.

**6. Architectural notes for upcoming work**
- ARCH-DRY / ARCH-PURE / ARCH-PURPOSE all pass. If more finders acquire a `<Tab>` natural-key alias (issue finder already has one), consider whether the "register fn under both `<C-*>` and Tab key + dual registry entry with duplicate desc" idiom is worth extracting into a small helper — three finders in and it may become the ARCH-DRY consolidation target across finders rather than within one.

**7. Plan revision recommendations**
None — the plan matches the code exactly (factory, key registration, header, config/registry/help/logic-spec touchpoints, and the `--no-atlas` justification all hold). The plan's own note that the cycle glue is manual-verify already flags the coverage limitation; no `## Revisions` entry is needed.
