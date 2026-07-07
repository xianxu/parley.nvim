# Inline Term Definition Implementation Plan

> **For agentic workers:** Consult AGENTS.md Section 3 (Subagent Strategy) to determine the appropriate execution approach: use superpowers-subagent-driven-development (if subagents are suitable per AGENTS.md) or superpowers-executing-plans to implement this plan. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Let a user visually select a phrase in a parley chat, press `<M-CR>`, and get a concise context-aware definition rendered as an ephemeral inline diagnostic under the phrase — nothing written to the transcript.

**Architecture:** A pure core (`lua/parley/define.lua`: selection slice, context window, message formatter) plus a thin IO shell in `init.lua` (`define_visual`, `render_definition`). The agent call reuses the existing `skill_invoke` driver with a new auto-discovered `define` skill and a new `emit_definition` structured-output tool (unforced, so the server-side `web_search` tool can still run when `:ToggleWebSearch` is on). Two small `skill_invoke` seams are added: `opts.no_reload` (don't save/reload the chat buffer for a read-only lookup) and use of the existing `opts.document` (send the enclosing exchange, not the whole buffer). Rendering reuses `diag_display`'s cursor-region `virtual_lines` on the shared `parley_skill` diagnostic namespace.

**Tech Stack:** Lua, Neovim API (`vim.diagnostic`, `getpos`, extmarks via `diag_display`), plenary.nvim busted tests, parley's `skill_invoke`/`skill_assembly`/`skill_render`/`tools` subsystem, Anthropic provider (server-side web tools).

**Spec:** `workshop/issues/000161-inline-term-definition.md`

---

## Core concepts

### Pure entities (the conceptual core)

| Name | Lives in | Status |
|------|----------|--------|
| `slice_selection` | `lua/parley/define.lua` | new |
| `context_for_selection` | `lua/parley/define.lua` | new |
| `format_definition` | `lua/parley/define.lua` | new |
| `define.source` (skill system-prompt builder) | `lua/parley/skills/define/init.lua` | new |

- **`slice_selection(lines, l1, c1, l2, c2) → text`** — extract the visually-selected substring from a `lines` array given 1-based start/end line + 0-based byte columns (charwise-visual semantics; clamps columns to line length; joins multi-line selections with `\n`).
  - **Relationships:** stateless; consumes a plain lines array (no buffer handle).
  - **DRY rationale:** `drill_in_visual` (`init.lua:1537-1564`) currently extracts a visual selection inline; this is the shared pure form. Task 9 refactors `drill_in_visual` onto it so there is one slice implementation (ARCH-DRY).
  - **Future extensions:** blockwise-visual (`<C-v>`) support if ever needed (add a `mode` arg).

- **`context_for_selection(parsed_chat, sel_line, all_lines) → string`** — the bounded context sent to the model: the line range of the *enclosing exchange* of `sel_line`, else the whole buffer.
  - **Relationships:** consumes a `parse_chat`-shaped table `{ exchanges = { { question = {line_start,line_end}, answer = {line_start,line_end}|nil }, … } }` plus the raw `all_lines`. Returns joined text.
  - **DRY rationale:** reuses parley's existing `parse_chat` + `find_exchange_at_line` (`init.lua:3077,3082`) rather than a new paragraph heuristic. Pure so it is testable with a synthetic `parsed_chat` (no real parser, no buffer).
  - **Future extensions:** widen to N exchanges of context, or a token budget.

- **`format_definition(term, definition, width) → string`** — compose the diagnostic message (`"TERM — definition"`), hard-wrapped to `width`.
  - **Relationships:** pure; delegates wrapping to `skill_render.wrap` (already pure, `skill_render.lua:52-74`) or reimplements the same wrap contract if avoiding the dependency in a `tests/unit` file.
  - **DRY rationale:** reuse `skill_render.wrap` — the review path already wraps diagnostic text to window width.
  - **Future extensions:** include a source/citation line when web_search was used.

- **`define.source(ctx) → string`** — builds the skill's system prompt, folding `ctx.args.phrase` in. Pure string builder (the review skill's `source(ctx)` is the model, `review/init.lua`).
  - **Relationships:** receives `ctx = { args = { phrase }, … }` from `skill_invoke` (`skill_invoke.lua:144`).
  - **DRY rationale:** same `source(ctx)` seam the skill system already defines; no new mechanism.

### Integration points (where pure meets the world)

| Name | Lives in | Status | Wraps |
|------|----------|--------|-------|
| `define_visual` | `lua/parley/init.lua` | new | vim visual mode + `skill_invoke` |
| `render_definition` (on_done) | `lua/parley/init.lua` | new | `vim.diagnostic` |
| `emit_definition` tool | `lua/parley/tools/builtin/emit_definition.lua` | new | LLM tool_use |
| `BUILTIN_NAMES` registration | `lua/parley/tools/init.lua` | modified | tool registry |
| `define` skill dir | `lua/parley/skills/define/init.lua` | new | skill registry / `skill_invoke` |
| `skill_invoke` opts (`no_reload`, `document`) | `lua/parley/skill_invoke.lua` | modified | buffer write/reload + user message |
| `chat_shortcut_define` keybinding | `lua/parley/config.lua`, `lua/parley/keybinding_registry.lua`, `lua/parley/init.lua` | new/modified | vim keymaps |

- **`define_visual(buf)`** — reads the visual selection (`getpos("'<"/"'>")`), guards empty/whitespace-only (mirror `init.lua:1566-1569`), builds context via the pure helpers, calls `skill_invoke.invoke(buf, manifest, {phrase}, {document, on_done=render_definition, no_reload=true})`, then parks the cursor on the selection's first line.
  - **Injected into:** nothing; it is the top thin caller. All logic it needs is in the pure helpers so it stays trivial.
  - **Future extensions:** a normal-mode variant (`<word>` under cursor).

- **`render_definition`** — the `on_done` callback: guards `#calls == 0`, else reads `result.calls[1].input = {term, definition}`, `format_definition`s it, and `vim.diagnostic.set(skill_render.diag_namespace(), buf, {…})` at the selection line range; nudges a redraw so `diag_display` reveals it immediately.
  - **Injected into:** passed to `skill_invoke.invoke` as `opts.on_done`.

- **`emit_definition` tool** — output-only structured tool `{term, definition}`, `self_paginates = true`, no-op `execute`. Registered in `BUILTIN_NAMES`.
  - **Future extensions:** an optional `confidence`/`source` field.

- **`define` skill** — manifest `{name, description, scope, activation={manual=true}, tools={"emit_definition"}, source}` — **no `force_tool`**, no `SKILL.md` (source owns the prompt). Auto-discovered by the disk provider (`skill_providers.lua:95`).

- **`skill_invoke` opts** — `opts.no_reload` gates the pre-query `silent write` (`skill_invoke.lua:133-137`) and the on-exit `:edit!` reload (`:230`); `document = opts.document or original` at the invoke call-site (`:~152`). `build_invocation` already consumes `document` (`skill_assembly.lua:43`) — no change there.

- **`chat_shortcut_define` keybinding** — pull `<M-CR>` out of `chat_shortcut_respond` into its own registry entry with a per-mode callback `{n=respond, i=respond, v=define_visual, x=define_visual}` (registry supports per-mode callback tables, `keybinding_registry.lua:1072-1085`).

**Test surface.** Pure entities → `tests/unit/define_spec.lua` (no Neovim APIs beyond plain tables/strings). Integration (`skill_invoke` fake exchange, diagnostic placement, no-write, registration, web-toggle payload) → `tests/integration/define_spec.lua`, reusing the process-level fake pattern from `tests/integration/skill_invoke_review_spec.lua`.

---

## Chunk 1: Pure core + agent plumbing + wiring

### Task 1: `slice_selection` (pure)

**Files:**
- Create: `lua/parley/define.lua`
- Test: `tests/unit/define_spec.lua`

- [ ] **Step 1: Write the failing test**

```lua
-- tests/unit/define_spec.lua
local define = require("parley.define")

describe("define.slice_selection", function()
  local lines = { "the quick brown", "fox jumps over", "the lazy dog" }

  it("extracts a single-line span (0-based end-exclusive col2+1 inclusive)", function()
    -- select "quick" on line 1: cols [4,8]
    assert.equals("quick", define.slice_selection(lines, 1, 4, 1, 8))
  end)

  it("extracts a multi-line span joined with newline", function()
    -- "brown" .. "\n" .. "fox"
    assert.equals("brown\nfox", define.slice_selection(lines, 1, 10, 2, 2))
  end)

  it("clamps an end column past line length", function()
    assert.equals("dog", define.slice_selection(lines, 3, 9, 3, 999))
  end)

  it("returns empty string for a reversed/empty span", function()
    assert.equals("", define.slice_selection(lines, 1, 5, 1, 4))
  end)
end)
```

- [ ] **Step 2: Run test to verify it fails**

Run: `make test-unit` (or the single file: `nvim -n --headless --noplugin -u tests/minimal_init.vim -c "PlenaryBustedFile tests/unit/define_spec.lua" -c "qa!"`)
Expected: FAIL — `module 'parley.define' not found`.

- [ ] **Step 3: Write minimal implementation**

```lua
-- lua/parley/define.lua
local M = {}

-- Extract the charwise-visual selection [l1,c1]..[l2,c2] from `lines`.
-- l1/l2 are 1-based line numbers; c1/c2 are 0-based byte columns where c2 is
-- the *inclusive* end column (Neovim getpos "'>" convention). Multi-line spans
-- join with "\n". Columns clamp to line length; a reversed span → "".
function M.slice_selection(lines, l1, c1, l2, c2)
  if l1 > l2 or (l1 == l2 and c1 > c2) then return "" end
  if l1 == l2 then
    local line = lines[l1] or ""
    return line:sub(c1 + 1, math.min(c2 + 1, #line))
  end
  local out = {}
  for l = l1, l2 do
    local line = lines[l] or ""
    if l == l1 then
      out[#out + 1] = line:sub(c1 + 1)
    elseif l == l2 then
      out[#out + 1] = line:sub(1, math.min(c2 + 1, #line))
    else
      out[#out + 1] = line
    end
  end
  return table.concat(out, "\n")
end

return M
```

- [ ] **Step 4: Run test to verify it passes**

Run: `make test-unit`
Expected: PASS (the 4 `slice_selection` cases).

> **Implementer note:** confirm the `getpos("'>")` column convention on this Neovim build (byte col, 1-based from getpos → subtract 1 to reach the 0-based `c`; the *inclusive* end may need `+1` for multibyte/`selection=exclusive`). The test encodes the intended contract; adjust `define_visual` (Task 7) to feed columns in this convention, not the helper.

- [ ] **Step 5: Commit**

```bash
git add lua/parley/define.lua tests/unit/define_spec.lua
git commit -m "#161: define.slice_selection — pure visual-selection extractor"
```

### Task 2: `context_for_selection` (pure)

**Files:**
- Modify: `lua/parley/define.lua`
- Test: `tests/unit/define_spec.lua`

- [ ] **Step 1: Write the failing test**

```lua
describe("define.context_for_selection", function()
  local all_lines = {}
  for i = 1, 20 do all_lines[i] = "line " .. i end
  local parsed = {
    exchanges = {
      { question = { line_start = 3, line_end = 4 }, answer = { line_start = 5, line_end = 8 } },
      { question = { line_start = 10, line_end = 10 }, answer = nil },
    },
  }
  -- fake find_exchange_at_line: returns idx if sel_line in [q.start, (a and a.end or q.end)]
  local function finder(pc, line)
    for i, ex in ipairs(pc.exchanges) do
      local lo = ex.question.line_start
      local hi = (ex.answer and ex.answer.line_end) or ex.question.line_end
      if line >= lo and line <= hi then return i end
    end
    return nil
  end

  it("returns the enclosing exchange's lines (question..answer)", function()
    local ctx = define.context_for_selection(parsed, 6, all_lines, finder)
    assert.equals("line 3\nline 4\nline 5\nline 6\nline 7\nline 8", ctx)
  end)

  it("handles an answerless exchange (question only)", function()
    local ctx = define.context_for_selection(parsed, 10, all_lines, finder)
    assert.equals("line 10", ctx)
  end)

  it("falls back to the whole buffer when outside any exchange", function()
    local ctx = define.context_for_selection(parsed, 1, all_lines, finder)
    assert.equals(table.concat(all_lines, "\n"), ctx)
  end)
end)
```

- [ ] **Step 2: Run to verify it fails** — `make test-unit` → FAIL (`context_for_selection` nil).

- [ ] **Step 3: Implement**

```lua
-- `find_exchange` is injected (default = require("parley").find_exchange_at_line)
-- so the pure fn is unit-testable without the real parser / a Neovim buffer.
function M.context_for_selection(parsed_chat, sel_line, all_lines, find_exchange)
  find_exchange = find_exchange or require("parley").find_exchange_at_line
  local idx = find_exchange(parsed_chat, sel_line)
  local ex = idx and parsed_chat.exchanges and parsed_chat.exchanges[idx]
  if not ex then
    return table.concat(all_lines, "\n") -- whole-buffer fallback
  end
  local lo = ex.question.line_start
  local hi = (ex.answer and ex.answer.line_end) or ex.question.line_end
  local slice = {}
  for l = lo, hi do slice[#slice + 1] = all_lines[l] end
  return table.concat(slice, "\n")
end
```

- [ ] **Step 4: Run to verify it passes** — `make test-unit` → PASS.

> **Implementer note:** verify the real `find_exchange_at_line` return arity (`init.lua:3082`; the confirmation review found it returns `idx, component` and `nil,nil` outside any exchange) and that `question.line_start` / `answer.line_end` are the real field names (`answer.line_end` is used at `chat_respond.lua:1250`). Adjust the injected default accordingly; the test's synthetic `finder` pins the contract.

- [ ] **Step 5: Commit**

```bash
git add lua/parley/define.lua tests/unit/define_spec.lua
git commit -m "#161: define.context_for_selection — enclosing-exchange context window"
```

### Task 3: `format_definition` (pure)

**Files:**
- Modify: `lua/parley/define.lua`
- Test: `tests/unit/define_spec.lua`

- [ ] **Step 1: Failing test**

```lua
describe("define.format_definition", function()
  it("composes 'TERM — definition'", function()
    local msg = define.format_definition("ASIN", "Amazon Standard Identification Number.", 200)
    assert.equals("ASIN — Amazon Standard Identification Number.", msg)
  end)

  it("hard-wraps to width", function()
    local msg = define.format_definition("X", string.rep("word ", 30), 40)
    for _, l in ipairs(vim.split(msg, "\n", { plain = true })) do
      assert.is_true(#l <= 40)
    end
  end)

  it("trims a nil/blank definition to a safe string", function()
    assert.equals("X — (no definition)", define.format_definition("X", nil, 80))
  end)
end)
```

- [ ] **Step 2: Run to fail** — `make test-unit` → FAIL.

- [ ] **Step 3: Implement** (reuse `skill_render.wrap`)

```lua
function M.format_definition(term, definition, width)
  definition = (definition and definition:gsub("%s+$", "")) or ""
  if definition == "" then definition = "(no definition)" end
  local head = tostring(term or "") .. " — " .. definition
  return require("parley.skill_render").wrap(head, width or 80)
end
```

- [ ] **Step 4: Run to pass** — `make test-unit` → PASS.

> **Implementer note:** confirm `skill_render.wrap(text, width)` arg order + that it returns a `\n`-joined string (`skill_render.lua:52-74`). If `wrap` word-splits differently than the test expects, relax the test to assert `#l <= width` only (the invariant that matters), not exact break points.

- [ ] **Step 5: Commit**

```bash
git add lua/parley/define.lua tests/unit/define_spec.lua
git commit -m "#161: define.format_definition — diagnostic message composer"
```

### Task 4: `emit_definition` builtin tool

**Files:**
- Create: `lua/parley/tools/builtin/emit_definition.lua`
- Modify: `lua/parley/tools/init.lua` (add to `BUILTIN_NAMES`)
- Test: `tests/integration/define_spec.lua`

- [ ] **Step 1: Read a sibling builtin for the exact shape**

Read `lua/parley/tools/builtin/propose_edits.lua` and `lua/parley/tools/types.lua` (see `is_pageable`/`self_paginates`, `tools/types.lua:98-100`) to copy the builtin table contract (fields: `name`, `description`, `schema`/`input_schema`, `kind`/`self_paginates`, `execute`).

- [ ] **Step 2: Write the failing registration test**

```lua
-- tests/integration/define_spec.lua
describe("emit_definition tool", function()
  it("is registered and selectable without raising", function()
    local reg = require("parley.tools")            -- adjust to real registry module
    local ok, sel = pcall(function() return reg.select({ "emit_definition" }) end)
    assert.is_true(ok)
    assert.is_not_nil(sel)
  end)

  it("does not advertise pager offset/limit params", function()
    local def = require("parley.tools.builtin.emit_definition")
    local props = def.input_schema.properties   -- assert input_schema specifically
    assert.is_nil(props.offset)
    assert.is_nil(props.limit)
    assert.is_not_nil(props.term)
    assert.is_not_nil(props.definition)
  end)
end)
```

- [ ] **Step 3: Run to fail** — `make test-integration` → FAIL (unknown tool raises).

- [ ] **Step 4: Implement the tool + register**

```lua
-- lua/parley/tools/builtin/emit_definition.lua
-- Output-only structured tool: the model calls it to return a concise
-- definition. No side effects; the value is read from the tool-call args in
-- define's on_done. self_paginates=true suppresses pager param injection.
-- NOTE the contract (tools/types.lua:66,69): the fields are `input_schema`
-- (not `schema`) and `handler` (not `execute`), and `handler` must return a
-- ToolResult (`{ content = "…" }`). `M.register` RAISES on a bad shape
-- (tools/init.lua:59-63), which would hard-error every define invoke.
return {
  name = "emit_definition",
  description = "Return a concise definition of the selected term as used in "
    .. "the provided context. Call this exactly once with your answer.",
  self_paginates = true,
  input_schema = {
    type = "object",
    properties = {
      term = { type = "string", description = "The term being defined." },
      definition = {
        type = "string",
        description = "A concise 1–3 sentence definition, in context.",
      },
    },
    required = { "term", "definition" },
  },
  handler = function(_args) return { content = "" } end, -- no-op ToolResult
}
```

Add `"emit_definition"` to `BUILTIN_NAMES` in `lua/parley/tools/init.lua` (~158-167). The builtin is `require`d by name → the filename must equal the tool name exactly (`tools/init.lua:181`).

- [ ] **Step 5: Run to pass** — `make test-integration` → PASS.

> **Implementer note:** the contract is `input_schema` + `handler`→ToolResult (verified `tools/types.lua:66,69`, `dispatcher.lua:313`); a `schema`/`execute` shape fails `types.validate_definition` and `M.register` raises. Filename must equal the tool name (require-by-name, `tools/init.lua:181`).

- [ ] **Step 6: Commit**

```bash
git add lua/parley/tools/builtin/emit_definition.lua lua/parley/tools/init.lua tests/integration/define_spec.lua
git commit -m "#161: emit_definition — output-only structured tool for define"
```

### Task 5: `define` skill (manifest)

**Files:**
- Create: `lua/parley/skills/define/init.lua`
- Test: `tests/integration/define_spec.lua`

> **No `SKILL.md`.** `define_visual` passes the manifest table directly to
> `skill_invoke.invoke`, bypassing the disk provider's `ctx.skill_md` wrapping
> (`skill_providers.lua:44-69`), so a `SKILL.md` would be dead content. The
> `source(ctx)` function below owns the entire system prompt (it must, to fold
> the phrase in). Auto-discovery still works — the disk provider only needs
> `init.lua` returning a table with a `source`.

- [ ] **Step 1: Read `review` skill for the manifest shape**

Read `lua/parley/skills/review/init.lua` (manifest fields, `source(ctx)`) and `lua/parley/skill_manifest.lua:52-97` (validated fields: `name, description, scope, activation, source`).

- [ ] **Step 2: Failing test — discovery + source composition**

```lua
describe("define skill", function()
  it("is auto-discovered by the registry", function()
    local skills = require("parley.skill_registry").current()
    local names = {}
    for _, s in ipairs(skills) do names[s.name] = true end
    assert.is_true(names["define"] == true)
  end)

  it("folds the phrase into the system prompt and forces no tool", function()
    local skill = require("parley.skills.define")
    local body = skill.source({ args = { phrase = "ASIN" }, repo_root = "." })
    assert.is_true(body:find("ASIN", 1, true) ~= nil)
    assert.is_nil(skill.force_tool)
    assert.same({ "emit_definition" }, skill.tools)
  end)
end)
```

- [ ] **Step 3: Run to fail** — `make test-integration` → FAIL.

- [ ] **Step 4: Implement**

```lua
-- lua/parley/skills/define/init.lua
local M = {
  name = "define",
  description = "Define a selected term concisely, inline.",
  scope = "global",
  activation = { manual = true },
  tools = { "emit_definition" },
  -- no force_tool: unforced so server-side web_search can run when enabled.
}

function M.source(ctx)
  local phrase = ctx and ctx.args and ctx.args.phrase or ""
  return table.concat({
    "You define a single term for a reader of a chat transcript.",
    "The user selected this phrase: «" .. phrase .. "».",
    "Define it concisely (1–3 sentences) AS USED in the document below.",
    "If it is an unfamiliar or fresh proper noun and web search is available,",
    "you may search first. Then ALWAYS call the emit_definition tool exactly",
    "once with {term, definition}. Do not reply in plain prose.",
  }, "\n")
end

return M
```

- [ ] **Step 5: Run to pass** — `make test-integration` → PASS.

> **Implementer note:** verify `activation` flag names (`always|auto|manual`) against `skill_manifest.lua` (required fields: name, description, scope, activation, source — all present). A flat table is accepted by the disk provider (`def.skill or def`, `skill_providers.lua:117`). Optional (Spec's "fast" goal): `resolve_agent` picks the *first* tool-capable agent (`skill_assembly.lua:91-96`) — no config needed, but if that model is heavy, add a `define_agent` config pointing at a fast model and set `M.agent` from it.

- [ ] **Step 6: Commit**

```bash
git add lua/parley/skills/define/ tests/integration/define_spec.lua
git commit -m "#161: define skill — unforced emit_definition, phrase in source(ctx)"
```

### Task 6: `skill_invoke` seams — `opts.no_reload` + `opts.document`

**Files:**
- Modify: `lua/parley/skill_invoke.lua` (write `~133-137`, document `~152`, reload `~230`)
- Test: `tests/integration/define_spec.lua`

- [ ] **Step 1: Read the three sites** — `skill_invoke.lua:133-137` (write), `:~152` (`document = original` passed to `build_invocation`), `:230` (`:edit!` reload on exit).

- [ ] **Step 2: Failing test — no write/reload under `no_reload`, and document override**

```lua
it("does not write or reload the buffer when opts.no_reload is set", function()
  -- Arrange: a modified buffer + a fake exchange that returns emit_definition.
  -- Use the fake-provider harness from skill_invoke_review_spec.lua.
  -- Assert: the file on disk is unchanged and no :edit! ran
  -- (spy on vim.cmd / check &modified stays true / mtime unchanged).
end)

it("sends opts.document as the user message, not the whole buffer", function()
  -- Assert the payload's user message equals the passed document string.
end)
```

- [ ] **Step 3: Run to fail** — `make test-integration` → FAIL.

- [ ] **Step 4: Implement**

- Guard the pre-query write: `if vim.bo[buf].modified and not opts.no_reload then …silent write… end`.
- Thread the document: `local document = opts.document or original` and pass `document` into `build_invocation` at `:~152`.
- Guard the reload: wrap the `:edit!` at `:230` in `if not opts.no_reload then … end`.

- [ ] **Step 5: Run to pass** — `make test-integration` → PASS.

- [ ] **Step 6: Web-toggle payload assertion** (Spec Done-when — deterministic, no model call)

```lua
it("includes the web_search server tool in the payload iff the toggle is on", function()
  local parley = require("parley")
  local dispatcher = require("parley.dispatcher")
  -- Build a payload the way skill_invoke does (prepare_payload → anthropic
  -- format_payload injects web tools gated on parley._state.web_search).
  local function tool_names(payload)
    local n = {}
    for _, t in ipairs(payload.tools or {}) do n[t.name] = true end
    return n
  end
  -- NOTE: model MUST be a table {model=id}. prepare_payload short-circuits on a
  -- STRING model and returns a bare payload with no .tools (dispatcher.lua:86-92),
  -- never reaching anthropic.format_payload where web_search is injected.
  local MODEL = { model = "<real-anthropic-id-from-config>" }
  parley._state.web_search = true
  local on = dispatcher.prepare_payload({ { role = "user", content = "x" } },
    MODEL, "anthropic", { "emit_definition" })
  assert.is_true(tool_names(on).web_search == true)
  parley._state.web_search = false
  local off = dispatcher.prepare_payload({ { role = "user", content = "x" } },
    MODEL, "anthropic", { "emit_definition" })
  assert.is_nil(tool_names(off).web_search)
end)
```

Run: `make test-integration` → PASS.

> **Implementer note:** copy the fake-exchange harness verbatim from `tests/integration/skill_invoke_review_spec.lua` (process-level fake, ARCH-PURE integration seam). If asserting "no `:edit!`" is awkward, assert on-disk file bytes unchanged + `&modified` still true after invoke. For Step 6, the model arg MUST be a **table** `{model=<real-anthropic-id>}` — a bare string id short-circuits `prepare_payload` (`dispatcher.lua:86-92`) before `format_payload` injects web tools, so the assertion would spuriously fail. Confirm `emit_definition` (Task 4) isn't clobbered by the appended server tools (`dispatcher.lua:118`).

- [ ] **Step 7: Commit**

```bash
git add lua/parley/skill_invoke.lua tests/integration/define_spec.lua
git commit -m "#161: skill_invoke — opts.no_reload + opts.document; web-toggle payload test"
```

### Task 7: `define_visual` + `render_definition` (IO shell)

**Files:**
- Modify: `lua/parley/init.lua` (new `define_visual`, `render_definition`; wire near `drill_in_visual` `~1537`)
- Test: `tests/integration/define_spec.lua`

- [ ] **Step 1: Failing integration test — end-to-end with a faked emit_definition**

```lua
it("renders a definition diagnostic on the selection line via a faked exchange", function()
  -- Open a chat buffer; set '<,'> marks around a phrase on a known line.
  -- Fake exchange returns calls = { { name="emit_definition",
  --   input = { term="ASIN", definition="Amazon Standard Identification Number." } } }.
  -- Call the define entrypoint; then read diagnostics on skill_render.diag_namespace().
  local diags = vim.diagnostic.get(buf, { namespace = require("parley.skill_render").diag_namespace() })
  assert.is_true(#diags >= 1)
  assert.equals(SEL_LINE - 1, diags[1].lnum) -- 0-based
  assert.is_true(diags[1].message:find("ASIN", 1, true) ~= nil)
end)

it("no-ops on an empty selection and on a no-tool-call response", function()
  -- empty '<,'> → no invoke, no diagnostic, no error
  -- fake exchange with calls = {} → render no-ops, no error
end)
```

- [ ] **Step 2: Run to fail** — `make test-integration` → FAIL.

- [ ] **Step 3: Implement `render_definition` and `define_visual`**

```lua
-- render_definition(buf, sel_line0, result): on_done callback (IO seam)
local function render_definition(buf, sel_line0, result)
  if not result or not result.calls or #result.calls == 0 then return end
  local call                                    -- defensive: pick the define call
  for _, c in ipairs(result.calls) do
    if c.name == "emit_definition" then call = c break end
  end
  if not call then return end
  local input = call.input or {}
  local define = require("parley.define")
  local ns = require("parley.skill_render").diag_namespace()
  local width = math.max(40, vim.api.nvim_win_get_width(0) - 8)
  local msg = define.format_definition(input.term, input.definition, width)
  vim.diagnostic.set(ns, buf, { {
    lnum = sel_line0, col = 0, end_lnum = sel_line0,
    message = msg, severity = vim.diagnostic.severity.INFO, source = "parley-define",
  } })
  vim.cmd("redraw") -- reveal via diag_display (no CursorMoved fires; see spec watch-item)
end

function M.define_visual(buf)
  buf = buf or vim.api.nvim_get_current_buf()
  local s, e = vim.fn.getpos("'<"), vim.fn.getpos("'>")
  local l1, c1, l2, c2 = s[2], s[3] - 1, e[2], e[3] - 1
  local lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
  local define = require("parley.define")
  local phrase = define.slice_selection(lines, l1, c1, l2, c2)
  if phrase:gsub("%s", "") == "" then return end          -- empty-selection guard
  local header_end = M.chat_parser.find_header_end(lines) or 0  -- M.find_chat_header_end does NOT exist
  local parsed = M.parse_chat(lines, header_end)
  local context = define.context_for_selection(parsed, l1, lines, M.find_exchange_at_line)
  local manifest = require("parley.skills.define")
  require("parley.skill_invoke").invoke(buf, manifest, { phrase = phrase }, {
    document = context,
    no_reload = true,
    on_done = function(result) render_definition(buf, l1 - 1, result) end,
  })
  vim.api.nvim_win_set_cursor(0, { l1, c1 })              -- park cursor to reveal
end
```

- [ ] **Step 4: Run to pass** — `make test-integration` → PASS.

> **Implementer notes:** (a) `skill_invoke.invoke` resolves the agent itself (`skill_assembly.resolve_agent` picks the first tool-capable agent); no config needed, optionally add `define_agent` for a faster model. (b) `on_done` runs async (`vim.schedule`) — `diag_display.set(true)` is already applied at setup (`init.lua:776`) so the parked cursor + set is enough; the `redraw` nudge is belt-and-suspenders. (c) `M.chat_parser.find_header_end(lines)` is the public accessor (`M.find_chat_header_end` does not exist — the header-end helper is a file-local at `init.lua:180`, exposed only via `M.chat_parser`). (d) `<Esc>` to commit the visual marks is handled at the Task 8 wiring, not here — but if you unit-drive `define_visual` directly, `setpos("'<"/"'>")` first.

- [ ] **Step 5: Commit**

```bash
git add lua/parley/init.lua tests/integration/define_spec.lua
git commit -m "#161: define_visual + render_definition — inline definition IO shell"
```

### Task 8: Keybinding restructure — visual `<M-CR>` → define

**Files:**
- Modify: `lua/parley/config.lua:448` (`chat_shortcut_respond`), add `chat_shortcut_define`
- Modify: `lua/parley/keybinding_registry.lua` (the `chat_respond` entry `~470-479`; add a `chat_define` entry)
- Modify: `lua/parley/init.lua` (`~1988` — provide the `chat_define` per-mode callback table)
- Test: `tests/integration/define_spec.lua` (or manual)

- [ ] **Step 1: Read the registry binding path** — `keybinding_registry.lua:470-479` (`chat_respond` entry: `id`, `config_key`, `default_key`, `default_modes`), `:1065-1091` (per-mode callback table dispatch), and `init.lua:~1988` where `make_respond_cb`'s table is registered.

- [ ] **Step 2: Restructure**

- In `config.lua`: change `chat_shortcut_respond.shortcut` to `{ "<C-g><C-g>" }` (drop `<M-CR>`); add `chat_shortcut_define = { modes = { "n", "i", "v", "x" }, shortcut = "<M-CR>" }`.
- In `keybinding_registry.lua`: (i) drop `"<M-CR>"` from the existing `chat_respond` entry's `default_key` (`~473`, leaving `{ "<C-g><C-g>" }`) so no registry-level default double-binds `<M-CR>`; (ii) add a `chat_define` entry mirroring `chat_respond` — it **must** carry `scope = "chat"` and `buffer_local = true` (the register filter is `scope_set[entry.scope] and entry.buffer_local`, `keybinding_registry.lua:1066`), plus `id = "chat_define"`, `config_key = "chat_shortcut_define"`, `default_key = { "<M-CR>" }`, `default_modes = { "n", "i", "v", "x" }`.
- In `init.lua` (where the respond callback table is registered, `~1988`): the callbacks table is keyed by `entry.id`, and `make_respond_cb` returns `{ n=fn, i=fn, v=<string rhs>, x=<string rhs> }` (v/x are the `:'<,'>ChatRespond<cr>` range STRINGS). Build the `chat_define` callback by **reusing** the respond closures for n/i and routing v/x to `define_visual` — and **v/x MUST `<Esc>` first** to commit the `'<`/`'>` marks (a visual-mode function callback otherwise sees the *previous* selection; both `drill_in_callbacks` `init.lua:1792,1796` and `branch_ref.v` `:1983` do this):

```lua
local r = make_respond_cb("ChatRespond")   -- reuse the exact n/i respond closures
local esc = vim.api.nvim_replace_termcodes("<Esc>", true, false, true)
local function define_v() vim.cmd("normal! " .. esc); M.define_visual() end
callbacks["chat_define"] = { n = r.n, i = r.i, v = define_v, x = define_v }
```

- [ ] **Step 3: Verify**

- Automated (if feasible): assert the buffer keymap for `<M-CR>` in visual mode resolves to the define callback and `<C-g><C-g>` in visual still maps to respond (`nvim_buf_get_keymap`).
- Manual: open a chat, `V`-select a line, `<M-CR>` → definition appears; `<C-g><C-g>` on a selection still line-scopes a resubmit; normal-mode `<M-CR>` on a question still resubmits.

Run: `make test` (full suite + lint).
Expected: PASS.

> **Implementer note (from confirmation review):** the registry keys callbacks by `entry.id`, not `config_key`. Ensure the `chat_define` entry's `id` matches the key under which you register the callback table in `init.lua` — a mismatch silently no-ops the binding.

- [ ] **Step 4: Commit**

```bash
git add lua/parley/config.lua lua/parley/keybinding_registry.lua lua/parley/init.lua tests/integration/define_spec.lua
git commit -m "#161: keybinding — split <M-CR> into chat_define; visual routes to define"
```

### Task 9: ARCH-DRY — refactor `drill_in_visual` onto `slice_selection`

**Files:**
- Modify: `lua/parley/init.lua:1537-1564` (`drill_in_visual`)
- Test: existing `tests/unit/drill_in_spec.lua` + `tests/integration/*` as the regression guard

- [ ] **Step 1: Confirm the shared shape** — read `drill_in_visual`'s inline extraction; confirm it computes the same `(lines, l1, c1, l2, c2) → text` as `slice_selection`.

- [ ] **Step 2: Refactor** — replace the inline substring logic with `require("parley.define").slice_selection(...)`, feeding columns in the same convention Task 7 uses. Leave the marker-wrapping unchanged.

- [ ] **Step 3: Verify no regression** — Run: `make test` → PASS (drill_in specs green). Manual: `<M-q>` in visual still wraps `🤖<selected>[]` correctly (single- and multi-line).

> **Cite ARCH-DRY** in the commit + `## Log`: one slice implementation shared by define and drill-in. If the column conventions turn out to differ subtly (line-visual clamping), keep them separate and record the divergence rather than forcing a leaky shared fn.

- [ ] **Step 4: Commit**

```bash
git add lua/parley/init.lua
git commit -m "#161: side-quest: drill_in_visual reuses define.slice_selection (ARCH-DRY)"
```

### Task 10: Atlas + full verification

**Files:**
- Create/Modify: `atlas/chat/inline_define.md` (new); link it in `atlas/index.md`
- Modify: `atlas/traceability.yaml` (map the new specs so `make test-spec` works)

- [ ] **Step 1: Write the atlas note** — a short `atlas/chat/inline_define.md`: the gesture, the `define` skill + `emit_definition` tool, the ephemeral-diagnostic render, the keybinding split, and the `skill_invoke` `no_reload`/`document` seams. Link from `atlas/index.md`.

- [ ] **Step 2: Traceability** — add an entry mapping an `atlas/chat/inline_define.md` spec key → `tests/unit/define_spec.lua`, `tests/integration/define_spec.lua`.

- [ ] **Step 3: Full green** — Run: `make test`. Expected: PASS (lint + unit + integration).

- [ ] **Step 4: Manual acceptance (record in `## Log`)**
  - Select `ASIN` in a real chat → `<M-CR>` → concise definition under the line.
  - `:ToggleWebSearch` on → select an obscure proper noun → definition (may cite web).
  - Visual `<C-g><C-g>` still line-scopes a resubmit; normal `<M-CR>` unchanged.
  - Trigger define while mid-typing an unsaved prompt → the draft is NOT written to disk.

- [ ] **Step 5: Commit**

```bash
git add atlas/
git commit -m "#161: atlas + traceability for inline define"
```

---

## Notes for the executor

- **ARCH-PURE:** all decision logic lives in `lua/parley/define.lua` (pure, `tests/unit/define_spec.lua`, no Neovim APIs); `define_visual`/`render_definition` are the thin IO seam; the external-service seam (Anthropic) is exercised via the process-level fake reused from `skill_invoke_review_spec.lua`.
- **ARCH-DRY:** reuse `skill_invoke`, `skill_render.wrap`, `diag_display`, `parse_chat`/`find_exchange_at_line`; Task 9 unifies the visual-selection slice.
- **ARCH-PURPOSE:** the web-search path is delivered (unforced tool + honored global toggle), not deferred — Done-when asserts it at payload level.
- **Line refs will drift.** Every `file:line` here is a starting pointer; re-grep before editing.
- Single-pass, single close: plain checkboxes, **no `Mx` milestones** (one review boundary at `sdlc close`).
