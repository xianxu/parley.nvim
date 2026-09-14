---
id: 000249
status: working
deps: []
github_issue:
created: 2026-09-14
updated: 2026-09-14
estimate_hours: 0.51
started: 2026-09-14T09:15:17-07:00
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

Acceptance boundary: close through the binary-owned fresh review.

## Log

### 2026-09-14

- User reported Ctrl+d failure while preparing tutorial. Confirmed default-key alias; independent reproduction investigating real picker/confirmation flow. Trivial default-key correction: use change-code --no-judge for planning, retain the full closing code review. Preserve existing unrelated workspace edits.

### 2026-09-14 — Implementation

- Independent actual-picker reproduction confirmed Ctrl+d invoked tree deletion; native y confirmation worked. No second failure reproduced.
- Six regression cases failed before the two-default fix: config and registry fallback each dispatched the wrong delete action and lacked the new tree chord. All six now pass (54 finder spec tests total), including saved-file outcomes and resume after confirmation.
- Updated README finder instructions and recorded the key-normalization lesson. Full make test passed (256 spec files; lint clean). Native Insert-mode Ctrl+d plus native y confirmation deleted the temporary selected file through the single-chat path; /tmp/parley249-native.log. No architectural surface changed, so close uses --no-atlas; README covers the default-key change.
