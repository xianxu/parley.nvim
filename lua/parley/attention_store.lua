-- parley.attention_store — the attention finder's entries on disk (#354).
--
-- One JSON file, `state_dir/attention/attention.json`, holds the
-- attention_model state. Several editors may submit at once, so every write
-- happens under one document lease and re-reads the file first. The lease is
-- non-blocking: a held lease is retried a bounded number of times and then
-- reported, so a lost submit record is never silent. The file is app-owned
-- state, parsed into typed entries at the read (#261); anything that does not
-- fit is dropped with one warning per read.

local Model = require("parley.attention_model")
local logger = require("parley.logger")

local M = {}

local TRIES, DELAY_MS = 10, 25

local OPTIONAL = { answered_at = "number", seen_at = "number", breadcrumb = "table", unknown = "string",
    recorded_at = "number", kind = "string", parent = "string" }

-- One stored entry as a typed entry, or nil with why it cannot be one. A wrong
-- optional field is dropped; a wrong required one drops the entry.
local function typed(key, entry)
    if type(entry) ~= "table" or entry.path ~= key or type(entry.submitted_at) ~= "number"
        or type(entry.pending) ~= "table" then
        return nil, true
    end
    local result, dropped = { path = key, submitted_at = entry.submitted_at, pending = {} }, false
    for id, at in pairs(entry.pending) do
        if type(id) == "string" and type(at) == "number" then result.pending[id] = at else dropped = true end
    end
    for field, want in pairs(OPTIONAL) do
        if type(entry[field]) == want then result[field] = entry[field] elseif entry[field] ~= nil then dropped = true end
    end
    return result, dropped
end

local function state_dir()
    local configured = package.loaded.parley and package.loaded.parley.config
    return (configured and configured.state_dir) or require("parley.config").state_dir
end

function M.dir() return state_dir():gsub("/$", "") .. "/attention" end
function M.path() return M.dir() .. "/attention.json" end

--- The seen grace, in seconds, from `attention.seen_grace_minutes`.
function M.grace_seconds()
    local configured = package.loaded.parley and package.loaded.parley.config
    local attention = (configured and configured.attention) or require("parley.config").attention or {}
    return (tonumber(attention.seen_grace_minutes) or 60) * 60
end

--- A decoded file as a model state. A wrong version reads as empty; an entry
--- missing its path, its submit time or its pending set is dropped, and so is
--- a wrongly typed optional field. One warning covers whatever was dropped.
function M.parse(decoded, label)
    label = tostring(label or M.path())
    if type(decoded) ~= "table" then return Model.empty() end
    if decoded.version ~= Model.VERSION or type(decoded.entries) ~= "table" then
        logger.warning("Ignoring attention entries of " .. label .. ": unknown version or shape")
        return Model.empty()
    end
    local state, dropped = Model.empty(), 0
    for key, entry in pairs(decoded.entries) do
        local clean, lossy = typed(key, entry)
        if clean then state.entries[key] = clean end
        if lossy then dropped = dropped + 1 end
    end
    for path, at in pairs(type(decoded.retired) == "table" and decoded.retired or {}) do
        if type(path) == "string" and type(at) == "number" then state.retired[path] = at else dropped = dropped + 1 end
    end
    if decoded.retired ~= nil and type(decoded.retired) ~= "table" then dropped = dropped + 1 end
    if dropped > 0 then
        logger.warning(("Ignoring malformed parts of %d attention entr%s of %s"):format(dropped,
            dropped == 1 and "y" or "ies", label))
    end
    return state
end

--- The stored state; empty when the file is missing or unreadable.
function M.load()
    local path = M.path()
    if vim.fn.filereadable(path) ~= 1 then return Model.empty() end
    local helper = require("parley.helper")
    return M.parse(helper.file_to_table(path), path)
end

-- Run the transition and the sweep under the lease, and write the result.
local function apply_locked(event, now, grace)
    local state = M.load()
    local next_state, refused = Model.transition(state, event, now)
    next_state = Model.transition(next_state, { type = "sweep", grace = grace }, now)
    local ok, err = require("parley.helper").table_to_file_atomic(next_state, M.path())
    if not ok then return nil, "cannot write " .. M.path() .. ": " .. tostring(err) end
    return next_state, refused
end

--- Apply one model event to the stored state, then sweep seen entries past
--- the grace. on_done(state, err) runs in the main loop: state is the stored
--- result, or nil when nothing was written; err is "full" when the model
--- refused a submit, or the reason the store could not be written. Every
--- failure is also warned, naming `event.path`.
---@param options table|nil # { tries, delay_ms, now, grace, lease } for tests
function M.apply(event, options, on_done)
    options = options or {}
    on_done = on_done or function() end
    local tries = options.tries or TRIES
    local delay = options.delay_ms or DELAY_MS
    local leases = options.lease or require("parley.document_lease")
    local function fail(message)
        logger.warning("attention: " .. message)
        on_done(nil, message)
    end
    local function attempt(left)
        local made, made_err = pcall(require("parley.fs").ensure_dir, M.dir(), 448)
        if not made then return fail("cannot create " .. M.dir() .. ": " .. tostring(made_err)) end
        local lease, err = leases.acquire("attention", "store", { root = state_dir() })
        if not lease then
            if err and err.kind == "busy" and left > 1 then
                vim.defer_fn(function() attempt(left - 1) end, delay)
                return
            end
            local why = err and err.kind == "busy" and "store busy" or (err and err.message or "lease unavailable")
            return fail(("%s for %s lost (%s)"):format(event.type, tostring(event.path), why))
        end
        -- Under the lease only this editor writes, so a temp file is a crash leftover.
        require("parley.helper").remove_stale_temps(M.dir())
        local ok, state, refused = pcall(apply_locked, event, options.now or os.time(), options.grace or M.grace_seconds())
        lease.release()
        if not ok then return fail(("%s for %s lost (%s)"):format(event.type, tostring(event.path), tostring(state))) end
        if not state then return fail(refused) end
        if refused == "full" then
            logger.warning(("attention: %d files are waiting; %s was not recorded"):format(Model.LIMIT, tostring(event.path)))
        end
        on_done(state, refused)
    end
    attempt(tries)
end

return M
