---
id: 000304
status: open
deps: []
github_issue:
created: 2026-09-29
updated: 2026-09-29
estimate_hours:
card_mirror: '91fe7bac0955adf6af3973cba6b973540bf83ad2' # card fields mirrored from issue-cards; edit via sdlc
---

# Unify automatic spell suggestions in Blink

## Problem

The native `z=` spelling interface feels awkward in parley_app. Buffer-word completion already uses Blink in the app, while the main plugin has a separate optional spell typeahead popup. Users need one consistent correction interface in both distributions, including when revisiting an existing misspelling.

## Spec

- Provide Blink-based spell typeahead in the main Parley plugin, not only in the packaged app. The app consumes the same spelling integration and must work out of the box.
- Automatically show the Blink spelling menu when the cursor is on a misspelled word in either Normal or Insert mode. This includes moving onto an existing word, entering either mode on it, and creating a misspelling while typing; it must not require `z=` first.
- Offer corrections for the whole word under the cursor, including a cursor in the middle of a word. Accepting a suggestion replaces that word without stranding its suffix or changing surrounding text; do not silently autocorrect.
- Use the established menu controls: Tab/Down select next, Up selects previous, Enter accepts, Esc dismisses. With no menu, keys retain native behavior. Showing or dismissing corrections must not unexpectedly switch editing modes.
- Coexist with buffer-word completion and Parley shortcuts through one menu owner. Integrate or retire the old spell popup/mapping path rather than running two competing menus.
- Avoid a menu that immediately reopens after Esc on the same unchanged word. Moving to another word, changing the word or explicitly requesting suggestions may re-enable it. Correct words, whitespace and punctuation should not open a correction menu.
- Keep spell language and existing spell settings meaningful. Popup behavior should be configurable independently of visible spell underlines; plugin users need documented Blink setup and graceful behavior if Blink is unavailable.

Related work: #259 covers compact spell/buffer completion and historical typing thresholds; #288 covers plugin Blink sources, including neighborhood paths and spelling. This ticket records the explicit plugin-plus-app and automatic Normal/Insert cursor-trigger requirements. Coordinate overlapping spelling work when implementing; neighborhood-path completion remains #288's scope. A typing threshold must not prevent correcting a short existing misspelling merely by placing the cursor on it.

Implementation questions to resolve during design: verify the pinned Blink version's Normal-mode capabilities and required adapter; define event/debounce and dismissal state so cursor movement remains responsive. ARCH-DRY: shared plugin spelling integration and a single completion UI owner. Do not assume enabling the legacy `chat_spell.typeahead` alone meets this contract.

## Done when

- In both the main plugin and parley_app, misspelling a word while typing produces Blink spelling suggestions.
- In both Normal and Insert modes, moving onto an existing misspelled word automatically opens the correction menu, including short words and mid-word cursor positions.
- Keyboard selection, acceptance and dismissal work consistently; correction replaces exactly one whole word, supports undo, and preserves the surrounding text and appropriate editing mode.
- Correct words and non-word positions do not trigger corrections; Esc dismisses without an immediate reopen loop or unintended mode switch.
- Existing buffer-word completion, app pairing, send shortcuts and no-menu native keys continue to work; no competing legacy popup or Enter mapping remains active.
- Tests exercise actual Blink in plugin and app configurations, typing and cursor-motion triggers in both modes, whole-word edits, stale results after cursor changes, dismissal/retrigger behavior and graceful absence of Blink. README and atlas document setup and controls.

## Plan

- [ ] Reconcile overlapping spelling scope with #259/#288 and design shared Blink sources, Normal-mode presentation, triggers and dismissal lifecycle.
- [ ] Implement the shared plugin integration and app wiring with regression coverage.
- [ ] Verify real keyboard behavior in both distributions and document the resulting interface.

## Log

### 2026-09-29

User requested a ticket only, not implementation. Explicit priorities: use Blink for spell typeahead in main Parley, ensure it works in parley_app, and automatically pop the Blink spelling menu over a misspelled word in Normal or Insert mode. Current spell underlines are enabled; legacy spell typeahead is disabled and owns a separate popup/Enter mapping when enabled. The app already has Blink buffer completion and the requested selection/acceptance/dismissal keys.
