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
    local slot = send_result.stdout:match("^%S+%s+(%S+)%s+%->%s+%S+")
    apply({ type = "submitted", path = path, id = id, breadcrumb = breadcrumb, slot = slot }, options, on_done)
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

--- Scan each owning root once, flat files plus one month directory level.
--- Historical direct nested folders remain separate explicit entry roots. No
--- scan descends through a link or through an arbitrary directory.
function M.discover(state)
    local uv, side = vim.uv or vim.loop, require("parley.side_document_path")
    local roots, files, by_path = {}, {}, {}
    local function since(entry)
        return entry.kind == "side" and entry.submitted_at or (entry.recorded_at or entry.submitted_at)
    end
    local function root(folder, entry, monthly)
        if not folder then return end
        local value = roots[folder]
        if not value then value = { parent = entry, monthly = monthly }; roots[folder] = value end
        if since(entry) < since(value.parent) then value.parent = entry end
        value.monthly = value.monthly or monthly
    end
    for _, entry in pairs(state.entries) do
        root(side.root(entry.path), entry, true)
        root(require("parley.document_move_plan").side_path(entry.path), entry, false)
    end
    local function scan(folder, value, months)
        local stat = uv.fs_lstat(folder)
        if not stat or stat.type ~= "directory" then return end
        local directory = uv.fs_scandir(folder)
        while directory do
            local name, kind = uv.fs_scandir_next(directory)
            if not name then break end
            local path = folder .. "/" .. name
            if kind == "directory" and months and side.month(name) then
                scan(path, value, false)
            elseif kind == "file" and name:match("%.md$") then
                local file = uv.fs_stat(path)
                if file and file.type == "file" and not by_path[path] then
                    local candidate = { path = path, parent = value.parent.path,
                        mtime_sec = file.mtime.sec, mtime_id = mtime_id(file) }
                    files[#files + 1], by_path[path] = candidate, candidate
                end
            end
        end
    end
    for folder, value in pairs(roots) do scan(folder, value, value.monthly) end
    table.sort(files, function(x, y) return x.path < y.path end)
    local events = {}
    -- The provisional parent is the oldest tracked attachment in this root:
    -- mtime selection remains cheap. Read only selected headers, then repeat
    -- that rule with the proven actual parent, never the provisional one.
    for _, event in ipairs(Model.scan(state, files)) do
        local ok, head = pcall(vim.fn.readfile, event.path, "", SIDE_HEAD_LINES)
        if ok and M.is_side_doc(head) then
            local candidate = by_path[event.path]
            local parent = side.parent(event.path, head)
            if parent and state.entries[parent] and side.relation(event.path, parent, head) then
                local real_child, real_parent = uv.fs_realpath(event.path), uv.fs_realpath(parent)
                if real_child and real_parent and side.relation(real_child, real_parent, head) then
                    candidate.parent = parent
                    local selected = Model.scan(state, { candidate })
                    if selected[1] then events[#events + 1] = selected[1] end
                end
            end
        end
    end
    return events
end

--- The operator's own saves suppress discovery for flat/monthly side files,
--- including legacy nested direct folders already represented in the finder.
function M.saved(buf)
    if vim.bo[buf].buftype ~= "" then return end
    local name = vim.api.nvim_buf_get_name(buf)
    if name == "" then return end
    local path = vim.fn.fnamemodify(name, ":p")
    if not require("parley.side_document_path").member(path) and not path:match("%.side/[^/]+%.md$") then return end
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
---@param options table|nil # { run, picker, history, limit, store, home, own_slot } for tests
function M.open(options)
    local seam = seams(options)
    local home = (options and options.home) or vim.env.HOME
    require("parley.highlight_groups").keep("attention", define_highlights)
    define_highlights()
    -- The file in the current window is already in front of the operator.
    local current = vim.api.nvim_buf_get_name(0)
    current = current ~= "" and vim.fn.fnamemodify(current, ":p") or nil
    local slot, all_slots, latest
    local function items(state)
        local shown = vim.tbl_filter(function(entry) return entry.path ~= current end, Model.list(state, not all_slots and slot or nil))
        return Rows.items(shown, { home = home })
    end
    local function show(state)
        latest = state
        local handle
        local config = (package.loaded.parley or {}).config or require("parley.config")
        local bindings = require("parley.keybinding_registry")
        local clear_keys = bindings.keys_for("attention_clear", config)
        local function title()
            return "Attention — " .. (all_slots and "all slots" or slot)
                .. (#clear_keys > 0 and (" — " .. table.concat(clear_keys, "/") .. " clear shown") or "")
        end
        local function repaint(prefer_unread)
            if not handle then return end
            local selected = handle.selected and handle.selected()
            local shown, initial = items(latest)
            local retarget = prefer_unread and (not handle.current_query or handle.current_query() == "")
            handle.update(shown, nil, retarget and initial or (selected and selected.value or nil),
                retarget and { ensure_visible = true } or nil)
            if handle.set_title then handle.set_title(title()) end
        end
        local mappings = slot and { { key = bindings.keys_for("attention_scope", config),
            fn = function() all_slots = not all_slots; repaint(true) end } } or {}
        mappings[#mappings + 1] = { key = clear_keys, fn = function(_, _, context)
            local paths = vim.tbl_map(function(item) return item.value end, context.items)
            apply({ type = "clear", paths = paths }, seam.store, function(next_state, count)
                if not next_state then return end
                latest = next_state
                repaint()
                logger.info(("Cleared %d entries."):format(count))
            end)
        end }
        local shown, initial = items(state)
        handle = seam.picker.open({
            title = title(),
            items = shown,
            initial_index = initial,
            filter_items = Rows.filter,
            anchor = "top", -- forest preorder must put parents physically above children
            mappings = mappings,
            on_select = function(item) select(item.value, seam, options and options.on_selected) end,
        })
        M.refresh(options, function(next_state) latest = next_state; repaint() end, options and options.on_refreshed)
    end
    local couch = require("parley.couch")
    local own_slot = options and options.own_slot or couch.own_slot
    own_slot(function(actors, own)
        slot = couch.slot(own)
        all_slots = slot == nil
        if actors and not slot then logger.warning("attention: slot unavailable; showing all slots, reopen to retry") end
        apply({ type = "sweep", grace = Store.grace_seconds() }, seam.store, function(swept)
            local state = swept or Store.load()
            local events = M.discover(state)
            if #events == 0 then return show(state) end
            apply({ type = "batch", events = events }, seam.store, function(found)
                show(found or Store.load())
            end)
        end)
    end)
end

return M
