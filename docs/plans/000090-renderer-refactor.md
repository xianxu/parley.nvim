# #90 — Renderer refactor: pure position model

> Status: design phase. Brainstormed 2026-04-09. Approved by user before this doc was written.
> Issue: `issues/000090-renderer-refactor-for-pure-position-model.md`
> Blocks: `issues/000081-...` M2 Task 2.7 (currently failing intermittently with Anthropic `assistant message prefill` rejection on the recursive call)
> Blocks: `issues/000081-...` M2 Tasks 2.8, 2.9, 2.10, 2.11 and all of M3, M4, M5, M6
> Blocked by: nothing

---

## 0. Why

`lua/parley/chat_respond.lua::M.respond` computes buffer line positions imperatively through a chain of dependent variables and `+N` magic offsets. Each new state stacks another branch. Three rounds of #81 M2 Task 2.7 manual testing surfaced three distinct offset bugs in this code path. Adding M3/M4/M5/M6 tool-use features would multiply the branches further.

The fix is to extract a pure data model + pure render layer + single mutation entry point, with extmark-backed position handles for streaming. This makes buffer state deterministic and lets the existing dispatcher streaming-handler abstraction (which already uses extmarks correctly) apply to ALL mutation paths instead of just streaming.

---

## 1. Architecture overview

Three new modules + one extension to an existing module:

```
                                   ┌─────────────────────────────────────────┐
chat_parser.lua                    │  produces: exchanges[i].answer.sections │
  (extended)                       │  each section = { kind, line_start,     │
                                   │                   line_end, ...fields } │
                                   └────────────────┬────────────────────────┘
                                                    │ pure data
                                                    ▼
                                   ┌─────────────────────────────────────────┐
render_buffer.lua                  │  pure: section → lines[]                │
  (NEW)                            │  pure: exchange → lines[]               │
                                   │  pure: positions(exchanges) → spans     │
                                   └────────────────┬────────────────────────┘
                                                    │ describes WHAT to write
                                                    ▼
                                   ┌─────────────────────────────────────────┐
buffer_edit.lua                    │  insert_section_after(handle, section)  │
  (NEW)                            │  append_section_to_answer(buf, idx, …)  │
                                   │  delete_answer(buf, exchange_idx)       │
                                   │  replace_section(handle, section)       │
                                   │  stream_into(handle, chunk)             │
                                   │  →  ALL nvim_buf_set_lines live here    │
                                   │  →  returns extmark-backed PosHandle    │
                                   └────────────────┬────────────────────────┘
                                                    │ side effects
                                                    ▼
                                   ┌─────────────────────────────────────────┐
chat_respond.lua                   │  no more line arithmetic                │
  (refit)                          │  no more nvim_buf_set_lines             │
                                   │  uses semantic operations               │
                                   └─────────────────────────────────────────┘

tests/arch/arch_helper.lua          arch fitness functions (NEW)
```

**Invariants enforced by arch tests:**
1. `nvim_buf_set_lines` only in `buffer_edit.lua` (after Phase 3; `dispatcher.lua` exempt during Phases 0–2)
2. `nvim_buf_set_text` only in `buffer_edit.lua`
3. Pure files (`tools/types`, `tools/serialize`, `tools/init`) contain no `vim.api`/`vim.cmd`/`vim.schedule`/`vim.defer_fn`

---

## 2. Data model — chat_parser extension

`chat_parser.lua` keeps its current state machine. The `cb_state` machinery already tracks `current_kind` and `current_lines` per content block. The only addition: each block also records its line span as it goes.

```lua
-- chat_parser.lua, cb_start_block:
local function cb_start_block(kind, line_no)
    cb_state.current_kind = kind
    cb_state.current_lines = {}
    cb_state.current_line_start = line_no   -- NEW: 1-indexed buffer line
    cb_state.tool_fence_len = nil
    cb_state.tool_body_complete = false
end

-- cb_finalize_block:
local function cb_finalize_block(line_no)
    -- ... existing parse/decode logic ...
    table.insert(cb_state.blocks, {
        kind = kind,                                  -- renamed from `type` for clarity
        line_start = cb_state.current_line_start,    -- NEW
        line_end = line_no - 1,                      -- NEW (1-indexed, inclusive)
        -- ...kind-specific fields (text, id, name, input, content, is_error)
    })
end
```

**Naming:**
- `answer.sections` is the new name. `answer.content_blocks` becomes a read-only alias pointing to the same table for backward compat with `_emit_content_blocks_as_messages`.
- `answer.content` (flat string) is kept untouched — many readers still depend on it.

**Helpers exposed by chat_parser** (pure functions, callable from render_buffer / buffer_edit):

```lua
M.find_exchange_at_line(parsed, line_no) → exchange_idx | nil
M.find_section_at_line(parsed, line_no) → exchange_idx, section_idx | nil
M.last_section_in_answer(parsed, exchange_idx) → section | nil
```

**Field redundancy note**: `line_start` is technically derivable from `line_count` of preceding sections, but stored explicitly for O(1) random access. The renderer reads positions on every edit.

**Tests**:
- Existing `chat_parser_tools_spec.lua` 11 tests stay green (sections is a superset of content_blocks)
- New tests assert `line_start/line_end` for every block kind: text-only, single tool_use, tool_use+result pair, multiple rounds, mixed text-and-tools, fenced bodies with backticks, blocks at start/middle/end of answer

---

## 3. `lua/parley/buffer_edit.lua` — single mutation entry point

Pure module API (no globals, no state). All functions take `buf` as first arg. Returns `PosHandle` opaque type for chaining.

```lua
local M = {}

-- ============================================================================
-- PosHandle: opaque extmark-backed position. Caller never sees line numbers.
-- ============================================================================
-- Internally: { buf, ns_id, ex_id }
-- Resolved on demand via nvim_buf_get_extmark_by_id.
-- right_gravity = false means inserts AT the position push the handle right.

M.make_handle(buf, line_0_indexed) → PosHandle
M.handle_line(handle) → integer  -- current resolved line
M.handle_invalidate(handle)      -- delete extmark, mark dead

-- ============================================================================
-- Topic header
-- ============================================================================
M.set_topic_header_line(buf, line_0_indexed, text)
M.insert_topic_line(buf, after_line_0_indexed, text)

-- ============================================================================
-- Question region
-- ============================================================================
M.pad_question_with_blank(buf, exchange)

-- ============================================================================
-- Answer region — the core of the refactor
-- ============================================================================
M.create_answer_region(buf, exchange, agent_prefix) → PosHandle
M.insert_raw_request_fence(buf, answer_handle, fence_lines)
M.append_section_to_answer(buf, exchange_idx, section) → PosHandle
M.replace_answer(buf, exchange) → PosHandle
M.delete_answer(buf, exchange)

-- ============================================================================
-- Streaming
-- ============================================================================
-- Replaces dispatcher.create_handler's two raw nvim_buf_set_lines.
M.stream_into(handle, chunk)
M.stream_finalize(handle)

-- ============================================================================
-- Progress indicator
-- ============================================================================
M.set_progress_line(handle, text)
M.clear_progress_lines(handle, count)

-- ============================================================================
-- Cancellation cleanup
-- ============================================================================
M.delete_lines_after(handle, n_lines)
M.append_blank_at_end(buf)

return M
```

**Key design points**:

1. **Every mutation that needs follow-up returns a `PosHandle`.** Callers chain: `local h = create_answer_region(...); insert_raw_request_fence(buf, h, ...); local stream_h = append_section_to_answer(buf, idx, {kind="text", text=""}); stream_into(stream_h, chunk)`.

2. **No raw line numbers cross the boundary.** Once you have a handle, you re-read the line via `handle_line()` only when you need to log or debug — never to compute the next operation.

3. **Streaming is now `buffer_edit`'s responsibility.** `dispatcher.create_handler` shrinks to just "extract chunks from SSE → call `buffer_edit.stream_into(handle, chunk)`". The two `nvim_buf_set_lines` in dispatcher migrate INTO `buffer_edit.stream_into`. After Phase 3, dispatcher has zero raw mutations.

4. **`render_buffer.lua` stays purely functional.** It produces lines from sections. `buffer_edit.lua` calls into it whenever it needs to render a section before writing. There's no "render and write" combined op — they compose.

**Tests** for `buffer_edit.lua` use a real scratch buffer (`vim.api.nvim_create_buf(false, true)`) — not mocks — because the whole point is exercising real `nvim_buf_set_lines` semantics. Estimated ~35 tests covering each entry point + edge cases (empty buffer, handle invalidation, concurrent inserts shifting handles).

---

## 4. `lua/parley/render_buffer.lua` — pure render layer

Pure module. Inputs are pure data, outputs are line arrays. No buffer access, no nvim API beyond `vim.json.encode` and `vim.tbl_*`. Goes in the `PURE_FILES` arch list.

```lua
local M = {}

-- Section rendering — produces the lines a section occupies in the buffer.
-- Dispatches by kind. Delegates tool_use/tool_result to lua/parley/tools/serialize.lua
-- (single source of truth for the schema, same as today).
M.render_section(section) → string[]

-- Exchange rendering — the full block for one Q+A pair.
-- Used for golden-snapshot tests (round-trip: parse → render == original).
M.render_exchange(exchange) → string[]

-- Position computation — pure function from the parsed model.
-- Walks exchanges in order, accumulates line counts. Used in tests
-- to verify round-trip consistency:
--   parse(lines) → exchanges
--   positions(exchanges) → spans
--   spans must equal exchange.answer.sections[i].{line_start,line_end}
M.positions(parsed_chat) → { exchanges = [...] }

-- Standalone helpers
M.agent_header_lines(agent_prefix, agent_suffix) → string[]
M.raw_request_fence_lines(payload) → string[]

return M
```

**Tests** (~25):
- Each section kind renders identically to current `serialize.render_call/render_result` output (delegation works)
- Multi-section answer renders as flat list with no extra blanks
- `render_exchange(parse(lines)[0])` round-trips to original lines for every fixture in `tests/fixtures/transcripts/`
- `positions(parse(lines))` agrees with parser's recorded spans
- Empty answer / tool-only answer / text-then-tool / tool-then-text edge cases

---

## 5. `tests/arch/arch_helper.lua` — architecture fitness functions

Single primary helper:

```lua
local M = {}

-- Assert that `pattern` (literal string, default; or Lua pattern if `is_pattern = true`)
-- appears ONLY in files listed in `allow_only_in`, within the file set defined by `scope`.
--
-- scope: glob string ("lua/parley/**/*.lua") OR list of file paths
-- allow_only_in: list of file paths exempt from the rule. Empty list = pattern forbidden in all of scope.
-- ignore_comments: skip lines that start with `--` (default true)
-- rationale: human-readable explanation surfaced in failure output
function M.assert_pattern_scoping(opts) end

return M
```

**Failure output** is human-readable:

```
arch: buffer mutation boundary
  no raw nvim_buf_set_lines outside buffer_edit.lua ... FAILED

  Rationale: #90: single mutation entry point

  Violations (3):
    lua/parley/chat_respond.lua:1020: vim.api.nvim_buf_set_lines(buf, response_line, ...)
    lua/parley/chat_respond.lua:1094: vim.api.nvim_buf_set_lines(buf, progress_line, ...)
    lua/parley/tool_loop.lua:91: vim.api.nvim_buf_set_lines(bufnr, last, last, ...)

  Allowed in: lua/parley/buffer_edit.lua, lua/parley/dispatcher.lua
```

**Initial rule set** (`tests/arch/buffer_mutation_spec.lua`):
1. `nvim_buf_set_lines` allowed only in `buffer_edit.lua` + `dispatcher.lua` (tightened in Phase 3)
2. `nvim_buf_set_text` allowed only in `buffer_edit.lua`
3. Pure files have no `vim.api/cmd/schedule/defer_fn`:

```lua
local PURE_FILES = {
    "lua/parley/tools/types.lua",
    "lua/parley/tools/serialize.lua",
    "lua/parley/tools/init.lua",
}
for _, forbidden in ipairs({ "vim%.api%.", "vim%.cmd", "vim%.schedule", "vim%.defer_fn" }) do
    it("pure files: no " .. forbidden, function()
        arch.assert_pattern_scoping({
            pattern = forbidden,
            is_pattern = true,
            scope = PURE_FILES,
            allow_only_in = {},
            rationale = "designated pure data transforms; no nvim state interaction",
        })
    end)
end
```

Future arch rules (deferred): `tools/builtin/*` shouldn't import `parley.chat_respond`/`parley.dispatcher`; `tools/*` shouldn't import provider code; etc.

---

## 6. Anthropic interaction harness

`scripts/test-anthropic-interaction.sh <transcript.md>` — one-shot payload sender, NOT a tool-loop runner. Exercises parser → build_messages → prepare_payload → real Anthropic API.

```bash
#!/usr/bin/env bash
set -euo pipefail
TRANSCRIPT="${1:?usage: $0 <transcript.md>}"
nvim --headless -u NORC \
    -c "luafile scripts/parley_harness.lua" \
    -c "lua require('parley_harness').run('$TRANSCRIPT')" \
    -c "qa!"
```

**Lua entry point** `scripts/parley_harness.lua` (~80 lines):
1. Bootstraps parley
2. Reads the transcript file
3. `chat_parser.parse_chat`
4. `chat_respond._build_messages` with `exchange_idx = last`
5. `dispatcher.prepare_payload`
6. Writes JSON payload to stdout (for inspection / golden capture)
7. Optionally curls to Anthropic and prints response status + body

**Env vars:**
- `ANTHROPIC_API_KEY` (required for live mode)
- `PARLEY_HARNESS_DRY_RUN=1` — skip curl, just print payload (CI-safe)

**Fixture transcripts** in `tests/fixtures/transcripts/`:
- `single-user.md` — bare `💬:` question (baseline)
- `simple-chat.md` — one full Q→A round, no tools
- `one-round-tool-use.md` — `💬:` + `🤖:` + `🔧:` + `📎:` (the recursion shape)
- `two-round-tool-use.md` — stacked `🔧:/📎:` pairs
- `mixed-text-and-tools.md` — text before, between, after tool blocks
- `tool-error.md` — `📎:` with `is_error=true`
- `dynamic-fence-stress.md` — content body containing nested ``` fences requiring 5+ backticks

Each fixture also serves as a **golden snapshot** for `render_buffer.render_exchange`: parse → render must equal the original file byte-for-byte.

**Golden JSON payloads** captured via dry-run mode, saved to `tests/fixtures/golden_payloads/<fixture>.json`. A unit test asserts `harness round-trip == golden`, catching future drift.

---

## 7. Test strategy summary

| Layer | Catches |
|---|---|
| Unit tests (`chat_parser`, `render_buffer`, `buffer_edit`, `arch_helper`) | Logic bugs in pure functions, individual buffer_edit operations |
| Architecture tests | Backsliding (someone adds raw mutation, breaks pure-file invariant) |
| Harness dry-run + golden payloads | Payload shape regressions |
| Harness live mode | Real Anthropic compatibility (run on demand, not in CI) |
| Round-trip render (parse→render==original) | Parser/renderer asymmetry |

**Estimated test counts**: ~321 existing + ~85 new = ~406 total.

---

## 8. Migration order — strict ordering, each step ends green and deployable

### Phase 0 — Infrastructure (no behavior changes)
1. Land `tests/arch/arch_helper.lua` + meta tests for the helper itself
2. Land `tests/arch/buffer_mutation_spec.lua` with the 3 rules (initial `allow_only_in` baselined wide enough to pass against current code)
3. Land `scripts/parley_harness.lua` + `scripts/test-anthropic-interaction.sh` + 7 fixture transcripts
4. Capture golden JSON payloads via `PARLEY_HARNESS_DRY_RUN=1`
5. Add unit test: harness round-trip == golden payload

After Phase 0: zero production code changed, full safety net deployed.

### Phase 1 — Pure layers (no chat_respond changes)
6. Extend `chat_parser.lua` with `line_start/line_end` per section + new helpers
7. Add `lua/parley/render_buffer.lua` with all functions + tests
8. Add `lua/parley/buffer_edit.lua` with all entry points + tests (real scratch buffers)

After Phase 1: new infrastructure exists, nothing in `chat_respond.lua` calls it yet, all existing tests still green.

### Phase 2 — Migrate `chat_respond.lua` mutations (one logical group per commit)
9. Topic header group (4 sites at lines 159/166/170/174)
10. Question padding (site at 975)
11. Answer region creation (site at 1020 — the big one)
12. Raw request fence (site at 1060)
13. Progress indicator (sites at 1094, 1136)
14. Cancellation cleanup (sites at 1248, 1259, 1262)
15. Replace existing answer (site at 944)
16. Delete dead code: `progress_line / response_start_line / raw_request_offset / in_tool_loop_recursion / response_block_lines` variables and their branching

After Phase 2: `chat_respond.M.respond` has zero `nvim_buf_set_lines`. Arch test #1 narrows `allow_only_in` to `{ buffer_edit.lua, dispatcher.lua }` and stays green.

### Phase 3 — Migrate streaming + tool_loop
17. Migrate `tool_loop.lua::_append_block_to_buffer` to `buffer_edit.append_section_to_answer`
18. Migrate `dispatcher.create_handler` streaming writes to `buffer_edit.stream_into(handle, chunk)`
19. Tighten arch test #1: `allow_only_in = { "lua/parley/buffer_edit.lua" }`

After Phase 3: ONE file in the entire plugin contains `nvim_buf_set_lines`, and arch tests guard it forever.

### Phase 4 — Re-validate #81 M2
20. Run `make test` — full suite green
21. Run `scripts/test-anthropic-interaction.sh tests/fixtures/transcripts/one-round-tool-use.md` in live mode
22. Manual: vanilla chat (no tools) — expect byte-identical
23. Manual: ClaudeAgentTools → "read lua/parley/init.lua" — expect clean tool round-trip
24. Resume #81 M2 Task 2.7 verification list (the original 9 manual test steps)
25. Add Log entries to #90 and #81

The whole refactor is ~25 commits.

---

## 9. Out of scope (deferred)

| Item | Why deferred |
|---|---|
| Unifying `question` / `summary` / `thinking` into `sections[]` | YAGNI; not load-bearing for offset bugs |
| `lua/parley/highlighter.lua` mutation review | Uses extmark/virt_text, not `set_lines/set_text` — orthogonal |
| Folding for `🔧:/📎:` regions (#81 M2 Task 2.8) | Resumes after #90 lands |
| `<C-g>b` toggle shortcut (#81 M2 Task 2.9) | Resumes after #90 lands |
| Migrating other providers' tool encoders | #81 says client tools = anthropic-only v1 |
| Removing `answer.content` flat string | Many readers still depend on it; free to keep |
| Removing `answer.content_blocks` alias | Same — keep as alias to `sections` until all callers migrate |
| Renaming `cb_state` / `cb_*` functions in chat_parser | Cosmetic; defer to a follow-up cleanup |
| Splitting `chat_respond.lua` into multiple files | The 1580→~1200 LOC reduction makes this less urgent |
| OpenAI / Google / Ollama provider tool support | #81 follow-up issues |
| `assert_file_contains_only` arch helper | No concrete need yet |
| Live-mode harness in CI | Live API calls in CI need budget + key management decision |

---

## 10. Risks

| Risk | Mitigation |
|---|---|
| `buffer_edit.lua` API turns out to need a 16th entry point | Land Phase 0+1 first, exercise via Phase 2 migration. Add new entry point inside `buffer_edit.lua`, never inline raw mutation. Arch tests prevent backsliding. |
| Extmark gravity surprise during streaming | `dispatcher.create_handler` already proves the extmark approach works. Reuse the exact same gravity setting (`right_gravity = false`). Tests cover concurrent insert behavior. |
| Refactor doesn't fix the intermittent Anthropic rejection | Acceptable. The refactor's value is determinism + maintainability. Post-refactor we debug the bug with the harness in a stable codebase. |
| Hidden state in `chat_respond.M.respond` (closures, upvalues) breaks when offset variables get deleted in step 16 | Each migration commit runs full `make test`. Phase 2 commits are small, isolated, reversible. |
| Golden payload snapshots become noise (tiny irrelevant changes break them) | Use stable JSON encoding; failures print diff so changes are reviewable, not a black box |
| Round-trip render (parse→render==original) fails on edge cases | Add fixture coverage for each edge case; treat as a bug in render_buffer, not a "test is too strict" concession |

---

## 11. Definition of done

- [ ] All Phase 0–4 commits landed
- [ ] `make test` green
- [ ] 3 arch tests green and tightened to final scope
- [ ] `chat_respond.lua` LOC reduced (target ≥300 lines deleted)
- [ ] `grep -rn "nvim_buf_set_lines\|nvim_buf_set_text" lua/parley/` returns ONLY `lua/parley/buffer_edit.lua`
- [ ] Manual: vanilla chat works, ClaudeAgentTools tool round-trip works
- [ ] `issues/000081-...` Log entry: "M2 Task 2.7 unblocked by #90; resuming"
- [ ] `issues/000090-...` Log entry: closed; lessons recorded
- [ ] Code review via `superpowers:code-reviewer` subagent (the same gate #81 M2 Task 2.11 was waiting on)
