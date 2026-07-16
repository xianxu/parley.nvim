# 000106 — Unified Skill System for AI-Powered Buffer Editing

## Overview

A skill is an AI-powered tool that edits the current buffer. All skills share the same pipeline: build a system prompt, send buffer content to an LLM with the `review_edit` tool, apply returned edits, and show changes via highlights and diagnostics.

A single entry point `<C-g>s` (capital S) opens a picker with cascading typeahead completion. Users type `/skill-name arg1 arg2` and press Enter to execute.

### Constraints

- **Anthropic-compatible providers only.** Skills use `review_edit` tool calling and `decode_anthropic_tool_calls_from_stream`. Providers must support Anthropic-style tool use (currently: `anthropic`, `cliproxyapi`).
- **No free-form arguments.** All skill args are completable from a finite set. Ad-hoc instructions go through skill-specific mechanisms (e.g., review's ㊷ markers).

## Skill Definition

Each skill is a folder under `lua/parley/skills/`:

```
lua/parley/skills/
  review/
    init.lua       -- mechanical definition (args, completion, hooks)
    SKILL.md       -- the system prompt sent to the LLM
  voice_apply/
    init.lua
    SKILL.md
```

`SKILL.md` IS the system prompt. Other .md files can be added for documentation if needed.

`init.lua` returns a table:

```lua
return {
  name = "voice-apply",
  description = "Rewrite to match a personal writing voice",
  agent = nil,  -- nil = use global default; string = agent name
  args = {
    {
      name = "slug",
      description = "Voice style",
      complete = function()
        -- return list of valid values for typeahead
        return { "xian" }
      end,
    },
  },

  -- System prompt builder.
  -- nil = use SKILL.md verbatim.
  -- function = receives (args, file_path, content, skill_md) and returns prompt string.
  system_prompt = function(args, file_path, content, skill_md)
    local style = read_style_file(args.slug)
    return skill_md .. "\n\n## Voice Style Guide\n\n" .. style
  end,

  -- Optional. Called before LLM submission.
  -- Return false, "message" to abort.
  pre_submit = nil,

  -- Optional. Called after edits are applied and diagnostics shown.
  -- Receives (buf, args, edit_result, new_content).
  post_apply = nil,
}
```

### Field Reference

| Field | Type | Required | Description |
|---|---|---|---|
| `name` | string | yes | Unique skill identifier, used in picker and config |
| `description` | string | yes | One-line description shown in picker results |
| `agent` | string or nil | no | Default agent name. Resolution: user per-skill config > this field > `config.skill_agent` > first tool-capable agent |
| `args` | table[] | no | Ordered list of completable arguments. No free-form text. |
| `args[].name` | string | yes | Arg identifier |
| `args[].description` | string | yes | Shown in picker during arg completion |
| `args[].complete` | function | yes | Returns list of valid values (strings) for typeahead |
| `system_prompt` | function or nil | no | nil = SKILL.md verbatim. Function receives `(args, file_path, content, skill_md)` and returns prompt string |
| `pre_submit` | function or nil | no | `(buf, args) -> bool\|nil, err_msg`. Return false to abort. May perform side effects (e.g., populate quickfix). |
| `post_apply` | function or nil | no | `(buf, args, edit_result, new_content)`. Runs after edits applied and diagnostics shown. May re-invoke `skill_runner.run()` (max 3 resubmits). |

## Skill Runner (`skill_runner.lua`)

The shared pipeline. Single function: `run(buf, skill, args)`.

### Pipeline Steps

1. **Pre-submit hook** — call `skill.pre_submit(buf, args)` if defined. Abort on false + show error message.
2. **Save buffer** if modified.
3. **Read buffer content** — `vim.api.nvim_buf_get_lines`.
4. **Build system prompt** — read SKILL.md from the skill's directory. If missing, abort with error: `"Skill <name>: SKILL.md not found"`. If `skill.system_prompt` is a function, call it with `(args, file_path, content, skill_md)`. Otherwise use SKILL.md verbatim.
5. **Resolve agent** — scan `config.skills` array for matching name. Priority: user per-skill config `.agent` > `skill.agent` > `config.skill_agent` > first tool-capable agent. Agent's `model` must be a table (not string) for correct provider payload formatting.
6. **Prepare payload** — `dispatcher.prepare_payload(messages, agent.model, agent.provider)` + attach `review_edit` tool.
7. **Headless LLM call** — `dispatcher.query` with `buf = nil`. Progress notifications: `"Running <skill>... (X chars)"`.
8. **Extract tool calls** — `providers.decode_anthropic_tool_calls_from_stream(raw_response)`.
9. **Apply edits** — `apply_edits(file_path, edits)` using `compute_edits` (find-and-replace, bottom-up).
10. **Reload buffer** — `vim.cmd("checktime")`.
11. **Display** — `highlight_edits` (DiffChange on changed lines) + `attach_diagnostics` (INFO diagnostics from explain fields).
12. **Post-apply hook** — call `skill.post_apply(buf, args, edit_result, new_content)` if defined.

### Shared Functions (extracted from review.lua)

- `compute_edits(content, edits)` — pure: validate old_strings exist and are unique, apply replacements bottom-up, return `{ok, content, applied}`.
- `apply_edits(file_path, edits)` — IO: read file, compute_edits, write file.
- `highlight_edits(buf, edits, new_content)` — highlight changed lines with `DiffChange`.
- `attach_diagnostics(buf, edits, original_content)` — INFO diagnostics from `explain` fields.
- `clear_decorations(buf)` — clear highlights and diagnostics from previous run.
- `REVIEW_EDIT_TOOL` — tool definition table for the LLM.

### Message Format

```lua
messages = {
  { role = "system", content = system_prompt },
  { role = "user", content = "Please edit this document (file: " .. file_path .. "):\n\n" .. content },
}
```

## Skill Picker (`skill_picker.lua`)

Activated by `<C-g>s`. Uses `float_picker.open()` with dynamic item replacement.

### Required float_picker extension

The current `float_picker.open()` accepts `items` once at open time. The skill picker needs to replace items when transitioning between states (skill list → arg completions). Extension: `float_picker.open()` returns a handle with a `set_items(new_items)` method that replaces the item list and re-renders. The prompt/query text can be reset via `set_query(text)`.

### States

1. **Skill selection** — Input prefilled with `/`. Results show all enabled skills: `review — Edit document based on review markers`. Typeahead filters by skill name.

2. **Arg completion** — Skill name locked (space after valid name). Results show completions for current arg position from `arg.complete()`. Prompt indicates expected arg.

3. **Ready** — All required args filled. Enter executes `skill_runner.run()`.

### Interactions

- Typing narrows results via typeahead at every state.
- Space after a valid match locks the current token and advances to next position.
- Tab auto-completes the top match.
- Enter with all args filled executes the skill.
- Enter with missing args does nothing.
- Escape cancels.

### Initial display (0 input)

All enabled skills shown with descriptions. This is the discovery mechanism.

## Skill Discovery and Configuration

### Discovery

Skills are discovered lazily on first `<C-g>s` press or first programmatic `skill_runner.run()` call (not at setup time). This avoids scanning the filesystem during startup. `skill_runner` scans `lua/parley/skills/*/init.lua`, `require`'s each, and caches the returned tables. Subsequent calls use the cache.

### Configuration

```lua
config.skill_shortcut = { modes = { "n" }, shortcut = "<C-g>s" }
config.skill_agent = "Claude-Sonnet"   -- global default agent for all skills
config.skills = {}                      -- per-skill overrides
-- Example: { { name = "review", agent = "Claude-Opus" }, { name = "summarize", disable = true } }
```

All skills enabled by default. Disable with `{ name = "skill-name", disable = true }`.

The `config.skills` array is scanned by name at runtime. Each entry is `{ name = string, agent = string|nil, disable = bool|nil }`.

Agent resolution priority:
1. `config.skills[]` entry with matching name → `.agent` field
2. Skill definition's `agent` field
3. `config.skill_agent` (global default)
4. First tool-capable agent in registry

### Deprecation

`config.review_agent` is deprecated. Migrate to `config.skills = { { name = "review", agent = "Claude-Sonnet" } }`. During transition, if `review_agent` is set and no `config.skills` entry for review exists, `review_agent` is used as fallback.

## Skills to Implement

### review

Port of existing `<C-g>ve` / `<C-g>vr`.

**SKILL.md**: Contains `SYSTEM_PREAMBLE` content (marker syntax rules, tool usage requirements). Includes both edit-level sections, selected by the `system_prompt` function based on `level` arg.

**init.lua**:
- `args`: `[{ name = "level", complete = fn() return {"edit", "revise"} end }]`
- `system_prompt(args, file_path, content, skill_md)`: reads SKILL.md, appends the section matching `args.level`
- `pre_submit(buf, args)`: parses ㊷ markers, rejects if any have even section count (pending user response), populates quickfix with pending items
- `post_apply(buf, args, result, new_content)`: re-scans for remaining markers. If agent questions exist, populates quickfix. If markers remain with no questions, auto-resubmits via `skill_runner.run()` (max 3 resubmits, tracked by skill_runner via a counter passed through).

Marker parsing functions (`parse_markers`, `parse_marker_sections`, `populate_quickfix`) live in `skills/review/init.lua`.

The `<C-g>vi` keybinding (insert ㊷ marker) remains as a buffer-local keymap on markdown files — it's an editing aid, not a skill invocation. Stays in review's init.lua, wired via `setup_keymaps` called from init.lua's `setup_markdown_keymaps`.

The `<C-g>ve` / `<C-g>vr` keybindings become fast paths that call `skill_runner.run()` directly, bypassing the picker.

### voice-apply

New skill.

**SKILL.md**: Two-pass rewriting prompt — content audit first, then voice rewrite. Rules: preserve content/structure/meaning, change voice only, be specific about which style guide rule justifies each change, don't over-apply.

**init.lua**:
- `args`: `[{ name = "slug", complete = fn() ... scan ~/.personal/*-writing-style.md ... end }]`
- `system_prompt(args, file_path, content, skill_md)`: reads SKILL.md, reads `~/.personal/<slug>-writing-style.md`, combines them
- No hooks needed

## File Layout

### New files
```
lua/parley/skill_runner.lua              -- shared pipeline
lua/parley/skill_picker.lua              -- <C-g>s picker UI
lua/parley/skills/review/init.lua        -- review skill definition + marker logic
lua/parley/skills/review/SKILL.md        -- review system prompt
lua/parley/skills/voice_apply/init.lua   -- voice-apply skill definition
lua/parley/skills/voice_apply/SKILL.md   -- voice-apply system prompt
```

### Extraction from review.lua
| Function | From | To |
|---|---|---|
| `compute_edits` | review.lua | skill_runner.lua |
| `apply_edits` | review.lua | skill_runner.lua |
| `highlight_edits` | review.lua | skill_runner.lua |
| `attach_diagnostics` | review.lua | skill_runner.lua |
| `clear_review_decorations` | review.lua | skill_runner.lua (renamed `clear_decorations`) |
| `REVIEW_EDIT_TOOL` | review.lua | skill_runner.lua |
| `resolve_review_agent` | review.lua | skill_runner.lua (generalized) |
| `submit_review` | review.lua | skill_runner.run (generalized) |
| `parse_markers` | review.lua | skills/review/init.lua |
| `parse_marker_sections` | review.lua | skills/review/init.lua |
| `populate_quickfix` | review.lua | skills/review/init.lua |
| `setup_keymaps` (㊷ insert) | review.lua | skills/review/init.lua |

### review.lua after extraction
Thin shim that requires `skills/review/init.lua` and exposes `setup_keymaps` for init.lua's `setup_markdown_keymaps` call. May be eliminated entirely if init.lua can wire directly to the skill module.

## Progress Feedback

Reuse existing pattern from review.lua:
- `vim.notify("Running <skill>...")` on start
- Throttled `vim.notify("Running <skill>... (X chars)")` during streaming
- `vim.notify("Applied N edit(s)")` on completion
- Error/warning via `vim.notify` for failures

## Error Handling

- **SKILL.md missing**: abort with `"Skill <name>: SKILL.md not found at <path>"`.
- **No tool-capable agent**: abort with `"No tool-capable agent available for skill <name>"`.
- **LLM returns no tool call**: warn `"Skill <name>: agent returned no edits"`.
- **Edit apply fails** (old_string not found / not unique): warn with the specific failure from `compute_edits`.
- **Resubmit limit**: `skill_runner.run` accepts an optional `_resubmit_count` parameter (internal). If `post_apply` calls `run()` again, the count increments. At 3, abort with `"Skill <name>: max resubmits reached"`.
- **In-flight guard**: one skill execution per buffer at a time. Second invocation warns and returns.

---

# Implementation Plan

> **For agentic workers:** Consult AGENTS.md Section 3 (Subagent Strategy) to decide whether to use superpowers-subagent-driven-development, superpowers-executing-plans, or main-session execution for each task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build a unified skill system that generalizes parley's review feature into a pluggable pipeline, with a picker UI and two initial skills (review, voice-apply).

**Architecture:** Extract shared edit-apply-display code from review.lua into skill_runner.lua. Skills are folders under lua/parley/skills/ with init.lua (mechanics) and SKILL.md (prompt). A picker (skill_picker.lua) provides the `<C-g>s` entry point with cascading typeahead.

**Tech Stack:** Lua, Neovim API, existing parley infrastructure (float_picker, dispatcher, providers)

---

## Milestone 1: Extract shared pipeline into skill_runner.lua

### Task 1.1: Create skill_runner.lua with pure edit functions

**Files:**
- Create: `lua/parley/skill_runner.lua`
- Test: `tests/unit/skill_runner_spec.lua`
- Reference: `lua/parley/review.lua:160-250` (compute_edits, apply_edits)

- [ ] **Step 1: Create test file for compute_edits**

The existing tests in `tests/unit/review_spec.lua` cover `compute_edits` and `apply_edits`. We need equivalent tests that import from `skill_runner` instead.

```lua
-- tests/unit/skill_runner_spec.lua
local skill_runner = require("parley.skill_runner")

describe("compute_edits", function()
    it("applies a single edit", function()
        local result = skill_runner.compute_edits(
            "Hello world",
            {{ old_string = "world", new_string = "earth", explain = "changed" }}
        )
        assert.is_true(result.ok)
        assert.equals("Hello earth", result.content)
        assert.equals(1, #result.applied)
    end)

    it("rejects missing old_string", function()
        local result = skill_runner.compute_edits(
            "Hello world",
            {{ old_string = "missing", new_string = "x", explain = "x" }}
        )
        assert.is_false(result.ok)
    end)

    it("rejects non-unique old_string", function()
        local result = skill_runner.compute_edits(
            "aa bb aa",
            {{ old_string = "aa", new_string = "cc", explain = "x" }}
        )
        assert.is_false(result.ok)
    end)

    it("applies multiple edits bottom-up", function()
        local result = skill_runner.compute_edits(
            "aaa bbb ccc",
            {
                { old_string = "aaa", new_string = "AAA", explain = "first" },
                { old_string = "ccc", new_string = "CCC", explain = "third" },
            }
        )
        assert.is_true(result.ok)
        assert.equals("AAA bbb CCC", result.content)
    end)
end)
```

- [ ] **Step 2: Run test to verify it fails**

Run: `make test-unit`
Expected: FAIL — `skill_runner` module not found

- [ ] **Step 3: Create skill_runner.lua with compute_edits and apply_edits**

Copy `compute_edits` (review.lua:160-219) and `apply_edits` (review.lua:225-250) into `lua/parley/skill_runner.lua`. Also copy `REVIEW_EDIT_TOOL` (review.lua:288-311).

```lua
-- lua/parley/skill_runner.lua
-- Shared pipeline for AI-powered buffer editing skills.

local M = {}

local _parley  -- lazily resolved

--- review_edit tool definition (shared by all skills)
M.REVIEW_EDIT_TOOL = {
    name = "review_edit",
    description = "Edit a document. Each edit replaces old_string with new_string and includes an explanation.",
    input_schema = {
        type = "object",
        properties = {
            file_path = { type = "string", description = "Absolute path to the file" },
            edits = {
                type = "array",
                items = {
                    type = "object",
                    properties = {
                        old_string = { type = "string", description = "Exact text to find and replace" },
                        new_string = { type = "string", description = "Replacement text" },
                        explain = { type = "string", description = "Brief explanation of why this change was made" },
                    },
                    required = { "old_string", "new_string", "explain" },
                },
            },
        },
        required = { "file_path", "edits" },
    },
}

-- (paste compute_edits from review.lua:160-219 verbatim)
-- (paste apply_edits from review.lua:225-250 verbatim)

return M
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `make test-unit`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add lua/parley/skill_runner.lua tests/unit/skill_runner_spec.lua
git commit -m "feat(skill): extract compute_edits and apply_edits into skill_runner.lua"
```

### Task 1.2: Move diagnostics and highlights to skill_runner

**Files:**
- Modify: `lua/parley/skill_runner.lua`
- Modify: `lua/parley/review.lua`
- Reference: `lua/parley/review.lua:313-385` (diagnostics, highlights, namespaces)

- [ ] **Step 1: Copy highlight_edits, attach_diagnostics, clear_decorations, ensure_namespaces into skill_runner.lua**

Copy from review.lua:
- `ensure_namespaces` (lines 323-330) — rename namespace strings to `parley_skill` / `parley_skill_hl`
- `clear_review_decorations` (lines 333-337) → `M.clear_decorations`
- `M.attach_diagnostics` (lines 343-361)
- `M.highlight_edits` (lines 367-385)

- [ ] **Step 2: Update review.lua to import from skill_runner**

Replace review.lua's own `attach_diagnostics`, `highlight_edits`, `clear_review_decorations` calls to use `skill_runner.*`. Remove the local copies. Keep `ensure_namespaces` and namespace constants local to skill_runner.

In review.lua, replace:
- `M.attach_diagnostics(...)` → `skill_runner.attach_diagnostics(...)`
- `M.highlight_edits(...)` → `skill_runner.highlight_edits(...)`
- `clear_review_decorations(buf)` → `skill_runner.clear_decorations(buf)`

Note: `review.lua` still exports `M.attach_diagnostics` and `M.highlight_edits` for backward compatibility (thin wrappers). Remove in a later cleanup.

- [ ] **Step 3: Run existing review tests**

Run: `make test-unit`
Expected: PASS — no behavioral changes

- [ ] **Step 4: Commit**

```bash
git add lua/parley/skill_runner.lua lua/parley/review.lua
git commit -m "refactor(skill): move diagnostics and highlights to skill_runner"
```

### Task 1.3: Add agent resolution and the run() pipeline

**Files:**
- Modify: `lua/parley/skill_runner.lua`
- Modify: `lua/parley/config.lua`
- Reference: `lua/parley/review.lua:426-680` (resolve_review_agent, submit_review)

- [ ] **Step 1: Add config keys**

In `lua/parley/config.lua`, add after the `review_agent` line (~line 372):

```lua
-- Skill system
skill_shortcut = { modes = { "n" }, shortcut = "<C-g>s" },
skill_agent = "Claude-Sonnet",
skills = {},
```

Also change `chat_shortcut_system_prompt` shortcut from `"<C-g>s"` to `"<C-g>p"` (line 339).

- [ ] **Step 2: Add skill discovery function**

In skill_runner.lua, add:

```lua
local _skills_cache = nil

M.discover_skills = function()
    if _skills_cache then return _skills_cache end
    _parley = _parley or require("parley")
    _skills_cache = {}

    -- Find the skills directory relative to this file's location
    local info = debug.getinfo(1, "S")
    local this_dir = vim.fn.fnamemodify(info.source:sub(2), ":h")
    local skills_dir = this_dir .. "/skills"

    local handle = vim.loop.fs_scandir(skills_dir)
    if not handle then return _skills_cache end

    while true do
        local name, typ = vim.loop.fs_scandir_next(handle)
        if not name then break end
        if typ == "directory" then
            local ok, skill = pcall(require, "parley.skills." .. name)
            if ok and type(skill) == "table" and skill.name then
                -- Check if disabled via config
                local disabled = false
                for _, cfg in ipairs(_parley.config.skills or {}) do
                    if cfg.name == skill.name and cfg.disable then
                        disabled = true
                        break
                    end
                end
                if not disabled then
                    -- Store the directory path for SKILL.md resolution
                    skill._dir = skills_dir .. "/" .. name
                    _skills_cache[skill.name] = skill
                end
            end
        end
    end
    return _skills_cache
end

M.get_skill = function(name)
    local skills = M.discover_skills()
    return skills[name]
end

M.list_skills = function()
    local skills = M.discover_skills()
    local list = {}
    for _, skill in pairs(skills) do
        table.insert(list, skill)
    end
    table.sort(list, function(a, b) return a.name < b.name end)
    return list
end
```

- [ ] **Step 3: Add resolve_agent function**

```lua
M.resolve_agent = function(skill)
    _parley = _parley or require("parley")

    -- Priority 1: user per-skill config
    for _, cfg in ipairs(_parley.config.skills or {}) do
        if cfg.name == skill.name and cfg.agent then
            local agent = _parley.get_agent(cfg.agent)
            if agent then return agent end
        end
    end

    -- Priority 1b: deprecated review_agent fallback
    if skill.name == "review" and _parley.config.review_agent then
        local agent = _parley.get_agent(_parley.config.review_agent)
        if agent then return agent end
    end

    -- Priority 2: skill definition default
    if skill.agent then
        local agent = _parley.get_agent(skill.agent)
        if agent then return agent end
    end

    -- Priority 3: global skill_agent config
    if _parley.config.skill_agent then
        local agent = _parley.get_agent(_parley.config.skill_agent)
        if agent then return agent end
    end

    -- Priority 4: first tool-capable agent
    for _, name in ipairs(_parley._agents or {}) do
        local agent = _parley.agents[name]
        if agent and (agent.provider == "anthropic" or agent.provider == "cliproxyapi") then
            return agent
        end
    end

    return nil
end
```

- [ ] **Step 4: Add the run() function**

This is the generalized version of `submit_review`. Copy the structure from review.lua:465-680, replacing review-specific logic with skill hooks.

```lua
local _in_flight = {}
local MAX_RESUBMITS = 3

M.run = function(buf, skill, args, _resubmit_count)
    _parley = _parley or require("parley")
    _resubmit_count = _resubmit_count or 0

    if _resubmit_count > MAX_RESUBMITS then
        _parley.logger.warning("Skill " .. skill.name .. ": max resubmits reached")
        return
    end

    if _in_flight[buf] then
        _parley.logger.warning("Skill: already in progress for this buffer")
        return
    end

    local file_path = vim.api.nvim_buf_get_name(buf)
    if file_path == "" then
        _parley.logger.warning("Skill: buffer has no file path")
        return
    end

    -- Step 1: pre_submit hook
    if skill.pre_submit then
        local ok, err = skill.pre_submit(buf, args)
        if ok == false then
            _parley.logger.warning("Skill " .. skill.name .. ": " .. (err or "pre_submit rejected"))
            return
        end
    end

    -- Step 2: save if modified
    if vim.bo[buf].modified then
        vim.api.nvim_buf_call(buf, function() vim.cmd("write") end)
    end

    -- Step 3: read buffer content
    local lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
    local content = table.concat(lines, "\n")

    -- Step 4: build system prompt
    local skill_md_path = skill._dir .. "/SKILL.md"
    local f = io.open(skill_md_path, "r")
    if not f then
        _parley.logger.error("Skill " .. skill.name .. ": SKILL.md not found at " .. skill_md_path)
        return
    end
    local skill_md = f:read("*a")
    f:close()

    local system_prompt
    if type(skill.system_prompt) == "function" then
        system_prompt = skill.system_prompt(args, file_path, content, skill_md)
    else
        system_prompt = skill_md
    end

    -- Step 5: resolve agent
    local agent = M.resolve_agent(skill)
    if not agent then
        _parley.logger.error("No tool-capable agent available for skill " .. skill.name)
        return
    end

    -- Step 6: prepare payload
    local dispatcher = _parley.dispatcher
    local messages = {
        { role = "system", content = system_prompt },
        { role = "user", content = "Please edit this document (file: " .. file_path .. "):\n\n" .. content },
    }
    local payload = dispatcher.prepare_payload(messages, agent.model, agent.provider)
    payload.tools = payload.tools or {}
    table.insert(payload.tools, {
        name = M.REVIEW_EDIT_TOOL.name,
        description = M.REVIEW_EDIT_TOOL.description,
        input_schema = M.REVIEW_EDIT_TOOL.input_schema,
    })

    -- Clear previous decorations
    M.clear_decorations(buf)

    _parley.logger.info("Running " .. skill.name .. "...")

    local original_content = content
    local tasker = require("parley.tasker")
    local providers = require("parley.providers")

    _in_flight[buf] = true
    local chars_received = 0
    local last_progress = 0

    -- Step 7: headless LLM call
    dispatcher.query(
        nil, agent.provider, payload,
        function(_qid, chunk)
            if chunk then
                chars_received = chars_received + #chunk
                if chars_received - last_progress >= 500 then
                    last_progress = chars_received
                    vim.schedule(function()
                        _parley.logger.info("Running " .. skill.name .. "... (" .. chars_received .. " chars)")
                    end)
                end
            end
        end,
        function(qid)
            vim.schedule(function()
                _in_flight[buf] = nil

                -- Step 8: extract tool calls
                local qt = tasker.get_query(qid)
                if not qt then
                    _parley.logger.error("Skill " .. skill.name .. ": query not found")
                    return
                end

                local raw_response = qt.raw_response or ""
                local tool_calls = providers.decode_anthropic_tool_calls_from_stream(raw_response)

                local review_call = nil
                for _, call in ipairs(tool_calls) do
                    if call.name == "review_edit" then
                        review_call = call
                        break
                    end
                end

                if not review_call then
                    _parley.logger.warning("Skill " .. skill.name .. ": agent returned no edits")
                    return
                end

                local input = review_call.input or {}
                local edits = input.edits
                if type(edits) ~= "table" or #edits == 0 then
                    _parley.logger.warning("Skill " .. skill.name .. ": agent returned empty edits")
                    return
                end

                -- Step 9: apply edits
                local result = M.apply_edits(file_path, edits)
                if not result.ok then
                    _parley.logger.error("Skill " .. skill.name .. ": " .. result.msg)
                    return
                end

                -- Step 10: reload buffer
                pcall(vim.cmd, "checktime")

                -- Step 11: display
                local new_lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
                local new_content = table.concat(new_lines, "\n")
                M.highlight_edits(buf, result.applied, new_content)
                M.attach_diagnostics(buf, result.applied, original_content)

                _parley.logger.info("Skill " .. skill.name .. ": applied " .. #result.applied .. " edit(s)")

                -- Step 12: post_apply hook
                if skill.post_apply then
                    skill.post_apply(buf, args, result, new_content, _resubmit_count)
                end
            end)
        end,
        nil
    )
end
```

- [ ] **Step 5: Run all tests**

Run: `make test-unit`
Expected: PASS

- [ ] **Step 6: Commit**

```bash
git add lua/parley/skill_runner.lua lua/parley/config.lua
git commit -m "feat(skill): add discovery, agent resolution, and run() pipeline"
```

---

## Milestone 2: Port review as a skill

### Task 2.1: Create review skill folder

**Files:**
- Create: `lua/parley/skills/review/init.lua`
- Create: `lua/parley/skills/review/SKILL.md`
- Reference: `lua/parley/review.lua:256-285` (system prompts), `lua/parley/review.lua:24-154` (marker parsing), `lua/parley/review.lua:395-417` (quickfix)

- [ ] **Step 1: Create SKILL.md**

Move `SYSTEM_PREAMBLE` content from review.lua into `lua/parley/skills/review/SKILL.md`. Add section markers for edit levels:

```markdown
You are a collaborative document editor. The user has annotated their markdown document with review comments using ㊷[comment] markers.

(... full SYSTEM_PREAMBLE content ...)

## LIGHT_EDIT

(... SYSTEM_EDIT_SUFFIX content ...)

## HEAVY_REVISION

(... SYSTEM_REVISE_SUFFIX content ...)
```

- [ ] **Step 2: Create init.lua with skill definition**

```lua
-- lua/parley/skills/review/init.lua
local M = {}

-- (paste parse_marker_sections, find_matching_bracket, in_code_fence,
--  compute_fence_ranges, parse_markers from review.lua:24-154)
-- (paste populate_quickfix from review.lua:395-417)

local skill_runner  -- lazily resolved
local _parley       -- lazily resolved

local function get_runner()
    if not skill_runner then skill_runner = require("parley.skill_runner") end
    return skill_runner
end

local function get_parley()
    if not _parley then _parley = require("parley") end
    return _parley
end

M.skill = {
    name = "review",
    description = "Edit document based on review markers",
    args = {
        { name = "level", description = "Edit intensity",
          complete = function() return { "edit", "revise" } end },
    },

    system_prompt = function(args, file_path, content, skill_md)
        local level = args.level or "edit"
        -- Extract the appropriate section from SKILL.md
        local section_header = level == "edit" and "## LIGHT_EDIT" or "## HEAVY_REVISION"
        local base = skill_md:match("^(.-)## LIGHT_EDIT") or skill_md
        local section = skill_md:match(section_header .. "\n(.-)\n##") or skill_md:match(section_header .. "\n(.+)$") or ""
        return base .. "\n" .. section
    end,

    pre_submit = function(buf, args)
        local lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
        local markers = M.parse_markers(lines)

        if #markers == 0 then
            get_runner().clear_decorations(buf)
            vim.fn.setqflist({}, "r")
            pcall(vim.cmd, "cclose")
            get_parley().logger.info("Review: complete — no markers found")
            return false, "no markers"
        end

        local pending = {}
        for _, marker in ipairs(markers) do
            if not marker.ready then table.insert(pending, marker) end
        end

        if #pending > 0 then
            M.populate_quickfix(buf, pending, "pending")
            return false, #pending .. " marker(s) need your response"
        end

        -- Clear stale quickfix
        vim.fn.setqflist({}, "r")
        pcall(vim.cmd, "cclose")
        return true
    end,

    post_apply = function(buf, args, result, new_content, resubmit_count)
        local new_lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
        local remaining = M.parse_markers(new_lines)
        if #remaining == 0 then
            get_parley().logger.info("Review: all comments addressed")
            return
        end

        local has_questions = false
        for _, marker in ipairs(remaining) do
            if not marker.ready then
                has_questions = true
                break
            end
        end

        if has_questions then
            M.populate_quickfix(buf, remaining, "pending")
            get_parley().logger.info("Review: agent has follow-up questions")
        elseif (resubmit_count or 0) < 3 then
            get_parley().logger.info("Review: " .. #remaining .. " marker(s) remain, resubmitting...")
            get_runner().run(buf, M.skill, args, (resubmit_count or 0) + 1)
        end
    end,
}

-- Export marker parsing for highlighter.lua
M.parse_markers = nil  -- (will be set after function definitions above)
M._parse_marker_sections = nil  -- (for highlighter.lua backward compat)
M.populate_quickfix = nil

-- Keybindings for ㊷ marker insertion (buffer-local, called from init.lua)
M.setup_keymaps = function(buf)
    -- (copy from review.lua:688-758, but change submit calls to use skill_runner)
    -- <C-g>vi: insert marker (keep as-is)
    -- <C-g>ve: skill_runner.run(buf, M.skill, {level="edit"})
    -- <C-g>vr: skill_runner.run(buf, M.skill, {level="revise"})
end

return M
```

- [ ] **Step 3: Run tests**

Run: `make test-unit`
Expected: PASS

- [ ] **Step 4: Commit**

```bash
git add lua/parley/skills/review/init.lua lua/parley/skills/review/SKILL.md
git commit -m "feat(skill): create review skill with marker parsing and hooks"
```

### Task 2.2: Wire review skill into init.lua, update review.lua

**Files:**
- Modify: `lua/parley/init.lua:2187-2190`
- Modify: `lua/parley/review.lua`
- Modify: `lua/parley/highlighter.lua:270`

- [ ] **Step 1: Update init.lua to use review skill for keymaps**

Change `setup_markdown_keymaps` (init.lua ~line 2187-2190):

```lua
M.setup_markdown_keymaps = function(buf)
    local review_skill = require("parley.skills.review")
    review_skill.setup_keymaps(buf)
    -- ... rest of markdown keymaps
```

- [ ] **Step 2: Update review.lua to delegate to skill_runner**

review.lua becomes a thin shim:
- Remove `compute_edits`, `apply_edits`, `highlight_edits`, `attach_diagnostics`, `clear_review_decorations`, `ensure_namespaces`, `REVIEW_EDIT_TOOL`, `resolve_review_agent`, `submit_review`, `SYSTEM_*` constants
- Keep backward-compatible exports that delegate:
  - `M.parse_markers` → `require("parley.skills.review").parse_markers`
  - `M._parse_marker_sections` → `require("parley.skills.review")._parse_marker_sections`
  - `M.compute_edits` → `require("parley.skill_runner").compute_edits`
  - `M.apply_edits` → `require("parley.skill_runner").apply_edits`
  - `M.submit_review` → calls `skill_runner.run` with review skill
  - `M.setup_keymaps` → `require("parley.skills.review").setup_keymaps`

- [ ] **Step 3: Update highlighter.lua**

Change line 270 from `review._parse_marker_sections` to import from the review skill module.

- [ ] **Step 4: Run all tests including review_spec**

Run: `make test-unit`
Expected: PASS — review_spec.lua tests should still pass since review.lua re-exports the same functions.

- [ ] **Step 5: Manual verification**

Open a markdown file with ㊷ markers. Verify:
- `<C-g>vi` inserts marker
- `<C-g>ve` triggers skill_runner.run with review skill
- Edits appear with highlights and diagnostics

- [ ] **Step 6: Commit**

```bash
git add lua/parley/init.lua lua/parley/review.lua lua/parley/highlighter.lua
git commit -m "refactor(skill): wire review through skill_runner, review.lua becomes shim"
```

---

## Milestone 3: Skill picker UI

### Task 3.1: Extend float_picker with set_items

**Files:**
- Modify: `lua/parley/float_picker.lua`

- [ ] **Step 1: Check existing update API**

float_picker.open() already returns `{update = function(new_items, new_tag_bar_tags)}` (line ~541 of float_picker.lua). Check if this `update` function replaces items and re-renders. If it does, we may not need any extension.

Read float_picker.lua to understand the returned `update` function.

- [ ] **Step 2: Extend if needed**

If the existing `update` function handles item replacement, we just need to add a `set_query(text)` method to the returned handle. If not, add `set_items` that replaces the internal items list and re-filters/re-renders.

- [ ] **Step 3: Test manually**

Open a picker, call update with different items, verify display updates.

- [ ] **Step 4: Commit**

```bash
git add lua/parley/float_picker.lua
git commit -m "feat(float_picker): extend update API for skill picker"
```

### Task 3.2: Create skill_picker.lua

**Files:**
- Create: `lua/parley/skill_picker.lua`

- [ ] **Step 1: Create the picker module**

```lua
-- lua/parley/skill_picker.lua
-- Skill picker UI: <C-g>s entry point with cascading typeahead.

local M = {}
local _parley

M.setup = function(parley)
    _parley = parley
end

M.open = function()
    _parley = _parley or require("parley")
    local skill_runner = require("parley.skill_runner")
    local float_picker = _parley.float_picker

    local skills = skill_runner.list_skills()
    local buf = vim.api.nvim_get_current_buf()

    -- State machine
    local state = {
        phase = "skill",     -- "skill" | "arg" | "ready"
        skill = nil,         -- selected skill
        args = {},           -- collected args
        arg_index = 0,       -- current arg position (0 = selecting skill)
    }

    -- Build skill items
    local function skill_items()
        local items = {}
        for _, skill in ipairs(skills) do
            table.insert(items, {
                display = skill.name .. " — " .. skill.description,
                search_text = skill.name,
                value = skill,
            })
        end
        return items
    end

    -- Build arg items for current position
    local function arg_items()
        local skill = state.skill
        if not skill or not skill.args then return {} end
        local arg_def = skill.args[state.arg_index]
        if not arg_def or not arg_def.complete then return {} end
        local values = arg_def.complete()
        local items = {}
        for _, v in ipairs(values) do
            table.insert(items, {
                display = v,
                search_text = v,
                value = v,
            })
        end
        return items
    end

    local picker_handle

    local function on_select(item)
        if state.phase == "skill" then
            state.skill = item.value
            state.phase = "arg"
            state.arg_index = 1
            state.args = {}

            -- If no args, execute immediately
            if not state.skill.args or #state.skill.args == 0 then
                skill_runner.run(buf, state.skill, state.args)
                return
            end

            -- Show arg completions
            if picker_handle then
                picker_handle.update(arg_items())
            end
        elseif state.phase == "arg" then
            local arg_def = state.skill.args[state.arg_index]
            state.args[arg_def.name] = item.value
            state.arg_index = state.arg_index + 1

            -- Check if all args collected
            if state.arg_index > #state.skill.args then
                skill_runner.run(buf, state.skill, state.args)
                return
            end

            -- Show next arg completions
            if picker_handle then
                picker_handle.update(arg_items())
            end
        end
    end

    picker_handle = float_picker.open({
        title = "Skills",
        items = skill_items(),
        on_select = on_select,
        on_cancel = function() end,
        anchor = "bottom",
    })
end

return M
```

Note: This is a simplified version. The full cascading-in-one-input-line UX described in the spec may require more work on float_picker. Start with this multi-step picker (select skill → select arg1 → select arg2 → run) which achieves the same result with the existing float_picker API. The single-input-line UX can be refined in a follow-up.

- [ ] **Step 2: Wire into init.lua**

Add the `<C-g>s` global keybinding registration in init.lua setup, near the other global shortcuts (~line 526):

```lua
if M.config.skill_shortcut then
    for _, mode in ipairs(M.config.skill_shortcut.modes) do
        vim.keymap.set(mode, M.config.skill_shortcut.shortcut, function()
            require("parley.skill_picker").open()
        end, { silent = true, desc = "Open Skill Picker" })
    end
end
```

Also remap system prompt shortcut from `<C-g>s` to `<C-g>p` — update the line that registers `chat_shortcut_system_prompt`.

- [ ] **Step 3: Manual verification**

Start nvim, press `<C-g>s`:
- Picker shows "review" skill
- Select review → shows "edit" / "revise"
- Select "edit" → runs review on current buffer

- [ ] **Step 4: Commit**

```bash
git add lua/parley/skill_picker.lua lua/parley/init.lua
git commit -m "feat(skill): add skill picker with <C-g>s keybinding"
```

---

## Milestone 4: Voice-apply skill

### Task 4.1: Create voice-apply skill

**Files:**
- Create: `lua/parley/skills/voice_apply/init.lua`
- Create: `lua/parley/skills/voice_apply/SKILL.md`

- [ ] **Step 1: Create SKILL.md**

Based on ariadne's voice-apply skill and the spec:

```markdown
You are a voice editor. Rewrite the document to match a specific writing voice, guided by the style guide provided below.

## Process

1. **Content audit.** Read the document for structure and argument. Note which sections feel off-voice. Do not change anything yet.
2. **Voice rewrite.** Rewrite the document applying the style guide. Preserve the content, structure, and meaning. Change the voice: sentence structure, word choices, openings, closings, transitions, emphasis patterns.

## Rules

- **Preserve content.** Change voice, not substance. Don't add or remove arguments, examples, or sections unless the style guide specifically calls for it.
- **Be specific.** When applying a style pattern, you should be able to point to a rule in the style guide that justifies the change. Use the explain field to cite the rule.
- **Don't over-apply.** Not every sentence needs every pattern. A document that hits every pattern in every paragraph will feel forced.
- **Respect the document type.** A letter to a CEO and a blog post have different constraints even in the same voice.

You MUST use the review_edit tool for ALL changes. Include all changes in a single review_edit call.
```

- [ ] **Step 2: Create init.lua**

```lua
-- lua/parley/skills/voice_apply/init.lua

local function scan_voice_slugs()
    local dir = vim.fn.expand("~/.personal")
    local slugs = {}
    local handle = vim.loop.fs_scandir(dir)
    if not handle then return slugs end
    while true do
        local name = vim.loop.fs_scandir_next(handle)
        if not name then break end
        local slug = name:match("^(.+)-writing%-style%.md$")
        if slug then table.insert(slugs, slug) end
    end
    table.sort(slugs)
    return slugs
end

return {
    name = "voice-apply",
    description = "Rewrite to match a personal writing voice",
    args = {
        { name = "slug", description = "Voice style",
          complete = scan_voice_slugs },
    },
    system_prompt = function(args, file_path, content, skill_md)
        local style_path = vim.fn.expand("~/.personal/" .. args.slug .. "-writing-style.md")
        local f = io.open(style_path, "r")
        if not f then
            error("Voice style file not found: " .. style_path)
        end
        local style = f:read("*a")
        f:close()
        return skill_md .. "\n\n## Voice Style Guide\n\n" .. style
    end,
}
```

- [ ] **Step 3: Manual verification**

Open a markdown document. Press `<C-g>s`, select `voice-apply`, select `xian`. Verify the document is rewritten with voice edits shown as highlights and diagnostics.

- [ ] **Step 4: Commit**

```bash
git add lua/parley/skills/voice_apply/
git commit -m "feat(skill): add voice-apply skill"
```

---

## Milestone 5: Cleanup and verification

### Task 5.1: Run full test suite and verify no regressions

- [ ] **Step 1: Run all tests**

Run: `make test`
Expected: All tests pass, including review_spec.lua

- [ ] **Step 2: Manual end-to-end verification**

1. Start nvim in a parley-enabled repo
2. `<C-g>s` → picker shows "review" and "voice-apply"
3. Review flow: add ㊷[marker] to a .md file, run `/review edit`, verify edits + diagnostics
4. Voice flow: open a .md file, run `/voice-apply xian`, verify voice edits
5. Fast paths: `<C-g>ve` and `<C-g>vr` still work
6. `<C-g>vi` still inserts markers
7. `<C-g>p` opens system prompt picker (moved from `<C-g>s`)

- [ ] **Step 3: Commit any final fixes**

### Task 5.2: Update atlas

- [ ] **Step 1: Update atlas/index.md with skill system entry**
- [ ] **Step 2: Create atlas/skill-system.md describing the architecture**
- [ ] **Step 3: Commit**
