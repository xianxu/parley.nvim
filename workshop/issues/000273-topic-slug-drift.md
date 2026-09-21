---
id: 000273
status: open
deps: []
github_issue:
created: 2026-09-19
updated: 2026-09-19
estimate_hours:
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

## Spec

**The topic landing — not a write — is what should drive the rename.** A fact
that has been generated should reach both of its two representations, or
neither.

- Drive `_slug_rename_chat` from the topic leg's terminal callback, after the
  buffer holding the new topic has been saved, rather than hoping a debounced
  autosave lands on the far side of both the topic write and the tasker record's
  resolution. Keep the `BufWritePost` edge as a backstop for hand-edited topics.
- **A refusal must be retried, not dropped.** `"busy"` in particular is a
  statement about *now*; the rename is still owed once the generation resolves.
  Today it is returned to a callback that discards it.
- **Fix the write-then-rename ordering in `_slug_rename_chat`.** The buffer that
  carries the topic should be saved *before* the file is moved, so no
  intermediate state depends on which buffer writes next. Set `_in_slug_rename`
  around the whole critical section, including `sync_moved_chat_buffers`, so the
  inner write cannot re-enter through `BufWritePost`.
- **Decide what a second buffer on the same chat may do.** Writing every buffer
  that names the old path is how a stale copy overwrites a fresh topic. Either
  refuse to write buffers other than the one being renamed, or reload them from
  disk after the move.
- **Say so when the topic is genuinely lost.** A terminal failure inside
  `generate_topic` (`"empty"`, `"topic too long"`, `"abort"`, a provider failure)
  currently leaves `topic: ?` with no trace of an attempt. The three chats with
  no answer are correctly `?`; a chat whose topic call failed should be
  distinguishable from one that was never asked.
- Repairing the existing 10 drifted files is a separate, mechanical pass —
  worth a one-shot command (`slugify(topic)` → rename for class A; re-derive the
  topic from the slug, or re-run generation, for class B) rather than a
  hand-edit.

## Done when

- A chat whose topic generation succeeds always ends with a slugged filename
  **and** the same topic in its header; a test drives a generation to completion
  through the fake provider and asserts both.
- A rename refused as `"busy"` is retried and lands once the generation
  resolves; a test pins that (no silent drop).
- `sync_moved_chat_buffers` cannot re-enter `_slug_rename_chat` through
  `BufWritePost`, and a second buffer on the same chat cannot write a stale
  `topic: ?` over a renamed file. A test covers the two-buffer case.
- A failed topic call is visible to the operator rather than indistinguishable
  from "never asked".
- The 10 drifted files in `brain/workshop/parley` and `parli/workshop/parley`
  are reconciled.

## Plan

- [ ]

## Log

### 2026-09-19

Filed from an operator report naming `2026-09-19.23-09-28.629.md` (its
pre-rename name; on disk it is now
`2026-09-19.23-09-28.629_government-driven-ai-safety-review.md`, which is itself
the symptom — the rename happened, the header did not follow).

Survey that produced the table: for every file in both chat roots, compare the
`topic:` header against the slug parsed out of the filename. Classes A and B are
the two disagreements; the third row is chats with a question and no answer,
where `topic: ?` is correct and no topic was ever requested.

Not established, and worth ten minutes before designing the fix: whether class B
came from the un-guarded inner write re-entering the rename, or from a stale
second buffer writing `topic: ?` over the renamed file. Both are live paths in
the current code; the fix for one does not cover the other.

### 2026-09-20 — operator re-report: "slug generation seems inconsistent"

Reported again, framed from the filename side: *"the chat file slug generation
seems inconsistent. For example `../parli/workshop/parley/`, some of the file name
slugs are not generated."* That is class A above — same defect, seen from
`ls` instead of from the header. No new ticket; this is the same fix.

Re-survey of `parli/workshop/parley/`, one day on: 13 chats, 9 slugged.

| file | answers | topic | slug | class |
|---|---|---|---|---|
| `2026-09-19.23-08-17.193` | 0 | `?` | none | correct — never asked |
| `2026-09-19.23-09-28.629_government-driven-ai-safety-review` | 1 | `?` | yes | **B** (the original report) |
| `2026-09-19.23-17-24.715` | 1 | `Greeting, awaiting direction` | none | **A** |
| `2026-09-19.23-17-53.792` | 1 | `Debate prep greeting` | none | **A** |
| `2026-09-20.08-37-26.511` | 1 | `Prop 40 debate prep` | none | **A** (new since the first survey) |

Class A grew from 2 to 3 in `parli` in a day and class B did not change, so the
defect is live rather than historical.

**A pattern worth using:** every class-A chat in `parli` is among the *newest*
in the directory — the three most recent real chats. The nine slugged files are
all earlier. Two of the three are tiny (18 and 22 lines, one exchange), so the
topic leg is quick there, which fits the ordering in the Problem section: the
topic lands after the last save that would have armed the rename, and nothing
re-arms it. It does not by itself distinguish that from "the chat's buffer is
still open and unsaved since the topic landed" — the discriminating check is
whether the rename fires when one of these three is next saved by hand
(`:w` on an unslugged chat with a real topic should slug it; if it does, the
defect is purely a missing trigger, and the Spec's "drive the rename from the
topic leg" is the whole fix for class A).

Not yet checked: whether these chats were opened in an Neovim that has parli's
chat root configured, since `not_chat` gates the `BufWritePost` autocmd. The
nine slugged siblings in the same directory make a config gap unlikely, but a
per-window `not_chat` result is a one-line confirmation.
