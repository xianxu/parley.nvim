---
id: 000263
status: open
deps: []
github_issue:
created: 2026-09-16
updated: 2026-09-16
estimate_hours:
---

# Quick key to insert the chat question prefix at cursor

## Problem

Starting a new question in a Parley chat buffer means typing `💬:` — an emoji
the keyboard cannot produce. The operator works around this with a personal
clipboard shortcut, but end users have no discoverable quick key: they must
remember the emoji, copy-paste it, or reach for the OS emoji picker. A shipped
chat UI should provide the keystroke itself.

## Spec

Provide a **single quick key** that inserts the configured chat user prefix
(`config.chat_user_prefix`, default `💬:`) plus a trailing space at the
cursor:

- Works in **normal and insert mode**, buffer-local to Parley chat buffers.
  In normal mode, insert at the cursor and enter insert mode after; in insert
  mode, insert at the cursor without leaving insert mode.
- On an empty line or at column 0, insert at line start. Otherwise insert at
  the cursor position. If the line already starts with the prefix, do not
  duplicate it — move the cursor after it instead.
- Read the prefix from `config.chat_user_prefix` rather than hardcoding `💬:`,
  so an operator override is honored.
- Pick a chord that does not collide with existing Parley bindings — candidate
  under `<C-g>` (Parley's finder prefix) or a `<leader>` mapping; keep it
  chat-buffer-local, never global. Document it in help, atlas and which-key.
- No clipboard dependency. This is the end-user path that replaces the
  operator's clipboard workaround; any clipboard-based insertion stays a
  separate power-user affordance.

## Done when

- Pressing the quick key in a chat buffer inserts `💬: ` at the cursor (or
  moves after an existing prefix) with no clipboard or emoji picker involved.
- Works in both normal and insert mode, is undoable as one step, and leaves
  the cursor in insert mode ready to type the question.
- The inserted text follows `config.chat_user_prefix` when overridden.
- The keybinding is registered buffer-locally, documented in help/atlas/
  which-key, and shadows no existing Parley chord (verified against the
  keybinding registry).
- Focused tests cover insertion on an empty line, mid-line, an
  already-prefixed line, a non-default `chat_user_prefix`, and the normal/
  insert mode transitions.

## Plan

- [ ] Pick the chord (audit existing `<C-g>` and `<leader>` bindings in the
  registry) and implement insertion from `config.chat_user_prefix`.
- [ ] Register the keymap buffer-locally for chat buffers (normal + insert),
  group as one undo step, handle the already-prefixed case.
- [ ] Add unit/integration tests for insertion positions, prefix override and
  mode handling.
- [ ] Document in help, which-key and atlas.

## Log

### 2026-09-16

Filed from operator: "quick command to insert `💬:` — while I just have a
clipboard shortcut, as an end user facing [the product] needs to provide
that."

Captured first in `brain#000017` as `[pair / parley]`, because the sibling
repo write was sandbox-blocked; migrated here. The same need exists in
`pair`'s nvim draft pane — if that surface wants it too, file a sibling issue
in `pair` rather than widening this one. The operator's transcription of the
product name ("arle") matched no repo on disk; read as the end-user-facing
chat surface, which is Parley.
