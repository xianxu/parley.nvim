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

- **cwd-scope**: dispatcher (`resolve_path_in_cwd`) checks `path`, `file_path`, and every element of `paths` against the working directory, symlink-resolved (`fs_realpath`), so a symlink whose real path escapes is rejected. Read tools (`kind ~= "write"`, so an absent `kind` counts as read — same predicate as `@readonly`) may additionally reach any root in the global `tool_read_roots` config — entries are absolute (`/x`), home (`~/workspace`, `~` expanded), or relative-to-cwd (`../`); write tools (`edit_file`/`write_file`) stay cwd-confined regardless (#140). Default `tool_read_roots = {}` → cwd-only; a rejection names the knob. `chat_history_search` deliberately accepts no path fields, so it can search chat roots that live outside cwd (global iCloud dir, super-repo siblings).
- **Tool argv safety** (#144): `ls`, `grep`, and `find` no longer accept raw shell fragments. Each exposes structured fields and builds argv lists for the named binary, so shell metacharacters (`;`, `|`, `$()`, backticks, `>`) are data, not syntax. The shared pure helper (`lua/parley/tools/builtin/argv.lua`) validates local positive allowlists: `ls` allows compact display flags only; `grep` allows a small read-only flag set and rejects `rg` execution/arbitrary-read flags such as `--pre`, `--hostname-bin`, and `-f`; `find` has no free `flags` field and only exposes path/name/type/depth predicates. `grep` inserts `--` before pattern/path positionals so dash-leading patterns cannot be parsed as options; its omitted-path default is declared as `default_path = "."` so the dispatcher canonicalizes it through the cwd/read-root guard before execution.
- **Output pager** (#139): a horizontal substrate cap — *every tool's output is a paged stream.* The registry (`register`) injects `offset`/`limit` params into every non-write, non-`self_paginates` tool's schema, and the dispatcher windows each result to lines `[offset, offset+limit)` (offset 1-indexed; `limit` defaults to `tool_result_page_lines` = 200, clamped ≤ 2000), stripping the params so the handler never sees them. When the window is partial it appends a footer naming the **true total** + the next page: `[lines 1-200 of 1,240,118 — pass offset=201 for the next page, or narrow your query]`. `read_file` sets `self_paginates = true` — its native `offset`/`limit` (line-window of the file) *is* the contract, so the dispatcher neither injects nor slices it (a no-limit read falls back to the byte-cap). Deep paging on shell tools re-runs the tool (run+slice, no cache — v1). The 100KB byte-cap (`truncate`) stays as the backstop for pathological single lines. Orthogonal to input safety (#144) — slices *after* the handler.
- **Iteration cap**: `max_tool_iterations` (default 10) — writes synthetic `📎: (iteration limit reached)` when hit
- **Cancellation**: `cmd_stop` triggers `repair_unmatched_tool_blocks` — writes `📎: (cancelled by user)` for any 🔧: without matching 📎:
- **Backup**: `write_file` creates numbered `.parley-backup.N` on every write
- **Unknown tools**: return friendly error "Tool 'X' is not available on this client"
- **Malformed blocks**: `build_messages_from_model` degrades to text (no Anthropic rejection)
- **Buffer diagnostic**: `:lua require('parley').check_buffer()` validates invariants
- **Transcript drift**: pending chat leases cancel stale stream/tool/progress/topic callbacks when the response's agent-header line is deleted (e.g. undo/redo of the inserted response) — ordinary edits/streaming no longer invalidate (#138)

## Visual Treatment

- 🔧:/📎: blocks are dimmed (`ParleyThinking` highlight = `Comment`)
- Error results highlighted with `ParleyToolError` = `DiagnosticError`
- Completed tool blocks auto-folded via model-based manual folds
- Spinner shows during every API call (including recursive rounds)
