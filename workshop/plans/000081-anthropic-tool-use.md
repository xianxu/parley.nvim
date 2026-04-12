# Anthropic Tool Use Protocol — Implementation Plan

> **For agentic workers:** REQUIRED: Use `superpowers:subagent-driven-development` (if subagents available) or `superpowers:executing-plans` to implement this plan. Steps use checkbox (`- [ ]`) syntax for tracking. The authoritative spec lives in `issues/000081-support-anthropic-tool-use-protocol.md` under `## Spec` — this plan is the execution recipe, not a re-spec.

**Goal:** Add client-side tool-use loop to parley so Claude can call filesystem tools (read, edit, write) and parley executes them and feeds results back, enabling the personal-assistant foundation described in issue #81.

**Architecture:** A new `lua/parley/tools/` module defines provider-agnostic `ToolDefinition` / `ToolCall` / `ToolResult` types and hosts 6 builtin tool handlers. The dispatcher gains a tool-loop driver that recurses on assistant responses containing `tool_use` blocks, executes handlers, streams both `🔧:` / `📎:` prefixed blocks into the chat buffer, and terminates on plain text, cancel, or iteration cap. The Anthropic adapter is the only provider with tool encoding/decoding in v1; OpenAI/Google adapters are stubs. All paths are cwd-confined; all writes capture a `.parley-backup` pre-image for future replay (#84).

**Tech Stack:** Lua 5.1 / LuaJIT, Neovim 0.9+, plenary.nvim for tests (busted-style `describe`/`it`), `curl` subprocess for HTTP. No new dependencies.

**Authoritative spec:** [`issues/000081-support-anthropic-tool-use-protocol.md`](../../issues/000081-support-anthropic-tool-use-protocol.md) `## Spec`. Re-read before starting each milestone.

**Test commands:**
- Full suite: `make test`
- Single file: `nvim --headless -u scripts/minimal_init.lua -c "PlenaryBustedFile tests/unit/<name>_spec.lua"` (or `make test-spec SPEC=<spec-dir>`)
- Lint: `make lint`

**Commit hygiene:** Frequent, one commit per passing step-group. Never amend pushed commits. Conventional-commits prefix (`feat:`, `test:`, `refactor:`, `fix:`, `docs:`). Each commit co-authored as per repo norm.

**Post-milestone code review gate (MANDATORY):** At the end of **every** milestone (M1, M2, M3, …), BEFORE starting the next milestone, invoke `superpowers:requesting-code-review` and dispatch the `superpowers:code-reviewer` subagent to review all commits from the previous milestone boundary to HEAD. The reviewer receives:
- `BASE_SHA` = the commit hash of the last commit BEFORE this milestone's first task (e.g. for M2: `HEAD` of M1 completion commit)
- `HEAD_SHA` = current HEAD
- `WHAT_WAS_IMPLEMENTED` = milestone name + brief summary
- `PLAN_OR_REQUIREMENTS` = the milestone section of this plan
- Reference to `issues/000081-support-anthropic-tool-use-protocol.md` `## Spec` for the authoritative invariants

Address **Critical** and **Important** issues before proceeding. Minor/advisory items can be deferred to a polish commit at the end of the next milestone or to M9 regression lockdown. Record the review outcome (approved / fixes applied) in the issue's `## Log` section.

**Why this gate is mandatory:** M1 caught a real wiring-chain bug (`1b8ceb8`) only during manual end-to-end verification, because the plan's unit tests mocked each hop in isolation and no test exercised the full chain. The post-milestone code review is a second net that catches integration-layer bugs AND coverage gaps before they compound into the next milestone. See `tasks/lessons.md` 2026-04-09 entry.

**Rationale for skipping this in M1:** It wasn't in the plan. The reviewer gate was introduced mid-M1 based on the user's feedback after M1 was already complete. M1 DID get a retroactive full review (commit `6f5c8b9` addressed all 7 advisory items). M2 onward is gated.

---

## File Structure

Files that will be created or modified. Held here so decomposition decisions are locked before tasks start.

### New files

| Path                                              | Responsibility                                                                         |
|---------------------------------------------------|----------------------------------------------------------------------------------------|
| `lua/parley/tools/init.lua`                       | Module entry: registry, `register()`, `get()`, `list_names()`                          |
| `lua/parley/tools/types.lua`                      | Type docstrings + validators for `ToolDefinition`, `ToolCall`, `ToolResult`            |
| `lua/parley/tools/dispatcher.lua`                 | Safety helpers: cwd-scope check, dirty-buffer guard, `.parley-backup`, truncate, execute |
| `lua/parley/tools/synthetic.lua`                  | DRY synthetic ToolResult builder for cancel/iteration-cap paths (M4 + M6 shared)       |
| `lua/parley/tools/builtin/read_file.lua`          | `read_file` handler                                                                    |
| `lua/parley/tools/builtin/list_dir.lua`           | `list_dir` handler                                                                     |
| `lua/parley/tools/builtin/grep.lua`               | `grep` handler (ripgrep wrapper + `vim.fs` fallback)                                   |
| `lua/parley/tools/builtin/glob.lua`               | `glob` handler                                                                         |
| `lua/parley/tools/builtin/edit_file.lua`          | `edit_file` handler                                                                    |
| `lua/parley/tools/builtin/write_file.lua`         | `write_file` handler                                                                   |
| `lua/parley/tools/serialize.lua`                  | Schema for `🔧:` / `📎:` buffer prefixes: render + parse (DRY single source)           |
| `lua/parley/tool_loop.lua`                        | Tool loop driver: pending-calls queue, iteration state, run_iteration, cleanup         |
| `lua/parley/tool_folds.lua`                       | Foldexpr + `<C-g>b` toggle helper for `🔧:` / `📎:` regions                             |
| `tests/helpers/assert_reparsable.lua`             | Shared test helper — asserts every `🔧:` has a matching `📎:` (M6 DRY)                  |
| `tests/unit/tools_types_spec.lua`                 | Unit tests for type validators                                                         |
| `tests/unit/tools_dispatcher_spec.lua`            | Unit tests for safety helpers (pure where possible)                                    |
| `tests/unit/tools_builtin_read_file_spec.lua`     | `read_file` handler tests                                                              |
| `tests/unit/tools_builtin_list_dir_spec.lua`      | `list_dir` handler tests                                                               |
| `tests/unit/tools_builtin_grep_spec.lua`          | `grep` handler tests                                                                   |
| `tests/unit/tools_builtin_glob_spec.lua`          | `glob` handler tests                                                                   |
| `tests/unit/tools_builtin_edit_file_spec.lua`     | `edit_file` handler tests                                                              |
| `tests/unit/tools_builtin_write_file_spec.lua`    | `write_file` handler tests                                                             |
| `tests/unit/tools_serialize_spec.lua`             | Round-trip tests for prefix render/parse                                               |
| `tests/unit/anthropic_tool_encode_spec.lua`       | Anthropic adapter `encode_tools` / `encode_tool_results` tests                         |
| `tests/unit/anthropic_tool_decode_spec.lua`       | Anthropic adapter `decode_tool_calls` (streaming) tests                                |
| `tests/integration/tool_loop_spec.lua`            | End-to-end tool loop (mock provider)                                                   |
| `tests/fixtures/anthropic_tool_use_stream.jsonl`  | Recorded streaming events for decoder tests                                            |

### Modified files

| Path                                    | What changes                                                                                 |
|-----------------------------------------|----------------------------------------------------------------------------------------------|
| `lua/parley/config.lua`                 | New `chat_tool_use_prefix = "🔧:"`, `chat_tool_result_prefix = "📎:"`, `chat_shortcut_toggle_tool_folds = { ..., "<C-g>b" }`. New agent `ClaudeAgentTools` with `tools`, `max_tool_iterations`, `tool_result_max_bytes`. |
| `lua/parley/chat_parser.lua`            | Recognize `🔧:` and `📎:` components inside `🤖:` answer region; attach to current answer as content blocks |
| `lua/parley/dispatcher.lua`             | `prepare_payload` passes `tools` into provider adapter. New `run_tool_loop` orchestrator.   |
| `lua/parley/providers.lua`              | Anthropic: `encode_tools`, `encode_tool_results`, SSE decoder accumulates full `ToolCall`s. OpenAI/Google/Ollama adapters get error-raising stubs. |
| `lua/parley/chat_respond.lua`           | On response with `tool_use`, invoke `run_tool_loop`; stream `🔧:` / `📎:` blocks; handle cancel cleanup. |
| `lua/parley/agent_picker.lua`           | Render `[🔧]` badge next to agents with `tools` configured.                                 |
| `lua/parley/init.lua`                   | Register six builtin tools at setup; validate agent `tools` fields; map `<C-g>b` and `<Esc>`. |
| `lua/parley/highlighter.lua`            | Highlight groups for `🔧:` / `📎:` lines.                                                   |
| `lua/parley/outline.lua`                | Include `🔧:` components in outline entries.                                                 |
| `lua/parley/lualine.lua`                | Tool-loop progress indicator `🔧 <tool> (N/max)`.                                            |
| `lua/parley/defaults.lua`               | Help text for `<C-g>b` and tool-use behavior.                                                |

### Touched but not core-edited

- `.gitignore` — parley auto-appends `*.parley-backup` at M5 write time (runtime, not in this plan)
- `specs/index.md` — add `providers/tool_use.md` entry at M9 polish time
- `specs/providers/tool_use.md` — brief sketch at M9 polish time (one file, ~20-40 lines)

---

## Chunk 1: M1 — Plumbing (types, config, agent, payload)

**Goal:** Types and config land, a `ClaudeAgentTools` agent sends an Anthropic request with a valid `tools: [...]` array, vanilla non-tools agents remain byte-identical. No loop yet; if the model emits `tool_use`, we error cleanly.

**Gated on:** Stage 1 in issue #81.

### Task 1.0: PRE-M1 baseline fixture capture (prerequisite for Task 9.3)

**Files:**
- Create: `tests/fixtures/pre_81_vanilla_claude_request.json`
- Create: `tests/fixtures/pre_81_vanilla_claude_prompts.lua` (list of 3 prompts used to generate the baseline)

This step runs on **current main**, BEFORE any #81 code lands. It captures the ground-truth request payload that a vanilla Claude agent produces today, so Task 9.3 (M9 regression lockdown) has a golden JSON to diff against. Without this, byte-identity verification in M9 is unverifiable.

- [x] **Step 1.0.1: Capture the baseline**

1. Confirm you are on current main with no #81 changes (`git status` clean, `git log --oneline -1`).
2. Start Neovim with parley configured with an existing vanilla Anthropic agent.
3. Send 3 short prompts in sequence (e.g., `"What is 2+2?"`, `"Summarize the word 'lua' in one sentence."`, `"List three primary colors."`).
4. Copy the three most recent JSON files from `vim.fn.stdpath("cache") .. "/parley/query/"` to `tests/fixtures/pre_81_vanilla_claude_request_{1,2,3}.json`.
5. Record the three prompts in `tests/fixtures/pre_81_vanilla_claude_prompts.lua` so Task 9.3 can replay them.

- [x] **Step 1.0.2: Commit the baseline**

```bash
git add tests/fixtures/pre_81_vanilla_claude_request_*.json tests/fixtures/pre_81_vanilla_claude_prompts.lua
git commit -m "$(cat <<'EOF'
test(81): capture pre-#81 vanilla Claude request baseline

Ground-truth payloads for the byte-identity regression check that
M9 (Task 9.3) will diff against. Captured on current main before
any #81 code lands.

Co-Authored-By: Claude Opus 4.6 (1M context) <noreply@anthropic.com>
EOF
)"
```

**Critical:** Do not proceed to Task 1.1 until this commit is on the branch. M9 depends on it.



### Task 1.1: Type module with validators

**Files:**
- Create: `lua/parley/tools/types.lua`
- Test: `tests/unit/tools_types_spec.lua`

- [ ] **Step 1.1.1: Write the failing test**

Create `tests/unit/tools_types_spec.lua`. Test that:
1. `validate_definition` accepts `{ name, description, input_schema, handler }` and rejects missing fields, wrong types, empty name.
2. `validate_call` accepts `{ id, name, input }` and rejects missing fields.
3. `validate_result` accepts `{ id, content, is_error }` with `is_error` optional (defaults false) and rejects missing id/content.

```lua
local types = require("parley.tools.types")

describe("ToolDefinition validation", function()
  it("accepts a minimal valid definition", function()
    local def = { name = "read_file", description = "Read a file", input_schema = { type = "object" }, handler = function() end }
    assert.is_true(types.validate_definition(def))
  end)
  it("rejects missing name", function()
    local ok, err = types.validate_definition({ description = "x", input_schema = {}, handler = function() end })
    assert.is_false(ok)
    assert.matches("name", err)
  end)
  -- ... similar for description, input_schema, handler, empty name
end)

describe("ToolCall validation", function()
  it("accepts { id, name, input }", function()
    assert.is_true(types.validate_call({ id = "toolu_01", name = "read_file", input = { path = "x" } }))
  end)
  -- ... rejection cases
end)

describe("ToolResult validation", function()
  it("accepts with is_error omitted", function()
    assert.is_true(types.validate_result({ id = "toolu_01", content = "ok" }))
  end)
  it("accepts with is_error = true", function()
    assert.is_true(types.validate_result({ id = "toolu_01", content = "oops", is_error = true }))
  end)
end)
```

- [ ] **Step 1.1.2: Run test to verify fail**

Run: `make test-spec SPEC=tools_types` or `nvim --headless -u scripts/minimal_init.lua -c "PlenaryBustedFile tests/unit/tools_types_spec.lua"`
Expected: FAIL — `module 'parley.tools.types' not found`.

- [ ] **Step 1.1.3: Implement `lua/parley/tools/types.lua`**

```lua
local M = {}

--- @class ToolDefinition
--- @field name string
--- @field description string
--- @field input_schema table JSON-schema-shaped table
--- @field handler fun(input: table): ToolResult

--- @class ToolCall
--- @field id string
--- @field name string
--- @field input table

--- @class ToolResult
--- @field id string
--- @field content string
--- @field is_error boolean|nil

local function fail(msg) return false, msg end

function M.validate_definition(def)
  if type(def) ~= "table" then return fail("definition must be a table") end
  if type(def.name) ~= "string" or def.name == "" then return fail("definition.name must be a non-empty string") end
  if type(def.description) ~= "string" or def.description == "" then return fail("definition.description must be a non-empty string") end
  if type(def.input_schema) ~= "table" then return fail("definition.input_schema must be a table") end
  if type(def.handler) ~= "function" then return fail("definition.handler must be a function") end
  return true
end

function M.validate_call(call)
  if type(call) ~= "table" then return fail("call must be a table") end
  if type(call.id) ~= "string" or call.id == "" then return fail("call.id must be a non-empty string") end
  if type(call.name) ~= "string" or call.name == "" then return fail("call.name must be a non-empty string") end
  if type(call.input) ~= "table" then return fail("call.input must be a table") end
  return true
end

function M.validate_result(res)
  if type(res) ~= "table" then return fail("result must be a table") end
  if type(res.id) ~= "string" or res.id == "" then return fail("result.id must be a non-empty string") end
  if type(res.content) ~= "string" then return fail("result.content must be a string") end
  if res.is_error ~= nil and type(res.is_error) ~= "boolean" then return fail("result.is_error must be boolean or nil") end
  return true
end

return M
```

- [ ] **Step 1.1.4: Run test to verify pass**

Run: `make test-spec SPEC=tools_types`
Expected: PASS all.

- [ ] **Step 1.1.5: Commit**

```bash
git add lua/parley/tools/types.lua tests/unit/tools_types_spec.lua
git commit -m "$(cat <<'EOF'
feat(tools): add ToolDefinition/ToolCall/ToolResult type validators

Provider-agnostic internal types for the tool use loop. Validators
return (true) or (false, err_msg) so callers can surface actionable
errors at registration / decode time.

Part of issue #81 M1.

Co-Authored-By: Claude Opus 4.6 (1M context) <noreply@anthropic.com>
EOF
)"
```

### Task 1.2: Tool registry module

**Files:**
- Create: `lua/parley/tools/init.lua`
- Modify test: `tests/unit/tools_types_spec.lua` (or new file)

- [ ] **Step 1.2.1: Write failing test**

Add `tests/unit/tools_registry_spec.lua`:

```lua
local registry = require("parley.tools")

describe("tool registry", function()
  before_each(function() registry.reset() end)

  it("registers and retrieves a tool", function()
    local def = { name = "foo", description = "d", input_schema = {}, handler = function() end }
    registry.register(def)
    assert.equals(def, registry.get("foo"))
  end)
  it("rejects invalid definitions", function()
    assert.has_error(function() registry.register({ name = "" }) end)
  end)
  it("lists registered names", function()
    registry.register({ name = "a", description = "d", input_schema = {}, handler = function() end })
    registry.register({ name = "b", description = "d", input_schema = {}, handler = function() end })
    local names = registry.list_names()
    table.sort(names)
    assert.same({"a","b"}, names)
  end)
  it("selects a subset by name", function()
    registry.register({ name = "a", description = "d", input_schema = {}, handler = function() end })
    registry.register({ name = "b", description = "d", input_schema = {}, handler = function() end })
    local subset = registry.select({"a"})
    assert.equals(1, #subset)
    assert.equals("a", subset[1].name)
  end)
  it("select raises on unknown name", function()
    assert.has_error(function() registry.select({"nonexistent"}) end)
  end)
end)
```

- [ ] **Step 1.2.2: Run, verify fail**

- [ ] **Step 1.2.3: Implement `lua/parley/tools/init.lua`**

```lua
local types = require("parley.tools.types")

local M = {}
local registry = {}

function M.reset()
  registry = {}
end

function M.register(def)
  local ok, err = types.validate_definition(def)
  if not ok then error("parley.tools.register: " .. err) end
  registry[def.name] = def
end

function M.get(name)
  return registry[name]
end

function M.list_names()
  local out = {}
  for name, _ in pairs(registry) do table.insert(out, name) end
  return out
end

-- Given a list of tool names, return the matching definitions in order.
-- Raises on unknown names with the offending name in the message.
function M.select(names)
  local out = {}
  for _, name in ipairs(names) do
    local def = registry[name]
    if not def then
      error("parley.tools.select: unknown tool '" .. name .. "'")
    end
    table.insert(out, def)
  end
  return out
end

return M
```

- [ ] **Step 1.2.4: Run, verify pass**

- [ ] **Step 1.2.5: Commit**

```bash
git add lua/parley/tools/init.lua tests/unit/tools_registry_spec.lua
git commit -m "feat(tools): add tool registry with register/get/list/select

Co-Authored-By: Claude Opus 4.6 (1M context) <noreply@anthropic.com>"
```

### Task 1.3: Register builtin tool STUBS

At M1 we don't have real handlers yet; we need names registered so agents can reference them and Stage 1 passes. **This runs before Task 1.4 (config surface) so that config-validation tests can select real registered tools.**

**Files:**
- Create: `lua/parley/tools/builtin/read_file.lua` (stub returning `{ content = "read_file: not yet implemented (M1 stub)", is_error = true }`)
- Create: stub files for `list_dir`, `grep`, `glob`, `edit_file`, `write_file`
- Modify: `lua/parley/init.lua` — register all six at setup via `tools.register(require("parley.tools.builtin.<name>"))`

- [ ] **Step 1.3.1: Write failing test**

`tests/unit/tools_builtin_registered_spec.lua` — asserts that after `parley.setup({})`, all 6 builtin names are present in `tools.list_names()`.

- [ ] **Step 1.3.2: Run, verify fail**

- [ ] **Step 1.3.3: Implement stubs**

For each of the 6 files, emit a definition table like:

```lua
-- lua/parley/tools/builtin/read_file.lua
return {
  name = "read_file",
  description = "Read a file from the working directory and return its contents with line numbers (1-indexed).",
  input_schema = {
    type = "object",
    properties = {
      path = { type = "string", description = "Relative or absolute path to the file." },
      line_start = { type = "integer", description = "Optional starting line number (1-indexed)." },
      line_end = { type = "integer", description = "Optional ending line number (inclusive)." },
    },
    required = { "path" },
  },
  -- M1 stub: the dispatcher injects the real `id` at execute time, so stubs
  -- omit it. Real handlers in M2–M5 will also omit `id`; the dispatcher
  -- stamps it on the returned ToolResult.
  handler = function(_input)
    return { content = "read_file: not yet implemented (M1 stub)", is_error = true, name = "read_file" }
  end,
}
```

Descriptions and schemas are the real ones that the model will see — write them thoughtfully even at stub stage. Since `id` is injected by the dispatcher (see Task 2.3), handlers do not set it; validators tolerate this because `execute_call` stamps the id before returning.

In `init.lua`, add a `register_builtin_tools()` helper called from `setup()`:

```lua
local function register_builtin_tools()
  local tools = require("parley.tools")
  tools.reset() -- idempotent across repeated setup()
  for _, name in ipairs({ "read_file", "list_dir", "grep", "glob", "edit_file", "write_file" }) do
    tools.register(require("parley.tools.builtin." .. name))
  end
end
```

Call `register_builtin_tools()` near the top of `parley.setup()`, before any agent validation runs (which is important for Task 1.4).

- [ ] **Step 1.3.4: Run, verify pass**

- [ ] **Step 1.3.5: Commit**

```bash
git add lua/parley/tools/builtin/ lua/parley/init.lua tests/unit/tools_builtin_registered_spec.lua
git commit -m "feat(tools): register six builtin tool stubs at setup

Stubs return is_error=true. Real handlers land in M2–M5.
Dispatcher injects ToolResult.id at execute time; handlers omit it.

Co-Authored-By: Claude Opus 4.6 (1M context) <noreply@anthropic.com>"
```

### Task 1.4: Config surface for per-agent tools

**Files:**
- Modify: `lua/parley/config.lua` (new default config keys; new default agent)
- Modify: `lua/parley/init.lua` (validation on setup)
- Test: `tests/unit/config_tools_spec.lua`

Depends on Task 1.3 having run (builtin tools must be registered so the validator can select them).

- [ ] **Step 1.4.1: Write failing test**

`tests/unit/config_tools_spec.lua` — boots parley with a test agent having `tools` and asserts that:
1. Setup succeeds when `tools = { "read_file" }` and that tool is registered (builtins registered in Task 1.3 step which ran in `setup()` before validation).
2. Setup raises a clear error when `tools = { "nonexistent" }` — error message mentions the offending name.
3. Setup succeeds when `tools` is absent (backward-compatible).
4. `max_tool_iterations` defaults to 20 when absent; explicit override wins when present.
5. `tool_result_max_bytes` defaults to 102400 when absent; explicit override wins when present.
6. The default `ClaudeAgentTools` agent ships in the default config with `tools = {"read_file","list_dir","grep","glob","edit_file","write_file"}` present.

Use a pattern similar to existing `tests/unit/dispatcher_spec.lua` — call `parley.setup({ agents = { ... } })` in a `before_each`.

- [ ] **Step 1.4.2: Run, verify fail**

- [ ] **Step 1.4.3: Implement**

In `lua/parley/config.lua`:

- Add three new defaults for prefixes and the shortcut (near line 306, alongside existing `chat_shortcut_*` entries). Match the existing `{ modes, shortcut }` shape:
  ```lua
  chat_tool_use_prefix = "🔧:",
  chat_tool_result_prefix = "📎:",
  chat_shortcut_toggle_tool_folds = { modes = { "n" }, shortcut = "<C-g>b" },
  ```
  (The File Structure table's condensed shape `{ ..., "<C-g>b" }` is shorthand — the real config uses the full `{ modes, shortcut }` form.)

- Add a **real, uncommented** default agent alongside the existing Claude sample agents (around line 152). This is the headline ship artifact of #81 — users get an agentic Claude out of the box:
  ```lua
  {
    provider = "anthropic",
    name = "ClaudeAgentTools",
    model = { model = "claude-sonnet-4-6", temperature = 0.8 },
    system_prompt = require("parley.defaults").chat_system_prompt,
    tools = { "read_file", "list_dir", "grep", "glob", "edit_file", "write_file" },
    max_tool_iterations = 20,
    tool_result_max_bytes = 102400,
  },
  ```

In `lua/parley/init.lua`, locate the agent-resolution block in `parley.setup()`. The existing code iterates `opts.agents` (or `default_config.agents`) and registers them into `M.agents`. **Grep to locate: `for _, agent in ipairs` within `M.setup`.** Add tool validation AFTER each agent's provider/model resolution and BEFORE it's added to `M.agents`:

```lua
local tools_mod = require("parley.tools")
-- ... inside the existing agent-resolution loop, after provider/model are set ...
if agent.tools and #agent.tools > 0 then
  -- Raises with offending tool name if unknown
  local _ = tools_mod.select(agent.tools)
  agent.max_tool_iterations = agent.max_tool_iterations or 20
  agent.tool_result_max_bytes = agent.tool_result_max_bytes or 102400
end
```

This validation runs AFTER `register_builtin_tools()` (called at the top of `setup()` in Task 1.3), so `tools_mod.select` finds all six builtins.

- [ ] **Step 1.4.4: Run, verify pass**

- [ ] **Step 1.4.5: Commit**

```bash
git add lua/parley/config.lua lua/parley/init.lua tests/unit/config_tools_spec.lua
git commit -m "feat(config): per-agent tools + ship ClaudeAgentTools default

Agents opting into tool use declare which builtin tools they want and
get sensible defaults for loop ceiling and result-size cap. Unknown
tool names are rejected at setup with an actionable error.

Ships ClaudeAgentTools as a real default agent so users get agentic
Claude out of the box.

Co-Authored-By: Claude Opus 4.6 (1M context) <noreply@anthropic.com>"
```

### Task 1.5: Anthropic `encode_tools` payload adapter

**Files:**
- Modify: `lua/parley/providers.lua` — add `encode_tools` for anthropic branch
- Modify: `lua/parley/dispatcher.lua` — `prepare_payload` passes agent.tools through
- Test: `tests/unit/anthropic_tool_encode_spec.lua`

- [ ] **Step 1.5.1: Write failing test**

```lua
local tools_mod = require("parley.tools")
local providers = require("parley.providers")

describe("Anthropic encode_tools", function()
  before_each(function() tools_mod.reset() end)
  it("converts a ToolDefinition list into Anthropic tool payload format", function()
    tools_mod.register({
      name = "read_file",
      description = "Read a file.",
      input_schema = { type = "object", properties = { path = { type = "string" } }, required = { "path" } },
      handler = function() end,
    })
    local defs = tools_mod.select({"read_file"})
    local payload = providers.anthropic_encode_tools(defs)
    assert.equals(1, #payload)
    assert.equals("read_file", payload[1].name)
    assert.equals("Read a file.", payload[1].description)
    assert.equals("object", payload[1].input_schema.type)
  end)
  it("returns empty table on empty input", function()
    assert.same({}, providers.anthropic_encode_tools({}))
  end)
end)
```

Also add tests to `tests/unit/dispatcher_spec.lua` verifying that `prepare_payload` for an Anthropic agent with `tools = {...}` produces a payload with a top-level `tools` field, AND — critically — that client-side tools are APPENDED to the existing server-side tools list (`web_search`, `web_fetch`) rather than clobbering it. The append-not-clobber case is the one Task 1.0 baseline capture flagged:

```lua
describe("prepare_payload anthropic client-side tools", function()
  local parley = require("parley")
  local model = { model = "claude-sonnet-4-6", temperature = 0.8, top_p = 1.0, max_tokens = 1024 }
  local msgs = { { role = "user", content = "hi" } }

  before_each(function()
    parley._state = parley._state or {}
    parley._state.web_search = false
    -- Ensure client-side builtins are registered for the test
    require("parley.tools").reset()
    require("parley.tools").register({
      name = "read_file", description = "Read a file.",
      input_schema = { type = "object", properties = { path = { type = "string" } } },
      handler = function() return { content = "", is_error = false } end,
    })
  end)

  it("adds client-side tools to payload when agent has tools configured", function()
    local payload = dispatcher.prepare_payload(msgs, model, "anthropic", { "read_file" })
    assert.is_not_nil(payload.tools)
    assert.equals(1, #payload.tools)
    assert.equals("read_file", payload.tools[1].name)
  end)

  it("does NOT add client-side tools when agent_tools is nil (backward compat)", function()
    local payload = dispatcher.prepare_payload(msgs, model, "anthropic", nil)
    assert.is_nil(payload.tools)
  end)

  it("does NOT add client-side tools when agent_tools is empty (backward compat)", function()
    local payload = dispatcher.prepare_payload(msgs, model, "anthropic", {})
    assert.is_nil(payload.tools)
  end)

  -- THE Task-1.0-finding test: APPEND, do not CLOBBER
  it("APPENDS client-side tools to existing server-side web_search/web_fetch tools", function()
    parley._state.web_search = true -- triggers existing providers.lua server-side tools
    local payload = dispatcher.prepare_payload(msgs, model, "anthropic", { "read_file" })
    assert.is_not_nil(payload.tools)
    assert.equals(3, #payload.tools) -- web_search + web_fetch + read_file

    local names = {}
    for _, t in ipairs(payload.tools) do names[t.name] = true end
    assert.is_true(names["web_search"], "web_search must be preserved")
    assert.is_true(names["web_fetch"],  "web_fetch must be preserved")
    assert.is_true(names["read_file"],  "read_file must be appended")

    parley._state.web_search = false
  end)

  it("byte-identity: vanilla agent (no agent_tools) + web_search=true matches existing dispatcher_spec expectations", function()
    -- This test pins the existing dispatcher_spec.lua:190 expectation
    -- under the new signature. Guards against accidental breakage of the
    -- existing web_search path by our signature change.
    parley._state.web_search = true
    local payload = dispatcher.prepare_payload(msgs, model, "anthropic", nil)
    assert.is_not_nil(payload.tools)
    assert.equals(2, #payload.tools)
    parley._state.web_search = false
  end)
end)
```

**Note on existing test coverage:** `tests/unit/dispatcher_spec.lua` already has tests at lines 184, 190, 209, 223 covering the anthropic `web_search` branch (vanilla-no-tools, with-tools, haiku allowed_callers, non-haiku). Those tests MUST continue to pass unchanged after M1 — they guard the server-side tools path against regression. The new tests above fill the gap the existing ones do NOT cover: the combination of server-side tools AND client-side tools in the same payload. That combination is the exact bug Task 1.0 flagged.

- [ ] **Step 1.5.2: Run, verify fail**

- [ ] **Step 1.5.3: Implement**

In `lua/parley/providers.lua`, add a new top-level function (exported for test access):

```lua
function M.anthropic_encode_tools(tool_definitions)
  local out = {}
  for _, def in ipairs(tool_definitions or {}) do
    table.insert(out, {
      name = def.name,
      description = def.description,
      input_schema = def.input_schema,
    })
  end
  return out
end
```

In `lua/parley/dispatcher.lua` `prepare_payload`, locate the anthropic branch. After building `messages`, if the agent has `tools` configured, call `providers.anthropic_encode_tools(tools_mod.select(agent.tools))` and attach to the payload as `tools = ...`. Critical: only attach when non-empty, so vanilla agents stay byte-identical.

**Signature decision (pinned):** `prepare_payload(messages, model, provider, agent_tools)`. The new `agent_tools` parameter (4th positional) is optional — `nil` or empty for vanilla agents. Matches the existing parameter style in `dispatcher.lua` which already takes flat positional args. Callers in `chat_respond.lua` pass `agent.tools` explicitly. This avoids passing the whole agent table (keeps `prepare_payload` ignorant of agent-table shape) and avoids globals.

**CRITICAL — APPEND, do not CLOBBER, `payload.tools`:**

The Task 1.0 baseline capture revealed that the existing `providers.lua:568+` code already populates `payload.tools` with Anthropic's **server-side tools** (`web_search`, `web_fetch`) when the agent has web search enabled. Our client-side tool encoding MUST append to the existing `payload.tools` list, not overwrite it, otherwise users with web search lose it the moment they select an agent with client-side tools, AND vanilla agents with web search fail the M9 byte-identity check if the append logic is wrong.

```lua
function D.prepare_payload(messages, model, provider, agent_tools)
  -- ... existing body (which may have set payload.tools to server-side tools) ...
  -- In the anthropic branch, after messages are assembled AND after the
  -- existing server-side-tools logic has run:
  if agent_tools and #agent_tools > 0 then
    local defs = require("parley.tools").select(agent_tools)
    local client_tools = require("parley.providers").anthropic_encode_tools(defs)
    -- APPEND, do not overwrite:
    payload.tools = payload.tools or {}
    for _, t in ipairs(client_tools) do
      table.insert(payload.tools, t)
    end
  end
  -- ...
end
```

**Test requirement added to Task 1.5:** the dispatcher spec for tool encoding MUST include a case where the payload already has `tools = [web_search]` from the existing server-side logic, and verify that after client-side tool encoding the result is `tools = [web_search, read_file, ...]` — not `tools = [read_file, ...]`.

Update all existing callers of `prepare_payload` to pass `nil` or the agent's tools list as the new 4th arg. Grep: `prepare_payload(` across the repo — there should be a small number of callers in `chat_respond.lua` and tests.

**M1 caller-update strategy (pinned):** At M1, the only existing `prepare_payload` caller in production code is `chat_respond.lua`'s submit path. In M1, update that call site to pass `agent.tools` (which is `nil` for vanilla agents and the tool list for `ClaudeAgentTools`). No behavior change for vanilla agents (byte-identity held by existing `dispatcher_spec.lua` regression tests). The deeper tool-loop integration of `chat_respond.lua` lands in M2 Task 2.7. Therefore `lua/parley/chat_respond.lua` MUST be included in the Step 1.5.6 commit `git add` list.

- [ ] **Step 1.5.4: Run, verify pass**

- [ ] **Step 1.5.5: Byte-identity regression check**

Before committing, run the existing dispatcher spec: `make test-spec SPEC=dispatcher`. All existing tests MUST still pass — i.e. for agents without `tools`, the payload is unchanged.

- [ ] **Step 1.5.6: Commit**

```bash
git add lua/parley/providers.lua lua/parley/dispatcher.lua lua/parley/chat_respond.lua tests/unit/anthropic_tool_encode_spec.lua tests/unit/dispatcher_spec.lua
git commit -m "feat(providers): anthropic tool encoding in prepare_payload

Agents with tools = {...} now produce Anthropic payloads containing a
top-level tools array. Agents without tools are unchanged
(byte-identical regression locked by existing dispatcher_spec).

Co-Authored-By: Claude Opus 4.6 (1M context) <noreply@anthropic.com>"
```

### Task 1.6: Non-Anthropic provider error stubs

**Files:**
- Modify: `lua/parley/providers.lua` — add `openai_encode_tools`, `googleai_encode_tools`, `ollama_encode_tools` stubs + CLIProxyAPI branch
- Modify: `lua/parley/dispatcher.lua` — `prepare_payload` routes tool encoding through the provider's `_encode_tools` so non-Anthropic tool-enabled agents fail fast
- Test: `tests/unit/provider_tool_stubs_spec.lua`

- [ ] **Step 1.6.1: Write failing test**

```lua
local dispatcher = require("parley.dispatcher")

describe("non-anthropic provider tool stubs", function()
  local msgs = { { role = "user", content = "hi" } }
  local tools = { "read_file" }

  it("openai raises with follow-up message", function()
    local ok, err = pcall(dispatcher.prepare_payload, msgs, "gpt-4o", "openai", tools)
    assert.is_false(ok)
    assert.matches("tools not supported for this provider yet", err)
    assert.matches("#81 follow%-up", err)
  end)
  it("googleai raises with follow-up message", function()
    local ok, err = pcall(dispatcher.prepare_payload, msgs, "gemini-2.0-flash", "googleai", tools)
    assert.is_false(ok)
    assert.matches("tools not supported for this provider yet", err)
  end)
  it("ollama raises with follow-up message", function()
    local ok, err = pcall(dispatcher.prepare_payload, msgs, "llama3", "ollama", tools)
    assert.is_false(ok)
    assert.matches("tools not supported for this provider yet", err)
  end)
  it("cliproxyapi routed to non-anthropic model raises", function()
    -- Force the cliproxyapi branch to non-anthropic model family
    local ok, err = pcall(dispatcher.prepare_payload, msgs, "gpt-4o", "cliproxyapi", tools)
    assert.is_false(ok)
    assert.matches("anthropic%-family", err)
  end)
  it("cliproxyapi routed to anthropic-family model succeeds", function()
    local payload = dispatcher.prepare_payload(msgs, "claude-sonnet-4-6", "cliproxyapi", tools)
    assert.is_table(payload.tools)
  end)
  it("non-anthropic provider WITHOUT tools works unchanged", function()
    local payload = dispatcher.prepare_payload(msgs, "gpt-4o", "openai", nil)
    assert.is_nil(payload.tools)
  end)
end)
```

- [ ] **Step 1.6.2: Run, verify fail**

- [ ] **Step 1.6.3: Implement stubs in `providers.lua`**

```lua
local function unsupported_tools_error()
  error("tools not supported for this provider yet — see #81 follow-up")
end

function M.openai_encode_tools(_defs) unsupported_tools_error() end
function M.googleai_encode_tools(_defs) unsupported_tools_error() end
function M.ollama_encode_tools(_defs) unsupported_tools_error() end
```

CLIProxyAPI helper — detects model family by prefix:

```lua
function M.cliproxyapi_encode_tools(defs, model_name)
  local name = type(model_name) == "table" and model_name.model or model_name
  if not name or not name:match("^claude%-") then
    error("tools not supported for this provider yet — cliproxyapi requires an anthropic-family model (see #81 follow-up)")
  end
  return M.anthropic_encode_tools(defs)
end
```

- [ ] **Step 1.6.4: Wire into `prepare_payload`**

In `dispatcher.lua`, branch on provider name after loading `agent_tools`. Only attempt tool encoding if `agent_tools` is non-empty.

```lua
if agent_tools and #agent_tools > 0 then
  local defs = require("parley.tools").select(agent_tools)
  local providers = require("parley.providers")
  if provider == "anthropic" then
    payload.tools = providers.anthropic_encode_tools(defs)
  elseif provider == "cliproxyapi" then
    payload.tools = providers.cliproxyapi_encode_tools(defs, model)
  elseif provider == "openai" then
    payload.tools = providers.openai_encode_tools(defs) -- raises
  elseif provider == "googleai" then
    payload.tools = providers.googleai_encode_tools(defs) -- raises
  elseif provider == "ollama" then
    payload.tools = providers.ollama_encode_tools(defs) -- raises
  else
    error("tools not supported for provider: " .. tostring(provider))
  end
end
```

- [ ] **Step 1.6.5: Run, verify pass**

- [ ] **Step 1.6.6: Commit**

```bash
git add lua/parley/providers.lua lua/parley/dispatcher.lua tests/unit/provider_tool_stubs_spec.lua
git commit -m "$(cat <<'EOF'
feat(providers): error stubs for non-anthropic tool use

OpenAI/Google/Ollama raise a clear error when a tools-enabled agent
is selected against them. CLIProxyAPI routes to anthropic_encode_tools
only when the model name matches the claude- family; otherwise raises
with an anthropic-family-only message.

Co-Authored-By: Claude Opus 4.6 (1M context) <noreply@anthropic.com>
EOF
)"
```

### Task 1.7: Agent picker `[🔧]` badge

**Files:**
- Modify: `lua/parley/agent_picker.lua`
- Test: `tests/unit/agent_picker_spec.lua` (or add to existing)

- [ ] **Step 1.7.1: Write failing test**

Asserts that the rendered picker line for an agent with `tools = {...}` includes the substring `[🔧]`, and for an agent without it does not.

- [ ] **Step 1.7.2: Run, verify fail**

- [ ] **Step 1.7.3: Implement** — find the existing name-rendering path in `agent_picker.lua` and append `" [🔧]"` conditionally.

- [ ] **Step 1.7.4: Run, verify pass**

- [ ] **Step 1.7.5: Commit**

```bash
git commit -m "feat(agent-picker): show [🔧] badge for tool-enabled agents"
```

### Task 1.8: M1 stage-1 checklist in issue #81

- [ ] **Step 1.8.1: Manual verification**

Per Stage 1 in issue #81:
1. Define a real `ClaudeAgentTools` agent in your local setup with `tools = {"read_file","list_dir","grep","glob","edit_file","write_file"}` (all stubs at this point).
2. `:Parley` → create a chat with that agent.
3. Send "Hi, what is 2+2?" — expect normal text response (model will not call tools for this).
4. Check the latest file in `vim.fn.stdpath("cache") .. "/parley/query/"` — verify the JSON contains a top-level `tools: [...]` array with six entries.
5. Switch to an existing vanilla Claude agent — send the same prompt — verify the cached JSON has NO `tools` field.
6. Open `<C-g>a` agent picker — verify `[🔧]` badge on the tool-enabled agent.
7. Configure an agent with `tools = {"made_up_tool"}` and try to load parley — verify setup-time error mentions `made_up_tool`.
8. Edit the 9-stage checklist in `issues/000081-*.md` → mark all Stage 1 items `[x]`. Add a `### YYYY-MM-DD` log entry (use today's actual date at verification time) summarizing what was verified.

- [ ] **Step 1.8.2: M1 wrap commit**

```bash
git add issues/000081-support-anthropic-tool-use-protocol.md
git commit -m "docs(81): M1 complete, Stage 1 checklist verified

Co-Authored-By: Claude Opus 4.6 (1M context) <noreply@anthropic.com>"
```

---

## Chunk 2: M2 — Single read_file round-trip (end-to-end)

**Goal:** Real `read_file` handler, buffer representation (`🔧:` / `📎:`) with serializer and parser changes, Anthropic streaming decoder accumulates full `ToolCall`, dispatcher single-round loop, fold setup, `<C-g>b` shortcut. Stage 2 passes end-to-end.

**Gated on:** Stage 2 in issue #81.

### Task 2.1: Buffer serializer schema (`🔧:` / `📎:` render + parse)

**Files:**
- Create: `lua/parley/tools/serialize.lua`
- Test: `tests/unit/tools_serialize_spec.lua`

The schema (DRY single source):

```
🔧: <tool_name> id=<id>
```json
{"path": "foo.txt"}
```

📎: <tool_name> id=<id>
```
<result body — plain text>
```
```

- [ ] **Step 2.1.1: Write round-trip test**

```lua
local serialize = require("parley.tools.serialize")

describe("tool serialize", function()
  it("renders and parses a ToolCall round-trip", function()
    local call = { id = "toolu_01", name = "read_file", input = { path = "foo.txt" } }
    local rendered = serialize.render_call(call)
    assert.matches("🔧: read_file id=toolu_01", rendered)
    local parsed = serialize.parse_call(rendered)
    assert.same(call, parsed)
  end)

  it("renders and parses a ToolResult round-trip", function()
    local result = { id = "toolu_01", name = "read_file", content = "line1\nline2", is_error = false }
    local rendered = serialize.render_result(result)
    assert.matches("📎: read_file id=toolu_01", rendered)
    local parsed = serialize.parse_result(rendered)
    assert.equals(result.id, parsed.id)
    assert.equals(result.name, parsed.name)
    assert.equals(result.content, parsed.content)
    assert.equals(false, parsed.is_error)
  end)

  it("round-trips is_error=true", function()
    local result = { id = "toolu_02", name = "edit_file", content = "missing file", is_error = true }
    local parsed = serialize.parse_result(serialize.render_result(result))
    assert.equals(true, parsed.is_error)
    assert.equals("missing file", parsed.content)
  end)

  it("round-trips empty content", function()
    local result = { id = "toolu_03", name = "write_file", content = "", is_error = false }
    local parsed = serialize.parse_result(serialize.render_result(result))
    assert.equals("", parsed.content)
  end)

  it("round-trips content containing triple backticks via dynamic fence", function()
    -- Critical: tool output (e.g. read_file on a markdown file) often
    -- contains ``` fences. The serializer picks a fence longer than the
    -- longest backtick run in content, so the block is unambiguous.
    local result = { id = "toolu_04", name = "read_file", content = "```lua\nlocal x = 1\n```", is_error = false }
    local rendered = serialize.render_result(result)
    -- Rendered MUST use a 4+-backtick fence since content has a 3-backtick run
    assert.matches("````", rendered)
    local parsed = serialize.parse_result(rendered)
    assert.equals(result.content, parsed.content)
  end)

  it("round-trips content containing four consecutive backticks", function()
    local result = { id = "toolu_05", name = "read_file", content = "````not-a-fence", is_error = false }
    local parsed = serialize.parse_result(serialize.render_result(result))
    assert.equals(result.content, parsed.content)
  end)

  it("parse_call handles input with nested JSON", function()
    local call = { id = "toolu_06", name = "edit_file", input = { path = "x", old_string = "a", new_string = "b\nc" } }
    assert.same(call, serialize.parse_call(serialize.render_call(call)))
  end)
end)
```

- [ ] **Step 2.1.2: Run, verify fail**

- [ ] **Step 2.1.3: Implement**

```lua
local M = {}

-- Find the longest run of consecutive backticks in `s`.
local function longest_backtick_run(s)
  local max = 0
  for run in (s or ""):gmatch("`+") do
    if #run > max then max = #run end
  end
  return max
end

-- Return a fence string (repeated backticks) guaranteed longer than any
-- run of backticks in content. Minimum 3.
local function fence_for(content)
  local n = longest_backtick_run(content or "")
  if n < 3 then return "```" end
  return string.rep("`", n + 1)
end

-- Escape a literal substring for use as a Lua pattern.
local function pesc(s)
  return (s:gsub("([%^%$%(%)%%%.%[%]%*%+%-%?])", "%%%1"))
end

--- Render a ToolCall. The JSON body uses a dynamic fence (length > any
--- backtick run in the encoded JSON, minimum 3). Tagged with "json" hint.
function M.render_call(call)
  local input_json = vim.json.encode(call.input or {})
  local fence = fence_for(input_json)
  -- Tag with "json" after the opening fence for syntax highlight
  return string.format("🔧: %s id=%s\n%sjson\n%s\n%s", call.name, call.id, fence, input_json, fence)
end

--- Parse a rendered ToolCall back into the canonical table.
function M.parse_call(text)
  local name, id = text:match("^🔧:%s*(%S+)%s+id=(%S+)")
  if not name then return nil end
  -- Match the opening fence (any length >= 3) followed by optional "json"
  -- hint, then body, then the same fence. %1 backref ensures matching lengths.
  local fence, body = text:match("\n(`+)json%s*\n(.-)\n%1")
  if not fence then
    -- Fallback: no language hint
    fence, body = text:match("\n(`+)%s*\n(.-)\n%1")
  end
  local input = {}
  if body and body ~= "" then
    local ok, decoded = pcall(vim.json.decode, body)
    if ok and type(decoded) == "table" then input = decoded end
  end
  return { id = id, name = name, input = input }
end

--- Render a ToolResult. Body fence is dynamic. is_error is encoded in the
--- header as "error=true" (omitted when false).
function M.render_result(result)
  local content = result.content or ""
  local fence = fence_for(content)
  local err_tag = result.is_error and " error=true" or ""
  return string.format("📎: %s id=%s%s\n%s\n%s\n%s",
    result.name or "", result.id, err_tag, fence, content, fence)
end

--- Parse a rendered ToolResult.
function M.parse_result(text)
  -- Header: 📎: <name> id=<id> [error=true]
  local name, id = text:match("^📎:%s*(%S+)%s+id=(%S+)")
  if not name then return nil end
  -- is_error detection on the header line only (first line up to newline)
  local header = text:match("^([^\n]*)")
  local is_error = header and header:find("error=true", 1, true) ~= nil or false
  -- Dynamic-length fenced body, same backref trick as parse_call
  local fence, body = text:match("\n(`+)%s*\n(.-)\n%1")
  return {
    id = id,
    name = name,
    content = body or "",
    is_error = is_error,
  }
end

return M
```

**Notes:**
- `%1` backreference in the pattern ensures the opening and closing fences are the same length. This is the core DRY guarantee of the dynamic-fence scheme.
- `pesc` helper is not used in the current sketch but kept available; it would become relevant if we later need to escape user-provided strings as patterns.
- Both `parse_call` and `parse_result` return `nil` on malformed input; callers must handle that.

The unit test suite is the guardrail — the dynamic-fence round-trip test with triple backticks is the most important case.

- [ ] **Step 2.1.4: Run, verify pass**

- [ ] **Step 2.1.5: Commit**

```bash
git commit -m "$(cat <<'EOF'
feat(tools): serialize schema for 🔧:/📎: buffer prefixes

Single-source render + parse for tool_use / tool_result buffer
components. Dynamic-length fences (via %1 backref) so LLM output
containing backticks is preserved round-trip.

Co-Authored-By: Claude Opus 4.6 (1M context) <noreply@anthropic.com>
EOF
)"
```

### Task 2.2: Real `read_file` handler

**Files:**
- Modify: `lua/parley/tools/builtin/read_file.lua`
- Test: `tests/unit/tools_builtin_read_file_spec.lua`

- [ ] **Step 2.2.1: Write failing test**

```lua
local read_file = require("parley.tools.builtin.read_file")

describe("read_file handler", function()
  it("returns content with line numbers", function()
    -- write a temp file, call read_file, check output has "1: first", "2: second"
  end)
  it("respects line_start and line_end", function() ... end)
  it("returns is_error=true on missing file", function() ... end)
  it("pure: same input → same output", function() ... end)
end)
```

- [ ] **Step 2.2.2: Run, verify fail** (stub is `is_error = true`)

- [ ] **Step 2.2.3: Implement**

```lua
return {
  name = "read_file",
  description = "Read a file from the working directory and return its contents with line numbers (1-indexed).",
  input_schema = { ... as in M1 stub ... },
  handler = function(input)
    local path = input.path
    if not path then
      return { id = "", content = "missing required field: path", is_error = true, name = "read_file" }
    end
    local f, err = io.open(path, "r")
    if not f then
      return { id = "", content = "cannot open: " .. (err or path), is_error = true, name = "read_file" }
    end
    local lines = {}
    local n = 0
    for line in f:lines() do
      n = n + 1
      if (not input.line_start or n >= input.line_start) and (not input.line_end or n <= input.line_end) then
        table.insert(lines, string.format("%5d  %s", n, line))
      end
    end
    f:close()
    return { id = "", content = table.concat(lines, "\n"), is_error = false, name = "read_file" }
  end,
}
```

NOTE: The handler is PURE (the spec's PURE principle). It does NOT apply the cwd-scope check. Cwd-scope is enforced in the dispatcher (Task 2.3) so all tools share one implementation (DRY).

NOTE: Handler returns `id = ""` — the dispatcher is responsible for stamping the real `id` into the result before it gets serialized. Keeps the handler free of call-identity concerns.

- [ ] **Step 2.2.4–5: Run, verify pass, commit**

### Task 2.3: Dispatcher safety helpers (cwd-scope, truncate, execute)

**Files:**
- Create: `lua/parley/tools/dispatcher.lua` — safety helpers + `execute_call`
- Test: `tests/unit/tools_dispatcher_spec.lua`

- [ ] **Step 2.3.1: Write failing test**

Tests for:
1. `resolve_path_in_cwd(path, cwd)` returns normalized absolute path when inside cwd.
2. Same function returns `nil, err` for absolute path outside cwd.
3. Same function returns `nil, err` for `..` escape (e.g. `../outside.txt` or `foo/../../outside.txt`).
4. Same function resolves symlinks via `vim.loop.fs_realpath` and rejects symlinks whose real path is outside cwd.
5. Same function accepts symlinks whose real path is inside cwd.
6. `truncate(content, max_bytes)` returns unchanged if under, truncated with `... [truncated: N bytes omitted]` marker if over.
7. `execute_call(call, registry, opts)` looks up the tool, runs the handler, stamps the id, truncates, returns a `ToolResult`.
8. `execute_call` on unknown tool name returns `is_error=true` with `"unknown tool: <name>"`.
9. `execute_call` wraps the handler call in `pcall` — a raising handler returns `is_error=true` with the error message, never propagates.

- [ ] **Step 2.3.2: Run, verify fail**

- [ ] **Step 2.3.3: Implement `lua/parley/tools/dispatcher.lua`**

```lua
local types = require("parley.tools.types")
local M = {}

-- Resolve a possibly-relative path against cwd, normalize, resolve any
-- symlinks in the result, and reject anything whose real path escapes cwd.
-- Returns (abs_path) or (nil, err_msg).
function M.resolve_path_in_cwd(path, cwd)
  if type(path) ~= "string" or path == "" then
    return nil, "path must be a non-empty string"
  end
  local joined
  if path:sub(1,1) == "/" then
    joined = vim.fs.normalize(path)
  else
    joined = vim.fs.normalize(cwd .. "/" .. path)
  end
  cwd = vim.fs.normalize(cwd)

  -- Resolve symlinks for both the path and cwd. If the path does not yet
  -- exist (e.g. write_file creating a new file), fall back to the joined
  -- normalized path — the parent directory must still be inside cwd.
  local real_path = vim.loop.fs_realpath(joined)
  if not real_path then
    -- Path doesn't exist: resolve parent dir's real path and append basename
    local parent = vim.fs.dirname(joined)
    local real_parent = vim.loop.fs_realpath(parent)
    if not real_parent then
      return nil, "cannot resolve parent directory: " .. parent
    end
    real_path = real_parent .. "/" .. vim.fs.basename(joined)
  end
  local real_cwd = vim.loop.fs_realpath(cwd) or cwd

  if real_path ~= real_cwd and not (real_path:sub(1, #real_cwd + 1) == real_cwd .. "/") then
    return nil, "path outside working directory: " .. path
  end
  return real_path
end

-- Pure: byte-length truncation with trailing marker.
function M.truncate(content, max_bytes)
  if #content <= max_bytes then return content end
  local omitted = #content - max_bytes
  return content:sub(1, max_bytes) .. string.format("\n... [truncated: %d bytes omitted]", omitted)
end

-- Impure: executes a handler, stamps id, truncates. pcall-guarded so a
-- raising handler never propagates — the dispatcher turns it into an
-- is_error=true result, preserving the cancel-cleanup invariant.
function M.execute_call(call, registry, opts)
  opts = opts or {}
  local def = registry.get(call.name)
  if not def then
    return { id = call.id, name = call.name, content = "unknown tool: " .. call.name, is_error = true }
  end
  local ok, result = pcall(def.handler, call.input or {})
  if not ok then
    return { id = call.id, name = call.name, content = "handler error: " .. tostring(result), is_error = true }
  end
  if type(result) ~= "table" then
    return { id = call.id, name = call.name, content = "handler returned non-table: " .. type(result), is_error = true }
  end
  result.id = call.id
  result.name = call.name
  if opts.max_bytes then
    result.content = M.truncate(result.content or "", opts.max_bytes)
  end
  return result
end

return M
```

Dirty-buffer guard and `.parley-backup` helper land in M5 (Task 5.x).

- [ ] **Step 2.3.4–5: Run, verify pass, commit**

### Task 2.4: Anthropic streaming decoder accumulates `ToolCall`s

**Files:**
- Modify: `lua/parley/providers.lua` (extend the existing Anthropic SSE parser near line 568)
- Create fixture: `tests/fixtures/anthropic_tool_use_stream.jsonl`
- Test: `tests/unit/anthropic_tool_decode_spec.lua`

The existing parser emits progress events for `tool_use` / `input_json_delta`. We need it to ALSO accumulate the full `{id, name, input}` tuple into a buffer the loop driver can read at stream end.

- [ ] **Step 2.4.1: Capture a live tool-use stream as a fixture**

Run a real Anthropic request (via `ANTHROPIC_API_KEY=... make fixtures` or a bespoke script). Save the raw SSE event lines to `tests/fixtures/anthropic_tool_use_stream.jsonl`. This is the ground-truth data.

- [ ] **Step 2.4.2: Write failing test**

Test feeds each fixture line to the Anthropic decoder and, at end of stream, pulls the accumulated `ToolCall` list. Asserts `{id, name, input}` matches the live stream.

- [ ] **Step 2.4.3: Implement**

In `providers.lua` Anthropic SSE parser, add state for the current in-flight tool_use block:
```lua
-- per-stream state stored in the closure/object that owns parsing
local tool_use_state = {
  current = nil,        -- { id, name, input_json_parts = {} } during block
  completed = {},       -- list of finalized ToolCalls at block_stop
}
```

Extend the branches:
- On `content_block_start` with `type == "tool_use"`: start a new `current` with `id`, `name`, empty `input_json_parts`.
- On `input_json_delta`: append `partial_json` to `current.input_json_parts`.
- On `content_block_stop` for the current block: decode JSON, push `{id, name, input}` into `completed`, clear `current`.
- At end of stream: return the `completed` list alongside the existing text/progress outputs.

The exact integration point is at `providers.lua:568+` where `tool_progress_message` already lives. Keep progress events as-is (DRY — same branch does two jobs now).

- [ ] **Step 2.4.4: Run, verify pass**

- [ ] **Step 2.4.5: Commit**

```bash
git commit -m "feat(providers): anthropic SSE decoder accumulates full ToolCalls

Extends existing tool_use/input_json_delta parsing (providers.lua:568+)
to also build a list of completed ToolCall tuples. Progress events are
unchanged; the new state is orthogonal."
```

### Task 2.5: Chat parser recognizes `🔧:` / `📎:` components

**Files:**
- Modify: `lua/parley/chat_parser.lua` (main parse loop, around the existing prefix branches at lines 265-340+)
- Test: extend existing chat_parser tests or new `tests/unit/chat_parser_tools_spec.lua`

- [ ] **Step 2.5.1: Write failing test**

Input: a chat buffer containing a `💬:` question followed by a `🤖:` answer that contains `🔧:` and `📎:` components. Assert that the parser attaches them as a list on the answer object:

```lua
assert.equals(1, #result.exchanges)
local answer = result.exchanges[1].answer
assert.is_table(answer.content_blocks) -- new field
-- Order of blocks matches buffer order: maybe text, then tool_use, then tool_result, then text
assert.equals("text", answer.content_blocks[1].type)
assert.equals("tool_use", answer.content_blocks[2].type)
assert.equals("read_file", answer.content_blocks[2].name)
assert.equals("tool_result", answer.content_blocks[3].type)
assert.equals("text", answer.content_blocks[4].type)
```

- [ ] **Step 2.5.2: Run, verify fail**

- [ ] **Step 2.5.3: Implement**

In `chat_parser.lua`:
1. Read `chat_tool_use_prefix` and `chat_tool_result_prefix` from config at parser entry.
2. Inside the answer-accumulation loop (after the existing `🤖:` handling), add branches for lines starting with `🔧:` and `📎:`. Each starts a new content block of the appropriate type and accumulates lines until the next prefix or the next section.
3. On any prefix transition inside an answer, finalize the current content block into `answer.content_blocks`.
4. A `🤖:` answer with no interleaved tool blocks gets `content_blocks = { { type = "text", text = <full content> } }` for uniform consumers, preserving backward compatibility with tests that read `answer.content`.

Keep `answer.content` as the full text concatenation for backward compat with any call site that reads it; `answer.content_blocks` is the new structured view.

- [ ] **Step 2.5.4–5: Run, verify pass, commit**

```bash
git commit -m "feat(parser): recognize 🔧:/📎: components inside assistant answer

Answer objects now carry a content_blocks list preserving order of
text / tool_use / tool_result. Backward compat: answer.content still
holds the concatenated text. Build_messages will consume
content_blocks in Task 2.6."
```

### Task 2.6: Build_messages → Anthropic payload with content blocks

**Files:**
- Modify: `lua/parley/dispatcher.lua` (`prepare_payload` / `build_messages`)
- Test: `tests/unit/build_messages_spec.lua`

- [ ] **Step 2.6.1: Write failing test**

Given an exchange list where an assistant answer has content_blocks `[text, tool_use, tool_result, text]`, assert that `build_messages` produces:
```
[
  { role = "user", content = "<question>" },
  { role = "assistant", content = [{type="text", text=...}, {type="tool_use", id=..., name=..., input=...}] },
  { role = "user", content = [{type="tool_result", tool_use_id=..., content=..., is_error=false}] },
  { role = "assistant", content = [{type="text", text=...}] },
]
```

This is the Anthropic content-block model. An assistant message's tool_use is followed by a user message containing matching tool_results — exactly what the API expects. Pure transformation over the parse tree.

- [ ] **Step 2.6.2: Run, verify fail**

- [ ] **Step 2.6.3: Implement** — a pure helper that walks `content_blocks` and emits messages. Split assistant-with-tool_use → user-with-tool_result pairs whenever a tool_use block is followed by a tool_result block.

Keep build_messages for non-content-blocks (legacy flat text) unchanged; branch on `answer.content_blocks ~= nil`.

- [ ] **Step 2.6.4: Run, verify pass**

- [ ] **Step 2.6.5: Regression check** — run the full `build_messages_spec.lua` to verify all pre-existing tests pass.

- [ ] **Step 2.6.6: Commit**

```bash
git commit -m "feat(dispatcher): build_messages emits anthropic content blocks for tool use

When an assistant answer has content_blocks, split the message stream
into assistant(text+tool_use) / user(tool_result) pairs matching the
Anthropic API shape. Pure transformation over the parse tree.

Co-Authored-By: Claude Opus 4.6 (1M context) <noreply@anthropic.com>"
```

### Task 2.7: Chat_respond tool loop driver (single-round)

**Files:**
- Create: `lua/parley/tool_loop.lua` — the loop driver in its own file (keeps `chat_respond.lua` reasoning-sized)
- Modify: `lua/parley/chat_respond.lua` — hook the loop driver at the streaming-end callback
- Modify: `lua/parley/providers.lua` — expose accumulated ToolCalls via module-level state keyed by `bufnr` (NOT `_G`)
- Test: `tests/integration/tool_loop_spec.lua` (with mock provider)

This is the biggest edit of M2. Pseudocode for the loop:

```
after provider call finishes streaming:
  pending_calls = tool_loop.take_pending_calls(bufnr)  -- provider-populated, keyed by buf
  if #pending_calls == 0 → done (existing path)
  else:
    for each tool_use in response order:
      resolve path if present (cwd-scope check); error → synthesize 📎: and continue
      execute via tools.dispatcher.execute_call(...)
      render the 📎: result block into the buffer
    if iter >= max_tool_iterations → synthesize 📎: (iteration limit reached) paired with LAST 🔧: and return
    rebuild messages from the updated buffer; call chat_respond again with iter+1
```

#### Provider → loop communication: module-level state (locked in)

**Decision:** providers expose accumulated ToolCalls via a module-level table in `lua/parley/tool_loop.lua`, keyed by target buffer number. NO `_G`, NO signature changes to `dispatcher.query`.

Shape in `lua/parley/tool_loop.lua`:

```lua
local M = {}

-- Module-level state keyed by bufnr. Cleared on `take_pending_calls` so each
-- iteration reads a fresh batch. Providers populate via `push_pending_calls`
-- during SSE parsing.
local pending_calls_by_buf = {}

function M.push_pending_calls(bufnr, calls)
  pending_calls_by_buf[bufnr] = calls
end

function M.take_pending_calls(bufnr)
  local calls = pending_calls_by_buf[bufnr] or {}
  pending_calls_by_buf[bufnr] = nil
  return calls
end

return M
```

Also store per-buffer loop progress (iter, current_tool) in the same module for the lualine indicator (Task 4.2):

```lua
local loop_state_by_buf = {}

function M.set_loop_state(bufnr, state) loop_state_by_buf[bufnr] = state end
function M.get_loop_state(bufnr) return loop_state_by_buf[bufnr] end
function M.clear_loop_state(bufnr) loop_state_by_buf[bufnr] = nil end
```

This gives us a single owner for all tool-loop-related state (DRY), scoped per chat buffer (no cross-chat leaks), and with no globals.

- [ ] **Step 2.7.0: Read `chat_respond.lua` to document integration surface**

Before writing any code in this task, read `lua/parley/chat_respond.lua` end-to-end and jot down in a scratch note:
- Where the streaming-end callback fires (the point where the assistant response has been fully received).
- How text is currently appended to the chat buffer during streaming (which will tell you the equivalent of `append_to_buffer`).
- Whether `chat_respond` currently accepts an options table and where its entry point is.
- How cancellation currently interacts with streaming (relevant to M6).

This de-risks Task 2.7.3 by surfacing integration points BEFORE implementation.

- [ ] **Step 2.7.1: Write integration test with mock provider**

```lua
-- tests/integration/tool_loop_spec.lua
describe("tool loop integration (mock provider)", function()
  it("runs a single-round tool_use → tool_result → final text", function()
    -- Inject a mock for dispatcher.query that:
    -- call 1: emits SSE events matching a tool_use for read_file on "lua/parley/init.lua"
    --         → providers.lua SSE parser calls tool_loop.push_pending_calls(bufnr, {...})
    -- call 2: emits a plain-text assistant response "The first function is foo."
    local call_count = 0
    -- ... set up mock ...

    -- Run chat_respond on a fake buffer containing a question
    -- Assert:
    assert.equals(2, call_count)
    local buf_lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
    local buf_text = table.concat(buf_lines, "\n")
    assert.matches("🔧: read_file id=", buf_text)
    assert.matches("📎: read_file id=", buf_text)
    assert.matches("The first function is foo%.", buf_text)
  end)
end)
```

- [ ] **Step 2.7.2: Run, verify fail**

- [ ] **Step 2.7.3: Implement `lua/parley/tool_loop.lua`**

```lua
local M = {}

-- State (documented above)
local pending_calls_by_buf = {}
local loop_state_by_buf = {}

function M.push_pending_calls(bufnr, calls) pending_calls_by_buf[bufnr] = calls end
function M.take_pending_calls(bufnr)
  local calls = pending_calls_by_buf[bufnr] or {}
  pending_calls_by_buf[bufnr] = nil
  return calls
end
function M.set_loop_state(bufnr, state) loop_state_by_buf[bufnr] = state end
function M.get_loop_state(bufnr) return loop_state_by_buf[bufnr] end
function M.clear_loop_state(bufnr) loop_state_by_buf[bufnr] = nil end

-- Run one iteration of the tool loop on the given buffer. Returns:
--   "done"    → no tool_use in the response; loop is finished
--   "recurse" → at least one tool_use was executed; caller must re-invoke
--               chat_respond on this buffer with iter + 1
--
-- M2 does NOT handle the iteration cap — M4 Task 4.1 lifts that guard and
-- adds a "cap" outcome with proper synthetic-result pairing. For M2, the
-- caller (chat_respond hook) enforces iter <= 1 as a hard single-recursion
-- limit; anything beyond that is a bug this early.
function M.run_iteration(bufnr, agent, iter)
  local calls = M.take_pending_calls(bufnr)
  if #calls == 0 then
    M.clear_loop_state(bufnr)
    return "done"
  end

  local tool_dispatcher = require("parley.tools.dispatcher")
  local tools_registry = require("parley.tools")
  local serialize = require("parley.tools.serialize")
  local cwd = vim.fn.getcwd()
  local max_iter = agent.max_tool_iterations or 20

  for _, call in ipairs(calls) do
    M.set_loop_state(bufnr, { iter = iter, max = max_iter, current_tool = call.name })

    -- Safety: path-scope check (DRY — every call with a "path" goes through this)
    if call.input and type(call.input.path) == "string" then
      local abs, err = tool_dispatcher.resolve_path_in_cwd(call.input.path, cwd)
      if not abs then
        local err_result = { id = call.id, name = call.name, content = err, is_error = true }
        M._append_block(bufnr, serialize.render_result(err_result))
        goto continue
      end
      call.input.path = abs
    end

    local result = tool_dispatcher.execute_call(call, tools_registry, {
      max_bytes = agent.tool_result_max_bytes,
    })
    M._append_block(bufnr, serialize.render_result(result))

    ::continue::
  end

  return "recurse"
end

-- Buffer-append helper. Uses the same mechanism the existing streaming
-- response uses to write to the chat buffer. Implementation will match
-- whatever chat_respond.lua uses (e.g., nvim_buf_set_lines on the tail).
-- Factored into the tool_loop module so both the streaming path and the
-- synthetic-result paths (cancel, cap) share one append function (DRY).
function M._append_block(bufnr, text)
  local lines = vim.split(text, "\n", { plain = true })
  local last = vim.api.nvim_buf_line_count(bufnr)
  vim.api.nvim_buf_set_lines(bufnr, last, last, false, lines)
end

return M
```

Hook this into `chat_respond.lua` at the streaming-end callback point documented in Step 2.7.0:

```lua
-- Pseudocode at the streaming-end callback (M2 — single recursion only).
-- M2 hardcodes iter = 1 so recursion happens at most once. M4 Task 4.1
-- lifts this guard and adds the "cap" outcome.
local tool_loop = require("parley.tool_loop")
local iter = opts and opts.iter or 1
local outcome = tool_loop.run_iteration(bufnr, agent, iter)
if outcome == "recurse" and iter < 1 then
  -- Wait — with iter defaulting to 1 and the guard `iter < 1`, this
  -- branch is never taken in M2. That's INTENTIONAL: M2 caps recursion
  -- at one round. To actually take a second trip, call chat_respond
  -- recursively from within tool_loop, which M4 wires up.
  --
  -- Concretely for M2: after run_iteration returns "recurse", DO NOT
  -- recurse. The tool results are in the buffer; the user will hit
  -- respond again themselves to see the follow-up. This is fine for
  -- Stage 2 verification (the test expects one tool_use → one
  -- tool_result → one final text, which happens within ONE
  -- provider call cycle because the LLM streams both the tool_use AND
  -- a final text response in the same message once it has the result).
  --
  -- Actually: re-read the spec. A single `read_file` roundtrip requires
  -- TWO provider calls (call 1 emits tool_use; call 2 emits final text
  -- after receiving tool_result). So M2 DOES need one recursion.
  --
  -- Corrected M2 hook (one recursion allowed):
end
-- outcome == "done" falls through to existing done-handling
```

**Correction — M2 DOES recurse once.** The minimal Stage 2 scenario is: provider call 1 returns `tool_use`; parley executes the tool and appends `📎:`; provider call 2 returns final text referencing the result. That's 2 provider calls, which means ONE recursion from M2's perspective. So the M2 hook guard is `iter <= 1` (allow recursion from iter 1 to iter 2), not `iter < 1`.

```lua
-- M2 hook (final — one recursion allowed, no cap handling):
local tool_loop = require("parley.tool_loop")
local iter = (opts and opts.iter) or 1
local outcome = tool_loop.run_iteration(bufnr, agent, iter)
if outcome == "recurse" then
  if iter >= 2 then
    -- M2 hard single-recursion limit. Real multi-round arrives in M4.
    -- Synthesize nothing; just return. The buffer is balanced because
    -- run_iteration already appended 📎: for every 🔧: it processed.
    return
  end
  M.chat_respond({ bufnr = bufnr, iter = iter + 1 })
end
-- outcome == "done" falls through to existing done-handling
```

M4 Task 4.1 removes the `if iter >= 2 then return end` guard entirely and adds the cap-outcome handling there.

Expect this task to be 150-300 LOC across the new `tool_loop.lua` and the `chat_respond.lua` integration, with TDD cycles per piece.

- [ ] **Step 2.7.4: Wire providers.lua SSE parser to push into tool_loop**

In `lua/parley/providers.lua`, at the end of the Anthropic SSE parse (`message_stop` event), when the accumulated ToolCall list is non-empty:

```lua
local tool_loop = require("parley.tool_loop")
tool_loop.push_pending_calls(bufnr, completed_tool_calls)
```

`bufnr` flows in from the caller (chat_respond passes it to `dispatcher.query` which passes it to the provider). Match how other per-buffer state already flows through (read current code to verify).

- [ ] **Step 2.7.5: Run integration test, verify pass**

- [ ] **Step 2.7.6: Regression — full suite**

```bash
make test
```
All pre-existing tests MUST pass.

- [ ] **Step 2.7.7: Commit**

```bash
git add lua/parley/tool_loop.lua lua/parley/chat_respond.lua lua/parley/providers.lua tests/integration/tool_loop_spec.lua
git commit -m "$(cat <<'EOF'
feat(chat_respond): single-round tool loop driver in tool_loop.lua

New lua/parley/tool_loop.lua owns all tool-loop state (pending calls
and loop progress), keyed per bufnr — no globals. chat_respond.lua
hooks into it at the streaming-end callback; providers.lua pushes
accumulated ToolCalls after SSE parse. pcall-guarded execute_call
means a raising handler never leaves an orphan 🔧:.

Full multi-round recursion lands in M4 (Task 4.1).

Co-Authored-By: Claude Opus 4.6 (1M context) <noreply@anthropic.com>
EOF
)"
```

### Task 2.8: Fold configuration for `🔧:` / `📎:` regions

**Files:**
- Create: `lua/parley/tool_folds.lua` — foldexpr helper + setup function
- Modify: `lua/parley/chat_respond.lua` or chat-buffer ftplugin init — install foldexpr on chat buffers
- Test: `tests/integration/tool_folds_spec.lua`

**Mechanism (locked in):** per-buffer `foldexpr` using `vim.fn.foldexpr` / `w:foldexpr`. On a line matching `^🔧:` or `^📎:`, start a fold at level 1. On the closing fence line (`^```+$` that closes the preceding tool block), end the fold. Lines inside the fold get level `>=1`. Rationale over foldmarker: foldexpr is content-aware so it survives buffer edits without requiring injected `{{{`/`}}}` markers. Rationale over extmark-based folds: foldexpr is universal and composable with any statusline/fold plugin users already have.

- [ ] **Step 2.8.1: Write failing test**

```lua
-- tests/integration/tool_folds_spec.lua
describe("tool block folds", function()
  it("starts folded on buffer load", function()
    local bufnr = vim.api.nvim_create_buf(false, true)
    vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, {
      "💬: what's in foo?",
      "🤖: [Claude]",
      "Let me look.",
      "🔧: read_file id=toolu_01",
      "```json",
      '{"path":"foo.txt"}',
      "```",
      "📎: read_file id=toolu_01",
      "```",
      "file contents here",
      "```",
      "Done.",
    })
    require("parley.tool_folds").setup_buffer(bufnr)
    -- Line 4 (🔧:) should be a fold start, level 1
    assert.equals(">1", vim.fn.foldexpr and vim.fn.getbufvar(bufnr, "&foldexpr") ~= "" and vim.fn.foldclosed(4) or ">1")
    -- Lines inside the fold (5, 6, 7) should be folded away (foldclosed ~= -1)
    -- Actual assertion depends on fold state; use a helper that opens the buffer
    -- in a window and checks foldclosed.
  end)
  it("📎: blocks also fold", function() ... end)
  it("non-tool exchanges have no extra folds", function() ... end)
end)
```

Folds are notoriously hard to assert headlessly. The test opens the buffer in a hidden window, calls `winrestview`, then queries `foldclosed(line)` which returns the fold-start line if `line` is inside a closed fold or `-1` otherwise.

- [ ] **Step 2.8.2: Run, verify fail**

- [ ] **Step 2.8.3: Implement `lua/parley/tool_folds.lua`**

```lua
local M = {}

-- foldexpr: returns the fold level for the given line.
-- Parley chat buffers expose this via `setlocal foldexpr=v:lua.require'parley.tool_folds'.foldexpr(v:lnum)`.
function M.foldexpr(lnum)
  local line = vim.fn.getline(lnum)
  local use_prefix = vim.g.parley_chat_tool_use_prefix or "🔧:"
  local result_prefix = vim.g.parley_chat_tool_result_prefix or "📎:"

  -- Start of a new fold when we see a tool prefix
  if line:sub(1, #use_prefix) == use_prefix or line:sub(1, #result_prefix) == result_prefix then
    return ">1"
  end

  -- Inside a fold: check if the previous-non-empty line was inside a tool block
  -- by scanning backwards until we hit a tool prefix or a non-fenced-non-tool line.
  -- Simpler heuristic: look at the NEXT line — if it's a closing fence and we
  -- are between a tool prefix and that fence, we're inside.
  --
  -- Efficient O(1) approach: track state via a small state machine by scanning
  -- once at buffer load and caching per-line fold levels on a buffer-local var.
  -- For correctness-first v1, use the naive per-line scan.
  local prev_tool_line = nil
  for i = lnum, 1, -1 do
    local l = vim.fn.getline(i)
    if l:sub(1, #use_prefix) == use_prefix or l:sub(1, #result_prefix) == result_prefix then
      prev_tool_line = i
      break
    end
    -- If we hit a non-tool prefix or non-fenced line that can't be part of a tool body, stop
    if l:match("^💬:") or l:match("^🤖:") or l:match("^🧠:") then
      return "0"
    end
  end
  if not prev_tool_line then return "0" end

  -- Are we before the closing fence of that tool block?
  -- The closing fence is the NEXT fence-only line at a shallower nesting.
  -- Simplification: fence lines are lines matching ^`+$
  local inside = false
  local open_fence = nil
  for i = prev_tool_line + 1, vim.fn.line("$") do
    local l = vim.fn.getline(i)
    if not open_fence then
      local m = l:match("^(`+)")
      if m then open_fence = m end
    else
      if l == open_fence then
        -- End of the tool block
        if lnum <= i then inside = true end
        break
      end
    end
  end

  return inside and "1" or "0"
end

function M.setup_buffer(bufnr)
  vim.api.nvim_buf_call(bufnr, function()
    vim.opt_local.foldmethod = "expr"
    vim.opt_local.foldexpr = "v:lua.require'parley.tool_folds'.foldexpr(v:lnum)"
    vim.opt_local.foldlevel = 0 -- start closed
  end)
end

return M
```

NOTE: The naive foldexpr is O(n²) across the buffer. Optimization (cache per-line fold state in a bufvar, invalidate on `BufWritePost`/`TextChanged`) is a future pass — v1 prioritizes correctness. Flag in the commit message.

- [ ] **Step 2.8.4: Wire into chat-buffer setup**

In `chat_respond.lua` (or wherever `filetype=parley` buffers get their buffer-local options), call `require("parley.tool_folds").setup_buffer(bufnr)` after the chat buffer is created. Also expose the prefixes to the foldexpr via `vim.g.parley_chat_tool_use_prefix` / `vim.g.parley_chat_tool_result_prefix` at setup time (these are read by the foldexpr on each call).

- [ ] **Step 2.8.5: Run, verify pass**

- [ ] **Step 2.8.6: Commit**

```bash
git commit -m "$(cat <<'EOF'
feat(chat): auto-fold 🔧:/📎: blocks on buffer load

New lua/parley/tool_folds.lua exposes a foldexpr that starts a
level-1 fold at every tool prefix line and closes it at the matching
closing fence. Naive O(n²) scan for v1; caching pass later.

Co-Authored-By: Claude Opus 4.6 (1M context) <noreply@anthropic.com>
EOF
)"
```

### Task 2.9: `<C-g>b` toggle-fold-in-exchange shortcut

**Files:**
- Modify: `lua/parley/tool_folds.lua` — add `toggle_exchange_folds(bufnr, cursor_line)` function
- Modify: `lua/parley/init.lua` — register keymap on chat buffer setup
- Test: `tests/integration/tool_folds_toggle_spec.lua`

Exchange under cursor: use `chat_parser` to find which exchange contains the cursor line, then iterate lines in that exchange range and toggle `foldclosed` on any tool-prefix line.

- [ ] **Step 2.9.1: Write failing test**

```lua
describe("<C-g>b exchange fold toggle", function()
  it("opens folded tool blocks in the exchange under cursor", function()
    -- Build buffer with 2 exchanges, each containing a tool block.
    -- Cursor on exchange 1. Call toggle_exchange_folds.
    -- Assert: folds in exchange 1 are open, folds in exchange 2 remain closed.
  end)
  it("closes open tool blocks in the exchange under cursor on second call", function() ... end)
  it("is a no-op in an exchange with no tool components", function() ... end)
  it("does not toggle folds outside the current exchange", function() ... end)
end)
```

- [ ] **Step 2.9.2: Run, verify fail**

- [ ] **Step 2.9.3: Implement `toggle_exchange_folds`**

```lua
function M.toggle_exchange_folds(bufnr, cursor_line)
  local parser = require("parley.chat_parser")
  local parsed = parser.parse(bufnr) -- or whatever the existing parse entry point is
  -- Find the exchange whose line range contains cursor_line
  local target = nil
  for _, ex in ipairs(parsed.exchanges) do
    local line_start = ex.question and ex.question.line_start or nil
    local line_end = ex.answer and ex.answer.line_end or ex.question.line_end
    if line_start and line_end and cursor_line >= line_start and cursor_line <= line_end then
      target = ex
      break
    end
  end
  if not target then return end

  -- Determine if ANY tool fold in the exchange is currently closed.
  -- If so, open all; else close all.
  local use_prefix = vim.g.parley_chat_tool_use_prefix or "🔧:"
  local result_prefix = vim.g.parley_chat_tool_result_prefix or "📎:"
  local any_closed = false
  local tool_lines = {}
  local s = target.question.line_start
  local e = target.answer and target.answer.line_end or target.question.line_end
  for i = s, e do
    local line = vim.api.nvim_buf_get_lines(bufnr, i - 1, i, false)[1] or ""
    if line:sub(1, #use_prefix) == use_prefix or line:sub(1, #result_prefix) == result_prefix then
      table.insert(tool_lines, i)
      if vim.fn.foldclosed(i) ~= -1 then any_closed = true end
    end
  end

  for _, ln in ipairs(tool_lines) do
    if any_closed then
      vim.api.nvim_buf_call(bufnr, function() vim.cmd(ln .. "foldopen") end)
    else
      vim.api.nvim_buf_call(bufnr, function() vim.cmd(ln .. "foldclose") end)
    end
  end
end
```

- [ ] **Step 2.9.4: Wire the keymap**

In `lua/parley/init.lua` where chat-buffer keymaps are set:

```lua
vim.keymap.set("n", cfg.chat_shortcut_toggle_tool_folds.shortcut, function()
  local bufnr = vim.api.nvim_get_current_buf()
  local line = vim.api.nvim_win_get_cursor(0)[1]
  require("parley.tool_folds").toggle_exchange_folds(bufnr, line)
end, { buffer = bufnr, desc = "Parley: toggle tool folds in current exchange" })
```

- [ ] **Step 2.9.5: Run, verify pass**

- [ ] **Step 2.9.6: Commit**

```bash
git commit -m "feat(chat): <C-g>b toggles tool-component folds in exchange under cursor

Reuses chat_parser's exchanges concept to scope the toggle.
Open-all/close-all toggle based on whether any fold is currently
closed in the exchange.

Co-Authored-By: Claude Opus 4.6 (1M context) <noreply@anthropic.com>"
```

### Task 2.10: M2 Stage-2 checklist verification

- [ ] Manual verification per Stage 2 in issue #81. Mark boxes, log entry.
- [ ] Commit the checklist update.

### Task 2.11: M2 post-milestone code review gate

**Mandatory** per the post-milestone review rule at the top of this plan. Dispatch the superpowers code-reviewer subagent against the full M2 commit range before starting M3.

- [ ] **Step 2.11.1:** Identify `BASE_SHA` = the M1-complete commit (the commit immediately before Task 2.0/2.1 touched any file). Use `git log --oneline` to find it.
- [ ] **Step 2.11.2:** Identify `HEAD_SHA` = current HEAD (after Task 2.10 commit lands).
- [ ] **Step 2.11.3:** Dispatch `superpowers:code-reviewer` subagent via the Task tool with:
  - `WHAT_WAS_IMPLEMENTED`: "M2 — Single read_file round-trip: serialize schema, read_file handler, tool dispatcher with safety helpers, Anthropic SSE ToolCall accumulator, chat parser content-block recognition, build_messages Anthropic content blocks, chat_respond tool loop driver (single-round), fold setup, `<C-g>b` shortcut."
  - `PLAN_OR_REQUIREMENTS`: paste the full "Chunk 2: M2" section from this plan file
  - `BASE_SHA`, `HEAD_SHA` from steps 1-2
  - `DESCRIPTION`: "M2 — first real tool loop end-to-end. Biggest architectural shift of #81."
  - Extra context: reference `issues/000081-support-anthropic-tool-use-protocol.md` `## Spec` sections 1 (loop model), 2 (buffer representation), and 4 (provider scope)
  - Emphasize the invariants: buffer-is-state (every tool_use has matching tool_result), append-not-clobber (continues from M1), no globals (tool_loop state is per-bufnr), PURE handlers + DRY dispatcher (safety checks in one place)
- [ ] **Step 2.11.4:** Address every **Critical** and **Important** issue the reviewer finds. Minor/advisory items can be deferred to M3's polish or M9 regression lockdown, but MUST be tracked in the issue's `## Log` section.
- [ ] **Step 2.11.5:** Log the review outcome (approved / issues found + count + fix commit SHAs) in `issues/000081-support-anthropic-tool-use-protocol.md` `## Log`.
- [ ] **Step 2.11.6:** Commit the log update. This commit closes M2.

---

## Chunk 3: M3 + M4 — Remaining read tools and multi-round loop

### M3 — `list_dir`, `grep`, `glob` handlers

Each tool follows the same TDD pattern as `read_file` (Task 2.2) but with full checkbox steps, schemas, and test skeletons inlined below.

### Task 3.1: `list_dir`

**Files:**
- Modify: `lua/parley/tools/builtin/list_dir.lua` (replace M1 stub)
- Test: `tests/unit/tools_builtin_list_dir_spec.lua`

**Schema:**
```lua
input_schema = {
  type = "object",
  properties = {
    path = { type = "string", description = "Directory path relative to cwd." },
    max_depth = { type = "integer", description = "Recursion depth. 1 = shallow listing. Default 1.", default = 1 },
  },
  required = { "path" },
}
```

**Entry cap:** **1000 entries** (hard-committed). If exceeded, truncate the result with a trailing `... [truncated: N entries omitted]` marker applied by the handler itself (separate from the dispatcher's byte-based truncation). Rationale: 1000 entries is ~60KB of listing text which stays comfortably under the 100KB default dispatcher cap while still handling most real directories.

- [ ] **Step 3.1.1: Write failing test**

```lua
local list_dir = require("parley.tools.builtin.list_dir")

describe("list_dir handler", function()
  local tmp
  before_each(function()
    tmp = vim.fn.tempname()
    vim.fn.mkdir(tmp .. "/sub1", "p")
    vim.fn.mkdir(tmp .. "/sub2", "p")
    vim.fn.writefile({"hello"}, tmp .. "/a.txt")
    vim.fn.writefile({"world"}, tmp .. "/b.txt")
    vim.fn.writefile({"nested"}, tmp .. "/sub1/c.txt")
  end)
  after_each(function() vim.fn.delete(tmp, "rf") end)

  it("lists a directory shallow by default", function()
    local result = list_dir.handler({ path = tmp })
    assert.is_false(result.is_error)
    -- Expect a.txt, b.txt, sub1/, sub2/ — sorted
    assert.matches("a%.txt", result.content)
    assert.matches("b%.txt", result.content)
    assert.matches("sub1/", result.content)
    assert.matches("sub2/", result.content)
    -- c.txt is under sub1/, should NOT appear at depth 1
    assert.not_matches("c%.txt", result.content)
  end)

  it("recurses when max_depth = 2", function()
    local result = list_dir.handler({ path = tmp, max_depth = 2 })
    assert.matches("c%.txt", result.content)
  end)

  it("returns error on missing directory", function()
    local result = list_dir.handler({ path = tmp .. "/nope" })
    assert.is_true(result.is_error)
    assert.matches("cannot", result.content)
  end)

  it("sorts output alphabetically", function()
    local result = list_dir.handler({ path = tmp })
    local a_pos = result.content:find("a%.txt")
    local b_pos = result.content:find("b%.txt")
    assert.is_true(a_pos < b_pos)
  end)

  it("truncates at 1000 entries with marker", function()
    local big = tmp .. "/big"
    vim.fn.mkdir(big, "p")
    for i = 1, 1200 do
      vim.fn.writefile({""}, string.format("%s/f%04d.txt", big, i))
    end
    local result = list_dir.handler({ path = big })
    assert.matches("truncated: %d+ entries omitted", result.content)
  end)
end)
```

- [ ] **Step 3.1.2: Run, verify fail** (M1 stub returns is_error = true, test expects is_error = false on happy path)

- [ ] **Step 3.1.3: Implement**

```lua
return {
  name = "list_dir",
  description = "List directory contents. Shallow by default. Confined to the working directory.",
  input_schema = {
    type = "object",
    properties = {
      path = { type = "string", description = "Directory path relative to cwd." },
      max_depth = { type = "integer", description = "Recursion depth. 1 = shallow. Default 1.", default = 1 },
    },
    required = { "path" },
  },
  handler = function(input)
    local path = input.path
    local max_depth = input.max_depth or 1
    if type(path) ~= "string" or path == "" then
      return { content = "missing required field: path", is_error = true, name = "list_dir" }
    end

    local stat = vim.loop.fs_stat(path)
    if not stat or stat.type ~= "directory" then
      return { content = "cannot list: not a directory: " .. path, is_error = true, name = "list_dir" }
    end

    local entries = {}
    local function walk(dir, depth, prefix)
      if depth > max_depth then return end
      local handle = vim.loop.fs_scandir(dir)
      if not handle then return end
      while true do
        local name, kind = vim.loop.fs_scandir_next(handle)
        if not name then break end
        local display = prefix .. name .. (kind == "directory" and "/" or "")
        table.insert(entries, display)
        if kind == "directory" and depth < max_depth then
          walk(dir .. "/" .. name, depth + 1, prefix .. name .. "/")
        end
      end
    end
    walk(path, 1, "")

    table.sort(entries)

    local cap = 1000
    local truncated = false
    if #entries > cap then
      truncated = true
      local omitted = #entries - cap
      for i = #entries, cap + 1, -1 do entries[i] = nil end
      table.insert(entries, string.format("... [truncated: %d entries omitted]", omitted))
    end

    return { content = table.concat(entries, "\n"), is_error = false, name = "list_dir" }
  end,
}
```

- [ ] **Step 3.1.4: Run, verify pass**

- [ ] **Step 3.1.5: Commit**

```bash
git commit -m "feat(tools): list_dir handler with 1000-entry cap"
```

### Task 3.2: `grep`

**Files:**
- Modify: `lua/parley/tools/builtin/grep.lua` (replace M1 stub)
- Test: `tests/unit/tools_builtin_grep_spec.lua`

**Schema:**
```lua
input_schema = {
  type = "object",
  properties = {
    pattern = { type = "string", description = "Regex pattern to search for." },
    path = { type = "string", description = "Directory or file to search. Default: cwd." },
    glob = { type = "string", description = "File glob filter, e.g. '*.lua'." },
    case_sensitive = { type = "boolean", description = "Default true." },
  },
  required = { "pattern" },
}
```

**Implementation strategy:** Prefer ripgrep via `vim.fn.system({ "rg", "--line-number", "--no-heading", "--color=never", ... })`. Fall back to a pure-Lua scanner using `vim.fs.find` + `io.lines` when `vim.fn.executable("rg") == 0`.

**rg flag set (committed):** `--line-number --no-heading --color=never --max-columns=500 --max-count=1000`. The `--max-count=1000` per-file cap prevents a single runaway file from flooding results; the overall result size is additionally capped by the dispatcher's `tool_result_max_bytes`.

- [ ] **Step 3.2.1: Write failing test**

```lua
local grep = require("parley.tools.builtin.grep")

describe("grep handler", function()
  local tmp
  before_each(function()
    tmp = vim.fn.tempname()
    vim.fn.mkdir(tmp, "p")
    vim.fn.writefile({ "local foo = 1", "local bar = 2", "local foo = 3" }, tmp .. "/a.lua")
    vim.fn.writefile({ "print('hello')", "print('FOO')" }, tmp .. "/b.py")
  end)
  after_each(function() vim.fn.delete(tmp, "rf") end)

  it("finds matches with line numbers", function()
    local result = grep.handler({ pattern = "foo", path = tmp })
    assert.is_false(result.is_error)
    assert.matches("a%.lua:1:", result.content)
    assert.matches("a%.lua:3:", result.content)
  end)

  it("returns empty content (not error) on no match", function()
    local result = grep.handler({ pattern = "zzz_nope", path = tmp })
    assert.is_false(result.is_error)
    assert.equals("", result.content)
  end)

  it("respects case_sensitive = false", function()
    local result = grep.handler({ pattern = "FOO", path = tmp, case_sensitive = false })
    assert.matches("a%.lua", result.content) -- lowercase foo should match
    assert.matches("b%.py", result.content)
  end)

  it("respects glob filter", function()
    local result = grep.handler({ pattern = "foo", path = tmp, glob = "*.lua" })
    assert.matches("a%.lua", result.content)
    assert.not_matches("b%.py", result.content)
  end)

  it("falls back when rg is missing", function()
    -- Monkey-patch vim.fn.executable to pretend rg is absent
    local orig = vim.fn.executable
    vim.fn.executable = function(name) if name == "rg" then return 0 end return orig(name) end
    local result = grep.handler({ pattern = "foo", path = tmp })
    vim.fn.executable = orig
    assert.is_false(result.is_error)
    assert.matches("a%.lua", result.content)
  end)
end)
```

- [ ] **Step 3.2.2: Run, verify fail**

- [ ] **Step 3.2.3: Implement** — rg path + pure-Lua fallback. (Full code ~80 LOC; details can be filled in at execution time following the test contract above.)

- [ ] **Step 3.2.4: Run, verify pass**

- [ ] **Step 3.2.5: Commit**

```bash
git commit -m "feat(tools): grep handler (ripgrep with pure-lua fallback)"
```

### Task 3.3: `glob`

**Files:**
- Modify: `lua/parley/tools/builtin/glob.lua` (replace M1 stub)
- Test: `tests/unit/tools_builtin_glob_spec.lua`

**Schema:**
```lua
input_schema = {
  type = "object",
  properties = {
    pattern = { type = "string", description = "Glob pattern, e.g. 'lua/**/*.lua' or '*.md'." },
    path = { type = "string", description = "Base path. Default: cwd." },
  },
  required = { "pattern" },
}
```

**Pattern dispatch (committed):** If the pattern contains `**`, route to `vim.fn.globpath(base, pattern, false, true)` with `wildignore` respected — this handles BOTH leading `**/foo.lua` and middle `lua/**/*.lua` uniformly via Neovim's native recursive glob. Otherwise (no `**`), route to `vim.fn.glob(base .. "/" .. pattern, false, true)` (non-recursive shell glob). Paths are resolved relative to `input.path or vim.fn.getcwd()`.

- [ ] **Step 3.3.1: Write failing test**

```lua
local glob = require("parley.tools.builtin.glob")

describe("glob handler", function()
  local tmp
  before_each(function()
    tmp = vim.fn.tempname()
    vim.fn.mkdir(tmp .. "/sub", "p")
    vim.fn.writefile({""}, tmp .. "/a.lua")
    vim.fn.writefile({""}, tmp .. "/b.lua")
    vim.fn.writefile({""}, tmp .. "/sub/c.lua")
    vim.fn.writefile({""}, tmp .. "/readme.md")
  end)
  after_each(function() vim.fn.delete(tmp, "rf") end)

  it("non-recursive glob", function()
    local result = glob.handler({ pattern = "*.lua", path = tmp })
    assert.matches("a%.lua", result.content)
    assert.matches("b%.lua", result.content)
    assert.not_matches("sub/c%.lua", result.content)
  end)

  it("recursive glob with leading **", function()
    local result = glob.handler({ pattern = "**/*.lua", path = tmp })
    assert.matches("a%.lua", result.content)
    assert.matches("sub/c%.lua", result.content)
  end)

  it("recursive glob with middle ** (e.g. lua/**/*.lua shape)", function()
    -- Verify pattern with ** in the middle also works via globpath routing
    local result = glob.handler({ pattern = "sub/**/*.lua", path = tmp })
    assert.matches("sub/c%.lua", result.content)
    assert.not_matches("a%.lua", result.content) -- NOT in sub/
  end)

  it("returns empty on no match", function()
    local result = glob.handler({ pattern = "*.xyz", path = tmp })
    assert.is_false(result.is_error)
    assert.equals("", result.content)
  end)
end)
```

- [ ] **Step 3.3.2: Run, verify fail**

- [ ] **Step 3.3.3: Implement**

```lua
return {
  name = "glob",
  description = "Find files matching a glob pattern. Use ** for recursive (leading or middle).",
  input_schema = { ... as above ... },
  handler = function(input)
    local pattern = input.pattern
    if type(pattern) ~= "string" or pattern == "" then
      return { content = "missing required field: pattern", is_error = true, name = "glob" }
    end
    local base = input.path or vim.fn.getcwd()
    local matches
    if pattern:find("**", 1, true) then
      -- Recursive: vim.fn.globpath handles both leading (**/foo) and middle
      -- (foo/**/bar) ** uniformly. Returns a list when 4th arg is true.
      matches = vim.fn.globpath(base, pattern, false, true)
    else
      -- Non-recursive
      matches = vim.fn.glob(base .. "/" .. pattern, false, true)
    end
    table.sort(matches)
    return { content = table.concat(matches, "\n"), is_error = false, name = "glob" }
  end,
}
```

- [ ] **Step 3.3.4: Run, verify pass**

- [ ] **Step 3.3.5: Commit**

```bash
git commit -m "feat(tools): glob handler (vim.fn.globpath for **, vim.fn.glob otherwise)"
```

### Task 3.4: Stage-3 manual verification

Per Stage 3 in issue #81.

- [ ] Define `ClaudeAgentTools` (M1 Task 1.4 shipped it). Send prompts exercising each read tool.
- [ ] `:lua require("parley.tools").list_names()` shows all six builtins (stubs replaced by real handlers for read tools).
- [ ] Mark Stage 3 checkboxes in `issues/000081-*.md`. Add log entry.
- [ ] Commit issue updates.

### Task 3.5: M3 post-milestone code review gate

**Mandatory** — same procedure as Task 2.11. Dispatch `superpowers:code-reviewer` with `BASE_SHA` = commit that closed M2 (Task 2.11 commit) and `HEAD_SHA` = current HEAD. `WHAT_WAS_IMPLEMENTED` = "M3 — list_dir / grep / glob read-only tool handlers". Emphasize PURE handlers (no dispatcher concerns leaked in), grep fallback correctness when ripgrep is absent, and 1000-entry cap in list_dir. Address Critical and Important issues before M4.

- [ ] Dispatch review, address issues, log outcome in issue, commit.

### M4 — Multi-round loop + iteration cap + lualine indicator

### Task 4.1: Lift single-round cap in `tool_loop.run_iteration`

Currently gated in M2 by `chat_respond`'s decision not to recurse. Lift that gate so recursion continues until the LLM stops emitting `tool_use` blocks or `max_tool_iterations` is hit.

**Cross-chunk reference:** M2 Task 2.7.3 introduced `tool_loop.run_iteration` with an outcome of `"recurse"` | `"done"` | `"cap"`. M2's `chat_respond` hook honors `"recurse"` but only for a single recursion (bounded by hard-coded `iter=1`). This task removes the single-recursion guard at the `chat_respond` hook site so recursion proceeds as long as `"recurse"` is returned.

**Iteration cap synthetic-result pairing:** When the cap triggers, the synthetic `📎: (iteration limit reached)` MUST pair with the last UNMATCHED `🔧:` id in the buffer. Concretely:
- Before calling the LLM for iteration N+1, check if `N >= max_tool_iterations`. If so:
  - The assistant response from iteration N has already been streamed into the buffer, but if any `🔧:` in that response was NOT followed by a `📎:` (because we stopped before execution), synthesize a `📎: (iteration limit reached)` for each unmatched `🔧:` id, in order.
  - If iteration N's execution already completed all `📎:` pairings, the cap simply ends the loop without synthesizing anything (the buffer is already valid).
- This guarantees the cancel-cleanup invariant: every `🔧:` has a matching `📎:` before control returns to the user.

- [ ] **Step 4.1.1: Write failing tests**

```lua
describe("multi-round tool loop", function()
  it("runs 3 full roundtrips then terminates on plain text", function()
    -- Mock provider that emits tool_use on iterations 1, 2, 3 and plain text on 4.
    -- Assert: buffer contains 3 🔧:/📎: pairs and a final text response.
    -- Assert: mock provider was called exactly 4 times.
  end)

  it("stops at max_tool_iterations with paired synthetic result", function()
    -- max_tool_iterations = 3; mock provider emits tool_use forever.
    -- Cap check happens BEFORE the next LLM call, so with cap=3 the
    -- provider is called exactly 3 times (iterations 1, 2, 3 all run).
    -- After iter 3 executes, the loop recursion would kick off iter 4
    -- but the cap guard fires FIRST, emitting synthetic (iteration limit
    -- reached) for each unmatched 🔧: in the latest assistant response.
    --
    -- In the common case (where iter 3's tool_uses all already have
    -- matching 📎: because execute_call ran them all synchronously),
    -- the synthesis loop is empty — the buffer is already balanced.
    -- The cap just ends the loop.
    --
    -- Assert: mock provider was called exactly 3 times.
    -- Assert: buffer contains 3 complete 🔧:/📎: pairs, no synthetic text.
    -- Assert: assert_buffer_reparsable(bufnr) passes.
  end)

  it("synthesizes paired cap result for unmatched 🔧: in final iteration", function()
    -- Scenario: iter 3 produces a tool_use that we do NOT execute because we
    -- are about to hit the cap. In the current design this cannot happen —
    -- execution always runs for every tool_use in an iteration. So this test
    -- documents the edge case and asserts it never occurs in practice (the
    -- buffer is always balanced). If the design later allows deferred
    -- execution, this test must gain teeth.
    pending("design currently makes this impossible; revisit if that changes")
  end)
end)
```

- [ ] **Step 4.1.2: Run, verify fail**

- [ ] **Step 4.1.3: Implement**

Remove the single-recursion guard from the M2 `chat_respond` hook point. The `tool_loop.run_iteration` outcome alone decides whether to recurse. The iteration cap check happens at the top of `run_iteration` BEFORE executing any calls:

```lua
function M.run_iteration(bufnr, agent, iter)
  local max_iter = agent.max_tool_iterations or 20
  if iter > max_iter then
    -- We're about to execute iteration `iter` but the cap has been hit.
    -- Synthesize a paired 📎: for any 🔧: in the last assistant response
    -- that does not yet have a matching 📎:. (In the current design,
    -- execution of all tool_uses happens immediately on response, so this
    -- loop normally does nothing — see test note above.)
    M._synthesize_cap_results(bufnr)
    M.clear_loop_state(bufnr)
    return "cap"
  end
  -- ... rest of existing body ...
end
```

Add `M._synthesize_cap_results(bufnr)` helper that walks the buffer from the tail, finds all `🔧:` blocks in the latest assistant region that lack a matching `📎:` id, and appends synthetic `📎: (iteration limit reached)` blocks for each. Uses the same `cancelled_result_for(call, "iteration_cap")` helper from M6 Task 6.5 (DRY).

**Note:** The cap helper is shared with M6 cancellation. Task 6.5 is where the `cancelled_result_for` helper lives; this task depends on M6 for the helper implementation OR implements it here first and M6 reuses it. **Commit order decision: implement the helper HERE in a new file `lua/parley/tools/synthetic.lua`, and M6 Task 6.5 becomes a consumer, not a factoring.** Fixes the M6 inverted-ordering issue.

- [ ] **Step 4.1.4: Create `lua/parley/tools/synthetic.lua`**

```lua
local serialize = require("parley.tools.serialize")
local M = {}

-- Returns a ToolResult for a given reason. Used by both cancellation (M6)
-- and iteration-cap (M4). Single source of truth for synthetic-result text.
function M.cancelled_result_for(call, reason)
  local msg
  if reason == "iteration_cap" then
    msg = "(iteration limit reached)"
  elseif reason == "user" then
    msg = "(cancelled by user)"
  else
    msg = "(cancelled)"
  end
  return {
    id = call.id,
    name = call.name,
    content = msg,
    is_error = true,
  }
end

-- Render + append a synthetic result for each unmatched 🔧: id in the
-- current buffer tail. `reason` is passed to cancelled_result_for.
function M.synthesize_for_unmatched(bufnr, reason)
  local parser = require("parley.chat_parser")
  local parsed = parser.parse(bufnr)
  local last = parsed.exchanges[#parsed.exchanges]
  if not (last and last.answer and last.answer.content_blocks) then return end

  -- Collect ids of tool_use blocks without a matching tool_result
  local unmatched = {}
  local matched = {}
  for _, block in ipairs(last.answer.content_blocks) do
    if block.type == "tool_result" then matched[block.id] = true end
  end
  for _, block in ipairs(last.answer.content_blocks) do
    if block.type == "tool_use" and not matched[block.id] then
      table.insert(unmatched, { id = block.id, name = block.name })
    end
  end

  -- Append a synthetic 📎: for each unmatched id, in order
  local tool_loop = require("parley.tool_loop")
  for _, call in ipairs(unmatched) do
    local result = M.cancelled_result_for(call, reason)
    tool_loop._append_block(bufnr, serialize.render_result(result))
  end
end

return M
```

- [ ] **Step 4.1.5: Wire `_synthesize_cap_results` in `tool_loop.lua`** to call `require("parley.tools.synthetic").synthesize_for_unmatched(bufnr, "iteration_cap")`.

- [ ] **Step 4.1.6: Run, verify pass**

- [ ] **Step 4.1.7: Commit**

```bash
git add lua/parley/tools/synthetic.lua lua/parley/tool_loop.lua lua/parley/chat_respond.lua tests/integration/tool_loop_spec.lua
git commit -m "$(cat <<'EOF'
feat(tool_loop): multi-round recursion with iteration cap

Lifts the M2 single-recursion guard. Adds lua/parley/tools/synthetic.lua
as the single source of truth for cancelled/cap synthetic results,
used by both M4 (this commit) and M6 (cancellation, upcoming).
Cap-triggered synthesis walks the latest exchange's content_blocks and
emits a paired 📎: for every unmatched 🔧: id, preserving the cancel-
cleanup invariant.

Co-Authored-By: Claude Opus 4.6 (1M context) <noreply@anthropic.com>
EOF
)"
```

### Task 4.2: Lualine progress indicator

**Files:**
- Modify: `lua/parley/lualine.lua`
- Modify: `lua/parley/tool_loop.lua` — expose `get_loop_state(bufnr)` accessor (already added in M2 Task 2.7.3 per the locked state design)
- Test: `tests/integration/lualine_tool_indicator_spec.lua`

**State location (pinned, no globals):** The per-buffer loop state lives in `tool_loop.lua`'s module-level `loop_state_by_buf` table, set by `run_iteration` at the top of each iteration and cleared on `done` / `cap`. Lualine reads it via `require("parley.tool_loop").get_loop_state(bufnr)` — NO globals.

- [ ] **Step 4.2.1: Write failing test**

```lua
describe("lualine tool indicator", function()
  it("shows 🔧 <tool> (N/max) when a loop is active", function()
    local tool_loop = require("parley.tool_loop")
    local lualine = require("parley.lualine")
    local fake_buf = 42
    tool_loop.set_loop_state(fake_buf, { iter = 2, max = 20, current_tool = "read_file" })
    local status = lualine.tool_indicator(fake_buf)
    assert.matches("🔧 read_file %(2/20%)", status)
  end)
  it("returns empty string when no loop is active", function()
    local tool_loop = require("parley.tool_loop")
    local lualine = require("parley.lualine")
    tool_loop.clear_loop_state(43)
    assert.equals("", lualine.tool_indicator(43))
  end)
end)
```

- [ ] **Step 4.2.2: Run, verify fail**

- [ ] **Step 4.2.3: Implement**

Add a new function `lualine.tool_indicator(bufnr)` to `lua/parley/lualine.lua`:

```lua
function M.tool_indicator(bufnr)
  bufnr = bufnr or vim.api.nvim_get_current_buf()
  local ok, tool_loop = pcall(require, "parley.tool_loop")
  if not ok then return "" end
  local state = tool_loop.get_loop_state(bufnr)
  if not state then return "" end
  return string.format("🔧 %s (%d/%d)", state.current_tool or "?", state.iter or 0, state.max or 0)
end
```

Users wire this into their lualine section of choice; the README should mention it.

- [ ] **Step 4.2.4: Run, verify pass**

- [ ] **Step 4.2.5: Commit**

```bash
git commit -m "feat(lualine): tool_indicator reads per-buffer loop state

No globals — state lives in tool_loop.lua's module-level table.
Users opt in by adding parley.lualine.tool_indicator to their lualine
section configuration."
```

### Task 4.3: Stage-4 manual verification

Per Stage 4 in issue #81.

- [ ] Verify all three Stage 4 checks (5+ tool calls in one turn render correctly; max_tool_iterations=3 stops with synthetic cap result; resubmit after cap parses cleanly).
- [ ] Mark Stage 4 boxes in the issue. Add log entry.
- [ ] Commit issue updates.

### Task 4.4: M4 post-milestone code review gate

**Mandatory** — same procedure as Task 2.11. `BASE_SHA` = M3 close commit. `WHAT_WAS_IMPLEMENTED` = "M4 — multi-round tool loop with iteration cap and lualine indicator. Introduces `lua/parley/tools/synthetic.lua` (shared with M6 cancellation)." Emphasize: cap-check happens BEFORE next LLM call, synthetic `(iteration limit reached)` result preserves buffer-reparsable invariant, no globals for loop state, lualine indicator reads per-bufnr state only.

- [ ] Dispatch review, address issues, log outcome, commit.

---

## Chunk 4: M5 — Write tools with safety (edit_file, write_file, dirty-buffer, .parley-backup)

### Task 5.1: Dirty-buffer guard and checktime-reload helpers

**Files:**
- Modify: `lua/parley/tools/dispatcher.lua` — add `check_dirty_buffer(abs_path) → ok, err` and `_checktime_if_loaded(abs_path)`
- Test: `tests/unit/tools_dispatcher_spec.lua` (extend)

Both helpers are buffer-aware and live together for DRY / locality of reference.

- [ ] **Step 5.1.1: Write failing tests**

```lua
describe("check_dirty_buffer", function()
  it("returns false on buffer with unsaved changes", function() ... end)
  it("returns true on loaded non-dirty buffer", function() ... end)
  it("returns true when no buffer loads the path", function() ... end)
end)

describe("_checktime_if_loaded", function()
  it("reloads a loaded non-dirty buffer after disk change", function()
    -- Load a file in a buffer, modify it on disk via io.open,
    -- call _checktime_if_loaded, assert buffer lines reflect the new content
  end)
  it("is a no-op for unloaded paths", function() ... end)
  it("does NOT touch a dirty buffer", function()
    -- Invariant: _checktime is only called AFTER a successful write, which
    -- only happens AFTER check_dirty_buffer passed; so this case should
    -- never occur in production. But defensive: assert that if it is
    -- called on a dirty buffer, it does not lose changes.
  end)
end)
```

- [ ] **Step 5.1.2: Run, verify fail**

- [ ] **Step 5.1.3: Implement**

```lua
local function find_loaded_buf_for_path(abs_path)
  local target = vim.fs.normalize(abs_path)
  for _, buf in ipairs(vim.api.nvim_list_bufs()) do
    if vim.api.nvim_buf_is_loaded(buf) then
      local name = vim.api.nvim_buf_get_name(buf)
      if name ~= "" and vim.fs.normalize(name) == target then
        return buf
      end
    end
  end
  return nil
end

function M.check_dirty_buffer(abs_path)
  local buf = find_loaded_buf_for_path(abs_path)
  if not buf then return true, nil end
  if vim.api.nvim_get_option_value("modified", { buf = buf }) then
    return false, "buffer has unsaved changes: " .. abs_path
  end
  return true, buf
end

function M._checktime_if_loaded(abs_path)
  local buf = find_loaded_buf_for_path(abs_path)
  if not buf then return end
  -- Only safe when not dirty (guarded by check_dirty_buffer upstream)
  if vim.api.nvim_get_option_value("modified", { buf = buf }) then return end
  vim.api.nvim_buf_call(buf, function() vim.cmd("checktime") end)
end
```

- [ ] **Step 5.1.4: Run, verify pass**
- [ ] **Step 5.1.5: Commit**

### Task 5.2: `.parley-backup` helper

- [ ] Test: file exists with content "old" → helper creates `<path>.parley-backup` with "old" and returns it. Same path called again → helper does NOT overwrite backup.
- [ ] Test: file does NOT exist → helper creates `<path>.parley-backup` with sentinel `# parley:deleted-before-write`.
- [ ] Implement in `lua/parley/tools/dispatcher.lua`:

```lua
function M.ensure_backup(abs_path)
  local backup_path = abs_path .. ".parley-backup"
  local existing = io.open(backup_path, "r")
  if existing then existing:close(); return backup_path end
  local orig = io.open(abs_path, "r")
  local content
  if orig then
    content = orig:read("*a"); orig:close()
  else
    content = "# parley:deleted-before-write\n"
  end
  local f = io.open(backup_path, "w")
  if not f then return nil, "cannot write backup: " .. backup_path end
  f:write(content); f:close()
  return backup_path
end
```

- [ ] Run, commit.

### Task 5.3: Auto-gitignore for `*.parley-backup` in repo-mode

**Files:**
- Modify: `lua/parley/tools/dispatcher.lua` — add `ensure_gitignore_entry(repo_root)` and a dispatcher-local session-once flag
- Test: `tests/unit/tools_dispatcher_gitignore_spec.lua`

**Session-once flag location (pinned):** The "only once per session" guarantee uses a module-local table `M._gitignore_checked = {}` keyed by `repo_root` string, initialized to `{}` at module load. Reset on test setup via `M.reset_gitignore_checked()`. NOT stored in chat state (would break across chat switches) and NOT global.

**Repo-mode detection (pinned):** Use `require("parley.helper").find_repo_root()` if it exists, otherwise walk up from cwd looking for the `.parley` marker file. Locate the existing helper first — grep for `find_repo_root` or `repo_mode` in `lua/parley/`. Implementer resolves this in the first step of this task.

- [ ] Test: in a temp repo with `.parley` marker file and a `.gitignore` without the line → helper appends it. With the line already present → helper is a no-op.
- [ ] Test: outside repo-mode (no `.parley` marker) → helper does NOT touch `.gitignore` even if present.
- [ ] Test: calling the helper twice in the same session → second call is a no-op (session-once guarantee).
- [ ] Implement in `lua/parley/tools/dispatcher.lua`:

```lua
M._gitignore_checked = {}

function M.reset_gitignore_checked() M._gitignore_checked = {} end

function M.ensure_gitignore_entry(repo_root)
  if not repo_root or M._gitignore_checked[repo_root] then return end
  M._gitignore_checked[repo_root] = true

  local gi_path = repo_root .. "/.gitignore"
  local f = io.open(gi_path, "r")
  local content = f and f:read("*a") or ""
  if f then f:close() end
  if content:find("*.parley-backup", 1, true) then return end
  local out = io.open(gi_path, "a")
  if not out then return end
  if content ~= "" and not content:match("\n$") then out:write("\n") end
  out:write("*.parley-backup\n")
  out:close()
end
```

- [ ] Run, commit.

### Task 5.4: `edit_file` handler

**Schema:** `{ path, old_string, new_string, replace_all? }`

- [ ] Tests:
  1. Happy path: unique `old_string` → replaced.
  2. Non-unique `old_string` with `replace_all=false` → error, file unchanged.
  3. Non-unique `old_string` with `replace_all=true` → all replaced.
  4. Missing `old_string` → error.
  5. File not readable → error.
  6. Pure function: given input, returns result without side effects beyond the target file.
- [ ] Implement (pure handler; cwd-scope enforced by caller):

```lua
return {
  name = "edit_file",
  description = "Perform a literal string replacement in a file. Errors if old_string is not unique unless replace_all is true.",
  input_schema = {
    type = "object",
    properties = {
      path = { type = "string" },
      old_string = { type = "string" },
      new_string = { type = "string" },
      replace_all = { type = "boolean" },
    },
    required = { "path", "old_string", "new_string" },
  },
  handler = function(input)
    local f = io.open(input.path, "r")
    if not f then return { content = "cannot read: " .. input.path, is_error = true, name = "edit_file" } end
    local content = f:read("*a"); f:close()
    local old = input.old_string
    if old == "" then return { content = "old_string must not be empty", is_error = true, name = "edit_file" } end

    -- Count occurrences (literal, not pattern)
    local count = 0
    local search_from = 1
    while true do
      local s, e = content:find(old, search_from, true)
      if not s then break end
      count = count + 1
      search_from = e + 1
    end

    if count == 0 then
      return { content = "old_string not found in file", is_error = true, name = "edit_file" }
    end
    if count > 1 and not input.replace_all then
      return { content = string.format("old_string appears %d times (use replace_all=true)", count), is_error = true, name = "edit_file" }
    end

    -- Literal replace (not gsub — gsub is pattern-based)
    local new_content
    if input.replace_all then
      new_content = content:gsub(old:gsub("[%-%.%+%[%]%(%)%$%^%%%?%*]", "%%%1"), (input.new_string:gsub("%%", "%%%%")))
    else
      local s, e = content:find(old, 1, true)
      new_content = content:sub(1, s - 1) .. input.new_string .. content:sub(e + 1)
    end

    local out = io.open(input.path, "w")
    if not out then return { content = "cannot write: " .. input.path, is_error = true, name = "edit_file" } end
    out:write(new_content); out:close()
    return { content = string.format("edited: %d replacement(s)", count == 1 and 1 or count), is_error = false, name = "edit_file" }
  end,
}
```

- [ ] Run, verify, commit.

### Task 5.5: `write_file` handler

**Schema:** `{ path, content }`

- [ ] Handler-level tests (pure, no dispatcher in the way):
  1. Write to a path → file content matches input.
  2. Overwriting an existing file → file content matches input (handler does NOT touch `.parley-backup` — that's the dispatcher's job in Task 5.6).
  3. Returns `is_error=false` and `content = "wrote N bytes"` on success.
  4. Returns `is_error=true` on permission denied.

**NOTE:** `.parley-backup` creation and `pre-image:` metadata line are tested in Task 5.6 (the dispatcher-level integration), not here. The handler is pure I/O on the target path only.

- [ ] Implement handler as pure I/O on the path (cwd-scope, dirty-buffer, backup, gitignore all enforced by the DISPATCHER before the handler runs):

```lua
return {
  name = "write_file",
  description = "Create or overwrite a file. Confined to the working directory.",
  input_schema = {
    type = "object",
    properties = { path = { type = "string" }, content = { type = "string" } },
    required = { "path", "content" },
  },
  handler = function(input)
    local f = io.open(input.path, "w")
    if not f then return { content = "cannot write: " .. input.path, is_error = true, name = "write_file" } end
    f:write(input.content); f:close()
    return { content = "wrote " .. #input.content .. " bytes", is_error = false, name = "write_file" }
  end,
}
```

The `pre-image:` line is appended by the DISPATCHER after `ensure_backup` returns — this keeps the handler pure and the pre-image metadata consistent across any future destructive tool.

- [ ] Run, verify, commit.

### Task 5.6: Dispatcher write-path orchestration

**Files:**
- Modify: `lua/parley/tools/dispatcher.lua` — extend `execute_call` with a write-path branch
- Modify: all 6 builtin `ToolDefinition` files — add `kind = "read"` or `kind = "write"` field
- Test: `tests/unit/tools_dispatcher_write_path_spec.lua`

**Write-path algorithm (pinned, applies to every tool with `kind = "write"`):**

1. Resolve path via `resolve_path_in_cwd` (shared with read tools — already done in M2). Error → return `is_error=true`.
2. Check `check_dirty_buffer(abs_path)`. Dirty → return `is_error=true` with the dirty-buffer message.
3. If the tool declares `needs_backup = true` (only `write_file` in v1, set in its definition file):
   a. Call `ensure_backup(abs_path)` → get `backup_path`.
   b. Call `ensure_gitignore_entry(repo_root)` (session-once, noop outside repo-mode).
4. Call `handler(input)` via the pcall-guarded path (already in M2 `execute_call`).
5. If result is NOT an error AND `needs_backup`, append a **metadata footer** to the result content:
   ```
   <original content>

   pre-image: <backup_path>
   ```
6. Call `M.truncate(result.content, opts.max_bytes)` — **AFTER** metadata append. **Truncation is metadata-preserving**: if adding the metadata footer would exceed `max_bytes`, truncate the body portion only and keep the footer intact. See `truncate_preserving_footer` below.
7. If the handler succeeded AND the file is loaded in a non-dirty buffer, trigger `:checktime` on that buffer so the user sees the new content.

**`truncate_preserving_footer`:** A new helper alongside `M.truncate`. Signature: `truncate_preserving_footer(body, footer, max_bytes)`. If `#body + #footer + 2 <= max_bytes`, return `body .. "\n\n" .. footer`. Else truncate body to `max_bytes - #footer - #footer_marker - 2`, append the `... [truncated: N bytes omitted]` marker, then append `"\n\n" .. footer`. Ensures the `pre-image:` line is NEVER truncated off, which is required for #84's future replay.

**Tool metadata registry:** add `kind` and `needs_backup` fields to every `ToolDefinition`:
```lua
-- In lua/parley/tools/builtin/read_file.lua (and list_dir, grep, glob):
return { name = "read_file", kind = "read", description = "...", input_schema = {...}, handler = ... }
-- In lua/parley/tools/builtin/edit_file.lua:
return { name = "edit_file", kind = "write", needs_backup = false, description = "...", ... }
-- In lua/parley/tools/builtin/write_file.lua:
return { name = "write_file", kind = "write", needs_backup = true, description = "...", ... }
```
Extend `types.validate_definition` to accept the new fields (both optional; default `kind = "read"`, `needs_backup = false`).

- [ ] **Step 5.6.1: Extend types with kind / needs_backup**

Update `types.lua` validator and commit.

- [ ] **Step 5.6.2: Write failing tests**

```lua
describe("dispatcher write-path orchestration", function()
  it("rejects write to a dirty buffer", function()
    -- open a buffer for path, set modified, call execute_call, assert is_error
  end)
  it("creates .parley-backup on first write_file", function()
    -- assert backup file exists with original content
  end)
  it("preserves earliest .parley-backup on second write_file to same path", function()
    -- write, modify, write again, assert backup still holds pre-first-write content
  end)
  it("creates sentinel backup for new file write_file", function()
    -- assert .parley-backup contains "# parley:deleted-before-write"
  end)
  it("appends pre-image: metadata to write_file result body", function()
    local result = dispatcher.execute_call(write_file_call, registry, { max_bytes = 102400 })
    assert.matches("pre%-image: .+%.parley%-backup", result.content)
  end)
  it("edit_file result does NOT contain pre-image: metadata", function()
    local result = dispatcher.execute_call(edit_file_call, registry, { max_bytes = 102400 })
    assert.not_matches("pre%-image:", result.content)
  end)
  it("truncate preserves pre-image: footer even when body exceeds cap", function()
    local huge = string.rep("x", 200000)
    -- write_file with huge content, max_bytes=1000
    -- assert result.content ends with "pre-image: <path>"
    -- assert "[truncated:" marker appears before the footer
  end)
  it(":checktime reloads a loaded non-dirty buffer after write_file", function()
    -- open buffer for path, run write_file, assert buffer lines now reflect new content
  end)
  it("reads go through the same cwd-scope check as writes (DRY)", function()
    -- read_file with path outside cwd → error tool_result
  end)
  it("no write-safety duplication in handlers", function()
    -- Direct handler call with dirty buffer should SUCCEED (handler is pure).
    -- Only the dispatcher-level execute_call enforces dirty-buffer.
    -- This test locks in the DRY invariant.
  end)
end)
```

- [ ] **Step 5.6.3: Run, verify fail**

- [ ] **Step 5.6.4: Implement**

Extend `execute_call` with a write-path branch. Add `truncate_preserving_footer` helper.

```lua
function M.truncate_preserving_footer(body, footer, max_bytes)
  local sep = "\n\n"
  if #body + #sep + #footer <= max_bytes then
    return body .. sep .. footer
  end
  local marker = string.format("\n... [truncated: %d bytes omitted]", 0) -- placeholder, recomputed below
  local budget = max_bytes - #footer - #sep - 64 -- 64 bytes reserve for the marker
  if budget < 0 then budget = 0 end
  local trimmed = body:sub(1, budget)
  marker = string.format("\n... [truncated: %d bytes omitted]", #body - budget)
  return trimmed .. marker .. sep .. footer
end

function M.execute_call(call, registry, opts)
  opts = opts or {}
  local def = registry.get(call.name)
  if not def then
    return { id = call.id, name = call.name, content = "unknown tool: " .. call.name, is_error = true }
  end

  -- SHARED PRELUDE: cwd-scope check applies to EVERY tool with a path input
  -- (read or write). DRY: single site for cwd enforcement. This call may
  -- have already been done by the caller (tool_loop.run_iteration does it
  -- before execute_call for efficiency), but we re-run here to guarantee
  -- that direct callers of execute_call cannot bypass it.
  if call.input and type(call.input.path) == "string" then
    -- If the path is already absolute and inside cwd, resolve_path_in_cwd
    -- is a no-op; otherwise it resolves relative → absolute AND checks scope.
    local cwd = vim.fn.getcwd()
    local abs, scope_err = M.resolve_path_in_cwd(call.input.path, cwd)
    if not abs then
      return { id = call.id, name = call.name, content = scope_err, is_error = true }
    end
    call.input.path = abs
  end

  -- WRITE-PATH PRELUDE (only for kind = "write")
  if def.kind == "write" and call.input and type(call.input.path) == "string" then
    -- Dirty-buffer guard
    local clean, err = M.check_dirty_buffer(call.input.path)
    if not clean then
      return { id = call.id, name = call.name, content = err, is_error = true }
    end
    -- Backup (if needed)
    if def.needs_backup then
      local backup_path, berr = M.ensure_backup(call.input.path)
      if not backup_path then
        return { id = call.id, name = call.name, content = berr or "backup failed", is_error = true }
      end
      -- Gitignore (session-once)
      local helper = require("parley.helper")
      local repo_root = helper.find_repo_root and helper.find_repo_root() or nil
      if repo_root then M.ensure_gitignore_entry(repo_root) end
      -- Stash backup_path for the post-handler footer
      call._parley_backup_path = backup_path
    end
  end

  -- HANDLER (pcall-guarded, as in M2)
  local ok, result = pcall(def.handler, call.input or {})
  if not ok then
    return { id = call.id, name = call.name, content = "handler error: " .. tostring(result), is_error = true }
  end
  if type(result) ~= "table" then
    return { id = call.id, name = call.name, content = "handler returned non-table: " .. type(result), is_error = true }
  end
  result.id = call.id
  result.name = call.name

  -- WRITE-PATH POSTLUDE
  if def.kind == "write" and not result.is_error then
    -- Metadata footer (write_file only)
    local footer = nil
    if def.needs_backup and call._parley_backup_path then
      footer = "pre-image: " .. call._parley_backup_path
    end
    -- Truncate (metadata-preserving if there's a footer)
    if opts.max_bytes then
      if footer then
        result.content = M.truncate_preserving_footer(result.content or "", footer, opts.max_bytes)
      else
        result.content = M.truncate(result.content or "", opts.max_bytes)
      end
    elseif footer then
      result.content = (result.content or "") .. "\n\n" .. footer
    end
    -- :checktime reload
    M._checktime_if_loaded(call.input.path)
  else
    -- READ-PATH (or write error): plain truncate
    if opts.max_bytes then
      result.content = M.truncate(result.content or "", opts.max_bytes)
    end
  end

  return result
end
```

- [ ] **Step 5.6.5: Run, verify pass**

- [ ] **Step 5.6.6: Commit**

```bash
git commit -m "$(cat <<'EOF'
feat(tools): dispatcher write-path orchestration

Kind-based branch (read/write) in execute_call adds dirty-buffer,
backup, gitignore, checktime-reload, and metadata-preserving
truncation. All write-safety concerns live in the dispatcher; handlers
remain pure I/O on the target path.

DRY locks in: cwd-scope, dirty-buffer, backup, gitignore, truncation
all have a single implementation. Handlers never duplicate these.

Co-Authored-By: Claude Opus 4.6 (1M context) <noreply@anthropic.com>
EOF
)"
```

### Task 5.7: Stage-5 manual verification

Per Stage 5 in issue #81. This is the most safety-critical stage.

- [ ] **Step 5.7.1:** Execute all 11 Stage 5 checks in `issues/000081-support-anthropic-tool-use-protocol.md` lines 206-217 in a live Neovim session with a real `ClaudeAgentTools` agent.
- [ ] **Step 5.7.2:** Mark each Stage 5 box in the issue file and add a `### YYYY-MM-DD` log entry summarizing what was verified.
- [ ] **Step 5.7.3:** Commit the issue updates.

### Task 5.8: M5 post-milestone code review gate

**Mandatory + CRITICAL for M5 specifically** — write tools are the highest-risk code in #81. `BASE_SHA` = M4 close commit. `WHAT_WAS_IMPLEMENTED` = "M5 — edit_file / write_file handlers + dispatcher write-path orchestration (cwd scope, dirty-buffer guard, .parley-backup pre-image capture, gitignore auto-add in repo-mode, post-write :checktime reload, metadata-preserving truncation)". Emphasize: cwd-scope via `vim.loop.fs_realpath` handles symlinks, `.parley-backup` is created only on first write AND never overwritten, `pre-image:` metadata footer survives truncation, dirty-buffer guard cannot be bypassed, edit_file is reversible via old_string without backup. This is a SECURITY review as much as a correctness review.

- [ ] Dispatch review, address ALL Critical issues (no deferring), address Important issues, log outcome, commit.

---

## Chunk 5: M6 + M7 + M8 + M9

### M6 — Cancellation hardening

**Buffer-reparsability invariant helper (DRY — used by every M6 test):** Create `tests/helpers/assert_reparsable.lua`:
```lua
local M = {}
function M.assert_buffer_reparsable(bufnr)
  local parser = require("parley.chat_parser")
  local parsed = parser.parse(bufnr)
  -- Every tool_use in the latest answer must have a matching tool_result
  for _, ex in ipairs(parsed.exchanges) do
    if ex.answer and ex.answer.content_blocks then
      local matched = {}
      for _, b in ipairs(ex.answer.content_blocks) do
        if b.type == "tool_result" then matched[b.id] = true end
      end
      for _, b in ipairs(ex.answer.content_blocks) do
        if b.type == "tool_use" and not matched[b.id] then
          error("buffer not reparsable: unmatched tool_use id=" .. b.id)
        end
      end
    end
  end
end
return M
```
Every M6 test calls `assert_reparsable.assert_buffer_reparsable(bufnr)` as its final assertion.

### Task 6.1: `<Esc>` buffer-local mapping

**Files:**
- Modify: `lua/parley/init.lua` where chat-buffer keymaps are set
- Modify: `lua/parley/config.lua` — add `chat_shortcut_stop_esc = true` default
- Test: `tests/integration/chat_esc_stop_spec.lua`

- [ ] **Step 6.1.1: Write failing test**

```lua
describe("<Esc> in chat buffer triggers stop", function()
  it("buffer-local <Esc> in normal mode calls ChatStop", function()
    -- Create chat buffer; mock ChatStop; simulate <Esc> keypress via nvim_feedkeys
    -- Assert: ChatStop mock was called exactly once
  end)
  it("does NOT remap <Esc> in insert mode", function()
    -- Assert: normal vim insert-mode <Esc> still exits to normal mode
  end)
  it("respects chat_shortcut_stop_esc = false to disable", function()
    -- Re-setup with flag false; <Esc> in normal mode should not trigger stop
  end)
end)
```

- [ ] **Step 6.1.2: Run, verify fail**

- [ ] **Step 6.1.3: Implement**

```lua
if cfg.chat_shortcut_stop_esc ~= false then
  vim.keymap.set("n", "<Esc>", function()
    vim.cmd(cfg.cmd_prefix .. "ChatStop")
  end, { buffer = bufnr, desc = "Parley: stop response (chat buffer)" })
end
```

- [ ] **Step 6.1.4: Run, verify pass**
- [ ] **Step 6.1.5: Commit**

```bash
git commit -m "feat(chat): <Esc> in normal mode triggers ChatStop (buffer-local)"
```

### Task 6.2: Case 1 — partial streaming tool_use drop

**Files:**
- Modify: `lua/parley/tool_loop.lua` — add `cleanup_after_cancel(bufnr)`
- Modify: `lua/parley/chat_respond.lua` — wire cleanup into the cancel path
- Test: `tests/unit/tool_loop_cancel_cleanup_spec.lua`

**Precise "partial" definition (pinned):** A `🔧:` block is "partial" if and only if: starting from the `🔧:` prefix line to the end of the buffer, there is no line consisting solely of a closing fence (matching any opening fence length `>= 3`) that closes the opening fence of that block.

Concretely the algorithm walks the buffer tail backwards looking for `🔧:`. For the latest `🔧:`:
1. Scan forward from `🔧:` looking for the first opening fence line. An **opening fence** line matches `^(`+)[%w_-]*%s*$` — a run of 3+ backticks followed by an optional info string (e.g. `json`). We capture the backtick run length.
2. During that scan, if we encounter another prefix line (`📎:`, `💬:`, `🤖:`, `🧠:`) BEFORE finding an opening fence → **partial (header-only, fence never started)** → drop the entire `🔧:` region. (Guard exists because the model may emit the prefix line and then never stream JSON.)
3. If we reach end of buffer without finding an opening fence → **partial (fence never started)** → drop the entire `🔧:` region.
4. Otherwise, record the opening fence length. Scan forward looking for a **closing fence** line — a line consisting ONLY of exactly that number of backticks (no info string), matched by `^<same-length-backticks>$`.
5. If no matching closing fence found before end of buffer → **partial (fence unclosed)** → drop the entire `🔧:` region.
6. Otherwise → the block is complete; proceed to Case 2 (synthesize `📎:` for unmatched complete tool_use).

- [ ] **Step 6.2.1: Write failing tests**

```lua
describe("tool_loop.cleanup_after_cancel — Case 1 partial JSON", function()
  it("drops a partial 🔧: with no opening fence", function()
    -- Buffer ends with literal line '🔧: read_file id=toolu_01' and no fence.
    -- cleanup_after_cancel should remove that line.
    -- assert_buffer_reparsable(bufnr) must pass.
  end)
  it("drops a partial 🔧: with opening fence but incomplete JSON body", function()
    -- Buffer ends with:
    --   🔧: read_file id=toolu_01
    --   ```json
    --   {"pat
    -- cleanup_after_cancel should remove all three lines.
  end)
  it("drops a partial 🔧: with opening fence but no closing fence", function()
    -- Buffer ends with:
    --   🔧: read_file id=toolu_01
    --   ```json
    --   {"path":"foo"}
    -- (missing closing ```)
    -- cleanup_after_cancel should remove all three lines.
  end)
  it("leaves a complete 🔧: alone (delegates to Case 2)", function()
    -- Buffer ends with a complete 🔧: block; cleanup_after_cancel should
    -- NOT drop it. Case 2 (Task 6.3) handles the synthetic 📎:.
  end)
  it("preserves preceding assistant text", function()
    -- Buffer: text + partial 🔧:. After cleanup, text remains.
  end)
end)
```

- [ ] **Step 6.2.2: Run, verify fail**

- [ ] **Step 6.2.3: Implement `cleanup_after_cancel` Case 1 branch**

```lua
function M.cleanup_after_cancel(bufnr, reason)
  reason = reason or "user"
  M._drop_partial_tool_use(bufnr)
  M._synthesize_cancelled_for_unmatched(bufnr, reason)
end

-- Case 1: drop an incomplete 🔧: at the buffer tail.
-- Opening fence is `^(`+)[%w_-]*%s*$` — 3+ backticks followed by optional info string.
-- Closing fence must be the SAME backtick count with NO info string: `^<exactly-N-backticks>$`.
-- This handles ```json opening fences (the format render_call actually emits).
function M._drop_partial_tool_use(bufnr)
  local use_prefix = vim.g.parley_chat_tool_use_prefix or "🔧:"
  local result_prefix = vim.g.parley_chat_tool_result_prefix or "📎:"
  local total = vim.api.nvim_buf_line_count(bufnr)

  local function line_at(i)
    return vim.api.nvim_buf_get_lines(bufnr, i - 1, i, false)[1] or ""
  end

  -- Find last 🔧: line
  local tool_line = nil
  for i = total, 1, -1 do
    if line_at(i):sub(1, #use_prefix) == use_prefix then
      tool_line = i
      break
    end
  end
  if not tool_line then return end

  -- Scan forward looking for an opening fence. Bail out if we hit another
  -- prefix line first (partial — header only).
  local open_len, open_line = nil, nil
  for i = tool_line + 1, total do
    local line = line_at(i)
    -- Opening fence: 3+ backticks followed by optional info string (e.g. "json")
    local fence = line:match("^(`+)[%w_%-]*%s*$")
    if fence and #fence >= 3 then
      open_len = #fence
      open_line = i
      break
    end
    -- If we hit any other known prefix, tool_line is header-only — drop
    if line:sub(1, #result_prefix) == result_prefix
       or line:match("^💬:") or line:match("^🤖:") or line:match("^🧠:") then
      vim.api.nvim_buf_set_lines(bufnr, tool_line - 1, total, false, {})
      return
    end
  end
  if not open_line then
    -- No opening fence at all → partial; drop from tool_line to end
    vim.api.nvim_buf_set_lines(bufnr, tool_line - 1, total, false, {})
    return
  end

  -- Find matching closing fence of same length and NO info string
  local expected_close = string.rep("`", open_len)
  local close_line = nil
  for i = open_line + 1, total do
    if line_at(i) == expected_close then
      close_line = i
      break
    end
  end
  if not close_line then
    -- Fence unclosed → partial; drop from tool_line to end
    vim.api.nvim_buf_set_lines(bufnr, tool_line - 1, total, false, {})
  end
  -- Else: block is complete; Case 2 will handle it.
end
```

**Test case for info-string fence:** add to Step 6.2.1:

```lua
it("recognizes ```json opening fence as valid (info string)", function()
  -- Complete 🔧: with ```json fence — must NOT be dropped
  local bufnr = build_buf({
    "💬: test",
    "🤖: [Claude]",
    "🔧: read_file id=toolu_01",
    "```json",
    '{"path":"foo"}',
    "```",
  })
  require("parley.tool_loop")._drop_partial_tool_use(bufnr)
  local lines = vim.api.nvim_buf_line_count(bufnr)
  assert.equals(6, lines) -- nothing dropped
end)

it("drops a partial 🔧: with ```json opening but no closing fence", function()
  local bufnr = build_buf({
    "💬: test",
    "🤖: [Claude]",
    "🔧: read_file id=toolu_01",
    "```json",
    '{"pat',
  })
  require("parley.tool_loop")._drop_partial_tool_use(bufnr)
  local total = vim.api.nvim_buf_line_count(bufnr)
  assert.equals(2, total) -- only 💬: and 🤖: remain
end)
```

- [ ] **Step 6.2.4: Run, verify pass**
- [ ] **Step 6.2.5: Commit**

```bash
git commit -m "feat(tool_loop): cancel Case 1 — drop partial 🔧: block at buffer tail"
```

### Task 6.3: Case 2/3 — synthetic `(cancelled by user)` for unmatched complete 🔧:

**Files:**
- Modify: `lua/parley/tool_loop.lua` — add `_synthesize_cancelled_for_unmatched` using `lua/parley/tools/synthetic.lua` from M4 Task 4.1
- Test: extend `tests/unit/tool_loop_cancel_cleanup_spec.lua`

**Depends on:** M4 Task 4.1 landing `lua/parley/tools/synthetic.lua`. No re-factoring — this task is a CONSUMER of the helper, not its introduction. (The M6-ordering issue from the review is fixed by landing the helper in M4 first.)

- [ ] **Step 6.3.1: Write failing tests**

```lua
describe("tool_loop.cleanup_after_cancel — Case 2 unmatched complete 🔧:", function()
  it("synthesizes 📎: (cancelled by user) for one complete unmatched 🔧:", function()
    -- Buffer ends with a complete 🔧: read_file block, no 📎: after it
    local bufnr = build_buf_with_complete_unmatched_tool_use()
    require("parley.tool_loop").cleanup_after_cancel(bufnr, "user")
    assert_buffer_reparsable(bufnr)
    -- Also assert the specific synthetic message
    local last_line = vim.api.nvim_buf_get_lines(bufnr, -2, -1, false)[1]
    assert.matches("^```$", last_line) -- closing fence of synthetic 📎:
  end)
  it("synthesizes one 📎: per unmatched 🔧: in buffer order", function()
    -- Buffer has 2 complete 🔧: blocks with no 📎:
    -- Assert: 2 synthetic 📎: blocks appear, with ids matching the 🔧: ids
  end)
  it("does nothing when all 🔧: already have matching 📎:", function()
    -- Buffer is already balanced; cleanup is a no-op
  end)
  it("is idempotent (second call does nothing)", function() ... end)
end)
```

- [ ] **Step 6.3.2: Run, verify fail**

- [ ] **Step 6.3.3: Implement**

```lua
function M._synthesize_cancelled_for_unmatched(bufnr, reason)
  require("parley.tools.synthetic").synthesize_for_unmatched(bufnr, reason or "user")
end
```

That's literally it — all the heavy lifting is in `synthetic.synthesize_for_unmatched` landed in Task 4.1. This is the DRY payoff.

- [ ] **Step 6.3.4: Wire cleanup_after_cancel into the cancel code path**

In `chat_respond.lua`, wherever `ChatStop` or the existing cancel handler fires, call:
```lua
require("parley.tool_loop").cleanup_after_cancel(bufnr, "user")
```
BEFORE doing any other cleanup, so the buffer is in a reparsable state regardless of what the rest of the cancel path does.

- [ ] **Step 6.3.5: Run, verify pass**
- [ ] **Step 6.3.6: Commit**

```bash
git commit -m "feat(tool_loop): cancel Case 2/3 — synthesize (cancelled by user) for unmatched 🔧:"
```

### Task 6.4: Case 4 — drop partial assistant text after completed roundtrips

Case 4 is when the user cancels during a streaming assistant text response AFTER one or more completed roundtrips. The existing `<C-g>x` behavior already truncates partial text. This task verifies that integration and adds a regression test.

**Files:**
- Test: extend `tests/integration/tool_loop_spec.lua`

- [ ] **Step 6.4.1: Write failing test**

```lua
it("Case 4: multi-roundtrip chat, cancel during partial assistant text", function()
  -- Mock provider:
  --   Call 1: tool_use for read_file → complete
  --   Call 2: tool_use for read_file → complete
  --   Call 3: partial assistant text "Based on the files I read, the answer..."
  --           (cancel before stream completes)
  -- After cancel:
  --   - Both completed roundtrips (pairs of 🔧:/📎:) are intact
  --   - Partial assistant text is dropped (or truncated to only what was committed)
  --   - assert_buffer_reparsable passes
end)
```

- [ ] **Step 6.4.2: Run** — if it passes, the existing cancel path already handles it. Commit a comment-only change noting the regression lock. If it fails, extend `cleanup_after_cancel` with a Case 4 branch (likely trivial — just ensure the last assistant content block is valid).

- [ ] **Step 6.4.3: Commit**

```bash
git commit -m "test(tool_loop): regression lock for Case 4 cancel during partial text"
```

### Task 6.5: (Removed — helper now lives in M4 Task 4.1)

The `cancelled_result_for` helper and `synthesize_for_unmatched` helper landed in M4 Task 4.1 (`lua/parley/tools/synthetic.lua`). M6 is a consumer, not a factoring pass. This task exists as a marker so the plan sequence is unambiguous.

- [ ] **Step 6.5.1: Verify both M4 (iteration cap) and M6 (cancellation) call the same helper**

Grep the codebase: every `(cancelled by user)` and `(iteration limit reached)` string should ONLY appear in `lua/parley/tools/synthetic.lua`. If either appears anywhere else, consolidate. DRY assertion.

```bash
rg "cancelled by user|iteration limit reached" lua/
# Expected: only matches in lua/parley/tools/synthetic.lua
```

- [ ] **Step 6.5.2: Commit any consolidation**

### Task 6.6: Stage-6 manual verification

Per Stage 6 in issue #81.

- [ ] Run each of the four cases (1-4) manually in a live Neovim session.
- [ ] For each case, immediately `<C-g><C-g>` (resubmit) and confirm no Anthropic validation error.
- [ ] Mark Stage 6 boxes in the issue. Add log entry.
- [ ] Commit issue updates.

### Task 6.7: M6 post-milestone code review gate

**Mandatory.** `BASE_SHA` = M5 close commit. `WHAT_WAS_IMPLEMENTED` = "M6 — cancellation hardening for all 4 cases. `<Esc>` buffer-local keymap, partial JSON drop via dynamic-fence regex, synthetic `(cancelled by user)` results via `lua/parley/tools/synthetic.lua` (shared with M4 iteration-cap)". Emphasize: the buffer-reparsable invariant MUST hold after any cancel path, the `^(`+)[%w_%-]*%s*$` opening-fence regex handles info-string fences correctly, `cleanup_after_cancel` walks the buffer tail correctly, and the M6 tests use `assert_buffer_reparsable` helper consistently.

- [ ] Dispatch review, address issues, log outcome, commit.

### M7 — Buffer-is-state invariants

**Note:** Task 7.1 is a *safety net* for user hand-edits. It is NOT a substitute for the M6 cancel-cleanup correctness — cancel paths MUST leave the buffer reparsable on their own. Do not weaken M6 because M7 exists.

### Task 7.1: Parser diagnostic for unmatched `🔧:` / `📎:`

**Files:**
- Modify: `lua/parley/chat_parser.lua` — emit a `diagnostics` field on the parse result
- Modify: `lua/parley/chat_respond.lua` — check diagnostics before calling provider; abort on unmatched tool_use
- Test: `tests/unit/chat_parser_tool_diagnostics_spec.lua`

- [ ] **Step 7.1.1: Write failing test**

```lua
describe("chat_parser tool diagnostics", function()
  it("flags unmatched 🔧: in the latest answer", function()
    -- Buffer with a 🔧: and no matching 📎:
    local parsed = parser.parse(bufnr)
    assert.is_table(parsed.diagnostics)
    assert.equals(1, #parsed.diagnostics)
    assert.matches("tool_use without matching tool_result", parsed.diagnostics[1].message)
    assert.matches("toolu_%w+", parsed.diagnostics[1].id)
  end)
  it("flags orphan 📎: (tool_result without matching tool_use)", function()
    -- Buffer with a 📎: and no matching 🔧:
    local parsed = parser.parse(bufnr)
    assert.equals(1, #parsed.diagnostics)
    assert.matches("tool_result without matching tool_use", parsed.diagnostics[1].message)
  end)
  it("has no diagnostics on well-formed buffer", function()
    local parsed = parser.parse(bufnr)
    assert.same({}, parsed.diagnostics)
  end)
end)

describe("chat_respond refuses to submit with diagnostics", function()
  it("shows a message and aborts when diagnostics present", function()
    -- Build buffer with unmatched 🔧:, trigger chat_respond
    -- Assert: provider was NOT called, buffer contains warning message
  end)
end)
```

- [ ] **Step 7.1.2: Run, verify fail**

- [ ] **Step 7.1.3: Implement parser diagnostics (symmetric)**

In `chat_parser.lua`, track tool_use / tool_result ids per answer. At answer finalization:
- Any `tool_use` id without a matching `tool_result` id → diagnostic `"tool_use without matching tool_result: <id>"`
- Any `tool_result` id without a matching `tool_use` id → diagnostic `"tool_result without matching tool_use: <id>"`

Both directions are flagged for symmetry so Task 7.2's "delete 🔧: leaving orphan 📎:" test has a diagnostic to fire against.

- [ ] **Step 7.1.4: Implement chat_respond diagnostic gate**

Before calling `dispatcher.query`, call `parser.parse(bufnr)`, check `parsed.diagnostics`. If non-empty, append a warning to the buffer (`🔒: parley: cannot submit — <count> unmatched tool_use. Fix manually or cancel.`) and return early.

- [ ] **Step 7.1.5: Run, verify pass**
- [ ] **Step 7.1.6: Commit**

```bash
git commit -m "feat(parser): diagnostic for unmatched 🔧: (safety net for hand-edits)"
```

### Task 7.2: Manual-edit survivability tests

**Files:**
- Test: `tests/integration/tool_manual_edit_spec.lua`

- [ ] **Step 7.2.1: Write failing tests**

```lua
describe("manual buffer edits propagate to payload", function()
  it("editing a 📎: body changes what the LLM sees on next submit", function()
    -- Build buffer with a completed tool roundtrip.
    -- Manually replace the 📎: body with "FAKE CONTENT XYZ".
    -- Capture the outgoing payload on next submit (mock dispatcher).
    -- Assert: payload's user message tool_result content contains "FAKE CONTENT XYZ".
  end)
  it("editing a 🔧: input JSON changes what the LLM sees on next submit", function()
    -- Edit input JSON from {"path":"foo"} to {"path":"BAR"}, resubmit,
    -- assert payload contains input.path == "BAR".
  end)
  it("deleting a 🔧: while leaving its 📎: produces a diagnostic (Task 7.1)", function()
    -- This is the dual of the 7.1 test — orphan tool_result, not orphan tool_use.
    -- Decision: orphan 📎: is also flagged as a diagnostic (symmetric safety).
  end)
end)
```

- [ ] **Step 7.2.2: Run, verify fail on any test that finds gaps**
- [ ] **Step 7.2.3: Fix any gaps found**
- [ ] **Step 7.2.4: Commit**

```bash
git commit -m "test(chat): manual-edit survivability for 🔧:/📎: blocks"
```

### Task 7.3: Stage-7 manual verification

- [ ] Run all three Stage 7 checks in issue #81 manually.
- [ ] Mark Stage 7 boxes. Add log entry.
- [ ] Commit issue updates.

### Task 7.4: M7 post-milestone code review gate

**Mandatory.** `BASE_SHA` = M6 close commit. `WHAT_WAS_IMPLEMENTED` = "M7 — parser diagnostics for unmatched `🔧:` / `📎:` (symmetric: both orphan tool_use and orphan tool_result flagged), chat_respond refuses to submit when diagnostics present, manual-edit survivability tests". Emphasize: M7 is a SAFETY NET for user hand-edits, NOT a substitute for M6 cancel-cleanup correctness; the diagnostic gate at submit time must not regress the "transcript IS state" invariant.

- [ ] Dispatch review, address issues, log outcome, commit.

### M8 — UX polish

### Task 8.1: Syntax highlighting for `🔧:` / `📎:`

**Files:**
- Modify: `lua/parley/highlighter.lua`
- Test: `tests/integration/tool_highlight_spec.lua`

- [ ] **Step 8.1.1: Write failing test**

```lua
describe("tool prefix highlighting", function()
  it("defines ParleyToolUse and ParleyToolResult hl groups", function()
    require("parley.highlighter").setup()
    assert.is_not_nil(vim.api.nvim_get_hl(0, { name = "ParleyToolUse" }))
    assert.is_not_nil(vim.api.nvim_get_hl(0, { name = "ParleyToolResult" }))
  end)
  it("applies the groups to 🔧:/📎: lines in chat buffers", function()
    -- Open a chat buffer with tool blocks, check the highlight namespace
    -- over the prefix lines.
  end)
end)
```

- [ ] **Step 8.1.2: Run, verify fail**

- [ ] **Step 8.1.3: Implement**

Add two new hl groups in `highlighter.lua` linked to sensible defaults (`ParleyToolUse → Keyword`, `ParleyToolResult → String`). Match pattern: lines starting with `chat_tool_use_prefix` or `chat_tool_result_prefix`.

- [ ] **Step 8.1.4: Run, verify pass**
- [ ] **Step 8.1.5: Commit**

```bash
git commit -m "feat(highlighter): syntax highlighting for 🔧:/📎: prefixes"
```

### Task 8.2: Outline navigation includes tool components

**Files:**
- Modify: `lua/parley/outline.lua`
- Test: `tests/unit/outline_tool_entries_spec.lua`

- [ ] **Step 8.2.1: Write failing test**

```lua
describe("outline includes tool components", function()
  it("adds one entry per 🔧: block, showing tool name", function()
    -- Build buffer with 2 exchanges, each with 1 tool_use
    -- Build outline; expect at least 2 tool entries labeled with the tool names
  end)
end)
```

- [ ] **Step 8.2.2: Run, verify fail**
- [ ] **Step 8.2.3: Implement** — extend outline's entry collector to include `🔧:` components as sub-entries of their exchange.
- [ ] **Step 8.2.4: Run, verify pass**
- [ ] **Step 8.2.5: Commit**

```bash
git commit -m "feat(outline): include 🔧: entries in outline navigation"
```

### Task 8.3: Agent picker `[🔧]` badge polish

Already landed in Task 1.7. This is a verification pass only.

- [ ] **Step 8.3.1: Verify the badge renders correctly with the final `ClaudeAgentTools` shipped in M1 Task 1.4.**
- [ ] **Step 8.3.2: If any visual tweaks needed (spacing, color), apply and commit.**

### Task 8.4: Lualine indicator polish

Already landed in Task 4.2. Verification pass.

- [ ] **Step 8.4.1: Verify the indicator updates smoothly in a real Neovim session with a multi-round loop.**
- [ ] **Step 8.4.2: If flicker / stale state issues, adjust and commit.**

### Task 8.5: Stage-8 manual verification

- [ ] Run all 5 Stage 8 checks in issue #81 manually.
- [ ] Mark Stage 8 boxes. Add log entry.
- [ ] Commit issue updates.

### Task 8.6: M8 post-milestone code review gate

**Mandatory.** `BASE_SHA` = M7 close commit. `WHAT_WAS_IMPLEMENTED` = "M8 — UX polish: syntax highlighting for `🔧:` / `📎:`, outline navigation entries for tool components, picker/lualine indicator polish". Lightweight review scope because M8 is pure UI polish with no new correctness invariants.

- [ ] Dispatch review, address issues, log outcome, commit.

### M9 — Regression lockdown

### Task 9.1: Full `make lint` pass

- [ ] Run `make lint`. Fix all warnings surfaced in new code.
- [ ] Commit lint fixes.

### Task 9.2: Full `make test` pass

- [ ] Run `make test`. All existing + new tests pass.
- [ ] If any pre-existing test breaks, STOP and diagnose. No regressions allowed.

### Task 9.3: Byte-identical vanilla chat check

**Prerequisite:** Task 1.0 (pre-M1 baseline capture) must have landed 3 fixture files at `tests/fixtures/pre_81_vanilla_claude_request_{1,2,3}.json` and a prompts file at `tests/fixtures/pre_81_vanilla_claude_prompts.lua`. If these are missing, STOP and go back to capture them from the last pre-#81 commit (`git checkout <pre-M1-sha> -- scripts/ && replay fixtures`). Do NOT skip this check.

- [ ] **Step 9.3.1: Replay the 3 baseline prompts on post-#81 code**

1. Ensure you are on the #81 implementation branch with all M1-M8 landed.
2. Load the prompts from `tests/fixtures/pre_81_vanilla_claude_prompts.lua`.
3. For each prompt: start a new vanilla chat (use a non-tools Claude agent, NOT `ClaudeAgentTools`). Send the prompt. Capture the resulting query JSON from `vim.fn.stdpath("cache") .. "/parley/query/"`. Save as `tests/fixtures/post_81_vanilla_claude_request_{1,2,3}.json`.

- [ ] **Step 9.3.2: Diff each pair**

```bash
for i in 1 2 3; do
  diff -u tests/fixtures/pre_81_vanilla_claude_request_$i.json \
          tests/fixtures/post_81_vanilla_claude_request_$i.json || exit 1
done
```

**Expected:** diff is EMPTY for all three pairs. Vanilla Anthropic requests contain no timestamp fields at the request level (the `x-api-key` and request ID are headers, not body), so the body JSON must match byte-for-byte.

If the diff is non-empty, STOP. The regression is real — vanilla chat behavior has changed, which violates the scope fence. Investigate and fix before continuing.

- [ ] **Step 9.3.3: Commit the post-fixtures for future re-verification**

```bash
git add tests/fixtures/post_81_vanilla_claude_request_*.json
git commit -m "test(81): post-#81 vanilla Claude byte-identity confirmed"
```

### Task 9.4: Brief sketch at `specs/providers/tool_use.md`

Per parley convention (`specs/` is a sketch, detail lives in the issue). Short file:

```markdown
# Tool Use

Client-side tool-use loop: Claude (Anthropic only in v1) calls filesystem tools,
parley executes them, feeds results back. Full design in [issue #81's Spec section](../../issues/000081-support-anthropic-tool-use-protocol.md).

## Buffer representation
`🔧:` tool_use, `📎:` tool_result, auto-folded, toggle with `<C-g>b`.

## Tools (v1 builtins)
read_file, list_dir, grep, glob, edit_file, write_file — cwd-scoped,
dirty-buffer-protected, `write_file` captures `<path>.parley-backup`.

## Enablement
Per-agent `tools = { ... }` field. See `lua/parley/config.lua` for the
`ClaudeAgentTools` sample.

## Related
- [#82 CLAUDE.md constitution](../../issues/000082-claude-md-constitution-file.md)
- [#83 skill system](../../issues/000083-skill-system.md)
- [#84 transcript-driven reconciliation](../../issues/000084-transcript-driven-filesystem-reconciliation.md)
- [#85 file reference freshness](../../issues/000085-file-reference-freshness.md)
```

- [ ] Add entry to `specs/index.md` under "LLM Providers & Agents" section.
- [ ] Commit.

### Task 9.5: M9 final full-issue code review gate

**Mandatory final review** — the whole of #81 in one pass, not just M9. `BASE_SHA` = the commit immediately before Task 1.0 baseline capture (the pre-#81 boundary). `HEAD_SHA` = current HEAD after Task 9.4. `WHAT_WAS_IMPLEMENTED` = "Full Anthropic tool use protocol implementation, M1-M9 complete". Include a summary table of each milestone's scope and cite the per-milestone review commits as prior art. This is the last gate before closing the issue.

- [ ] Dispatch review, address Critical and Important issues (any that slipped past per-milestone reviews), log outcome, commit.

### Task 9.6: Close issue #81

- [ ] Mark all `## Done when` items in `issues/000081-*.md` as checked.
- [ ] Final log entry summarizing implementation.
- [ ] Flip frontmatter `status` from `working` to `done`.
- [ ] Commit.

```bash
git commit -m "docs(81): M9 complete, close issue

All 9 manual test stages passed. Spec sketch added to
specs/providers/tool_use.md. Ready for follow-up work on #82/#83/#84/#85.

Co-Authored-By: Claude Opus 4.6 (1M context) <noreply@anthropic.com>"
```

---

## Execution notes

- **Frequent commits.** Every passing TDD cycle is a commit. The plan is explicit about this because this feature spans many files and a long timeline; small commits make bisecting feasible.
- **Issue file is ground truth for progress.** After each milestone, update `issues/000081-*.md` `## Plan` (check milestone box, check stage-N manual items) and add a `## Log` entry. This is required per AGENTS.md ("Write out your thinking to the `issues/` file you are working on often to preserve your design state").
- **Tasks/lessons.md.** Any mistake that required a re-plan → add a rule to `tasks/lessons.md` per AGENTS.md rule §3.
- **Subagent dispatch.** Long tasks (streaming decoder, chat_respond loop driver) should use Explore subagents for initial codebase reconnaissance. Keep main context clean.
- **When in doubt, re-read the spec.** The `## Spec` section of issue #81 is the contract. This plan is the recipe. If plan and spec disagree, the spec wins — update the plan.
