# Tool Use Protocol

Client-side tool loop enabling LLM agents to call tools (read/edit files, search, etc.) and receive results.

## Tool Set

Standard Unix tools exposed to Claude, plus file operations:

| Tool | Kind | Description |
|------|------|-------------|
| `read_file` | read | Read file with line numbers. Params: `file_path`, `offset`, `limit` |
| `ls` | read | Shell out to system `ls` with structured `path`/`flags` fields |
| `find` | read | Shell out to system `find` with structured path/name/type/depth fields |
| `grep` | read | Shell out to `rg` or system `grep` with structured pattern/path/filter fields |
| `chat_history_search` | read | Search past chats across ALL chat roots (global + repo + super-repo siblings). Output is `{<repo>}/...`-prefixed. Default context `-B1 -A2`, `*.md` glob, case-insensitive. Params: `pattern`, `before`, `after`, `glob`, `case_insensitive`, `max_count` |
| `edit_file` | write | String replacement (`old_string`/`new_string`) or line insertion (`insert_line`/`insert_text`) |
| `write_file` | write | Create/overwrite file. Numbered `.parley-backup.N` on each write |
| `ack` | read | Optional, registered only if `ack` is installed; structured pattern/path/filter fields |

Tool descriptions dynamically advertise the locally available command version (e.g., "ripgrep 14.1" vs "GNU grep 3.11").

## Selecting Tools (agent config)

An agent's `tools` field is an explicit allow-list resolved by `tools.select()` (`lua/parley/tools/init.lua`). Empty/absent `tools` → the agent gets NO tools (a vanilla chat agent); there is no implicit "all" default. Each entry is either a tool name or a group sentinel:

| Selector | Expands to |
|----------|------------|
| `"@all"` | every registered tool (includes `ack` when installed) |
| `"@readonly"` | every registered non-write tool (`kind ~= "write"`; absent kind defaults to read) |

Group sentinels expand alphabetically; the combined list is de-duplicated by name (first occurrence wins), so `{ "edit_file", "@readonly" }` is safe. An unknown name or group raises at agent-config validation, naming the offending token.

## Wires (per-provider tool protocol)

A **wire** owns everything about how one provider family expresses client-side
tool use on the network. `lua/parley/tools/wire.lua` is the registry consumers
resolve through; the protocols themselves are pure modules beside it. Before
#198 the Anthropic protocol lived inline in `providers.lua` and each consumer
hardcoded it.

> **State at #198 M1:** the wire layer and the encoders are wired up; the
> *read* side is not. `dispatcher.lua` still runs its five-branch provider
> chain, `tool_loop.lua` and `skill_invoke.lua` still call
> `providers.decode_anthropic_tool_calls_from_stream` directly, `dispatcher`'s
> `empty_response` still hardcodes the Anthropic literal, and nothing calls
> `translate_messages` yet. M2 rewires all four. Until then an OpenAI-family
> tool agent builds a valid request but decodes zero calls — see the issue Log.
> Drop this note at M2's atlas pass.

| Module | Speaks for |
|--------|-----------|
| `tools/wire_anthropic.lua` | `anthropic`; cliproxyapi's anthropic route |
| `tools/wire_openai.lua` | `openai`, `copilot`, `azure`, `ollama`; cliproxyapi's openai route |
| `tools/wire.lua` | the registry — resolves, then forwards |

Contract: `encode_tools`, `encode_tool_choice`, `decode_tool_calls_from_stream`,
`has_tool_calls`, and the OPTIONAL `translate_messages` (defined only by wires
whose message shape differs from parley's internal one).

**The registry API takes `(provider, model)`, never a route.** cliproxyapi
speaks both wires depending on the model, so a route argument is one a caller
can forget — and a forgotten route resolves to *some* wire and then decodes
zero tool calls, which downstream is indistinguishable from a model that chose
not to call a tool. `providers.cliproxy_route(model_name, strategy)` derives it
inside; `providers.cliproxy_strategy(model)` supplies the strategy including its
config-level fallback. `cliproxyapi.format_payload` asks the *same* helper, so
the tools in a payload can never disagree with the payload's own shape (they
could before #198: the encoder keyed on `^claude%-` alone).

`encode`/`encode_tool_choice` **raise** for a provider with no wire — a real
misconfiguration, caught at request-build time and naming the provider.
`decode`/`has_tool_calls`/`translate_messages` **degrade quietly**, because they
run on every response including from agents that declared no tools.

`googleai` has no wire yet; it needs `functionDeclarations`, a genuinely
different shape.

### Message shapes

Internally parley always speaks Anthropic's shape — assistant `[text, tool_use]`
content blocks followed by a user turn of matching `[tool_result]` blocks — and
`_emit_content_blocks_as_messages` is the single place that shape and its
`#155`/`#156` invariants are produced. `wire_openai.translate_messages` converts
that already-validated output into OpenAI's shape (called from
`dispatcher.prepare_payload` as of M2 — the one point upstream of every payload
builder, since cliproxy's openai route and ollama each build their own):
`tool_calls[]` on the assistant message with **JSON-string** `arguments`, plus
one `{role = "tool", tool_call_id}` message per result. `is_error` folds into
the content string (OpenAI has no such field). Translating in the adapter rather
than forking the emitter keeps those invariants single-sourced.

### Stream decoding differs structurally

Anthropic frames each call with `content_block_start`/`_stop` around a top-level
`.index`. OpenAI streams an *array* of partial `delta.tool_calls[]` where `id`
and `function.name` arrive only in that call's first chunk, `arguments`
accumulates as string fragments, and **nothing closes a call**. The OpenAI
decoder therefore keys on the array index, orders by first appearance, and is
deliberately *not* gated on `finish_reason == "tool_calls"` — a truncated stream
still surfaces what assembled, so the loop can write a synthetic result instead
of stranding the buffer with an unmatched 🔧:. Malformed `arguments` yield an
empty input rather than raising.

Wire shapes are pinned by real captures in `tests/fixtures/openai_*.sse`.

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

- **root-policy scope**: chat and `skill_invoke` pass one neighborhood policy to
  the dispatcher and model guidance. All relative paths resolve against the
  policy's **write root** — the single base; `../sibling` traversal is the
  canonical spelling for peer-repo reads (#192). Read tools then require the
  resolved realpath to exist and to land within the permission set
  (`policy.read_roots` = write root + configured `tool_read_roots`); the
  permission roots are never fallback resolution bases. This applies to
  `path`, `file_path`, `paths`, and injected `default_path`. Absolute paths and
  symlinks must remain within a read root. Write tools ignore the wider set and
  retain `resolve_path_in_cwd` confinement plus missing-leaf creation semantics
  (reads share the same mechanism via `resolve_read_path`, differing only by
  extra roots + existence). Tools without path fields, such as
  `chat_history_search`, are unaffected. (#147, #192)
- **Tool argv safety** (#144, #149): `ls`, `grep`, `find`, `chat_history_search`, and optional `ack` no longer accept raw shell fragments. Each exposes structured fields and builds argv lists for the named binary, so shell metacharacters (`;`, `|`, `$()`, backticks, `>`) are data, not syntax. The shared pure helper (`lua/parley/tools/builtin/argv.lua`) validates local positive allowlists and numeric process flags: `ls` allows compact display flags only; `grep` allows a small read-only flag set and rejects `rg` execution/arbitrary-read flags such as `--pre`, `--hostname-bin`, and `-f`; `find` has no free `flags` field and only exposes path/name/type/depth predicates; `ack` exposes pattern/path/type/context fields with no raw `command` or `flags` escape hatch; `chat_history_search` keeps its explicit chat-root cwd bypass but validates `before`/`after`/`max_count` as non-negative integers before invoking `rg` or `grep` through argv-list execution. `grep`, `ack`, and `chat_history_search` insert `--` before pattern/path positionals so dash-leading patterns cannot be parsed as options; omitted-path defaults for cwd-confined tools are declared as `default_path = "."` so the dispatcher canonicalizes them through the cwd/read-root guard before execution.
- **Output pager** (#139): a horizontal substrate cap — *every tool's output is a paged stream.* The registry (`register`) injects `offset`/`limit` params into every non-write, non-`self_paginates` tool's schema, and the dispatcher windows each result to lines `[offset, offset+limit)` (offset 1-indexed; `limit` defaults to `tool_result_page_lines` = 200, clamped ≤ 2000), stripping the params so the handler never sees them. When the window is partial it appends a footer naming the **true total** + the next page: `[lines 1-200 of 1,240,118 — pass offset=201 for the next page, or narrow your query]`. `read_file` sets `self_paginates = true` — its native `offset`/`limit` (line-window of the file) *is* the contract, so the dispatcher neither injects nor slices it (a no-limit read falls back to the byte-cap). Deep paging on shell tools re-runs the tool (run+slice, no cache — v1). The 100KB byte-cap (`truncate`) stays as the backstop for pathological single lines. Orthogonal to input safety (#144) — slices *after* the handler.
- **Iteration cap**: `max_tool_iterations` (default 42, single-sourced in `defaults.lua` `#154`) — writes synthetic `📎: (iteration limit reached — max N rounds)` when hit
- **Cancellation**: `cmd_stop` triggers `repair_unmatched_tool_blocks` — writes `📎: (cancelled by user)` for any 🔧: without matching 📎:
- **Tool_use↔tool_result invariant → valid payload by construction** (#155, #156): the single pure emitter `_emit_content_blocks_as_messages` (shared by both build paths — `build_messages` and `build_messages_from_model` normalize into it) tracks pending tool_use ids and synthesizes a neutral `is_error` result (`M.DANGLING_TOOL_RESULT_TEXT`) for any not answered by a real `📎:`, in the immediately-following user message (partial parallel calls handled). So an unanswered 🔧: (crash / kill / reload / hand-edited buffer that `repair_unmatched_tool_blocks` never covered) never reaches Anthropic as an assistant `tool_use` without a matching user `tool_result`. Symmetrically (#156), an **orphan** `📎:` (no preceding 🔧:) or a **duplicate** result is dropped: `resolve_pending` returns whether the id matched a still-pending `tool_use`, and an unmatched result is skipped — so the payload never carries an unmatched user `tool_result` either. Empty tool input coerces to `{}` here (one source). The stop-time buffer repair is now a UX nicety, not load-bearing for payload validity.
- **Backup**: `write_file` creates numbered `.parley-backup.N` on every write
- **Unknown tools**: return friendly error "Tool 'X' is not available on this client"
- **Malformed blocks**: `build_messages_from_model` degrades to text (no Anthropic rejection)
- **Buffer diagnostic**: `:lua require('parley').check_buffer()` validates invariants
- **Transcript drift**: pending chat leases cancel stale stream/tool/progress/topic callbacks when the response's agent-header line is deleted (e.g. undo/redo of the inserted response) — ordinary edits/streaming no longer invalidate (#138)

## Visual Treatment

- 🔧:/📎: blocks are dimmed (`ParleyThinking` highlight = `Comment`)
- Error results highlighted with `ParleyToolError` = `DiagnosticError`
- Completed tool blocks auto-folded via model-based manual folds
- Each initial or recursive LLM round uses the delayed virtual
  [response-progress](../chat/response_progress.md) presentation; fast visible
  output bypasses it, and local tool execution itself shows no spinner
