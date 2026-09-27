---
id: 000273
status: open
created: 2026-09-19
updated: 2026-09-19
estimate_hours:
github_issue:
---

# Generated topic and filename slug drift apart

## Problem

Operator, 2026-09-19: *"topic generation sometimes fail"*, pointing at
`parli/workshop/parley/2026-09-19.23-09-28.629.md`.

Generation is mostly not what fails — **persistence is**. The topic header and
the filename slug are supposed to be two views of one fact, and they come apart
in both directions. Measured over the two live chat roots:

| class | what is on disk | count |
|---|---|---|
| **A. topic, no slug** | `topic: <real topic>`, filename is bare `<timestamp>.md` | 7 in `brain/workshop/parley`, 2 in `parli/workshop/parley` |
| **B. slug, no topic** | filename carries the slug, header still says `topic: ?` | 1 (`parli`, the reported file) |
| (not a defect) | `topic: ?` and no slug on a chat with **no answer yet** | 3 |

The reported file is class B — and it is the more alarming direction, because
the slug can only have come from a topic that **was** generated and **was** in
the header at rename time:

```
parli/workshop/parley/2026-09-19.23-09-28.629_government-driven-ai-safety-review.md
---
topic: ?
file: 2026-09-19.23-09-28.629_government-driven-ai-safety-review.md
```

The `file:` header was updated too, so `_slug_rename_chat` ran to completion —
and the header it left behind says `?`. Class A files are the inverse: the topic
reached disk, the name never changed.

### Where it comes from

**One edge arms the rename, and it is the wrong one.** The only caller of
`M._slug_rename_chat` is a `BufWritePost` autocmd (`lua/parley/init.lua:1145`).
The function then refuses on two conditions and is **never retried**
(`init.lua:3170-3195`):

```lua
if M.tasker and M.tasker.is_busy(buf, true) then return nil, "busy" end
...
if not headers or not headers.topic or headers.topic == "" or headers.topic == "?" then
    return nil, "no topic"
end
```

The topic arrives on its own leg, after the answer: `start_topic` runs at
finalize and its terminal callback only calls
`buffer_lifecycle.finalize_mutated_api_leg(buf, true)`
(`chat_respond.lua:1591-1613`), which **converges structure and does not save**.
Persistence is left to the debounced autosave — `TextChanged`/`InsertLeave`,
1000 ms (`init.lua:1775-1800`). So the sequence that produces class A is
ordinary: the save that fires while the answer is streaming sees `topic: ?` (→
"no topic") or an unresolved tasker record (→ "busy"), the topic lands after it,
and whatever writes the buffer later either does not re-arm the rename or hits
`is_busy` again. Nothing ever comes back to finish the job.

**Class B has a second, independent defect to check first.** In
`_slug_rename_chat` the disk rename happens *before* the buffer is saved, and
`sync_moved_chat_buffers` then writes every buffer still pointing at the old
path (`init.lua:3152-3166`):

```lua
local ok = vim.fn.rename(file_path, new_path)   -- disk moves first
sync_moved_chat_buffers(file_path, new_path)    -- `silent! write` per modified buffer,
                                                -- THEN nvim_buf_set_name(new_path)
```

That inner `silent! write` runs while `M._in_slug_rename` is still **false** —
the guard is set later, around the final `write!` only — so it fires
`BufWritePost` and re-enters `_slug_rename_chat` recursively. It also writes to
a path that no longer exists, recreating the old file. And it writes *every*
matching buffer, including a stale one that was loaded before the topic was
written; such a buffer holds `topic: ?` and, once renamed onto the new path,
will happily write that `?` over the good file on its next autosave. Either the
recursion or the stale duplicate is enough to produce class B; which one it was
has not been established.

Both directions leave the artifact self-contradicting, and the slug is what the
chat finder and every `🌿` reference show a human, so this is visible in normal
use.
