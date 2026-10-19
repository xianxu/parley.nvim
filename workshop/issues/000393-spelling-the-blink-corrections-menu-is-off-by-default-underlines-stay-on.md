---
id: 000393
status: working
deps: []
github_issue:
created: 2026-10-18
updated: 2026-10-18
estimate_hours:
collaboration-mode: collaboration
card_mirror: '4588d04c799b508f32d3a61591610ab292528ee3' # card fields mirrored from issue-cards; edit via sdlc
started: 2026-10-18T21:11:16-07:00
claimant:
    operator: Xian Xu
    machine: 4716879978a7b90f6b583da1716fd0e9
    machine_name: Xian’s MacBook Pro
    workspace: parley.nvim:1
    worktree: /Users/xianxu/workspace/worktree/parley.nvim-slot1/parley.nvim
    repository: github.com/xianxu/parley.nvim
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

- [ ] Change only the shared Blink default/comment; document the default and explicit opt-in in the existing atlas (ARCH-DRY).
- [ ] Red/green bare setup through prep_chat with a ready stateful Blink fake: underlines stay on, no menu; retain opt-in menu behavior coverage. Run mapped tests, architecture guards and recorded suite before landing.

## Log

### 2026-10-18

## Revisions

### 2026-10-18 — correct documentation path

The existing spelling atlas is atlas/chat/spell_typeahead.md, not atlas/ui/.
Update that source; README has no spelling-default claim. No new mechanism,
state, actions, resources or growth drivers: only the existing setup default
changes; blink=true opts back into the existing controller and ownership rules.
