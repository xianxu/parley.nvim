---
id: 000122
status: open
deps: []
created: 2026-05-06
updated: 2026-05-06
---

# chat_finder: sort by real last-modified time

The chat finder list order is currently surprising — chats whose filename creation timestamp is older than other chats sometimes appear "newer" in the list, with their bracket date `[YYYY-MM-DD]` not matching the filename's leading timestamp.

What I want is the **real last-modified time** of the conversation — the moment a question or response was last appended, not creation time, and not noise from sync or the editor opening the file.

## Done when

- The chat finder's bracket date and sort order reflect when the chat's *content* was actually last appended-to (last user question or last agent response).
- Sort is stable across iCloud syncs between devices: opening or syncing a chat from another device does not bubble it to the top of the list.
- Opening a chat in Neovim, scrolling around, and closing without typing a new turn does not change its sort position.

## Spec

(empty — brainstorm before deciding direction)

## Plan

- [ ] (empty — pending spec)

## Log

### 2026-05-06

Spun off from #119 testing. While verifying the recall feature on chat_finder, the visible list order looked wrong relative to filename timestamps. Two threads emerged:

**Thread 1 — chat_finder regex doesn't parse the real filename format.**

`lua/parley/chat_finder.lua:427` tries to extract the creation timestamp from filenames with this pattern:

```lua
filename:match("^(%d%d%d%d)%-(%d%d)%-(%d%d)%-(%d%d)%-(%d%d)%-(%d%d)")
```

It expects `YYYY-MM-DD-HH-MM-SS` — all dashes. The actual chat filenames are `YYYY-MM-DD.HH-MM-SS.mmm.md` (e.g. `2026-03-25.17-29-47.860.md`) — there's a `.` between the date and the time. The match silently fails, and the code falls through to `stat.mtime.sec`.

So today's sort is **mtime-based, not filename-creation-based**, even though the surrounding code reads as if it intended creation-time parsing with mtime as a fallback.

**Thread 2 — mtime is noisy in this setup.**

The chat dir lives in iCloud Drive (`~/Library/Mobile Documents/com~apple~CloudDocs/parley`). iCloud updates local mtime when a file syncs in from another device, so a chat created on device A and synced to device B has B's local-mtime = sync-time on B, completely unrelated to user activity. That alone reproduces the "filename says 2026-03-24, bracket date says 2026-03-25" pattern in the screenshots.

I also briefly worried that parley's `prep_md` auto-save (TextChanged/InsertLeave debounced `silent! write`, `lua/parley/init.lua:1262-1290`) might fire on bare open via the highlighter's branch-ref re-render. Empirical test rules this out for the headless case:

```
before:  mtime = Jan 1 2025  (touched manually)
nvim --headless -u <minimal probe init> <chat file> +"sleep 4" +"qa!"
after:   mtime = Jan 1 2025  (UNCHANGED)
```

Interactive open could still differ — that test would be needed if we want to rule out parley-side mtime bumps end-to-end. But the iCloud explanation alone covers the symptom.

**What "real last-modified" should mean.**

Not creation time (filename) — the user has explicitly ruled that out. The intent is "when was the conversation last extended" — the timestamp of the most recent user question or agent response in the file. That's content-derived, not filesystem-derived, so it's immune to:
- iCloud sync touching mtime
- Editors writing the file without semantic change
- `touch` / git checkout / backups bumping fs metadata

### Approaches to brainstorm

1. **Parse from buffer content.** On scan, derive last-modified by looking for the latest timestamp embedded in the chat — either the last `💬:` / agent header, or a line that explicitly carries a timestamp. Cost: re-reads file on every scan; would want to keep the existing mtime-based scan cache and invalidate by mtime + size.
2. **Frontmatter `last_modified` field.** parley updates `last_modified: <ISO>` in the file's YAML frontmatter on every successful chat-respond cycle. Scan reads it cheaply (top of file). Survives iCloud sync because the value is in-content. Adds a small write surface in chat_respond.
3. **Sidecar index.** A JSON/lua index keyed by chat path, recording last-modified per chat. Updated on chat-respond. Lives outside iCloud Drive (e.g. under `stdpath('data')`). Pure cost: an extra file to manage, plus drift risk if the user edits chats outside parley.
4. **Use the existing filename timestamp as creation-time tier-break, mtime as activity-time, but with mtime sanitized.** Doesn't cleanly solve iCloud, so probably ruled out.

(2) is probably the right shape — explicit, in-content, cheap to read, naturally device-portable via the same iCloud sync. Worth confirming before committing.

### Side-fix candidate

Even if we go the frontmatter route, the regex at `chat_finder.lua:427` is still a latent bug — it advertises filename-time parsing but never actually succeeds, so the fallback path runs unconditionally. Worth fixing as a side-quest or as part of this issue: change the separator class to `[%-.]` or rewrite to match the real `YYYY-MM-DD.HH-MM-SS` shape.
