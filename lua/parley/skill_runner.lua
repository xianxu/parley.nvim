-- skill_runner.lua — Shared pipeline for AI-powered buffer editing skills.
--
-- A skill is an AI tool that edits the current buffer. All skills share:
--   - The review_edit tool (old_string → new_string + explain)
--   - compute_edits / apply_edits for applying changes
--   - highlight_edits / attach_diagnostics for showing results
--   - A common run() pipeline: prompt → LLM → edits → display

local M = {}

local _parley  -- lazily resolved

local function get_parley()
    if not _parley then _parley = require("parley") end
    return _parley
end

--------------------------------------------------------------------------------
-- Tool definition (shared by all skills)
--------------------------------------------------------------------------------

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

--------------------------------------------------------------------------------
-- Pure edit computation (extracted from review.lua)
--------------------------------------------------------------------------------

--- Pure: validate and apply edits to a content string.
--- DELEGATES to parley.skill_edits — the single source of the batch-edit
--- transform (#128 M2). Kept here as a thin pass-through until skill_runner is
--- deleted in M4, so the v1 path + its spec stay green.
--- @param content string  file content
--- @param edits table[]  list of {old_string, new_string, explain}
--- @return table  {ok=bool, msg=string, content=string|nil, applied=table[]}
function M.compute_edits(content, edits)
    return require("parley.skill_edits").compute_edits(content, edits)
end

--- IO boundary: read file, apply edits, write file.
--- @param file_path string
--- @param edits table[]  list of {old_string, new_string, explain}
--- @return table  {ok=bool, msg=string, applied=table[]}
function M.apply_edits(file_path, edits)
    local f, err = io.open(file_path, "r")
    if not f then
        return { ok = false, msg = "cannot open: " .. (err or file_path), applied = {} }
    end
    local content = f:read("*a")
    f:close()

    local result = M.compute_edits(content, edits)
    if not result.ok then
        return result
    end

    local wf, werr = io.open(file_path, "w")
    if not wf then
        return { ok = false, msg = "cannot write: " .. (werr or file_path), applied = {} }
    end
    wf:write(result.content)
    wf:close()

    return {
        ok = true,
        msg = result.msg,
        applied = result.applied,
    }
end

--------------------------------------------------------------------------------
-- Diagnostics and highlights — DELEGATE to parley.skill_render (#128 M3),
-- the single source. Thin pass-throughs kept until skill_runner is deleted in M4
-- (so the v1 path + its spec stay green).
--------------------------------------------------------------------------------

function M.clear_decorations(buf)
    return require("parley.skill_render").clear_decorations(buf)
end

function M.attach_diagnostics(buf, edits, original_content)
    return require("parley.skill_render").attach_diagnostics(buf, edits, original_content)
end

function M.highlight_edits(buf, edits, new_content)
    return require("parley.skill_render").highlight_edits(buf, edits, new_content)
end

--------------------------------------------------------------------------------
-- Skill discovery
--------------------------------------------------------------------------------

local _skills_cache = nil

M.discover_skills = function()
    if _skills_cache then return _skills_cache end
    local parley = get_parley()
    _skills_cache = {}

    local info = debug.getinfo(1, "S")
    local this_dir = vim.fn.fnamemodify(info.source:sub(2), ":h")
    local skills_dir = this_dir .. "/skills"

    local handle = vim.loop.fs_scandir(skills_dir)
    if not handle then return _skills_cache end

    while true do
        local name, typ = vim.loop.fs_scandir_next(handle)
        if not name then break end
        if typ == "directory" then
            local ok, skill_mod = pcall(require, "parley.skills." .. name)
            if ok and type(skill_mod) == "table" then
                -- Support both { name, ... } and { skill = { name, ... } } shapes
                local skill = skill_mod.skill or skill_mod
                if skill.name then
                    local disabled = false
                    for _, cfg in ipairs(parley.config.skills or {}) do
                        if cfg.name == skill.name and cfg.disable then
                            disabled = true
                            break
                        end
                    end
                    if not disabled then
                        skill._dir = skills_dir .. "/" .. name
                        skill._module = skill_mod
                        _skills_cache[skill.name] = skill
                    end
                end
            end
        end
    end
    return _skills_cache
end

M.get_skill = function(name)
    return M.discover_skills()[name]
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

--- Reset skill cache (for testing or after config changes).
M.reset_cache = function()
    _skills_cache = nil
end

--------------------------------------------------------------------------------
-- Agent resolution
--------------------------------------------------------------------------------

-- DELEGATES to parley.skill_assembly.resolve_agent — the single source of the
-- agent cascade (#128 M2). Builds the injected deps from the live parley module
-- (the IO boundary) and calls the pure cascade, mirroring the compute_edits
-- delegation. Kept until skill_runner is deleted in M4.
M.resolve_agent = function(skill)
    local parley = get_parley()
    return require("parley.skill_assembly").resolve_agent(skill, {
        config = parley.config,
        get_agent = parley.get_agent,
        agent_names = parley._agents,
        agents = parley.agents,
    })
end

--------------------------------------------------------------------------------
-- Run pipeline
--------------------------------------------------------------------------------

local _in_flight = {}
local MAX_RESUBMITS = 3

--- Test helper: is a skill run in flight for `buf`? (#131 abort-teardown test)
---@param buf number
---@return boolean
function M.is_in_flight(buf)
    return _in_flight[buf] == true
end

--- Run a skill on the current buffer.
--- @param buf number  buffer handle
--- @param skill table  skill definition
--- @param args table  resolved arguments {name=value, ...}
--- @param _resubmit_count number|nil  internal resubmit counter
function M.run(buf, skill, args, _resubmit_count)
    local parley = get_parley()
    _resubmit_count = _resubmit_count or 0

    if _resubmit_count > MAX_RESUBMITS then
        parley.logger.warning("Skill " .. skill.name .. ": max resubmits reached")
        return
    end

    if _in_flight[buf] then
        parley.logger.warning("Skill: already in progress for this buffer")
        return
    end

    local file_path = vim.api.nvim_buf_get_name(buf)
    if file_path == "" then
        parley.logger.warning("Skill: buffer has no file path")
        return
    end

    -- Step 1: pre_submit hook
    if skill.pre_submit then
        local ok, err = skill.pre_submit(buf, args)
        if ok == false then
            if err then parley.logger.warning("Skill " .. skill.name .. ": " .. err) end
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
    -- Resolve skill directory if not set (e.g., fast-path calls bypassing discovery)
    if not skill._dir and skill._module then
        local mod_info = debug.getinfo(1, "S")
        -- fallback: scan from skill_runner.lua's directory
        local runner_dir = vim.fn.fnamemodify(mod_info.source:sub(2), ":h")
        local name_under = skill.name:gsub("-", "_")
        skill._dir = runner_dir .. "/skills/" .. name_under
    end
    if not skill._dir then
        -- Last resort: find from the skills directory
        local info = debug.getinfo(1, "S")
        local runner_dir = vim.fn.fnamemodify(info.source:sub(2), ":h")
        local name_under = skill.name:gsub("-", "_")
        local candidate = runner_dir .. "/skills/" .. name_under
        if vim.fn.isdirectory(candidate) == 1 then
            skill._dir = candidate
        end
    end

    local skill_md
    if skill._dir then
        local skill_md_path = skill._dir .. "/SKILL.md"
        local f = io.open(skill_md_path, "r")
        if not f then
            parley.logger.error("Skill " .. skill.name .. ": SKILL.md not found at " .. skill_md_path)
            return
        end
        skill_md = f:read("*a")
        f:close()
    end

    if not skill_md or skill_md:match("^%s*$") then
        parley.logger.error("Skill " .. skill.name .. ": SKILL.md is empty or not found")
        return
    end

    local system_prompt
    if type(skill.system_prompt) == "function" then
        system_prompt = skill.system_prompt(args, file_path, content, skill_md or "")
    else
        system_prompt = skill_md
    end

    if not system_prompt or system_prompt == "" then
        parley.logger.error("Skill " .. skill.name .. ": no system prompt")
        return
    end

    -- Step 5: resolve agent
    local agent = M.resolve_agent(skill)
    if not agent then
        parley.logger.error("No tool-capable agent available for skill " .. skill.name)
        return
    end

    -- Step 6: prepare payload
    local dispatcher = parley.dispatcher
    local messages = {
        { role = "system", content = system_prompt },
        { role = "user", content = "Please edit this document (file: " .. file_path .. "):\n\n" .. content
            .. "\n\nIMPORTANT: Your response must fit within 100K output tokens. If the document is very large, prioritize the most impactful edits and omit lower-priority ones. The user can re-run the skill to address remaining issues." },
    }
    local payload = dispatcher.prepare_payload(messages, agent.model, agent.provider)
    payload.tools = payload.tools or {}
    table.insert(payload.tools, {
        name = M.REVIEW_EDIT_TOOL.name,
        description = M.REVIEW_EDIT_TOOL.description,
        input_schema = M.REVIEW_EDIT_TOOL.input_schema,
    })
    -- Force the model to use the review_edit tool
    payload.tool_choice = { type = "tool", name = "review_edit" }
    -- Ensure enough tokens for tool call output on large documents
    if not payload.max_tokens or payload.max_tokens < 100000 then
        payload.max_tokens = 100000
    end

    -- Clear previous decorations
    M.clear_decorations(buf)

    parley.logger.info("Running " .. skill.name .. "...")

    local original_content = content
    local tasker = require("parley.tasker")
    local providers = require("parley.providers")

    _in_flight[buf] = true
    local chars_received = 0
    local last_progress = 0

    -- Abort teardown (#131): clear the in-flight guard if the managed cliproxy
    -- can't start, else this buffer's skill runs are blocked forever (the guard
    -- is otherwise only cleared in the qid-coupled on_exit, which never fires).
    local function on_abort(msg)
        _in_flight[buf] = nil
        vim.schedule(function()
            vim.notify("Skill " .. skill.name .. ": " .. tostring(msg), vim.log.levels.WARN)
        end)
    end

    -- Step 7: headless LLM call
    dispatcher.query(
        nil, agent.provider, payload,
        function(_qid, chunk)
            if chunk then
                chars_received = chars_received + #chunk
                if chars_received - last_progress >= 500 then
                    last_progress = chars_received
                    vim.schedule(function()
                        parley.logger.info("Running " .. skill.name .. "... (" .. chars_received .. " chars)")
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
                    parley.logger.error("Skill " .. skill.name .. ": query not found")
                    return
                end

                local raw_response = qt.raw_response or ""
                local tool_calls = providers.decode_anthropic_tool_calls_from_stream(raw_response)
                parley.logger.debug("Skill " .. skill.name .. ": tool_calls count=" .. #tool_calls)

                local review_call = nil
                for _, call in ipairs(tool_calls) do
                    if call.name == "review_edit" then
                        review_call = call
                        break
                    end
                end

                if not review_call then
                    -- Check if response was truncated
                    if raw_response:find('"stop_reason"%s*:%s*"max_tokens"') or raw_response:find('"stop_reason":"max_tokens"') then
                        parley.logger.error("Skill " .. skill.name .. ": response truncated (hit max_tokens). Try on a shorter document or re-run to address remaining edits.")
                    else
                        parley.logger.warning("Skill " .. skill.name .. ": agent returned no edits")
                    end
                    return
                end

                local input = review_call.input or {}
                local edits = input.edits
                if type(edits) ~= "table" or #edits == 0 then
                    parley.logger.warning("Skill " .. skill.name .. ": agent returned empty edits")
                    return
                end

                -- Step 9: apply edits
                local result = M.apply_edits(file_path, edits)
                if not result.ok then
                    parley.logger.error("Skill " .. skill.name .. ": " .. result.msg)
                    return
                end

                -- Step 10: reload buffer
                pcall(vim.cmd, "checktime")

                -- Step 11: display
                local new_lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
                local new_content = table.concat(new_lines, "\n")
                M.highlight_edits(buf, result.applied, new_content)
                M.attach_diagnostics(buf, result.applied, original_content)

                parley.logger.info("Skill " .. skill.name .. ": applied " .. #result.applied .. " edit(s)")

                -- Step 12: post_apply hook
                if skill.post_apply then
                    skill.post_apply(buf, args, result, new_content, _resubmit_count)
                end
            end)
        end,
        nil,
        nil,
        on_abort
    )
end

return M
