# #231 Attach images to questions — Implementation Plan

> **For agentic workers:** Consult AGENTS.md Section 3 (Subagent Strategy) to determine the appropriate execution approach: use superpowers-subagent-driven-development (if subagents are suitable per AGENTS.md) or superpowers-executing-plans to implement this plan. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** `<M-v>` in a chat buffer saves the clipboard image under
`<chat-dir>/assets/<chat-timestamp>/` and inserts `![](assets/<ts>/<file>.png)`;
the parser reads that line in a question as an attachment; `build_messages`
sends it in each wire's own image shape; a summarized exchange drops it and
says so; every chat move and every chat delete carries or removes the folder;
tree export copies it.

**Architecture:** One new pure module, `lua/parley/assets.lua`, owns the
sidecar layout (folder, filename, link, attachment grammar, content blocks,
the omitted-note) with a tiny injectable IO table for save/read/move/delete/copy
— it is the single writer #239 will also call. A second pure module,
`lua/parley/clipboard_image.lua`, owns the platform recipes and the
classification of a clipboard read; `vim.system` is its one seam.
`lua/parley/paste_image.lua` is the thin orchestration behind the key. The
parser, `build_messages`, and the three provider shapes each gain one small
branch that consumes `assets`. A process fixture, `tests/fixtures/fake_clipboard`,
models `osascript` behind the same argv seam the real recipe uses.

**Tech Stack:** Lua on Neovim 0.10+ (`vim.system`, `vim.base64`, `vim.uv`),
`osascript` (macOS) / `wl-paste` / `xclip` (Linux), plenary busted; a Python 3
test fixture.

---

## Facts this plan rests on (verified 2026-09-12)

- Chat identity is the timestamp prefix. `chat_slug.parse_filename(basename)`
  (`lua/parley/chat_slug.lua:74`) returns `ts, slug` and round-trips a bare
  timestamp; `TIMESTAMP_PATTERN` is `YYYY-MM-DD.HH-MM-SS.mmm` (`:69`).
  `logger.now()` (`lua/parley/logger.lua:16`) mints the same shape. The slug
  rename at `init.lua:3085` renames only the `.md`, in place.
- The parser creates an exchange at `chat_parser.lua:637-645` with
  `question = { line_start, line_end, content, file_references = {} }`; question
  lines are scanned at `:653-660` (prefix line) and `:845-866` (continuation).
  The loop index `i` is the 1-based index into `lines`. A `![](…)` line
  classifies as `text` today.
- `build_messages` (`chat_respond.lua:700`) emits the question at `:857-864`
  (string content) and the placeholder `omit_user_text` at `:868`; preservation
  is decided at `:779-798`. Its one caller is `:1454`, where `buf` is in scope.
  `build_messages_from_model` (`:432`) rebuilds from buffer blocks for the
  tool-loop continuation and reads question text at `:474-484`.
  `parley._build_messages` (`init.lua:3948`) is the public alias the unit spec
  drives; that spec defines `stub_helpers` and `stub_logger` at its top
  (`tests/unit/build_messages_spec.lua:83-94`) and helpers `agent()`,
  `parsed_chat()`, `exchange(q, answer)`.
- Internal messages are Anthropic-shaped; `wire.translate_messages` runs
  unconditionally in `dispatcher.prepare_payload` (`dispatcher.lua:121`). Only
  `wire_openai.translate_messages` (`wire_openai.lua:232`) exists; its user
  branch at `:288-297` warns and DROPS any block that is not `tool_result` or
  `text`. `ERROR_PREFIX` is file-local at `:207`. googleai has no wire;
  `googleai.format_payload` (`providers.lua:841`) does
  `parts = {{ text = message.content }}` and merges same-role neighbours by
  `parts[1].text` — a table `content` would corrupt it. `logger` is in scope in
  `providers.lua` (`:13`). `anthropic.format_payload` hoists `system` and passes
  table content through; `openai.format_payload` leaves messages untouched.
- Provider image shapes, read from current docs today:
  - Anthropic (platform.claude.com/docs/en/build-with-claude/vision): user
    content block `{ "type":"image", "source":{ "type":"base64",
    "media_type":"image/png", "data":"…" } }`; images before text is the
    documented preference; JPEG/PNG/GIF/WebP; 10 MB per image; 100 per request.
  - OpenAI Chat Completions (developers.openai.com/api/docs/api-reference/chat/create):
    content part `{ "type":"image_url", "image_url":{ "url":"data:image/png;base64,…",
    "detail":"auto" } }`.
  - Gemini generateContent (ai.google.dev/api): part
    `{ "inlineData": { "mimeType":"image/png", "data":"…" } }`, camelCase; 20 MB
    total inline request.
- macOS clipboard, measured on this machine: `pngpaste` is not installed;
  `osascript` is. `osascript -e 'clipboard info'` takes 60–70 ms. The
  write-to-file recipe below, run against a text clipboard, exits **1** with
  stderr `207:208: execution error: Can’t make some data into the expected
  type. (-2700)` and leaves a **0-byte file** at the target path.
- Neovim here is 0.11.7; `vim.base64.encode` exists (0.10+). `vim.system`'s
  `on_exit` runs in a libuv callback where `vim.fn.*` is refused; a `timeout`
  expiry yields `code 124, signal 15`. `register_buffer`
  (`keybinding_registry.lua:1279`) passes a plain function to `vim.keymap.set`
  for every mode including `i`; the registry's entry list is the table
  `M.entries` (`tests/unit/keybindings_spec.lua:234` iterates it).
- **Chat files move at two sites**: `M.move_chat` (`init.lua:3209-3247`, a
  single-file mover with its own conflict check and `os.rename` at `:3232`;
  production has no caller, `tests/integration/chat_move_spec.lua:70` drives it)
  and `M.move_chat_tree` (`:3529`, the `:ParleyChatMove` path via
  `chat_dirs.cmd_chat_move`, `os.rename` at `:3571`). Branch chats are siblings
  in one directory, each with its own timestamp.
- **Chat files are deleted at five sites**, all through `helpers.delete_file`:
  `delete_chat_tree` (`init.lua:3523`), `cmd.ChatDelete` (`:3873`, `:3880`),
  the markdown `md_delete_file` key (`:2952`), the finder's
  `handle_delete_response` (`chat_finder.lua:215`) and
  `handle_delete_tree_response` (`:289`). `dispatcher.lua:76` deletes query
  cache JSON, `issue_finder`/`note_finder` delete non-chats — excluded.
- Export (`exporter.lua:820 export_tree`) exports the **current buffer's**
  tree; every existing case in `tests/integration/tree_export_spec.lua` does
  `create_chat_file(name, content_string)` (front matter required —
  `build_info_from_lines` refuses a file without it), `vim.cmd("edit …")`,
  `M.cmd.ExportHTML()` / `M.cmd.ExportMarkdown()`, then `bdelete!`; the dirs
  are `tmpdir`, `export_html_dir`, `export_markdown_dir`. `write_markdown_file`
  (`:751`) / `write_html_file` (`:695`) write one file per entry.
  `simple_markdown_to_html` (`:339`) has no image conversion; **every inline
  rule runs over the whole string**, so an `<img …>` emitted early is still
  mangled by the `_([^_\n]+)_` italic rule at `:415` (verified: the attribute
  text gets `<em>` inserted). The file already solves this class with opaque
  placeholders: `XBRANCHX<n>XBRANCHX` (`:282-284`), restored after every gsub
  (`:709-717`). `html_css` is at `:446`.
- Keys: chat buffers register at `init.lua:2701`, markdown at `:2900`; a
  `parley_buffer` entry needs a callback in both. Resolution REPLACES: the
  shipped key must live in `config.lua` (`chat_shortcut_*`, `:357-467`).
  `<M-v>` is unused across the alt family.
- Buffer writes go through `lua/parley/buffer_edit.lua`
  (`tests/arch/buffer_mutation_spec.lua`); `insert_lines_at(buf, line0, lines)`
  (`:297`) inserts before `line0`; `make_handle`/`handle_line` give an
  extmark-anchored line that survives concurrent edits.
- `tests/arch/single_source_sweeps_spec.lua:86` requires a Core-concepts table
  row for every `M.<fn>` / `M.<x> = <non-literal>` this branch adds under
  `lua/`; `:657-679` require every `.lua` path and every added spec named in
  `atlas/traceability.yaml` to exist and every added spec to be routed;
  `tests/arch/untrusted_path_spec.lua` forbids `vim.fn.expand/glob` on
  non-literal input outside its allow-list. The atlas document itself is
  required by `sdlc milestone-close`'s atlas gate, not by that guard.
- Process fixtures spawn through `tests/helpers/fixture_process.lua`
  (`spawn(script, args, extra_env)`); async specs wait with
  `tests/helpers/await.lua`; `$PARLEY_TEST_MODE` reaches child nvims, `g:`
  variables do not (#227). `chat_move_spec.lua`'s `create_chat` makes a
  scratch buffer (`nofile`), so `:write` on it raises E382.
- **Three logging sinks see the outgoing messages**: the unconditional
  `logger.debug("messages to send: " .. vim.inspect(messages))`
  (`chat_respond.lua:1639`; `logger.log` writes every level to `parley.log`,
  truncated at startup by line count only), and raw mode's
  `raw_log.write_exchange_turn(chat_path, messages)` / `write_raw_turn(…, {
  request = final_payload })` (`:2020-2030`, via `log_emit.format_exchange_turn`
  `:309`, which YAML-emits table content verbatim). With one 10 MB image in the
  window each is a ≈13 MB write per turn.
- The finder's delete handlers end by calling `_parley._reopen_chat_finder`
  (`chat_finder.lua:239,258,302,321`), which `vim.defer_fn`s a real
  `ChatFinder` 100 ms later; `tests/unit/chat_finder_logic_spec.lua:128-207`
  saves, stubs and restores both it and `M.helpers.delete_file`. The finder's
  single-file prompt is `prompt_delete_confirmation` (`:260`; its
  `vim.ui.input({ prompt = "Delete " .. item_value .. "? [y/N] " })` at `:273`)
  and the tree prompt is `prompt_delete_tree_confirmation` (`:324-341`).
  `cmd.ChatDelete`'s prompt is at `init.lua:3878`, `md_delete_file`'s confirm
  at `:2950`.
- `init.lua:1438 os.remove(last)` removes the legacy `<chat_dir>/last.md`
  state file — a deletion of a non-chat, never a timestamp chat.
- Ollama resolves to `wire_openai` (`wire.lua:39`), so it would receive
  `image_url` parts; Ollama's native chat API wants an `images` array.
- `collect_ancestor_messages` (`chat_respond.lua:225`) builds ancestor user
  turns from `exchange.question.content` strings, so an ancestor chat's
  attachment reaches the model as link text only.

## Design decisions

1. **The transcript is the index; the folder holds only bytes.** Every asset
   file is referenced from a transcript line; nothing reads the folder to
   discover content. Keyed by the chat's timestamp, never its slug (operator,
   2026-09-12: slugs are for humans, and humans reach assets through the
   transcript). Folder name `assets/`, not `images/`: #239's model-generated
   images and any later binary kind share it — one folder, one rule, one
   writer (`ARCH-DRY`).
2. **Ordinary markdown, relative to the chat file:** `![](assets/<ts>/<file>)`.
   `:MarkdownPreview` renders it unchanged; an operator deletes or reorders an
   attachment with normal editing; the link text also goes to the model, so a
   follow-up can name the file.
3. **One writer.** `assets.save(chat_path, bytes, ext)` is the only code that
   creates the folder, names a file, and forms a link. The clipboard flow, #239,
   both movers, all five deleters and export go through `assets`. No second
   layout.
4. **The attachment grammar is a parse at the boundary** (`ARCH-SECURE`): a
   line that is exactly an image link whose target is `assets/<timestamp>/<name>`
   with `[A-Za-z0-9._-]` characters and an accepted image extension. Absolute
   paths, `..`, URLs, backticks and anything else are prose, never read from
   disk — the transcript is model-writable.
5. **Attachments do not force preservation.** File references (`@@`) pin an
   exchange in the memory window; images do not — a screenshot can outweigh
   the whole conversation and would recur per request (operator decision in the
   issue). A summarized question's placeholder gains one fixed sentence saying
   an image was attached and is no longer included.
6. **Images lead, text follows** in the internal content blocks, matching the
   Anthropic guidance and giving every wire the same order.
7. **Missing or oversized files degrade visibly.** A block is never emitted for
   bytes that could not be read; a one-line note replaces it in the text so the
   model and the log both know. The size cap is Anthropic's 10 MB per image,
   the strictest of the three wires, applied at paste (refuse) and at send
   (note) from one constant and one sentence.
8. **googleai gets its parts mapping fixed, not a wire.** A `wire_googleai`
   (functionDeclarations) is the tool-loop's job, not this issue's; the parts
   mapping in `googleai.format_payload` becomes block-aware and the merge
   appends whole `parts` lists. Text-only payloads stay byte-identical (pinned).
9. **Clipboard recipes are data; the spawn is the seam** (`ARCH-MOCK`). A recipe
   is `{ tool, argv-with-{out} }`; selection is by platform and
   `vim.fn.executable`; `config.assets.clipboard_cmd` (an argv list) overrides
   it — the same contract the test fixture speaks, so production and test share
   the boundary. Classification is one rule for every recipe: exit 0 and a
   non-empty file → image; exit 0 with an empty file, or exit 1 → no image
   (osascript, wl-paste and xclip all exit 1 for "no such type"); anything else
   — including the 124 of a timeout — → failure, with the tool's stderr.
10. **The paste is asynchronous, anchored, and never orphans bytes.** The cursor
    line is captured as an extmark handle before the spawn; on completion the
    buffer is checked **before** anything is saved — a closed buffer discards
    the image (decision 1: no bytes without a transcript line). The chat path is
    re-read from the buffer at completion, so a `ParleySlug` or `ChatMove` that
    ran meanwhile is honoured. One paste per buffer at a time: a second `<M-v>`
    while one is in flight is refused with a message (see State and ordering).
11. **Every mover and every deleter is swept, not just the command** (`ARCH-PURPOSE`;
    memory: fix the class, not the site). Both movers call `assets.move_with`
    behind one shared conflict rule; one `M.delete_chat_file(path)` = folder +
    file replaces `helpers.delete_file` at all five chat-deletion sites, and an
    arch spec keeps it that way.
12. **Scope is `parley_buffer` but the feature needs a timestamp-named file.**
    In a markdown note without a timestamp basename the key declines with a
    message (there is no stable identity to key a folder on). Widening to notes
    is a separate decision (see Future extensions).
13. **Milestones and chunks.** M1 ends when an image pasted into a question
    reaches every wire and drops correctly out of the memory window (Tasks
    1–8). M2 carries the folder through move, delete and export, and lands the
    docs and the live conformance check (Tasks 9–12). Two boundaries, two
    reviews. Execution chunks are smaller than milestones: Chunk 1 = the pure
    modules (Tasks 1–3), Chunk 2 = the key (Task 4), Chunk 3 = send (Tasks
    5–8), Chunk 4 = M2 (Tasks 9–12).

## Non-goals

- Model-generated images (#239). This plan only makes `assets.save` caller-agnostic.
- Images in answer blocks are prose here (#239 makes them attachments).
- Resizing or re-encoding; the bytes on the clipboard are the bytes sent.
- Cross-chat asset references (a link to another chat's `assets/<ts>/`): they
  resolve while both chats share a directory and are not carried by a move.
- An orphan sweep (see Lifecycle): an asset whose link line the operator
  deletes stays until its chat is deleted.
- A `wire_googleai` for tool use.
- Windows clipboard; `clipboard_cmd` is the escape hatch.
- Dragging or `:read`-ing image files; paste from the clipboard only.
- `![](…)` inside fenced or inline code in the HTML export: the image
  tokenisation runs before the fence pass, so such a sample becomes a live
  `<img>` inside `<pre><code>` rather than literal text. Every other inline
  rule already reaches code bodies today; this one joins them. Accepted.
- Ollama agents: they ride `wire_openai` and would get `image_url` parts,
  which Ollama's native API does not take. An attachment on an ollama agent
  is not supported by this issue; the openai-compatible endpoint may accept it.
- Ancestor chats (tree-of-chat context): an ancestor's attachment reaches the
  model as its link text only — consistent with "images follow the window".

## Operating envelope (ARCH-CONSTRAINTS)

| Path | Workload | Budget | Basis | When exceeded |
|---|---|---|---|---|
| `<M-v>` → link inserted | UI response, one-shot | tool ≤ 5 s (`vim.system` timeout); osascript measured 60–70 ms; editor never blocks | measured / operator choice | "nothing pasted — exit 124: <tool> timed out"; temp file removed; nothing written |
| paste size | per image | ≤ 10 MB (`assets.MAX_BYTES`) | Anthropic per-image cap | refuse with the size and the limit; nothing written |
| `build_messages` with attachments | per request | one file read + base64 per attachment in the window; ≤ 10 MB each; no caching | domain-informed: window ≤ `chat_memory.max_full_exchanges` exchanges | oversized → note, not block; unreadable → note |
| request growth | per turn | each attached image re-sent while its exchange is in the window; 10 MB base64 ≈ 13 MB on the wire | operator decision (#231 spec) | drops with the exchange when summarized |
| move / delete / export | one-shot | one `os.rename` (or copy) per asset folder | existing tree walk | error names the folder; `.md` moves and 🌿 rewrites already done stay done |
| keystroke, redraw, parse | untouched | `parse_attachment` is one anchored `string.match` per question line, only inside a question | — | N/A |

N/A: memory beyond the base64 string held for one request; startup.

## Lifecycle (ARCH-FUNERAL)

`assets/<ts>/<stamp>.png` is a new durable family: created by the paste (and
by #239), needed for as long as a transcript line references it, removed by
whichever of the five deleters removes its chat (Task 9), moved by whichever
of the two movers moves its chat, copied by export. Bound: one file per paste,
≤ 10 MB each, never rewritten. **Residue named:** a link line the operator
deletes by hand, or a paste completing after its buffer was closed (prevented
in decision 10), leaves an asset nothing references, up to 10 MB per stray
paste, collected only when the chat is deleted. No sweep is planned (Non-goals);
if it ever matters, the sweep is "files in `assets/<ts>/` not named by any
`![](…)` line of `<ts>*.md`", and it lives in `assets`.

**Logs are a second residue** and are bounded here: the three sinks in Facts
receive `assets.elide_image_data(...)` — image bytes replaced by
`<image/png, N bytes>` — so `parley.log` and the raw-mode logs grow by a few
dozen bytes per image per turn, never by the image.

## Trust boundaries (ARCH-SECURE)

- **Transcript lines** (model-writable, hand-editable): `assets.parse_attachment`
  accepts only the closed grammar in decision 4; the path it yields is joined
  to the chat's own directory with string concatenation and read with
  `io.open`, never `vim.fn.expand`/`glob` (`untrusted_path_spec`).
- **Clipboard bytes** (external): written verbatim under the constructed folder
  with a name parley minted; the extension is fixed `png` (the recipes ask the
  clipboard for PNG); size capped before writing.
- **Tool stderr** (external): trimmed and shown in a notification; never
  executed or logged as a path.
- **`config.assets.clipboard_cmd`** (user config): an argv list; the `{out}`
  token is replaced as a whole argument, never interpolated into a shell
  string. The built-in Linux recipes use `sh -c '… > "$1"' sh <out>` so the
  path is an argument, not part of the script.
- **Destructive calls**: `delete_chat_file` removes `assets/<ts>` only for a
  path `assets.folder_for` constructed from the chat file being deleted (a
  non-timestamp name removes nothing); `vim.fn.delete(…, "rf")` does not follow
  symlinks. The operator consents to what the prompt names: all four
  single/tree prompts (`ChatDelete`, `md_delete_file`, the finder's two)
  append `assets.removal_note(path)` when a folder exists, and
  `delete_chat_tree` lists each folder. Export copies, never moves.
- **Logs**: image bytes never reach `parley.log` or the raw-mode logs
  (`elide_image_data` at all three sinks).
  Temp files come from `vim.fn.tempname()` (outside the repo) and are removed
  on every path.
- **HTML export**: `alt` and `src` are attribute-escaped (`"` → `&quot;`) on
  top of the existing `&<>` escaping.
- **Credentials**: none touched.
- **Tests**: no real clipboard is read (fixture recipe via config); the live
  check is opt-in (`PARLEY_LIVE_CLIPBOARD=1`) and restores the text it found.

## State and ordering (ARCH-ORDER)

`paste_image.paste` carries state between events: an in-flight marker per
buffer, an extmark anchor, a spawned process, a temp file.

| State | Event | Next / effects |
|---|---|---|
| idle | `<M-v>` on a non-chat buffer / no tool | idle; message; nothing spawned |
| idle | `<M-v>` | reading: mark `inflight[buf]`, anchor the cursor line, spawn |
| reading | second `<M-v>` on the same buffer | reading; message "a paste is already in progress" — **ignore** (a queue would land links in completion order, not key order) |
| reading | tool exits `ok` (file non-empty) | if buffer invalid → idle: temp removed, **nothing saved**, message; else save under the buffer's *current* name, insert after the anchor, idle |
| reading | tool exits `no_image` / `failed` / 124 | idle; temp removed; message with the tool's words |
| reading | buffer closed | stays reading until the tool answers, then the row above discards |
| reading | `ParleySlug` / `ChatMove` finishes first | the completion re-reads `nvim_buf_get_name(buf)`; the folder is keyed by timestamp so the link is right either way |
| reading | lines inserted/deleted above the anchor | the extmark follows; the link lands after the original line |
| reading | nvim dies | the temp file under the OS temp dir leaks (bounded by one paste); no asset written |
| any | Lua error inside the callback | idle: `inflight[buf]` cleared in a `pcall` wrapper, error notified |

The event most likely to be mishandled is the buffer closing before the tool
answers — the first draft saved the file before checking, which orphaned
bytes; the spec "discards the image when the buffer was closed" pins the fix.
Extent: nothing outlives a paste except the spawned tool until its timeout.
Nondeterminism enters only at IO completion; the fixture answers immediately,
and the "lines inserted above meanwhile" spec reproduces the anchor case by
editing between spawn and completion (the fake runner in unit tests can hold
its callback to reproduce any interleaving).

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
| `question_content` | `lua/parley/assets.lua` | new |
| `omitted_text` | `lua/parley/assets.lua` | new |
| `move_conflict` | `lua/parley/assets.lua` | new |
| `elide_image_data` | `lua/parley/assets.lua` | new |
| `select` | `lua/parley/clipboard_image.lua` | new |
| `argv_for` | `lua/parley/clipboard_image.lua` | new |
| `classify` | `lua/parley/clipboard_image.lua` | new |
| `host_env` | `lua/parley/clipboard_image.lua` | new |
| `parse_chat` | `lua/parley/chat_parser.lua` | modified (question gains `attachments`) |
| `build_messages` | `lua/parley/chat_respond.lua` | modified (`opts.chat_path`; attachment blocks; omitted note) |
| `build_messages_from_model` | `lua/parley/chat_respond.lua` | modified (attachments from block text) |
| `translate_messages` | `lua/parley/tools/wire_openai.lua` | modified (image blocks → `image_url` parts) |
| `googleai_parts` | `lua/parley/providers.lua` | new (local; block-aware parts mapping) |
| `simple_markdown_to_html` | `lua/parley/exporter.lua` | modified (`![alt](src)` → `<img>` via placeholder) |

- **`key_for`** — `chat_path → ts|nil`: the chat's asset key (timestamp
  prefix of the basename via `chat_slug.parse_filename`).
  - **Relationships:** 1:1 with a chat file; the folder, the link, the move
    and the delete all derive from it.
  - **DRY rationale:** one place answers "which folder is this chat's";
    #239, both movers, all deleters and export reuse it.
  - **Future extensions:** notes (non-timestamp basenames) would widen the key
    rule here and nowhere else.
- **`folder_for`** — `chat_path → abs folder|nil, err` =
  `<dir>/assets/<ts>`. **`folder_in`** — `(dir, ts) → abs folder`, the
  destination form the movers and export use. Both use a string `split`
  rather than `vim.fs.dirname`/`basename` so the layout half of the module is
  plain Lua; only `question_content` touches `vim.base64`.
- **`relative_path`** — `(ts, filename) → "assets/<ts>/<filename>"`;
  **`markdown_link`** — `rel → "![](rel)"`. Together the only link former.
- **`unique_name`** — `(stamp, ext, exists) → "<stamp>.<ext>"` or
  `"<stamp>-N.<ext>"` while `exists` says taken; pure via the predicate.
- **`media_type`** — extension → `image/png|jpeg|gif|webp` or nil.
- **`too_big`** — `n → "<n> bytes exceeds the <MAX>-byte limit"`: the one
  sentence paste-refusal and send-note both use.
- **`parse_attachment`** — one line → `{ path, ts, name, media_type }` or nil;
  the grammar of decision 4. **`attachments_in`** — text → list, one per
  matching line (used by the buffer-block path so both paths share the grammar).
- **`question_content`** — `(text, attachments, read) → string|blocks`: the
  internal Anthropic-shaped content for a preserved question; images first,
  then one text block; unreadable/oversized become notes in the text.
  `read(rel) → bytes|nil, err` is the injected IO.
  - **Relationships:** consumed by both `build_messages` paths; the wires
    translate its output.
  - **Future extensions:** #239 adds the same call for answer-side attachments
    on wires that accept model-role images.
- **`omitted_text`** — `(omit_user_text, attachments) → string`: the
  placeholder plus `OMITTED_NOTE` when an image was attached.
- **`move_conflict`** — `(chat_src, dst_dir, io_) → src, dst | nil`: the
  source folder (when it exists) and its destination, or `nil, err` when the
  destination already exists. The one rule the pre-check and `move_with` share.
- **`elide_image_data`** — any messages/payload table → a deep copy in which
  every image payload (`source.data` of an `image` block, `inlineData.data`, a
  `data:` `image_url.url`) is `"<mime, N bytes>"`. Applied at the three log
  sinks so a log line is never an image (`ARCH-FUNERAL`; one helper, three
  sinks — `ARCH-DRY`).
- **The M2 rows** (`removal_note` in Pure entities; `delete_chat_file` in
  Integration points) are **appended to these tables by Task 9, Step 1**, not
  listed here: `tests/arch/single_source_sweeps_spec.lua` "every symbol the
  plan tables name exists" is document-wide and would be red at the M1 gate
  for a name M2 creates. Until then the sibling rows below say "the one
  delete door" in prose. Likewise, within M1 the table is only fully green
  once Task 7 lands (`googleai_parts`, `image_url`) — expected, not a surprise.
- **`select`** — `(config_cmd, env) → recipe|nil, err`: config override, else
  first executable platform recipe; the error names what to install.
  **`argv_for`** — `(recipe, out_path) → argv` with `{out}` substituted.
  **`classify`** — `(code, stderr, size) → "ok"|"no_image"|"failed", message`
  (decision 9). **`host_env`** — the real `{ sysname, wayland, executable }`.
- **`googleai_parts`** — `content → parts[]`: string → `{{text}}`; blocks →
  `{text}` / `{inlineData={mimeType,data}}`. Local to `providers.lua`; the
  merge loop appends whole lists.

### Integration points

| Name | Lives in | Status | Wraps |
|------|----------|--------|-------|
| `default_io` | `lua/parley/assets.lua` | new | filesystem (`io.open`, `vim.fn.mkdir`, `os.rename`, `vim.fn.delete`, `vim.fn.readdir`) |
| `save` | `lua/parley/assets.lua` | new | `default_io` |
| `read` | `lua/parley/assets.lua` | new | `default_io` |
| `move_with` | `lua/parley/assets.lua` | new | `default_io` |
| `delete_with` | `lua/parley/assets.lua` | new | `default_io` |
| `copy_into` | `lua/parley/assets.lua` | new | `default_io` |
| `read_png` | `lua/parley/clipboard_image.lua` | new | `vim.system` (the clipboard tool) |
| `paste` | `lua/parley/paste_image.lua` | new | buffer, current window's cursor, notify |
| `paste_image` | `lua/parley/init.lua` | new | `paste_image.paste` with real deps |
| `move_chat` | `lua/parley/init.lua` | modified | `assets.move_conflict` / `move_with` |
| `move_chat_tree` | `lua/parley/init.lua` | modified | `assets.move_conflict` / `move_with` |
| `delete_chat_tree` | `lua/parley/init.lua` | modified | the one delete door (Task 9); confirmation lists folders |
| `handle_delete_response` | `lua/parley/chat_finder.lua` | modified | the one delete door (Task 9) |
| `handle_delete_tree_response` | `lua/parley/chat_finder.lua` | modified | the one delete door (Task 9) |
| `export_tree` | `lua/parley/exporter.lua` | modified | `assets.copy_into` |
| `fake_clipboard` | `tests/fixtures/fake_clipboard` | new | stands in for `osascript` |

- **`default_io`** — `{ exists, mkdir, write, read, rename, remove_tree, list, now }`.
  Every `assets` IO function takes an optional `io_` and defaults to it.
  - **Injected into:** `save`, `read`, `move_with`, `delete_with`, `copy_into`,
    `move_conflict`; unit tests pass an in-memory table.
- **`save`** — `(chat_path, bytes, ext, io_) → rel, abs | nil, nil, err`. The
  writer. Refuses over `MAX_BYTES` with `too_big`; creates the folder; mints a
  unique name.
- **`read`** — `(chat_path, rel, io_) → bytes|nil, err`.
- **`move_with`** — `(chat_src, chat_dst, io_) → ok, err`: renames the
  folder `move_conflict` names. **`delete_with`** — removes
  `folder_for(chat_path)` when it exists. **`copy_into`** —
  `(chat_path, export_dir, io_) → n`: copies the folder's files to
  `export_dir/assets/<ts>/`.
- **`read_png`** — `(recipe, out_path, on_done, runner)`: spawns the recipe,
  stats the file with `uv.fs_stat`, classifies, schedules `on_done(status, msg)`.
  `runner(argv, on_complete(code, stderr))` defaults to `vim.system` with a 5 s
  timeout; tests inject a fake or use the fixture recipe.
- **`paste`** — `(buf, deps)` with `deps = { config, notify, runner? }`: the
  flow of decision 10 and the ordering table. The cursor row is read from the
  **current window**, which must be showing `buf` (true for the key; a caller
  with another window active gets the wrong row — documented, not guarded).
- **The one delete door** (Task 9 adds its row) — `(path)`:
  `assets.delete_with(path)` then `helpers.delete_file(path)`; the only
  permitted deleter of a chat path (`tests/arch/chat_delete_sweep_spec.lua`).
- **`fake_clipboard`** — Python 3; models **osascript** (says so in its
  docstring): `PARLEY_FAKE_CLIPBOARD=png:<file>` copies that file to
  `argv[1]` and exits 0; `text` creates an empty `argv[1]`, prints the measured
  osascript sentence to stderr and exits 1; `broken` exits 2 with `boom`;
  `slow` sleeps `PARLEY_FAKE_CLIPBOARD_DELAY_MS` first (default 300) then acts
  as `png:`; every call appends one line to `$PARLEY_FAKE_CLIPBOARD_LOG` when
  set, so a spec can count reads.

## Test surface (ARCH-MOCK)

| Dependency | Seam | Fake | Live check |
|---|---|---|---|
| clipboard tool (`osascript` / `wl-paste` / `xclip`) | recipe argv → `read_png(runner)`; `config.assets.clipboard_cmd` | `tests/fixtures/fake_clipboard` through the config seam (integration); a Lua fake runner (unit) | `tests/integration/clipboard_live_spec.lua`, opt-in `PARLEY_LIVE_CLIPBOARD=1`, darwin only: saves the clipboard text, puts a 1×1 PNG on it via osascript, reads it back through the real recipe, restores the text |
| filesystem | `assets.default_io` | in-memory `io_` table (unit); real `$TMPDIR` dirs (integration) | — |
| provider wires | `dispatcher.prepare_payload` | none needed: payload assertions are pure | the three shapes were read from the provider docs on 2026-09-12; re-read at implementation if the docs moved |

## Running tests

- One spec: `nvim -n --headless --noplugin -u tests/minimal_init.vim -c "PlenaryBustedFile tests/unit/assets_spec.lua" -c "qa!"`
- By atlas key (after Task 8): `make test-spec SPEC=chat/attachments`
- Full: `make test` (runs the arch guards; `make lint` first).

---

## Chunk 1: the pure modules — assets, clipboard (M1, Tasks 1–3)

### Task 1: `assets` — layout, grammar, content blocks (pure)

**Files:**
- Create: `lua/parley/assets.lua`
- Test: `tests/unit/assets_spec.lua`

- [ ] **Step 1: Write the failing tests**

```lua
-- tests/unit/assets_spec.lua
local assets = require("parley.assets")

local CHAT = "/roots/chats/2026-09-10.14-20-03.112_ui-bug.md"
local TS = "2026-09-10.14-20-03.112"

describe("assets: layout", function()
    it("keys a chat by its timestamp, never its slug", function()
        assert.equals(TS, assets.key_for(CHAT))
        assert.equals(TS, assets.key_for("/roots/chats/" .. TS .. ".md"))
        assert.is_nil(assets.key_for("/roots/notes/todo.md"))
    end)

    it("folder_for is <dir>/assets/<ts>", function()
        assert.equals("/roots/chats/assets/" .. TS, assets.folder_for(CHAT))
        local folder, err = assets.folder_for("/roots/notes/todo.md")
        assert.is_nil(folder)
        assert.matches("not a timestamp%-named chat", err)
    end)

    it("folder_in composes the destination form", function()
        assert.equals("/elsewhere/assets/" .. TS, assets.folder_in("/elsewhere", TS))
    end)

    it("relative_path and markdown_link form the one link shape", function()
        local rel = assets.relative_path(TS, "2026-09-10.14-22-31.487.png")
        assert.equals("assets/" .. TS .. "/2026-09-10.14-22-31.487.png", rel)
        assert.equals("![](" .. rel .. ")", assets.markdown_link(rel))
    end)

    it("unique_name suffixes -N while the name is taken", function()
        local taken = { ["s.png"] = true, ["s-2.png"] = true }
        local exists = function(n) return taken[n] == true end
        assert.equals("s-3.png", assets.unique_name("s", "png", exists))
        assert.equals("t.png", assets.unique_name("t", "png", exists))
    end)

    it("media_type knows the four wire-accepted formats", function()
        assert.equals("image/png", assets.media_type("a.png"))
        assert.equals("image/jpeg", assets.media_type("a.JPG"))
        assert.equals("image/jpeg", assets.media_type("a.jpeg"))
        assert.equals("image/gif", assets.media_type("a.gif"))
        assert.equals("image/webp", assets.media_type("a.webp"))
        assert.is_nil(assets.media_type("a.svg"))
        assert.is_nil(assets.media_type("a"))
    end)

    it("too_big is the one size sentence", function()
        assert.equals((assets.MAX_BYTES + 1) .. " bytes exceeds the " .. assets.MAX_BYTES .. "-byte limit",
            assets.too_big(assets.MAX_BYTES + 1))
    end)
end)

describe("assets: attachment grammar", function()
    local ok_line = "![](assets/" .. TS .. "/2026-09-10.14-22-31.487.png)"

    it("accepts exactly a relative assets link on its own line", function()
        local att = assets.parse_attachment(ok_line)
        assert.same({
            path = "assets/" .. TS .. "/2026-09-10.14-22-31.487.png",
            ts = TS,
            name = "2026-09-10.14-22-31.487.png",
            media_type = "image/png",
        }, att)
        assert.is_not_nil(assets.parse_attachment("  " .. ok_line .. "  "))
        assert.is_not_nil(assets.parse_attachment("![a screenshot](assets/" .. TS .. "/x.png)"))
    end)

    it("rejects everything that is not the grammar", function()
        local rejected = {
            "![](/abs/assets/" .. TS .. "/x.png)",           -- absolute
            "![](assets/../" .. TS .. "/x.png)",             -- traversal in ts
            "![](assets/" .. TS .. "/../x.png)",             -- traversal in name
            "![](assets/" .. TS .. "/x.svg)",                -- unsupported type
            "![](assets/" .. TS .. "/`id`.png)",             -- backtick
            "![](assets/notatimestamp/x.png)",               -- ts not a timestamp
            "![](https://example.com/x.png)",                -- URL
            "see ![](assets/" .. TS .. "/x.png) here",       -- not alone on the line
            "[](assets/" .. TS .. "/x.png)",                 -- not an image link
            "![](images/" .. TS .. "/x.png)",                -- wrong folder
            "![](assets/" .. TS .. "/.hidden.png)",          -- dotfile
        }
        for _, line in ipairs(rejected) do
            assert.is_nil(assets.parse_attachment(line), line)
        end
    end)

    it("attachments_in lists one per matching line", function()
        local text = "look:\n" .. ok_line .. "\nand\n![](assets/" .. TS .. "/b.gif)\nprose ![](assets/" .. TS .. "/c.png) prose"
        local list = assets.attachments_in(text)
        assert.equals(2, #list)
        assert.equals("image/png", list[1].media_type)
        assert.equals("image/gif", list[2].media_type)
    end)
end)

describe("assets: question content", function()
    local atts = {
        { path = "assets/" .. TS .. "/a.png", media_type = "image/png" },
        { path = "assets/" .. TS .. "/b.gif", media_type = "image/gif" },
    }

    it("returns the text unchanged with no attachments", function()
        assert.equals("hi", assets.question_content("hi", {}, function() error("no read") end))
        assert.equals("hi", assets.question_content("hi", nil, function() error("no read") end))
    end)

    it("puts images first, base64-encoded, then one text block", function()
        local files = { ["assets/" .. TS .. "/a.png"] = "PNGBYTES", ["assets/" .. TS .. "/b.gif"] = "GIFBYTES" }
        local content = assets.question_content("what is this?", atts, function(rel) return files[rel] end)
        assert.equals(3, #content)
        assert.same({ type = "image", source = { type = "base64", media_type = "image/png", data = vim.base64.encode("PNGBYTES") } }, content[1])
        assert.same({ type = "image", source = { type = "base64", media_type = "image/gif", data = vim.base64.encode("GIFBYTES") } }, content[2])
        assert.same({ type = "text", text = "what is this?" }, content[3])
    end)

    it("replaces an unreadable file with a note and never a block", function()
        local content = assets.question_content("q", { atts[1] }, function() return nil, "ENOENT" end)
        assert.equals("string", type(content))
        assert.equals("[attachment assets/" .. TS .. "/a.png could not be read: ENOENT]\nq", content)
    end)

    it("replaces an oversized file with the one size sentence", function()
        local big = string.rep("x", assets.MAX_BYTES + 1)
        local content = assets.question_content("q", { atts[1] }, function() return big end)
        assert.equals("[attachment assets/" .. TS .. "/a.png not sent: " .. assets.too_big(assets.MAX_BYTES + 1) .. "]\nq", content)
    end)

    it("keeps readable images when a sibling failed", function()
        local content = assets.question_content("q", atts, function(rel)
            if rel:match("a%.png$") then return "A" end
            return nil, "gone"
        end)
        assert.equals(2, #content)
        assert.equals("image", content[1].type)
        assert.equals("[attachment assets/" .. TS .. "/b.gif could not be read: gone]\nq", content[2].text)
    end)

    it("omitted_text appends the note only when an image was attached", function()
        assert.equals("[omitted]", assets.omitted_text("[omitted]", {}))
        assert.equals("[omitted]\n" .. assets.OMITTED_NOTE, assets.omitted_text("[omitted]", atts))
    end)
end)
```

- [ ] **Step 2: Run to verify it fails**

Run: `nvim -n --headless --noplugin -u tests/minimal_init.vim -c "PlenaryBustedFile tests/unit/assets_spec.lua" -c "qa!"`
Expected: FAIL — `module 'parley.assets' not found`.

- [ ] **Step 3: Write the module**

```lua
-- lua/parley/assets.lua
--
-- Chat assets: the per-chat sidecar folder for what markdown cannot hold.
--
-- The transcript is the index; this folder holds only bytes that a transcript
-- line references. It is keyed by the chat's TIMESTAMP, never its slug, so a
-- ParleySlug rename or a ChatMove never orphans it (#231; the #224 lesson —
-- the timestamp is the identity, the slug is decoration). Layout:
--
--   <chat-dir>/assets/<chat-timestamp>/<asset-timestamp>.<ext>
--
-- referenced from the chat as `![](assets/<chat-timestamp>/<file>)`.
--
-- Everything above `default_io` is PURE (the layout half is plain Lua string
-- work; only question_content touches vim.base64). The IO functions (save/
-- read/move/delete/copy) take an injectable `io_` so the clipboard flow, #239's
-- model-generated images, both chat movers, every chat deleter and export
-- share ONE writer, and tests run against an in-memory table (ARCH-DRY,
-- ARCH-MOCK).

local chat_slug = require("parley.chat_slug")

local M = {}

M.DIR = "assets"

-- Anthropic's per-image cap (10 MB base64) is the strictest of the three
-- wires; one constant and one sentence govern paste (refuse) and send (note).
M.MAX_BYTES = 10 * 1024 * 1024

M.OMITTED_NOTE = "[An image was attached to this question; it is no longer included.]"

local MEDIA_TYPES = {
    png = "image/png",
    jpg = "image/jpeg",
    jpeg = "image/jpeg",
    gif = "image/gif",
    webp = "image/webp",
}

--- Split an absolute path into directory and basename (string ops only).
local function split(path)
    local dir, base = tostring(path):match("^(.*)/([^/]+)$")
    if not dir then
        return nil, tostring(path)
    end
    return dir, base
end

--- The chat's asset key: its timestamp prefix. nil for a file that is not a
--- timestamp-named chat — a plain note has no stable identity to key on.
--- @param chat_path string
--- @return string|nil ts
function M.key_for(chat_path)
    local _, base = split(chat_path)
    local ts = chat_slug.parse_filename(base)
    return ts
end

--- Absolute asset folder for a chat, or nil + reason.
--- @param chat_path string
--- @return string|nil folder, string|nil err
function M.folder_for(chat_path)
    local dir = split(chat_path)
    local ts = M.key_for(chat_path)
    if not dir or not ts then
        return nil, "not a timestamp-named chat: " .. tostring(chat_path)
    end
    return M.folder_in(dir, ts)
end

--- The folder for key `ts` inside `dir` — the destination form.
function M.folder_in(dir, ts)
    return dir .. "/" .. M.DIR .. "/" .. ts
end

--- Link target relative to the chat file.
function M.relative_path(ts, filename)
    return M.DIR .. "/" .. ts .. "/" .. filename
end

function M.markdown_link(relative)
    return "![](" .. relative .. ")"
end

--- `<stamp>.<ext>`, then `<stamp>-2.<ext>`, … while `exists(name)` is true.
--- Two pastes in one millisecond therefore never collide.
function M.unique_name(stamp, ext, exists)
    local name = stamp .. "." .. ext
    local n = 1
    while exists(name) do
        n = n + 1
        name = stamp .. "-" .. n .. "." .. ext
    end
    return name
end

--- Media type by extension; nil when no wire would accept it.
function M.media_type(path)
    local ext = tostring(path):match("%.(%w+)$")
    return ext and MEDIA_TYPES[ext:lower()] or nil
end

--- The one size sentence, for paste refusals and send notes alike.
function M.too_big(n)
    return ("%d bytes exceeds the %d-byte limit"):format(n, M.MAX_BYTES)
end

-- The attachment grammar (ARCH-SECURE — the transcript is model-writable):
-- a line that is exactly `![…](assets/<ts>/<name>)`, blanks allowed either
-- side, where <ts> parses as a chat timestamp and <name> is
-- [A-Za-z0-9][A-Za-z0-9._-]* with an accepted image extension. Anything else
-- — absolute, `..`, URL, backtick, inline in prose — is prose, never read.
local LINK = "^%s*!%[[^%]]*%]%((" .. M.DIR .. "/([^/%)%s]+)/([^/%)%s]+))%)%s*$"

--- @param line string
--- @return table|nil { path, ts, name, media_type }
function M.parse_attachment(line)
    local rel, ts, name = tostring(line):match(LINK)
    if not rel then
        return nil
    end
    if chat_slug.parse_filename(ts) ~= ts then
        return nil
    end
    if not name:match("^[A-Za-z0-9][A-Za-z0-9._%-]*$") or name:find("..", 1, true) then
        return nil
    end
    local media_type = M.media_type(name)
    if not media_type then
        return nil
    end
    return { path = rel, ts = ts, name = name, media_type = media_type }
end

--- Every attachment line in a block of text, in order. The buffer-block
--- rebuild path uses this; the parser applies parse_attachment per line —
--- one grammar, two callers.
function M.attachments_in(text)
    local out = {}
    for line in (tostring(text) .. "\n"):gmatch("([^\n]*)\n") do
        local att = M.parse_attachment(line)
        if att then
            out[#out + 1] = att
        end
    end
    return out
end

--- Internal (Anthropic-shaped) content for a preserved question: image blocks
--- first, one text block last. A file that cannot be read or exceeds
--- MAX_BYTES becomes a one-line note at the top of the text — visible to the
--- model and in the log — never a dangling block.
--- @param text string
--- @param attachments table[]|nil  { path, media_type }
--- @param read fun(rel: string): string|nil, string|nil
--- @return string|table content
function M.question_content(text, attachments, read)
    if not attachments or #attachments == 0 then
        return text
    end
    local blocks, notes = {}, {}
    for _, att in ipairs(attachments) do
        local bytes, err = read(att.path)
        if not bytes then
            notes[#notes + 1] = "[attachment " .. att.path .. " could not be read: " .. tostring(err) .. "]"
        elseif #bytes > M.MAX_BYTES then
            notes[#notes + 1] = "[attachment " .. att.path .. " not sent: " .. M.too_big(#bytes) .. "]"
        else
            blocks[#blocks + 1] = {
                type = "image",
                source = { type = "base64", media_type = att.media_type, data = vim.base64.encode(bytes) },
            }
        end
    end
    local body = text
    if #notes > 0 then
        body = table.concat(notes, "\n") .. "\n" .. text
    end
    if #blocks == 0 then
        return body
    end
    blocks[#blocks + 1] = { type = "text", text = body }
    return blocks
end

--- The memory-window placeholder for a summarized question, plus the note
--- when an image was attached (so the model is not left inferring it).
function M.omitted_text(omit_user_text, attachments)
    if attachments and #attachments > 0 then
        return omit_user_text .. "\n" .. M.OMITTED_NOTE
    end
    return omit_user_text
end

return M
```

- [ ] **Step 4: Run to verify it passes**

Run the Step 2 command. Expected: all `assets:` specs PASS.

- [ ] **Step 5: Commit**

```bash
git add lua/parley/assets.lua tests/unit/assets_spec.lua
git commit -m "#231 M1: assets — sidecar layout, attachment grammar, question content

The transcript is the index; assets/<chat-timestamp>/ holds only bytes a
transcript line references. Keyed by timestamp, never slug (#224). One
grammar, one link former, one content builder — #239 reuses all three.

Co-Authored-By: Claude Fable 5.1 <noreply@anthropic.com>"
```

### Task 2: `assets` — the IO shell (save / read / move / delete / copy)

**Files:**
- Modify: `lua/parley/assets.lua` (append before `return M`)
- Test: `tests/unit/assets_spec.lua` (append)

- [ ] **Step 1: Write the failing tests** (an in-memory `io_`)

```lua
-- append to tests/unit/assets_spec.lua
local function fake_io(files, dirs)
    files = files or {}
    dirs = dirs or {}
    local io_ = { files = files, dirs = dirs, removed = {}, clock = 0 }
    io_.exists = function(p) return files[p] ~= nil or dirs[p] == true end
    io_.mkdir = function(p) dirs[p] = true return true end
    io_.write = function(p, bytes) files[p] = bytes return true end
    io_.read = function(p) if files[p] == nil then return nil, "ENOENT" end return files[p] end
    io_.rename = function(a, b)
        if dirs[a] then dirs[a] = nil dirs[b] = true end
        for p, v in pairs(files) do
            if p:sub(1, #a + 1) == a .. "/" then files[b .. p:sub(#a + 1)] = v files[p] = nil end
        end
        return true
    end
    io_.remove_tree = function(p)
        io_.removed[#io_.removed + 1] = p
        dirs[p] = nil
        for f in pairs(files) do if f:sub(1, #p + 1) == p .. "/" then files[f] = nil end end
        return true
    end
    io_.list = function(p)
        local out = {}
        for f in pairs(files) do
            if f:sub(1, #p + 1) == p .. "/" and not f:sub(#p + 2):find("/", 1, true) then out[#out + 1] = f:sub(#p + 2) end
        end
        table.sort(out)
        return out
    end
    io_.now = function() io_.clock = io_.clock + 1 return "2026-09-12.10-00-00.00" .. io_.clock end
    return io_
end

describe("assets: save and read", function()
    it("creates the folder, mints a unique name, writes, and returns the link", function()
        local io_ = fake_io()
        local rel, abs = assets.save(CHAT, "PNG", "png", io_)
        assert.equals("assets/" .. TS .. "/2026-09-12.10-00-00.001.png", rel)
        assert.equals("/roots/chats/assets/" .. TS .. "/2026-09-12.10-00-00.001.png", abs)
        assert.is_true(io_.dirs["/roots/chats/assets/" .. TS])
        assert.equals("PNG", io_.files[abs])
        assert.equals("PNG", assets.read(CHAT, rel, io_))
    end)

    it("two saves in the same millisecond do not collide", function()
        local io_ = fake_io()
        io_.now = function() return "same" end
        local a = assets.save(CHAT, "1", "png", io_)
        local b = assets.save(CHAT, "2", "png", io_)
        assert.equals("assets/" .. TS .. "/same.png", a)
        assert.equals("assets/" .. TS .. "/same-2.png", b)
    end)

    it("refuses a non-chat path and an oversized image, writing nothing", function()
        local io_ = fake_io()
        local rel, _, err = assets.save("/roots/notes/todo.md", "x", "png", io_)
        assert.is_nil(rel)
        assert.matches("not a timestamp%-named chat", err)
        rel, _, err = assets.save(CHAT, string.rep("x", assets.MAX_BYTES + 1), "png", io_)
        assert.is_nil(rel)
        assert.equals(assets.too_big(assets.MAX_BYTES + 1), err)
        assert.same({}, io_.files)
        assert.same({}, io_.dirs, "no folder is created for a refused save")
    end)

    it("read reports a missing file, never raises", function()
        local bytes, err = assets.read(CHAT, "assets/" .. TS .. "/nope.png", fake_io())
        assert.is_nil(bytes)
        assert.equals("ENOENT", err)
    end)
end)

describe("assets: move, delete, copy", function()
    local folder = "/roots/chats/assets/" .. TS
    local function seeded()
        return fake_io({ [folder .. "/a.png"] = "A", [folder .. "/b.png"] = "B" }, { [folder] = true })
    end

    it("move_conflict names source and destination, or the clash", function()
        local io_ = seeded()
        local src, dst = assets.move_conflict(CHAT, "/other/root", io_)
        assert.equals(folder, src)
        assert.equals("/other/root/assets/" .. TS, dst)
        io_.dirs["/other/root/assets/" .. TS] = true
        local s, err = assets.move_conflict(CHAT, "/other/root", io_)
        assert.is_nil(s)
        assert.matches("asset folder already exists", err)
        assert.is_nil(assets.move_conflict(CHAT, "/other/root", fake_io()), "no folder → nothing to move")
    end)

    it("move_with renames the folder next to the moved chat", function()
        local io_ = seeded()
        local ok, err = assets.move_with(CHAT, "/other/root/" .. TS .. "_ui-bug.md", io_)
        assert.is_true(ok, err)
        assert.is_nil(io_.dirs[folder])
        assert.is_true(io_.dirs["/other/root/assets/" .. TS])
        assert.equals("A", io_.files["/other/root/assets/" .. TS .. "/a.png"])
        assert.is_true(io_.dirs["/other/root/assets"], "parent assets/ is created first")
    end)

    it("move_with is a no-op when the chat has no folder", function()
        local io_ = fake_io()
        assert.is_true(assets.move_with(CHAT, "/other/root/" .. TS .. ".md", io_))
        assert.same({}, io_.dirs)
    end)

    it("move_with refuses when the destination folder exists", function()
        local io_ = seeded()
        io_.dirs["/other/root/assets/" .. TS] = true
        local ok, err = assets.move_with(CHAT, "/other/root/" .. TS .. ".md", io_)
        assert.is_nil(ok)
        assert.matches("already exists", err)
        assert.is_true(io_.dirs[folder], "source untouched")
    end)

    it("delete_with removes exactly the constructed folder", function()
        local io_ = seeded()
        assets.delete_with(CHAT, io_)
        assert.same({ folder }, io_.removed)
        assets.delete_with("/roots/notes/todo.md", io_)
        assert.same({ folder }, io_.removed, "a non-chat path removes nothing")
    end)

    it("copy_into duplicates the folder's files under export_dir/assets/<ts>", function()
        local io_ = seeded()
        local n = assets.copy_into(CHAT, "/export", io_)
        assert.equals(2, n)
        assert.equals("A", io_.files["/export/assets/" .. TS .. "/a.png"])
        assert.equals("B", io_.files["/export/assets/" .. TS .. "/b.png"])
        assert.equals("A", io_.files[folder .. "/a.png"], "source kept")
        assert.equals(0, assets.copy_into("/roots/chats/2026-01-01.00-00-00.000.md", "/export", io_))
    end)
end)
```

- [ ] **Step 2: Run to verify it fails**

Expected: FAIL — `attempt to call field 'save' (a nil value)`.

- [ ] **Step 3: Append the IO shell**

```lua
-- append to lua/parley/assets.lua, before `return M`

--------------------------------------------------------------------------------
-- IO shell. Every function below takes `io_` (defaults to default_io) so the
-- clipboard flow, #239, both movers, every deleter and export share one
-- writer and the unit tests run on an in-memory table.
-- MAIN LOOP ONLY: default_io uses vim.fn, which a libuv callback refuses;
-- clipboard_image.read_png schedules its on_done before any of this runs.
--------------------------------------------------------------------------------

M.default_io = {
    exists = function(p)
        return vim.fn.filereadable(p) == 1 or vim.fn.isdirectory(p) == 1
    end,
    mkdir = function(p)
        -- "p": create parents; an existing directory is not an error.
        return vim.fn.mkdir(p, "p") == 1
    end,
    write = function(p, bytes)
        local f, err = io.open(p, "wb")
        if not f then
            return false, err
        end
        f:write(bytes)
        f:close()
        return true
    end,
    read = function(p)
        local f, err = io.open(p, "rb")
        if not f then
            return nil, err
        end
        local data = f:read("*a")
        f:close()
        return data
    end,
    rename = function(a, b)
        return os.rename(a, b)
    end,
    -- Destructive: callers pass only a path folder_for constructed.
    -- vim.fn.delete(…, "rf") does not follow symlinks.
    remove_tree = function(p)
        return vim.fn.delete(p, "rf") == 0
    end,
    list = function(p)
        local out = {}
        for _, name in ipairs(vim.fn.readdir(p) or {}) do
            if vim.fn.filereadable(p .. "/" .. name) == 1 then
                out[#out + 1] = name
            end
        end
        table.sort(out)
        return out
    end,
    now = function()
        return require("parley.logger").now()
    end,
}

--- THE writer. Saves `bytes` as a new asset of `chat_path` and returns the
--- link target relative to the chat file plus the absolute path.
--- @param chat_path string
--- @param bytes string
--- @param ext string  e.g. "png"
--- @param io_ table|nil
--- @return string|nil rel, string|nil abs, string|nil err
function M.save(chat_path, bytes, ext, io_)
    io_ = io_ or M.default_io
    local folder, err = M.folder_for(chat_path)
    if not folder then
        return nil, nil, err
    end
    if #bytes > M.MAX_BYTES then
        return nil, nil, M.too_big(#bytes)
    end
    if not io_.mkdir(folder) then
        return nil, nil, "could not create " .. folder
    end
    local name = M.unique_name(io_.now(), ext, function(n)
        return io_.exists(folder .. "/" .. n)
    end)
    local abs = folder .. "/" .. name
    local ok, werr = io_.write(abs, bytes)
    if not ok then
        return nil, nil, "could not write " .. abs .. ": " .. tostring(werr)
    end
    return M.relative_path(M.key_for(chat_path), name), abs
end

--- Bytes of an asset named by its transcript-relative path.
function M.read(chat_path, relative, io_)
    io_ = io_ or M.default_io
    local dir = split(chat_path)
    if not dir then
        return nil, "chat path has no directory: " .. tostring(chat_path)
    end
    return io_.read(dir .. "/" .. relative)
end

--- The one move rule: the chat's folder (when it exists) and where it goes
--- under `dst_dir`, or nil + err when the destination is taken. nil alone
--- means there is nothing to move.
--- @return string|nil src, string|nil dst_or_err
function M.move_conflict(chat_src, dst_dir, io_)
    io_ = io_ or M.default_io
    local src = M.folder_for(chat_src)
    if not src or not io_.exists(src) then
        return nil
    end
    local dst = M.folder_in(dst_dir, M.key_for(chat_src))
    if io_.exists(dst) then
        return nil, "asset folder already exists: " .. dst
    end
    return src, dst
end

--- Carry the folder when its chat moves. No folder → ok, nothing to do.
--- @return boolean|nil ok, string|nil err
function M.move_with(chat_src, chat_dst, io_)
    io_ = io_ or M.default_io
    local dst_dir = split(chat_dst)
    local src, dst = M.move_conflict(chat_src, dst_dir, io_)
    if not src then
        if dst then
            return nil, dst -- the clash message
        end
        return true
    end
    if not io_.mkdir(dst_dir .. "/" .. M.DIR) then
        return nil, "could not create " .. dst_dir .. "/" .. M.DIR
    end
    local ok, err = io_.rename(src, dst)
    if not ok then
        return nil, "could not move " .. src .. ": " .. tostring(err)
    end
    return true
end

--- Remove the folder with its chat. Only a path folder_for constructed from
--- a chat the caller is already deleting; a non-chat path removes nothing.
function M.delete_with(chat_path, io_)
    io_ = io_ or M.default_io
    local folder = M.folder_for(chat_path)
    if folder and io_.exists(folder) then
        io_.remove_tree(folder)
    end
end

--- Copy the folder's files to `<export_dir>/assets/<ts>/` so exported links
--- keep resolving. Returns the number of files copied.
function M.copy_into(chat_path, export_dir, io_)
    io_ = io_ or M.default_io
    local folder = M.folder_for(chat_path)
    if not folder or not io_.exists(folder) then
        return 0
    end
    local dst = M.folder_in(export_dir, M.key_for(chat_path))
    io_.mkdir(dst)
    local n = 0
    for _, name in ipairs(io_.list(folder)) do
        local bytes = io_.read(folder .. "/" .. name)
        if bytes then
            io_.write(dst .. "/" .. name, bytes)
            n = n + 1
        end
    end
    return n
end
```

- [ ] **Step 4: Run to verify it passes** — the Step 2 command; all PASS.

- [ ] **Step 5: Commit**

```bash
git add lua/parley/assets.lua tests/unit/assets_spec.lua
git commit -m "#231 M1: assets — save/read/move/delete/copy behind one injectable io

Co-Authored-By: Claude Fable 5.1 <noreply@anthropic.com>"
```

### Task 3: `clipboard_image` — recipes, selection, classification, the spawn seam

**Files:**
- Create: `lua/parley/clipboard_image.lua`
- Test: `tests/unit/clipboard_image_spec.lua`

- [ ] **Step 1: Write the failing tests**

```lua
-- tests/unit/clipboard_image_spec.lua
local ci = require("parley.clipboard_image")

local function env(sysname, wayland, tools)
    return {
        sysname = sysname,
        wayland = wayland,
        executable = function(t) return tools[t] == true end,
    }
end

describe("clipboard_image: select", function()
    it("macOS uses osascript", function()
        local r = ci.select(nil, env("Darwin", false, { osascript = true }))
        assert.equals("osascript", r.tool)
    end)

    it("Wayland prefers wl-paste, falls back to xclip", function()
        assert.equals("wl-paste", ci.select(nil, env("Linux", true, { ["wl-paste"] = true, xclip = true })).tool)
        assert.equals("xclip", ci.select(nil, env("Linux", true, { xclip = true })).tool)
    end)

    it("X11 prefers xclip, falls back to wl-paste", function()
        assert.equals("xclip", ci.select(nil, env("Linux", false, { ["wl-paste"] = true, xclip = true })).tool)
        assert.equals("wl-paste", ci.select(nil, env("Linux", false, { ["wl-paste"] = true })).tool)
    end)

    it("names what to install when nothing is executable", function()
        local r, err = ci.select(nil, env("Linux", false, {}))
        assert.is_nil(r)
        assert.matches("no clipboard image tool found", err)
        assert.matches("xclip", err)
        assert.matches("wl%-clipboard", err)
    end)

    it("a configured argv wins and is used verbatim", function()
        local r = ci.select({ "/x/fake", "{out}" }, env("Darwin", false, { osascript = true }))
        assert.equals("/x/fake", r.tool)
        assert.same({ "/x/fake", "{out}" }, r.argv)
    end)

    it("a configured argv must contain {out}", function()
        local r, err = ci.select({ "/x/fake" }, env("Darwin", false, {}))
        assert.is_nil(r)
        assert.matches("{out}", err)
    end)
end)

describe("clipboard_image: argv_for", function()
    it("substitutes {out} as a whole argument, once, anywhere", function()
        local r = { tool = "t", argv = { "t", "--to", "{out}", "{out}x" } }
        assert.same({ "t", "--to", "/p/a.png", "{out}x" }, ci.argv_for(r, "/p/a.png"))
    end)

    it("the darwin recipe passes the path as argv, not inside the script", function()
        local argv = ci.argv_for(ci.RECIPES.darwin, "/p/a b.png")
        assert.equals("/p/a b.png", argv[#argv])
        for i = 1, #argv - 1 do
            assert.is_nil(argv[i]:find("/p/a b.png", 1, true))
        end
    end)
end)

describe("clipboard_image: classify", function()
    it("exit 0 with bytes is ok", function()
        assert.equals("ok", ci.classify(0, "", 1234))
    end)
    it("exit 0 with an empty or missing file is no_image", function()
        local s, msg = ci.classify(0, "", 0)
        assert.equals("no_image", s)
        assert.matches("no image", msg)
        assert.equals("no_image", ci.classify(0, "", nil))
    end)
    it("exit 1 is no_image and carries the tool's words", function()
        local s, msg = ci.classify(1, "207:208: execution error: Can’t make some data into the expected type. (-2700)\n", 0)
        assert.equals("no_image", s)
        assert.matches("expected type", msg)
    end)
    it("any other exit is failed with stderr — a timeout included", function()
        local s, msg = ci.classify(2, "boom\n", nil)
        assert.equals("failed", s)
        assert.equals("exit 2: boom", msg)
        s, msg = ci.classify(124, "osascript timed out after 5000 ms", nil)
        assert.equals("failed", s)
        assert.matches("timed out", msg)
    end)
end)

describe("clipboard_image: read_png", function()
    it("runs the recipe argv and classifies on the scheduled callback", function()
        local out = vim.fn.tempname() .. ".png"
        local seen_argv
        local runner = function(argv, on_complete)
            seen_argv = argv
            local f = assert(io.open(out, "wb")); f:write("PNG"); f:close()
            on_complete(0, "")
        end
        local status, msg
        ci.read_png({ tool = "t", argv = { "t", "{out}" } }, out, function(s, m) status, msg = s, m end, runner)
        vim.wait(500, function() return status ~= nil end, 10)
        assert.same({ "t", out }, seen_argv)
        assert.equals("ok", status, msg)
        os.remove(out)
    end)

    it("reports no_image when the tool wrote nothing", function()
        local out = vim.fn.tempname() .. ".png"
        local runner = function(_, on_complete) on_complete(1, "nothing") end
        local status
        ci.read_png({ tool = "t", argv = { "t", "{out}" } }, out, function(s) status = s end, runner)
        vim.wait(500, function() return status ~= nil end, 10)
        assert.equals("no_image", status)
    end)

    it("a held callback reproduces the in-flight interleaving (ARCH-ORDER seam)", function()
        local out = vim.fn.tempname() .. ".png"
        local held
        local runner = function(_, on_complete) held = on_complete end
        local status
        ci.read_png({ tool = "t", argv = { "t", "{out}" } }, out, function(s) status = s end, runner)
        assert.is_nil(status, "nothing settles until the tool answers")
        local f = assert(io.open(out, "wb")); f:write("PNG"); f:close()
        held(0, "")
        vim.wait(500, function() return status ~= nil end, 10)
        assert.equals("ok", status)
        os.remove(out)
    end)
end)
```

- [ ] **Step 2: Run to verify it fails** — `module 'parley.clipboard_image' not found`.

- [ ] **Step 3: Write the module**

```lua
-- lua/parley/clipboard_image.lua
--
-- Read an image off the system clipboard into a file. Platform recipes are
-- DATA — an argv array with an `{out}` token for the PNG path to write — and
-- the spawn is the one IO seam (ARCH-MOCK): `config.assets.clipboard_cmd`
-- supplies a recipe in the same shape, which is how tests/fixtures/fake_clipboard
-- stands in for osascript through the very boundary production uses.
--
-- Classification is ONE rule for every recipe (measured 2026-09-12 on macOS;
-- wl-paste and xclip document the same exit code for "no such type"):
--   exit 0 + non-empty file → ok
--   exit 0 + empty/missing  → no_image   (tool wrote nothing)
--   exit 1                  → no_image   (osascript: "Can’t make some data
--                                         into the expected type. (-2700)")
--   anything else           → failed, with the tool's stderr (124 = timeout)
--
-- PURE except read_png (spawn) and host_env (probes the host).

local uv = vim.uv or vim.loop

local M = {}

M.OUT = "{out}"
M.TIMEOUT_MS = 5000

-- The macOS recipe writes «class PNGf» to the path passed as argv — the
-- path never enters the script text. On a text clipboard it exits 1 and
-- leaves a 0-byte file, which classify() reads as no_image.
M.RECIPES = {
    darwin = {
        tool = "osascript",
        argv = {
            "osascript",
            "-e", "on run argv",
            "-e", "set p to POSIX file (item 1 of argv)",
            "-e", "set f to open for access p with write permission",
            "-e", "try",
            "-e", "set eof f to 0",
            "-e", "write (the clipboard as «class PNGf») to f",
            "-e", "close access f",
            "-e", "on error m",
            "-e", "close access f",
            "-e", "error m",
            "-e", "end try",
            "-e", "end run",
            "{out}",
        },
        install = "osascript ships with macOS",
    },
    -- `sh -c '… > "$1"' sh <out>`: the path is $1, an argument, never part
    -- of the script (ARCH-SECURE).
    wayland = {
        tool = "wl-paste",
        argv = { "sh", "-c", 'exec wl-paste --type image/png > "$1"', "sh", "{out}" },
        install = "install wl-clipboard (wl-paste)",
    },
    x11 = {
        tool = "xclip",
        argv = { "sh", "-c", 'exec xclip -selection clipboard -t image/png -o > "$1"', "sh", "{out}" },
        install = "install xclip",
    },
}

--- The host as select() sees it. Probed once per paste; tests pass their own.
function M.host_env()
    local uname = uv.os_uname()
    return {
        sysname = uname and uname.sysname or "",
        wayland = (vim.env.WAYLAND_DISPLAY or "") ~= "",
        executable = function(tool)
            return vim.fn.executable(tool) == 1
        end,
    }
end

local function has_out_token(argv)
    for _, a in ipairs(argv) do
        if a == M.OUT then
            return true
        end
    end
    return false
end

--- Pick a recipe: a configured argv wins; else the first executable platform
--- recipe. The error names what to install.
--- @param config_cmd string[]|nil
--- @param env table { sysname, wayland, executable }
--- @return table|nil recipe, string|nil err
function M.select(config_cmd, env)
    if type(config_cmd) == "table" and #config_cmd > 0 then
        if not has_out_token(config_cmd) then
            return nil, "assets.clipboard_cmd must contain the " .. M.OUT .. " token for the PNG path to write"
        end
        return { tool = config_cmd[1], argv = config_cmd, install = nil }
    end
    local order
    if env.sysname == "Darwin" then
        order = { "darwin" }
    elseif env.wayland then
        order = { "wayland", "x11" }
    else
        order = { "x11", "wayland" }
    end
    local hints = {}
    for _, key in ipairs(order) do
        local recipe = M.RECIPES[key]
        if env.executable(recipe.tool) then
            return recipe
        end
        hints[#hints + 1] = recipe.install
    end
    return nil, "no clipboard image tool found: " .. table.concat(hints, " or ")
end

--- The recipe's argv with `{out}` replaced as a whole argument.
function M.argv_for(recipe, out_path)
    local argv = {}
    for i, a in ipairs(recipe.argv) do
        argv[i] = (a == M.OUT) and out_path or a
    end
    return argv
end

--- One rule for every recipe (see the module header).
--- @param code integer
--- @param stderr string|nil
--- @param size integer|nil  bytes at out_path, nil when missing
--- @return "ok"|"no_image"|"failed" status, string|nil message
function M.classify(code, stderr, size)
    local words = (stderr or ""):gsub("%s+$", "")
    if code == 0 and size and size > 0 then
        return "ok"
    end
    if code == 0 then
        return "no_image", "no image on the clipboard (the tool wrote nothing)"
    end
    if code == 1 then
        return "no_image", "no image on the clipboard" .. (words ~= "" and (" (" .. words .. ")") or "")
    end
    return "failed", "exit " .. tostring(code) .. ": " .. words
end

--- Spawn the recipe to write a PNG at out_path, then on_done(status, msg) on
--- the main loop. runner(argv, on_complete(code, stderr)) defaults to
--- vim.system; tests inject one.
function M.read_png(recipe, out_path, on_done, runner)
    local argv = M.argv_for(recipe, out_path)
    local run = runner or function(a, on_complete)
        vim.system(a, { text = true, timeout = M.TIMEOUT_MS }, function(res)
            local stderr = res.stderr or ""
            if res.code == 124 and stderr == "" then
                stderr = recipe.tool .. " timed out after " .. M.TIMEOUT_MS .. " ms"
            end
            on_complete(res.code or 1, stderr)
        end)
    end
    run(argv, function(code, stderr)
        -- uv.fs_stat is safe in a libuv callback; vim.fn is not.
        local st = uv.fs_stat(out_path)
        local status, msg = M.classify(code, stderr, st and st.size or nil)
        vim.schedule(function()
            on_done(status, msg)
        end)
    end)
end

return M
```

- [ ] **Step 4: Run to verify it passes** — all `clipboard_image:` specs PASS.

- [ ] **Step 5: Commit**

```bash
git add lua/parley/clipboard_image.lua tests/unit/clipboard_image_spec.lua
git commit -m "#231 M1: clipboard_image — platform recipes as data, one classify rule, vim.system seam

Co-Authored-By: Claude Fable 5.1 <noreply@anthropic.com>"
```

---

## Chunk 2: the key — fixture, paste flow, `<M-v>` (M1, Task 4)

### Task 4: the fixture, the paste flow, the key

**Files:**
- Create: `tests/fixtures/fake_clipboard` (executable, Python 3)
- Create: `tests/fixtures/one_pixel.png` (a 1×1 PNG, 67 bytes)
- Create: `lua/parley/paste_image.lua`
- Modify: `lua/parley/config.lua` (an `assets` block near `chat_memory`, `:574`; a `chat_shortcut_paste_image` row after `chat_shortcut_branch_ref`, `:411`)
- Modify: `lua/parley/keybinding_registry.lua` (entry after `branch_ref`, `:495`)
- Modify: `lua/parley/init.lua` (`M.paste_image`; callbacks at `:2715` and `:2915`)
- Test: `tests/integration/paste_image_spec.lua`

- [ ] **Step 1: Create the fixture and the PNG**

```python
#!/usr/bin/env python3
"""A stand-in for the macOS clipboard recipe (#231).

Models `osascript` writing «class PNGf» to the path in argv[1], as measured on
2026-09-12: an image → the bytes land and it exits 0; a text clipboard → a
0-byte file is left, stderr says "Can’t make some data into the expected
type. (-2700)" and it exits 1. Which state the clipboard is in comes from
PARLEY_FAKE_CLIPBOARD:
    png:<path>   copy that file to argv[1], exit 0
    slow:<path>  sleep PARLEY_FAKE_CLIPBOARD_DELAY_MS (default 300), then as png:
    text         empty argv[1], the osascript sentence on stderr, exit 1
    broken       exit 2 with "boom"
Every call appends "<state>\t<argv[1]>" to $PARLEY_FAKE_CLIPBOARD_LOG when set,
so a spec can count reads.
"""
import os
import shutil
import sys
import time

sys.dont_write_bytecode = True  # never write __pycache__ into the repo (#202)

state = os.environ.get("PARLEY_FAKE_CLIPBOARD", "text")
out = sys.argv[1] if len(sys.argv) > 1 else ""
log = os.environ.get("PARLEY_FAKE_CLIPBOARD_LOG")
if log:
    with open(log, "a") as fh:
        fh.write(state + "\t" + out + "\n")

if state.startswith("slow:"):
    time.sleep(int(os.environ.get("PARLEY_FAKE_CLIPBOARD_DELAY_MS", "300")) / 1000.0)
    state = "png:" + state[5:]
if state.startswith("png:"):
    shutil.copyfile(state[4:], out)
    sys.exit(0)
if state == "broken":
    sys.stderr.write("boom\n")
    sys.exit(2)
open(out, "wb").close()
sys.stderr.write("207:208: execution error: Can’t make some data into the expected type. (-2700)\n")
sys.exit(1)
```

```bash
chmod +x tests/fixtures/fake_clipboard
python3 - <<'EOF'
import base64
png = base64.b64decode("iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAIAAACQd1PeAAAADElEQVR4nGP4z8AAAAMBAQDJ/pLvAAAAAElFTkSuQmCC")
open("tests/fixtures/one_pixel.png", "wb").write(png)
print(len(png), "bytes")
EOF
```
Expected: `67 bytes`; `file tests/fixtures/one_pixel.png` says `PNG image data, 1 x 1`.

- [ ] **Step 2: Write the failing integration spec**

```lua
-- tests/integration/paste_image_spec.lua
--
-- End-to-end through the config seam: the fixture stands in for osascript.
local root = vim.fn.tempname() .. "-parley-paste"
vim.fn.mkdir(root, "p")
local repo = vim.fn.fnamemodify(debug.getinfo(1, "S").source:sub(2), ":p:h:h:h")
-- Named so the plan's Integration-points row `fake_clipboard` resolves to a
-- definition (tests/arch/single_source_sweeps_spec.lua "every symbol … exists").
local fake_clipboard = repo .. "/tests/fixtures/fake_clipboard"
local png = repo .. "/tests/fixtures/one_pixel.png"
local log = root .. "/clipboard.log"

local parley = require("parley")
parley.setup({
    chat_dir = root,
    state_dir = root .. "/state",
    providers = {},
    api_keys = {},
    assets = { clipboard_cmd = { fake_clipboard, "{out}" } },
})
local assets = require("parley.assets")

local TS = "2026-09-10.14-20-03.112"

local function open_chat(name, lines)
    local path = root .. "/" .. name
    vim.fn.writefile(lines, path)
    vim.cmd("edit " .. vim.fn.fnameescape(path))
    return vim.api.nvim_get_current_buf(), path
end

local function chat_lines()
    return { "---", "topic: Paste", "file: x.md", "model: m", "provider: openai", "---", "", "💬: look at this", "and this" }
end

local function wait_for(pred, ms)
    return vim.wait(ms or 3000, pred, 20)
end

local function reads()
    return vim.fn.filereadable(log) == 1 and #vim.fn.readfile(log) or 0
end

local notices
local function notify(msg, level) notices[#notices + 1] = { msg = msg, level = level } end

describe("paste image (#231)", function()
    before_each(function()
        notices = {}
        os.remove(log)
        vim.env.PARLEY_FAKE_CLIPBOARD_LOG = log
    end)
    after_each(function()
        vim.env.PARLEY_FAKE_CLIPBOARD = nil
        vim.cmd("silent! %bwipeout!")
        vim.fn.delete(root, "rf")
        vim.fn.mkdir(root, "p")
    end)

    it("saves the clipboard PNG under assets/<ts>/ and inserts the link after the cursor line", function()
        vim.env.PARLEY_FAKE_CLIPBOARD = "png:" .. png
        local buf, path = open_chat(TS .. "_paste.md", chat_lines())
        vim.api.nvim_win_set_cursor(0, { 8, 0 })  -- the 💬: line

        parley.paste_image(buf, { notify = notify })

        assert.is_true(wait_for(function() return #vim.api.nvim_buf_get_lines(buf, 0, -1, false) == 10 end), "link inserted")
        local lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
        local att = assets.parse_attachment(lines[9])
        assert.is_not_nil(att, "line 9 is an attachment: " .. lines[9])
        assert.equals(TS, att.ts)
        assert.equals("and this", lines[10], "the following line is untouched")
        local abs = root .. "/" .. att.path
        assert.equals(1, vim.fn.filereadable(abs))
        assert.equals(assets.default_io.read(png), assets.default_io.read(abs), "bytes are the clipboard bytes")
        assert.matches("pasted assets/", notices[#notices].msg)
        assert.equals(1, reads(), "one clipboard read")
        assert.equals(path, vim.api.nvim_buf_get_name(buf))
    end)

    it("declines a text clipboard, writes nothing, and says why", function()
        vim.env.PARLEY_FAKE_CLIPBOARD = "text"
        local buf = open_chat(TS .. "_text.md", chat_lines())
        vim.api.nvim_win_set_cursor(0, { 8, 0 })

        parley.paste_image(buf, { notify = notify })

        assert.is_true(wait_for(function() return #notices > 0 end))
        assert.matches("nothing pasted", notices[1].msg)
        assert.matches("expected type", notices[1].msg, "the tool's own words are shown")
        assert.equals("info", notices[1].level)
        assert.equals(9, #vim.api.nvim_buf_get_lines(buf, 0, -1, false))
        assert.equals(0, vim.fn.isdirectory(root .. "/assets"), "no folder created")
    end)

    it("reports a broken tool as a failure with its stderr", function()
        vim.env.PARLEY_FAKE_CLIPBOARD = "broken"
        local buf = open_chat(TS .. "_broken.md", chat_lines())
        parley.paste_image(buf, { notify = notify })
        assert.is_true(wait_for(function() return #notices > 0 end))
        assert.equals("warn", notices[1].level)
        assert.matches("exit 2: boom", notices[1].msg)
    end)

    it("declines a markdown file without a timestamp name, without reading the clipboard", function()
        vim.env.PARLEY_FAKE_CLIPBOARD = "png:" .. png
        local buf = open_chat("notes.md", { "# note" })
        parley.paste_image(buf, { notify = notify })
        assert.equals(1, #notices)
        assert.matches("timestamp%-named chat", notices[1].msg)
        assert.equals(0, reads())
    end)

    it("the link lands where the cursor was, even if lines were inserted above meanwhile", function()
        vim.env.PARLEY_FAKE_CLIPBOARD = "slow:" .. png
        local buf = open_chat(TS .. "_race.md", chat_lines())
        vim.api.nvim_win_set_cursor(0, { 9, 0 })  -- "and this"
        parley.paste_image(buf, { notify = notify })
        -- Typing above before the tool answers: the anchor must follow.
        vim.api.nvim_buf_set_lines(buf, 6, 6, false, { "inserted above" })
        assert.is_true(wait_for(function() return #vim.api.nvim_buf_get_lines(buf, 0, -1, false) == 11 end))
        local lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
        assert.equals("and this", lines[10])
        assert.is_not_nil(assets.parse_attachment(lines[11]))
    end)

    it("discards the image when the buffer was closed before the tool answered", function()
        vim.env.PARLEY_FAKE_CLIPBOARD = "slow:" .. png
        local buf = open_chat(TS .. "_closed.md", chat_lines())
        parley.paste_image(buf, { notify = notify })
        vim.api.nvim_buf_delete(buf, { force = true })
        assert.is_true(wait_for(function() return #notices > 0 end))
        assert.matches("buffer was closed", notices[1].msg)
        assert.equals(0, vim.fn.isdirectory(root .. "/assets"), "no bytes without a transcript line")
    end)

    it("refuses a second paste while one is in flight on the same buffer", function()
        vim.env.PARLEY_FAKE_CLIPBOARD = "slow:" .. png
        local buf = open_chat(TS .. "_twice.md", chat_lines())
        parley.paste_image(buf, { notify = notify })
        parley.paste_image(buf, { notify = notify })
        assert.matches("already in progress", notices[1].msg)
        assert.is_true(wait_for(function() return #vim.api.nvim_buf_get_lines(buf, 0, -1, false) == 10 end))
        assert.equals(1, reads(), "the second key spawned nothing")
        -- and the flight is over: a third paste is accepted. Wait for ITS link,
        -- not the log line — the fixture logs before it sleeps, and a paste
        -- still in flight when this case returns would notify into the next
        -- case's table (nothing outlives a paste: ARCH-ORDER).
        parley.paste_image(buf, { notify = notify })
        assert.is_true(wait_for(function() return #vim.api.nvim_buf_get_lines(buf, 0, -1, false) == 11 end))
        assert.equals(2, reads())
    end)

    it("<M-v> is a parley_buffer entry resolving to n/i through the registry", function()
        local reg = require("parley.keybinding_registry")
        local entry
        for _, e in ipairs(reg.entries) do if e.id == "paste_image" then entry = e end end
        assert.is_not_nil(entry)
        assert.equals("parley_buffer", entry.scope)
        local keys, modes = reg.resolve_keys(entry, parley.config)
        assert.same({ "<M-v>" }, keys)
        assert.same({ "n", "i" }, modes)
    end)
end)
```

- [ ] **Step 3: Run to verify it fails** — `attempt to call field 'paste_image' (a nil value)`.

- [ ] **Step 4: Config, registry entry, orchestration, wiring**

`lua/parley/config.lua`, next to `chat_memory` (`:574`):
```lua
	-- #231: chat assets — the per-chat sidecar folder `assets/<chat-timestamp>/`
	-- for what markdown cannot hold (pasted images now; #239's generated images
	-- next). `assets.clipboard_cmd` overrides the platform recipe (osascript /
	-- wl-paste / xclip): an argv list whose "{out}" token is replaced by the PNG
	-- path to write. Contract: exit 0 + a non-empty file = image; exit 0 + empty,
	-- or exit 1 = no image on the clipboard; anything else = failure (stderr shown).
	-- setup() REPLACES this table wholesale (as for `outline`/`drill_in`): keep
	-- it free of defaults; anything #239 adds resolves in code with `or`.
	assets = {},
```

`lua/parley/config.lua`, after `chat_shortcut_branch_ref` (`:411`):
```lua
	-- #231: paste the clipboard image as an attachment. <M-v> — v for paste,
	-- free, joins the alt family. (<M-i> was the request; it is branch_ref.)
	chat_shortcut_paste_image = { modes = { "n", "i" }, shortcut = "<M-v>" },
```

`lua/parley/keybinding_registry.lua`, after the `branch_ref` entry (`:495`):
```lua
	{
		id = "paste_image",
		config_key = "chat_shortcut_paste_image",
		default_key = "<M-v>",
		default_modes = { "n", "i" },
		scope = "parley_buffer",
		desc = "Parley paste clipboard image as attachment",
		help_desc = "Paste image from clipboard",
		buffer_local = true,
	},
```

`lua/parley/paste_image.lua`:
```lua
-- lua/parley/paste_image.lua
--
-- The <M-v> flow (#231): read the clipboard image through clipboard_image,
-- save it through assets (THE writer), insert the link on its own line after
-- the cursor line. Asynchronous and anchored: the cursor line is captured as
-- an extmark handle before the spawn, so typing meanwhile cannot misplace the
-- link; the editor never blocks. One paste per buffer at a time; a closed
-- buffer discards the image — no bytes without a transcript line. The chat
-- path is re-read at completion so a rename or move that finished meanwhile
-- is honoured. The cursor row comes from the CURRENT window, which the key
-- guarantees is showing `buf`. In insert mode the key does NOT stopinsert
-- (helper.set_keymap does not, unlike register_global): the row is still the
-- right one, and a stopinsert here would pull the cursor left — leave it.
--
-- deps = { config, notify(msg, level), runner? } — init.lua supplies the real
-- ones; specs pass a recording notify.

local assets = require("parley.assets")
local clipboard_image = require("parley.clipboard_image")
local buffer_edit = require("parley.buffer_edit")

local M = {}

-- buf → true while a read is in flight; cleared on every terminal path.
local inflight = {}

function M.paste(buf, deps)
    local chat_path = vim.api.nvim_buf_get_name(buf)
    local folder, ferr = assets.folder_for(chat_path)
    if not folder then
        deps.notify("Parley: image paste needs a timestamp-named chat (" .. ferr .. ")", "warn")
        return
    end
    if inflight[buf] then
        deps.notify("Parley: a paste is already in progress for this buffer", "info")
        return
    end
    local cfg = deps.config.assets or {}
    local recipe, rerr = clipboard_image.select(cfg.clipboard_cmd, clipboard_image.host_env())
    if not recipe then
        deps.notify("Parley: " .. rerr, "warn")
        return
    end

    local row = vim.api.nvim_win_get_cursor(0)[1]
    local anchor = buffer_edit.make_handle(buf, row - 1)
    local tmp = vim.fn.tempname() .. ".png"
    inflight[buf] = true

    local function finish(msg, level)
        inflight[buf] = nil
        os.remove(tmp)
        buffer_edit.handle_invalidate(anchor) -- checks `dead` and pcalls itself
        deps.notify(msg, level)
    end

    clipboard_image.read_png(recipe, tmp, function(status, msg)
        local ok, err = pcall(function()
            if status ~= "ok" then
                return finish("Parley: nothing pasted — " .. msg, status == "no_image" and "info" or "warn")
            end
            if not vim.api.nvim_buf_is_valid(buf) then
                return finish("Parley: nothing pasted — the buffer was closed before the clipboard answered", "info")
            end
            local bytes, read_err = assets.default_io.read(tmp)
            if not bytes then
                return finish("Parley: could not read the pasted image: " .. tostring(read_err), "error")
            end
            -- The buffer's CURRENT name: a rename or move may have finished meanwhile.
            local rel, _, save_err = assets.save(vim.api.nvim_buf_get_name(buf), bytes, "png")
            if not rel then
                return finish("Parley: " .. save_err, "error")
            end
            local line = buffer_edit.handle_line(anchor)
            buffer_edit.insert_lines_at(buf, line + 1, { assets.markdown_link(rel) })
            finish("Parley: pasted " .. rel, "info")
        end)
        if not ok then
            finish("Parley: paste failed: " .. tostring(err), "error")
        end
    end, deps.runner)
end

return M
```

`lua/parley/init.lua` — the public entry (near `M.move_chat_tree`, `:3529`):
```lua
-- #231: paste the clipboard image as an attachment of the chat in `buf`.
-- `deps` is for specs (a recording notify, a fake runner); the key passes nothing.
M.paste_image = function(buf, deps)
	deps = deps or {}
	require("parley.paste_image").paste(buf, {
		config = M.config,
		notify = deps.notify or function(msg, level)
			vim.notify(msg, vim.log.levels[level:upper()] or vim.log.levels.INFO)
		end,
		runner = deps.runner,
	})
end
```
and the callback in BOTH `register_buffer` tables (`:2715` and `:2915`), right
after `branch_ref = …`:
```lua
			paste_image = function() M.paste_image(vim.api.nvim_get_current_buf()) end,
```

- [ ] **Step 5: Run the spec, then the keybinding guards**

Run: `nvim -n --headless --noplugin -u tests/minimal_init.vim -c "PlenaryBustedFile tests/integration/paste_image_spec.lua" -c "qa!"`
Expected: 8 PASS.
Run: `… -c "PlenaryBustedFile tests/integration/keybinding_agreement_spec.lua"` and `… tests/unit/keybindings_spec.lua`
Expected: PASS (no leak, no ghost; help lists "Paste image from clipboard").

- [ ] **Step 6: Commit**

```bash
git add tests/fixtures/fake_clipboard tests/fixtures/one_pixel.png lua/parley/paste_image.lua lua/parley/config.lua lua/parley/keybinding_registry.lua lua/parley/init.lua tests/integration/paste_image_spec.lua
git commit -m "#231 M1: <M-v> pastes the clipboard image into assets/<ts>/ and links it

The fixture models osascript through the same config seam a Linux user
would use for their own tool; the link is anchored by an extmark so the
async read cannot misplace it; a closed buffer discards the bytes.

Co-Authored-By: Claude Fable 5.1 <noreply@anthropic.com>"
```

---

## Chunk 3: send — parser, build_messages, wires, M1 gate (M1, Tasks 5–8)

### Task 5: the parser — an image link in a question is an attachment

**Files:**
- Modify: `lua/parley/chat_parser.lua:637-660` and `:845-866`
- Test: `tests/unit/parse_chat_spec.lua` (append)

- [ ] **Step 1: Write the failing tests** (`std_header` is the header table
  every other case in this spec passes to `make_chat`; use it so
  `parse_header_metadata` sees a real header)

```lua
-- append to tests/unit/parse_chat_spec.lua
describe("attachments (#231)", function()
    local TS = "2026-09-10.14-20-03.112"
    local link = "![](assets/" .. TS .. "/2026-09-10.14-22-31.487.png)"

    it("collects image links in the question body, with their lines", function()
        local lines, header_end = make_chat(std_header, {
            "💬: what is this?",
            link,
            "and this one",
            "![](assets/" .. TS .. "/b.gif)",
            "",
            "🤖: an answer",
        })
        local parsed = parse_chat(lines, header_end)
        local q = parsed.exchanges[1].question
        assert.equals(2, #q.attachments)
        assert.equals("assets/" .. TS .. "/2026-09-10.14-22-31.487.png", q.attachments[1].path)
        assert.equals("image/png", q.attachments[1].media_type)
        assert.equals(header_end + 3, q.attachments[1].line)
        assert.equals("image/gif", q.attachments[2].media_type)
        assert.matches(vim.pesc(link), q.content, "the link text stays in the content")
    end)

    it("collects a link on the 💬: prefix line itself", function()
        local lines, header_end = make_chat(std_header, { "💬: " .. link })
        local q = parse_chat(lines, header_end).exchanges[1].question
        assert.equals(1, #q.attachments)
    end)

    it("an image link in an answer is prose, not an attachment", function()
        local lines, header_end = make_chat(std_header, {
            "💬: draw", "", "🤖: here", link,
        })
        local ex = parse_chat(lines, header_end).exchanges[1]
        assert.equals(0, #ex.question.attachments)
        assert.is_nil(ex.answer.attachments)
    end)

    it("a link that is not the grammar is prose", function()
        local lines, header_end = make_chat(std_header, {
            "💬: q", "![](/etc/passwd.png)", "see ![](assets/" .. TS .. "/x.png) inline",
        })
        assert.equals(0, #parse_chat(lines, header_end).exchanges[1].question.attachments)
    end)

    it("every exchange has an attachments list, even when empty", function()
        local lines, header_end = make_chat(std_header, { "💬: q", "", "🤖: a", "", "💬: q2" })
        for _, ex in ipairs(parse_chat(lines, header_end).exchanges) do
            assert.same({}, ex.question.attachments)
        end
    end)
end)
```

- [ ] **Step 2: Run to verify it fails** — `attempt to get length of field 'attachments' (a nil value)`.

- [ ] **Step 3: Implement**

At the top of `chat_parser.lua` with the other requires:
```lua
local assets = require("parley.assets")
```
In the exchange constructor (`:637-645`) add the field:
```lua
				question = {
					line_start = i,
					line_end = nil,
					content = "",
					file_references = {}, -- Will store file references we find (length > 0 means has references)
					-- #231: `![](assets/<ts>/<file>)` lines in this question, in order.
					-- An attachment, not prose: build_messages sends the bytes.
					attachments = {},
				},
```
After the prefix-line `inline_refs` loop (`:653-660`):
```lua
			-- #231: an attachment on the prefix line itself (`💬: ![](assets/…)`)
			local prefix_att = assets.parse_attachment(question_content)
			if prefix_att then
				table.insert(current_exchange.question.attachments, {
					line = i, path = prefix_att.path, media_type = prefix_att.media_type,
				})
			end
```
In the continuation branch (`:865`, inside `if current_component == "question" then`), after the file-refs loop:
```lua
				local att = assets.parse_attachment(line)
				if att then
					table.insert(current_exchange.question.attachments, {
						line = i, path = att.path, media_type = att.media_type,
					})
				end
```

- [ ] **Step 4: Run to verify it passes** — `tests/unit/parse_chat_spec.lua` all PASS.

- [ ] **Step 5: Commit**

```bash
git add lua/parley/chat_parser.lua tests/unit/parse_chat_spec.lua
git commit -m "#231 M1: parser — an image link in a question block is an attachment

Co-Authored-By: Claude Fable 5.1 <noreply@anthropic.com>"
```

### Task 6: `build_messages` — attachments become image blocks; summarized ones become a note

**Files:**
- Modify: `lua/parley/chat_respond.lua` (`build_messages` `:700-870`; `build_messages_from_model` `:474-484`; caller `:1454`)
- Test: `tests/unit/build_messages_spec.lua` (append; uses that file's `stub_helpers`/`stub_logger`)

- [ ] **Step 1: Write the failing tests**

```lua
-- append to tests/unit/build_messages_spec.lua
describe("attachments (#231)", function()
    local assets = require("parley.assets")
    local TS = "2026-09-10.14-20-03.112"
    local chat_dir = tmp_dir .. "/chats"
    local chat_path = chat_dir .. "/" .. TS .. "_att.md"
    local rel = "assets/" .. TS .. "/a.png"

    before_each(function()
        vim.fn.mkdir(chat_dir .. "/assets/" .. TS, "p")
        assets.default_io.write(chat_dir .. "/" .. rel, "PNGBYTES")
    end)

    local function att_exchange(q, answer)
        local ex = exchange(q .. "\n![](" .. rel .. ")", answer)
        ex.question.attachments = { { line = 11, path = rel, media_type = "image/png" } }
        return ex
    end

    local function build(exchanges, idx)
        return parley._build_messages({
            parsed_chat = parsed_chat(exchanges),
            start_index = 1, end_index = 999, exchange_idx = idx or #exchanges,
            agent = agent(), config = parley.config,
            helpers = stub_helpers, logger = stub_logger,
            chat_path = chat_path,
        })
    end

    local function first_user(messages)
        for _, m in ipairs(messages) do
            if m.role == "user" then return m end
        end
    end

    it("a preserved question carries image blocks first, then the text", function()
        local messages = build({ att_exchange("what?") })
        local user = messages[#messages]
        assert.equals("user", user.role)
        assert.equals("table", type(user.content))
        assert.equals("image", user.content[1].type)
        assert.equals(vim.base64.encode("PNGBYTES"), user.content[1].source.data)
        assert.equals("image/png", user.content[1].source.media_type)
        assert.equals("text", user.content[2].type)
        assert.matches("^what%?\n!%[%]", user.content[2].text)
    end)

    it("a question with @@ file references AND an attachment keeps both", function()
        local ex = att_exchange("q")
        ex.question.file_references = { { line = "@@/x@@", path = "/x", original_line_index = 1 } }
        local messages = build({ ex })
        assert.equals("system", messages[#messages - 1].role)
        assert.matches("File content: /x", messages[#messages - 1].content)
        assert.equals("image", messages[#messages].content[1].type)
    end)

    it("a summarized question drops the image and says so", function()
        local exchanges = { att_exchange("old", "old answer"), exchange("mid", "a2"), exchange("new", "a3"), exchange("now") }
        local messages = build(exchanges)  -- max_full_exchanges = 2 in this spec's setup
        local user = first_user(messages)
        assert.equals("string", type(user.content))
        assert.equals("[Previous messages omitted]\n" .. assets.OMITTED_NOTE, user.content)
        for _, m in ipairs(messages) do
            if type(m.content) == "table" then
                for _, b in ipairs(m.content) do assert.not_equals("image", b.type) end
            end
        end
    end)

    -- A PIN, not a red/green case: the case above already proves it; this one
    -- names the rule so a future "preserve if attachments" change goes red here.
    it("attachments do not pin an exchange in the window (pin)", function()
        local exchanges = { att_exchange("old", "a1"), exchange("b", "a2"), exchange("c", "a3"), exchange("now") }
        assert.matches("^%[Previous messages omitted%]", first_user(build(exchanges)).content)
    end)

    it("elide_image_data replaces bytes in every wire shape and leaves the rest", function()
        local data = vim.base64.encode(string.rep("x", 30))
        local elided = assets.elide_image_data({
            { role = "user", content = {
                { type = "image", source = { type = "base64", media_type = "image/png", data = data } },
                { type = "text", text = "q" } } },
            { role = "user", content = { { type = "image_url", image_url = { url = "data:image/png;base64," .. data, detail = "auto" } } } },
            { role = "user", parts = { { inlineData = { mimeType = "image/png", data = data } }, { text = "t" } } },
            { role = "assistant", content = "plain" },
        })
        assert.equals("<image/png, 40 bytes>", elided[1].content[1].source.data)
        assert.equals("q", elided[1].content[2].text)
        assert.equals("<image/png, 40 bytes>", elided[2].content[1].image_url.url)
        assert.equals("auto", elided[2].content[1].image_url.detail)
        assert.equals("<image/png, 40 bytes>", elided[3].parts[1].inlineData.data)
        assert.equals("plain", elided[4].content)
        assert.is_nil(vim.inspect(elided):find(data, 1, true), "no base64 survives")
    end)

    it("the messages-to-send debug line never carries image bytes", function()
        -- stub_logger records; the real logger.debug is what production calls,
        -- so this asserts through the seam build_messages' caller uses.
        local seen = {}
        local logger = require("parley.logger")
        local saved = logger.debug
        logger.debug = function(msg) seen[#seen + 1] = msg end
        local ok, err = pcall(function()
            local messages = build({ att_exchange("q") })
            logger.debug("messages to send: " .. vim.inspect(assets.elide_image_data(messages)))
        end)
        logger.debug = saved
        assert(ok, err)
        assert.is_nil(seen[#seen]:find(vim.base64.encode("PNGBYTES"), 1, true))
        assert.is_not_nil(seen[#seen]:find("<image/png, 8 bytes>", 1, true))
    end)

    it("a missing file degrades to a note, not a block", function()
        os.remove(chat_dir .. "/" .. rel)
        local messages = build({ att_exchange("q") })
        local user = messages[#messages]
        assert.equals("string", type(user.content))
        assert.matches("could not be read", user.content)
    end)

    it("without chat_path every attachment is a visible note", function()
        local messages = parley._build_messages({
            parsed_chat = parsed_chat({ att_exchange("q") }),
            start_index = 1, end_index = 999, exchange_idx = 1,
            agent = agent(), config = parley.config, helpers = stub_helpers, logger = stub_logger,
        })
        assert.matches("chat_path not supplied", messages[#messages].content)
    end)
end)
```

- [ ] **Step 2: Run to verify it fails** — the first case fails with `content` being a string.

- [ ] **Step 3: Implement**

First the eliding helper, appended to `lua/parley/assets.lua` (pure) — one
helper, three sinks:
```lua
--- A deep copy of any messages/payload table with every image payload
--- replaced by "<mime, N bytes>": an Anthropic `image` block's source.data,
--- a Gemini inlineData.data, an OpenAI data-URL image_url.url. For the logs
--- (ARCH-FUNERAL): a log line is never an image.
function M.elide_image_data(value)
    if type(value) ~= "table" then
        return value
    end
    local out = {}
    for k, v in pairs(value) do
        out[k] = M.elide_image_data(v)
    end
    local function elided(mime, b64)
        return "<" .. tostring(mime) .. ", " .. tostring(#(b64 or "")) .. " bytes>"
    end
    if out.type == "image" and type(out.source) == "table" and type(out.source.data) == "string" then
        out.source.data = elided(out.source.media_type, out.source.data)
    end
    if type(out.inlineData) == "table" and type(out.inlineData.data) == "string" then
        out.inlineData.data = elided(out.inlineData.mimeType, out.inlineData.data)
    end
    if type(out.image_url) == "table" and type(out.image_url.url) == "string" then
        local mime, b64 = out.image_url.url:match("^data:([^;]+);base64,(.*)$")
        if mime then
            out.image_url.url = elided(mime, b64)
        end
    end
    return out
end
```
The three sinks in `chat_respond.lua`:
```lua
        -- :1639
        _parley.logger.debug("messages to send: " .. vim.inspect(require("parley.assets").elide_image_data(messages)))
        -- :2021
                            raw_log.write_exchange_turn(chat_path, require("parley.assets").elide_image_data(messages))
        -- :2030
                                request = require("parley.assets").elide_image_data(final_payload),
```

In `build_messages`, after `local define = require("parley.define")` (`:709`):
```lua
    local assets = require("parley.assets")
    -- #231: attachments are read relative to the chat file. Callers pass the
    -- buffer's name; a missing chat_path makes every attachment a visible note.
    local function read_asset(rel)
        if not opts.chat_path then
            return nil, "chat_path not supplied to build_messages"
        end
        return assets.read(opts.chat_path, rel)
    end
```
Replace the two question inserts (`:857-864`) so both use one `content`:
```lua
                    -- #231: image blocks lead, the text follows (one builder, both branches).
                    local user_content = assets.question_content(
                        question_content, exchange.question.attachments, read_asset)

                    if exchange.question.file_references and #exchange.question.file_references > 0 then
                        table.insert(messages, {
                            role = "system",
                            content = table.concat(file_content_parts, "\n") .. "\n",
                            cache_control = { type = "ephemeral" },
                        })
                        table.insert(messages, { role = "user", content = user_content })
                    else
                        table.insert(messages, { role = "user", content = user_content })
                    end
```
Replace the placeholder insert (`:868`):
```lua
                    -- #231: the placeholder says an image was there, so the model
                    -- is not left inferring it from context that no longer exists.
                    table.insert(messages, {
                        role = "user",
                        content = assets.omitted_text(omit_user_text, exchange.question.attachments),
                    })
```
The caller (`:1454`) gains one field:
```lua
            messages = M.build_messages({
                parsed_chat = parsed_chat,
                -- … existing fields …
                root_policy = agent_info.root_policy,
                chat_path = vim.api.nvim_buf_get_name(buf),  -- #231: attachments resolve here
            })
```
In `build_messages_from_model`, add `local assets = require("parley.assets")`
to the function's require block (`:433-436`) and
`local chat_path = vim.api.nvim_buf_get_name(buf)` beside it; then replace the
question branch body (`:474-484`):
```lua
            if blk.kind == "question" then
                local text = read_block_text(k, b)
                text = text:gsub("^💬:%s*", ""):gsub("^%s*(.-)%s*$", "%1")
                text = define.strip_definition_footnote_footer(text)
                if text ~= "" then
                    flush_answer()
                    -- #231: same grammar and same builder as the parse path.
                    local content = assets.question_content(text, assets.attachments_in(text), function(rel)
                        return assets.read(chat_path, rel)
                    end)
                    table.insert(messages, { role = "user", content = content })
                end
```

- [ ] **Step 4: Run to verify it passes** — `tests/unit/build_messages_spec.lua` all PASS, including the pre-existing cases (a question without attachments is byte-identical: `question_content` returns the string). Then `grep -n "elide_image_data" lua/parley/chat_respond.lua` shows exactly three sites (`:1639`, `:2021`, `:2030`).

- [ ] **Step 5: Commit**

```bash
git add lua/parley/assets.lua lua/parley/chat_respond.lua tests/unit/build_messages_spec.lua
git commit -m "#231 M1: build_messages — attachments as image blocks; summarized ones become a note

Both the parse path and the buffer-block rebuild use assets.question_content,
so a resubmit cannot lose an image the first send carried. The three log
sinks elide image bytes: a log line is never an image.

Co-Authored-By: Claude Fable 5.1 <noreply@anthropic.com>"
```

### Task 7: three wires, three shapes

**Files:**
- Modify: `lua/parley/tools/wire_openai.lua:270-310`
- Modify: `lua/parley/providers.lua:841-870` (googleai)
- Test: `tests/unit/wire_images_spec.lua`

- [ ] **Step 1: Write the failing tests**

```lua
-- tests/unit/wire_images_spec.lua
--
-- One internal image block, three wire shapes — asserted against the payload
-- prepare_payload builds, per wire, from the provider docs read 2026-09-12.
local tmp_dir = (os.getenv("TMPDIR") or "/tmp") .. "/claude/parley-test-wire-images-" .. os.time()
local parley = require("parley")
parley.setup({ chat_dir = tmp_dir, state_dir = tmp_dir .. "/state", providers = {}, api_keys = {} })
local dispatcher = require("parley.dispatcher")

-- As dispatcher_spec does: a truthy web_search would append server tools to
-- the anthropic/googleai payloads and muddy the pinned shapes. Set once at
-- file scope (no spec here toggles it); this repo has no top-level before_each.
parley._state.web_search = false

local DATA = vim.base64.encode("PNGBYTES")
local function image_user(text)
    return {
        role = "user",
        content = {
            { type = "image", source = { type = "base64", media_type = "image/png", data = DATA } },
            { type = "text", text = text },
        },
    }
end
local function sys(t) return { role = "system", content = t } end
local function user(t) return { role = "user", content = t } end
local function assistant(t) return { role = "assistant", content = t } end

describe("image attachments on the anthropic wire", function()
    it("passes the image block through, images before text, system hoisted", function()
        local payload = dispatcher.prepare_payload(
            { sys("S"), image_user("what?") }, { model = "claude-opus-5" }, "anthropic")
        assert.equals("S", payload.system[1].text)
        local m = payload.messages[1]
        assert.equals("user", m.role)
        assert.same({ type = "image", source = { type = "base64", media_type = "image/png", data = DATA } }, m.content[1])
        assert.same({ type = "text", text = "what?" }, m.content[2])
    end)
end)

describe("image attachments on the openai wire", function()
    it("becomes an image_url data URL part followed by a text part", function()
        local payload = dispatcher.prepare_payload(
            { sys("S"), image_user("what?") }, { model = "gpt-4o" }, "openai")
        local m = payload.messages[2]
        assert.equals("user", m.role)
        assert.same({
            { type = "image_url", image_url = { url = "data:image/png;base64," .. DATA, detail = "auto" } },
            { type = "text", text = "what?" },
        }, m.content)
    end)

    it("a text-only user message stays a plain string (pinned)", function()
        local payload = dispatcher.prepare_payload({ user("hi") }, { model = "gpt-4o" }, "openai")
        assert.equals("hi", payload.messages[1].content)
    end)

    it("tool_result blocks and an image in one user turn keep their order", function()
        local msg = {
            role = "user",
            content = {
                { type = "tool_result", tool_use_id = "t1", content = "R" },
                { type = "image", source = { type = "base64", media_type = "image/png", data = DATA } },
                { type = "text", text = "and?" },
            },
        }
        local payload = dispatcher.prepare_payload({ msg }, { model = "gpt-4o" }, "openai")
        assert.equals("tool", payload.messages[1].role)
        assert.equals("image_url", payload.messages[2].content[1].type)
        assert.equals("and?", payload.messages[2].content[2].text)
    end)
end)

describe("image attachments on the googleai wire", function()
    it("becomes an inlineData part, camelCase, before the text part", function()
        local payload = dispatcher.prepare_payload(
            { image_user("what?") }, { model = "gemini-2.5-pro" }, "googleai")
        local c = payload.contents[1]
        assert.equals("user", c.role)
        assert.same({ inlineData = { mimeType = "image/png", data = DATA } }, c.parts[1])
        assert.same({ text = "what?" }, c.parts[2])
    end)

    it("same-role merging appends whole parts lists", function()
        local payload = dispatcher.prepare_payload(
            { sys("S"), image_user("what?") }, { model = "gemini-2.5-pro" }, "googleai")
        -- system → user, merged with the following user message
        assert.equals(1, #payload.contents)
        assert.same({ text = "S" }, payload.contents[1].parts[1])
        assert.equals("image/png", payload.contents[1].parts[2].inlineData.mimeType)
        assert.same({ text = "what?" }, payload.contents[1].parts[3])
    end)

    it("text-only payloads are byte-identical to before (pinned)", function()
        local payload = dispatcher.prepare_payload(
            { sys("S"), user("u"), assistant("a"), user("u2") }, { model = "gemini-2.5-pro" }, "googleai")
        assert.same({
            { role = "user", parts = { { text = "S" }, { text = "u" } } },
            { role = "model", parts = { { text = "a" } } },
            { role = "user", parts = { { text = "u2" } } },
        }, payload.contents)
    end)
end)
```

- [ ] **Step 2: Run to verify it fails** — openai: content is a string missing the image (dropped with a warning); googleai: `parts[1].text` is a table / merge errors.

- [ ] **Step 3: Implement**

`wire_openai.lua`, the user branch (`:270-310`): collect images and emit parts.
```lua
        else
            -- A user turn carrying tool_result blocks and/or (#231) image
            -- blocks. Each result becomes its own message; images and stray
            -- text collapse into ONE user message after them — as content
            -- PARTS when an image is present, a plain string otherwise (the
            -- pre-#231 shape, pinned).
            local texts, parts = {}, {}
            for _, block in ipairs(msg.content) do
                if block.type == "tool_result" then
                    local content = block.content or ""
                    if block.is_error then
                        content = ERROR_PREFIX .. content
                    end
                    table.insert(out, {
                        role = "tool",
                        tool_call_id = block.tool_use_id,
                        content = content,
                    })
                elseif block.type == "text" then
                    table.insert(texts, block.text or "")
                elseif block.type == "image" and block.source and block.source.type == "base64" then
                    -- Chat Completions image part (docs read 2026-09-12):
                    -- {type="image_url", image_url={url="data:<mime>;base64,<data>", detail}}
                    table.insert(parts, {
                        type = "image_url",
                        image_url = {
                            url = "data:" .. block.source.media_type .. ";base64," .. block.source.data,
                            detail = "auto",
                        },
                    })
                else
                    require("parley.logger").warning(
                        "wire_openai.translate_messages: dropping unsupported "
                        .. tostring(msg.role) .. " content block of type "
                        .. tostring(block.type))
                end
            end
            local text = #texts > 0 and table.concat(texts, "\n\n") or nil
            if #parts > 0 then
                if text then
                    table.insert(parts, { type = "text", text = text })
                end
                table.insert(out, { role = msg.role or "user", content = parts })
            elseif text then
                table.insert(out, { role = msg.role or "user", content = text })
            end
        end
```

`providers.lua`, above `googleai.format_payload` (`:841`):
```lua
--- #231: parley's internal content — a string, or Anthropic-shaped blocks —
--- as Gemini parts. camelCase is what generateContent's REST JSON expects
--- (docs read 2026-09-12): {text=…} and {inlineData={mimeType=…, data=…}}.
local function googleai_parts(content)
    if type(content) ~= "table" then
        return { { text = content } }
    end
    local parts = {}
    for _, block in ipairs(content) do
        if block.type == "text" then
            parts[#parts + 1] = { text = block.text or "" }
        elseif block.type == "image" and block.source and block.source.type == "base64" then
            parts[#parts + 1] = { inlineData = { mimeType = block.source.media_type, data = block.source.data } }
        else
            logger.warning("googleai.format_payload: dropping unsupported content block of type " .. tostring(block.type))
        end
    end
    return parts
end
```
and in `format_payload` replace the parts assignment and the merge:
```lua
        if message.content then
            messages[i].parts = googleai_parts(message.content)
            messages[i].content = nil
        end
    end

    -- Merge consecutive same-role messages (Google API requirement): append
    -- the whole parts list, so an image part survives the merge (#231).
    local i = 1
    while i < #messages do
        if messages[i].role == messages[i + 1].role then
            for _, part in ipairs(messages[i + 1].parts or {}) do
                table.insert(messages[i].parts, part)
            end
            table.remove(messages, i + 1)
        else
            i = i + 1
        end
    end
```

- [ ] **Step 4: Run to verify it passes** — `tests/unit/wire_images_spec.lua` PASS; then
`tests/unit/dispatcher_spec.lua`, `tests/unit/parley_harness_golden_spec.lua`,
`tests/integration/openai_tool_loop_spec.lua` still PASS (text-only shapes
unchanged).

- [ ] **Step 5: Commit**

```bash
git add lua/parley/tools/wire_openai.lua lua/parley/providers.lua tests/unit/wire_images_spec.lua
git commit -m "#231 M1: image blocks reach every wire in its own shape

anthropic passes through; openai gets image_url data-URL parts; googleai's
parts mapping becomes block-aware and its merge appends whole lists.

Co-Authored-By: Claude Fable 5.1 <noreply@anthropic.com>"
```

### Task 8: M1 gate — atlas, traceability, lint, full suite, milestone close

**Files:**
- Create: `atlas/chat/attachments.md` (the M1 text below; Task 11 appends the M2 lines)
- Modify: `atlas/index.md` (§1 line), `atlas/traceability.yaml` (key `chat/attachments`, M1 files only)
- Modify: `workshop/issues/000231-*.md` (`## Plan` retagged `M1 —`/`M2 —`, ticks, `## Log`)

- [ ] **Step 1: Write the atlas document (M1 content)**

```markdown
# Chat Attachments (assets)

The transcript is the index; `<chat-dir>/assets/<chat-timestamp>/` holds only
bytes a transcript line references. Keyed by the chat's timestamp, never its
slug: `ParleySlug` renames nothing here, and the folder moves with its chat.

## Surface
- `<M-v>` (`paste_image`, `parley_buffer` scope, n/i): reads a PNG off the
  clipboard, saves it as `assets/<ts>/<stamp>.png`, inserts `![](assets/<ts>/<stamp>.png)`
  on its own line after the cursor line. Declines with a message when the
  clipboard holds no image, when no tool is found (names what to install),
  when the buffer is not a timestamp-named chat, or when a paste is already in
  flight for that buffer. A buffer closed before the tool answers discards the
  image — no bytes without a transcript line.
- `config.assets.clipboard_cmd`: an argv list with a `{out}` token; overrides
  the platform recipe (`osascript` on macOS, `wl-paste`/`xclip` on Linux).
  Contract: exit 0 + non-empty file = image; exit 0 + empty, or exit 1 = no
  image; else failure with stderr shown.

## Model
- `lua/parley/assets.lua` — layout, link, attachment grammar, content blocks,
  and THE writer (`save`); `read`/`move_with`/`delete_with`/`copy_into` behind
  one injectable io. #239 (model-generated images) calls the same writer.
- `lua/parley/clipboard_image.lua` — recipes as data; one classify rule;
  `vim.system` seam. `lua/parley/paste_image.lua` — the async, extmark-anchored flow.
- Parser: a line that is exactly `![…](assets/<ts>/<name>.<png|jpg|jpeg|gif|webp>)`
  inside a QUESTION is `question.attachments[]`; anywhere else it is prose.
- `build_messages`: a preserved question becomes image blocks (Anthropic
  shape) then one text block; wires translate — openai `image_url` data URL,
  googleai `inlineData`. Unreadable or >10 MB files become a one-line note.
- Memory: attachments do NOT pin an exchange; a summarized question's
  placeholder gains "[An image was attached to this question; it is no longer included.]".
  An ancestor chat's attachment (tree-of-chat context) reaches the model as
  its link text only.
- Logs: `parley.log` and the raw-mode logs receive `assets.elide_image_data`
  output — `<image/png, N bytes>` in place of the base64 — at all three sinks.

## Lifecycle
An asset lives as long as a transcript line references it, and is removed
with its chat. A link line deleted by hand leaves the file until then; there
is no sweep. Logs never hold the bytes.

## Tests
`tests/unit/assets_spec.lua`, `clipboard_image_spec.lua`, `wire_images_spec.lua`;
`tests/integration/paste_image_spec.lua` (fixture `tests/fixtures/fake_clipboard`
models osascript).
```
Index §1 line: `- [Chat Attachments](chat/attachments.md): \`<M-v>\` pastes a clipboard image into \`assets/<chat-timestamp>/\`; a question's image links are sent to every wire and follow the memory window.`

- [ ] **Step 2: Route the M1 specs** (the `:676` guard fails otherwise; every path must exist)

```yaml
  chat/attachments:
    code:
      - lua/parley/assets.lua
      - lua/parley/clipboard_image.lua
      - lua/parley/paste_image.lua
      - lua/parley/chat_parser.lua
      - lua/parley/chat_respond.lua
      - lua/parley/providers.lua
      - lua/parley/tools/wire_openai.lua
      - lua/parley/init.lua
      - lua/parley/config.lua
      - lua/parley/keybinding_registry.lua
    tests:
      - tests/unit/assets_spec.lua
      - tests/unit/clipboard_image_spec.lua
      - tests/unit/wire_images_spec.lua
      - tests/unit/parse_chat_spec.lua
      - tests/unit/build_messages_spec.lua
      - tests/integration/paste_image_spec.lua
```
Tasks 9, 10 and 12 append their own files to this key when they create them.

- [ ] **Step 3: Retag the issue's `## Plan`**

The issue's Plan rows carry no `Mx` tag today. Retag: the clipboard seam,
write+insert, parser, build_messages, memory-window and keybinding rows
become `- [x] M1 — …`; the ChatMove/export row becomes `- [ ] M2 — …`, and add
`- [ ] M2 — atlas + README + live conformance`. (The plan-check gate reads
these tags at `milestone-close`.)

- [ ] **Step 4: Run everything**

Run: `make lint && make test`
Expected: green, including `tests/arch/single_source_sweeps_spec.lua` (every
new `M.` export above has a Core-concepts row) and `untrusted_path_spec.lua`
(no `vim.fn.expand`/`glob` was added).

- [ ] **Step 5: Manual check on this machine** (osascript, real clipboard, real wires)

1. Copy any image (e.g. `⌘⇧4` a region, or copy an image from a browser).
2. In a chat buffer, `<M-v>` on the question line.
3. Expect: a new line `![](assets/<ts>/<stamp>.png)` under the cursor, the file
   under `<chat-dir>/assets/<ts>/`, and `:MarkdownPreview` showing it.
4. Copy some text, `<M-v>` again: expect "nothing pasted — no image on the
   clipboard (…expected type…)" and no new file.
5. **Send it, per wire family.** The spec warns a wrong envelope fails with a
   400 at runtime, and the unit specs only assert parley's own payload table.
   With the pasted question "What is in this image?", respond once with an
   agent on each family configured on this machine — anthropic, openai,
   googleai, and cliproxy (the daily route) — and confirm the model describes
   the picture. Before sending, re-read the Anthropic vision page for the
   per-image cap `MAX_BYTES` rests on (it has been quoted lower than the Files
   API limit before). Record each family's result in `## Log`; a family with
   no key on this machine is recorded as "not exercised", not assumed.
6. `tail -c 2000 <state_dir>/parley.log` after the send: the debug line shows
   `<image/png, N bytes>`, never base64.

- [ ] **Step 6: Commit docs, log, close M1**

```bash
git add atlas/chat/attachments.md atlas/index.md atlas/traceability.yaml workshop/issues/000231-*.md
git commit -m "#231 M1: atlas — chat attachments; traceability; plan retagged M1/M2

Co-Authored-By: Claude Fable 5.1 <noreply@anthropic.com>"
sdlc milestone-close --issue 231 --milestone M1
```
Fix Critical/Important findings before proceeding; record the verdict in `## Log`.

---

## Chunk 4: M2 — the folder follows the chat; export; docs; live conformance (Tasks 9–12)

### Task 9: every mover carries the folder; every deleter removes it

**Files:**
- Modify: `lua/parley/init.lua` (`move_chat` `:3209-3247`; `delete_chat_tree` `:3506`; `move_chat_tree` `:3529`; `cmd.ChatDelete` `:3862-3883`; `md_delete_file` `:2946-2955`; new `M.delete_chat_file`)
- Modify: `lua/parley/chat_finder.lua` (`:215`, `:289`)
- Create: `tests/arch/chat_delete_sweep_spec.lua`
- Test: `tests/integration/chat_move_spec.lua` (append)

- [ ] **Step 1: Append the M2 rows to the plan's Core-concepts tables, then write the failing tests**

Pure entities: `| \`removal_note\` | \`lua/parley/assets.lua\` | new |`.
Integration points: `| \`delete_chat_file\` | \`lua/parley/init.lua\` | new | \`assets.delete_with\` + \`helpers.delete_file\` |`,
and replace "the one delete door (Task 9)" on the three sibling rows with
`` `delete_chat_file` ``. (The document-wide symbol guard needs the names to
exist in the tree; this is the commit where they do.)

```lua
-- append inside describe("chat move") in tests/integration/chat_move_spec.lua
    local assets = require("parley.assets")
    local TS = "2026-09-10.14-20-03.112"

    local function seed_assets(dir)
        vim.fn.mkdir(dir .. "/assets/" .. TS, "p")
        assets.default_io.write(dir .. "/assets/" .. TS .. "/a.png", "A")
    end

    it("ChatMove carries the tree's assets folder and the link still resolves", function()
        local _, old_path = create_chat(TS .. "_move-assets.md")
        vim.fn.writefile({ "![](assets/" .. TS .. "/a.png)" }, old_path, "a")
        seed_assets(primary_dir)

        parley.cmd.ChatMove({ args = secondary_dir })

        local new_path = secondary_dir .. "/" .. TS .. "_move-assets.md"
        assert.equals(1, vim.fn.filereadable(new_path))
        assert.equals(0, vim.fn.isdirectory(primary_dir .. "/assets/" .. TS))
        assert.equals("A", assets.read(new_path, "assets/" .. TS .. "/a.png"))
    end)

    it("the single-file mover carries the folder too", function()
        local _, old_path = create_chat(TS .. "_single.md")
        seed_assets(primary_dir)

        local new_path, err = parley.move_chat(old_path, secondary_dir)

        assert.is_not_nil(new_path, err)
        assert.equals(0, vim.fn.isdirectory(primary_dir .. "/assets/" .. TS))
        assert.equals("A", assets.read(new_path, "assets/" .. TS .. "/a.png"))
    end)

    it("a tree move refuses when the target already has that assets folder, before moving anything", function()
        local _, old_path = create_chat(TS .. "_clash.md")
        seed_assets(primary_dir)
        vim.fn.mkdir(secondary_dir .. "/assets/" .. TS, "p")

        local new_path, err = parley.move_chat_tree(old_path, secondary_dir)

        assert.is_nil(new_path)
        assert.matches("asset folder already exists", err)
        assert.equals(1, vim.fn.filereadable(old_path), "nothing moved")
        assert.equals(1, vim.fn.isdirectory(primary_dir .. "/assets/" .. TS))
    end)

    it("deleting a tree removes its assets folders", function()
        local buf = create_chat(TS .. "_del.md")
        seed_assets(primary_dir)
        local confirm = vim.fn.confirm
        vim.fn.confirm = function() return 1 end
        local ok, err = pcall(parley.delete_chat_tree, buf)
        vim.fn.confirm = confirm
        assert.is_true(ok, err)
        assert.equals(0, vim.fn.isdirectory(primary_dir .. "/assets/" .. TS))
    end)

    it(":ParleyChatDelete removes the folder with the file", function()
        local _, path = create_chat(TS .. "_cmd-del.md")
        seed_assets(primary_dir)
        local saved = parley.config.chat_confirm_delete
        parley.config.chat_confirm_delete = false
        parley.cmd.ChatDelete()
        parley.config.chat_confirm_delete = saved
        assert.equals(0, vim.fn.filereadable(path))
        assert.equals(0, vim.fn.isdirectory(primary_dir .. "/assets/" .. TS))
    end)

    it("the finder's tree delete removes the folders", function()
        local _, path = create_chat(TS .. "_finder-del.md")
        seed_assets(primary_dir)
        -- The handler ends by re-opening the finder on a 100 ms timer
        -- (chat_finder.lua:302 → _reopen_chat_finder → vim.defer_fn); stub it
        -- as tests/unit/chat_finder_logic_spec.lua:128 does, so no effect
        -- outlives this case.
        local saved_reopen = parley._reopen_chat_finder
        parley._reopen_chat_finder = function() end
        local ok, err = pcall(require("parley.chat_finder").handle_delete_tree_response,
            "y", path, { path }, 1, 1, nil, nil, nil)
        parley._reopen_chat_finder = saved_reopen
        assert.is_true(ok, err)
        assert.equals(0, vim.fn.filereadable(path))
        assert.equals(0, vim.fn.isdirectory(primary_dir .. "/assets/" .. TS))
    end)

    it(":ParleyChatDelete's prompt names the folder it will remove", function()
        local _, path = create_chat(TS .. "_prompt.md")
        seed_assets(primary_dir)
        local saved_confirm, saved_input = parley.config.chat_confirm_delete, vim.ui.input
        parley.config.chat_confirm_delete = true
        local prompt
        vim.ui.input = function(opts, on_done) prompt = opts.prompt on_done("y") end
        local ok, err = pcall(parley.cmd.ChatDelete)
        parley.config.chat_confirm_delete, vim.ui.input = saved_confirm, saved_input
        assert.is_true(ok, err)
        assert.matches(" and assets/" .. TS:gsub("%-", "%%-"):gsub("%.", "%%.") .. "/ %(1 file%)", prompt)
        assert.equals(0, vim.fn.filereadable(path))
        assert.equals(0, vim.fn.isdirectory(primary_dir .. "/assets/" .. TS))
    end)
```
`tests/unit/chat_finder_logic_spec.lua` Group E keeps passing unchanged: it
stubs `M.helpers.delete_file`, which `delete_chat_file` resolves at call time,
and `assets.delete_with("/tmp/chat-b.md")` is a no-op for a non-timestamp name.

```lua
-- tests/arch/chat_delete_sweep_spec.lua
--
-- #231: a chat is deleted through ONE door. `helpers.delete_file` on a chat
-- path orphans `assets/<ts>/`, so exactly one call may exist in lua/parley/**:
-- the one inside M.delete_chat_file. A count assertion, not an allow-list:
-- tests/arch/arch_helper.lua:assert_pattern_scoping is file-granular and
-- cannot say "one call inside one function".
--
-- Enumerated and excluded, with reasons:
--   dispatcher.lua    — deletes query-cache JSON, never a chat
--   issue_finder.lua  — deletes issue files (workshop/issues), never a chat
--   note_finder.lua   — deletes notes, never a timestamp chat
--   init.lua:1438 os.remove(last) — the legacy <chat_dir>/last.md state file
local EXCLUDED = {
    ["lua/parley/dispatcher.lua"] = "query cache",
    ["lua/parley/issue_finder.lua"] = "issues",
    ["lua/parley/note_finder.lua"] = "notes",
}

describe("chat deletion goes through delete_chat_file (#231)", function()
    it("exactly one helpers.delete_file call exists, inside M.delete_chat_file", function()
        local hits = {}
        for _, file in ipairs(vim.fn.glob("lua/parley/**/*.lua", false, true)) do
            if not EXCLUDED[file] then
                local n, inside_door = 0, false
                for line in io.lines(file) do
                    n = n + 1
                    if line:match("^M%.delete_chat_file = function") then inside_door = true end
                    if inside_door and line:match("^end%s*$") then inside_door = false end
                    if line:find("helpers.delete_file(", 1, true) then
                        hits[#hits + 1] = { site = file .. ":" .. n, in_door = inside_door and file == "lua/parley/init.lua" }
                    end
                end
            end
        end
        assert.equals(1, #hits, "sites: " .. vim.inspect(vim.tbl_map(function(h) return h.site end, hits))
            .. " — call M.delete_chat_file / _parley.delete_chat_file instead")
        assert.is_true(hits[1].in_door, "the one call must be inside M.delete_chat_file: " .. hits[1].site)
    end)
end)
```
Verify the guard goes red for the right reason: with the five call sites still
in place it must report six hits; restore one after the sweep and it must
report two. (lessons.md: a guard is finished when you have seen it red.)

- [ ] **Step 2: Run to verify it fails** — folders stay under `primary_dir`; the sweep counts five sites; the prompt lacks the note.

- [ ] **Step 3: Implement**

`assets.lua` (append; pure given `io_`):
```lua
--- The suffix a single-file delete prompt appends when the chat owns a
--- folder: " and assets/<ts>/ (N files)". Empty when there is nothing more
--- to remove — the operator consents to what the prompt names.
function M.removal_note(chat_path, io_)
    io_ = io_ or M.default_io
    local folder = M.folder_for(chat_path)
    if not folder or not io_.exists(folder) then
        return ""
    end
    return " and " .. M.relative_path(M.key_for(chat_path), "") .. " (" .. #io_.list(folder) .. " files)"
end
```
Unit test (append to `assets_spec.lua`'s "move, delete, copy" describe):
```lua
    it("removal_note names the folder and its count, or nothing", function()
        assert.equals(" and assets/" .. TS .. "/ (2 files)", assets.removal_note(CHAT, seeded()))
        assert.equals("", assets.removal_note(CHAT, fake_io()))
        assert.equals("", assets.removal_note("/roots/notes/todo.md", seeded()))
    end)
```

`init.lua`, next to `delete_chat_tree`:
```lua
-- #231: THE door for deleting a chat file — the assets folder goes with it.
-- delete_with is a no-op for a non-timestamp name, so every caller is safe.
-- tests/arch/chat_delete_sweep_spec.lua allows exactly one helpers.delete_file
-- call in lua/parley/**, this one.
M.delete_chat_file = function(path)
	require("parley.assets").delete_with(path)
	M.helpers.delete_file(path)
end
```
The four single/tree prompts gain the note (`assets` required locally at each):
```lua
-- cmd.ChatDelete (:3878)
	vim.ui.input({ prompt = "Delete " .. file_name .. require("parley.assets").removal_note(file_name) .. "? [y/N] " }, function(input)
-- md_delete_file (:2950)
					local choice = vim.fn.confirm("Delete " .. rel .. require("parley.assets").removal_note(file) .. "?", "&Yes\n&No", 2)
-- chat_finder.prompt_delete_confirmation (:273)
	vim.ui.input({ prompt = "Delete " .. item_value .. require("parley.assets").removal_note(item_value) .. "? [y/N] " }, function(input)
-- chat_finder.prompt_delete_tree_confirmation (:338-341): append each file's note
	for _, f in ipairs(tree_files) do
		table.insert(rel_files, vim.fn.fnamemodify(f, ":~:.") .. require("parley.assets").removal_note(f))
	end
```
`delete_chat_tree` — list the folders and use the door:
```lua
	local assets = require("parley.assets")
	local folders = {}
	for _, f in ipairs(tree_files) do
		local folder = assets.folder_for(f)
		if folder and vim.fn.isdirectory(folder) == 1 then
			folders[#folders + 1] = folder
		end
	end
	local msg = "Delete " .. #tree_files .. " chat file(s) in tree rooted at " .. root_rel
		.. (#folders > 0 and (" and " .. #folders .. " assets folder(s)") or "") .. "?\n\n"
	for _, f in ipairs(tree_files) do
		msg = msg .. "  " .. vim.fn.fnamemodify(f, ":~:.") .. "\n"
	end
	for _, d in ipairs(folders) do
		msg = msg .. "  " .. vim.fn.fnamemodify(d, ":~:.") .. "/\n"
	end
	local choice = vim.fn.confirm(msg, "&Yes\n&No", 2)
	if choice == 1 then
		for _, f in ipairs(tree_files) do
			M.delete_chat_file(f)
		end
	end
```
`cmd.ChatDelete` (`:3873`, `:3880`) and `md_delete_file` (`:2952`): replace
`M.helpers.delete_file(file_name)` / `(file)` with `M.delete_chat_file(...)`.
`chat_finder.lua:215` and `:289`: replace `_parley.helpers.delete_file(x)` with
`_parley.delete_chat_file(x)`.

`move_chat` (`:3225-3234`): after the `.md` conflict check, before the rename:
```lua
	-- #231: the assets folder moves with its chat; a clash is refused before
	-- the .md moves, so a refusal leaves everything in place.
	local assets = require("parley.assets")
	local folder, clash = assets.move_conflict(resolved_file, target_root)
	if not folder and clash then
		return nil, clash
	end
```
and after `sync_moved_chat_buffers(resolved_file, target_file)`, carry the
folder but let the state refresh and file tracking (`:3238-3244`) complete
first — the `.md` move stays done and the state must follow it (the same rule
`move_chat_tree` applies below):
```lua
	local carried, aerr = assets.move_with(resolved_file, target_file)
	-- … the existing refresh_state / track_file_access lines stay here …
	if not carried then
		return nil, "moved the chat but not its assets: " .. aerr
	end
	return target_file
```
`move_chat_tree` — after the `.md` conflict loop (`:3556`):
```lua
	-- #231: refuse an assets clash BEFORE any .md moves.
	local assets = require("parley.assets")
	for _, src in ipairs(tree_files) do
		local folder, clash = assets.move_conflict(src, target_root)
		if not folder and clash then
			return nil, clash
		end
	end
	local asset_errors = {}
```
and in the move loop, after `sync_moved_chat_buffers(src, path_map[src])`:
```lua
		local carried, aerr = assets.move_with(src, path_map[src])
		if not carried then
			-- Keep going: the .md moves and the 🌿 rewrite below must still
			-- complete; report every stranded folder at the end.
			asset_errors[#asset_errors + 1] = aerr
		end
```
and at the function's end, before the final `return`:
```lua
	if #asset_errors > 0 then
		return nil, "moved the tree but not every assets folder: " .. table.concat(asset_errors, "; ")
	end
```
(The pre-check makes the "already exists" case unreachable here; what remains
is a cross-device or permission failure, which the `.md` rename would have hit
first. Reporting rather than aborting keeps the tree's references consistent.)

- [ ] **Step 4: Run to verify it passes** — `tests/unit/assets_spec.lua`, `tests/integration/chat_move_spec.lua`, `tests/unit/chat_finder_logic_spec.lua` (unchanged, still green) and `tests/arch/chat_delete_sweep_spec.lua` PASS. Append both new spec paths and `lua/parley/chat_finder.lua` to the `chat/attachments` traceability key.

- [ ] **Step 5: Commit**

```bash
git add lua/parley/assets.lua lua/parley/init.lua lua/parley/chat_finder.lua tests/unit/assets_spec.lua tests/integration/chat_move_spec.lua tests/arch/chat_delete_sweep_spec.lua atlas/traceability.yaml
git commit -m "#231 M2: both movers carry assets/<ts>/; all five deleters remove it

One door for chat deletion, guarded by an arch sweep that allows exactly one
helpers.delete_file call; every delete prompt names the folder it removes;
one conflict rule shared by the pre-check and the move.

Co-Authored-By: Claude Fable 5.1 <noreply@anthropic.com>"
```

### Task 10: tree export copies the folder; HTML renders the image

**Files:**
- Modify: `lua/parley/exporter.lua` (`simple_markdown_to_html` `:339`; `html_css` `:446`; `export_tree` `:868`)
- Test: `tests/unit/exporter_tree_spec.lua` (append), `tests/integration/tree_export_spec.lua` (append)

- [ ] **Step 1: Write the failing tests**

```lua
-- append to tests/unit/exporter_tree_spec.lua
describe("images in simple_markdown_to_html (#231)", function()
    local exporter = require("parley.exporter")
    it("converts a bare image link to an img tag that no inline rule can mangle", function()
        local html = exporter.simple_markdown_to_html("![a_b](assets/2026-09-10.14-20-03.112/x_y.png)")
        assert.is_not_nil(html:find('<img src="assets/2026-09-10.14-20-03.112/x_y.png" alt="a_b" class="asset-image">', 1, true), html)
        assert.is_nil(html:find("<em", 1, true))
    end)
    it("escapes quotes in alt and src", function()
        local html = exporter.simple_markdown_to_html('![say "hi"](a"b.png)')
        assert.is_not_nil(html:find('alt="say &quot;hi&quot;"', 1, true), html)
        assert.is_not_nil(html:find('src="a&quot;b.png"', 1, true), html)
    end)
end)
```
```lua
-- append inside the outer describe in tests/integration/tree_export_spec.lua
	describe("Group E: assets (#231)", function()
		local TS = "2026-09-10.14-20-03.112"
		local function chat_with_image()
			local path = create_chat_file(TS .. "_img.md",
				"---\ntopic: Img\nfile: " .. TS .. "_img.md\n---\n💬: see\n\n![](assets/" .. TS .. "/a.png)\n\n🤖: ok\n")
			vim.fn.mkdir(tmpdir .. "/assets/" .. TS, "p")
			require("parley.assets").default_io.write(tmpdir .. "/assets/" .. TS .. "/a.png", "A")
			vim.cmd("edit " .. path)
			return path
		end

		it("E1: markdown export copies the assets folder beside the files", function()
			chat_with_image()
			M.cmd.ExportMarkdown()
			assert.equals(1, vim.fn.filereadable(export_markdown_dir .. "/assets/" .. TS .. "/a.png"))
			assert.equals(1, vim.fn.filereadable(tmpdir .. "/assets/" .. TS .. "/a.png"), "source kept")
			vim.cmd("bdelete!")
		end)

		it("E2: HTML export renders the image and copies the folder", function()
			chat_with_image()
			M.cmd.ExportHTML()
			local html = table.concat(vim.fn.readfile(export_html_dir .. "/" .. TS:sub(1, 10) .. "-img.html"), "\n")
			assert.is_not_nil(html:find('<img src="assets/' .. TS .. '/a.png"', 1, true), html)
			assert.is_not_nil(html:find(".asset-image", 1, true))
			assert.equals(1, vim.fn.filereadable(export_html_dir .. "/assets/" .. TS .. "/a.png"))
			vim.cmd("bdelete!")
		end)
	end)
```
The expected HTML name is a verified fact: `extract_date` takes the
`YYYY-MM-DD` from the basename, `sanitize_title("Img")` gives `img`, and
`build_link_map` joins them as `2026-09-10-img.html`.

- [ ] **Step 2: Run to verify it fails.**

- [ ] **Step 3: Implement**

`simple_markdown_to_html`: an opaque placeholder, the same mechanism the
branch links use (`XBRANCHX<n>XBRANCHX`, `:282`), because every inline rule
runs over the whole string and would mangle an early `<img>`. Right after the
HTML escaping (`:346`):
```lua
	-- #231: image links become opaque tokens FIRST, and <img> tags LAST — the
	-- `_…_` italic rule (and every other inline rule) runs over the whole
	-- string, so an early <img> would get <em> inside its attributes. Same
	-- mechanism as the branch placeholders. Function replacements: alt/src are
	-- user text (a `%` in a string replacement corrupts silently, #214 BR-34).
	local images = {}
	html = html:gsub("!%[([^%]]*)%]%(([^%)%s]+)%)", function(alt, src)
		images[#images + 1] = '<img src="' .. src:gsub('"', "&quot;")
			.. '" alt="' .. alt:gsub('"', "&quot;") .. '" class="asset-image">'
		return "XIMGX" .. #images .. "XIMGX"
	end)
```
and at the very end of the function, after the last cleanup gsub, before `return html`:
```lua
	for n, tag in ipairs(images) do
		local function repl() return tag end
		-- gsub-safe: function replacement (#214 BR-34)
		html = html:gsub("<p[^>]*>%s*XIMGX" .. n .. "XIMGX%s*</p>", repl)
		html = html:gsub("XIMGX" .. n .. "XIMGX", repl)
	end
```
(`src:gsub(...)` inside a `..` chain is truncated to its first value, so no
wrapping is needed.) In `html_css` add: `.asset-image { max-width: 100%; height: auto; }`.
In `export_tree`, inside the per-info loop after `write_fn` succeeds (`:872`):
```lua
			-- #231: the folder travels with the export so relative links keep
			-- resolving for an HTML export opened from disk. (A Jekyll post URL
			-- does not resolve `assets/…` relative to `_posts/`; the copy is
			-- still the right thing to ship — see atlas/export/tree_export.md.)
			require("parley.assets").copy_into(info.abs_path, export_dir)
```

- [ ] **Step 4: Run to verify it passes** — both export specs PASS. Append `lua/parley/exporter.lua`, `tests/unit/exporter_tree_spec.lua` and `tests/integration/tree_export_spec.lua` to the `chat/attachments` traceability key.

- [ ] **Step 5: Commit**

```bash
git add lua/parley/exporter.lua tests/unit/exporter_tree_spec.lua tests/integration/tree_export_spec.lua atlas/traceability.yaml
git commit -m "#231 M2: tree export copies assets/<ts>/ and renders image links in HTML

Co-Authored-By: Claude Fable 5.1 <noreply@anthropic.com>"
```

### Task 11: the M2 docs

**Files:**
- Modify: `atlas/chat/attachments.md` (append the M2 lines), `atlas/index.md`, `atlas/chat/memory.md`, `atlas/chat/format.md`, `atlas/providers/anthropic.md`, `atlas/providers/openai.md`, `atlas/providers/googleai.md`, `atlas/export/tree_export.md`, `atlas/ui/keybindings.md`, `README.md` (`:156` region)

- [ ] **Step 1: Append to `atlas/chat/attachments.md`**

Under `## Model`:
```markdown
- Movers and deleters: `move_chat` and `move_chat_tree` carry the folder
  (`assets.move_conflict` is the one clash rule; a clash is refused before any
  `.md` moves); every chat deletion goes through `delete_chat_file`
  (`tests/arch/chat_delete_sweep_spec.lua`), whose confirmations list the
  folders. Tree export copies the folder and renders `<img>` in HTML.
```
Under `## Tests`, add `tests/arch/chat_delete_sweep_spec.lua`,
`chat_move_spec.lua`, `tree_export_spec.lua`, and
`clipboard_live_spec.lua (opt-in PARLEY_LIVE_CLIPBOARD=1)`.

- [ ] **Step 2: The one-liners**

- `atlas/index.md` §1: extend the line with "; the folder travels with ChatMove and export and dies with the chat."
- `atlas/chat/memory.md` Preservation Rules: add `- NOT image attachments — they drop with their exchange; the placeholder notes one was there.`
- `atlas/chat/format.md`: under the markers list, `![](assets/<ts>/<file>)` on its own line in a question = attachment.
- `atlas/providers/{anthropic,openai,googleai}.md`: one line each naming the image shape (see Facts).
- `atlas/export/tree_export.md`: "assets/<ts>/ is copied beside the exported files; HTML renders `<img>`; relative links resolve for an HTML export opened from disk, not from a Jekyll `_posts/` URL."
- `atlas/ui/keybindings.md`: add `paste_image` with `<M-v>` to the alt-family sentence.
- `README.md` near `:156`: `- \`<M-v>\` paste the clipboard image as an attachment of the question (saved under \`assets/<chat-timestamp>/\`).`

- [ ] **Step 3: Run the doc guards** — `make test` (traceability + index guards).

- [ ] **Step 4: Commit**

```bash
git add atlas README.md
git commit -m "#231 M2: atlas — movers/deleters, memory rule, wire shapes, keys

Co-Authored-By: Claude Fable 5.1 <noreply@anthropic.com>"
```

### Task 12: live conformance (opt-in), close

**Files:**
- Create: `tests/integration/clipboard_live_spec.lua`
- Modify: `atlas/traceability.yaml` (append the live spec)

- [ ] **Step 1: Write the opt-in live check**

```lua
-- tests/integration/clipboard_live_spec.lua
--
-- Conformance: the REAL macOS recipe against the REAL clipboard. Opt-in
-- (PARLEY_LIVE_CLIPBOARD=1) because it replaces the clipboard's contents; it
-- restores any text it found. Skips on non-Darwin hosts.
local ci = require("parley.clipboard_image")

describe("clipboard recipe conformance (live, opt-in)", function()
    it("reads back a PNG placed on the clipboard, and declines text", function()
        if os.getenv("PARLEY_LIVE_CLIPBOARD") ~= "1" then
            pending("set PARLEY_LIVE_CLIPBOARD=1 to run against the real clipboard")
            return
        end
        local env = ci.host_env()
        if env.sysname ~= "Darwin" then
            pending("the live check models osascript; this host is " .. env.sysname)
            return
        end
        local repo = vim.fn.fnamemodify(debug.getinfo(1, "S").source:sub(2), ":p:h:h:h")
        local png = repo .. "/tests/fixtures/one_pixel.png"

        -- Save what is there (text only; a non-text clipboard errors → skip restore).
        local saved = vim.fn.system({ "osascript", "-e", "the clipboard as text" })
        local had_text = vim.v.shell_error == 0
        saved = saved:gsub("\n$", "")
        local function restore()
            if had_text then
                vim.fn.system({ "osascript", "-e", "on run argv", "-e", "set the clipboard to (item 1 of argv)", "-e", "end run", saved })
            end
        end

        local function read_once()
            local out = vim.fn.tempname() .. ".png"
            local status, msg
            ci.read_png(ci.RECIPES.darwin, out, function(s, m) status, msg = s, m end)
            vim.wait(ci.TIMEOUT_MS + 500, function() return status ~= nil end, 20)
            local bytes = require("parley.assets").default_io.read(out)
            os.remove(out)
            return status, msg, bytes
        end

        local ok, err = pcall(function()
            vim.fn.system({ "osascript", "-e", "on run argv",
                "-e", "set the clipboard to (read (POSIX file (item 1 of argv)) as «class PNGf»)", "-e", "end run", png })
            local status, msg, bytes = read_once()
            assert.equals("ok", status, msg)
            assert.is_true(bytes ~= nil and bytes:sub(1, 8) == "\137PNG\r\n\26\n", "a PNG came back")

            vim.fn.system({ "osascript", "-e", "set the clipboard to \"plain text\"" })
            status, msg = read_once()
            assert.equals("no_image", status)
            assert.matches("expected type", msg)
        end)
        restore()
        assert(ok, err)
    end)
end)
```
Append `tests/integration/clipboard_live_spec.lua` to the `chat/attachments`
traceability key.

- [ ] **Step 2: Run it live once on this machine**

Run: `PARLEY_LIVE_CLIPBOARD=1 nvim -n --headless --noplugin -u tests/minimal_init.vim -c "PlenaryBustedFile tests/integration/clipboard_live_spec.lua" -c "qa!"`
Expected: PASS (outside the agent sandbox, which blocks the clipboard
service). Record the run in `## Log`.

- [ ] **Step 3: Full suite and lint** — `make lint && make test` green.

- [ ] **Step 4: Commit, tick the remaining `## Plan` rows, close**

```bash
git add tests/integration/clipboard_live_spec.lua atlas/traceability.yaml
git commit -m "#231 M2: live clipboard conformance (opt-in)

Co-Authored-By: Claude Fable 5.1 <noreply@anthropic.com>"
sdlc milestone-close --issue 231 --milestone M2
sdlc close --issue 231 --verified '<the make test line, the manual <M-v> check, the live spec run>'
```

## Future extensions

- **#239** calls `assets.save` from the stream sink and `assets.question_content`
  for model-role images on wires that accept them.
- **Notes**: widening `key_for` to non-timestamp basenames is the one place a
  notes-side paste would change; the orphan-on-rename question must be answered
  first.
- **An orphan sweep**, if residue ever matters: files in `assets/<ts>/` not
  named by any `![](…)` line of `<ts>*.md`; it lives in `assets`.
- **A `target`** for the invariant "the transcript is the index; sidecars hold
  only referenced bytes, keyed by chat timestamp" (`workshop/targets/`) — worth
  writing once #231 lands, so #239 and later binary kinds defend it.
- **Anthropic Files API**: for long conversations with many images, upload once
  and reference by `file_id` instead of re-sending base64 per turn; the block
  builder is the single place to switch.

## Revisions

### 2026-09-12 — after the first plan-document review (two reviewers, one per chunk)

- **Reason:** review findings, all verified against the tree.
- **Delta:** (1) `assets.save` and `question_content` share one size sentence
  (`too_big`); the oversized-save test asserted a word the message did not
  contain. (2) `reg.entries` is a table. (3) ARCH-ORDER section added; the paste
  now checks buffer validity **before** saving (the first draft orphaned bytes
  when the buffer closed mid-read), refuses a second in-flight paste per buffer,
  re-reads the chat path at completion; two specs pin it (`slow:` fixture
  state added). (4) ARCH-FUNERAL section added; the orphan residue and the
  no-sweep decision are stated. (5) `M.move_chat` is a second, independent
  mover, not a wrapper — both movers now carry the folder behind one shared
  `assets.move_conflict`; the tree mover collects asset errors and finishes the
  🌿 rewrite. (6) Chat deletion has five sites — one `delete_chat_file` door
  replaces `helpers.delete_file` at all of them, with an arch sweep and tests
  through `ChatDelete` and the finder. (7) The `<img>` conversion uses the
  file's placeholder mechanism, since every inline rule runs over the whole
  string (verified: the italic rule mangled the early tag); quotes are escaped.
  (8) The export test is concrete (front matter, `create_chat_file`, current
  buffer, `bdelete!`) and has an HTML sibling. (9) Traceability lists only
  files that exist at each gate; the live spec's row moves to Task 12. (10)
  Task 8 carries the M1 atlas text; Task 11 appends the M2 lines. (11) Chunks
  re-cut to ≤ ~1000 lines: capture / send / M2. (12) `chat_move_spec`'s
  scratch buffer cannot `:write`; the test appends with `writefile(…, "a")`.
  (13) The build_messages tests use the spec's own `stub_helpers`/`stub_logger`.
  (14) The live spec trims the saved text, skips restore on a non-text
  clipboard, and restores on assertion failure.

### 2026-09-12 — after the second review (three reviewers, one per chunk)

- **Reason:** round-2 findings, all verified against the tree.
- **Delta:** (1) The three log sinks (`logger.debug` at send, raw-mode
  exchange and raw logs) would have written ≈13 MB of base64 per image per
  turn: `assets.elide_image_data` at all three, with a unit test per wire
  shape and a Lifecycle line (ARCH-FUNERAL). (2) The M1 gate now sends the
  pasted question through each configured wire family and records the result;
  a docs-only shape was not evidence for "reaches every wire". (3) The finder
  tree-delete test stubs `_reopen_chat_finder` (the handler would have opened
  a real finder 100 ms after the case ended). (4) The delete sweep counts
  exactly one `helpers.delete_file` call across `lua/parley/**`, inside the
  door, with named exclusions — no comment-marker exemption. (5) All four
  single/tree delete prompts append `assets.removal_note`; a test reads the
  `ChatDelete` prompt. (6) `move_chat` finishes its state refresh before
  reporting an assets failure. (7) `fake_clipboard` is a named local in the
  spec and `chat_memory.max_full_exchanges` is dotted, so the document-wide
  symbol guard resolves every table name; the two M2-only rows are appended
  by Task 9. (8) The third-paste test waits for its link, so no paste outlives
  its case. (9) Chunks re-cut to four. (10) Smaller: `std_header` in the
  parser spec, `web_search = false` in the wire spec, `text` computed once in
  `wire_openai`, the assets require hoisted in `build_messages_from_model`, a
  held-callback unit case in `read_png`, config/insert-mode/main-loop notes,
  Ollama and ancestor-context non-goals, the fenced-code non-goal stated
  precisely, E2's filename and the `src:gsub` note stated as facts.
