---
id: 000295
status: working
deps: []
github_issue:
created: 2026-09-28
updated: 2026-09-28
estimate_hours:
card_mirror: '7266608d9423fa7744968468654a3f9e346582f7' # card fields mirrored from issue-cards; edit via sdlc
started: 2026-09-28T14:55:58-07:00
flow: {kind: quick, provenance: inferred, spec: "1d87dc59", done: "e3574f5d"}
---

# Continue private note prefixes on Return

## Problem

Private notes are single-line annotations. Pressing Return currently leaves the next line unprefixed, making multiline private notes tedious and risking accidental submission of the continuation.

## Spec

In regular chat buffers, Insert-mode Return on a private-note line continues the configured `chat_local_prefix` (default `🔒:`) on the new line. Splitting note text keeps both pieces private; repeated Return continues empty note lines too. Delete the new prefix to leave private notes. Ordinary lines and non-chat buffers keep their existing behavior; prompt buffers retain Return-to-submit.

Use buffer-local native comment continuation during chat preparation, preserving existing comment definitions and Return mappings. This reuses Neovim editing/undo and composes with spell completion (ARCH-DRY); no per-keystroke scanning or new persistent state. Test actual keyboard input, custom prefixes and mapping coexistence. User explicitly requested creation followed by implementation; proceed within this small scope.

## Done when

- Return continues default and custom note prefixes, including mid-line splits and repeated empty note lines.
- Ordinary text and non-chat buffers are unchanged; prompt and existing Return mappings retain ownership.
- Production keyboard regressions and mapped keybinding suite pass; atlas describes the behavior.


## Plan

- [ ] Add failing keyboard regressions, configure native chat continuation, and verify mapped tests.
- [ ] Document behavior and close through the SDLC review gate.


## Log

### 2026-09-28
