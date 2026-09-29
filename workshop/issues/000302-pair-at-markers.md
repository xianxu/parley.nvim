---
id: 000302
status: working
deps: []
github_issue:
created: 2026-09-29
updated: 2026-09-29
estimate_hours:
card_mirror: 'e4526c79552e2b7e6c10403e6035e62873ff7c06' # card fields mirrored from issue-cards; edit via sdlc
started: 2026-09-29T11:08:55-07:00
flow: {kind: quick, provenance: inferred, spec: "dbd4d9ad", done: "7f0c9902"}
---

# Auto-pair double-at markers while typing

## Problem

Typing paired double-at markers currently requires manually entering and positioning both delimiters.

## Spec

In chat Insert mode, the second @ creates @@|@@, with the cursor between delimiters. Typing the closing @@ moves across existing closers. Ordinary single @ remains literal. Preserve effective user mappings, respect default_keymaps=false, and keep repeated preparation idempotent.

ARCH-DRY: reuse native_map and its registry exemption. ARCH-PURE: isolate line/byte-column decisions in a stateless helper; the mapping reads the editor and returns keys. ARCH-CONSTRAINTS: scan only the current line on @, never the chat. ARCH-MOCK/SECURE/STATE/FUNERAL: no external service, secrets, inter-event state, or durable runtime artifacts. ARCH-PURPOSE: verify actual remappable typing and one-step undo.

## Done when

- Real typing creates paired markers, skips closers, preserves existing pairs and single-at text, and undoes in one step.
- Existing global/buffer mappings and disabled defaults remain effective; non-chat buffers are unchanged.
- Keybinding and architecture tests pass; README and atlas describe the shortcut.

## Plan

- [ ] Add failing production-key tests for pairing, cursor, skip, reuse, multiple pairs, mapping ownership, scope and undo.
- [ ] Add pure pairing helper and minimal native insert mapping.
- [ ] Document, run keybinding and single-source checks, and commit for integration before close.

## Log

### 2026-09-29
