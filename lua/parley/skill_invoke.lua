-- parley.skill_invoke — the thin P2 (artifact-workbench) skill driver.
--
-- Drives ONE LLM tool-use exchange on an artifact buffer by REUSING the existing
-- dispatcher layer (`prepare_payload` / `query` / `execute_call`) — a *second*
-- driver alongside the chat loop, NOT a refactor of it (the chat loop is
-- untouched). Replaces skill_runner.run's bespoke pipeline (#128 M3).
--
-- Flow: source the body → build_invocation (pure) → prepare_payload + tool_choice
-- → query (headless) → on_exit: decode tool calls → execute_call each → reload
-- the artifact buffer → render (skill_render). An `opts.on_done` hook lets a
-- caller (review) run post-apply logic (its resubmit loop).
--
-- P2 binds edits to THE artifact: a `propose_edits` call's `file_path` is set to
-- the artifact's path (the artifact is the known, human-chosen target — the
-- model picks edits, not the file). cwd-scope for that call is the artifact's
-- own dir, so editing an artifact anywhere passes the dispatcher guard while
-- still flowing through the uniform `execute_call` path.

local M = {}

local function parley()
    return require("parley")
end

-- Build the diagnostics/highlight edit list for a propose_edits call from its
-- input + the pre-edit content (positions for INFO diagnostics).
local function render_propose_edits(buf, call, original, new_content)
    local skill_render = require("parley.skill_render")
    local edits = {}
    for _, e in ipairs((call.input or {}).edits or {}) do
        local pos = original:find(e.old_string, 1, true)
        if pos then
            table.insert(edits, { pos = pos, explain = e.explain, new_string = e.new_string })
        end
    end
    skill_render.attach_diagnostics(buf, edits, original)
    skill_render.highlight_edits(buf, edits, new_content)
end

-- Reload the artifact buffer from its (now-edited) file. Uses `:edit!` (a
-- command, run with the buffer current) rather than nvim_buf_set_lines so buffer
-- mutation stays out of this module — the #90 arch boundary keeps direct
-- line-setting in buffer_edit.lua. Deterministic (synchronous force-reload).
local function reload_buffer(buf)
    vim.api.nvim_buf_call(buf, function()
        pcall(vim.cmd, "silent edit!")
    end)
end

--- Invoke a skill on an artifact buffer (one exchange).
--- @param buf number the artifact buffer
--- @param manifest table SkillManifest
--- @param args table|nil completable-arg values
--- @param opts table|nil { manual = boolean? (default true), on_done = fun(result)? }
function M.invoke(buf, manifest, args, opts)
    opts = opts or {}
    local manual = opts.manual
    if manual == nil then
        manual = true
    end

    local p = parley()
    local llm = require("parley.dispatcher") -- LLM dispatcher: prepare_payload / query
    local tools_dispatcher = require("parley.tools.dispatcher") -- tool dispatcher: execute_call
    local providers = require("parley.providers")
    local tasker = require("parley.tasker")
    local tools_registry = require("parley.tools")
    local assembly = require("parley.skill_assembly")
    local skill_render = require("parley.skill_render")

    local artifact_path = vim.api.nvim_buf_get_name(buf)

    -- Sync file == buffer so edits compute + apply against the same content.
    if vim.bo[buf].modified then
        vim.api.nvim_buf_call(buf, function()
            pcall(vim.cmd, "silent write")
        end)
    end

    local original = table.concat(vim.api.nvim_buf_get_lines(buf, 0, -1, false), "\n")
    local body = manifest.source({ args = args or {}, repo_root = p.config.repo_root })
    local inv = assembly.build_invocation(manifest, { body = body, document = original, manual = manual })

    local agent = assembly.resolve_agent(manifest, {
        config = p.config,
        get_agent = p.get_agent,
        agent_names = p._agents,
        agents = p.agents,
    })
    if not agent then
        p.logger.warning("skill " .. tostring(manifest.name) .. ": no tool-capable agent resolved")
        if opts.on_done then
            opts.on_done({ ok = false, msg = "no agent" })
        end
        return
    end

    local payload = llm.prepare_payload(inv.messages, agent.model, agent.provider, inv.tools)
    if inv.tool_choice then
        payload.tool_choice = inv.tool_choice
    end

    skill_render.clear_decorations(buf)

    local cwd = vim.fn.fnamemodify(artifact_path, ":h")

    llm.query(
        nil, -- headless: no streaming buffer insertion
        agent.provider,
        payload,
        function() end, -- handler (headless)
        function(qid) -- on_exit
            vim.schedule(function()
                local qt = tasker.get_query(qid) or {}
                local calls = providers.decode_anthropic_tool_calls_from_stream(qt.raw_response or "")
                local results = {}
                for _, call in ipairs(calls) do
                    if call.name == "propose_edits" then
                        call.input = call.input or {}
                        call.input.file_path = artifact_path -- artifact-bound
                    end
                    table.insert(results, tools_dispatcher.execute_call(call, tools_registry, { cwd = cwd }))
                end
                reload_buffer(buf)
                local new_content = table.concat(vim.api.nvim_buf_get_lines(buf, 0, -1, false), "\n")
                for _, call in ipairs(calls) do
                    if call.name == "propose_edits" then
                        render_propose_edits(buf, call, original, new_content)
                    end
                end
                if opts.on_done then
                    opts.on_done({ ok = true, calls = calls, results = results })
                end
            end)
        end,
        nil,
        nil,
        function(msg) -- on_abort
            p.logger.error("skill " .. tostring(manifest.name) .. " abort: " .. tostring(msg))
            if opts.on_done then
                opts.on_done({ ok = false, msg = tostring(msg) })
            end
        end
    )
end

return M
