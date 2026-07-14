-- Main-loop adapter for one chat-producing LLM leg's pending presentation.
local M = {}

local logger = require("parley.logger")
local presentation = require("parley.chat_presentation")
local spinner = require("parley.progress").SPINNER
local unpack_values = unpack

local namespace = vim.api.nvim_create_namespace("parley_chat_pending")
local active_by_buf = {}
local verbs = {
    "Baking",
    "Brewing",
    "Caramelizing",
    "Chopping",
    "Concocting",
    "Cooking",
    "Crafting",
    "Cultivating",
    "Fermenting",
    "Garnishing",
    "Kneading",
    "Marinating",
    "Mulling",
    "Noodling",
    "Percolating",
    "Puttering",
    "Seasoning",
    "Simmering",
    "Sketching",
    "Sprouting",
    "Steeping",
    "Stewing",
    "Tinkering",
    "Toasting",
    "Unfurling",
    "Whisking",
    "Working",
    "Zesting",
}

local function monotonic_now_ms()
    local uv = vim.uv or vim.loop
    return uv.hrtime() / 1000000
end

local function close_timer(timer)
    if not timer then
        return
    end
    pcall(function() timer:stop() end)
    if not timer:is_closing() then
        pcall(function() timer:close() end)
    end
end

local function production_timer(delay_ms, repeat_ms, callback)
    local uv = vim.uv or vim.loop
    local timer = uv.new_timer()
    local cancelled = false
    timer:start(delay_ms, repeat_ms, callback)
    return function()
        if cancelled then
            return
        end
        cancelled = true
        close_timer(timer)
    end
end

local production_scheduler = {
    enqueue = vim.schedule,
    after = function(delay_ms, callback)
        return production_timer(delay_ms, 0, callback)
    end,
    every = function(delay_ms, callback)
        return production_timer(delay_ms, delay_ms, callback)
    end,
}

local function call_safely(label, callback, ...)
    if type(callback) ~= "function" then
        return
    end
    local arguments = { n = select("#", ...), ... }
    local ok = xpcall(function()
        callback(unpack_values(arguments, 1, arguments.n))
    end, function()
        -- Callback errors can contain provider output, chunks, or secrets.
        return nil
    end)
    if not ok then
        logger.error("chat pending " .. label .. " callback failed")
    end
end

-- Start one serialized presentation session for a response header.
M.start = function(opts)
    opts = opts or {}
    local buf = assert(opts.buf, "buf is required")
    local agent = assert(opts.agent, "agent is required")
    assert(type(agent) == "string" and agent ~= "", "agent must be a non-empty string")
    local existing = active_by_buf[buf]
    assert(not existing or existing.finished, "chat pending session already active for buffer")

    local scheduler = opts.scheduler or production_scheduler
    local clock = opts.clock or { now_ms = monotonic_now_ms }
    assert(type(scheduler.enqueue) == "function", "scheduler.enqueue is required")
    assert(type(scheduler.after) == "function", "scheduler.after is required")
    assert(type(scheduler.every) == "function", "scheduler.every is required")
    assert(type(clock.now_ms) == "function", "clock.now_ms is required")

    local session = {
        buf = buf,
        agent = agent,
        anchor_line = assert(opts.anchor_line, "anchor_line is required"),
        lease_valid = assert(opts.lease_valid, "lease_valid is required"),
        emit_content = assert(opts.emit_content, "emit_content is required"),
        choose_verb_index = assert(opts.choose_verb_index, "choose_verb_index is required"),
        on_discard = opts.on_discard,
        scheduler = scheduler,
        clock = clock,
        timers = {},
        frame_index = 2, -- The approved first visible frame is ⠙.
        detail_state = {},
        finished = false,
    }
    local function now_ms()
        return session.clock.now_ms()
    end

    local initial_index = session.choose_verb_index(#verbs)
    session.state = presentation.initial({
        now_ms = now_ms(),
        verbs = verbs,
        verb_index = initial_index,
    })
    assert(session.on_discard == nil or type(session.on_discard) == "function",
        "on_discard must be a function")

    local function cancel_timer(name)
        local cancel = session.timers[name]
        session.timers[name] = nil
        call_safely("timer cancellation", cancel)
    end

    local function cancel_timers()
        local names = {}
        for name in pairs(session.timers) do
            table.insert(names, name)
        end
        for _, name in ipairs(names) do
            cancel_timer(name)
        end
    end

    local function hide()
        if session.extmark_id then
            if vim.api.nvim_buf_is_valid(session.buf) then
                local position = vim.api.nvim_buf_get_extmark_by_id(
                    session.buf, namespace, session.extmark_id, { details = true })
                if #position >= 2 and not (position[3] and position[3].invalid) then
                    session.last_mark_row = position[1]
                    session.last_mark_col = position[2]
                end
            end
            pcall(vim.api.nvim_buf_del_extmark, session.buf, namespace, session.extmark_id)
            session.extmark_hidden = true
        end
        session.visible_text = nil
        session.playful_verb = nil
    end

    local function set_mark(text, row, col)
        local ok, mark_id = pcall(vim.api.nvim_buf_set_extmark, session.buf, namespace,
            row, col, {
                id = session.extmark_id,
                virt_lines = { { { text, "Comment" } } },
                virt_lines_above = false,
                invalidate = true,
            })
        if not ok then
            return false
        end
        session.extmark_id = mark_id
        session.extmark_hidden = false
        session.last_mark_row = row
        session.last_mark_col = col
        session.visible_text = text
        return true
    end

    local function render(text)
        if not vim.api.nvim_buf_is_valid(session.buf) then
            return false
        end
        local row = session.anchor_line
        local col = 0
        if session.extmark_id then
            local position = vim.api.nvim_buf_get_extmark_by_id(
                session.buf, namespace, session.extmark_id, { details = true })
            if #position >= 2 and not (position[3] and position[3].invalid) then
                row = position[1]
                col = position[2]
            elseif session.extmark_hidden and session.last_mark_row then
                row = session.last_mark_row
                col = session.last_mark_col
            else
                return false
            end
        end
        return set_mark(text, row, col)
    end

    local function render_playful()
        return render(spinner[session.frame_index] .. " " .. session.playful_verb)
    end

    local function finish()
        if session.finished then
            return
        end
        session.finished = true
        cancel_timers()
        hide()
        if active_by_buf[session.buf] == session then
            active_by_buf[session.buf] = nil
        end
    end

    local dispatch

    local function enqueue_timer_event(event_factory)
        scheduler.enqueue(function()
            if session.finished then
                return
            end
            if not vim.api.nvim_buf_is_valid(session.buf) then
                dispatch({ type = "invalid" })
                return
            end
            dispatch(event_factory())
        end)
    end

    local function schedule_after(name, delay_ms, event_factory)
        cancel_timer(name)
        session.timers[name] = scheduler.after(delay_ms, function()
            enqueue_timer_event(event_factory)
        end)
    end

    local function start_frame_timer()
        if session.timers.frame then
            return
        end
        session.timers.frame = scheduler.every(120, function()
            scheduler.enqueue(function()
                if session.finished then
                    return
                end
                if not vim.api.nvim_buf_is_valid(session.buf) then
                    dispatch({ type = "invalid" })
                    return
                end
                local ok, valid = pcall(session.lease_valid)
                if not ok or not valid then
                    dispatch({ type = "stale" })
                    return
                end
                if session.playful_verb then
                    session.frame_index = session.frame_index % #spinner + 1
                    if not render_playful() then
                        dispatch({ type = "invalid" })
                    end
                end
            end)
        end)
    end

    local function reset_idle_timer()
        schedule_after("idle", 15000, function()
            return {
                type = "idle",
                now_ms = now_ms(),
                verb_index = session.choose_verb_index(#verbs),
            }
        end)
    end

    local function rearm_early_timer(event, state)
        local deadline
        local name
        local event_factory
        if event.type == "reveal_due" and state.phase == "waiting" then
            deadline = state.reveal_at
            name = "reveal"
            event_factory = function()
                return { type = "reveal_due", now_ms = now_ms() }
            end
        elseif event.type == "minimum_due" and state.phase == "showing" then
            deadline = state.minimum_at
            name = "minimum"
            event_factory = function()
                return { type = "minimum_due", now_ms = now_ms() }
            end
        elseif event.type == "idle"
                and (state.phase == "waiting" or state.phase == "showing") then
            deadline = state.verb_due_at
            name = "idle"
            event_factory = function()
                return {
                    type = "idle",
                    now_ms = now_ms(),
                    verb_index = session.choose_verb_index(#verbs),
                }
            end
        end
        if deadline and event.now_ms < deadline then
            schedule_after(name, math.max(1, math.ceil(deadline - event.now_ms)), event_factory)
            return true
        end
        return false
    end

    local function apply_actions(actions, context)
        for _, action in ipairs(actions) do
            if action.type == "show_playful" then
                session.playful_verb = action.verb
                if not render_playful() then
                    finish()
                    return
                end
                start_frame_timer()
            elseif action.type == "render_status" then
                session.playful_verb = nil
                cancel_timer("frame")
                if not render(action.message) then
                    finish()
                    return
                end
            elseif action.type == "emit_content" then
                call_safely("content emitter", session.emit_content, action.qid, action.chunk)
            elseif action.type == "hide" then
                hide()
            elseif action.type == "continue_completion" then
                hide()
                call_safely("completion", action.completion)
            elseif action.type == "surface_failure" then
                hide()
                call_safely("failure surface", context and context.surface_failure, action.error)
            end
        end
    end

    dispatch = function(event, context)
        if session.finished then
            return
        end
        if event.type ~= "cancel" and event.type ~= "invalid" then
            local ok, valid = pcall(session.lease_valid)
            if not ok or not valid then
                event = { type = "stale" }
            end
        end
        local previous_phase = session.state.phase
        local next_state, actions = presentation.transition(session.state, event)
        session.state = next_state
        if next_state.phase == "finished" then
            -- Release registry/timer ownership before a continuation starts a
            -- recursive LLM leg in this buffer.
            finish()
            if event.type == "cancel" or event.type == "stale" or event.type == "invalid" then
                call_safely("discard terminal", session.on_discard, event.type, event.reason)
            end
            apply_actions(actions, context)
            return
        end
        apply_actions(actions, context)

        if session.finished then
            return
        end
        if rearm_early_timer(event, next_state) then
            return
        end
        if previous_phase == "waiting" and next_state.phase ~= "waiting" then
            cancel_timer("reveal")
            if next_state.phase == "released" then
                cancel_timer("idle")
            end
        end
        if next_state.phase == "showing" and previous_phase ~= "showing" then
            schedule_after("minimum", 1000, function()
                return { type = "minimum_due", now_ms = now_ms() }
            end)
        end
        if previous_phase == "showing" and next_state.phase ~= "showing" then
            cancel_timer("minimum")
            cancel_timer("frame")
            cancel_timer("idle")
        elseif (event.type == "activity" or event.type == "idle")
                and (next_state.phase == "waiting" or next_state.phase == "showing") then
            reset_idle_timer()
        end
    end

    local function submit(event_factory, context)
        scheduler.enqueue(function()
            if session.finished then
                return
            end
            if not vim.api.nvim_buf_is_valid(session.buf) then
                dispatch({ type = "invalid" })
                return
            end
            dispatch(event_factory(), context)
        end)
    end

    -- Validate immediately before the stream writer mutates the pending line.
    -- Since before_write, mutation, and tip_written share one scheduled callback,
    -- this authorization can only cover invalidation caused by that mutation.
    session.before_write = function(_self)
        session.tip_repair_authorized = false
        if session.finished then
            -- Reducer actions may already have emitted staged content into the
            -- scheduled stream writer before finish hid the presentation.
            return session.visible_text == nil
        end
        if not vim.api.nvim_buf_is_valid(session.buf) then
            dispatch({ type = "invalid" })
            return false
        end
        if session.visible_text then
            local position = vim.api.nvim_buf_get_extmark_by_id(
                session.buf, namespace, session.extmark_id, { details = true })
            if #position < 2 or (position[3] and position[3].invalid) then
                dispatch({ type = "invalid" })
                return false
            end
        end
        session.tip_repair_authorized = true
        return true
    end

    -- Called synchronously from dispatcher.create_handler's scheduled writer.
    -- The pending stream line may have just invalidated this extmark; repaint it
    -- before the writer yields so queued frame/progress work never sees a gap.
    session.tip_written = function(_self, last_written_line_0)
        local repair_authorized = session.tip_repair_authorized
        session.tip_repair_authorized = false
        if session.finished or type(last_written_line_0) ~= "number"
                or not vim.api.nvim_buf_is_valid(session.buf) then
            return
        end
        session.anchor_line = last_written_line_0
        session.last_mark_row = last_written_line_0
        session.last_mark_col = 0
        if not session.visible_text then
            return
        end
        local position = vim.api.nvim_buf_get_extmark_by_id(
            session.buf, namespace, session.extmark_id, { details = true })
        local mark_is_valid = #position >= 2 and not (position[3] and position[3].invalid)
        if not mark_is_valid and not repair_authorized then
            dispatch({ type = "invalid" })
            return
        end
        if not set_mark(session.visible_text, last_written_line_0, 0) then
            dispatch({ type = "invalid" })
        end
    end

    session.activity = function(_self, _qid)
        submit(function()
            return {
                type = "activity",
                now_ms = now_ms(),
                verb_index = session.choose_verb_index(#verbs),
            }
        end)
    end

    session.content = function(_self, qid, chunk)
        submit(function()
            return { type = "content", now_ms = now_ms(), qid = qid, chunk = chunk }
        end)
    end

    session.progress = function(_self, _qid, event)
        submit(function()
            if type(event) ~= "table" then
                event = { message = tostring(event or "") }
            end
            local message
            session.detail_state, message = presentation.progress_message(session.detail_state, event)
            return { type = "progress", now_ms = now_ms(), message = message }
        end)
    end

    session.complete = function(_self, _qid, continuation)
        submit(function()
            return { type = "complete", now_ms = now_ms(), completion = continuation }
        end)
    end

    session.failure = function(_self, _qid, err, surface_failure)
        submit(function()
            return {
                type = "failure",
                error = err,
                owns_transcript = type(surface_failure) == "function",
            }
        end, { surface_failure = surface_failure })
    end

    session.cancel = function(_self, reason)
        submit(function() return { type = "cancel", reason = reason } end)
    end

    -- Synchronously retire a structurally stale session. This public contract
    -- never throws: all external callbacks reached by dispatch are contained.
    session.retire_stale_now = function(_self, reason)
        dispatch({ type = "stale", reason = reason })
    end

    active_by_buf[buf] = session
    local enqueued, enqueue_error = pcall(scheduler.enqueue, function()
        if session.finished then
            return
        end
        if not vim.api.nvim_buf_is_valid(session.buf) then
            dispatch({ type = "invalid" })
            return
        end
        schedule_after("reveal", 1000, function()
            return { type = "reveal_due", now_ms = now_ms() }
        end)
        reset_idle_timer()
    end)
    if not enqueued then
        finish()
        error(enqueue_error, 0)
    end

    return session
end

-- Cancel every registered chat session before global task termination.
M.cancel_all = function(reason)
    local sessions = {}
    for _, session in pairs(active_by_buf) do
        table.insert(sessions, session)
    end
    for _, session in ipairs(sessions) do
        session:cancel(reason)
    end
end

-- Report only a fully constructed session that still owns this buffer.
M.is_active = function(buf)
    local session = active_by_buf[buf]
    return session ~= nil and not session.finished
end

-- Return a copied display identity only for a fully constructed active session.
function M.identity(buf)
    local session = active_by_buf[buf]
    if not session or session.finished then
        return nil
    end
    return { agent = session.agent }
end

-- Synchronously retire one stale session; no-op after ownership is gone.
---@param buf number
---@param reason string|nil
---@return boolean retired
function M.retire_stale_now(buf, reason)
    local session = active_by_buf[buf]
    if not session or session.finished then
        return false
    end
    session:retire_stale_now(reason)
    return true
end

return M
