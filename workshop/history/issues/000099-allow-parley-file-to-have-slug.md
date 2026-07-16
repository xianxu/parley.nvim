---
id: 000099
status: done
deps: []
created: 2026-04-11
updated: 2026-04-11
---

# allow parley file to have slug

right now parley chat files are named by time they are created. this makes creation of chat fast. however, it also makes finding a chat hard in shell, outside chat finder. one way to address this is to put topic as slug at end of the file name. 

One issue is that when parley chat is created, topic is not set yet. So this updated file name scheme, need to work in two ways, both without any slug, or with slug inserted. think this way, the slug is only useful for user of shell to know what a file is about before opening the file. 

And due to the asynchronicity of chat creation, likely this needs to be designed as file renaming operation. i.e. when parley has a subject, an optional step is to rename it when subject is available. if subject later change, we will change the file name as well. 

Going down this path, then we need to update other parts of parley dealing with chat file, as the slug might potentially be outdated. so each file read of file.md, previously we just check file.md, but this need to be changed to try to find file*.md for parley chat files.

## Done when

- Chat files auto-rename to include slug when topic is set/changed
- `ls` on chat dir shows recognizable filenames like `2026-04-11.16-38-42.729_debugging-auth-flow.md`
- Existing branch links and file references resolve correctly even if slug changed
- Stale references self-heal on access (read repair)

## Spec

### Filename Format
- Without slug: `YYYY-MM-DD.HH-MM-SS.mmm.md` (unchanged)
- With slug: `YYYY-MM-DD.HH-MM-SS.mmm_slug-words-here.md`
- Separator is `_` (underscore) — unambiguous since neither timestamp nor slug contains underscores
- Timestamp is the stable identity; slug is cosmetic

### Slug Generation
- Source: `topic:` header in YAML front matter
- Algorithm: strip stop words → kebab-case → cap at 5 words or 40 chars (whichever shorter, break at word boundary)
- Stop words: `the`, `a`, `an`, `in`, `of`, `for`, `to`, `and`, `is`, `with`, `on`, `at`, `by`
- Topic `?` or empty → no slug, keep timestamp-only name
- Non-ASCII characters: strip non-ASCII bytes, collapse resulting runs of hyphens
- `slugify()` must never produce underscores — replace any `_` in topic with `-`

### Rename Trigger
- `BufWritePost` autocmd on parley chat files
- Compare current `topic:` to cached topic from last rename
- If changed and not `?`, generate slug → rename file
- Rename updates: filesystem (`vim.fn.rename`), buffer name (`nvim_buf_set_name`), `file:` header in front matter
- If topic changes again, re-rename (old slug replaced)
- Defer rename if `_parley.tasker.is_busy(buf)` (streaming in progress) — retries naturally on next `BufWritePost`
- Note: `new_chat()` has `gsub("_", "\\_")` for markdown escaping — not a conflict since new chats start without slugs, and rename writes raw filename directly to the `file:` header

### Fuzzy Resolution + Read Repair
- `resolve_chat_path()` tries exact path first (existing behavior, no change)
- On miss: extract timestamp prefix from filename, glob `timestamp*.md` in candidate directories
- Single match → use it, **write corrected reference back** to referring file (read repair)
- Multiple matches → prefer the one with a slug (most recent rename)
- Read repair deferred if buffer is mid-stream (LLM response in progress)

### New Module: `lua/parley/chat_slug.lua`
- `slugify(topic)` — pure function: topic string → slug string or nil
- `make_filename(timestamp, slug)` — assembles filename
- `parse_filename(filename)` — splits on first `_` → `{timestamp, slug_or_nil}`
- `glob_pattern(timestamp)` — returns glob for fuzzy resolution

### Integration Points
1. `init.lua` — new `BufWritePost` handler for slug rename
2. `init.lua` — `resolve_chat_path()` enhanced with fuzzy fallback + read repair
3. `init.lua` — `file:` header updated on rename
4. `exporter.lua` — refactor its local `resolve_chat_path` to use the shared one from `init.lua` (so it gets fuzzy resolution for free)
5. No changes to `chat_finder.lua` (already scans dirs and reads topics via `*` glob)

### Edge Cases
- File open in multiple buffers → iterate `nvim_list_bufs()`, compare `nvim_buf_get_name(b)` to old path, update matches. `nvim_buf_set_name` does not trigger `BufWritePost` (no recursive rename)
- Concurrent rename during LLM streaming → defer via `_parley.tasker.is_busy(buf)` check
- Branch link read repair during streaming → defer write-back
- `new_chat()` unchanged — still creates timestamp-only filenames

## Plan

See detailed plan: `workshop/plans/000099-allow-parley-file-to-have-slug-plan.md`

- [x] Task 1: Create `chat_slug.lua` — pure slug functions (slugify, parse_filename, make_filename, glob_pattern)
- [x] Task 2: Add BufWritePost rename trigger in init.lua
- [x] Task 3: Fuzzy resolution in `resolve_chat_path()`
- [x] Task 4: Read repair for stale references
- [x] Task 5: Refactor exporter to use shared `resolve_chat_path`
- [x] Task 6: Verify slugged filenames pass existing validation
- [x] Task 7: Update issue and atlas docs

## Log

### 2026-04-11
- Brainstormed design: auto-slug from topic header, fuzzy resolution + read repair, `_` separator
- Implemented all tasks. New files: `lua/parley/chat_slug.lua`, `tests/unit/chat_slug_spec.lua`, `tests/unit/chat_slug_resolve_spec.lua`. Modified: `lua/parley/init.lua` (rename + fuzzy resolve + read repair + autocmd), `lua/parley/exporter.lua` (shared resolve), `atlas/chat/lifecycle.md`
- All tests pass (unit + integration)

