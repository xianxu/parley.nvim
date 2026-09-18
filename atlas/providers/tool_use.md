# Tool Use Protocol

Client-side tool loop enabling LLM agents to call tools (read/edit files, search, etc.) and receive results.

Tool calls appear as `🔧:` blocks with `📎:` results in the chat. They can read or
change files according to the selected agent's tool list and the active root
policy. `@readonly` grants read tools; `@all` also grants writes. A model may
choose not to call a tool even when one is available.

Anthropic and OpenAI-compatible providers have client tool wires; direct Google
AI does not. Server-side web search is independent of this loop. A turn stops
at `max_tool_iterations` (42 by default). Cancellation revokes further writes
and waits for positive producer cleanup; it does not repair the live transcript
by inventing tool results.

## Tool Set

File operations and structured wrappers around locally available Unix tools:

| Tool | Kind | Description |
|------|------|-------------|
| `parley_help` | read | List/read installed README, tutorials, and atlas by exact topic ID; no arbitrary file paths or personal-file access |
| `read_file` | read | Read file with line numbers. Params: `file_path`, `offset`, `limit` |
| `ls` | read | Shell out to system `ls` with structured `path`/`flags` fields |
| `find` | read | Shell out to system `find` with structured path/name/type/depth fields |
| `grep` | read | Shell out to `rg` or system `grep` with structured pattern/path/filter fields |
| `chat_history_search` | read | Search configured chat roots admitted by the request's root policy; extra `tool_read_roots` can allow global or sibling roots. Output is `{<repo>}/...`-prefixed. Default context `-B1 -A2`, `*.md` glob, case-insensitive. Params: `pattern`, `before`, `after`, `glob`, `case_insensitive`, `max_count` |
| `edit_file` | write | String replacement (`old_string`/`new_string`) or line insertion (`insert_line`/`insert_text`) |
| `write_file` | write | Create/overwrite file. Numbered `.parley-backup.N` on each write |
| `propose_edits` | write | Apply a batch of explained document edits; used by review and voice skills |
| `emit_definition` | output | Return a structured inline definition to the definition skill |
| `ack` | read | Optional, registered only if `ack` is installed; structured pattern/path/filter fields |

Tool descriptions identify the selected local command. Registering builtin tools does not launch version-probe subprocesses.

## Selecting Tools (agent config)

An agent's `tools` field is an explicit allow-list resolved by `tools.select()` (`lua/parley/tools/init.lua`). Empty/absent `tools` → the agent gets NO tools (a vanilla chat agent); there is no implicit "all" default. Each entry is either a tool name or a group sentinel:

| Selector | Expands to |
|----------|------------|
| `"@all"` | every registered tool (includes `ack` when installed) |
| `"@readonly"` | every registered non-write tool (`kind ~= "write"`; absent kind defaults to read) |

`parley_help = false` suppresses the introductory product context added to chat
system prompts; it does not unregister the `parley_help` tool. Tool availability
still follows the agent's explicit list or group selectors.

Group sentinels expand alphabetically; the combined list is de-duplicated by name (first occurrence wins), so `{ "edit_file", "@readonly" }` is safe. An unknown name or group raises at agent-config validation, naming the offending token.

## Wires (per-provider tool protocol)

A **wire** owns everything about how one provider family expresses client-side
tool use on the network. `lua/parley/tools/wire.lua` is the registry consumers
resolve through; the protocols themselves are pure modules beside it. Before
#198 the Anthropic protocol lived inline in `providers.lua` and each consumer
hardcoded it.

Every consumer resolves through the registry: `dispatcher.prepare_payload`
(translate + encode), `dispatcher`'s `empty_response` probe, `response_provider`, and
`skill_invoke`. No provider is hardcoded at a call site.

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
that already-validated output into OpenAI's shape, called from
`dispatcher.prepare_payload` — the one point upstream of every payload builder,
since cliproxy's openai route (`cliproxy_openai_payload`) and `ollama` each
build their own and only copilot/azure delegate to `openai.format_payload`:
`tool_calls[]` on the assistant message with **JSON-string** `arguments`, plus
one `{role = "tool", tool_call_id}` message per result. `is_error` folds into
the content string (OpenAI has no such field). Translating in the adapter rather
than forking the emitter keeps those invariants single-sourced.

A saved round is laid out `🔧a 📎a 🔧b 📎b` — each call immediately before its own
result (#266) — so re-parsing a transcript emits four messages where the live
round sent two: assistant `[tool_use a]`, user `[result a]`, assistant
`[tool_use b]`, user `[result b]`. That is accepted deliberately: the wire
reflects the file, and batching them back into one parallel turn would need round
identity written into the transcript. The live round is unaffected — its
continuation is built from the frozen round (Loop Model, step 5) and still sends
every call in one assistant message and every result in one user message.

### Stream decoding differs structurally

Anthropic frames each call with `content_block_start`/`_stop` around a top-level
`.index`. OpenAI streams an *array* of partial `delta.tool_calls[]` where `id`
and `function.name` arrive only in that call's first chunk, `arguments`
accumulates as string fragments, and **nothing closes a call**. The OpenAI
decoder therefore keys on the array index. Both wires return calls in declared
numeric index order, independent of start, fragment, or completion arrival.
Sparse indexes are supported; missing or invalid indexes are rejected rather
than aliased to index zero. Conflicting identities invalidate that index. The
OpenAI decoder is
deliberately *not* gated on `finish_reason == "tool_calls"` — a truncated stream
still surfaces what assembled. The response adapter admits tool rounds only
from a successful provider completion; failure does not launch tools from a
partial stream. Malformed `arguments` yield an empty input rather than raising.

Wire shapes are pinned by real captures in `tests/fixtures/openai_*.sse`, plus a
live conformance spec (`cliproxy_tool_conformance_spec.lua`, gated behind
`PARLEY_LIVE_CONFORMANCE=1`) that asks a real proxy for a real tool call so
upstream drift fails there rather than as a silently empty chat answer.

`vim.json.decode` maps an explicit JSON `null` to `vim.NIL`, which is **truthy**
in Lua — a bare `if obj.field then` accepts it and overwrites a good value with
userdata that raises on the next concatenation. Both decoders read optional
fields through `sse.str()` for that reason.

### The response side needs the request's wire

A stream comes back with no model params table: the query table has the provider
and the serialized payload, whose `model` is a bare NAME. That is not enough —
`claude-sonnet-5` resolves to a *different* wire depending on the agent's
`web_search_strategy`, so re-deriving on the response side would silently pick
the wrong decoder. Instead `prepare_payload` stamps `_parley_tool_wire` on the
payload, `dispatcher.query` consumes it onto the query table before the body is
serialized, and the `empty_response` probe resolves via `wire.by_name`. The chat `response_provider` also prefers this stamped wire, with the captured
request provider/model as its fallback; `skill_invoke` resolves where the agent
is in scope. The stamp never goes
over the network; `scripts/parley_harness.lua` strips it too, so the golden
payloads stay an accurate model of the request.

## Loop Model

`response_session.lua` composes submission, preparation, provider transport,
tool rounds, and pending presentation under one document generation. The
`response_runner` and supervisor own admission and completion; transport and tool
adapters receive operation handles, not authority to write arbitrary positions.

1. Submission captures the target and request source before asynchronous
   preparation. Preparation validates ownership before changing the answer shell,
   and changes it immediately before the generation's first write.
2. `response_provider` streams position-free output into the runner. On successful
   completion it decodes and freezes tool declarations using the request's wire.
3. A declared round starts its tools at once — at most four running — whatever
   the write turn: execution is concurrent. Nothing is written for them yet, and
   no placeholder is ever written.
4. The generation machine writes the round one block at a time in declared order
   — call 1, its result, call 2, its result — ordered by `tools/sequence.lua`
   and held, like output, behind the text streamed before the round, the write
   turn and the deferred gap. An outcome that arrives early waits for everything
   before it, so the transcript only grows at its tail. `response_tools` renders
   the block the machine asks for (`insert_tool`); a result block and the
   continuation carry the same recorded result. A **failed** call — `unknown`,
   `rejected`, `cancelled_before_effect` — is written as an ordinary
   `📎: … error=true` result saying what is known about its effect, and the round
   continues so the model can try another way; an outcome is final once written.
   Only a call whose outcome never arrives holds the blocks behind it: those tools
   still run and presentation counts them
   ([response progress](../chat/response_progress.md)), and `:ParleyStop` drops
   pairs not yet written, like any held output.
5. After the round is settled, `response_tools` builds continuation messages from
   the frozen previous request, assistant text, calls, and known results. The same
   Session admits the next provider operation; it neither recursively calls
   `respond` nor rebuilds the request from the mutable transcript.

The prepared response profile captures iteration and result-byte limits once per
generation, including an agent explicitly chosen during onboarding. Limits are
validated before preparation writes. Later configuration changes or continuation
metadata cannot raise these captured limits.

Logical cancellation and physical cleanup are separate. Stopping or invalidating
an answer prevents further admission immediately, but its operation remains
unresolved until the producer reports cleanup. A throwing producer may already
have caused an effect: an `unknown` outcome prevents continuation and is not
converted into a successful or cancelled result. A later known outcome and
positive cleanup can settle it; a cancellation request alone cannot.

Builtin definitions expose asynchronous execution and resource declarations.
The captured dispatcher profile, process-scoped scheduler, checked filesystem
seam, and Tasker supervise effects independently from transcript grants. See
[Tool Execution and Cleanup](tool_execution.md) for admission, bounds, uncertain
outcomes, and internal reconciliation APIs.

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

### The fenced-body grammar

`lua/parley/fence.lua` is the single source for how a tool body is delimited.
**Its docstrings are the specification** — this page deliberately does not
restate the rule, because prose cannot derive from a module and a restatement
drifts silently (it did, within this milestone: this section described a
bare-word info string two commits after the grammar became CommonMark-conformant).

What belongs here is the shape and the consumers:

- `fence.open_len` / `closes` / `for_content` define opening, closing and
  selection; `fence.scan` makes one depth-aware pass returning each tool block's
  extent plus the depth-0 marker set, and `fence.body_rows` is the derived view.
- Consumers, all deriving: `tools/serialize` (writer *and* both reader paths),
  `answer_structure`'s section scanner, `chat_parser`'s precompute and its
  `cb_state` tracker, and `fold_projection`'s interior drift scan. All three
  `fence.scan` callers pass the structural predicate — a caller left without it
  gets the pre-#203 close search, which is the divergence #200 collapsed.
- **A body may not span a column-0 structural marker** (#203). The close search
  stops there rather than latching onto a later bare fence belonging to another
  pair, which used to swallow every exchange in between, silently.

#### The producer-side invariant that rule rests on

The bound is safe because **the content-echoing tools never emit a column-0
marker**: each prefixes its output — `read_file` `%5d  `, `grep`/`ack` `-H`
giving `file:line:`, `chat_history_search` `{label}/path:line:`, and the write
tools return status messages. So a column-0 marker inside a body means the
content did not come from a parley tool — hand-edited, truncated, or pasted —
and forking there is the visible degradation chosen over silent swallowing.

`grep`/`ack` pass `-H` unconditionally rather than leaving it to the caller
(#203 BR-12): both omit the filename on a **single-file** search, so
`grep pattern=💬 path=chat.md` used to return bare transcript lines and fork a
well-formed body.

**The invariant is not total, and the claim is bounded rather than chased.** Two
exceptions, both degrading to over-forking:

- **path-echoing tools** — for `ls`/`find` the path IS the output, so a file
  *named* `💬: notes.md` yields a column-0 marker and no flag prevents it;
- **error paths** — `grep`/`ack`/`ls`/`find` splice raw stderr after a prefixed
  first line, so a hostile message can carry one.

This is a *producer* obligation the *parser* depends on, so it is guarded where
it is produced: `tests/integration/tool_output_prefix_spec.lua` derives its
subjects from `tools.BUILTIN_NAMES` + `OPTIONAL_NAMES`, so a new builtin is
covered by construction, and drives each over a **call-shape product** (single
file and directory) — one shape per tool is how its first draft passed while
`grep` on a single file was emitting column-0 markers. A missing builtin fails;
an absent OPTIONAL tool (`ack`) is reported `pending` rather than skipped
silently, so green never means "never checked".


**Which markers the depth rule covers** is stated once, in
`atlas/chat/parsing.md`: tool markers only. Inside a tool body, or inside any
other fenced block, a `🔧:`/`📎:` is content; a `💬:`/`🤖:` in a plain fenced
block still starts a turn.

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
  extra roots + existence). Pathless `chat_history_search` receives the same
  trusted policy in its handler context and filters configured chat roots through
  `resolve_read_path`. Model input cannot supply a wider policy. A direct Lua
  handler call without context searches all configured roots; normal dispatched
  chat/skill requests supply context and remain confined. Finder visibility is
  not a tool permission grant.
- **Tool argv safety** (#144, #149): `ls`, `grep`, `find`, `chat_history_search`, and optional `ack` no longer accept raw shell fragments. Each exposes structured fields and builds argv lists for the named binary, so shell metacharacters (`;`, `|`, `$()`, backticks, `>`) are data, not syntax. The shared pure helper (`lua/parley/tools/builtin/argv.lua`) validates local positive allowlists and numeric process flags: `ls` allows compact display flags only; `grep` allows a small read-only flag set and rejects `rg` execution/arbitrary-read flags such as `--pre`, `--hostname-bin`, and `-f`; `find` has no free `flags` field and only exposes path/name/type/depth predicates; `ack` exposes pattern/path/type/context fields with no raw `command` or `flags` escape hatch; `chat_history_search` searches only policy-admitted chat roots and validates `before`/`after`/`max_count` as non-negative integers before invoking `rg` or `grep` through argv-list execution. `grep`, `ack`, and `chat_history_search` insert `--` before pattern/path positionals so dash-leading patterns cannot be parsed as options; omitted-path defaults for cwd-confined tools are declared as `default_path = "."` so the dispatcher canonicalizes them through the cwd/read-root guard before execution.
- **Output pager** (#139): a horizontal substrate cap — *every tool's output is a paged stream.* The registry (`register`) injects `offset`/`limit` params into every non-write, non-`self_paginates` tool's schema, and the dispatcher windows each result to lines `[offset, offset+limit)` (offset 1-indexed; `limit` defaults to `tool_result_page_lines` = 200, clamped ≤ 2000), stripping the params so the handler never sees them. When the window is partial it appends a footer naming the **true total** + the next page: `[lines 1-200 of 1,240,118 — pass offset=201 for the next page, or narrow your query]`. `read_file` sets `self_paginates = true` — its native `offset`/`limit` (line-window of the file) *is* the contract, so the dispatcher neither injects nor slices it (a no-limit read falls back to the byte-cap). Deep paging on shell tools re-runs the tool (run+slice, no cache — v1). The 100KB byte-cap (`truncate`) stays as the backstop for pathological single lines. Orthogonal to input safety (#144) — slices *after* the handler.
- **Iteration cap**: `max_tool_iterations` (default 42, single-sourced in `defaults.lua`) is captured by the Session; a further tool round is refused when the limit is reached, without executing its calls.
- **Cancellation**: scoped generation cancellation revokes answer/tool grants and stops owned operations. It waits for positive cleanup and does not scan or repair unmatched transcript blocks.
- **Tool_use↔tool_result invariant → valid payload by construction** (#155, #156): the single pure emitter `_emit_content_blocks_as_messages` (shared by both build paths — `build_messages` and `build_messages_from_model` normalize into it) tracks pending tool_use ids and synthesizes a neutral `is_error` result (`M.DANGLING_TOOL_RESULT_TEXT`) for any not answered by a real `📎:`, in the immediately-following user message (partial parallel calls handled). So an unanswered 🔧: (crash / kill / reload / hand-edited buffer) never reaches Anthropic as an assistant `tool_use` without a matching user `tool_result`. Symmetrically (#156), an **orphan** `📎:` (no preceding 🔧:) or a **duplicate** result is dropped: `resolve_pending` returns whether the id matched a still-pending `tool_use`, and an unmatched result is skipped — so the payload never carries an unmatched user `tool_result` either. Empty tool input coerces to `{}` here (one source). This normalization belongs to request construction; it does not rewrite the buffer.
- **Backup**: asynchronous existing-file writes and edits publish a checked numbered `.parley-backup.N` before destructive IO; a failed backup prevents the target write. New files use exclusive creation.
- **Unknown tools**: return friendly error "Tool 'X' is not available on this client"
- **Malformed blocks**: `build_messages_from_model` degrades to text (no Anthropic rejection)
- **Buffer diagnostic**: `:lua require('parley').check_buffer()` validates invariants
- **Transcript drift**: Document grants and captured source guards fence answer, tool, progress, and topic callbacks. Editing a protected region or deleting its marker invalidates that work; disjoint draft edits leave it valid, and so does a sibling generation's work (which writes only when it holds the write turn — see [write ownership](../chat/ownership.md)). Reload invalidates active writes.

## Visual Treatment

- 🔧:/📎: blocks are dimmed (`ParleyThinking` highlight = `Comment`)
- Error results highlighted with `ParleyToolError` = `DiagnosticError`
- Completed tool blocks auto-folded via model-based manual folds
- Each provider round uses the delayed virtual
  [response-progress](../chat/response_progress.md) presentation; fast visible
  output bypasses it, and local tool execution itself shows no spinner

## Implementation and verification

The builtin list lives in `lua/parley/tools/init.lua`; `response_session.lua`
composes the chat response, `response_provider.lua` owns transport callbacks,
`response_tools.lua` runs a round's tools, renders its blocks and builds frozen
continuations, and `tools/sequence.lua` orders the blocks.
`tools/dispatcher.lua` owns execution/root checks/paging, and `tools/wire.lua`
selects the protocol. Native integration coverage includes
`response_session_spec.lua`, `response_tools_spec.lua`, and
`response_profile_spec.lua` under `tests/integration/`. Protocol tests include
`tests/unit/tool_wire_registry_spec.lua`,
`tests/unit/anthropic_tool_wire_spec.lua`,
`tests/unit/tools_builtin_propose_edits_spec.lua`, and
`tests/integration/cliproxy_tool_conformance_spec.lua`.

`tests/unit/tools_builtin_chat_history_search_spec.lua` verifies policy-confined
history search, explicit additional roots, symlink rejection, and forged input
policy. The dispatcher passes policy as handler context, separately from model
arguments.

No placeholder is ever written: a result block exists only once its outcome
arrives. A call cut off by reload or Stop before its result lands stays an
unmatched call; historical provider projection reports its missing result as an
error, never as successful execution evidence.

Tool adapter retirement joins a recorded outcome and positive producer cleanup;
every contributing event reevaluates that join, including late outcomes after
cancellation. The outcome is recorded before outcome observers can report cleanup
reentrantly. Writing is the machine's decision, not the adapter's, so a tool's
retirement never races its own result block.
