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

In regular chat buffers, Insert-mode Return on a private-note line continues the configured `chat_local_prefix` (default `🔒:`) on the new line. Splitting note text keeps both pieces private; repeated Return continues empty note lines too. Delete the new prefix to leave private notes. Ordinary prose and non-chat buffers keep their existing behavior; prompt buffers retain Return-to-submit.

Use buffer-local native comment continuation during chat preparation, preserving existing comment definitions and Return mappings. This reuses Neovim editing/undo and composes with spell completion (ARCH-DRY); no per-keystroke scanning or new persistent state. Test actual keyboard input, custom prefixes and mapping coexistence. User explicitly requested creation followed by implementation; proceed within this small scope.

### Core concepts

| Symbol | Location | Status |
| --- | --- | --- |
| `prep_chat` | `lua/parley/init.lua` | modified |

## Done when

- Return continues default and custom note prefixes, including mid-line splits and repeated empty note lines.
- Ordinary prose and non-chat buffers are unchanged; prompt and existing Return mappings retain ownership.
- Production keyboard regressions and mapped keybinding suite pass; atlas describes the behavior.


## Plan

- [x] Add failing keyboard regressions, configure native chat continuation, and verify mapped tests.
- [x] Document behavior; submit implementation to the SDLC close review gate.


## Log

### 2026-09-28

## Revisions

### 2026-09-28 — native continuation semantics
Spec review identified that `formatoptions=r` also continues existing comment leaders and indented leaders. Accept Neovim's native comment behavior in chat buffers rather than replacing users' Return mappings; ordinary prose remains unchanged. Only column-one private-note prefixes are private according to the existing parser; this change does not broaden privacy classification.

### 2026-09-28 — test contract
The mapped architecture guard requires a Core concepts row even for quick-flow changes; added the existing prep_chat owner. Red keyboard tests demonstrate missing prefixes for default/custom markers, repeated Return, splits, and spell typeahead.

### 2026-09-28 — unsupported native leaders
A probe found that Neovim cannot represent every custom prefix as a comment leader (for example a backslash immediately followed by a comma). Preserve chat preparation and report a warning if native option validation rejects the prefix; those unusual prefixes remain manually usable. The standard prefix and tested literal colon/comma/backslash variants continue automatically.

### 2026-09-28 — implementation and verification
Native comment continuation is configured only for regular chat buffers. Keyboard regressions cover repeated Return, splitting, literal custom prefixes, native undo, existing Return maps, spell typeahead, prompt exclusion, non-chat isolation, and unsupported native leaders. Red runs confirmed missing prefixes and unsupported-prefix setup failure before implementation. Spec review approved the clarified native-comment scope; lessons and atlas updated. Verification: mapped ui/keybindings suite and lint (0 warnings/errors); final close review follows.

### 2026-09-28 — boundary review revisions
BR-1 identified native leader precedence: private prefixes must precede existing shorter single-line, nested, block, and user-defined comment leaders so continuation retains private classification (ARCH-PURPOSE). Add keyboard coverage for all those overlap classes. BR-2 adds the user-facing README instructions. BR-3 expands repeated-empty-line, split, and no-space cases across default/custom prefixes, and verifies prompt Return reaches ChatRespond. The reviewer could not complete the mapped suite in its sandbox; the main-session suite passed with process cleanup and is rerun after these changes.

### 2026-09-28 — boundary review corrections verified
BR-1: red matrix reproduced all six overlapping leader classes; prepending the private leader preserves the complete prefix and existing definitions. BR-2: README explains Return and leaving notes. BR-3: nine prefixes now each exercise repeated/empty Return, split text, and no-space continuation; prompt Return is observed at ChatRespond. `make test-spec SPEC=ui/keybindings` passed with clean process census; `make lint` reports zero warnings/errors; `git diff --check` passes. Re-submit all three findings for boundary review.
