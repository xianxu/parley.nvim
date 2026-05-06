---
id: 000121
status: working
deps: []
created: 2026-05-06
updated: 2026-05-06
---

# improve raw mode

Raw mode is not useful, as it operates within the buffer. it's purpose is for debugging and learning, and it should be logged to a side file. basically what is sent and what's received each turn, at two levels, the exchange level, and the raw request/response level. log them into two different files with proper formatting for both human and machine's inspection. sort of mirror structure to parley chat's transcript. 

## Done when

- The current in-buffer raw-mode behavior (request fence inserted between Q and A; response replaced with raw stream) is removed. The stale `/tmp/claude/parley-debug/` dump is removed.
- A `:Toggle…` command and a config flag turn on **side-file logging** instead. Default off.
- For each chat, two log files accumulate at `<chat-dir>/.parley-logs/<chat-basename>/{exchange.md, raw.md}`, appended to per turn (each tool-loop iteration counts as its own turn entry).
- `exchange.md` is human-readable markdown that mirrors the chat transcript: per turn → `## Turn N — <iso ts>`, then per role (`### system`, `### user`, `### assistant`) the message content.
- `raw.md` carries two sub-blocks per turn: the **assembled** request + response in YAML (copy-paste friendly), and the **raw** SSE stream lines as captured. Choice of YAML for assembled view because it round-trips cleanly with the kept input feature (see below) and is much more readable than JSON for nested structures and multi-line strings.
- The input feature (a fenced payload at the bottom of a question becomes the actual request body) is **kept**, but the on-disk format is YAML now (`\`\`\`yaml {"type":"request"}` … `\`\`\``), so the user can copy a turn's request from the raw log, paste into a new question, edit, and re-send.
- When either log toggle is on, the lualine parley section turns **red** so the user can't miss that they're in a debug-logging mode.
- `:ParleyOpenExchangeLog` and `:ParleyOpenRawLog` open the current chat's log file in a split.
- Tests cover the per-turn append shape, the YAML emitter / parser round-trip, and that the in-buffer side effects are gone.

## Spec

### Config

```lua
raw_mode = {
    enable = true,                  -- master switch (kept; if false, toggles no-op)
    log_exchange = false,           -- new: append exchange-level log per turn
    log_raw     = false,            -- new: append raw-level log per turn
    -- (parse_raw_request / show_raw_response removed entirely)
}
```

Toggles: `:ToggleExchangeLog`, `:ToggleRawLog`. (The old `:ToggleRawRequest` / `:ToggleRawResponse` command names are dropped, since their semantics no longer exist; users who scripted them will see a clear "command not found" rather than silent shifted behavior. Old `<C-g>r` / `<C-g>R` bindings stay unbound — they were freed in #120.)

### File layout

For a chat at `<chat-dir>/<basename>.md`:

```
<chat-dir>/.parley-logs/<basename>/
├── exchange.md
└── raw.md
```

The `<chat-dir>` is the chat file's actual containing directory (chat root or sub-root) — same as the chat's write location. The `.parley-logs` prefix hides from the chat finder and most directory listings.

### Exchange log format

```markdown
# Exchange log for <basename>

## Turn 1 — 2026-05-06T12:34:56Z

### system
A conversation between You and Me.

We collaboratively seek knowledge…

### user
hello

### assistant
🧠: …
hi there
📝: simple greeting

## Turn 2 — 2026-05-06T12:35:10Z
…
```

Multi-line content is inlined verbatim (no fencing — markdown headers separate sections). Tool-loop iterations are their own `## Turn` entry; their assistant content includes `🔧:` / `📎:` blocks just like the buffer.

### Raw log format

```markdown
# Raw log for <basename>

## Turn 1 — 2026-05-06T12:34:56Z

### Request payload (yaml)

\`\`\`yaml
model: claude-sonnet-4-6
max_tokens: 4096
stream: true
system:
  - type: text
    cache_control: { type: ephemeral }
    text: |
      A conversation between You and Me.
      …
messages:
  - role: user
    content: hello
tools:
  - name: web_search
    type: web_search_20260209
    max_uses: 5
\`\`\`

### Response (assembled, yaml)

\`\`\`yaml
content:
  - type: text
    text: |
      🧠: …
      hi there
      📝: simple greeting
  - type: tool_use
    id: toolu_xxx
    name: read_file
    input:
      file_path: foo.lua
stop_reason: end_turn
usage:
  input_tokens: 1000
  output_tokens: 50
\`\`\`

### Response (raw SSE)

\`\`\`
event: content_block_start
data: {"type":"content_block_start","index":0,"content_block":{"type":"text","text":""}}

event: content_block_delta
data: {"type":"content_block_delta","index":0,"delta":{"type":"text_delta","text":"🧠"}}
…
\`\`\`
```

Three sub-blocks per turn so the log captures the full picture: what we sent, what the API decided was the response (assembled), and the raw event stream that reconstructs to the assembled form.

### Input feature (kept, format change)

Today: a `\`\`\`json {"type":"request"}\n…\n\`\`\`` fence at the bottom of a question is parsed and used as the actual API payload (skipping the normal message-build path). Tomorrow: same idea, but the fence info string is `yaml {"type":"request"}` and the body is YAML. Reading from raw-log → pasting into a new turn → editing fields and submitting becomes a one-step iteration loop.

A small Python helper handles YAML ↔ Lua-table conversion (parley already shells out to `python3 -m json.tool` for pretty-printing; YAML support uses `python3 -c "import yaml; …"`). YAML emission for the log can be a small custom Lua function — emit-only is much simpler than parse — to avoid forking python on every dispatch. We only fork python for the input feature, which is rare/manual.

### Lualine indicator

When `log_exchange` or `log_raw` is true, the parley lualine section adopts a red color (probably via `color = { fg = ..., gui = "bold" }` returned alongside the section text, or via a dedicated highlight group toggled at session level). Existing `[r]` / `[R]` indicators in the section text get replaced with `[LOG-EX]` / `[LOG-RAW]` so the meaning is unmistakable.

### Removed

- In-buffer request fence insertion at `chat_respond.lua:1346-1366` (the `if … parse_raw_request and not raw_payload then …` block).
- In-buffer response replacement at `dispatcher.lua:208-218` (`qt.response = '\`\`\`json …'`).
- The unconditional `pcall` debug dump to `/tmp/claude/parley-debug/` at `chat_respond.lua:1334-1342`.
- `parse_raw_request` / `show_raw_response` config keys; the old `:ToggleRawRequest` / `:ToggleRawResponse` commands and their callbacks.

### What we're NOT changing

- The agent / messages pipeline. Logging hooks read what's already computed; they don't reshape the request or response.
- The chat buffer's own format. Logs are write-only artifacts; the chat file stays the canonical conversation.

## Plan

- [x] `lua/parley/log_emit.lua`: pure-function YAML emitter (mappings, arrays, scalars, multi-line `|` blocks, priority-key heuristic for `type/role/name`). Plus `format_exchange_turn` / `format_raw_turn` markdown helpers. 19 unit specs.
- [x] `scripts/yaml_to_json.py`: tiny PyYAML-backed helper for the input-feature parse. Test seam via `log_emit._parse_yaml_impl`.
- [x] Replace the old JSON fence input path with `yaml {"type":"request"}`. `chat_respond.lua` calls `log_emit.parse_yaml`. Build-messages tests stub the parser to keep them dependency-free.
- [x] Config: drop `parse_raw_request` / `show_raw_response`. Add `log_exchange` / `log_raw`.
- [x] Drop `:ToggleRawRequest` / `:ToggleRawResponse` / `:ToggleRaw`. Add `:ParleyToggleExchangeLog` / `:ParleyToggleRawLog`.
- [x] `lua/parley/raw_log.lua`: path resolution (`<chat-dir>/.parley-logs/<basename>/{exchange,raw}.md`), header-on-first-write, monotonic turn numbering by counting existing `## Turn ` markers. 9 unit specs.
- [x] Hook in `chat_respond.respond` completion callback. Stash `qt.usage` and `qt.stop_reason` in `dispatcher.lua` so the assembled-response YAML has metrics.
- [x] Remove in-buffer fence insertion, response replacement, and stale `/tmp/claude/parley-debug` dump. Remove now-unused `buffer_edit.insert_raw_request_fence` + its test.
- [x] Lualine: prepend a red `%#ErrorMsg# [LOG-EX|LOG-RAW] %*` flag when either toggle is on (replaces the old `[r]/[R]/[rR]` indicators).
- [x] `:ParleyOpenExchangeLog` / `:ParleyOpenRawLog` open the current chat's log in a vsplit (no-op + notify if absent).
- [x] Atlas: new `atlas/infra/raw_logging.md` with full spec; `atlas/modes/raw_mode.md` rewritten to point at it; `atlas/index.md` updated.
- [ ] Manual smoke: turn on log_raw, run a few turns including a tool-loop, verify both files materialize; copy a YAML request from raw.md into a new turn, edit, send — verify the raw input path picks it up.

## Log

### 2026-05-06

Locked at status=working. Brainstormed with user; key decisions:
- Side-file logs at `<chat-dir>/.parley-logs/<basename>/{exchange,raw}.md`, appended per turn.
- Raw log carries three sub-blocks: request (YAML), assembled response (YAML), raw SSE.
- YAML chosen over JSON for human readability + copy-paste round-trip with the kept input feature.
- All in-buffer raw-mode behavior + stale /tmp dump removed.
- Lualine section turns red when log toggles are on.
- Old `<C-g>r` / `<C-g>R` chat keys stay unbound (freed in #120); raw-mode is now toggle-only via commands.

Implementation pass complete. Surface touched:

- New: `lua/parley/log_emit.lua`, `lua/parley/raw_log.lua`, `scripts/yaml_to_json.py`, `tests/unit/log_emit_spec.lua`, `tests/unit/raw_log_spec.lua`, `atlas/infra/raw_logging.md`.
- Modified: `chat_respond.lua` (hook + remove old paths + YAML input), `dispatcher.lua` (remove raw-response fence path + stash usage/stop_reason), `init.lua` (commands), `lualine.lua` (red flag), `config.lua` (toggle keys), `buffer_edit.lua` (drop fence helper), `atlas/modes/raw_mode.md` (point to new spec), `atlas/index.md` (link).
- Test cleanup: `tests/unit/buffer_edit_spec.lua` (drop fence test), `tests/unit/dispatcher_query_spec.lua` (collapse Group B from 4 fence tests to 1 negative), `tests/unit/build_messages_spec.lua` (json→yaml fences, stub parser).
- Manual smoke pending.


