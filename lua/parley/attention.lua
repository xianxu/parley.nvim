-- parley.attention — the attention finder's glue (#354): records each
-- Alt+Return submit that Couch accepted, probes Couch for the ones still
-- waiting, and opens the finder. The state and its rules live in
-- attention_model, the file in attention_store, the rows in attention_rows.

local logger = require("parley.logger")
local Model = require("parley.attention_model")
local Store = require("parley.attention_store")
local Rows = require("parley.attention_rows")

local PROBES = 4
-- A probe is a short local couch run; one that hangs reads as failed.
local PROBE_TIMEOUT_MS = 5000

local M = {}

--- The message ID from `couch --send-to`'s stdout, whose first line reads
--- `<ID> <from> -> <to> <status>`; nil for anything else.
function M.parse_message_id(stdout)
    local line = (stdout or ""):match("^[^\n]*")
    return line:match("^(%S+)%s+%S+%s+%->%s+%S+")
end

--- The breadcrumb of `win` through #353's seam (`file_history.snapshot`), or
--- nil: before that seam lands, with no window, or when it has no value.
function M.breadcrumb(win)
    if not win or win == -1 or not vim.api.nvim_win_is_valid(win) then return nil end
    local ok, history = pcall(require, "parley.file_history")
    if not ok or type(history.snapshot) ~= "function" then return nil end
    local taken, value = pcall(history.snapshot, win)
    return taken and type(value) == "table" and value or nil
end

--- Record a submit of `path` that Couch accepted. `send_result` is the
--- `couch --send-to` result; without a message ID in its stdout nothing can
--- later tell the submit answered, so nothing is recorded and that is warned.
---@param options table|nil # passed to attention_store.apply (tests)
function M.record(path, breadcrumb, send_result, options, on_done)
    on_done = on_done or function() end
    local id = M.parse_message_id(send_result and send_result.stdout)
    if not id then
        logger.warning("attention: no message ID in Couch's reply; the submit of " .. tostring(path) .. " is not tracked")
        return on_done(nil, "no message id")
    end
    Store.apply({ type = "submitted", path = path, id = id, breadcrumb = breadcrumb }, options, on_done)
end

-- The real seams; `open` and `refresh` take replacements for tests.
local function seams(options)
    options = options or {}
    return {
        run = options.run or require("parley.couch").query,
        picker = options.picker or require("parley.float_picker"),
        history = options.history or (function()
            local ok, history = pcall(require, "parley.file_history")
            return ok and history or {}
        end)(),
        limit = options.limit or PROBES,
        timeout = options.timeout_ms or PROBE_TIMEOUT_MS,
        store = options.store,
    }
end

--- The observation event for one probe of `path`. `probed` lists the IDs
--- pending when the probe started; `data` is couch.query's decoded reply (nil
--- when couch failed; anything but a table, such as async_operation_queue's
--- message for a probe that raised, counts as a failure too). Only a reply with
--- a ledger for the file is evidence: a failure, or a file Couch keeps no
--- ledger for, only marks the entry unknown.
function M.observation(path, probed, data)
    if type(data) ~= "table" then
        return { type = "observe_failed", path = path, reason = "couch status unavailable" }
    end
    if type(data.Status) ~= "table" then
        return { type = "observe_failed", path = path, reason = "no Couch ledger for this file" }
    end
    local owed = {}
    for _, event in ipairs(type(data.Status.Owed) == "table" and data.Status.Owed or {}) do
        if type(event) == "table" and type(event.ID) == "string" then owed[#owed + 1] = event.ID end
    end
    return { type = "observed", path = path, probed_ids = probed, owed_ids = owed }
end

--- Probe Couch for every waiting entry, at most `limit` at a time. Each
--- probe captures the entry's pending IDs as it starts, and its result is
--- applied to the store. on_change(state) runs after each applied result;
--- on_done() after the last.
function M.refresh(options, on_change, on_done)
    local seam = seams(options)
    on_change, on_done = on_change or function() end, on_done or function() end
    local queue = {}
    for _, entry in ipairs(Model.list(Store.load())) do
        if Model.state_of(entry) == "waiting" then queue[#queue + 1] = entry.path end
    end
    if #queue == 0 then return on_done() end
    -- The shared bounded queue (async_operation_queue) runs at most `limit`
    -- probes; each captures its entry's pending IDs as it starts.
    local probes, finished = require("parley.async_operation_queue").new(vim.uv or vim.loop, seam.limit), 0
    for _, path in ipairs(queue) do
        local probed
        probes:call(function(finish)
            local entry = Store.load().entries[path]
            probed = entry and vim.tbl_keys(entry.pending) or {}
            return seam.run({ "couch", "--session-sync", "status", "--json", path }, finish, { timeout = seam.timeout })
        end, function(data)
            Store.apply(M.observation(path, probed, data), seam.store, function(state)
                if state then on_change(state) end
                finished = finished + 1
                if finished == #queue then on_done() end
            end)
        end)
    end
end

--- Whether `lines` (the head of a file) open with a closed frontmatter block
--- whose `type` is `side-doc`, read through the one frontmatter parser.
function M.is_side_doc(lines)
    local fm = require("parley.frontmatter").parse(lines)
    return fm ~= nil and fm.fields.type == "side-doc"
end

-- Enough lines for a frontmatter block; one that runs longer is not read as a side doc.
local SIDE_HEAD_LINES = 40

--- `discovered` events for the side docs the agent wrote: every `*.md` with
--- frontmatter `type: side-doc` in the `.side/` folder of an entry already
--- in the finder, written after that entry entered it, and neither an entry
--- nor retired. Side docs are entries too, so nesting is found on the next scan.
function M.discover(state)
    local uv = vim.uv or vim.loop
    local events, seen = {}, {}
    for _, entry in pairs(state.entries) do
        local folder = require("parley.document_move_plan").side_path(entry.path)
        local since = entry.kind == "side" and entry.submitted_at or (entry.recorded_at or entry.submitted_at)
        local scan = uv.fs_scandir(folder)
        while scan do
            local name, kind = uv.fs_scandir_next(scan)
            if not name then break end
            local path = folder .. "/" .. name
            local stat = (kind == "file" or kind == "link") and name:match("%.md$") and uv.fs_stat(path)
            if stat and stat.type == "file" and stat.mtime.sec > since and not seen[path]
                and not state.entries[path] and not state.retired[path] then
                local ok, head = pcall(vim.fn.readfile, path, "", SIDE_HEAD_LINES)
                if ok and M.is_side_doc(head) then
                    seen[path] = true
                    events[#events + 1] = { type = "discovered", path = path, parent = entry.path, at = stat.mtime.sec }
                end
            end
        end
    end
    table.sort(events, function(x, y) return x.path < y.path end)
    return events
end

local function define_highlights()
    local groups = {
        ParleyAttentionWaiting = { link = "Normal" },
        ParleyAttentionAnswered = { link = "Title" },
        ParleyAttentionSeen = { link = "Comment" },
    }
    for name, spec in pairs(groups) do
        vim.api.nvim_set_hl(0, name, vim.tbl_extend("force", spec, { default = true }))
    end
end

-- Open the selected entry's file in the current window, mark it seen, and
-- restore its breadcrumb through #353's seam. When restore refuses, the
-- ordinary open result stands and the reason is shown.
local function select(path, seam, on_done)
    if vim.fn.filereadable(path) ~= 1 then
        logger.warning("attention: " .. path .. " no longer exists")
        return on_done and on_done()
    end
    local breadcrumb = (Store.load().entries[path] or {}).breadcrumb
    vim.cmd("edit " .. vim.fn.fnameescape(path))
    local win = vim.api.nvim_get_current_win()
    if breadcrumb and type(seam.history.restore) == "function" then
        local ok, restored, reason = pcall(seam.history.restore, win, breadcrumb)
        if not ok or restored ~= true then
            logger.warning("attention: breadcrumb not restored: " .. tostring(ok and reason or restored))
        end
    end
    Store.apply({ type = "opened", path = path }, seam.store, function() if on_done then on_done() end end)
end

--- Open the finder: sweep, add the side docs the agent wrote, list the
--- stored entries at once, then probe the waiting ones and repaint as their
--- results land.
---@param options table|nil # { run, picker, history, limit, store, home } for tests
function M.open(options)
    local seam = seams(options)
    local home = (options and options.home) or vim.env.HOME
    define_highlights()
    local function items(state) return Rows.items(Model.list(state), { home = home }) end
    local function show(state)
        local handle
        handle = seam.picker.open({
            title = "Attention",
            items = items(state),
            on_select = function(item) select(item.value, seam, options and options.on_selected) end,
        })
        M.refresh(options, function(next_state)
            if not handle then return end
            local selected = handle.selected and handle.selected()
            handle.update(items(next_state), nil, selected and selected.value or nil)
        end, options and options.on_refreshed)
    end
    Store.apply({ type = "sweep", grace = Store.grace_seconds() }, seam.store, function(swept)
        local state = swept or Store.load()
        local events = M.discover(state)
        if #events == 0 then return show(state) end
        Store.apply({ type = "batch", events = events }, seam.store, function(found)
            show(found or Store.load())
        end)
    end)
end

return M
