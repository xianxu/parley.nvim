---
id: 000289
status: working
deps: []
github_issue:
created: 2026-09-27
updated: 2026-09-28
estimate_hours:
card_mirror: 'e744defd8e959eb840e7ffd5476fdafc6802da69' # card fields mirrored from issue-cards; edit via sdlc
started: 2026-09-28T10:52:38-07:00
flow: {kind: quick, provenance: inferred, spec: "9f48bafd", done: "3ce9d79f"}
---

# Add tutorial 4: VIM Basics for newcomers

## Problem

The welcome chat teaches newcomers how to enter text and exit Vim, but that is
not enough to comfortably edit and navigate Parley chats. People arriving from
ordinary text editors need familiar actions explained in Vim terms.

## Spec

Add a fourth packaged tutorial, titled **4. VIM Basics**, for people with no Vim
experience. Keep it short, practical, and organized by what the user wants to
do, rather than by Vim terminology or a comprehensive command inventory.

Cover the essentials through small exercises in an editable chat:

- Briefly explain Normal, Insert, and Visual modes, with Escape as the way back
  to Normal mode. Build on welcome.md's existing exit instructions.
- Go back to a previous location and forward again with Ctrl+o / Ctrl+i;
  explain navigation history using a familiar Back/Forward analogy and a real
  Parley navigation example.
- Undo and redo text edits with `u` / Ctrl+r in Normal mode.
- Find text with `/`, move between matches with `n` / `N`, and explain the app's
  smart-case search: lowercase queries ignore case; uppercase makes a query
  case-sensitive. Include a concrete example and how to clear highlighting.
- Cover the other small set of actions someone expects from a stock editor:
  moving around text, selecting, copying/cutting/pasting, and saving. Explain
  the difference between Vim's internal copy buffer and the system clipboard
  only as needed for the packaged app's actual behavior.

State the required mode beside each shortcut. Favor a compact quick reference
and a few useful examples over advanced motions, macros, registers, or extensive
Vim customization. Verify the examples against the actual packaged profile,
including Ctrl+i/Tab handling and clipboard configuration; do not promise key
behavior based solely on generic Vim documentation.

Ship the new chat with the app and expose it through tutorial navigation, the
chat finder, and the existing help catalog. Preserve users' edited tutorial
copies when later launches seed the new file. Reuse the existing tutorial/help
mechanisms (ARCH-DRY); this task adds teaching content, not new editor behavior.

## Done when
- A fresh app profile includes a discoverable fourth chat titled `4. VIM Basics`.
- A newcomer can follow exercises for Back/Forward navigation, undo/redo, and
  smart-case search without prior knowledge of Vim modes.
- Selection, copy/cut/paste, movement, and saving have concise explanations
  tied to familiar editor tasks; key instructions match the packaged app.
- Existing profiles receive the additional tutorial without overwriting edited
  lessons. Navigation and help links resolve to packaged content.
- Startup/help coverage includes the new tutorial, and its keyboard exercises
  have been verified in the local packaged-app tester.

## Plan

- [ ] Write the concise tutorial and connect it to the existing lessons.
- [ ] Include it in starter seeding and help discovery, with regression coverage.
- [ ] Walk through the exercises in `./parley_app` and verify fresh/existing profiles.

## Log

### 2026-09-27

Filed at the user's request. Welcome already covers exiting Vim; this lesson
should make everyday Parley use easier for people coming from stock editors.
The explicitly requested anchors are Ctrl+o/Ctrl+i, u/Ctrl+r, and smart search.

## Revisions

### 2026-09-28 — implementation scope

Use one pure tutorial-name registry for starter seeding, filename recognition,
help discovery and finder diagnostics (ARCH-DRY, ARCH-PURE). Add vim-basics.md
with mode-labelled examples and a practice question. Test upgrading a profile
missing only the fourth lesson while preserving edited copies. Verify keyboard
exercises through the packaged profile; no new mappings or external services.
The existing seed-once lifecycle owns the one additional user-editable file
(ARCH-FUNERAL); no new state machine, background job or growing cache is added.
