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

---

# Implementation Plan

> **For agentic workers:** Use TDD per task. Each task ends with a clean commit. Chunks 0–3 are sequential — do not start Chunk N+1 until Chunk N is fully green. Chunk 4 is manual validation.

**Goal:** Refactor parley's chat buffer rendering to a pure data model + single mutation entry point, eliminating the offset-arithmetic bugs that block #81 M2 Task 2.7.

**Architecture:** See sections 1–4 above.

**Tech Stack:** Lua 5.1 / LuaJIT, Neovim 0.10+, plenary.nvim/busted via `make test`.

**Conventions for every task:**
- Test files use `(os.getenv("TMPDIR") or "/tmp") .. "/claude/parley-test-..."` for any tmp dirs (sandbox-friendly per `tasks/lessons.md` 2026-04-09)
- Run `make test` after every commit; refuse to advance if any test fails
- Commit messages: `feat(90): ...`, `refactor(90): ...`, `test(90): ...`, `chore(90): ...` — single commit per task unless the task explicitly says otherwise
- After every commit, update progress in this plan (check the box) before moving on

---

## Chunk 0: Phase 0 — Infrastructure (no behavior changes)

> Goal of this chunk: full safety net deployed before any production code is touched. After Chunk 0 is green, the refactor has arch-test guards, an offline payload-shape harness, golden snapshots, and round-trip fixture coverage.

### Task 0.1: arch_helper.assert_pattern_scoping (literal-string mode)

**Files:**
- Create: `tests/arch/arch_helper.lua`
- Test: `tests/unit/arch_helper_spec.lua`

- [ ] **Step 1: Write the failing test**

```lua
-- tests/unit/arch_helper_spec.lua
local arch = require("tests.arch.arch_helper")
local tmp = (os.getenv("TMPDIR") or "/tmp") .. "/claude/parley-test-arch-" .. os.time()
vim.fn.mkdir(tmp, "p")

local function write(path, lines)
    vim.fn.writefile(lines, tmp .. "/" .. path)
end

describe("arch_helper.assert_pattern_scoping (literal)", function()
    before_each(function()
        vim.fn.delete(tmp, "rf"); vim.fn.mkdir(tmp, "p")
    end)

    it("passes when pattern is absent from scope", function()
        write("a.lua", { "local x = 1" })
        assert.has_no.errors(function()
            arch.assert_pattern_scoping({
                pattern = "FORBIDDEN",
                scope = { tmp .. "/a.lua" },
                allow_only_in = {},
                rationale = "test rule",
            })
        end)
    end)

    it("fails when pattern appears in a non-allowed file", function()
        write("a.lua", { "FORBIDDEN call" })
        local ok, err = pcall(arch.assert_pattern_scoping, {
            pattern = "FORBIDDEN",
            scope = { tmp .. "/a.lua" },
            allow_only_in = {},
            rationale = "no FORBIDDEN allowed",
        })
        assert.is_false(ok)
        assert.matches("a%.lua:1", err)
        assert.matches("no FORBIDDEN allowed", err)
    end)

    it("passes when pattern appears only in allow_only_in files", function()
        write("a.lua", { "FORBIDDEN call" })
        write("b.lua", { "local x = 1" })
        assert.has_no.errors(function()
            arch.assert_pattern_scoping({
                pattern = "FORBIDDEN",
                scope = { tmp .. "/a.lua", tmp .. "/b.lua" },
                allow_only_in = { tmp .. "/a.lua" },
                rationale = "ok in a only",
            })
        end)
    end)
end)
```

- [ ] **Step 2: Run test, verify it fails**

```bash
nvim --headless -c "PlenaryBustedFile tests/unit/arch_helper_spec.lua" -c qa 2>&1 | tail -20
```
Expected: failure — `tests/arch/arch_helper.lua` doesn't exist yet.

- [ ] **Step 3: Implement minimal `arch_helper.lua`**

```lua
-- tests/arch/arch_helper.lua
local M = {}

local function read_lines(path)
    local f = io.open(path, "r")
    if not f then return nil end
    local lines = {}
    for line in f:lines() do table.insert(lines, line) end
    f:close()
    return lines
end

local function expand_scope(scope)
    if type(scope) == "string" then
        return vim.fn.glob(scope, false, true)
    end
    return scope or {}
end

--- @param opts {pattern: string, scope: string|string[], allow_only_in: string[],
---              rationale: string, ignore_comments?: boolean, is_pattern?: boolean}
function M.assert_pattern_scoping(opts)
    local pattern = opts.pattern
    local files = expand_scope(opts.scope)
    local allow = {}
    for _, p in ipairs(opts.allow_only_in or {}) do allow[p] = true end
    local ignore_comments = opts.ignore_comments ~= false  -- default true
    local plain = not opts.is_pattern  -- string.find plain mode unless is_pattern=true

    local violations = {}
    for _, file in ipairs(files) do
        if not allow[file] then
            local lines = read_lines(file)
            if lines then
                for i, line in ipairs(lines) do
                    local stripped = line:gsub("^%s+", "")
                    local is_comment = ignore_comments and stripped:sub(1, 2) == "--"
                    if not is_comment and string.find(line, pattern, 1, plain) then
                        table.insert(violations, string.format("    %s:%d: %s", file, i, line))
                    end
                end
            end
        end
    end

    if #violations > 0 then
        local msg = string.format(
            "\n\n  Rationale: %s\n\n  Violations (%d):\n%s\n\n  Allowed in: %s\n",
            opts.rationale or "(no rationale)",
            #violations,
            table.concat(violations, "\n"),
            table.concat(opts.allow_only_in or {}, ", ")
        )
        error(msg, 2)
    end
end

return M
```

- [ ] **Step 4: Run test, verify pass**

```bash
nvim --headless -c "PlenaryBustedFile tests/unit/arch_helper_spec.lua" -c qa 2>&1 | tail -10
```
Expected: 3 successes.

- [ ] **Step 5: Commit**

```bash
git add tests/arch/arch_helper.lua tests/unit/arch_helper_spec.lua
git commit -m "feat(90): arch_helper.assert_pattern_scoping (literal mode)"
```

---

### Task 0.2: arch_helper Lua-pattern mode + comment skipping

**Files:**
- Modify: `tests/arch/arch_helper.lua` (already supports `is_pattern` flag from Task 0.1; add tests)
- Test: `tests/unit/arch_helper_spec.lua`

- [ ] **Step 1: Add failing tests for Lua-pattern mode and comment skipping**

```lua
describe("arch_helper.assert_pattern_scoping (lua pattern + comments)", function()
    before_each(function()
        vim.fn.delete(tmp, "rf"); vim.fn.mkdir(tmp, "p")
    end)

    it("respects is_pattern = true (Lua pattern matching)", function()
        write("a.lua", { "vim.api.nvim_buf_set_lines(buf, 0, -1, false, {})" })
        local ok = pcall(arch.assert_pattern_scoping, {
            pattern = "vim%.api%.",
            is_pattern = true,
            scope = { tmp .. "/a.lua" },
            allow_only_in = {},
            rationale = "no vim.api in pure files",
        })
        assert.is_false(ok)
    end)

    it("skips lines starting with -- when ignore_comments = true (default)", function()
        write("a.lua", { "-- mention of FORBIDDEN in a comment" })
        assert.has_no.errors(function()
            arch.assert_pattern_scoping({
                pattern = "FORBIDDEN",
                scope = { tmp .. "/a.lua" },
                allow_only_in = {},
                rationale = "comments don't count",
            })
        end)
    end)

    it("does NOT skip comments when ignore_comments = false", function()
        write("a.lua", { "-- mention of FORBIDDEN" })
        local ok = pcall(arch.assert_pattern_scoping, {
            pattern = "FORBIDDEN",
            scope = { tmp .. "/a.lua" },
            allow_only_in = {},
            rationale = "comments count too",
            ignore_comments = false,
        })
        assert.is_false(ok)
    end)

    it("scope can be a glob string", function()
        write("a.lua", { "FORBIDDEN" })
        write("b.lua", { "FORBIDDEN" })
        local ok = pcall(arch.assert_pattern_scoping, {
            pattern = "FORBIDDEN",
            scope = tmp .. "/*.lua",
            allow_only_in = {},
            rationale = "no forbidden",
        })
        assert.is_false(ok)
    end)
end)
```

- [ ] **Step 2: Run, verify pass** (the `is_pattern` and comment logic should already work from Task 0.1; this task just locks the behavior in tests).

```bash
nvim --headless -c "PlenaryBustedFile tests/unit/arch_helper_spec.lua" -c qa 2>&1 | tail -10
```
Expected: 7 total successes (3 from Task 0.1 + 4 new).

- [ ] **Step 3: Commit**

```bash
git add tests/unit/arch_helper_spec.lua
git commit -m "test(90): arch_helper Lua patterns, comment skip, glob scope"
```

---

### Task 0.3: arch test — buffer mutation boundary (baseline scope)

**Files:**
- Create: `tests/arch/buffer_mutation_spec.lua`

- [ ] **Step 1: Write the test with baseline `allow_only_in`**

```lua
-- tests/arch/buffer_mutation_spec.lua
local arch = require("tests.arch.arch_helper")

describe("arch: buffer mutation boundary", function()
    -- Baseline scope: every file currently using nvim_buf_set_lines is allowed.
    -- Phase 2 + Phase 3 of #90 will narrow this list one file at a time until
    -- only buffer_edit.lua remains.
    it("nvim_buf_set_lines callers (baseline)", function()
        arch.assert_pattern_scoping({
            pattern = "nvim_buf_set_lines",
            scope = "lua/parley/**/*.lua",
            allow_only_in = {
                "lua/parley/chat_respond.lua",
                "lua/parley/dispatcher.lua",
                "lua/parley/tool_loop.lua",
                -- buffer_edit.lua will be added in Phase 1 and others removed in Phase 2/3
            },
            rationale = "#90: buffer mutation must flow through buffer_edit.lua (baseline scope; tightens through phases)",
        })
    end)

    it("nvim_buf_set_text callers", function()
        arch.assert_pattern_scoping({
            pattern = "nvim_buf_set_text",
            scope = "lua/parley/**/*.lua",
            allow_only_in = {},  -- not used anywhere today; lock that in
            rationale = "#90: nvim_buf_set_text must only be used via buffer_edit.lua",
        })
    end)
end)

describe("arch: pure files have no nvim state interaction", function()
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
end)
```

- [ ] **Step 2: Run, verify all pass against current `main`**

```bash
nvim --headless -c "PlenaryBustedFile tests/arch/buffer_mutation_spec.lua" -c qa 2>&1 | tail -15
```
Expected: 6 successes (1 set_lines baseline + 1 set_text + 4 pure file rules).

- [ ] **Step 3: Verify the test would fail if a violation is introduced** (manual sanity check):

```bash
# Temporarily add a forbidden call to a pure file
sed -i '' '1a\
local _ = vim.api.nvim_get_current_buf()
' lua/parley/tools/serialize.lua
nvim --headless -c "PlenaryBustedFile tests/arch/buffer_mutation_spec.lua" -c qa 2>&1 | tail -15
# Expected: "pure files: no vim.api." FAILS with the violation
git checkout lua/parley/tools/serialize.lua
```

- [ ] **Step 4: Commit**

```bash
git add tests/arch/buffer_mutation_spec.lua
git commit -m "test(90): arch baseline — buffer mutation boundary + pure files"
```

---

### Task 0.4: parley_harness.lua — entry point + dry-run mode

**Files:**
- Create: `scripts/parley_harness.lua`
- Test: `tests/unit/parley_harness_spec.lua`

- [ ] **Step 1: Write the failing test**

```lua
-- tests/unit/parley_harness_spec.lua
local harness = require("scripts.parley_harness")
local tmp = (os.getenv("TMPDIR") or "/tmp") .. "/claude/parley-harness-test-" .. os.time()
vim.fn.mkdir(tmp, "p")

local function write_transcript(name, lines)
    local p = tmp .. "/" .. name
    vim.fn.writefile(lines, p)
    return p
end

describe("parley_harness", function()
    it("builds an Anthropic payload from a single-user transcript", function()
        local p = write_transcript("single-user.md", {
            "---",
            "topic: test",
            "file: dummy.md",
            "model: claude-sonnet-4-6",
            "provider: anthropic",
            "---",
            "",
            "💬: hello",
        })
        local payload = harness.build_payload(p)
        assert.equals("claude-sonnet-4-6", payload.model)
        assert.equals(1, #payload.messages)
        assert.equals("user", payload.messages[1].role)
        assert.matches("hello", payload.messages[1].content)
    end)

    it("builds a tool-loop recursive payload (3 messages ending in user[tool_result])", function()
        local p = write_transcript("one-round.md", {
            "---",
            "topic: t",
            "file: dummy.md",
            "model: claude-sonnet-4-6",
            "provider: anthropic",
            "---",
            "",
            "💬: read foo.txt",
            "",
            "🤖: [Claude]",
            "🔧: read_file id=toolu_X",
            "```json",
            '{"path":"foo.txt"}',
            "```",
            "📎: read_file id=toolu_X",
            "````",
            "    1  hi",
            "````",
        })
        local payload = harness.build_payload(p)
        assert.equals(3, #payload.messages)
        assert.equals("user", payload.messages[1].role)
        assert.equals("assistant", payload.messages[2].role)
        assert.equals("user", payload.messages[3].role)
        assert.equals("table", type(payload.messages[3].content))
        assert.equals("tool_result", payload.messages[3].content[1].type)
    end)
end)
```

- [ ] **Step 2: Run, verify it fails** (`scripts/parley_harness.lua` not found)

- [ ] **Step 3: Implement `parley_harness.lua`**

```lua
-- scripts/parley_harness.lua
-- Offline payload builder for parley transcripts. Used by
-- scripts/test-anthropic-interaction.sh and by unit tests.
--
-- Usage from Lua:
--   local payload = require("scripts.parley_harness").build_payload("path/to/transcript.md")
--
-- Usage from shell (via the .sh wrapper):
--   PARLEY_HARNESS_DRY_RUN=1 scripts/test-anthropic-interaction.sh transcript.md

local M = {}

local function load_lines(path)
    local f = assert(io.open(path, "r"), "cannot open transcript: " .. path)
    local lines = {}
    for line in f:lines() do table.insert(lines, line) end
    f:close()
    return lines
end

--- Build the Anthropic payload that would be sent for the LAST exchange
--- in the transcript. This mirrors the chat_respond → dispatcher path.
function M.build_payload(transcript_path)
    -- Bootstrap parley if not already done.
    local parley = require("parley")
    if not parley._state then
        parley.setup({
            chat_dir = (os.getenv("TMPDIR") or "/tmp") .. "/claude/parley-harness",
            state_dir = (os.getenv("TMPDIR") or "/tmp") .. "/claude/parley-harness/state",
            providers = {},
            api_keys = {},
        })
    end

    local lines = load_lines(transcript_path)
    local chat_parser = require("parley.chat_parser")
    local cfg = require("parley.config")
    local parsed = chat_parser.parse_chat(lines, chat_parser.find_header_end(lines), cfg)

    local exchange_idx = #parsed.exchanges
    assert(exchange_idx > 0, "transcript has no exchanges: " .. transcript_path)

    -- Resolve the agent from headers (model + provider override the default)
    local agent = parley.get_agent(parsed.headers.agent or "Claude-Sonnet")
    if parsed.headers.model then agent.model = { model = parsed.headers.model } end
    if parsed.headers.provider then agent.provider = parsed.headers.provider end

    local messages = parley._build_messages({
        parsed_chat = parsed,
        start_index = 1,
        end_index = #lines,
        exchange_idx = exchange_idx,
        agent = agent,
        config = cfg,
        helpers = require("parley.helper"),
        logger = { debug = function() end, warning = function() end },
    })

    local dispatcher = require("parley.dispatcher")
    local payload = dispatcher.prepare_payload(messages, agent.model, agent.provider, agent.tools)
    return payload
end

--- CLI entry point — called from the shell wrapper.
function M.run(transcript_path)
    local payload = M.build_payload(transcript_path)
    local json = vim.json.encode(payload)
    -- Pretty-print via python3 if available
    local pretty = vim.fn.system({ "python3", "-m", "json.tool" }, json)
    if vim.v.shell_error == 0 then json = pretty end

    if os.getenv("PARLEY_HARNESS_DRY_RUN") == "1" then
        io.stdout:write("=== PAYLOAD (dry run) ===\n")
        io.stdout:write(json)
        io.stdout:write("\n")
        return
    end

    local key = os.getenv("ANTHROPIC_API_KEY")
    if not key or key == "" then
        io.stderr:write("ANTHROPIC_API_KEY not set; use PARLEY_HARNESS_DRY_RUN=1 for offline mode\n")
        os.exit(1)
    end

    -- Write payload to a temp file and curl it
    local tmpfile = vim.fn.tempname() .. ".json"
    local f = assert(io.open(tmpfile, "w"))
    f:write(json); f:close()

    local cmd = {
        "curl", "-s", "-w", "\nHTTP %{http_code}\n",
        "https://api.anthropic.com/v1/messages",
        "-H", "Content-Type: application/json",
        "-H", "x-api-key: " .. key,
        "-H", "anthropic-version: 2023-06-01",
        "-d", "@" .. tmpfile,
    }
    local out = vim.fn.system(cmd)
    io.stdout:write("=== PAYLOAD ===\n" .. json .. "\n=== RESPONSE ===\n" .. out .. "\n")
    os.remove(tmpfile)
end

return M
```

- [ ] **Step 4: Run, verify pass**

```bash
nvim --headless -c "PlenaryBustedFile tests/unit/parley_harness_spec.lua" -c qa 2>&1 | tail -15
```
Expected: 2 successes.

- [ ] **Step 5: Commit**

```bash
git add scripts/parley_harness.lua tests/unit/parley_harness_spec.lua
git commit -m "feat(90): parley_harness Lua entry point + dry-run mode"
```

---

### Task 0.5: test-anthropic-interaction.sh shell wrapper

**Files:**
- Create: `scripts/test-anthropic-interaction.sh`

- [ ] **Step 1: Write the script**

```bash
#!/usr/bin/env bash
# Offline payload-shape tester for parley transcripts.
#
# Usage:
#   scripts/test-anthropic-interaction.sh <transcript.md>
#
# Env:
#   PARLEY_HARNESS_DRY_RUN=1   Skip the curl, just print the JSON payload (CI-safe)
#   ANTHROPIC_API_KEY=...      Required for live mode
set -euo pipefail

TRANSCRIPT="${1:?usage: $0 <transcript.md>}"
if [ ! -f "$TRANSCRIPT" ]; then
    echo "transcript not found: $TRANSCRIPT" >&2
    exit 1
fi

# Resolve to absolute path so nvim --headless finds it regardless of cwd.
TRANSCRIPT_ABS="$(cd "$(dirname "$TRANSCRIPT")" && pwd)/$(basename "$TRANSCRIPT")"
PROJECT_ROOT="$(cd "$(dirname "$0")/.." && pwd)"

cd "$PROJECT_ROOT"
nvim --headless -u NORC \
    -c "set rtp+=$PROJECT_ROOT" \
    -c "lua package.path = package.path .. ';$PROJECT_ROOT/lua/?.lua;$PROJECT_ROOT/lua/?/init.lua;$PROJECT_ROOT/?.lua'" \
    -c "lua require('scripts.parley_harness').run('$TRANSCRIPT_ABS')" \
    -c "qa!"
```

- [ ] **Step 2: chmod + smoke test against an existing transcript fixture**

```bash
chmod +x scripts/test-anthropic-interaction.sh
PARLEY_HARNESS_DRY_RUN=1 scripts/test-anthropic-interaction.sh design/2026-04-09.13-52-39.328.md 2>&1 | head -30
```
Expected: prints `=== PAYLOAD (dry run) ===` followed by a JSON document. (The scratch transcript is incomplete so the payload may be minimal, but the script should not crash.)

- [ ] **Step 3: Commit**

```bash
git add scripts/test-anthropic-interaction.sh
git commit -m "feat(90): test-anthropic-interaction.sh shell wrapper"
```

---

### Task 0.6: Fixture transcripts (7 files)

**Files:**
- Create: `tests/fixtures/transcripts/single-user.md`
- Create: `tests/fixtures/transcripts/simple-chat.md`
- Create: `tests/fixtures/transcripts/one-round-tool-use.md`
- Create: `tests/fixtures/transcripts/two-round-tool-use.md`
- Create: `tests/fixtures/transcripts/mixed-text-and-tools.md`
- Create: `tests/fixtures/transcripts/tool-error.md`
- Create: `tests/fixtures/transcripts/dynamic-fence-stress.md`

- [ ] **Step 1: Create all 7 fixtures**

Each fixture is a self-contained parley chat file (front matter + body). See the design's section 6 for the catalog. Concrete shapes:

`single-user.md`:
```
---
topic: single user
file: single-user.md
model: claude-sonnet-4-6
provider: anthropic
agent: ClaudeAgentTools
---

💬: hello
```

`simple-chat.md`:
```
---
topic: simple
file: simple-chat.md
model: claude-sonnet-4-6
provider: anthropic
agent: Claude-Sonnet
---

💬: what is 2+2?

🤖: [Claude-Sonnet]
4
```

`one-round-tool-use.md`:
```
---
topic: one round
file: one-round.md
model: claude-sonnet-4-6
provider: anthropic
agent: ClaudeAgentTools
---

💬: read foo.txt

🤖: [ClaudeAgentTools]
🔧: read_file id=toolu_ABC
```json
{"path":"foo.txt"}
```
📎: read_file id=toolu_ABC
````
    1  hello world
````
```

`two-round-tool-use.md`:
```
---
topic: two rounds
file: two-rounds.md
model: claude-sonnet-4-6
provider: anthropic
agent: ClaudeAgentTools
---

💬: read foo.txt and bar.txt

🤖: [ClaudeAgentTools]
🔧: read_file id=toolu_A
```json
{"path":"foo.txt"}
```
📎: read_file id=toolu_A
````
    1  hi from foo
````
🔧: read_file id=toolu_B
```json
{"path":"bar.txt"}
```
📎: read_file id=toolu_B
````
    1  hi from bar
````
```

`mixed-text-and-tools.md`:
```
---
topic: mixed
file: mixed.md
model: claude-sonnet-4-6
provider: anthropic
agent: ClaudeAgentTools
---

💬: tell me about init.lua

🤖: [ClaudeAgentTools]
I'll read the file first.
🔧: read_file id=toolu_M
```json
{"path":"init.lua"}
```
📎: read_file id=toolu_M
````
    1  local M = {}
    2  return M
````
This is a minimal Lua module that exports an empty table.
```

`tool-error.md`:
```
---
topic: error
file: error.md
model: claude-sonnet-4-6
provider: anthropic
agent: ClaudeAgentTools
---

💬: read /etc/hosts

🤖: [ClaudeAgentTools]
🔧: read_file id=toolu_E
```json
{"path":"/etc/hosts"}
```
📎: read_file id=toolu_E error=true
````
path /etc/hosts is outside working directory
````
```

`dynamic-fence-stress.md`:
```
---
topic: fences
file: fences.md
model: claude-sonnet-4-6
provider: anthropic
agent: ClaudeAgentTools
---

💬: read example.md

🤖: [ClaudeAgentTools]
🔧: read_file id=toolu_F
```json
{"path":"example.md"}
```
📎: read_file id=toolu_F
`````
    1  ```lua
    2  local x = 1
    3  ```
    4  ````bash
    5  echo hi
    6  ````
`````
```

- [ ] **Step 2: Smoke-test each fixture through the harness**

```bash
for f in tests/fixtures/transcripts/*.md; do
    echo "=== $f ==="
    PARLEY_HARNESS_DRY_RUN=1 scripts/test-anthropic-interaction.sh "$f" 2>&1 | head -5
done
```
Expected: every fixture produces a JSON payload without errors.

- [ ] **Step 3: Commit**

```bash
git add tests/fixtures/transcripts/
git commit -m "test(90): 7 fixture transcripts for harness + golden snapshots"
```

---

### Task 0.7: Capture golden JSON payloads

**Files:**
- Create: `tests/fixtures/golden_payloads/<each fixture>.json`

- [ ] **Step 1: Capture all 7 golden payloads**

```bash
mkdir -p tests/fixtures/golden_payloads
for f in tests/fixtures/transcripts/*.md; do
    name=$(basename "$f" .md)
    PARLEY_HARNESS_DRY_RUN=1 scripts/test-anthropic-interaction.sh "$f" \
        | sed -n '/^=== PAYLOAD (dry run) ===$/,$p' \
        | tail -n +2 \
        > "tests/fixtures/golden_payloads/$name.json"
done
ls -la tests/fixtures/golden_payloads/
```
Expected: 7 non-empty JSON files.

- [ ] **Step 2: Sanity-check each golden file is valid JSON**

```bash
for f in tests/fixtures/golden_payloads/*.json; do
    python3 -m json.tool "$f" > /dev/null && echo "OK $f" || echo "BAD $f"
done
```
Expected: 7 OKs.

- [ ] **Step 3: Commit**

```bash
git add tests/fixtures/golden_payloads/
git commit -m "test(90): capture golden Anthropic payloads for 7 fixtures"
```

---

### Task 0.8: Round-trip test — harness output equals golden payload

**Files:**
- Create: `tests/unit/parley_harness_golden_spec.lua`

- [ ] **Step 1: Write the test**

```lua
local harness = require("scripts.parley_harness")

local FIXTURES = {
    "single-user", "simple-chat", "one-round-tool-use", "two-round-tool-use",
    "mixed-text-and-tools", "tool-error", "dynamic-fence-stress",
}

local function read_json(path)
    local f = assert(io.open(path, "r"))
    local s = f:read("*a"); f:close()
    return vim.json.decode(s)
end

describe("parley_harness golden round-trip", function()
    for _, name in ipairs(FIXTURES) do
        it("payload for " .. name .. " matches golden", function()
            local payload = harness.build_payload("tests/fixtures/transcripts/" .. name .. ".md")
            local golden = read_json("tests/fixtures/golden_payloads/" .. name .. ".json")
            assert.same(golden, payload)
        end)
    end
end)
```

- [ ] **Step 2: Run, verify all 7 pass**

```bash
nvim --headless -c "PlenaryBustedFile tests/unit/parley_harness_golden_spec.lua" -c qa 2>&1 | tail -15
```
Expected: 7 successes.

- [ ] **Step 3: Run full make test, verify everything green**

```bash
make test 2>&1 | tail -15
```
Expected: no new failures vs pre-Chunk-0 baseline.

- [ ] **Step 4: Commit**

```bash
git add tests/unit/parley_harness_golden_spec.lua
git commit -m "test(90): harness round-trip == golden payload (7 fixtures)"
```

**Chunk 0 done.** Safety net deployed: arch tests, harness, fixtures, goldens, round-trip guard. Zero production code changed.

---

## Chunk 1: Phase 1 — Pure layers

> Goal of this chunk: chat_parser carries line spans per section; render_buffer is a complete pure render layer; buffer_edit is a complete mutation layer with PosHandle. Nothing in chat_respond.lua calls them yet — all existing tests still green.

### Task 1.1: chat_parser line span extension

**Files:**
- Modify: `lua/parley/chat_parser.lua` (add `line_start/line_end` to each block in `cb_finalize_block`)
- Test: `tests/unit/chat_parser_section_lines_spec.lua`

- [ ] **Step 1: Write the failing test**

```lua
-- tests/unit/chat_parser_section_lines_spec.lua
local chat_parser = require("parley.chat_parser")
local cfg = require("parley.config")

local function parse(lines)
    return chat_parser.parse_chat(lines, chat_parser.find_header_end(lines), cfg)
end

describe("chat_parser: section line spans", function()
    it("text-only answer has one text section spanning the answer body", function()
        local lines = {
            "---", "topic: t", "file: f.md", "---", "",
            "💬: q",
            "",
            "🤖: [A]",
            "the answer",
        }
        local p = parse(lines)
        local secs = p.exchanges[1].answer.sections
        assert.equals(1, #secs)
        assert.equals("text", secs[1].kind)
        assert.equals(9, secs[1].line_start) -- 1-indexed: "the answer" line
        assert.equals(9, secs[1].line_end)
    end)

    it("tool_use + tool_result get exact line spans", function()
        local lines = {
            "---", "topic: t", "file: f.md", "---", "",
            "💬: q",
            "",
            "🤖: [A]",          -- 8
            "🔧: read_file id=X", -- 9
            "```json",          -- 10
            '{"p":"x"}',         -- 11
            "```",              -- 12
            "📎: read_file id=X", -- 13
            "````",             -- 14
            "body",             -- 15
            "````",             -- 16
        }
        local p = parse(lines)
        local secs = p.exchanges[1].answer.sections
        assert.equals(2, #secs)
        assert.equals("tool_use",   secs[1].kind)
        assert.equals(9, secs[1].line_start)
        assert.equals(12, secs[1].line_end)
        assert.equals("tool_result", secs[2].kind)
        assert.equals(13, secs[2].line_start)
        assert.equals(16, secs[2].line_end)
    end)

    it("text + tool_use + tool_result + text have 4 sections in order", function()
        local lines = {
            "---", "topic: t", "file: f.md", "---", "",
            "💬: q", "",
            "🤖: [A]",            -- 8
            "Let me check.",      -- 9
            "🔧: read_file id=X", -- 10
            "```json",            -- 11
            '{"p":"x"}',           -- 12
            "```",                -- 13
            "📎: read_file id=X", -- 14
            "````",               -- 15
            "body",               -- 16
            "````",               -- 17
            "Done.",              -- 18
        }
        local p = parse(lines)
        local secs = p.exchanges[1].answer.sections
        assert.equals(4, #secs)
        assert.equals("text",        secs[1].kind); assert.equals("Let me check.", secs[1].text)
        assert.equals("tool_use",    secs[2].kind)
        assert.equals("tool_result", secs[3].kind)
        assert.equals("text",        secs[4].kind); assert.equals("Done.", secs[4].text)
        assert.equals(9,  secs[1].line_start); assert.equals(9,  secs[1].line_end)
        assert.equals(10, secs[2].line_start); assert.equals(13, secs[2].line_end)
        assert.equals(14, secs[3].line_start); assert.equals(17, secs[3].line_end)
        assert.equals(18, secs[4].line_start); assert.equals(18, secs[4].line_end)
    end)

    it("answer.content_blocks alias still works", function()
        local lines = {
            "---","topic: t","file: f.md","---","",
            "💬: q","","🤖: [A]","hi",
        }
        local p = parse(lines)
        assert.equals(p.exchanges[1].answer.sections, p.exchanges[1].answer.content_blocks)
    end)
end)
```

- [ ] **Step 2: Run, verify failures** (line_start/line_end fields don't exist)

- [ ] **Step 3: Modify `chat_parser.lua` cb_state machinery**

In `cb_start_block`, accept and store `line_no`:
```lua
local function cb_start_block(kind, line_no)
    if not cb_state then return end
    cb_state.current_kind = kind
    cb_state.current_lines = {}
    cb_state.current_line_start = line_no
    cb_state.tool_fence_len = nil
    cb_state.tool_body_complete = false
end
```

In `cb_finalize_block`, accept `end_line_no` and write the spans:
```lua
local function cb_finalize_block(end_line_no)
    if not cb_state or not cb_state.current_kind then return end
    local body = table.concat(cb_state.current_lines, "\n")
    local kind = cb_state.current_kind
    local block
    if kind == "text" then
        local trimmed = body:gsub("^%s*(.-)%s*$", "%1")
        if trimmed ~= "" then
            block = { kind = "text", text = trimmed }
        end
    elseif kind == "tool_use" then
        local parsed = serialize_ok and serialize.parse_call(body) or nil
        if parsed then
            block = { kind = "tool_use", id = parsed.id, name = parsed.name, input = parsed.input }
        end
    elseif kind == "tool_result" then
        local parsed = serialize_ok and serialize.parse_result(body) or nil
        if parsed then
            block = { kind = "tool_result", id = parsed.id, name = parsed.name,
                      content = parsed.content, is_error = parsed.is_error }
        end
    end
    if block then
        block.line_start = cb_state.current_line_start
        block.line_end = end_line_no
        -- Backward compat: keep `type` field as alias of `kind`
        block.type = block.kind
        table.insert(cb_state.blocks, block)
    end
    cb_state.current_kind = nil
    cb_state.current_lines = {}
    cb_state.tool_fence_len = nil
    cb_state.tool_body_complete = false
end
```

Update all callers of `cb_start_block` and `cb_finalize_block` to pass the current loop index `i` (1-indexed) appropriately. The auto-transition path inside `cb_append_line` becomes:
```lua
if cb_state.tool_body_complete then
    cb_finalize_block(i - 1)
    cb_start_block("text", i)
end
```

After `cb_attach_to_current_answer`, set the alias:
```lua
current_exchange.answer.content_blocks = current_exchange.answer.sections
```

(`sections` becomes the canonical name; `content_blocks` is the alias for backward compat with `_emit_content_blocks_as_messages`.)

- [ ] **Step 4: Run new tests + existing chat_parser tests, verify all pass**

```bash
nvim --headless \
  -c "PlenaryBustedFile tests/unit/chat_parser_section_lines_spec.lua" \
  -c "PlenaryBustedFile tests/unit/chat_parser_tools_spec.lua" \
  -c qa 2>&1 | tail -20
```
Expected: 4 new + 11 existing = 15 successes.

- [ ] **Step 5: Run full make test**

```bash
make test 2>&1 | tail -10
```
Expected: no regressions.

- [ ] **Step 6: Commit**

```bash
git add lua/parley/chat_parser.lua tests/unit/chat_parser_section_lines_spec.lua
git commit -m "feat(90): chat_parser records line spans per section"
```

---

### Task 1.2: chat_parser helpers — find_section_at_line, last_section_in_answer

**Files:**
- Modify: `lua/parley/chat_parser.lua` (export new functions)
- Test: `tests/unit/chat_parser_section_lines_spec.lua` (extend)

- [ ] **Step 1: Add failing tests**

```lua
describe("chat_parser: section helpers", function()
    local function fixture()
        return parse({
            "---","topic: t","file: f.md","---","",
            "💬: q1", "", "🤖: [A]", "hi",
            "💬: q2", "", "🤖: [B]",
            "🔧: read_file id=X",
            "```json", '{"p":"x"}', "```",
            "📎: read_file id=X",
            "````", "body", "````",
        })
    end

    it("find_exchange_at_line", function()
        local p = fixture()
        assert.equals(1, chat_parser.find_exchange_at_line(p, 6))
        assert.equals(1, chat_parser.find_exchange_at_line(p, 9))
        assert.equals(2, chat_parser.find_exchange_at_line(p, 10))
        assert.equals(2, chat_parser.find_exchange_at_line(p, 19))
    end)

    it("last_section_in_answer", function()
        local p = fixture()
        local s = chat_parser.last_section_in_answer(p, 2)
        assert.is_not_nil(s)
        assert.equals("tool_result", s.kind)
    end)
end)
```

- [ ] **Step 2: Run, verify failures**

- [ ] **Step 3: Implement helpers in chat_parser.lua**

```lua
function M.find_exchange_at_line(parsed, line_no)
    for i, ex in ipairs(parsed.exchanges) do
        local q_start = ex.question and ex.question.line_start or math.huge
        local a_end = (ex.answer and ex.answer.line_end) or (ex.question and ex.question.line_end) or 0
        if line_no >= q_start and line_no <= a_end then return i end
    end
    return nil
end

function M.find_section_at_line(parsed, line_no)
    local idx = M.find_exchange_at_line(parsed, line_no)
    if not idx then return nil end
    local secs = parsed.exchanges[idx].answer and parsed.exchanges[idx].answer.sections or {}
    for s_idx, s in ipairs(secs) do
        if line_no >= s.line_start and line_no <= s.line_end then
            return idx, s_idx
        end
    end
    return idx, nil
end

function M.last_section_in_answer(parsed, exchange_idx)
    local ex = parsed.exchanges[exchange_idx]
    if not ex or not ex.answer or not ex.answer.sections then return nil end
    return ex.answer.sections[#ex.answer.sections]
end
```

- [ ] **Step 4: Run, verify pass**

- [ ] **Step 5: Commit**

```bash
git add lua/parley/chat_parser.lua tests/unit/chat_parser_section_lines_spec.lua
git commit -m "feat(90): chat_parser section helper functions"
```

---

### Task 1.3: render_buffer.render_section + render_exchange

**Files:**
- Create: `lua/parley/render_buffer.lua`
- Test: `tests/unit/render_buffer_spec.lua`

- [ ] **Step 1: Write failing tests**

```lua
local rb = require("parley.render_buffer")

describe("render_buffer.render_section", function()
    it("renders a text section as its lines", function()
        local lines = rb.render_section({ kind = "text", text = "hello\nworld" })
        assert.same({ "hello", "world" }, lines)
    end)

    it("renders a tool_use section using serialize.render_call", function()
        local lines = rb.render_section({
            kind = "tool_use", id = "toolu_X", name = "read_file",
            input = { path = "foo.txt" },
        })
        assert.matches("^🔧: read_file id=toolu_X$", lines[1])
        assert.matches("^```json", lines[2])
        assert.matches('"path"', lines[3])
        assert.equals("```", lines[4])
    end)

    it("renders a tool_result section using serialize.render_result", function()
        local lines = rb.render_section({
            kind = "tool_result", id = "toolu_X", name = "read_file",
            content = "hi", is_error = false,
        })
        assert.matches("^📎: read_file id=toolu_X$", lines[1])
    end)
end)

describe("render_buffer.render_exchange", function()
    it("renders question + answer with sections in order", function()
        local ex = {
            question = { content = "what?", line_start = 1, line_end = 1 },
            answer = {
                line_start = 3, line_end = 4,
                sections = {
                    { kind = "text", text = "the answer", line_start = 4, line_end = 4 },
                },
                content = "the answer",
            },
        }
        local lines = rb.render_exchange(ex)
        assert.same({ "💬: what?", "", "🤖:", "the answer" }, lines)
    end)
end)
```

- [ ] **Step 2: Run, verify failures**

- [ ] **Step 3: Implement render_buffer.lua**

```lua
-- lua/parley/render_buffer.lua
-- Pure render layer. No buffer access. No nvim API beyond vim.json/vim.tbl_*.
-- Marked PURE in the arch tests — must stay free of vim.api/cmd/schedule/defer_fn.

local serialize = require("parley.tools.serialize")

local M = {}

function M.render_section(section)
    if section.kind == "text" then
        local out = {}
        for line in (section.text or ""):gmatch("([^\n]*)\n?") do
            table.insert(out, line)
        end
        if #out > 0 and out[#out] == "" then table.remove(out) end
        return out
    elseif section.kind == "tool_use" then
        local rendered = serialize.render_call(section)
        local out = {}
        for line in (rendered .. "\n"):gmatch("([^\n]*)\n") do
            table.insert(out, line)
        end
        return out
    elseif section.kind == "tool_result" then
        local rendered = serialize.render_result(section)
        local out = {}
        for line in (rendered .. "\n"):gmatch("([^\n]*)\n") do
            table.insert(out, line)
        end
        return out
    end
    error("render_section: unknown kind " .. tostring(section.kind))
end

function M.render_exchange(exchange)
    local out = { "💬: " .. (exchange.question and exchange.question.content or "") }
    if exchange.answer then
        table.insert(out, "")
        table.insert(out, "🤖:")  -- agent suffix optional; caller-managed
        local secs = exchange.answer.sections or {}
        for _, s in ipairs(secs) do
            for _, line in ipairs(M.render_section(s)) do
                table.insert(out, line)
            end
        end
    end
    return out
end

return M
```

- [ ] **Step 4: Run, verify pass**

- [ ] **Step 5: Commit**

```bash
git add lua/parley/render_buffer.lua tests/unit/render_buffer_spec.lua
git commit -m "feat(90): render_buffer.render_section + render_exchange"
```

---

### Task 1.4: render_buffer.positions + agent_header_lines + raw_request_fence_lines

**Files:**
- Modify: `lua/parley/render_buffer.lua`
- Test: `tests/unit/render_buffer_spec.lua`

- [ ] **Step 1: Add failing tests for the three helpers**

(See section 4 of design for shapes; tests assert that `positions(parse(lines))` agrees with parser-recorded spans, and that `agent_header_lines("[Claude]")` returns `{ "", "🤖: [Claude]", "" }`.)

- [ ] **Step 2: Implement**

```lua
function M.agent_header_lines(agent_prefix, agent_suffix)
    return { "", "🤖: " .. (agent_prefix or "") .. (agent_suffix or ""), "" }
end

function M.raw_request_fence_lines(payload)
    local json_str = vim.json.encode(payload)
    local pretty = vim.fn.system({ "python3", "-m", "json.tool" }, json_str)
    if vim.v.shell_error ~= 0 then pretty = json_str end
    local out = { "", '```json {"type": "request"}' }
    for line in pretty:gmatch("[^\n]+") do table.insert(out, line) end
    table.insert(out, "```")
    return out
end

function M.positions(parsed_chat)
    local result = { exchanges = {} }
    for _, ex in ipairs(parsed_chat.exchanges) do
        local entry = {
            question = ex.question and { line_start = ex.question.line_start, line_end = ex.question.line_end },
            answer = ex.answer and {
                line_start = ex.answer.line_start, line_end = ex.answer.line_end,
                sections = {}
            }
        }
        if ex.answer and ex.answer.sections then
            for _, s in ipairs(ex.answer.sections) do
                table.insert(entry.answer.sections, { line_start = s.line_start, line_end = s.line_end, kind = s.kind })
            end
        end
        table.insert(result.exchanges, entry)
    end
    return result
end
```

NOTE: `vim.fn.system` and `vim.fn.shell_error` are NOT pure but ARE used elsewhere in `_build_messages`. They are NOT on the pure-files arch ban list (`vim%.api%.`, `vim%.cmd`, `vim%.schedule`, `vim%.defer_fn`). If we want render_buffer fully pure, move `raw_request_fence_lines` out — call it in chat_respond instead. **Decision**: keep `raw_request_fence_lines` here for DRY, but DO NOT add `lua/parley/render_buffer.lua` to the `PURE_FILES` arch list. The pure-files list stays as `tools/types`, `tools/serialize`, `tools/init` only.

- [ ] **Step 3: Run, verify pass**

- [ ] **Step 4: Commit**

```bash
git add lua/parley/render_buffer.lua tests/unit/render_buffer_spec.lua
git commit -m "feat(90): render_buffer positions + header + raw_request_fence helpers"
```

---

### Task 1.5: Round-trip render test for all 7 fixtures

**Files:**
- Create: `tests/unit/render_buffer_roundtrip_spec.lua`

- [ ] **Step 1: Write the test**

```lua
local chat_parser = require("parley.chat_parser")
local rb = require("parley.render_buffer")
local cfg = require("parley.config")

local FIXTURES = {
    "single-user", "simple-chat", "one-round-tool-use", "two-round-tool-use",
    "mixed-text-and-tools", "tool-error", "dynamic-fence-stress",
}

local function read_file_lines(path)
    local f = assert(io.open(path, "r"))
    local lines = {}
    for line in f:lines() do table.insert(lines, line) end
    f:close()
    return lines
end

describe("render_buffer round-trip", function()
    for _, name in ipairs(FIXTURES) do
        it(name .. " parses and re-renders to original (modulo header)", function()
            local lines = read_file_lines("tests/fixtures/transcripts/" .. name .. ".md")
            local parsed = chat_parser.parse_chat(lines, chat_parser.find_header_end(lines), cfg)
            local positions = rb.positions(parsed)
            -- Verify every section's recorded line span matches the positions function
            for ex_idx, ex in ipairs(parsed.exchanges) do
                if ex.answer and ex.answer.sections then
                    for s_idx, s in ipairs(ex.answer.sections) do
                        local p_section = positions.exchanges[ex_idx].answer.sections[s_idx]
                        assert.equals(s.line_start, p_section.line_start,
                            name .. " ex " .. ex_idx .. " sec " .. s_idx .. " line_start")
                        assert.equals(s.line_end, p_section.line_end,
                            name .. " ex " .. ex_idx .. " sec " .. s_idx .. " line_end")
                    end
                end
            end
        end)
    end
end)
```

- [ ] **Step 2: Run, verify all 7 pass**

- [ ] **Step 3: Commit**

```bash
git add tests/unit/render_buffer_roundtrip_spec.lua
git commit -m "test(90): round-trip parser/render line-span agreement (7 fixtures)"
```

---

### Task 1.6: buffer_edit PosHandle + topic header operations

**Files:**
- Create: `lua/parley/buffer_edit.lua`
- Test: `tests/unit/buffer_edit_spec.lua`

- [ ] **Step 1: Write failing tests**

```lua
local be = require("parley.buffer_edit")

local function mk_buf(lines)
    local b = vim.api.nvim_create_buf(false, true)
    vim.api.nvim_buf_set_lines(b, 0, -1, false, lines or {})
    return b
end

describe("buffer_edit.PosHandle", function()
    it("make_handle / handle_line returns the line", function()
        local b = mk_buf({ "a", "b", "c" })
        local h = be.make_handle(b, 1)
        assert.equals(1, be.handle_line(h))
    end)

    it("handle survives inserts BEFORE its position", function()
        local b = mk_buf({ "a", "b", "c" })
        local h = be.make_handle(b, 2)  -- pointing at "c"
        be.set_topic_header_line(b, 0, "X")  -- replaces "a" with "X" (no shift)
        assert.equals(2, be.handle_line(h))  -- still on "c"
        be.insert_topic_line(b, 0, "Y")  -- insert "Y" before line 0
        assert.equals(3, be.handle_line(h))  -- "c" pushed down
    end)
end)

describe("buffer_edit.topic header", function()
    it("set_topic_header_line replaces a line", function()
        local b = mk_buf({ "old", "rest" })
        be.set_topic_header_line(b, 0, "new")
        local got = vim.api.nvim_buf_get_lines(b, 0, -1, false)
        assert.same({ "new", "rest" }, got)
    end)

    it("insert_topic_line inserts after a given 0-indexed line", function()
        local b = mk_buf({ "a", "c" })
        be.insert_topic_line(b, 0, "b")  -- after line 0
        local got = vim.api.nvim_buf_get_lines(b, 0, -1, false)
        assert.same({ "a", "b", "c" }, got)
    end)
end)
```

- [ ] **Step 2: Run, verify failures**

- [ ] **Step 3: Implement initial buffer_edit.lua**

```lua
-- lua/parley/buffer_edit.lua
-- Single mutation entry point for the chat buffer. All nvim_buf_set_lines
-- and nvim_buf_set_text calls in the plugin live here. See #90 design.

local M = {}

local NS_NAME = "ParleyBufferEdit"
local ns_id = vim.api.nvim_create_namespace(NS_NAME)

-- ============================================================================
-- PosHandle
-- ============================================================================

--- @param buf integer
--- @param line_0_indexed integer
--- @return PosHandle
function M.make_handle(buf, line_0_indexed)
    local ex_id = vim.api.nvim_buf_set_extmark(buf, ns_id, line_0_indexed, 0, {
        right_gravity = false,
        strict = false,
    })
    return { buf = buf, ns_id = ns_id, ex_id = ex_id, dead = false }
end

function M.handle_line(handle)
    if handle.dead then error("handle is dead") end
    local pos = vim.api.nvim_buf_get_extmark_by_id(handle.buf, handle.ns_id, handle.ex_id, {})
    return pos[1]
end

function M.handle_invalidate(handle)
    if not handle.dead then
        pcall(vim.api.nvim_buf_del_extmark, handle.buf, handle.ns_id, handle.ex_id)
        handle.dead = true
    end
end

-- ============================================================================
-- Topic header
-- ============================================================================

function M.set_topic_header_line(buf, line_0_indexed, text)
    vim.api.nvim_buf_set_lines(buf, line_0_indexed, line_0_indexed + 1, false, { text })
end

function M.insert_topic_line(buf, after_line_0_indexed, text)
    vim.api.nvim_buf_set_lines(buf, after_line_0_indexed + 1, after_line_0_indexed + 1, false, { text })
end

return M
```

- [ ] **Step 4: Run, verify pass**

- [ ] **Step 5: Commit**

```bash
git add lua/parley/buffer_edit.lua tests/unit/buffer_edit_spec.lua
git commit -m "feat(90): buffer_edit PosHandle + topic header ops"
```

---

### Task 1.7: buffer_edit answer region operations

**Files:**
- Modify: `lua/parley/buffer_edit.lua`
- Test: `tests/unit/buffer_edit_spec.lua`

- [ ] **Step 1: Add failing tests** for `pad_question_with_blank`, `create_answer_region`, `delete_answer`, `replace_answer`, `insert_raw_request_fence`, `append_section_to_answer`. Each test sets up a real scratch buffer, calls the operation, asserts the resulting line state.

- [ ] **Step 2: Implement each entry point**

```lua
local render_buffer = require("parley.render_buffer")

function M.pad_question_with_blank(buf, line_0_indexed)
    vim.api.nvim_buf_set_lines(buf, line_0_indexed + 1, line_0_indexed + 1, false, { "" })
end

function M.create_answer_region(buf, after_line_0_indexed, agent_prefix, agent_suffix)
    local lines = render_buffer.agent_header_lines(agent_prefix, agent_suffix)
    vim.api.nvim_buf_set_lines(buf, after_line_0_indexed + 1, after_line_0_indexed + 1, false, lines)
    -- Position handle at the line right after the agent header (where streaming writes)
    return M.make_handle(buf, after_line_0_indexed + #lines)
end

function M.delete_answer(buf, answer_line_start_0_indexed, answer_line_end_0_indexed)
    vim.api.nvim_buf_set_lines(buf, answer_line_start_0_indexed, answer_line_end_0_indexed + 1, false, {})
end

function M.replace_answer(buf, answer_line_start_0_indexed, answer_line_end_0_indexed)
    -- Delete and insert a single blank separator. Returns handle at the blank.
    vim.api.nvim_buf_set_lines(buf, answer_line_start_0_indexed, answer_line_end_0_indexed + 1, false, { "" })
    return M.make_handle(buf, answer_line_start_0_indexed)
end

function M.insert_raw_request_fence(buf, before_line_0_indexed, fence_lines)
    vim.api.nvim_buf_set_lines(buf, before_line_0_indexed, before_line_0_indexed, false, fence_lines)
end

function M.append_section_to_answer(buf, after_line_0_indexed, section)
    -- Render the section and append. Insert a leading blank if the previous
    -- line is non-empty so blocks don't concatenate.
    local prev = vim.api.nvim_buf_get_lines(buf, after_line_0_indexed, after_line_0_indexed + 1, false)[1] or ""
    local rendered = render_buffer.render_section(section)
    local insert_lines = {}
    if prev:match("%S") then table.insert(insert_lines, "") end
    for _, l in ipairs(rendered) do table.insert(insert_lines, l) end
    vim.api.nvim_buf_set_lines(buf, after_line_0_indexed + 1, after_line_0_indexed + 1, false, insert_lines)
    return M.make_handle(buf, after_line_0_indexed + #insert_lines)
end
```

- [ ] **Step 3: Run, verify pass**

- [ ] **Step 4: Commit**

```bash
git add lua/parley/buffer_edit.lua tests/unit/buffer_edit_spec.lua
git commit -m "feat(90): buffer_edit answer region ops (create/delete/replace/append)"
```

---

### Task 1.8: buffer_edit streaming + progress + cleanup

**Files:**
- Modify: `lua/parley/buffer_edit.lua`
- Test: `tests/unit/buffer_edit_spec.lua`

- [ ] **Step 1: Add failing tests** for `stream_into`, `stream_finalize`, `set_progress_line`, `clear_progress_lines`, `delete_lines_after`, `append_blank_at_end`. Stream tests should cover: chunk with newlines, chunk without newline (pending), multi-chunk reassembly, finalize flushes pending.

- [ ] **Step 2: Implement**

```lua
-- Per-handle stream state stored on the handle table itself.
local function ensure_stream_state(handle)
    handle._stream = handle._stream or { pending = "", finished_lines = 0 }
    return handle._stream
end

function M.stream_into(handle, chunk)
    if handle.dead then return end
    local s = ensure_stream_state(handle)
    s.pending = s.pending .. chunk
    local lines = vim.split(s.pending, "\n", { plain = true })
    s.pending = lines[#lines]
    table.remove(lines)
    -- Append complete lines plus current pending as a "ghost" trailing line
    local first_line = M.handle_line(handle)
    local write_at = first_line + s.finished_lines
    table.insert(lines, s.pending)
    vim.api.nvim_buf_set_lines(handle.buf, write_at, write_at + 1, false, lines)
    s.finished_lines = s.finished_lines + #lines - 1
end

function M.stream_finalize(handle)
    -- No-op; the trailing pending line is already in the buffer.
    M.handle_invalidate(handle)
end

function M.set_progress_line(handle, text)
    if handle.dead then return end
    local line = M.handle_line(handle)
    vim.api.nvim_buf_set_lines(handle.buf, line, line + 1, false, { text or "" })
end

function M.clear_progress_lines(handle, count)
    if handle.dead then return end
    local line = M.handle_line(handle)
    vim.api.nvim_buf_set_lines(handle.buf, line, line + count, false, {})
end

function M.delete_lines_after(buf, line_0_indexed, n)
    vim.api.nvim_buf_set_lines(buf, line_0_indexed, line_0_indexed + n, false, {})
end

function M.append_blank_at_end(buf)
    vim.api.nvim_buf_set_lines(buf, -1, -1, false, { "" })
end
```

- [ ] **Step 3: Run, verify pass**

- [ ] **Step 4: Commit**

```bash
git add lua/parley/buffer_edit.lua tests/unit/buffer_edit_spec.lua
git commit -m "feat(90): buffer_edit streaming + progress + cleanup ops"
```

---

### Task 1.9: Update arch baseline to allow buffer_edit.lua

**Files:**
- Modify: `tests/arch/buffer_mutation_spec.lua`

- [ ] **Step 1: Add `lua/parley/buffer_edit.lua` to the `allow_only_in` list of the `nvim_buf_set_lines` rule and the `nvim_buf_set_text` rule.**

- [ ] **Step 2: Run arch tests, verify pass**

- [ ] **Step 3: Run full make test**

- [ ] **Step 4: Commit**

```bash
git add tests/arch/buffer_mutation_spec.lua
git commit -m "test(90): arch — allow nvim_buf_set_lines in buffer_edit.lua"
```

**Chunk 1 done.** Pure layers shipped, all existing tests still green, nothing in `chat_respond.lua` calls them yet.

---

## Chunk 2: Phase 2 — Migrate chat_respond.lua mutations

> Goal of this chunk: every `nvim_buf_set_lines` call in `chat_respond.lua` migrates to a `buffer_edit` entry point. The dead offset variables (`response_line / progress_line / response_start_line / raw_request_offset / response_block_lines / in_tool_loop_recursion`) get deleted in step 8. After Chunk 2: `chat_respond.lua` has zero raw mutations.

### Task 2.1: Migrate topic header (4 sites)

**Files:**
- Modify: `lua/parley/chat_respond.lua` lines 159, 166, 170, 174

- [ ] **Step 1: Replace each call** — `vim.api.nvim_buf_set_lines(buf, 0, 1, false, { "# topic: " .. topic })` becomes `buffer_edit.set_topic_header_line(buf, 0, "# topic: " .. topic)`. Same for the other 3 sites.

- [ ] **Step 2: Run make test, verify pass**

- [ ] **Step 3: Commit**

```bash
git commit -am "refactor(90): chat_respond — topic header via buffer_edit"
```

---

### Task 2.2: Migrate question padding (line 975)

- [ ] Replace `vim.api.nvim_buf_set_lines(buf, response_line + 1, response_line + 1, false, { "" })` with `buffer_edit.pad_question_with_blank(buf, response_line)`. Update local `response_line` if needed.

- [ ] Test, commit.

---

### Task 2.3: Migrate answer region creation (line 1020)

This is the big one. Replace `response_block_lines` hand-construction + the `nvim_buf_set_lines` insert with `buffer_edit.create_answer_region(buf, response_line, agent_prefix, agent_suffix)`. Capture the returned `PosHandle` for the streaming handler. Handle the recursion case by switching to `buffer_edit.append_section_to_answer` instead of `create_answer_region`.

- [ ] Test (existing chat_respond tests + a manual `make test`), commit.

---

### Task 2.4: Migrate raw request fence (line 1060)

Replace the inline lines + `nvim_buf_set_lines` with `buffer_edit.insert_raw_request_fence(buf, before_line, render_buffer.raw_request_fence_lines(payload))`.

- [ ] Test, commit.

---

### Task 2.5: Migrate progress indicator (lines 1094, 1136)

Replace `set_progress_indicator_line` and `clear_progress_indicator` internals with `buffer_edit.set_progress_line(handle, text)` and `buffer_edit.clear_progress_lines(handle, n)`. The closures capture a `PosHandle` instead of a numeric `progress_line`.

- [ ] Test, commit.

---

### Task 2.6: Migrate cancellation cleanup (lines 1248, 1259, 1262)

Replace each call:
- 1248 → `buffer_edit.delete_lines_after(buf, last_content_line, ...)`
- 1259 → `buffer_edit.delete_lines_after(buf, last_content_line, line_count - last_content_line)`
- 1262 → `buffer_edit.append_blank_at_end(buf)`

- [ ] Test, commit.

---

### Task 2.7: Migrate replace existing answer (line 944)

Replace with `buffer_edit.replace_answer(buf, answer.line_start - 1, answer.line_end - 1)` (converting 1-indexed to 0-indexed).

- [ ] Test, commit.

---

### Task 2.8: Delete dead offset variables

Now that no caller computes line offsets manually, delete:
- `response_line` (becomes a `PosHandle` returned from `create_answer_region`)
- `response_block_lines`
- `progress_line`
- `response_start_line`
- `raw_request_offset` (the offset is now implicit in extmark gravity)
- `in_tool_loop_recursion` branching that depends on these offsets

The branching collapses: there's one code path for "fresh answer region" and one for "append to existing answer".

- [ ] Diff `chat_respond.lua` LOC before/after; expect ≥150 line reduction in `M.respond` alone.
- [ ] Run make test.
- [ ] Tighten arch test #1: remove `lua/parley/chat_respond.lua` from `allow_only_in`. Verify still passes.
- [ ] Commit:

```bash
git commit -am "refactor(90): chat_respond — delete dead offset variables; arch tightened"
```

**Chunk 2 done.** `chat_respond.lua` has zero raw `nvim_buf_set_lines`. Arch test #1's `allow_only_in` is now `{ buffer_edit.lua, dispatcher.lua, tool_loop.lua }`.

---

## Chunk 3: Phase 3 — Migrate streaming + tool_loop

### Task 3.1: Migrate `tool_loop.lua::_append_block_to_buffer`

**Files:**
- Modify: `lua/parley/tool_loop.lua`
- Test: `tests/unit/tool_loop_spec.lua`

- [ ] Replace the `_append_block_to_buffer` raw mutation with `buffer_edit.append_section_to_answer(bufnr, last_line_of_answer, section_table)`. The function signature changes — instead of taking a pre-rendered text block, take the `Section` table. `tool_loop.process_response` already has the parsed `tool_call` and `result` — pass those through `render_buffer` indirectly via `buffer_edit`.

- [ ] Tighten arch test #1: remove `lua/parley/tool_loop.lua` from `allow_only_in`.

- [ ] Test, commit.

---

### Task 3.2: Migrate `dispatcher.create_handler` streaming

**Files:**
- Modify: `lua/parley/dispatcher.lua` lines 518, 526
- Test: existing dispatcher tests

- [ ] Refactor `create_handler` to receive a `PosHandle` instead of a line number. Caller (chat_respond) passes the handle returned by `buffer_edit.create_answer_region` or `buffer_edit.append_section_to_answer`. Internal mutations become `buffer_edit.stream_into(handle, chunk)` and `buffer_edit.stream_finalize(handle)`.

- [ ] The extmark machinery currently in `create_handler` (`ex_id`, `ns_id`) deletes — replaced by the `PosHandle` mechanism in `buffer_edit`. Reduces `create_handler` by ~30 LOC.

- [ ] Tighten arch test #1: remove `lua/parley/dispatcher.lua` from `allow_only_in`. Final state: `allow_only_in = { "lua/parley/buffer_edit.lua" }`.

- [ ] Test, commit.

---

### Task 3.3: Final arch tightening + grep verification

- [ ] Verify `grep -rn "nvim_buf_set_lines\|nvim_buf_set_text" lua/parley/` returns ONLY `lua/parley/buffer_edit.lua`.
- [ ] Run `make test`.
- [ ] Commit any final tightening:

```bash
git commit -am "test(90): arch tightened — only buffer_edit.lua may mutate"
```

**Chunk 3 done.** Single mutation entry point achieved.

---

## Chunk 4: Phase 4 — Re-validation

### Task 4.1: Full make test green

- [ ] Run `make test`. Resolve any regressions before proceeding.

### Task 4.2: Live Anthropic harness test

- [ ] Run `ANTHROPIC_API_KEY=... scripts/test-anthropic-interaction.sh tests/fixtures/transcripts/one-round-tool-use.md`. Expect HTTP 200 and a non-error response body.
- [ ] Run for `simple-chat.md` and `single-user.md` as baselines.
- [ ] Document the result in the issue Log.

### Task 4.3: Manual nvim — vanilla chat byte-identity check

- [ ] In nvim, open a fresh chat with `Claude-Sonnet` agent.
- [ ] Send a "hello" prompt. Verify response renders normally.
- [ ] Compare query JSON in `~/.cache/nvim/parley/query/` against a Task 1.0 baseline fixture; expect byte-identity for vanilla chats.

### Task 4.4: Manual nvim — ClaudeAgentTools tool round-trip

- [ ] Open a fresh chat with `ClaudeAgentTools` agent.
- [ ] Send "read lua/parley/init.lua and tell me what M.get_chat_roots does".
- [ ] Verify: clean `🔧:`/`📎:` blocks, no stuck spinner, no duplicate calls, Claude's final answer streams below the `📎:` closing fence, buffer remains parseable on reopen.

### Task 4.5: Resume #81 M2 Task 2.7 verification list

- [ ] Run the original 9 manual test steps from issue #81 M2 Task 2.7.
- [ ] Document each step's outcome in `issues/000081-...` Log.

### Task 4.6: Log entries + close + code review

- [ ] Add Log entry to `issues/000090-...`: closed, lessons recorded.
- [ ] Add Log entry to `issues/000081-...`: "M2 Task 2.7 unblocked by #90; resuming Task 2.8".
- [ ] Update `tasks/lessons.md` with anything learned during the refactor.
- [ ] Dispatch `superpowers:code-reviewer` subagent against the #90 commit range. Address feedback in a follow-up commit if needed.
- [ ] Mark issue #90 status as `closed` in its front matter.

**Chunk 4 done.** #90 complete. Resume #81 M2 Task 2.8.
