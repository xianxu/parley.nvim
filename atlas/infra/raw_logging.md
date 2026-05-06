# Raw-Mode Logging

Per-chat side-file logging of LLM API state for debugging and learning. The previous behavior — inserting JSON fences in the chat buffer and replacing the response with raw stream content — was replaced wholesale (#121); raw-mode now writes to dedicated log files and never mutates the chat transcript.

## On-disk layout

For a chat at `<chat-dir>/<basename>.md`:

```
<chat-dir>/.parley-logs/<basename>/
├── exchange.md   # message-level transcript (one ## Turn per dispatch)
└── raw.md        # request payload + assembled response + raw SSE
```

`<chat-dir>` is the chat file's containing directory (whichever chat root or sub-root it lives in). The `.parley-logs` prefix hides the directory from the chat finder and standard `ls`. Each chat gets its own sub-directory so logs grow independently.

## Toggles

```lua
raw_mode = {
    enable       = true,   -- master switch; off → toggle commands no-op
    log_exchange = false,  -- per-turn message-list log
    log_raw      = false,  -- per-turn request + response + SSE log
}
```

Commands (default off):
- `:ParleyToggleExchangeLog` — toggle `log_exchange`.
- `:ParleyToggleRawLog` — toggle `log_raw`.
- `:ParleyOpenExchangeLog` — open the current chat's `exchange.md` in a vertical split.
- `:ParleyOpenRawLog` — open `raw.md`.

When either log toggle is on, the lualine parley section gains a red `[LOG-EX]` / `[LOG-RAW]` flag (rendered via `%#ErrorMsg#…%*`) so the user can't miss that they're writing debug logs.

## Format

### `exchange.md`

```markdown
# Exchange log for <basename>

## Turn 1 — 2026-05-06T12:34:56Z

### system
…system prompt body…

### user
hello

### assistant
🧠: …
hi there
📝: simple greeting

## Turn 2 — 2026-05-06T12:35:10Z
…
```

One `## Turn N — <iso ts>` per dispatch (including each tool-loop iteration). String message content is inlined verbatim; structured (Anthropic content-blocks list) is rendered as YAML.

### `raw.md`

```markdown
# Raw log for <basename>

## Turn 1 — 2026-05-06T12:34:56Z

### Request payload (yaml)

```yaml
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
  - type: web_search_20260209
    name: web_search
    max_uses: 5
```

### Response (assembled, yaml)

```yaml
stop_reason: end_turn
content:
  - type: text
    text: |
      🧠: …
      hi there
      📝: simple greeting
usage:
  input_tokens: 1234
  output_tokens: 56
```

### Response (raw SSE)

```
event: content_block_start
data: {"type":"content_block_start","index":0,"content_block":{"type":"text","text":""}}

event: content_block_delta
data: {"type":"content_block_delta","index":0,"delta":{"type":"text_delta","text":"🧠"}}
…
```
```

Three sub-blocks per turn so each log entry stands alone: what we sent, what the API actually returned (assembled), and the byte-level SSE that reconstructs to it. Drop one or two of these by setting fewer fields when calling `raw_log.write_raw_turn`.

YAML is chosen over JSON because (a) multi-line strings via `|` keep system prompts and assistant content readable, (b) it round-trips with the input feature below.

## Input feature: typed YAML fence as raw payload

Independent of logging, a chat question may end with:

```
```yaml {"type": "request"}
model: …
messages:
  - role: user
    content: …
```
```

When the next dispatch fires, this fence is parsed as the actual API payload (skipping the normal message-build path). YAML→JSON parse shells out to a small Python helper using PyYAML. Use it to copy a turn from `raw.md`, edit a field, and re-send — handy for iterating on system prompts or tool-call shapes.

## Architecture

- `lua/parley/log_emit.lua` — pure-function YAML emitter (mappings, arrays, scalars, multi-line `|` blocks; not a full YAML 1.2 emitter — narrow scope) and the per-turn markdown formatters. Also exposes `parse_yaml(s)` with a `_parse_yaml_impl` test seam.
- `lua/parley/raw_log.lua` — file path resolution, append-with-header, monotonic turn numbering by counting existing `## Turn ` headers.
- `lua/parley/chat_respond.lua` — completion-callback hook calls `raw_log.write_*_turn` when the relevant toggle is on.
- `lua/parley/dispatcher.lua` — accumulates raw SSE into `qt.raw_response`, stashes parsed `usage` and `stop_reason` on the query object so the assembled-response YAML has metrics to emit.
- `lua/parley/lualine.lua` — `[LOG-EX]` / `[LOG-RAW]` red flag prefix.
- `scripts/yaml_to_json.py` — tiny PyYAML-backed helper for the input-feature parse.

## Trade-offs / things explicitly NOT done

- **Not a general YAML emitter.** The Lua emitter handles only the shapes parley produces. Out-of-shape values fall back to inline-quoted vim.inspect strings.
- **PyYAML dependency for input feature.** YAML emission is pure Lua (frequent — every dispatch); YAML *parsing* shells to Python (rare — only when the user types a raw fence). If PyYAML isn't installed the parse fails with a clear hint, and the rest of parley keeps working.
- **No log rotation / truncation.** Logs grow unboundedly; user deletes manually. Acceptable because the toggle is off by default and explicitly debug-scoped.
- **Tool-loop iterations get their own `## Turn`.** Easier to read; matches the API call boundary.
