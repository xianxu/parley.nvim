# Tool Use Protocol

Client-side tool loop enabling LLM agents to call tools (read/edit files, search, etc.) and receive results.

## Tool Set

Standard Unix tools exposed to Claude, plus file operations:

| Tool | Kind | Description |
|------|------|-------------|
| `read_file` | read | Read file with line numbers. Params: `file_path`, `offset`, `limit` |
| `ls` | read | Shell out to system `ls`. Param: `command` |
| `find` | read | Shell out to system `find`. Param: `command` |
| `grep` | read | Shell out to `rg` or system `grep`. Param: `command` |
| `chat_history_search` | read | Search past chats across ALL chat roots (global + repo + super-repo siblings). Output is `{<repo>}/...`-prefixed. Default context `-B1 -A2`, `*.md` glob, case-insensitive. Params: `pattern`, `before`, `after`, `glob`, `case_insensitive`, `max_count` |
| `edit_file` | write | String replacement (`old_string`/`new_string`) or line insertion (`insert_line`/`insert_text`) |
| `write_file` | write | Create/overwrite file. Numbered `.parley-backup.N` on each write |
| `ack` | read | Optional, registered only if `ack` is installed |

Tool descriptions dynamically advertise the locally available command version (e.g., "ripgrep 14.1" vs "GNU grep 3.11").

## Selecting Tools (agent config)

An agent's `tools` field is an explicit allow-list resolved by `tools.select()` (`lua/parley/tools/init.lua`). Empty/absent `tools` → the agent gets NO tools (a vanilla chat agent); there is no implicit "all" default. Each entry is either a tool name or a group sentinel:

| Selector | Expands to |
|----------|------------|
| `"@all"` | every registered tool (includes `ack` when installed) |
| `"@readonly"` | every registered non-write tool (`kind ~= "write"`; absent kind defaults to read) |

Group sentinels expand alphabetically; the combined list is de-duplicated by name (first occurrence wins), so `{ "edit_file", "@readonly" }` is safe. An unknown name or group raises at agent-config validation, naming the offending token.

## Loop Model

1. User submits → Claude responds (may include `tool_use` content blocks)
2. `tool_loop.process_response` decodes tool calls, executes each via `dispatcher.execute_call`
3. Writes 🔧: (tool call) and 📎: (tool result) blocks into the buffer via the exchange model
4. Returns `"recurse"` → `M.respond` is called again with the live model
5. `build_messages_from_model` reads content from the buffer at model positions — no re-parsing
6. Repeats until Claude responds with text only (no tool_use) → `"done"`

The chat response lease guards this loop via an extmark anchored on the response's agent-header line (#138): before the scheduled recursive `M.respond`, the lease is validated again. If the user undoes/redoes or deletes the response in that gap, the anchor invalidates and recursive resubmit is cancelled rather than inserting a new placeholder from stale live-model positions. (Pre-#138 the lease committed a new `changedtick` after appending tool blocks; the extmark anchor needs no such commit.)

## Buffer Representation

Tool blocks in the transcript:

```
🔧: read_file id=toolu_xxx
```json
{"file_path":"./ARCH.md"}
```

📎: read_file id=toolu_xxx
```
    1  # Architecture
    ...
```
```

## Safety

- **cwd-scope**: dispatcher checks both `path` and `file_path` fields against working directory. `chat_history_search` deliberately accepts neither, so it can search chat roots that live outside cwd (global iCloud dir, super-repo siblings).
- **Iteration cap**: `max_tool_iterations` (default 10) — writes synthetic `📎: (iteration limit reached)` when hit
- **Cancellation**: `cmd_stop` triggers `repair_unmatched_tool_blocks` — writes `📎: (cancelled by user)` for any 🔧: without matching 📎:
- **Backup**: `write_file` creates numbered `.parley-backup.N` on every write
- **Unknown tools**: return friendly error "Tool 'X' is not available on this client"
- **Malformed blocks**: `build_messages_from_model` degrades to text (no Anthropic rejection)
- **Buffer diagnostic**: `:lua require('parley').check_buffer()` validates invariants
- **Transcript drift**: pending chat leases cancel stale stream/tool/progress/topic callbacks after undo/redo or out-of-band edits

## Visual Treatment

- 🔧:/📎: blocks are dimmed (`ParleyThinking` highlight = `Comment`)
- Error results highlighted with `ParleyToolError` = `DiagnosticError`
- Completed tool blocks auto-folded via model-based manual folds
- Spinner shows during every API call (including recursive rounds)
