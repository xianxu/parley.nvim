---
id: '000128'
status: done
created: 2026-06-11
updated: 2026-06-17
estimate_hours: 40
actual_hours: 4.9
---

# Skill system redesign: declarative modules over one engine

## Problem

Parley has **two execution engines that duplicate concerns**: the chat tool
loop (`chat_respond`/`dispatcher` — multi-turn, recursive, readonly-capable) and
`skill_runner.run` (single-shot, `tool_choice = review_edit` forced-write). They
each re-implement agent resolution, payload prep, tool decode, and result
handling.

The v1 skill system (#106) is hardwired to "force a structured edit on the
current buffer." That is the wrong shape for the direction parley is taking: a
**readonly research/exploration harness** whose value is a better *chat*
experience (tree-of-chats, markdown-as-state), and whose agent substrate should
be *composed per turn* (persona + skills) rather than run through a fixed
forced-write pipeline. v1 was built in a rush and is effectively unused — low
confidence in the design. Redo it, salvaging the good pure pieces.

Settled in the brain design conversation 2026-06-11 (product behavior agreed;
implementation pending a plan doc). Siblings: #116 (the discovery registry this
consumes) and #129 (the permission model layered on the manifest's tool grants).
