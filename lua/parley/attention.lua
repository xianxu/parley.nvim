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

-- The paths this editor last saw answered: the cheap test the view autocmds
-- (which fire on every cursor move) run before touching the store.
local answered = {}

local function remember(state)
    answered = {}
    for path, entry in pairs(state and state.entries or {}) do
        if Model.state_of(entry) == "answered" then answered[path] = true end
    end
end

-- Every store change from this module goes through here, so `answered` follows it.
local function apply(event, options, on_done)
    Store.apply(event, options, function(state, err)
        if state then remember(state) end
        if on_done then on_done(state, err) end
    end)
end

--- The clock for views; replaced by tests.
M.clock = os.time

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
    apply({ type = "submitted", path = path, id = id, breadcrumb = breadcrumb }, options, on_done)
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
            apply(M.observation(path, probed, data), seam.store, function(state)
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

-- A file's mtime as the "sec.nsec" the store's `saved` map records.
local function mtime_id(stat)
    return stat.mtime.sec .. "." .. stat.mtime.nsec
end

--- The events for the side docs the agent wrote (attention_model.scan owns
--- the rule): every `*.md` with frontmatter `type: side-doc` in the `.side/`
--- folder of an entry already in the finder. Only the files the rule picks by
--- their mtimes have their frontmatter read. Side docs are entries too, so
--- nesting is found on the next scan.
function M.discover(state)
    local uv = vim.uv or vim.loop
    local files = {}
    for _, entry in pairs(state.entries) do
        local folder = require("parley.document_move_plan").side_path(entry.path)
        local scan = uv.fs_scandir(folder)
        while scan do
            local name, kind = uv.fs_scandir_next(scan)
            if not name then break end
            local path = folder .. "/" .. name
            local stat = (kind == "file" or kind == "link") and name:match("%.md$") and uv.fs_stat(path)
            if stat and stat.type == "file" then
                files[#files + 1] = { path = path, parent = entry.path, mtime_sec = stat.mtime.sec, mtime_id = mtime_id(stat) }
            end
        end
    end
    table.sort(files, function(x, y) return x.path < y.path end)
    return vim.tbl_filter(function(event)
        local ok, head = pcall(vim.fn.readfile, event.path, "", SIDE_HEAD_LINES)
        return ok and M.is_side_doc(head)
    end, Model.scan(state, files))
end

--- The operator's editor wrote `buf`'s file: when it is a file in a `.side/`
--- folder, record its new mtime, so a scan does not take the save for the agent's.
function M.saved(buf)
    if vim.bo[buf].buftype ~= "" then return end
    local name = vim.api.nvim_buf_get_name(buf)
    if name == "" then return end
    local path = vim.fn.fnamemodify(name, ":p")
    if not path:match("%.side/[^/]+$") then return end
    local stat = (vim.uv or vim.loop).fs_stat(path)
    if not stat then return end
    apply({ type = "saved", path = path, mtime = mtime_id(stat) }, { now = M.clock() })
end

--- The operator looked at the current window's file: an answered entry for
--- it becomes seen (the model counts only a view after the answer).
function M.viewed(buf)
    buf = buf or vim.api.nvim_get_current_buf()
    if vim.bo[buf].buftype ~= "" then return end
    local name = vim.api.nvim_buf_get_name(buf)
    if name == "" then return end
    local path = vim.fn.fnamemodify(name, ":p")
    if not answered[path] then return end
    answered[path] = nil
    local at = M.clock()
    apply({ type = "viewed", path = path, at = at }, { now = at })
end

--- Install the view autocmds once: focusing a window on a file, or moving or
--- scrolling in it, is the operator looking at it; saving a side doc is the
--- operator's write, not the agent's. Loads the answered paths.
function M.setup()
    remember(Store.load())
    local group = vim.api.nvim_create_augroup("ParleyAttentionViews", { clear = true })
    vim.api.nvim_create_autocmd({ "WinEnter", "BufEnter", "CursorMoved", "CursorMovedI", "WinScrolled" }, {
        group = group,
        callback = function(args)
            if args.event == "WinScrolled" then
                -- WinScrolled names the scrolled window; it counts only while current.
                if tonumber(args.match) ~= vim.api.nvim_get_current_win() then return end
                return M.viewed(vim.api.nvim_get_current_buf())
            end
            M.viewed(args.buf)
        end,
    })
    vim.api.nvim_create_autocmd("BufWritePost", {
        group = group,
        callback = function(args) M.saved(args.buf) end,
    })
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
    apply({ type = "opened", path = path }, seam.store, function() if on_done then on_done() end end)
end

--- Open the finder: sweep, add the side docs the agent wrote, list the
--- stored entries at once, then probe the waiting ones and repaint as their
--- results land.
---@param options table|nil # { run, picker, history, limit, store, home } for tests
function M.open(options)
    local seam = seams(options)
    local home = (options and options.home) or vim.env.HOME
    define_highlights()
    -- The file in the current window is already in front of the operator.
    local current = vim.api.nvim_buf_get_name(0)
    current = current ~= "" and vim.fn.fnamemodify(current, ":p") or nil
    local function items(state)
        local shown = vim.tbl_filter(function(entry) return entry.path ~= current end, Model.list(state))
        return Rows.items(shown, { home = home })
    end
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
    apply({ type = "sweep", grace = Store.grace_seconds() }, seam.store, function(swept)
        local state = swept or Store.load()
        local events = M.discover(state)
        if #events == 0 then return show(state) end
        apply({ type = "batch", events = events }, seam.store, function(found)
            show(found or Store.load())
        end)
    end)
end

return M
