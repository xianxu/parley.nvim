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

- [x] Add the registry/config entry and buffer callback.
- [x] Add focused integration coverage, run it, and verify the full relevant test slice.

## Log

### 2026-09-26

- Closure review corrections: README documents Normal/Insert private-note
  insertion, both configuration keys, and the Ctrl+g b prune migration. Restore
  the generated rainbow side question to plain text so the shipped tutorial
  does not depend on an untracked chat; startup checks seeded link destinations.

- Closure audit: corrected the obsolete prune default assertion after Option+p
  moved to private notes. The complete ui/keybindings slice now passes,
  including private prefix, configuration, registry and architecture checks.
- Added real Normal/Insert keystroke coverage with a custom prefix: all three
  private-note tests pass, preserving adjacent text and cursor placement.
  Hardcoding the default prefix makes both new tests fail.

- Discovered `<M-p>` was already the shipped chat-prune primary. Moved prune to
  its stable `<C-g>b` binding so private-note insertion has one meaning.
- Direct integration test passes:
  `nvim -n --headless --noplugin -u tests/minimal_init.vim -c 'PlenaryBustedFile tests/integration/private_note_prefix_spec.lua' -c 'qa!'`.
- Direct keybinding unit test passes (80 assertions). The broader `ui/keybindings`
  slice also includes two pre-existing architecture failures about
  `create_child_chat` in the active issue sweep; the focused production tests are green.
