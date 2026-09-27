---
id: '000266'
status: done
started: 2026-09-17T11:06:53-07:00
created: 2026-09-17
updated: 2026-09-18
estimate_hours: 13.17
actual_hours: 19.79
---

# Serialize transcript mutation: queue generations, insert tool call/result pairs in order

## Problem

Transcript mutation is concurrent today, and the resulting edit history is not
something a user can reason about. Up to four generations may write one document
(`document/state.lua:190`, `if count(s.generations)>=4 then return reject('generation limit')`),
and within a single tool round every call block plus every `(Tool result pending)`
placeholder is appended in one write, after which results fill their reserved
slots **in completion order** (`response_tools.lua:137-170`):

```lua
for i in ipairs(calls)do
    append('

')
    local first=length
    append('(Tool result pending)')
    slots[i]={first=first,last=length}
end
```

So the buffer's undo chain carries entries from unrelated exchanges interleaved,
and holes that fill out of document order. Undo rewinds someone else's answer;
the user cannot predict what a keystroke restores. That unreasonable history is
the reason a bespoke restore sidecar existed beside the file at all — see
[[transcript-is-the-whole-truth]] and parley#261. Fixing the history is what lets
the sidecar be deleted rather than replaced.

This issue knowingly **reverses a #254 decision**. `atlas/chat/ownership.md:8`
currently promises "Disjoint generations may write separate answers while the
human edits the next question." That was a reasonable throughput choice; it is
being traded for a history a person can hold in their head. The atlas must be
rewritten, not merely appended to.
