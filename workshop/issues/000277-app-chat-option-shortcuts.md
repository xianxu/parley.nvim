---
id: 000277
status: codecomplete
deps: []
github_issue:
created: 2026-09-25
updated: 2026-09-25
estimate_hours:
started: 2026-09-25T23:05:53-07:00
flow: {kind: quick, provenance: inferred, spec: "bea912e4", done: "27d3bcad"}
actual_hours: N/A
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
- 2026-09-25: closed — Starter suite passed including real welcome-buffer normal/insert callback dispatch for Option f/n and Ctrl-g f/c, retained Ctrl-g n and unchanged plugin defaults. Regression failed before fix with Option+n running the wrong action. Lua lint and scoped whitespace checks pass; user tutorial edits excluded. Actual telemetry returned no measurable activity twice; record N/A rather than fabricate hours.; review verdict: SHIP

- Regression first failed because Option+n invoked new-question in the real welcome buffer.
- Starter suite passed (including normal/insert effective callback checks and unchanged plugin defaults); changed Lua lint and scoped whitespace checks pass.
- ARCH-DRY: aliases use the registry callbacks via pure starter options; no remap layer.
