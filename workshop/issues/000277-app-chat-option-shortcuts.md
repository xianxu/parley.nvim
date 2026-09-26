---
id: 000277
status: working
deps: []
github_issue:
created: 2026-09-25
updated: 2026-09-25
estimate_hours:
started: 2026-09-25T23:05:53-07:00
flow: {kind: quick, provenance: inferred, spec: "bea912e4", done: "27d3bcad"}
---

# Add app Option shortcuts for finding and creating chats

## Problem

App users want Option+f to find chats and Option+n to create a new chat.

## Spec

Add app-only aliases through starter options and the existing registry (ARCH-DRY).
Keep Ctrl+g f/c; remove the app Option+n new-question alias while retaining Ctrl+g n.
Use the existing action modes and callbacks, including normal and insert mode.

## Done when

- App Option+f/n invoke finder/new chat without a buffer-local new-question collision; Ctrl+g f/c/n remain available.
- Plugin defaults remain unchanged; shortcut documentation describes the app aliases.

## Plan

- [x] Update starter aliases, verify effective mappings in chat buffers, and document app shortcuts.

## Log

### 2026-09-25

- Regression first failed because Option+n invoked new-question in the real welcome buffer.
- Starter suite passed (including normal/insert effective callback checks and unchanged plugin defaults); changed Lua lint and scoped whitespace checks pass.
- ARCH-DRY: aliases use the registry callbacks via pure starter options; no remap layer.
