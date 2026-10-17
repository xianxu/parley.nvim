-- parley.attention_model — the attention finder's entries and their one
-- transition (#354). Pure Lua: no vim.*, no IO; time arrives as `now`.
--
-- An entry is a file submitted with Alt+Return, or a side doc the agent wrote
-- for one (`kind = "side"`, found in the entry's `.side/` folder). Its state is
-- derived from its pending message IDs and its answered/seen times, never stored:
--   waiting   some submit of the file is still owed by the agent;
--   answered  nothing is owed, and the operator has not opened it since;
--   seen      looked at after its last answer: opened from the finder, or
--             viewed in a window (`viewed`), however the operator got there.
-- A failed probe is never evidence of an answer: it only marks `unknown`.
-- A side doc that left the finder is `retired`, so a later scan of its folder
-- does not bring it back.

local M = {}

M.VERSION = 1
M.LIMIT = 256

function M.empty()
    return { version = M.VERSION, entries = {}, retired = {} }
end

function M.state_of(entry)
    if next(entry.pending) ~= nil then
        return "waiting"
    end
    if entry.seen_at and entry.answered_at and entry.seen_at >= entry.answered_at then
        return "seen"
    end
    return "answered"
end

local function set(list)
    local result = {}
    for _, value in ipairs(list or {}) do result[value] = true end
    return result
end

local function copy(value)
    if type(value) ~= "table" then return value end
    local result = {}
    for key, inner in pairs(value) do result[key] = copy(inner) end
    return result
end

-- A copy of `state` whose entry for `path` may be changed in place.
local function with_entry(state, path)
    local entries = {}
    for key, entry in pairs(state.entries) do entries[key] = entry end
    local entry = entries[path]
    if entry then
        entry = copy(entry)
        entries[path] = entry
    end
    local retired = {}
    for key, at in pairs(state.retired or {}) do retired[key] = at end
    return { version = state.version, entries = entries, retired = retired }, entry
end

local function newest_first(a, b)
    if a.submitted_at ~= b.submitted_at then return a.submitted_at > b.submitted_at end
    return a.path < b.path
end

--- Entries, newest submit first (ties by path).
function M.list(state)
    local result = {}
    for _, entry in pairs(state.entries) do result[#result + 1] = entry end
    table.sort(result, newest_first)
    return result
end

--- The number of answered entries the operator has not opened.
function M.answered_unseen(state)
    local count = 0
    for _, entry in pairs(state.entries) do
        if M.state_of(entry) == "answered" then count = count + 1 end
    end
    return count
end

-- Remove an entry from (a copy of) the state; a side doc is retired, keeping
-- at most LIMIT retired paths (the oldest go first).
local function remove(state, path, now)
    local entry = state.entries[path]
    state.entries[path] = nil
    if not entry or entry.kind ~= "side" then return end
    state.retired[path] = now
    local count, oldest = 0, nil
    for key, at in pairs(state.retired) do
        count = count + 1
        if not oldest or at < state.retired[oldest] or (at == state.retired[oldest] and key < oldest) then oldest = key end
    end
    if count > M.LIMIT then state.retired[oldest] = nil end
end

-- Make room for one more entry: drop the oldest seen, else the oldest
-- answered. A waiting entry is never dropped, so a table of waiting entries
-- is full.
local function make_room(state, now)
    local count = 0
    for _ in pairs(state.entries) do count = count + 1 end
    if count < M.LIMIT then return true end
    for _, kind in ipairs({ "seen", "answered" }) do
        local oldest
        for _, entry in pairs(state.entries) do
            if M.state_of(entry) == kind and (not oldest or newest_first(oldest, entry)) then oldest = entry end
        end
        if oldest then
            remove(state, oldest.path, now)
            return true
        end
    end
    return false
end

local handlers = {}

function handlers.submitted(state, event, now)
    local next_state, entry = with_entry(state, event.path)
    if not entry then
        if not make_room(next_state, now) then return state, "full" end
        entry = { path = event.path, pending = {}, recorded_at = now }
        next_state.entries[event.path] = entry
    end
    entry.pending[event.id] = now
    entry.submitted_at = now
    entry.breadcrumb = event.breadcrumb
    return next_state
end

function handlers.observed(state, event, now)
    if not state.entries[event.path] then return state end
    local next_state, entry = with_entry(state, event.path)
    entry.unknown = nil
    local had_pending = next(entry.pending) ~= nil
    local owed = set(event.owed_ids)
    for id in pairs(set(event.probed_ids)) do
        if not owed[id] then entry.pending[id] = nil end
    end
    if had_pending and next(entry.pending) == nil then entry.answered_at = now end
    return next_state
end

function handlers.observe_failed(state, event)
    if not state.entries[event.path] then return state end
    local next_state, entry = with_entry(state, event.path)
    entry.unknown = event.reason or "unknown"
    return next_state
end

function handlers.opened(state, event, now)
    local entry = state.entries[event.path]
    if not entry or M.state_of(entry) ~= "answered" then return state end
    local next_state, opened = with_entry(state, event.path)
    opened.seen_at = now
    return next_state
end

-- The operator looked at the file at `at`, however they got there (#354: a
-- session file is read where it is already open). It counts only after the
-- answer arrived; a view while waiting, or before the answer, changes nothing.
function handlers.viewed(state, event)
    local entry = state.entries[event.path]
    if not entry or M.state_of(entry) ~= "answered" or not entry.answered_at or event.at <= entry.answered_at then
        return state
    end
    local next_state, viewed = with_entry(state, event.path)
    viewed.seen_at = event.at
    return next_state
end

function handlers.sweep(state, event, now)
    local next_state = with_entry(state, nil)
    for path, entry in pairs(state.entries) do
        if M.state_of(entry) == "seen" and now - entry.seen_at >= event.grace then remove(next_state, path, now) end
    end
    return next_state
end

-- A side doc the agent wrote at `at` for the entry `parent`: answered, not yet
-- seen. Ignored when the path is already an entry or was retired.
function handlers.discovered(state, event, now)
    if state.entries[event.path] or (state.retired or {})[event.path] then return state end
    local next_state = with_entry(state, nil)
    if not make_room(next_state, now) then return state, "full" end
    next_state.entries[event.path] = { path = event.path, pending = {}, kind = "side", parent = event.parent,
        submitted_at = event.at, answered_at = event.at, recorded_at = now }
    return next_state
end

-- Several events as one change (one store write for a scan's discoveries).
function handlers.batch(state, event, now)
    local refused
    for _, inner in ipairs(event.events) do
        local next_state, err = M.transition(state, inner, now)
        state, refused = next_state, refused or err
    end
    return state, refused
end

--- The one owner of every state change. Returns the new state (the input is
--- never mutated) and, when a submit is refused because every entry is
--- waiting, the error "full".
function M.transition(state, event, now)
    local handler = handlers[event.type]
    assert(handler, "attention_model: unknown event " .. tostring(event.type))
    return handler(state, event, now)
end

return M
