---
id: 000377
status: open
deps: []
github_issue:
created: 2026-10-17
updated: 2026-10-17
estimate_hours:
collaboration-mode: collaboration
card_mirror: '62825bc936b6a48b87142d4e5c45026acf763751' # card fields mirrored from issue-cards; edit via sdlc
---

# Remap keys: Alt+i pastes an image (matching pair draft), Alt+b creates a sub-chat

## Problem

Pair's draft nvim puts "attach an image" on Alt+i. In parley, Alt+i creates a sub-chat (branch_ref), and image paste sits on Alt+v. The operator wants one image key across both editors, and wants sub-chat creation moved to Alt+b.

## Spec

- paste_image: `<M-i>` (n, i, parley buffers). `<M-v>` is dropped and left unbound. The TL approved this; adding it back is a one-line change.
- branch_ref: `<M-b>` plus the legacy `<C-g>i` alias (n, i, v, parley buffers).
- Conflict check, done before the change and reported to the hub:
  - Inside parley, `<M-b>` was unbound in every mode and buffer type.
  - Pair's own zellij config binds neither key.
  - Couch's chords and pair's global chords are clear of both. Couch's Ctrl+Alt+b is a different chord.
  - Pair's draft nvim, which never loads parley, uses Alt+b for scrollback.
- A user who sets `chat_shortcut_*` explicitly keeps their own keys.

## Done when

- The shipped defaults resolve paste_image to `{ "<M-i>" }` and branch_ref to `{ "<M-b>", "<C-g>i" }`.
- `<M-v>` is not bound by default.
- Help, README and atlas name the new keys.
- The specs that pin these keys are updated, and the suite passes.

## Plan

- [ ]

## Log

### 2026-10-17
