# Blink spell suggestions implementation plan

> **For agentic workers:** Consult AGENTS.md Section 3 (Subagent Strategy). Use superpowers-executing-plans for the shared controller and superpowers-subagent-driven-development only for bounded independent tasks. Track the checkboxes below.

**Goal:** Automatically offer whole-word spelling corrections through Blink in Normal and Insert modes, in both the plugin and app.

**Architecture:** One shared spelling controller owns target observation, dismissal and transient mappings. A pure transition function authorizes effects; a Blink source retains immutable acceptance evidence independently of menu visibility. The existing spell module selects exactly one backend and the app consumes the plugin integration.

**Tech Stack:** Lua, Neovim spell APIs, Blink 1.10.2 (pinned app commit 78336bc89ee5365633bcf754d93df01678b5c08f), Plenary and real headless keyboard tests.

## Contract and decisions

The issue's Spec and Done when are authoritative. Normal-mode feasibility and the reproducible probe are already recorded there; do not repeat discovery. This is one atomic delivery with one close review, not multiple Mx boundaries.

- Default `chat_spell.blink = true` enables suggestions when Blink has completed setup; Parley never calls Blink setup for plugin users. `blink = false` disables this integration independently of spell underlines. Keep `typeahead = false` and existing explicit legacy opt-in as a fallback when Blink is disabled or unavailable. Raw attach options with neither popup option enabled install no popup.
- Add `debounce_ms = 180` (configurable, nonnegative finite integer). Use `max_suggest = 9`, validated/clamped to 1–20. Existing `min_word = 4` continues to govern legacy typing only. Blink uses no length threshold: #304 explicitly requires short existing misspellings, including after entering Insert mode. Do not change the app's two-character buffer threshold.
- Blink owns completion in a chat once ready and enabled. Retire an already-attached legacy spell backend before activating Blink. While owned, suppress the Parley nvim-cmp neighborhood adapter, preserving completefunc/manual path completion. Do not globally disable a user's unrelated nvim-cmp configuration; document that manually enabling two engines in the same chat is unsupported. #288 retains migration of neighborhood paths and health reporting; #259 retains its other buffer/threshold requirements. Neither issue closes with #304.
- In Insert, add spelling to the existing Blink providers without replacing their lists. Automatic correction requests use the configured provider set, retaining buffer candidates. In Normal, explicitly request the spelling provider only. Never alter global dot-repeat, preselection, or auto-insert settings. Pinned Blink initially selects with auto_insert=false, but list.lua:125 reselects on refresh without that override. A narrow compatibility adapter in spell_blink wraps the loaded list.get_selection_mode: call the original, copy its result, and force auto_insert=false only for an exact owned context ID (registered synchronously on BlinkCmpShow from its spelling items). Delegate foreign contexts unchanged. Keep public navigation auto_insert=false as well. Install once with the first attached controller; restore the original function on last detach only if the wrapper is still installed. Never change Blink config values. Fail closed if the expected internal function is absent. This covers refresh-driven selection before Blink can apply a preview; explicit acceptance is the only edit.
- No automatic correction. Tab/Down and Up select; Enter accepts selected item or first item; Esc dismisses while retaining the current mode. Keys revert to their effective prior behavior when the owned menu closes. Prompt and interview Return handlers must be restored faithfully.

## Core concepts

### Pure entities

| Name | Lives in | Status |
|------|----------|--------|
| `spell_state` | `lua/parley/spell_state.lua` | new |

`spell_state` exports `target_at`, `same_target`, `transition`, and `accepts`. One buffer controller holds one immutable state value. `target_at(line, byte_col, mode, spans)` selects a whole word from byte spans provided by the Neovim boundary: Normal requires a character under the cursor; Insert can select the immediately preceding word at its end, but not across whitespace. Spans come from Neovim's Unicode-aware alphabetic matching with internal straight/curly apostrophes, excluding standalone apostrophes, digits and punctuation. This avoids pretending Lua byte character classes implement Unicode.

Target evidence includes buffer, window, row, start/end byte offsets, full word, changedtick, observed cursor/mode and generation. Word identity for dismissal excludes cursor position within the same word, mode and unrelated changedticks; exact acceptance evidence includes them. Pure `accepts(evidence, observation)` rejects any changed tick, buffer/window, cursor/mode, text or generation. This deliberately rejects move-away-and-back and edit-away-and-back races.

ARCH-PURE: target selection and transition tests supply data, without vim mocks. ARCH-DRY: the same target evidence drives sources, dismissal and acceptance; the legacy end-of-word helper retains its existing contract. Future sources can reuse the controller seam, but this issue adds no generic source framework.

### Integration points

| Name | Lives in | Status | Wraps |
|------|----------|--------|-------|
| `spell_blink` | `lua/parley/spell_blink.lua` | new | observations, timers, Blink lifecycle, keymap leases |
| `spell_source` | `lua/parley/spell_source.lua` | new | Blink provider callbacks and native spelling/edit APIs |
| `detach` | `lua/parley/spell.lua` | new | legacy and Blink teardown |
| `attach` | `lua/parley/spell.lua` | modified | backend selection and teardown |

`spell_blink` owns controllers indexed by attached buffer, exposes attach/detach/ownership and explicit request, and isolates the readiness probe. Its injected Blink boundary supports a stateful fake with provider registration, visible context, selected item, delayed source/resolve completions and show/hide events. Real pinned Blink tests check that model at the same seam. No new binary or remote-service dependency is introduced (ARCH-MOCK).

Every provider invocation passes a source-request event through the reducer. Before the debounce deadline, while dismissed on the unchanged word, or after invalidation, return an empty completed response; native Blink typing triggers cannot authorize spelling themselves. When the matching timer fires, the reducer issues one target-generation ticket; source requests may reuse it only while its exact observation remains valid. An explicit request through spell_blink is a reducer event that clears dismissal and authorizes a fresh ticket; arbitrary Blink requests do not clear suppression. Test native requests before the deadline, after Esc and after invalidation.

`spell_source` registers once under a namespaced provider ID, scoped to attached chats. It returns UTF-8 byte textEdit ranges and original evidence in item.data; filterText retains the misspelled query so valid corrections survive fuzzy matching. Never infer readiness from requiring Blink or its default fuzzy implementation. The only internal compatibility probe reads the already-loaded trigger module's buffer_events after setup; it does not require internals. Retry on subsequent scheduled buffer/mode/cursor events and fail closed without errors if incompatible.

## State, ordering and lifetime

ARCH-ORDER: authoritative transitions occur only through `spell_state.transition(state, event) -> new_state, effects`. Controller bookkeeping contains resource handles, not independent behavioral flags.

| State/event | Next state and effects |
|-------------|------------------------|
| detached / attach | idle; observe current target |
| idle, pending or open / new eligible target | pending with incremented generation; cancel old timer/request, hide only owned menu, restore maps, schedule one timer |
| pending / matching timer fires | pending request phase; request suggestions with immutable evidence |
| pending / matching nonempty result and visible owned context | open; acquire mapping leases |
| pending / empty, error or foreign-menu result | idle; release owned resources |
| open / Esc or explicit cancellation | dismissed(word identity); cancel work, hide owned menu and release leases |
| dismissed / same unchanged word (including within-word motion or mode switch) | dismissed; no new request |
| dismissed / different word, no word or changed word | idle then observe; clear suppression |
| dismissed / explicit request | pending with new generation |
| open / acceptance begins | idle; release visible resources but preserve acceptance ticket |
| any / stale timer, source result or resolve | unchanged; callback completes without edits |
| open / external hide | idle; do not reopen solely from the hide event |
| any / buffer leave, unsupported mode, detach, disable or wipeout | idle or detached; invalidate generation, cancel timers/requests, hide owned menu and restore leases |

Invalidate acceptance generation synchronously at cursor/text/mode/buffer event boundaries, before coalescing any observations; move-away-and-back within one scheduler turn must remain observable as invalidation. Observe CursorMoved, CursorMovedI, TextChanged, TextChangedI/P, InsertEnter/Leave, BufEnter/Leave, ModeChanged and BufWipeout through scheduled current-context reads. Cmdline, Visual, terminal and operator-pending modes are unsupported. Mode transitions between Normal and Insert invalidate pending acceptance but preserve same-word dismissal. Late callback effects must check both generation and current observation. Blink hides before execute: hiding alone does not invalidate an acceptance ticket; actual target/mode/buffer changes do. Only the source execution path consumes the ticket, exactly once.

Acceptance reconstructs the edit from original evidence, not Blink's cursor-adjusted textEdit. In Insert, restore that original range before invoking default implementation; in Normal, establish a separate undo entry, apply the explicit edit and put the cursor on the last replacement character. Invoke the provider completion callback exactly once on success or stale refusal. Test both paths with delayed resolution and Blink's hide-before-execute ordering.

Map leases snapshot existing buffer-local map dictionaries at menu open (after prep_chat installs registry maps); absence means deleting the lease reveals the original global mapping. Restore with mapset or an equivalent faithful API, covering callbacks, rhs, expr, remap, silent and replace_keycodes. Restore only if the installed mapping still matches the lease token/callback. Do not overwrite a user remap made while visible. Lease the five controls in both supported modes only for owned spelling menus, including mixed Insert menus containing spelling items; restore on every close/error/disable. Non-spelling menus retain Blink's existing controls.

## Operating envelope and boundaries

ARCH-CONSTRAINTS: this is a keystroke path. Read the current line only; cap inspection at 16 KiB per line and 128 bytes per word, skipping longer inputs without a popup. Debounce at 180 ms is a design choice, not a measured latency claim. One timer/request generation per current buffer; coalesce typing bursts, at most 20 suggestions and no full-buffer scan by the spell source. Native spellsuggest is synchronous and cannot be interrupted; measure representative English and configured-language cases, record p50/p95, and re-plan if it regularly exceeds 50 ms on this machine. No disk/network work occurs per key. Other Blink providers retain their own budgets.

ARCH-SECURE: text and option values are untrusted data. Use option APIs, not interpolated Ex commands, for spelllang. Validate finite option ranges and current buffer validity; edits use Neovim APIs and never execute suggestion text. Tests isolate XDG data/config/state/cache, use no user credentials and never write to the installed Blink checkout.

ARCH-FUNERAL: per-buffer timers close on detach/wipeout and cancel on leave; map snapshots disappear at lease release; evidence is retained only by the current request/acceptance callback, then released. One globally registered provider lives with the Neovim process. No disk cache or accumulating logs are created. Test repeated attach/disable/re-enable and buffer destruction for leaked autocmds/handles.

## Chunk 1: Shared integration and verification

### Task 1: Pure targets and transition contract

Files: create `lua/parley/spell_state.lua`, `tests/unit/spell_state_spec.lua`; add `chat/spell_typeahead` mapping in `atlas/traceability.yaml` covering the new tests and existing spell tests.

- [x] `spell_state.target_at` and `same_target`: data-only generated byte/span inputs, asserting whole-word bounds and semantic identity independently of cursor placement.
- [x] `spell_state.transition` and `accepts`: reproducible generated event sequences with permuted completion order, asserting dismissal, generation and exactly-once acceptance invariants.
- [x] Run `make test-spec SPEC=chat/spell_typeahead`; require failures at the missing target/state exports, not unrelated harness setup.
- [x] Implement the pure exports and immutable transition/effect values. Re-run until these cases pass (later integration files may still be absent).
- [x] Commit explicit task files with issue reference and author-model trailer; record red/green evidence in the issue.

### Task 2: Controller and source

Files: create `lua/parley/spell_blink.lua`, `lua/parley/spell_source.lua`, `tests/helpers/fake_blink.lua`, `tests/integration/spell_blink_spec.lua`; extend `tests/unit/spell_spec.lua` and `tests/integration/spell_chat_spec.lua`.

- [x] `spell_blink.attach`/`detach` and its observation handler: a stateful fake with controllable source/resolve queues, asserting bounded resources and reducer-only admission across generated lifecycle sequences.
- [x] `spell_source.get_completions`/`execute`: adversarial stale observations and reordered resolve/hide callbacks, guarded by immutable evidence and exactly-once edit/callback assertions.
- [x] Mapping lease acquisition/release: generated effective-map dictionaries and interleaved user remaps, asserting lossless restoration and ownership checks.
- [x] Run the mapped spell suite and confirm those failures, then implement thin effects around the pure reducer. Return cancellation functions for pending source work; canceled callbacks may complete but cannot publish effects.
- [x] Re-run the spell suite; verify no leaked timer/map/autocmd after repeated attach cycles. Commit explicit files and evidence.

### Task 3: Plugin and app ownership

Files: modify `lua/parley/spell.lua`, `lua/parley/config.lua`, `lua/parley/init.lua` prep_chat, `lua/parley/neighborhood.lua`, `lua/parley/keybinding_registry.lua`, and (only if needed for shared defaults) `packaging/starter-config/init.lua`. Extend `tests/integration/keybinding_agreement_spec.lua`. Extend `tests/integration/spell_chat_spec.lua` and `tests/packaging/completion_compatibility.lua`.

- [x] `spell.attach` and `neighborhood.attach_cmp_completion`: parameterize backend/option availability, asserting one owner, preserved providers and manual path completion.
- [x] Selection-mode adapter: delayed mixed-provider refresh under arbitrary user selection settings, asserting unchanged text until acceptance and unchanged foreign-context behavior/configuration.
- [x] Implement backend teardown/reconciliation and the prep_chat call site, including late Blink activation after legacy attachment. Register transient key metadata using existing registry conventions.
- [x] `prep_chat` keyboard integration: drive the registry and native editing controls through remappable keys, asserting menu-dependent behavior and no-menu equivalence to the baseline.
- [x] Run `make test-spec SPEC=chat/spell_typeahead`, then `make test-spec SPEC=ui/keybindings`, then `make test-spec SPEC=infra/starter`, sequentially. Expected: pass; investigate any baseline failure instead of labeling it green.
- [x] Commit the verified wiring and update the issue log.

### Task 4: Real dependency acceptance and documentation

Files: create `tests/packaging/spell_compatibility.lua` and `scripts/check-spell-compatibility.sh`; extend README spelling/setup sections, `atlas/chat/spell_typeahead.md`, `atlas/ui/keybindings.md`, `atlas/traceability.yaml`, `atlas/index.md`. This checkout has no generated doc/ help file.

- [x] Write real keyboard scenarios parameterized for plugin and production starter options. Boot real chat setup with real pinned Blink; fake only installation/provider services unrelated to spelling. The runner verifies the pin, sets temporary XDG roots and PARLEY_RUNTIME/PARLEY_BLINK_RUNTIME, launches with `nvim --headless -u NONE -i NONE -c 'luafile tests/packaging/spell_compatibility.lua'`, and cleans its owned temporary profile on exit.
- [x] `spell_blink` and `spell_source` real conformance: run the same editing/dismissal invariants through remappable key streams and controlled late provider completions in both distributions/modes; use predicate waits and exact text/cursor/undo assertions.
- [x] Run `PARLEY_BLINK_RUNTIME=/Users/xianxu/workspace/parley.nvim/demo/workspace/data/parley/lazy/blink.cmp scripts/check-spell-compatibility.sh`; require plugin and app pass markers and nonzero exit on any assertion failure.
- [x] Run the existing completion_compatibility.lua under the same isolated runner profile, preserving its no-native-library assertion. Record spell timing and bounded-work observations.
- [x] Document plugin Blink setup, defaults, independent underline/menu switches, fallback and single-owner behavior, mode controls and limits. Explain #304's short-word behavior versus legacy min_word. Add revision notes to #259/#288 only through their issue-detail workflow when reconciliation is needed; do not change their cards or mark them done.
- [x] Run mapped suites sequentially again after the final edits, `make lint`, `git diff --check`. Stage explicit files; commit tested code/docs with an issue reference and Co-Authored-By trailer.
- [ ] Tick completed issue/plan checkboxes; run `sdlc issue sync --issue 304`. Run `sdlc close --issue 304 --verified '<actual command results and timing evidence>'`; let the binary run the mandatory boundary review, fix findings and record lessons before retrying. Then publish through `sdlc pr` and `sdlc merge` under the existing authorization/workflow contract.

## Approval checkpoint

This plan is outside the quick-flow shell. Obtain approval for the concrete design, then run `sdlc change-code --issue 304`; satisfy plan-quality before deriving the requested estimate. No production edits before that gate. Preserve unrelated main commit 8f0e7a48 and the untracked continuation file.

## Revisions

### 2026-09-29 — Fresh-context plan review

- Reason: reviewer identified three ways observations/source requests could bypass the intended lifecycle.
- Delta: invalidate acceptance synchronously at event boundaries before deferred reads; make native Blink source admission pass through reducer-issued tickets and preserve dismissal/debounce; add Normal TextChanged and corresponding stationary-edit tests. Resolved auto-insert through pinned public navigation options and corrected repository file paths.

### 2026-09-29 — Implementation approval and full gate findings

- User approved execution with “continue”. Explicit full flow selected because the anticipated code exceeds the quick shell even though its inference uses design size.
- PQ-1: replace the insufficient public-navigation-only preview safeguard with one lifetime-owned internal selection-mode adapter; it changes no user configuration and delegates foreign contexts.
- PQ-2: compress task test inventories into named function strategies and adversarial classes, retaining executable commands and real-dependency acceptance.

### 2026-09-29 — Runtime conformance findings

- Real Blink exposed empty/late filetype registration; explicit spell requests append the source while preserving the enabled provider list, and FileType re-registers the current type.
- Force-showing mixed providers for a correctly spelled word can reopen buffer completion after acceptance and steal the next Return. The controller now shares Source.is_misspelled with the source and only requests automatic correction for a flagged word.
- Legacy detach is now explicit in Core concepts. Transient key metadata carries chat scope so the shipped-key guard distinguishes chat leases from picker Tab bindings.

### 2026-09-29 — BR-1 acceptance context invalidation

- Same-buffer window departure, entry, and departure/return during delayed resolution are part of the lifecycle. WinLeave synchronously invalidates through the reducer and releases menu/maps; WinEnter schedules a fresh observation. This covers window/tab transitions even when buffer and cursor remain identical.
- Controller regressions assert cleanup and re-observation; real pinned Blink replays delayed resolution while staying in the second window and returning to the origin.
