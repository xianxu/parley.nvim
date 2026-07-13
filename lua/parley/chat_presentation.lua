-- Pure presentation state for one chat-producing LLM leg.
local M = {}

local REVEAL_DELAY_MS = 1000
local MINIMUM_VISIBLE_MS = 1000
local VERB_IDLE_MS = 15000
local TIMED_EVENTS = {
    reveal_due = true,
    minimum_due = true,
    activity = true,
    idle = true,
    content = true,
    progress = true,
    complete = true,
}

local function copy_array(values)
    local copied = {}
    for index, value in ipairs(values or {}) do
        copied[index] = value
    end
    return copied
end

local function copy_state(state)
    local copied = {}
    for key, value in pairs(state) do
        copied[key] = value
    end
    return copied
end

local function content_action(event)
    return {
        type = "emit_content",
        qid = event.qid,
        chunk = event.chunk,
    }
end

local function progress_action(event)
    return {
        type = "render_status",
        message = event.message,
    }
end

local function visible_action(event)
    if event.type == "content" then
        return content_action(event)
    end
    return progress_action(event)
end

local function staged_event(event)
    if event.type == "content" then
        return {
            type = "content",
            qid = event.qid,
            chunk = event.chunk,
        }
    end
    return {
        type = "progress",
        message = event.message,
    }
end

local function append_staged_actions(actions, staged_tail, staged_count)
    local first_action = #actions
    local node = staged_tail
    for index = staged_count, 1, -1 do
        actions[first_action + index] = visible_action(node.event)
        node = node.previous
    end
end

local function continuation_action(completion)
    return {
        type = "continue_completion",
        completion = completion,
    }
end

local function finish(state)
    local finished = copy_state(state)
    finished.phase = "finished"
    finished.staged_tail = nil
    finished.staged_count = 0
    finished.completion_pending = nil
    finished.pending_completion = nil
    return finished
end

local function release_visible(state, event)
    local released = copy_state(state)
    released.phase = "released"
    released.staged_tail = nil
    released.staged_count = 0
    local actions = { { type = "hide" } }
    append_staged_actions(actions, state.staged_tail, state.staged_count)
    actions[#actions + 1] = visible_action(event)
    return released, actions
end

local function rotate_verb(state, event, now_ms)
    local rotated = copy_state(state)
    local verb_count = #rotated.verbs
    local requested = tonumber(event.verb_index) or (rotated.verb_index + 1)
    requested = ((requested - 1) % verb_count) + 1
    if verb_count > 1 and requested == rotated.verb_index then
        requested = (requested % verb_count) + 1
    end
    rotated.verb_index = requested
    rotated.verb = rotated.verbs[requested]
    rotated.last_activity_at = now_ms
    rotated.verb_due_at = now_ms + VERB_IDLE_MS
    return rotated, { { type = "show_playful", verb = rotated.verb } }
end

local function flush_showing(state, completion, completion_pending)
    local actions = { { type = "hide" } }
    append_staged_actions(actions, state.staged_tail, state.staged_count)
    if completion_pending then
        actions[#actions + 1] = continuation_action(completion)
        return finish(state), actions
    end
    local released = copy_state(state)
    released.phase = "released"
    released.staged_tail = nil
    released.staged_count = 0
    return released, actions
end

-- Construct deterministic presentation state without reading a clock or RNG.
M.initial = function(opts)
    opts = opts or {}
    local now_ms = assert(opts.now_ms, "now_ms is required")
    local verbs = copy_array(assert(opts.verbs, "verbs are required"))
    assert(#verbs > 0, "at least one verb is required")
    local verb_index = assert(opts.verb_index, "verb_index is required")
    assert(verbs[verb_index], "verb_index must identify an injected verb")

    return {
        phase = "waiting",
        verbs = verbs,
        verb_index = verb_index,
        verb = verbs[verb_index],
        reveal_at = now_ms + REVEAL_DELAY_MS,
        minimum_at = now_ms + REVEAL_DELAY_MS + MINIMUM_VISIBLE_MS,
        verb_due_at = now_ms + VERB_IDLE_MS,
        last_activity_at = now_ms,
        staged_count = 0,
    }
end

-- Reduce one serialized callback into immutable state and ordered UI actions.
M.transition = function(state, event)
    if state.phase == "finished" then
        return state, {}
    end

    local event_type = event.type
    if TIMED_EVENTS[event_type] then
        assert(type(event.now_ms) == "number", event_type .. " event requires now_ms")
    end
    local now_ms = event.now_ms

    if event_type == "cancel" or event_type == "stale" or event_type == "invalid" then
        local actions = state.phase == "showing" and { { type = "hide" } } or {}
        return finish(state), actions
    end

    if event_type == "failure" then
        local actions = state.phase == "showing" and { { type = "hide" } } or {}
        if event.owns_transcript then
            append_staged_actions(actions, state.staged_tail, state.staged_count)
            actions[#actions + 1] = { type = "surface_failure", error = event.error }
        end
        return finish(state), actions
    end

    if state.phase == "waiting" then
        if event_type == "content" or event_type == "progress" then
            local released = copy_state(state)
            released.phase = "released"
            return released, { visible_action(event) }
        end
        if event_type == "reveal_due" and now_ms >= state.reveal_at then
            local showing = copy_state(state)
            showing.phase = "showing"
            showing.minimum_at = now_ms + MINIMUM_VISIBLE_MS
            return showing, { { type = "show_playful", verb = showing.verb } }
        end
        if event_type == "activity" then
            local active = copy_state(state)
            active.last_activity_at = now_ms
            active.verb_due_at = now_ms + VERB_IDLE_MS
            return active, {}
        end
        if event_type == "complete" then
            return finish(state), { continuation_action(event.completion) }
        end
        return state, {}
    end

    if state.phase == "released" then
        if event_type == "content" or event_type == "progress" then
            return state, { visible_action(event) }
        end
        if event_type == "complete" then
            return finish(state), { continuation_action(event.completion) }
        end
        return state, {}
    end

    if event_type == "activity" then
        return rotate_verb(state, event, now_ms)
    end
    if event_type == "idle" and now_ms >= state.verb_due_at then
        return rotate_verb(state, event, now_ms)
    end
    if event_type == "content" or event_type == "progress" then
        if now_ms >= state.minimum_at then
            return release_visible(state, event)
        end
        local staged = copy_state(state)
        staged.staged_tail = {
            event = staged_event(event),
            previous = state.staged_tail,
        }
        staged.staged_count = state.staged_count + 1
        return staged, {}
    end
    if event_type == "complete" then
        if now_ms >= state.minimum_at then
            return flush_showing(state, event.completion, true)
        end
        local deferred = copy_state(state)
        deferred.completion_pending = true
        deferred.pending_completion = event.completion
        return deferred, {}
    end
    if event_type == "minimum_due" and now_ms >= state.minimum_at then
        if state.completion_pending then
            return flush_showing(state, state.pending_completion, true)
        end
        if state.staged_count > 0 then
            return flush_showing(state)
        end
    end

    return state, {}
end

-- Accumulate one provider detail stream and derive its meaningful status text.
M.progress_message = function(detail_state, event)
    local detail = event.text
    if type(detail) ~= "string" or detail == "" then
        return {}, event.message
    end

    local detail_key = table.concat({
        tostring(event.phase or ""),
        tostring(event.kind or ""),
        tostring(event.tool or ""),
        tostring(event.block_type or ""),
    }, ":")
    local accumulated = detail
    if detail_state.key == detail_key then
        accumulated = (detail_state.text or "") .. detail
    end

    local next_state = { key = detail_key, text = accumulated }
    local compact = accumulated:gsub("%s+", " "):gsub("^%s+", "")
    if compact == "" then
        return next_state, event.message
    end
    if event.kind == "reasoning" then
        return next_state, "Reasoning: " .. compact
    end
    local base = type(event.message) == "string" and event.message ~= "" and event.message or "Working..."
    return next_state, base .. " " .. compact
end

return M
