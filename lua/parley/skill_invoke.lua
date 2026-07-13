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

-- Per-buffer re-entrancy guard: one skill exchange per artifact buffer at a time
-- (a rapid double-trigger would otherwise launch concurrent exchanges).
local _in_flight = {}
-- Per-buffer generation counter. Each invoke bumps it; on_exit/on_abort carry
-- their gen and no-op if a newer exchange superseded them — so a cancelled
-- (killed) query's late callback can't clobber the new one's state. (#133)
local _gen = {}
-- The exact-once terminal owned by the active generation for each buffer.
local _terminals = {}

--- Is a skill exchange in flight for `buf`? Cleared on on_exit/on_abort, so an
--- abort that can't start the query doesn't block the buffer forever (#131).
--- @param buf number
--- @return boolean
function M.is_in_flight(buf)
    return _in_flight[buf] == true
end

--- Cancel an in-flight exchange for `buf`: invalidate it (bump the generation so
--- its callback no-ops), clear the in-flight flag, and stop the running query.
--- `tasker.stop` halts in-flight queries (review is headless, so this is the
--- review job). Lets a new round supersede a stuck/slow one (#133).
--- @param buf number
function M.cancel(buf)
    local finish = _terminals[buf]
    if finish then
        finish({ ok = false, msg = "cancelled" }, false)
    end
    _gen[buf] = (_gen[buf] or 0) + 1
    _in_flight[buf] = nil
    pcall(function() require("parley.tasker").stop() end)
end

local function parley()
    return require("parley")
end

-- Build the diagnostics/highlight edit list for a propose_edits call from its
-- input + the pre-edit content (positions for INFO diagnostics).
local function render_propose_edits(buf, call, original, new_content)
    local skill_render = require("parley.skill_render")
    local edits = {}
    -- Guard against a malformed call where `edits` isn't an array (e.g. a model
    -- that stringified it and coercion failed, or a truncated response) — the
    -- tool already surfaced its own error; the renderer must not crash. #133
    local edits_in = (call.input or {}).edits
    if type(edits_in) ~= "table" then
        edits_in = {}
    end
    for _, e in ipairs(edits_in) do
        local pos = original:find(e.old_string, 1, true)
        if pos then
            table.insert(edits, {
                pos = pos,
                explain = e.explain,
                new_string = e.new_string,
                -- A pure deletion (empty new_string) is oriented by its gutter
                -- "why" diagnostic, not a highlight (skill_render skips it). #133
                kind = (e.new_string == nil or e.new_string == "") and "delete" or "edit",
            })
        end
    end
    skill_render.attach_diagnostics(buf, edits, original)
    skill_render.highlight_edits(buf, edits, new_content)
    -- Return the decoration set so the caller can journal it (M3 #133).
    return edits
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
--- @param opts table|nil { manual=boolean?, no_reload=boolean?, document=string?,
---   detached_progress=boolean?, on_terminal=fun(result)?, on_done=fun(result)? }
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

    local function deliver_attempt(result, deliver_done)
        if opts.on_terminal then
            local ok = pcall(opts.on_terminal, result)
            if not ok then p.logger.error("skill terminal callback failed") end
        end
        if deliver_done and opts.on_done then
            local ok = pcall(opts.on_done, result)
            if not ok then p.logger.error("skill completion callback failed") end
        end
    end

    if _in_flight[buf] then
        p.logger.warning("skill " .. tostring(manifest.name) .. ": already running on this buffer")
        deliver_attempt({ ok = false, msg = "already running" }, true)
        return
    end

    -- This exchange's generation; on_exit/on_abort no-op if superseded (#133).
    local gen = (_gen[buf] or 0) + 1
    _gen[buf] = gen
    local finished = false
    local detached_progress = opts.detached_progress ~= false
    local progress_started = false
    local function finish(result, deliver_done)
        if finished then return false end
        finished = true
        if progress_started then
            pcall(function() require("parley.progress").stop() end)
            progress_started = false
        end
        if _terminals[buf] == finish then
            _terminals[buf] = nil
            _in_flight[buf] = nil
        end
        deliver_attempt(result, deliver_done)
        return true
    end
    _terminals[buf] = finish

    if not vim.api.nvim_buf_is_valid(buf) then
        finish({ ok = false, msg = "buffer invalid" }, false)
        return
    end
    local ok_path, artifact_path = pcall(vim.api.nvim_buf_get_name, buf)
    if not ok_path or artifact_path == "" then
        p.logger.warning("skill " .. tostring(manifest.name) .. ": buffer has no file — open the artifact first")
        finish({ ok = false, msg = "buffer has no file" }, true)
        return
    end

    -- Sync file == buffer so edits compute + apply against the same content.
    -- A read-only skill (opts.no_reload — e.g. define, #161) makes no edits, so
    -- it must NOT persist the user's in-progress buffer to disk.
    if vim.bo[buf].modified and not opts.no_reload then
        vim.api.nvim_buf_call(buf, function()
            pcall(vim.cmd, "silent write")
        end)
    end

    local original = table.concat(vim.api.nvim_buf_get_lines(buf, 0, -1, false), "\n")
    -- source(ctx) does IO (reads SKILL.md / style guides) and can fail — e.g.
    -- voice_apply with a missing style file. Route the failure through the SAME
    -- on_done({ok=false}) channel as the other early-outs (no file / no agent)
    -- rather than throwing a raw Lua error; skill_invoke is the generic P2 driver.
    local ok_src, body = pcall(manifest.source, { args = args or {}, repo_root = p.config.repo_root })
    if not ok_src then
        p.logger.error("skill " .. tostring(manifest.name) .. ": source failed: " .. tostring(body))
        finish({ ok = false, msg = "source failed: " .. tostring(body) }, true)
        return
    end
    -- opts.document lets a caller send a bounded context (e.g. define's enclosing
    -- exchange) instead of the whole buffer; defaults to the buffer content.
    local inv = assembly.build_invocation(manifest, { body = body, document = opts.document or original, manual = manual })

    local agent = assembly.resolve_agent(manifest, {
        config = p.config,
        get_agent = p.get_agent,
        agent_names = p._agents,
        agents = p.agents,
    })
    if not agent then
        p.logger.warning("skill " .. tostring(manifest.name) .. ": no tool-capable agent resolved")
        finish({ ok = false, msg = "no agent" }, true)
        return
    end

    local payload = llm.prepare_payload(inv.messages, agent.model, agent.provider, inv.tools)
    if inv.tool_choice then
        payload.tool_choice = inv.tool_choice
    end
    -- Large-document tool output needs headroom: a multi-edit propose_edits batch
    -- echoes old/new/explain per edit and easily exceeds the default (4096),
    -- truncating the tool JSON → empty decode. (Was skill_runner's explicit bump.)
    payload.max_tokens = math.max(payload.max_tokens or 0, 100000)

    skill_render.clear_decorations(buf)

    local neighborhood = require("parley.neighborhood")
    local root_policy = neighborhood.policy_for_buf(buf)
        or neighborhood.policy_from_roots(vim.fn.fnamemodify(artifact_path, ":h"), nil, {})
    local cwd = root_policy.write_root

    _in_flight[buf] = true
    -- Detached progress bar: this is a ~30s headless op, so show a running cue
    -- (the first substantive-progress surface, #133 M7). Stopped on exit/abort.
    if detached_progress then
        progress_started = require("parley.progress").start(
            "Parley " .. tostring(manifest.name) .. " running…")
    end
    local ok_query = pcall(llm.query,
        nil, -- headless: no streaming buffer insertion
        agent.provider,
        payload,
        function() end, -- handler (headless)
        function(qid) -- on_exit
            vim.schedule(function()
                -- Superseded by a newer exchange (the old one was cancelled) →
                -- no-op so we don't reload/re-render or clobber the new state.
                if finished or _gen[buf] ~= gen then
                    return
                end
                if not vim.api.nvim_buf_is_valid(buf) then
                    finish({ ok = false, msg = "buffer invalid" }, false)
                    return
                end
                local function complete()
                    local qt = tasker.get_query(qid) or {}
                    local calls = providers.decode_anthropic_tool_calls_from_stream(qt.raw_response or "")
                    local results = {}
                    local applied = 0
                    local errors = {}
                    for i, call in ipairs(calls) do
                        if call.name == "propose_edits" then
                            call.input = call.input or {}
                            call.input.file_path = artifact_path -- artifact-bound
                            -- Some models emit `edits` as a JSON STRING rather than an
                            -- array; coerce it once here so the batch actually applies
                            -- (and render_propose_edits below gets a table). #133
                            if type(call.input.edits) == "string" then
                                local ok, decoded = pcall(vim.json.decode, call.input.edits)
                                if ok and type(decoded) == "table" then
                                    call.input.edits = decoded
                                end
                            end
                        end
                        results[i] = tools_dispatcher.execute_call(call, tools_registry,
                            { cwd = cwd, root_policy = root_policy,
                              page_limit = require("parley.config").tool_result_page_lines }) -- #140 #139
                        if call.name == "propose_edits" then
                            if results[i].is_error then
                                table.insert(errors, results[i].content)
                            else
                                applied = applied + 1
                            end
                        end
                    end
                    if not vim.api.nvim_buf_is_valid(buf) then
                        finish({ ok = false, msg = "buffer invalid" }, false)
                        return
                    end
                    if not opts.no_reload then
                        reload_buffer(buf)
                    end
                    if not vim.api.nvim_buf_is_valid(buf) then
                        finish({ ok = false, msg = "buffer invalid" }, false)
                        return
                    end
                    local new_content = table.concat(vim.api.nvim_buf_get_lines(buf, 0, -1, false), "\n")
                    local decorations = {}
                    for _, call in ipairs(calls) do
                        if not vim.api.nvim_buf_is_valid(buf) then
                            finish({ ok = false, msg = "buffer invalid" }, false)
                            return
                        end
                        if call.name == "propose_edits" then
                            for _, d in ipairs(render_propose_edits(buf, call, original, new_content)) do
                                table.insert(decorations, d)
                            end
                        end
                    end
                    -- Surface failure rather than swallowing it: a tool error, or no
                    -- tool call at all (a truncated/empty response), is logged so the
                    -- caller (review) can STOP rather than resubmit blindly.
                    if #calls == 0 then
                        p.logger.warning("skill " .. tostring(manifest.name)
                            .. ": model returned no tool call (response may be truncated)")
                    end
                    for _, e in ipairs(errors) do
                        p.logger.error("skill " .. tostring(manifest.name) .. ": " .. tostring(e))
                    end
                    -- Pure-fed payload: original/new_content/decorations let a
                    -- caller (review) journal the round without re-reading the
                    -- buffer (#133 M3).
                    finish({
                        ok = (#errors == 0),
                        applied = applied,
                        calls = calls,
                        results = results,
                        original = original,
                        new_content = new_content,
                        decorations = decorations,
                    }, true)
                end
                local ok_completion = xpcall(complete, function() return nil end)
                if not ok_completion then
                    p.logger.error("skill " .. tostring(manifest.name) .. " completion failed")
                    finish({ ok = false, msg = "completion failed" }, true)
                end
            end)
        end,
        nil,
        nil,
        function(msg) -- on_abort
            if finished or _gen[buf] ~= gen then
                return -- superseded by a newer exchange (cancelled) → no-op
            end
            p.logger.error("skill " .. tostring(manifest.name) .. " abort: " .. tostring(msg))
            finish({ ok = false, msg = tostring(msg) }, true)
        end,
        nil,
        function(_qid, transport_error) -- on_error (dispatcher argument 10)
            if finished or _gen[buf] ~= gen then return end
            p.logger.error("skill " .. tostring(manifest.name) .. " transport error")
            finish({ ok = false, msg = "transport error", error = transport_error }, true)
        end
    )
    if not ok_query then
        p.logger.error("skill " .. tostring(manifest.name) .. " query failed")
        finish({ ok = false, msg = "query failed" }, true)
    end
end

return M
