# #231 Attach images to questions — Implementation Plan

> **For agentic workers:** Consult AGENTS.md Section 3 (Subagent Strategy) to determine the appropriate execution approach: use superpowers-subagent-driven-development (if subagents are suitable per AGENTS.md) or superpowers-executing-plans to implement this plan. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** `<M-v>` in a chat buffer saves the clipboard image under
`<chat-dir>/assets/<chat-timestamp>/` and inserts `![](assets/<ts>/<file>.png)`;
the parser reads that line in a question as an attachment; both message
builders send it in each wire's own image shape under one retention rule and
one request-wide budget; a summarized exchange drops it and says so; every
chat move and delete carries or removes the folder; tree export copies it.

**Architecture:** One new pure module, `lua/parley/assets.lua`, owns the
sidecar layout, the attachment grammar, the content blocks, the request
budget, the log elision and the single writer behind an injectable, checked IO
table — it is the writer #239 will also call. `lua/parley/clipboard_image.lua`
owns platform recipes as data and one classify rule; `vim.system` is its seam.
`lua/parley/paste_image.lua` is the thin async orchestration behind the key.
The retention decision the memory window makes is extracted into one pure
predicate that both message builders call. The parser and the three provider
shapes each gain one branch. A process fixture models `osascript` through the
same config seam a user's own tool would use.

**Tech Stack:** Lua on Neovim 0.10+ (`vim.system`, `vim.base64`, `vim.uv`),
`osascript` / `wl-paste` / `xclip`, plenary busted, a Python 3 fixture.

---

## Facts this plan rests on (verified 2026-09-12)

- Chat identity is the timestamp prefix: `chat_slug.parse_filename(basename)`
  (`lua/parley/chat_slug.lua:74`) → `ts, slug`, round-trips a bare timestamp.
  `logger.now()` mints the same shape. The slug rename (`init.lua:3085`)
  renames only the `.md`, in place.
- Parser: `parse_chat` builds each exchange's `question = { line_start,
  line_end, content, file_references = {} }` and scans question lines on the
  prefix line and on every continuation line; the loop index is the 1-based
  line number.
- Two message builders. `build_messages` decides retention per exchange
  (current question, or within the last `max_exchanges`, or file references)
  and emits either the question or the placeholder `omit_user_text`; its
  window size comes from the chat header's `max_full_exchanges` or
  `config.chat_memory.max_full_exchanges`. `build_messages_from_model` serves
  tool-loop continuation, walks **every** exchange up to the target and
  applies **no window today** — every exchange's full text is re-sent. The
  buffer is in scope at both call sites. Both feed one dispatch:
  `dispatcher.prepare_payload` translates for the wire and appends tool
  definitions, and `chat_respond` posts the result.
- Internal messages are Anthropic-shaped; `wire.translate_messages` runs
  unconditionally in `prepare_payload`. `wire_openai.translate_messages`
  drops unknown user blocks with a warning; googleai has no wire and its
  `format_payload` maps `content` to `parts = {{ text }}` and merges
  same-role neighbours by `parts[1].text`. Anthropic's `format_payload` hoists
  `system` and passes table content through; openai's leaves messages
  untouched. cliproxy routes a model to the anthropic or the openai wire and
  its payload builders pass the messages through unchanged. Ollama resolves to
  `wire_openai`.
- Provider image shapes, read from current docs today (re-read the per-image
  cap before the M1 send check):
  - Anthropic: `{ type="image", source={ type="base64", media_type, data } }`,
    images before text preferred; JPEG/PNG/GIF/WebP; **10 MB per image, 100
    per request, 32 MB per request**.
  - OpenAI Chat Completions: `{ type="image_url", image_url={ url="data:<mime>;base64,…", detail="auto" } }`.
  - Gemini generateContent: `{ inlineData={ mimeType, data } }`, camelCase;
    **20 MB total inline request**.
- Three log sinks see outgoing messages: the "messages to send" debug line
  in `chat_respond` (written to `parley.log` at every level; startup
  truncation is by line count), and raw mode's `write_exchange_turn` and
  `write_raw_turn` (the latter with the final payload).
- macOS clipboard, measured: no `pngpaste`; `osascript` present; `clipboard
  info` takes 60–70 ms; the write-to-file recipe against a text clipboard
  exits **1**, prints `execution error: Can’t make some data into the expected
  type. (-2700)`, and leaves a **0-byte file**. wl-paste and xclip exit 1 for
  "no such type".
- Neovim 0.11.7; `vim.base64` exists; `vim.system` `on_exit` runs in a libuv
  callback (`vim.fn` refused there); a `timeout` yields code 124.
  `register_buffer` maps a plain callback in every listed mode, including
  `i`, without `stopinsert`; the registry's `entries` is a table. Resolution replaces: the shipped key lives in `config.lua`
  (`chat_shortcut_*`). `M.setup` replaces nested config tables wholesale.
  `<M-v>` is unused.
- Chat files move through two functions in `init.lua` — `move_chat` (single
  file, no production caller) and `move_chat_tree` (the `:ParleyChatMove`
  path) — and are deleted through five: `delete_chat_tree`, `cmd.ChatDelete`,
  the markdown `md_delete_file` key (all `init.lua`), and the finder's
  `handle_delete_response` and `handle_delete_tree_response`
  (`chat_finder.lua`), each calling `helpers.delete_file`. Not chat deletions:
  the dispatcher's query-cache removal, the issue and note finders, and the
  legacy `last.md` state-file removal. The finder's handlers end in
  `_parley._reopen_chat_finder`, which defers a real picker;
  `tests/unit/chat_finder_logic_spec.lua` shows how to stub it and
  `helpers.delete_file`.
- Export (`exporter.lua`, `export_tree`) exports the current buffer's tree
  one file per entry; its integration spec creates front-matter chat files,
  `edit`s one, runs `M.cmd.ExportHTML()`/`ExportMarkdown()`, and `bdelete!`s;
  the exported name is `<YYYY-MM-DD>-<slug>.<ext>`. `simple_markdown_to_html`
  runs every inline rule over the whole string, so an early `<img>` is mangled
  by the italic rule (verified); its `XBRANCHX<n>XBRANCHX` placeholders,
  restored after the last rule, are the mechanism that survives it.
- Buffer writes go through `buffer_edit.lua` (arch guard); its
  `make_handle`/`handle_line`/`handle_invalidate` give an extmark-anchored
  line, and `handle_invalidate` is safe after the buffer is gone.
- Guards: `tests/arch/single_source_sweeps_spec.lua` needs a Core-concepts
  row for every `M.<fn>` / `M.<x> = <non-literal>` this branch adds, needs
  every backticked bare name in any `| ` table row to exist in the tree (so
  rows for names a later milestone creates are added by that milestone), and
  needs every traceability path to exist and every added spec to be routed;
  `untrusted_path_spec` forbids `vim.fn.expand/glob` on non-literal input. `$PARLEY_TEST_MODE` reaches child nvims, `g:` variables do not.
  Harness `$TMPDIR` is a symlink — compare with `vim.fn.resolve`.
  `chat_move_spec`'s `create_chat` makes a `nofile` buffer (`:write` raises).
  `parse_chat_spec` has `std_header`; `build_messages_spec` has
  `stub_helpers`/`stub_logger`, `agent()`, `parsed_chat()`, `exchange(q, a)`
  and sets `max_full_exchanges = 2`.

## Design decisions

1. **The transcript is the index; the folder holds only bytes.** Every asset
   is referenced from a transcript line; nothing reads the folder to discover
   content. Keyed by the chat's timestamp, never its slug (operator,
   2026-09-12: slugs are for humans, who reach assets through the transcript).
   Folder `assets/`, not `images/`: #239 and later binary kinds share it — one
   folder, one rule, one writer (`ARCH-DRY`).
2. **Ordinary markdown, relative to the chat file**: `![](assets/<ts>/<file>)`.
   `:MarkdownPreview` renders it unchanged; the link text also goes to the
   model so a follow-up can name the file.
3. **One writer.** `assets.save` is the only code that creates the folder,
   names a file and forms a link; the clipboard flow, #239, both movers, all
   five deleters and export go through `assets`.
4. **The attachment grammar is a parse at the boundary** (`ARCH-SECURE`): a
   line that is exactly an image link to `assets/<timestamp>/<name>` with
   `[A-Za-z0-9._-]` characters and an accepted image extension. Everything
   else is prose, never read.
5. **One retention rule for both builders** (PQ-1, `ARCH-DRY`,
   `ARCH-PURPOSE`). The predicate `build_messages` applies at `:779-798` is
   extracted as a pure function and the continuation builder applies it too —
   for attachments only, since re-sending old text there is pre-existing
   behaviour this issue does not change. An exchange outside the window sends
   no image bytes and the placeholder sentence says an image was there.
   Attachments do not pin an exchange (file references do).
6. **One request rule, enforced on the encoded payload, deterministic**
   (PQ-2, `ARCH-CONSTRAINTS`). Per image: 10 MB raw (Anthropic's cap). Per
   request: `MAX_REQUEST_BYTES` = 20 MB — Gemini's inline total, the
   strictest — measured as the length of the **final JSON-encoded payload**
   `prepare_payload` produces, after wire translation and tool definitions.
   Two layers, one rule: (a) both builders **plan** with `plan_budget`, which
   charges the retained text bytes, every note it will emit, and for each
   included image its base64 size plus a fixed per-block JSON overhead
   (`BLOCK_OVERHEAD`, 256 bytes, above any wire's envelope), newest exchanges
   first, so the built request fits with margin; (b) `chat_respond` then
   measures `#vim.json.encode(payload)` and, when it exceeds the limit and the
   payload carries an image, **refuses the send** with a message naming the
   size and the limit — never a silent over-limit request. A request with no
   image is not this issue's to govern and is unchanged. The refusal is
   deterministic and testable against the actual encoded payload; the planner
   exists so the refusal is not reached in practice. Text alone over the
   budget → no images, every attachment noted, and the same measured refusal
   applies only if an image is present (it cannot be, so the text request goes
   as today). Pinned exchanges count like any other.7. **Reads are bounded** (PQ-2, `ARCH-SECURE`): a persisted file is stat'ed
   first and read with `f:read(MAX_BYTES + 1)`; an oversized or unreadable
   file is a note, never a block.
8. **IO reports what happened** (PQ-3, `ARCH-ORDER`, `ARCH-FUNERAL`): every
   IO function in `assets` returns `ok, err` (or `n, errs`), checks `write`
   and `close`, removes a partial file it could not finish, and never counts
   an attempted operation as done. Callers relay: the paste says nothing was
   pasted, a mover reports a stranded folder after finishing what it can, a
   deleter reports a folder it could not remove, export reports a copy that
   failed. Nothing claims durable success on a failed call.
9. **Images lead, text follows** in the internal blocks (Anthropic guidance,
   same order on every wire). **Missing or oversized files degrade visibly.**
10. **googleai's parts mapping becomes block-aware; no new wire.** Text-only
    payloads stay byte-identical (pinned).
11. **Clipboard recipes are data; the spawn is the seam** (`ARCH-MOCK`).
    `config.assets.clipboard_cmd` (an argv list with `{out}`) overrides the
    platform recipe through the same contract the fixture speaks. One classify
    rule: exit 0 + non-empty file → image; exit 0 + empty, or exit 1 → no
    image; anything else (124 included) → failure with the tool's stderr.
12. **The paste is asynchronous, anchored, never orphans bytes.** The cursor
    line is an extmark before the spawn; on completion the buffer is checked
    **before** saving; the chat path is re-read from the buffer; one paste per
    buffer at a time. The cursor row is read from the current window (the key
    guarantees it shows `buf`); insert mode is not left.
13. **Every mover and every deleter is swept** (`ARCH-PURPOSE`; memory: fix the
    class): both movers carry the folder behind one shared conflict rule; one
    `delete_chat_file` door replaces `helpers.delete_file` at all five
    chat-deletion sites, an arch spec allows exactly one call, and every delete
    prompt names the folder it removes.
14. **Logs never hold the bytes**: `assets.elide_image_data` at all three sinks.
15. **Scope is `parley_buffer`; a non-timestamp markdown file declines** with a
    message (no stable identity to key a folder on).
16. **Milestones.** M1 = capture and send (Tasks 1–8); M2 = the folder follows
    the chat, export, docs, live conformance (Tasks 9–12). Two boundaries.

## Non-goals

- Model-generated images (#239); answer-side links are prose here.
- Resizing or re-encoding; cross-chat asset references; an orphan sweep;
  Anthropic Files API uploads.
- Changing what the continuation builder re-sends as **text** (it applies no
  window today; only attachments are windowed by this issue).
- A `wire_googleai`; Ollama agents (they ride `wire_openai`, whose image parts
  Ollama's native API does not take); Windows clipboard (`clipboard_cmd` is
  the escape hatch); drag-and-drop.
- `![](…)` inside fenced code in the HTML export becomes a live `<img>`
  (every inline rule already reaches code bodies); Jekyll `_posts/` URLs do
  not resolve the copied `assets/` folder (HTML opened from disk does).
- Ancestor-chat context sends an attachment as its link text only.

## Operating envelope (ARCH-CONSTRAINTS)

| Path | Budget | Basis | When exceeded |
|---|---|---|---|
| `<M-v>` → link | tool ≤ 5 s (`vim.system` timeout; osascript measured 60–70 ms); editor never blocks | measured / operator choice | "nothing pasted — exit 124: <tool> timed out"; temp removed; nothing written |
| one image | ≤ `assets.MAX_BYTES` = 10 MB | Anthropic per-image cap | paste refuses; send notes |
| one request | `#vim.json.encode(payload)` ≤ `assets.MAX_REQUEST_BYTES` = 20 MB and ≤ `assets.MAX_REQUEST_IMAGES` = 20 images, over **all** retained exchanges on **both** builders; planned with base64 size + `BLOCK_OVERHEAD` per image + text + notes | Gemini inline total; Anthropic's many-image threshold; base64 inflates 4/3; JSON envelope per block | planner: oldest images drop first, each a note; guard: an image-bearing payload still over the limit is **refused** with size and limit named — deterministic, no send |
| file read | `fs_stat` then `read(MAX_BYTES + 1)` per attachment; no caching | bounded read | oversized → note without loading |
| request growth per turn | retained images re-sent while in the window and within budget; ≈13 MB on the wire at the cap | operator decision | drops with the exchange when summarized |
| move / delete / export | one `rename`/`delete`/copy per folder | existing tree walk | reported; `.md` moves, 🌿 rewrites and state updates already done stay done |
| keystroke, redraw, parse | one anchored `match` per question line | — | N/A |

## Lifecycle (ARCH-FUNERAL)

`assets/<ts>/<stamp>.png` is created by the paste (and #239), needed while a
transcript line references it, moved with its chat by either mover, copied by
export, removed by whichever of the five deleters removes its chat. Bound: one
file per paste, ≤ 10 MB, never rewritten. **Residue named:** a link line the
operator deletes by hand leaves an unreferenced file until the chat is deleted;
no sweep (Non-goals). A removal that fails is **reported**, not assumed, and
the folder stays for the next delete. Logs are bounded by elision. The paste's
temp file is removed on every path; if nvim dies mid-read it leaks one file in
the OS temp dir.

## Trust boundaries (ARCH-SECURE)

- **Transcript lines** (model-writable): only the closed grammar of decision 4
  yields a path; it is joined to the chat's own directory by string
  concatenation and opened with `io.open`, never `vim.fn.expand`/`glob`.
- **Persisted asset bytes**: stat'ed and read bounded (decision 7); a file
  that grew, vanished or is not an image is a note.
- **Clipboard bytes**: written verbatim under a folder and name parley minted;
  extension fixed `png`; size capped before writing; the temp file lives in
  `vim.fn.tempname()`.
- **Tool stderr**: trimmed into a notification, never executed.
- **`clipboard_cmd`** (user config): an argv list; `{out}` replaced as a whole
  argument; built-in Linux recipes pass the path as `$1` to `sh -c`.
- **Destructive calls**: `delete_chat_file` removes only
  `folder_for(path)` for the chat being deleted (non-timestamp names remove
  nothing); `vim.fn.delete(…, "rf")` does not follow symlinks; every prompt
  names the folder. Export copies, never moves.
- **HTML export**: `alt`/`src` attribute-escaped.
- **Credentials**: none. **Tests**: no real clipboard (fixture via config);
  the live check is opt-in and restores what it found.

## State and ordering (ARCH-ORDER)

`paste_image.paste` carries an in-flight marker per buffer, an extmark anchor,
a spawned tool and a temp file.

| State | Event | Next / effects |
|---|---|---|
| idle | key on non-chat buffer / no tool | idle; message; nothing spawned |
| idle | key | reading: mark, anchor, spawn |
| reading | second key on the same buffer | reading; "already in progress" (ignored: a queue would land links in completion order) |
| reading | tool `ok` | buffer invalid → idle, temp removed, **nothing saved**; else `save` under the buffer's current name; save fails → idle, partial removed by `save`, message; else insert after the anchor, idle |
| reading | `no_image` / `failed` / 124 | idle; temp removed; message with the tool's words |
| reading | buffer closed, rename or move finished, lines inserted above | handled at completion: validity check; current name; the extmark follows |
| reading | nvim dies | temp leaks (bounded); no asset |
| any | Lua error in the callback | idle via `pcall`; error notified |

Filesystem outcomes (decision 8): `save` = mkdir fail → nothing; write/close
fail → partial removed, error; `move_with` = clash refused before any `.md`
moves; rename fail → reported after the `.md` move, state and 🌿 rewrite
complete; `delete_with` = fail → reported, file deletion still proceeds;
`copy_into` = each failed file reported, count is successes only. The event
most likely mishandled is the buffer closing before the tool answers (the first
draft saved first); a spec pins it. Extent: nothing outlives a paste except the
tool until its timeout. Nondeterminism enters at IO completion; the fixture's
`slow:` state and a held fake runner reproduce interleavings.

## Core concepts

### Pure entities

| Name | Lives in | Status |
|------|----------|--------|
| `key_for` | `lua/parley/assets.lua` | new |
| `folder_for` | `lua/parley/assets.lua` | new |
| `folder_in` | `lua/parley/assets.lua` | new |
| `relative_path` | `lua/parley/assets.lua` | new |
| `markdown_link` | `lua/parley/assets.lua` | new |
| `unique_name` | `lua/parley/assets.lua` | new |
| `media_type` | `lua/parley/assets.lua` | new |
| `too_big` | `lua/parley/assets.lua` | new |
| `parse_attachment` | `lua/parley/assets.lua` | new |
| `attachments_in` | `lua/parley/assets.lua` | new |
| `encoded_size` | `lua/parley/assets.lua` | new |
| `plan_budget` | `lua/parley/assets.lua` | new |
| `payload_size` | `lua/parley/assets.lua` | new |
| `has_image` | `lua/parley/assets.lua` | new |
| `question_content` | `lua/parley/assets.lua` | new |
| `omitted_text` | `lua/parley/assets.lua` | new |
| `move_conflict` | `lua/parley/assets.lua` | new |
| `elide_image_data` | `lua/parley/assets.lua` | new |
| `removal_note` | `lua/parley/assets.lua` | new (exported with Task 2; consumed by Task 9) |
| `select` | `lua/parley/clipboard_image.lua` | new |
| `argv_for` | `lua/parley/clipboard_image.lua` | new |
| `classify` | `lua/parley/clipboard_image.lua` | new |
| `host_env` | `lua/parley/clipboard_image.lua` | new |
| `preserve_exchange` | `lua/parley/chat_respond.lua` | new (extracted from `build_messages` `:779-798`) |
| `window_size` | `lua/parley/chat_respond.lua` | new (extracted from `:735-747`) |
| `parse_chat` | `lua/parley/chat_parser.lua` | modified (question gains `attachments`) |
| `build_messages` | `lua/parley/chat_respond.lua` | modified (uses the predicate, the budget, `opts.chat_path`) |
| `build_messages_from_model` | `lua/parley/chat_respond.lua` | modified (attachments under the same predicate and budget) |
| `translate_messages` | `lua/parley/tools/wire_openai.lua` | modified (image blocks → `image_url` parts) |
| `googleai_parts` | `lua/parley/providers.lua` | new (local) |
| `simple_markdown_to_html` | `lua/parley/exporter.lua` | modified (`![alt](src)` → `<img>` via placeholder) |

Contracts (all pure; unit-tested without IO):

- `key_for(chat_path) → ts|nil`; `folder_for(chat_path) → abs|nil, err`;
  `folder_in(dir, ts)`; `relative_path(ts, name)`; `markdown_link(rel)`;
  `unique_name(stamp, ext, exists)`; `media_type(path)`; `too_big(n)` — the one
  size sentence. The layout half is plain string work (no `vim.fs`), so the
  key rule for notes could widen here alone.
- `parse_attachment(line) → { path, ts, name, media_type }|nil` (decision 4);
  `attachments_in(text)` applies it per line — the parser and the buffer-block
  builder share the grammar.
- `encoded_size(n) → ⌈n/3⌉·4` (base64 length of `n` raw bytes).
  `plan_budget(candidates, text_bytes, limits) → { included = set(path), notes
  = { [path] = reason }, warning|nil }` where `candidates = { { order, path,
  size|nil, err|nil } }` in exchange order, `text_bytes` is the UTF-8 length of
  every retained text the request carries, and `limits = { max_bytes,
  max_request_bytes, max_images, block_overhead }`. The budget starts charged
  with `text_bytes`; each candidate is charged the bytes of the note it would
  get if excluded, then taken newest first while `encoded_size(size) +
  block_overhead` and the count still fit; a missing size or `size >
  max_bytes` is a note and never counts as an image; an image that does not
  fit is a note "not sent: request budget"; `text_bytes` alone over the
  request limit includes nothing and sets `warning`. Deterministic and total.
  `payload_size(payload) → bytes` = `#vim.json.encode(payload)`, and
  `has_image(payload) → boolean` over the three wire shapes: the final guard
  `chat_respond` applies to the built payload before posting — refuse when
  `has_image` and `payload_size > MAX_REQUEST_BYTES`. Tests exercise the guard
  on boundary-sized content against the actual encoded payload of each wire.
- `question_content(text, attachments, plan, read) → string|blocks`: image
  blocks for `plan.included`, one text block last; notes prepended (from
  `plan.notes` and from a read that fails after planning); `read(rel) →
  bytes|nil, err` is the bounded reader injected by the caller.
- `omitted_text(omit_user_text, attachments)`: the placeholder plus
  `OMITTED_NOTE` when an image was attached.
- `move_conflict(chat_src, dst_dir, io_) → src, dst | nil, err | nil` — the one
  clash rule the pre-check and `move_with` share.
- `elide_image_data(value)`: deep copy with every image payload (Anthropic
  `source.data`, Gemini `inlineData.data`, OpenAI data-URL `image_url.url`)
  replaced by `"<mime, N bytes>"`.
- `select(config_cmd, env)`, `argv_for(recipe, out)`, `classify(code, stderr,
  size)`, `host_env()` (decision 11).
- `preserve_exchange(idx, exchange_idx, total, max_exchanges, has_file_refs)
  → boolean` — exactly the rule at `:779-798`, now named; `window_size(headers,
  config) → max_exchanges` — exactly `:735-747`. Both builders call both.

### Integration points

| Name | Lives in | Status | Wraps |
|------|----------|--------|-------|
| `default_io` | `lua/parley/assets.lua` | new | filesystem (`io.open`, `uv.fs_stat`, `vim.fn.mkdir/delete/readdir`, `os.rename/remove`) |
| `save` | `lua/parley/assets.lua` | new | `default_io` |
| `read_bounded` | `lua/parley/assets.lua` | new | `default_io` |
| `move_with` | `lua/parley/assets.lua` | new | `default_io` |
| `delete_with` | `lua/parley/assets.lua` | new | `default_io` |
| `copy_into` | `lua/parley/assets.lua` | new | `default_io` |
| `read_png` | `lua/parley/clipboard_image.lua` | new | `vim.system` |
| `paste` | `lua/parley/paste_image.lua` | new | buffer, cursor, notify |
| `paste_image` | `lua/parley/init.lua` | new | `paste_image.paste` with real deps |
| `move_chat` | `lua/parley/init.lua` | modified | `assets.move_conflict` / `move_with` |
| `move_chat_tree` | `lua/parley/init.lua` | modified | `assets.move_conflict` / `move_with` |
| `delete_chat_tree` | `lua/parley/init.lua` | modified | the one delete door (row added by Task 9) |
| `handle_delete_response` | `lua/parley/chat_finder.lua` | modified | the one delete door (Task 9) |
| `handle_delete_tree_response` | `lua/parley/chat_finder.lua` | modified | the one delete door (Task 9) |
| `export_tree` | `lua/parley/exporter.lua` | modified | `assets.copy_into` |
| `fake_clipboard` | `tests/fixtures/fake_clipboard` | new | stands in for `osascript` |

Contracts (IO; every function takes `io_` defaulting to `default_io`, which is
**main-loop only** — `read_png` schedules before any of it runs):

- `default_io = { exists, stat(p) → size|nil, mkdir → ok, write(p, bytes) → ok,
  err (checks write AND close; removes the partial on failure), read(p, max) →
  bytes|nil, err, rename → ok, err, remove_tree → ok, err, list, now }`.
- `save(chat_path, bytes, ext, io_) → rel, abs | nil, nil, err`: refuses a
  non-chat path and `> MAX_BYTES` (with `too_big`) before touching disk; mkdir
  failure → error, nothing written; write failure → partial removed, error.
- `read_bounded(chat_path, rel, io_) → bytes|nil, err`: `stat` first; larger
  than `MAX_BYTES` → `nil, too_big(size)` without reading; else
  `read(p, MAX_BYTES + 1)` and a second size check.
- `move_with(chat_src, chat_dst, io_) → ok, err`: nothing to move → `true`;
  clash → `nil, err` (nothing done); mkdir/rename failure → `nil, err`.
- `delete_with(chat_path, io_) → ok, err`: no folder → `true`; removal
  failure → `nil, err` (reported by the caller; file deletion proceeds).
- `copy_into(chat_path, export_dir, io_) → n, errs[]`: `n` counts successful
  writes only; every failed mkdir/read/write is an entry in `errs`.
- `read_png(recipe, out, on_done, runner)`: spawn; `uv.fs_stat` the file;
  classify; `vim.schedule(on_done(status, msg))`. `runner(argv, on_complete)`
  defaults to `vim.system` with a 5 s timeout.
- `paste(buf, deps)` with `deps = { config, notify, runner? }`: decision 12
  and the ordering table; every terminal path clears the in-flight mark,
  removes the temp file and notifies.
- `delete_chat_file(path)` (Task 9): `assets.delete_with` then
  `helpers.delete_file`; a removal error is notified, the file is still deleted.
- `fake_clipboard`: models osascript (says so): `PARLEY_FAKE_CLIPBOARD =
  png:<file> | slow:<file> | text | broken`; logs each call to
  `$PARLEY_FAKE_CLIPBOARD_LOG`.

## Test surface (ARCH-MOCK) and strategies

| Dependency | Seam | Fake | Live check |
|---|---|---|---|
| clipboard tool | recipe argv → `read_png(runner)`; `config.assets.clipboard_cmd` | `tests/fixtures/fake_clipboard` through the config seam; a held fake runner in unit tests | `tests/integration/clipboard_live_spec.lua`, opt-in `PARLEY_LIVE_CLIPBOARD=1`, darwin only, restores the clipboard text |
| filesystem | `assets.default_io` | in-memory `io_` with **injectable failure** (`fail = { write = true }`, `stat = "ENOENT"`, `remove_tree = false`) | — |
| provider wires | `dispatcher.prepare_payload` | payload assertions are pure | the M1 gate sends a pasted image through every configured wire family |

One strategy per risky function — oracle and input class only; the cases
live in the specs:

| Function | Oracle | Input class |
|---|---|---|
| `parse_attachment`, `attachments_in` | adversarial-input table: accept iff the closed grammar | every rejection class of decision 4 plus the accepted forms |
| `encoded_size`, `plan_budget` | property: included = newest-first prefix fitting both limits after the text and note charges; every exclusion carries a reason; deterministic | synthetic candidate lists around each limit, base64 inflation, text alone over budget |
| `payload_size`, `has_image`, the send guard | mechanical guard on the **actual encoded payload** of each wire: a planned request fits; a payload pushed past the limit with an image present is refused with size and limit named; without an image it is untouched | boundary-sized content built through `prepare_payload` on all three wires; post-plan additions (notes) |
| `question_content`, `omitted_text` | shape: images first, one text block last, notes prepended, string when nothing included; the note only with attachments | planned/unplanned/failed-after-plan attachments |
| `preserve_exchange`, `window_size` | characterization: the existing cases in tests/unit/build_messages_spec.lua stay byte-identical; then differential — the continuation builder and the initial builder agree on which exchanges carry images | a summarized image exchange under tool-loop continuation; the fake reader records that nothing was read |
| both builders, budget | differential: identical inclusion, notes and encoded payload size on both paths | several retained exchanges over the request bytes or count; an oversized persisted file (fake `stat`) |
| `save`, `read_bounded`, `move_with`, `delete_with`, `copy_into` | failure-injection matrix on the in-memory `io_`: documented `ok, err` and documented residual state per failing operation | each operation failing in turn; a file that grew past the cap after planning |
| `classify`, `select`, `argv_for` | decision tables | exit code × file size; platform × executables; `{out}` placement |
| `read_png` | interleaving seam: a held fake runner settles nothing until released | synchronous and held runners |
| `paste` | one integration case per row of the ordering table, fixture through the config seam; the third paste waits for its link | fixture states `png:`/`slow:`/`text`/`broken`; a closed buffer; an unwritable folder |
| wires | golden payload per provider, text-only shapes pinned byte-for-byte | one internal image message; `web_search = false` at file scope |
| `elide_image_data` | no base64 survives `vim.inspect`; `grep` shows exactly three sinks | the three wire shapes |
| movers, deleters | integration through the real commands, the folder present and absent; the finder with `_reopen_chat_finder` stubbed | clash before any move; injected rename and removal failures |
| the sweep in tests/arch/chat_delete_sweep_spec.lua | count: exactly one `helpers.delete_file(` under `lua/parley/**` (named exclusions), inside the door; seen red with six and with two | — |
| export | `<img>` survives every inline rule and escapes quotes (unit); folder copied and tag present (integration, front-matter fixture) | markdown and HTML |
| live conformance | real recipe, real clipboard, opt-in, restores what it found | image then text |

## Running tests

- One spec: `nvim -n --headless --noplugin -u tests/minimal_init.vim -c "PlenaryBustedFile <spec>" -c "qa!"`
- Mapped: `make test-spec SPEC=chat/attachments` (after Task 8)
- Full: `make lint && make test`

---

## M1 — capture and send

### Task 1: `assets` — layout, grammar, budget, content (pure)

**Files:** create `lua/parley/assets.lua`, `tests/unit/assets_spec.lua`.
**Delivers:** every pure contract above except `move_conflict` and
`elide_image_data`; constants `DIR`, `MAX_BYTES`, `MAX_REQUEST_BYTES`,
`MAX_REQUEST_IMAGES`, `OMITTED_NOTE`.
**Acceptance:** grammar table, budget property, content shapes green; each
written red first.

- [ ] Red: grammar, budget, content, omitted specs
- [ ] Green: the module
- [ ] Commit `#231 M1: assets — layout, grammar, budget, question content`

### Task 2: `assets` — the checked IO shell

**Files:** `lua/parley/assets.lua` (append), `tests/unit/assets_spec.lua` (append).
**Delivers:** `default_io`, `save`, `read_bounded`, `move_conflict`,
`move_with`, `delete_with`, `copy_into` per the IO contracts.
**Acceptance:** the failure-injection matrix green; two saves in one
millisecond do not collide; a refused save creates nothing.

- [ ] Red: happy paths + failure matrix on the in-memory `io_`
- [ ] Green
- [ ] Commit `#231 M1: assets — checked save/read/move/delete/copy behind one io`

### Task 3: `clipboard_image`

**Files:** create `lua/parley/clipboard_image.lua`, `tests/unit/clipboard_image_spec.lua`.
**Delivers:** `RECIPES` (darwin/wayland/x11 as data), `select`, `argv_for`,
`classify`, `host_env`, `read_png`, `TIMEOUT_MS`.
**Acceptance:** decision tables green; the darwin recipe never puts the path
inside the script text; held-runner case green.

- [ ] Red / Green / Commit `#231 M1: clipboard_image — recipes as data, one classify rule, vim.system seam`

### Task 4: the fixture, the paste flow, the key

**Files:** create `tests/fixtures/fake_clipboard`, `tests/fixtures/one_pixel.png`,
`lua/parley/paste_image.lua`, `tests/integration/paste_image_spec.lua`;
modify `lua/parley/config.lua`, `lua/parley/keybinding_registry.lua`,
`lua/parley/init.lua`.
**Contract:** `config.assets.clipboard_cmd` is the documented override (its
comment carries the exit-code contract and the "setup replaces this table"
caveat); the registry gains `paste_image` in `parley_buffer` scope with the
shipped `<M-v>` for `n`/`i` in config; `init.lua` exposes
`M.paste_image(buf, deps)` and registers the callback for both chat and
markdown buffers; `paste_image.paste` implements decision 12 and the ordering
table. The fixture models osascript and says so.
**Acceptance:** the `paste` strategy green; keybinding agreement and help
specs unchanged and green; the spec binds the fixture path to a local named
`fake_clipboard`.

- [ ] Red / Green / Commit `#231 M1: <M-v> pastes the clipboard image into assets/<ts>/ and links it`

### Task 5: the parser

**Files:** `lua/parley/chat_parser.lua` (`:637-645`, `:653-660`, `:865`),
`tests/unit/parse_chat_spec.lua` (append, `std_header`).
**Delivers:** `question.attachments[] = { line, path, media_type }` from
`assets.parse_attachment` on the prefix line and every continuation line;
answer-block links stay prose; every exchange has the list.

- [ ] Red / Green / Commit `#231 M1: parser — an image link in a question block is an attachment`

### Task 6: one retention rule, one budget, both builders, elided logs

**Files:** `lua/parley/chat_respond.lua`, `lua/parley/assets.lua`
(`encoded_size`, `plan_budget`, `request_size`, `elide_image_data`),
`tests/unit/build_messages_spec.lua` (append).
**Contract:** `window_size` and `preserve_exchange` are the retention rule,
extracted unchanged from `build_messages`; both builders call them. Each
builder plans one budget over the request's retained attachments (charged with
its retained text bytes) before emitting, reads through `read_bounded` relative
to the buffer's chat path (the initial builder via `opts.chat_path`, the
continuation builder via `opts = { chat_path, max_exchanges }` from its
caller), emits `question_content` for retained exchanges and `omitted_text`
for the rest. After `prepare_payload`, `chat_respond` applies the send guard
(`has_image` and `payload_size` over the limit → refuse, message names size
and limit). The continuation builder's **text** behaviour is unchanged. The
three log sinks in Facts wrap their value in `elide_image_data`.
**Acceptance:** the characterization, differential-retention, budget, send-guard
and elision strategies green; a question without attachments produces
byte-identical messages to today.

- [ ] Red / Green / Commit `#231 M1: build_messages — one retention rule and one serialized-request budget for both builders; logs elided`

### Task 7: three wires, three shapes

**Files:** `lua/parley/tools/wire_openai.lua` (`:270-310`: image blocks →
`image_url` parts, `text` computed once), `lua/parley/providers.lua`
(`googleai_parts`; merge appends whole lists), `tests/unit/wire_images_spec.lua`.
**Acceptance:** the wire cases green; `dispatcher_spec`,
`parley_harness_golden_spec`, `openai_tool_loop_spec` still green.

- [ ] Red / Green / Commit `#231 M1: image blocks reach every wire in its own shape`

### Task 8: M1 gate

**Files:** create `atlas/chat/attachments.md` (surface, model, retention and
budget, logs, lifecycle; M2 lines are appended by Task 11); `atlas/index.md`
§1 line; `atlas/traceability.yaml` key `chat/attachments` listing only files
that exist at this point; the issue's `## Plan` retagged `M1 —` / `M2 —`.
**Acceptance:** `make lint && make test` green (arch guards included).
**Manual check on this machine:** paste a real image with `<M-v>`, see the
link and `:MarkdownPreview`; a text clipboard declines with osascript's
words; then **send** the pasted question through every wire family configured
here (anthropic, openai, googleai, cliproxy) after re-reading the Anthropic
per-image cap, and record each result in `## Log` (a family without a key is
"not exercised"); `tail` of `parley.log` shows `<image/png, N bytes>`.

- [ ] Atlas, index, traceability, retag
- [ ] `make lint && make test`
- [ ] Manual paste + per-wire send, logged
- [ ] `sdlc milestone-close --issue 231 --milestone M1`

## M2 — the folder follows the chat

### Task 9: every mover carries the folder; every deleter removes it

**Files:** `lua/parley/init.lua`, `lua/parley/chat_finder.lua`,
`lua/parley/assets.lua` (`removal_note`), `tests/integration/chat_move_spec.lua`
(append), `tests/arch/chat_delete_sweep_spec.lua`, this plan's tables (append
the `delete_chat_file` row; replace "the one delete door" on the sibling rows).
**Contract:** both movers named in Facts refuse an asset clash through
`assets.move_conflict` before any `.md` moves, carry the folder with
`assets.move_with` after the `.md` move, finish their state refresh, file
tracking and 🌿 rewrite regardless, and report any stranded folder at the
end. `M.delete_chat_file(path)` = `assets.delete_with` then
`helpers.delete_file`, a removal failure notified and the file still deleted;
it replaces `helpers.delete_file` at the five chat-deletion sites named in
Facts, and every single-file or tree prompt at those sites appends
`assets.removal_note(path)` (`"" | " and assets/<ts>/ (N files)"`).
**Acceptance:** the movers/deleters strategy and the sweep green;
`chat_finder_logic_spec` unchanged and green; `writefile(…, "a")` rather than
`:write` on the scratch buffer.

- [ ] Append the `delete_chat_file` table row
- [ ] Red / Green / Commit `#231 M2: both movers carry assets/<ts>/; all five deleters remove it`

### Task 10: export

**Files:** `lua/parley/exporter.lua`, `tests/unit/exporter_tree_spec.lua`,
`tests/integration/tree_export_spec.lua`.
**Contract:** `simple_markdown_to_html` renders `![alt](src)` as
`<img src alt class="asset-image">` through the file's placeholder mechanism
(taken before any inline rule, restored after the last, `<p>`-wrapped form
handled), with `alt`/`src` attribute-escaped and a `.asset-image` style;
`export_tree` copies each exported chat's folder with `assets.copy_into` and
reports failed copies.
**Acceptance:** the export strategy green.

- [ ] Red / Green / Commit `#231 M2: tree export copies assets/<ts>/ and renders image links in HTML`

### Task 11: docs

**Files:** `atlas/chat/attachments.md` (M2 lines: movers, deleters, prompts,
export, live spec), `atlas/index.md`, `atlas/chat/memory.md` (attachments do
not pin; the placeholder notes an image), `atlas/chat/format.md`,
`atlas/providers/{anthropic,openai,googleai}.md` (one shape line each),
`atlas/export/tree_export.md` (copy; HTML `<img>`; Jekyll caveat),
`atlas/ui/keybindings.md` (`paste_image` in the alt family), `README.md`
(`<M-v>` line near `:156`).

- [ ] Write / `make test` (doc guards) / Commit `#231 M2: atlas — attachments, movers/deleters, wire shapes, keys`

### Task 12: live conformance and close

**Files:** create `tests/integration/clipboard_live_spec.lua`;
`atlas/traceability.yaml` (append it).
**Contract:** opt-in (`PARLEY_LIVE_CLIPBOARD=1`), darwin only; exercises
`RECIPES.darwin` against the real clipboard for an image and for text;
preserves the operator's clipboard (text saved only when it is text, restored
on every path).
**Acceptance:** run once on this machine outside the agent sandbox and logged;
`make lint && make test` green.

- [ ] Write, run live, log
- [ ] `sdlc milestone-close --issue 231 --milestone M2`; `sdlc close --issue 231 --verified '…'`

## Future extensions

- **#239** calls `assets.save` from the stream sink and `assets.question_content`
  for model-role images on wires that accept them, under the same budget.
- **Notes**: widening `key_for` to non-timestamp basenames is the one place a
  notes-side paste would change.
- **An orphan sweep**, if residue ever matters: files in `assets/<ts>/` not
  named by any `![](…)` line of `<ts>*.md`; it lives in `assets`.
- **A `target`** for "the transcript is the index; sidecars hold only
  referenced bytes, keyed by chat timestamp".
- **Anthropic Files API** for long conversations with many images.

## Revisions

### 2026-09-12 — after the first plan-document review (two reviewers)

- **Reason:** review findings, all verified against the tree.
- **Delta:** one size sentence (`too_big`); `reg.entries` is a table;
  ARCH-ORDER section, buffer validity checked before saving, one paste per
  buffer, chat path re-read at completion; ARCH-FUNERAL section; both movers
  behind `move_conflict`; one `delete_chat_file` door for five sites plus a
  sweep; `<img>` via the exporter's placeholder mechanism; concrete export
  test; traceability lists only existing files; chunks re-cut.

### 2026-09-12 — after the second review (three reviewers)

- **Reason:** round-2 findings, all verified.
- **Delta:** `elide_image_data` at the three log sinks; the M1 gate sends the
  pasted question through every configured wire; the finder test stubs
  `_reopen_chat_finder`; the sweep counts exactly one call with named
  exclusions; all four delete prompts append `removal_note`; `move_chat`
  finishes state updates before reporting; `fake_clipboard` bound to a local
  and `chat_memory.max_full_exchanges` dotted for the symbol guard; the
  third-paste test waits for its link; small items (`std_header`,
  `web_search = false`, `text` once, hoisted require, held-runner case,
  config/insert-mode/main-loop notes, Ollama and ancestor non-goals).

### 2026-09-12 — after the plan-quality gate (codex, round 1: PQ-1..PQ-4)

- **Reason:** four Important findings.
- **Delta:** (PQ-1) retention extracted into `preserve_exchange` +
  `window_size` and applied by **both** builders to attachments; the
  continuation case is a named test strategy. (PQ-2) a request-wide budget
  (`MAX_REQUEST_BYTES` 20 MB, `MAX_REQUEST_IMAGES` 20) planned by
  `plan_budget` over all retained attachments before building, newest first,
  deterministic; reads are bounded (`read_bounded`: stat, then
  `read(MAX_BYTES + 1)`). (PQ-3) every `assets` IO function returns a checked
  outcome (`write` and `close` checked, partial removed, counts are successes
  only), callers relay failures, and the failure-injection matrix is a named
  strategy. (PQ-4) the procedural script (replacement code, line-by-line
  edits, prescribed test bodies) is compressed into contracts, decisions,
  acceptance criteria and one strategy per risky function; tasks keep files,
  deliverables, acceptance and commit boundaries. The reviewed draft that
  carried the full code lives in git history (`c977a18`, `95574c1`) for the
  implementer's reference; the contracts here are authoritative.

### 2026-09-12 — plan-quality round 2 (PQ-2, PQ-4 still open)

- **Reason:** the budget counted raw bytes (base64 inflates 4/3 and text was
  uncounted); strategies still read as case lists and two tasks as edit scripts.
- **Delta:** the budget is in serialized bytes — `encoded_size` of each
  included image plus the retained text, charged first — with text-only
  overflow defined (no images, notes, one warning) and a final
  `request_size` guard on both builders (tests assert, production warns).
  The strategy section is a table of oracle × input class per function;
  Tasks 6 and 9 are contracts with acceptance, the call-site inventories
  living in Facts only.

### 2026-09-12 — plan-quality round 3 (PQ-2, PQ-4 still open)

- **Reason:** accounting excluded JSON overhead and post-plan notes and the
  guard only warned; Facts and three tasks still carried line numbers and
  procedures.
- **Delta:** one request rule enforced on the **final encoded payload**: the
  planner charges text, notes and base64 + `BLOCK_OVERHEAD` per image; after
  `prepare_payload`, `chat_respond` refuses an image-bearing payload over the
  limit (`payload_size`, `has_image`), tested against the actual encoded
  payload of each wire. Facts name functions, not lines; Tasks 4, 10 and 12
  are contracts with acceptance.
