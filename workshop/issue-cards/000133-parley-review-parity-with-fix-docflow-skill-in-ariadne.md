---
id: '000133'
status: done
created: 2026-06-17
updated: 2026-06-18
estimate_hours: 8.4
actual_hours: 9.10
---

# parley review parity with fix/docflow skill in ariadne

## Problem

Parley's document review is a single marker-processor (`<C-g>ve` →
`skills/review`): it edits a doc from `🤖` *ready* markers in one batch, and
refuses entirely when there are no markers. It has no review **modes**, no
**free-form** instruction, no faster **ping-pong** trigger, and no **durable
record** of what each round changed or why (the per-edit `explain` lands only in
ephemeral gutter diagnostics and evaporates on the next run).

The goal is to bring review to **coding-agent parity** so parley can drive a
document review **independently** — borrowing the editing discipline of
ariadne's `fix` skill (reading frontier, attributed per-round history) but *not*
its git-branch machinery.

This **deliberately revises** the earlier "parley = marking layer; Claude Code
(`xx-fix`) resolves" split: review/resolution UX is back in scope for parley.
The one narrow exception is fact-check mode, which still hands resolution off to
the main agent.
