---
id: 000393
status: open
deps: []
github_issue:
created: 2026-10-18
updated: 2026-10-18
estimate_hours:
collaboration-mode: collaboration
card_mirror: '8d6c8efc0c929db9a6e09cef84c0caf56d728668' # card fields mirrored from issue-cards; edit via sdlc
---

# spelling: the Blink corrections menu is off by default (underlines stay on)

## Problem

The operator does not use the spelling suggestion menu (chat_spell.blink, on by default: after a 180 ms pause on a misspelled word, Blink opens a corrections menu) and asked (2026-10-18) to disable it by default in parley. Underlines (chat_spell.enable) stay on.

## Spec

Change the default of `chat_spell.blink` from true to false. `enable` (underlines) stays true; `typeahead` stays false. Users who want the menu set `chat_spell = { blink = true }`. Update the config comment, atlas/ui/spell_typeahead.md (default and how to opt in), README if it mentions the default, and the tests that assume the default.

## Done when

- A fresh setup with no chat_spell options shows underlines and opens no corrections menu (test).
- Setting blink = true restores today's menu behavior (existing tests, now opt-in).

## Plan

- [ ]

## Log

### 2026-10-18
