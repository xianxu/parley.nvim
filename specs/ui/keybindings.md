# Spec: Key Bindings Help

## Overview
Parley exposes a key-bindings help command that lists active default shortcuts derived from runtime config.

## Command
- `:ParleyKeyBindings`: Opens a centered floating window with grouped shortcut help.
- The window is scratch-only (`nofile`) and can be closed with `q` or `<Esc>`.

## Default Shortcut
- `global_shortcut_keybindings` defaults to `<C-g>?` in normal and insert modes.
- `global_shortcut_chat_dirs` defaults to `<C-g>h` in normal and insert modes.
- In insert mode, Parley exits insert mode before showing the key-bindings window.

## Content Requirements
- The help list MUST include:
  - global chat/note shortcuts,
  - chat/markdown shortcuts,
  - mode toggles (`web_search`, `raw request`, `raw response`, interview mode).
- The Chat Finder section MUST include both left and right recency-cycle shortcuts, plus delete and move.
- The Note Finder section MUST include both left and right recency-cycle shortcuts, plus delete.
- Displayed shortcuts MUST be resolved from active runtime keymaps when available.
- If a runtime keymap cannot be found, Parley falls back to configured/default shortcut values.
