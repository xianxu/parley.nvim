---
id: 000284
status: working
deps: []
github_issue:
created: 2026-09-26
updated: 2026-09-26
estimate_hours:
started: 2026-09-26T14:08:57-07:00
flow: {kind: quick, provenance: inferred, spec: "67078b5f", done: "1b152854"}
---

# Add private note prefix shortcut

## Problem

## Spec

Add a buffer-local `Option+p` shortcut for Parley chat and Markdown buffers. The
shortcut creates a new line below the current line, inserts the configured
`chat_local_prefix` (`🔒:` by default) at column one, and leaves the cursor after
the prefix ready for a private note. `Option+p` currently prunes chats, so move
prune's shipped primary to its existing `<C-g>b` alias to keep the new shortcut
unambiguous. Register both actions through the shared keybinding registry so
configuration and help remain consistent. (ARCH-DRY)

## Done when

- `Option+p` is advertised and bound in Parley buffers in Normal and Insert mode.
- It creates a new line below the current line with the configured private-note prefix at column one.
- Chat pruning remains available on `<C-g>b` without sharing `Option+p`.
- Focused integration coverage proves the mapping effect and cursor placement.

## Plan

- [ ] Add the registry/config entry and buffer callback.
- [ ] Add focused integration coverage, run it, and verify the full relevant test slice.

## Log

### 2026-09-26

- Discovered `<M-p>` was already the shipped chat-prune primary. Moved prune to
  its stable `<C-g>b` binding so private-note insertion has one meaning.
- Direct integration test passes:
  `nvim -n --headless --noplugin -u tests/minimal_init.vim -c 'PlenaryBustedFile tests/integration/private_note_prefix_spec.lua' -c 'qa!'`.
- Direct keybinding unit test passes (80 assertions). The broader `ui/keybindings`
  slice also includes two pre-existing architecture failures about
  `create_child_chat` in the active issue sweep; the focused production tests are green.
