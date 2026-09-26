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
the prefix ready for a private note. Register it through the shared keybinding
registry so configuration and help remain consistent. (ARCH-DRY)

## Done when

- `Option+p` is advertised and bound in Parley buffers in Normal and Insert mode.
- It creates a new line below the current line with the configured private-note prefix at column one.
- Focused integration coverage proves the mapping effect and cursor placement.

## Plan

- [ ] Add the registry/config entry and buffer callback.
- [ ] Add focused integration coverage, run it, and verify the full relevant test slice.

## Log

### 2026-09-26
