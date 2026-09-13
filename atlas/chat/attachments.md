# Chat Attachments (assets)

The transcript is the index; `<chat-dir>/assets/<chat-timestamp>/` holds only
bytes a transcript line references. Keyed by the chat's timestamp, never its
slug: `ParleySlug` renames nothing here, and the folder moves with its chat.

## Surface
- `<M-v>` (`paste_image`, `parley_buffer` scope, n/i): reads a PNG off the
  clipboard, saves it as `assets/<ts>/<stamp>.png`, inserts
  `![](assets/<ts>/<stamp>.png)` on its own line after the cursor line.
  Declines with a message when the clipboard holds no image, when no tool is
  found (names what to install), when the buffer is not a timestamp-named
  chat, or when a paste is already in flight for that buffer. A buffer closed
  before the tool answers discards the image — no bytes without a transcript
  line. The paste is asynchronous and anchored by an extmark; insert mode is
  not left.
- `config.assets.clipboard_cmd`: an argv list with a `{out}` token; overrides
  the platform recipe (`osascript` on macOS, `wl-paste`/`xclip` on Linux).
  Contract: exit 0 + non-empty file = image; exit 0 + empty, or exit 1 = no
  image; else failure with stderr shown. `setup()` replaces the `assets`
  table wholesale.

## Model
- `lua/parley/assets.lua` — layout, link, attachment grammar, request budget,
  content blocks, log elision, and THE writer (`save`) behind one injectable
  io that reports what happened (`read_bounded`, `move_with`, `delete_with`,
  `copy_into`). #239 (model-generated images) calls the same writer.
- `lua/parley/clipboard_image.lua` — recipes as data; one classify rule;
  `vim.system` seam. `lua/parley/paste_image.lua` — the async flow.
- Parser: a line that is exactly `![…](assets/<ts>/<name>.<png|jpg|jpeg|gif|webp>)`
  inside a QUESTION is `question.attachments[]`; anywhere else it is prose
  (absolute paths, `..`, URLs, backticks, inline links never resolve).
- Sending: one retention rule (`preserve_exchange`, `window_size`) shared by
  `build_messages` and the tool-loop continuation builder. A retained
  question becomes image blocks (Anthropic shape) then one text block; the
  openai wire emits `image_url` data-URL parts, googleai `inlineData`. One
  request budget (`plan_budget`): 10 MB per image, 20 MB encoded and 20 images
  per request, planned over every retained attachment, newest first; dropped
  or unreadable images become a one-line note. A final guard refuses an
  image-bearing payload that still exceeds the limit. Reads are bounded
  (`read_bounded`: stat first, then at most the cap).
- Memory: attachments do NOT pin an exchange; a summarized question's
  placeholder gains "[An image was attached to this question; it is no longer included.]".
  An ancestor chat's attachment (tree-of-chat context) reaches the model as
  its link text only.
- Logs: every logger call that serializes a request value goes through
  `elide_image_data` — `<image/png, N bytes>` in place of the base64
  (`tests/arch/log_sinks_spec.lua` enumerates the class). Transport files:
  an image-bearing request body under `query_dir` is removed on every
  terminal path of the curl job; text-only bodies keep the setup-time prune.
- Movers and deleters: `move_chat` and `move_chat_tree` carry the folder
  (`assets.move_conflict` is the one clash rule, refused before any `.md`
  moves; a carry failure is reported after the move, state refresh and 🌿
  rewrite complete); every chat deletion goes through `delete_chat_file`
  (`tests/arch/chat_delete_sweep_spec.lua` allows exactly one
  `helpers.delete_file` call), and every delete prompt appends
  `assets.removal_note` naming the folder and its file count.
- Export: tree export copies `assets/<ts>/` beside the exported files and
  HTML renders `![…](…)` as `<img class="asset-image">` (relative links
  resolve for an HTML export opened from disk, not from a Jekyll `_posts/`
  URL); a failed copy is reported.

## Lifecycle
An asset lives as long as a transcript line references it, and is removed
with its chat. A link line deleted by hand leaves the file until then; there
is no sweep. Logs never hold the bytes.

## Tests
`tests/unit/assets_spec.lua`, `clipboard_image_spec.lua`, `wire_images_spec.lua`,
`parse_chat_spec.lua`, `build_messages_spec.lua`;
`tests/integration/paste_image_spec.lua` (fixture `tests/fixtures/fake_clipboard`
models osascript through the config seam); `tests/integration/chat_move_spec.lua`,
`tree_export_spec.lua`, `query_cache_spec.lua`; `tests/arch/log_sinks_spec.lua`,
`chat_delete_sweep_spec.lua`; `tests/integration/clipboard_live_spec.lua`
(opt-in `PARLEY_LIVE_CLIPBOARD=1`, darwin, real recipe on the real clipboard).
