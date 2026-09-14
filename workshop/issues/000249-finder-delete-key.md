---
id: 000249
status: working
deps: []
github_issue:
created: 2026-09-14
updated: 2026-09-14
estimate_hours: 0.51
started: 2026-09-14T09:15:17-07:00
actual_hours: 0.21
---

# Fix chat finder delete key collision

## Problem

Ctrl+d in Chat Finder does not invoke single-chat deletion. The shipped delete_tree key `<C-D>` is identical to `<C-d>` after Neovim termcode normalization; the later extra mapping overwrites single deletion.

## Spec

Keep Ctrl+d for deleting the selected chat. Move finder tree deletion to Ctrl+g then uppercase D (`<C-g>D`), matching the existing chat-tree command chord. Update both config.lua defaults and keybinding_registry.lua fallback so help and runtime agree. Preserve confirmation, cancellation, finder refresh, and custom shortcut overrides.

Facts: lua/parley/config.lua:484-485 and keybinding_registry.lua:834-845 define colliding defaults; float_picker.lua:1495 registers them sequentially. A headless Neovim probe confirmed both termcodes equal byte 4. Existing chat_finder_logic tests replace finder config and often invoke captured callbacks rather than actual keys.

ARCH-DRY/PURPOSE: fix both existing default sources and test the live key rather than a callback by name. ARCH-PURE: only binding data changes; existing picker dispatch and deletion own effects. ARCH-ORDER: existing confirmation/suspend/resume remains authoritative. ARCH-CONSTRAINTS: no added per-keystroke work. ARCH-MOCK/SECURE: integration uses temporary chats, real local picker and controlled confirmation; no service or credentials. ARCH-FUNERAL: no new durable runtime artifacts.

## Done when

- Ctrl+d reaches single-chat confirmation from the finder and confirmed deletion removes only the selected chat.
- Tree deletion has a distinct reachable default chord; cancelling preserves files.
- Runtime defaults, registry fallback, and displayed help agree; focused tests and lint pass.

## Estimate

Method A, estimate-logic-v3.1 (repo calibration at brain/data/life/42shots/velocity/estimate-logic-v3.1.md, provisional/stale). One focused Lua/Neovim bugfix: low-end design 1h × 0.2 resolved-spec factor = 0.2h; implementation 0.5h × 0.4 ship-time factor = 0.2h, covering regression setup and binding change. One review: design 0h, implementation 0.2h × 0.4 = 0.08h. Familiar stack, existing picker/file fixture seams; no new library needed. 15% design buffer.

```estimate
model: estimate-logic-v3.1
familiarity: 1.0
item: lua-neovim design=0.2 impl=0.2
item: milestone-review design=0 impl=0.08
design-buffer: 0.15
total: 0.51
```

## Plan

- [x] Add live-picker regression coverage in tests/unit/chat_finder_logic_spec.lua using shipped defaults: drive normalized keys and compare temporary files/confirmation targets, including cancellation and child preservation.
- [x] Change only delete_tree defaults in config.lua and keybinding_registry.lua to `<C-g>D`; verify default and fallback resolution and help.
- [x] Run focused finder/keybinding tests and full suite/lint.

- [x] Preserve finder-local bindings in starter_config.options and test starter option resolution.
- [x] Exercise the actual ChatFinder with starter options and run exact-launcher native smoke plus full tests/lint.

Acceptance boundary: close through the binary-owned fresh review.

## Log

### 2026-09-14
- 2026-09-14: closed — make test passed: 256 specs; lint 0 warnings/errors; six live-picker regression cases red then green; native Insert-mode Ctrl+d and y deleted only selected temp chat. No architectural surface change: default shortcut correction documented in README.; review verdict: SHIP

- User reported Ctrl+d failure while preparing tutorial. Confirmed default-key alias; independent reproduction investigating real picker/confirmation flow. Trivial default-key correction: use change-code --no-judge for planning, retain the full closing code review. Preserve existing unrelated workspace edits.

### 2026-09-14 — Implementation

- Independent actual-picker reproduction confirmed Ctrl+d invoked tree deletion; native y confirmation worked. No second failure reproduced.
- Six regression cases failed before the two-default fix: config and registry fallback each dispatched the wrong delete action and lacked the new tree chord. All six now pass (54 finder spec tests total), including saved-file outcomes and resume after confirmation.
- Updated README finder instructions and recorded the key-normalization lesson. Full make test passed (256 spec files; lint clean). Native Insert-mode Ctrl+d plus native y confirmation deleted the temporary selected file through the single-chat path; /tmp/parley249-native.log. No architectural surface changed, so close uses --no-atlas; README covers the default-key change.

## Revisions

### 2026-09-14 — Exact app launcher exposes missing starter bindings

Reason: user reports the collision fix did not restore Ctrl+d with `NVIM_APPNAME=parley PARLEY_RUNTIME="$PWD" nvim -u "$PWD/packaging/starter-config/init.lua"`. Earlier default-profile smoke did not exercise the starter.

Delta: starter_config.options disables default_keymaps and only opts into Ctrl+g/Alt families, omitting Ctrl+d and other finder-local controls. Preserve every registry binding scoped to a finder while retaining the existing restricted global/editor key policy. This covers chat/note/issue finder-local actions, not just the reported key (ARCH-PURPOSE). Use existing registry scope metadata (ARCH-DRY); no new UI effects.

- starter_config.options: assert local delete/move/recency/filter bindings survive while unrelated global shortcut families remain disabled.
- Existing real ChatFinder mapping regression: add starter-derived options as a third configuration source, verifying confirmation, cancellation, and child preservation through effective mappings.
- Exact starter-config launcher: native keyboard/confirmation smoke with actual Lazy/plugins and isolated HOME/XDG directories; do not call setup({}) after startup. This is the acceptance environment for the reported bug.

### 2026-09-14 — Starter-profile reproduction and correction

- Exact launcher reproduced no confirmation with an empty Ctrl+d map. Real plugins copied into an isolated profile; no user chats/auth used. The probe retains the actual starter setup and drives native Ctrl+d plus native y input. It now passes: /tmp/parley249-exact-launcher.log (runner /tmp/parley-starter-delete-runner.py).
- Starter preserves all finder-local registry keys, including move, recency and filter actions, while global/editor prefix policy stays unchanged. Nine actual-picker cases now include starter options passed through setup, whose explicit-key bookkeeping is required by the resolver. Old policy produces two expected missing-Ctrl+d failures; corrected policy passes. Pure policy coverage checks chat, note and issue finder controls.
- Updated app configuration documentation and recorded the missed entry-point lesson. Full make test passed, exit 0: 256 spec files; lint 0 warnings/errors in 447 files.
