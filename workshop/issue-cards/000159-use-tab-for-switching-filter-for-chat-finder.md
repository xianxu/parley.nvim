---
id: '000159'
status: done
started: 2026-07-01T10:07:50-07:00
created: 2026-07-01
updated: 2026-07-01
estimate_hours: 0.63
actual_hours: 0.23
---

# use TAB for switching filter for chat finder

## Problem

The chat finder's "filter" is a **recency** cycle (time windows → "All"), driven
bidirectionally: `<C-a>` = `next_recency` (move left), `<C-s>` = `previous_recency`
(move right), both via `_cycle_chat_finder_recency`. The user wants `<Tab>` to
cycle the filter like `<C-a>` — the chat-finder analog of #158's IssueFinder
`<Tab>`. Because this finder is **bidirectional**, the natural completion is
`<Tab>` = forward (like `<C-a>`) **and** `<S-Tab>` = back (like `<C-s>`) — the
idiomatic Tab/Shift-Tab pair — keeping `<C-a>`/`<C-s>` for back-compat.
