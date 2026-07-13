-- Main-loop adapter for one chat-producing LLM leg's pending presentation.
local M = {}

local presentation = require("parley.chat_presentation")
local spinner = require("parley.progress").SPINNER

local namespace = vim.api.nvim_create_namespace("parley_chat_pending")
local active_by_buf = {}
local verbs = { "brewing", "cooking", "dragon-slaying" }

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

local function call_safely(callback, ...)
    if type(callback) == "function" then
        pcall(callback, ...)
    end
end

-- Start one serialized presentation session for a response header.
M.start = function(opts)
    opts = opts or {}
    local buf = assert(opts.buf, "buf is required")
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
        anchor_line = assert(opts.anchor_line, "anchor_line is required"),
        lease_valid = assert(opts.lease_valid, "lease_valid is required"),
        emit_content = assert(opts.emit_content, "emit_content is required"),
        choose_verb_index = assert(opts.choose_verb_index, "choose_verb_index is required"),
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

    local function cancel_timer(name)
        local cancel = session.timers[name]
        session.timers[name] = nil
        call_safely(cancel)
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
            pcall(vim.api.nvim_buf_del_extmark, session.buf, namespace, session.extmark_id)
        end
        session.visible_text = nil
        session.playful_verb = nil
    end

    local function render(text)
        if not vim.api.nvim_buf_is_valid(session.buf) then
            return false
        end
        local ok, mark_id = pcall(vim.api.nvim_buf_set_extmark, session.buf, namespace,
            session.anchor_line, 0, {
                id = session.extmark_id,
                virt_lines = { { { text, "Comment" } } },
                virt_lines_above = false,
                invalidate = true,
            })
        if not ok then
            return false
        end
        session.extmark_id = mark_id
        session.visible_text = text
        return true
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
                    render_playful()
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
                call_safely(session.emit_content, action.qid, action.chunk)
            elseif action.type == "hide" then
                hide()
            elseif action.type == "continue_completion" then
                hide()
                call_safely(action.completion)
            elseif action.type == "surface_failure" then
                hide()
                call_safely(context and context.surface_failure, action.error)
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
            apply_actions(actions, context)
            return
        end
        apply_actions(actions, context)

        if session.finished then
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

    session.cancel = function(_self, _reason)
        submit(function() return { type = "cancel" } end)
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

return M
