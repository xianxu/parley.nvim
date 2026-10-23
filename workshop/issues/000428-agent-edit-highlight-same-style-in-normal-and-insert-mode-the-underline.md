---
id: 000428
status: open
deps: []
github_issue:
created: 2026-10-23
updated: 2026-10-23
estimate_hours:
collaboration-mode: collaboration
card_mirror: '613f2ea82e141c96b5cdcea3a13490f65ddb6a47' # card fields mirrored from issue-cards; edit via sdlc
---

# Agent-edit highlight: same style in normal and insert mode (the underline disappears in insert)

## Problem

## Spec

**The agent-edit highlight changes style between normal and insert mode (operator, 10-23).** In a collaborative
document, the highlight of the agent's last edit shows with an underline over the whole edited text in normal mode;
on entering insert mode the underline disappears (only link-like references such as `pair#844` stay underlined).
Screenshots: ops `assets/session/2026-10-23.12-29-46.680.png` (normal) and `2026-10-23.12-30-25.815.jpg` (insert).
The operator wants **one consistent style** unless there's a reason to differ.

First find why it differs (an intentional insert-mode style, a highlight group linked to something mode-dependent
such as CursorLine or Visual, a conceal or extmark priority interaction, or the colorscheme), and report the cause
before changing anything. Then make the edit highlight render the same in every mode (the reference underlines are
separate and stay).

## Done when

- The cause is stated in the Log.
- The agent-edit highlight's attributes are identical in normal and insert mode (test reading the effective
  highlight at a position in both modes).

## Plan

- [ ]

## Log

### 2026-10-23
