---
id: 000081
status: working
deps: []
created: 2026-04-08
updated: 2026-04-09
---

# support anthropic tool use protocol

Foundation for evolving parley into an agentic environment. Scope: implement client-side tool use loop so the LLM can call tools (read/edit/write files, etc.) and parley executes them and feeds results back.

This is the first of a decomposed series from the original brainstorm. Once tool use exists, a `CLAUDE.md`-style constitution (#82) and a skill system (#83) largely become conventions rather than new machinery. Transcript-driven replay (#84) and file-reference freshness (#85) build on v1's data capture.

Original motivation (for context, not scope of this issue):
- Eventually have a `CLAUDE.md` constitution file for a personal assistant — [issue 000082](./000082-claude-md-constitution-file.md)
- Eventually have a skill system (folder of markdown pulled in on demand) — [issue 000083](./000083-skill-system.md)
- Foundation for a "1000 shot" personal assistant environment

## Follow-up sub-tickets (blocked on this)

- [issue 000082](./000082-claude-md-constitution-file.md) — `CLAUDE.md` constitution file
- [issue 000083](./000083-skill-system.md) — skill system (+ user-defined tools via skills)
- [issue 000084](./000084-transcript-driven-filesystem-reconciliation.md) — transcript-driven filesystem reconciliation (backtrack/replay)
- [issue 000085](./000085-file-reference-freshness.md) — file reference freshness (stale indicator + reload)

## Spec

Detailed design. A brief sketch will be added to `specs/providers/tool_use.md` after implementation lands (per `AGENTS.md` — `specs/` is a practical pointer, not detailed spec).

### Coding principles (PURE / DRY)

Called out first so they govern everything below.

- **PURE** — tool handlers are pure functions `input → ToolResult`. They do filesystem I/O but no logging side effects, no hidden global state, no error state held elsewhere. The dispatcher is the only layer aware of session state (registry, open buffers, repo root).
- **PURE** — the send-time payload builder (parley buffer → Anthropic request JSON) is a pure function of the parsed exchange list. No reading buffer state mid-build, no provider-specific leakage into the parser.
- **DRY** — cwd-scope check (path resolution + traversal-escape rejection) lives in one place (dispatcher). Every write tool goes through it. No per-tool path checks.
- **DRY** — dirty-buffer guard is one helper in the dispatcher, shared by `edit_file` / `write_file` and any future destructive tool.
- **DRY** — `.parley-backup` "write if not exists" logic is one helper, shared by `write_file` and any future destructive tool.
- **DRY** — truncation to `tool_result_max_bytes` happens once in the dispatcher, not per-tool.
- **DRY** — the `🔧:` / `📎:` buffer serialization and its reverse (parser's content-block extractor) share a single schema definition: prefix-line plus fenced body with `name=` and `id=` attributes. Adding a future prefix is one schema edit.

### 1. Loop model & cancellation

- **Auto loop, bounded.** On `:ChatRespond`, parley runs the Anthropic call; if the response contains `tool_use` blocks, parley executes them, appends `tool_result` content to the conversation, and recurses until the model returns a response without `tool_use` or until `max_tool_iterations` (default 20) is hit. All streaming is live into the chat buffer.
- **Interrupt: `<Esc>` (new) and `<C-g>x` (existing).** `<Esc>` is buffer-local in the chat filetype, normal mode only. Insert mode unchanged (remapping `<Esc>` in insert mode breaks vim).
- **Cancel-cleanup invariant.** After any cancellation (user `<Esc>`, `<C-g>x`, or `max_tool_iterations`), the buffer is left in a state that both (a) reads naturally to the user and (b) parses back into a valid Anthropic request (an assistant message with tool_use blocks MUST be followed by a user message with matching tool_result blocks — otherwise Anthropic rejects).
  - **Case 1 — partial streaming tool_use (incomplete JSON)** → the partial `🔧:` block is dropped; whatever preceded it is kept.
  - **Case 2 — committed `🔧:` with no `📎:`** → parley writes a synthetic `📎:` whose body is `(cancelled by user)` or `(iteration limit reached)`. Visible to user, valid tool_result to the LLM on resubmit.
  - **Case 3 — mid-execution (slow tool)** → same as Case 2.
  - **Case 4 — completed roundtrips + partial next assistant response** → drop the partial text, same as current `<C-g>x` behavior.

### 2. Buffer representation

- **Two new prefixes:**
  - `🔧:` — tool_use. Line format: `🔧: <tool_name> [id=<toolu_id>]`. Body is a fenced code block (`json`) containing the input arguments.
  - `📎:` — tool_result. Line format: `📎: <tool_name> [id=<toolu_id>]`. Body is a fenced code block (plain text) containing the tool output, or the synthetic `(cancelled by user)` / `(iteration limit reached)` marker. For `write_file` results, the body includes a trailing `pre-image: <path>.parley-backup` metadata line so #84's replay has the data it needs.
  - `id=` correlates call to result. Parser enforces pairing at submit time.
- **Components of a `🤖:` answer, not new exchanges.** An exchange is still one `💬:` + one `🤖:` answer. The answer can contain interleaved thinking (`🧠:`), text, `🔧:`, and `📎:` components in any order.
- **Auto-fold on buffer load.** Fold markers or `foldexpr` auto-close every `🔧:` and `📎:` body on buffer open. The one-line prefix stays visible. Folds are stable across edits.
- **New shortcut `<C-g>b`** — toggles open/closed fold state of all `🔧:` / `📎:` components within the exchange under the cursor. Reuses parley's existing `exchanges` parser concept (`chat_parser.lua:86-316`) to scope "exchange under cursor".
- **Send-time payload translation.** The provider payload builder walks the parse tree and recombines consecutive `🤖:` text + `🧠:` thinking + `🔧:` tool_use into a single Anthropic `assistant` message with `content: [text, thinking, tool_use, ...]`. Each `📎:` (or run of consecutive `📎:`) becomes the following `user` message's `content: [tool_result, ...]`. 1:1 with Anthropic content-block model.
- **Syntax highlighting** — new highlight groups for the two prefixes, reusing parley's existing prefix-highlight machinery (`specs/ui/highlights.md`).
- **Outline navigation** — tool components appear as entries in parley's outline picker, so users can jump between tool calls in long chats.

### 3. Tool set & safety

Six builtin tools in a new `lua/parley/tools/` module. Each tool is one file, ~50-100 LOC. Internal type: `ToolDefinition = { name, description, input_schema, handler }`.

| Tool         | Inputs                                                                      | Behavior                                                                        | Risk       |
|--------------|-----------------------------------------------------------------------------|---------------------------------------------------------------------------------|------------|
| `read_file`  | `path`, optional `line_start`, `line_end`                                   | Reads file, returns content with line numbers                                   | read-only  |
| `list_dir`   | `path`, optional `max_depth` (default 1)                                    | Lists directory entries (files + subdirs)                                       | read-only  |
| `grep`       | `pattern`, optional `path`, `glob`, `case_sensitive`                        | Thin wrapper over ripgrep (or `vim.fs` fallback)                                | read-only  |
| `glob`       | `pattern`, optional `path`                                                  | Returns matching paths via `vim.fs.find` / glob                                 | read-only  |
| `edit_file`  | `path`, `old_string`, `new_string`, optional `replace_all=false`            | Literal string replace. Errors if `old_string` not unique unless `replace_all`  | write      |
| `write_file` | `path`, `content`                                                           | Creates or overwrites file                                                      | write      |

**Safety rules — enforced in the dispatcher, not per-tool (DRY):**

- **Path scope: cwd only.** All paths — read and write — are resolved to absolute form. They must have the current working directory (repo root at chat-start time) as a prefix. Absolute paths outside cwd, and paths containing `..` that escape cwd, are rejected with a tool_result marked `is_error: true` and body `"path outside working directory: <path>"`. Relative paths are resolved against cwd.
- **Dirty-buffer protection.** If `edit_file` / `write_file` targets a file loaded in a vim buffer with unsaved changes → error tool_result, file untouched. If the buffer is loaded without changes, parley reloads it after the write via `:checktime`.
- **`.parley-backup` mechanism for `write_file`.** Before executing `write_file` on `<path>`, parley checks for `<path>.parley-backup`. If it does not exist, parley first writes the current contents of `<path>` to `<path>.parley-backup`. If `<path>` does not exist (new-file write), parley creates `<path>.parley-backup` with the single-line sentinel `# parley:deleted-before-write`. If `<path>.parley-backup` already exists, parley does not touch it — the existing backup captures the earliest pre-parley state, which is what #84's replay will need. This gives #84 everything it needs to implement delete-to-undo, edit-in-place, and reorder modes against `write_file`.
- **`edit_file` needs no backup.** The tool call already contains `old_string` AND `new_string`; it is a delta format and is locally reversible from the transcript alone.
- **Gitignore hygiene.** In parley repo-mode (marker file present), parley auto-appends `*.parley-backup` to the repo's `.gitignore` on first write if the line is not already there. Outside repo-mode, parley leaves `.gitignore` alone and creates backup files anyway — user decides what to do with them.
- **Result size cap.** `tool_result_max_bytes` (default 100KB). If a tool output exceeds this, it is truncated with trailing `\n... [truncated: N bytes omitted]`. Applied at dispatcher level.
- **Backup lifecycle.** Never auto-cleaned in v1. A future `:ParleyBackupSweep` command (likely in #84) will handle cleanup. For v1, they accumulate.

### 4. Provider scope & internal abstractions

- **v1 implements Anthropic only.** OpenAI, Google AI, Ollama, and CLIProxyAPI routed to non-Anthropic models surface a clear error: `"tools not supported for this provider yet — see #81 follow-up"` when a tools-enabled agent is selected against them. No partial support, no silent fallback.
- **CLIProxyAPI special case.** Tools work only when CLIProxyAPI is routing to an Anthropic-family model. Other routings error out identically.
- **Provider-agnostic internal types** (new module `lua/parley/tools/types.lua`):
  - `ToolDefinition = { name, description, input_schema, handler }` — registered at setup time, passed to agents.
  - `ToolCall = { id, name, input }` — what the LLM asked for, normalized out of any provider-specific shape.
  - `ToolResult = { id, content, is_error }` — what parley sends back, normalized before translating into a provider-specific shape.
- **Per-provider adapter surface** (only Anthropic implements in v1):
  - `encode_tools(tool_definitions) → provider_payload_fragment`
  - `decode_tool_calls(streaming_event) → ToolCall | nil`
  - `encode_tool_results(tool_results) → provider_payload_fragment`
  - OpenAI / Google adapters are stubs that raise `"not yet implemented"`.
- **Client-side tools APPEND to `payload.tools`, do NOT overwrite.** Discovered during Task 1.0 baseline capture: Anthropic's existing `providers.lua:568+` code already emits `payload.tools = [web_search, web_fetch]` for users with server-side web search enabled. M1 Task 1.5's client-side tool encoding MUST append client-side tool definitions to the existing `payload.tools` list, not assign it. Otherwise: (a) users lose web search when they pick a tools-enabled agent, (b) vanilla agents with web search fail the M9 byte-identity check.
- **The tool loop is provider-agnostic.** `lua/parley/chat_respond.lua` owns the loop. It calls `dispatcher.query(...)`, inspects the returned assistant message for `ToolCall`s via the provider adapter, executes the calls by looking up handlers in the registered `ToolDefinition` table, appends `ToolResult`s, and recurses. The loop never touches Anthropic-specific JSON.
- **Streaming integration.** Parley's existing SSE parsing in `providers.lua` already understands Anthropic's `tool_use` / `input_json_delta` event shapes for progress display (see `providers.lua:568+`). v1 extends that parsing from "emit progress events" to "also build a `ToolCall` accumulator" so at stream end, chat_respond has the full `ToolCall` ready to dispatch. No new curl paths, no new SSE parser.
- **Query cache.** Existing `query_dir` pruned at >200 files. A single user turn now produces N requests (one per loop iteration), each its own cache file. No schema changes, just more volume.

### 5. Enablement, config, and agent surface

- **Enablement is per-agent.** Three new optional fields on agents:
  - `tools = { "read_file", "list_dir", "grep", "glob", "edit_file", "write_file" }` — list of builtin tool names. Absent or empty = no tool use (current behavior). Unknown names → setup-time error.
  - `max_tool_iterations = 20` — loop ceiling. When hit, parley synthesizes `📎: (iteration limit reached)` and stops.
  - `tool_result_max_bytes = 102400` — per-result truncation cap (default 100KB).
- **No header override in v1.** Chat header front matter cannot add/remove tools. Deferred; easy to add later following existing `system_prompt` / `system_prompt+` pattern.
- **One new default agent ships with parley.** Name: `ClaudeAgentTools` (or TBD-bikeshedded). Same provider/model as the existing Claude agent, `tools` set to all six builtins. Existing Claude agents are untouched; vanilla chat byte-identical to pre-#81.
- **Agent picker `[🔧]` badge.** `<C-g>a` shows `[🔧]` next to any agent with `tools` configured. One-glance visibility.
- **No global enable flag.** Only way to activate tool use is to select a tools-enabled agent. Explicit, discoverable, reversible.
- **Lualine indicator** — during an active tool loop, parley's existing lualine component (`specs/ui/lualine.md`) shows `🔧 <current_tool> (N/max)` — current tool + iteration count. Uses existing progress-event plumbing.
- **Logging.** Each tool call + result round-trip logged at `debug` level through `lua/parley/logger.lua`. Nothing user-visible unless debug logging is on.

### 6. Scope fence (what's NOT in v1)

- **No #82 (`CLAUDE.md` constitution).** File format, location, system-prompt injection all in #82. Day #82 starts, it can use #81's tools.
- **No #83 (skill system).** Markdown skill discovery, trigger matching, and user-defined tools all in #83.
- **No #84 backtrack/replay UI.** #81 only captures `.parley-backup` data.
- **No #85 file-freshness indicator or reload commands.** #85 handles `@@` embeds and `📎: read_file` uniformly.
- **No OpenAI / Google / Ollama tool use.** Provider-agnostic types and adapter surface exist as stubs.
- **No user-defined tools.** Six builtins hardcoded.
- **No shell / `run_shell` tool.** Highest-risk tool; out of scope for stated motivation.
- **No per-chat header override of tool lists.** Tools are agent-scoped.
- **No auto-cleanup of `.parley-backup` files.** They accumulate; future cleanup tool.
- **No tool-level approval gates.** Auto-loop with `<Esc>` cancel is the entire safety model.
- **No changes to existing vanilla chat behavior.** Agents without `tools` configured behave identically. Zero regression.

## Done when

- [x] Detailed spec written in this issue's `## Spec` section (per AGENTS.md convention)
- [ ] Implementation complete for all 9 milestones
- [ ] All 9 manual test stages pass end-to-end in a live Neovim session
- [ ] `make lint` and `make test` pass
- [ ] Vanilla chat byte-identical to pre-#81 (query cache JSON diff is empty for non-tools agents)
- [ ] Brief sketch added to `specs/providers/tool_use.md` pointing here for detail
- [ ] `specs/index.md` updated to reference the new `tool_use.md` sketch

## Plan

### Brainstorm & design

- [x] Brainstorm scope and decompose (completed 2026-04-08 / 2026-04-09)
- [x] Create sub-tickets #82, #83, #84, #85 (completed 2026-04-09)
- [x] Write detailed design into this issue's `## Spec` section (completed 2026-04-09)
- [x] User reviewed the `## Spec` section (completed 2026-04-09)
- [x] Write implementation plan via writing-plans skill → [docs/plans/000081-anthropic-tool-use.md](../docs/plans/000081-anthropic-tool-use.md) (completed 2026-04-09)
- [ ] User reviews the implementation plan
- [ ] Begin implementation at M1
- [ ] Add brief sketch to `specs/providers/tool_use.md` after implementation lands (part of M9)

### Implementation milestones (each gated on its manual test stage)

- [ ] **M1 — Plumbing**: `ToolDefinition`/`ToolCall`/`ToolResult` types, agent `tools` config field, Anthropic payload `tools` encoding, new `ClaudeAgentTools` agent, picker `[🔧]` badge. No loop yet; model can respond but if it emits tool_use, we error. → gated on **Stage 1**
- [ ] **M2 — Single read_file round-trip**: buffer prefixes `🔧:`/`📎:`, parser changes, streaming tool_use accumulator in Anthropic adapter, dispatcher tool loop with single-round execution, `read_file` handler, fold setup, `<C-g>b` shortcut. → gated on **Stage 2**
- [ ] **M3 — Remaining read tools**: `list_dir`, `grep`, `glob`. → gated on **Stage 3**
- [ ] **M4 — Multi-round loop & iteration cap**: loop recursion, iteration counter, synthetic `(iteration limit reached)` result, lualine progress indicator. → gated on **Stage 4**
- [ ] **M5 — Write tools with safety**: `edit_file`, `write_file`, cwd-scope check, dirty-buffer guard, `.parley-backup` helper, auto-gitignore in repo-mode, post-write `:checktime` reload. → gated on **Stage 5**
- [ ] **M6 — Cancellation hardening**: `<Esc>` buffer-local mapping, synthetic `(cancelled by user)` result for all 4 cancel scenarios, partial-JSON drop path. → gated on **Stage 6**
- [ ] **M7 — Buffer-is-state invariants**: parser diagnostics for malformed tool blocks, manual-edit survivability tests. → gated on **Stage 7**
- [ ] **M8 — UX polish**: syntax highlighting, outline integration, badge/indicator polish. → gated on **Stage 8**
- [ ] **M9 — Regression lockdown**: full lint/test pass, byte-identical vanilla chat verification. → gated on **Stage 9**

### Manual test stages

Every stage is end-to-end in a live Neovim session. Log pass / fail / issues found in the Log section as each stage is attempted.

#### Stage 1 — Plumbing (no loop yet)

- [ ] `ClaudeAgentTools` agent loads with `tools` field configured
- [ ] Unknown tool name in config raises setup-time error with the offending name
- [ ] Agent picker (`<C-g>a`) shows `[🔧]` badge next to the new agent
- [ ] Sending a vanilla "Hi, what is 2+2?" to the new agent produces a normal text response (verifies tool-enabled payloads don't break non-tool conversations)
- [ ] Query cache file contains the outgoing request JSON with a `tools: [...]` field
- [ ] Vanilla (non-tools) agents: query cache JSON is byte-identical to pre-#81 for the same prompts

#### Stage 2 — Single read_file round-trip

- [ ] Ask agent "read `lua/parley/init.lua` and tell me the first function name"
- [ ] `🔧: read_file id=...` streams into buffer, auto-folded on arrival
- [ ] `<C-g>b` toggles the fold
- [ ] `📎: read_file id=...` streams in with file content, auto-folded
- [ ] Final `🤖:` text correctly references content from the file
- [ ] Loop terminates cleanly after one roundtrip
- [ ] Re-submitting the same exchange (without edit) produces no Anthropic validation error and a similar response (proves buffer → payload round-tripping)
- [ ] Lualine shows `🔧 read_file (1/20)` during the call, disappears after

#### Stage 3 — All read tools

- [ ] `list_dir lua/parley/` returns reasonable directory listing
- [ ] `grep "ChatRespond" lua/` returns matching lines
- [ ] `grep` output exceeding 100KB is truncated with `... [truncated: N bytes omitted]` marker
- [ ] `glob "lua/**/*.lua"` returns matching paths
- [ ] Agent chains multiple read tools in one turn (e.g. "find the function that handles the agent picker and read its body") — all render correctly in the buffer

#### Stage 4 — Multi-round loop & iteration cap

- [ ] Agent performs 5+ tool calls in a single user turn; all render correctly
- [ ] Temporarily set `max_tool_iterations = 3`; give a task needing more; verify synthetic `📎: (iteration limit reached)` appears and loop stops
- [ ] After iteration limit hit, resubmit the buffer; parses cleanly, no Anthropic validation error

#### Stage 5 — Write tools with safety

- [ ] Agent tries to `write_file /tmp/out.txt` (absolute path outside cwd) → error tool_result, no file created
- [ ] Agent tries to `write_file ../outside.txt` → error tool_result, no file created
- [ ] Agent creates `scratch/hello.txt` inside repo → file created, `scratch/hello.txt.parley-backup` exists with `# parley:deleted-before-write` sentinel
- [ ] `*.parley-backup` auto-added to `.gitignore` in repo-mode on first write
- [ ] `edit_file` with non-existent `old_string` → error tool_result, file unchanged
- [ ] `edit_file` with `old_string` appearing 3 times, `replace_all=false` → error tool_result, file unchanged
- [ ] `edit_file` with `old_string` appearing 3 times, `replace_all=true` → all replaced, file updated
- [ ] Open `scratch/hello.txt` in a buffer, make unsaved edit, ask agent to `write_file` → dirty-buffer rejection, file untouched
- [ ] Open `scratch/hello.txt` with no unsaved changes, ask agent to `write_file` → file updated AND buffer reloaded via `:checktime`
- [ ] Repeat `write_file` on the same path twice in the same chat → `.parley-backup` still captures the earliest pre-image, not the intermediate one
- [ ] `git diff` shows clean, expected changes matching the agent's actions

#### Stage 6 — Cancellation under all scenarios

- [ ] **Case 1 — partial JSON**: start a long tool call, `<Esc>` during `input_json_delta` → partial `🔧:` block dropped, preceding text retained, resubmit parses cleanly
- [ ] **Case 2 — committed tool_use, not executed**: force via breakpoint/sleep in dispatcher, cancel, verify synthetic `📎: (cancelled by user)` appears
- [ ] **Case 3 — mid-execution**: run `grep` on huge tree, cancel during execution, verify synthetic `📎: (cancelled by user)`
- [ ] **Case 4 — during follow-up LLM response**: multi-roundtrip scenario, let 2 roundtrips finish, cancel during 3rd assistant response, verify completed roundtrips intact and partial text dropped
- [ ] After every case above, press `<C-g><C-g>` (resubmit) — agent continues gracefully, no Anthropic validation error
- [ ] `<C-g>x` still works as fallback cancel

#### Stage 7 — Buffer-is-state invariants under user editing

- [ ] Delete a `🔧:` block but leave its `📎:` → parser emits clean diagnostic, refuses to submit
- [ ] Manually edit a `📎: read_file` body to fake file contents → follow-up LLM sees the edited content (transcript-is-state)
- [ ] Save and reopen chat buffer → all `🔧:` / `📎:` blocks start auto-folded

#### Stage 8 — Visual / UX polish

- [ ] `<C-g>b` correctly toggles fold state of tool components in the exchange under cursor; no-op in exchanges without tool components
- [ ] Syntax highlighting visually distinct for `🔧:` vs `📎:` vs `🤖:` vs `💬:`
- [ ] Lualine indicator tracks current tool name and iteration count; disappears on loop end or cancel
- [ ] Outline navigation (`<C-g>l` or similar) includes tool components as entries
- [ ] Agent picker `[🔧]` badge visible in the picker float

#### Stage 9 — Regression lockdown

- [ ] `make lint` passes
- [ ] `make test` passes
- [ ] A vanilla chat with a vanilla (non-tools) agent produces byte-identical query cache JSON to pre-#81 (diff-check a few fixture prompts)

## Log

### 2026-04-08

- Decomposed the original issue into 3 sub-issues (#81 tool use, #82 constitution file, #83 skill system)
- Starting with #81 since #82 and #83 become trivial once tool use exists
- Entering brainstorming phase

### 2026-04-09

- Brainstorming session with user answered 6 design questions covering loop model, buffer representation, tool set, provider scope, enablement, and cancel semantics
- Key design decisions recorded in the Design Summary section above
- User raised "transcript as source of truth" backtrack vision → deferred to new sub-ticket #84
- User asked for consistent cache-freshness treatment of `@@` embeds and `📎: read_file` results → deferred to new sub-ticket #85
- User asked for explicit manual test stages with emphasis on PURE/DRY coding principles — added 9 stages and coding-principles subsection
- User clarified parley convention: `specs/` is for sketches only; detailed spec lives in the issue file under a `## Spec` section. Moved full design into this issue. A brief sketch will be added to `specs/providers/tool_use.md` only after implementation lands.
- User reviewed and approved the `## Spec` section
- Wrote implementation plan to [docs/plans/000081-anthropic-tool-use.md](../docs/plans/000081-anthropic-tool-use.md). Plan location `docs/plans/` is new (created for this); future plans follow the same `docs/plans/NNNNNN-slug.md` convention.
- Dispatched 5 plan-document-reviewer subagents in parallel (one per chunk). All 5 returned Issues Found with 17 blocking issues and ~20 advisory items.
- Fixed all 17 blocking issues in a single pass. Plan grew from ~1570 → ~3300 lines. Key fixes:
  - `ClaudeAgentTools` now ships as a real default agent (not commented-out sample)
  - Task ordering: builtin stubs register BEFORE config validation needs them
  - Provider→loop communication locked in as module-level `tool_loop.lua` state keyed by bufnr — NO globals
  - Serialize module uses dynamic-length fence backref (`%1`) to survive LLM output containing backticks; invalid Lua `?` quantifier removed
  - `pcall`-guarded `execute_call` so handler exceptions never leave orphan `🔧:`
  - Symlink resolution via `vim.loop.fs_realpath` with parent-dir fallback for new files
  - `.parley-backup` pre-image + truncation ordering: new `truncate_preserving_footer` guarantees the `pre-image:` metadata line is never chopped (critical for #84 replay)
  - Session-once gitignore flag pinned to dispatcher-local `M._gitignore_checked` table keyed by repo_root
  - Baseline byte-identity fixture capture moved to Task 1.0 PRE-M1 prerequisite (was buried in M9)
  - M6 partial-JSON detection algorithm pinned with 3 sub-cases (no fence / incomplete body / unclosed fence)
  - Cancel/iteration-cap synthetic-result helper lives in new `lua/parley/tools/synthetic.lua` landed in M4 Task 4.1; M6 is a pure consumer (DRY)
  - Tool-loop driver extracted to its own file `lua/parley/tool_loop.lua` to keep `chat_respond.lua` reasoning-sized
  - All prior collapsed `2.x.y – 2.x.z` one-line tasks in Chunks 1, 2, 3, 5 expanded to full TDD checkboxes with concrete test skeletons
- Advisory items (not fixed): expand remaining `...` placeholders in test descriptions, add a DRY `assert_buffer_reparsable` test helper (added to M6 intro instead), file-size concerns for `providers.lua` (advisory only — no split in v1)
- Re-dispatched 5 reviewers (iteration 2). Result: chunks 1, 3, 4, 5 Approved with minor issues; chunk 2 had remaining issues. Total 11 follow-up items (4 real bugs, 7 structural gaps).
- Fixed all 11 in a second pass. Key fixes:
  - Removed unreachable iteration-cap branch from M2 Task 2.7 (was dead code with `synth` constructed but never appended) — cap lifting deferred cleanly to M4 Task 4.1
  - Task 6.2 fence regex: `^(`+)[%w_%-]*%s*$` now accepts info-string fences like ` ```json` (the actual format render_call emits). Previous regex would drop every complete block.
  - Task 2.1 commit message converted to heredoc so triple backticks don't trigger shell command substitution
  - Task 7.1 parser diagnostics made symmetric (orphan 📎: flagged in addition to orphan 🔧:)
  - File Structure table updated with `tool_loop.lua`, `tool_folds.lua`, `synthetic.lua`, `assert_reparsable.lua`
  - Task 3.3 glob: dispatch now uses `vim.fn.globpath` for any `**`, handling both leading and middle-position recursion
  - Task 5.6 cwd-scope check made explicit in the `execute_call` implementation sketch as a SHARED prelude (was previously assumed from M2 but invisible in the code)
  - Task 5.1 extended to co-locate `_checktime_if_loaded` helper with `check_dirty_buffer` (was referenced but undefined)
  - Task 4.1 test comment contradiction ("4 times" vs "3 times") resolved
  - Task 5.7 gained explicit checkbox steps (was a bare heading)
  - Task 6.2 pinned algorithm now includes the other-prefix early-exit guard (previously was in impl but not in spec — drift fix)
- Plan is now at ~3420 lines across 5 chunks.
- Dispatched iteration-3 reviewers. Result: chunks 1, 4, 5 Approved; chunks 2 and 3 had 3 residual items total (dangling `elseif cap` branch in M2 hook pseudocode, stale commit message in Task 3.3.5, and `chat_respond.lua` caller-update ambiguity in Task 1.5). All 3 fixed.
- Plan is now ready for implementation. Starting point: Task 1.0 (PRE-M1 baseline fixture capture on current main before any #81 code lands).
- **Task 1.0 completed** (2026-04-09): user ran 3 prompts through a vanilla `claude-sonnet-4-6` agent on current main; captured the 3 request-payload JSONs into `tests/fixtures/pre_81_vanilla_claude_request_{1,2,3}.json` and recorded metadata in `tests/fixtures/pre_81_vanilla_claude_prompts.lua`.
- **Important finding during Task 1.0** — the baseline JSONs already contain `tools = [web_search, web_fetch]` because the user's agent has Anthropic's server-side web search enabled. This means M1 Task 1.5's client-side tool encoding MUST APPEND to the existing `payload.tools` list, not overwrite it. If we assign `payload.tools = <client tools>`, we clobber server-side web search AND break byte-identity for vanilla agents with web search. Spec section 4 and plan Task 1.5 both updated with the append-not-overwrite rule + a dedicated test case.
- Next: M1 Task 1.1 (tool types module). Ready to proceed.
