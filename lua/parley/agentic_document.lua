-- Admission for named Markdown in a Couch pane. Registry knowledge is kept
-- separate from the existing edit-turn engine; unavailable knowledge is editable.
local M = {}
local couch = require("parley.couch")
local registry = require("parley.document_registry")
local lifecycle = require("parley.document_session")
local uv = vim.uv or vim.loop
local states, serial, retry_timer = {}, 0
local dispatch, retry_loaded, install_migration_hooks, advance_move, recover_migration

local function state_root()
    return require("parley").config.state_dir or require("parley.config").state_dir
end

local function reseed(s, registration, receipt)
    serial = serial + 1
    s.incarnation = serial
    s.model = lifecycle.new({ path = s.path, namespace = s.namespace, incarnation = serial,
        registration = registration, receipt = receipt })
end

local function notify(message)
    vim.notify("agentic document: " .. tostring(message), vim.log.levels.WARN)
end

local function canonical(path)
    if path == "" then return "" end
    local absolute = vim.fn.fnamemodify(path, ":p")
    return uv.fs_realpath(absolute) or ((uv.fs_realpath(vim.fs.dirname(absolute)) or vim.fs.dirname(absolute)) .. "/" .. vim.fs.basename(absolute))
end

local function namespace()
    local thread = couch.thread()
    if not thread then return nil end
    -- Scope knowledge at least as narrowly as the selected storage authority and
    -- pane namespace. Thread tags select actors, not registry membership.
    return table.concat({ vim.env.COUCH_ISOLATED_ROOT or "", vim.env.COUCH_STORE_DIR or "account-singleton", thread.scope }, "\n")
end

local function hash(buf)
    return vim.fn.sha256(vim.json.encode(vim.api.nvim_buf_get_lines(buf, 0, -1, false)))
end

-- The executor has just proven NEW's original inode and bytes. A buffer-name
-- API rename leaves Neovim's "not edited" flag set, so ordinary writes (including
-- auto-save) would refuse NEW with E13. A non-bang native read acknowledges it;
-- never force a write or discard an edit made during the handoff.
local function acknowledge_owned_move(s, path, expected)
    if vim.bo[s.buf].modified or hash(s.buf) ~= expected then return false, "buffer changed during owned move" end
    local undo = vim.o.undoreload
    s.owned_renaming = true
    local ok, err = pcall(vim.api.nvim_buf_call, s.buf, function()
        local view = vim.fn.winsaveview()
        vim.o.undoreload = -1 -- bounded by Couch's document size; preserve large-file undo too.
        local read_ok, read_err = pcall(function()
            vim.api.nvim_buf_set_name(s.buf, path)
            require("parley.session_sync").with_buffer_read(s.buf, function()
                vim.cmd("silent keepalt keepjumps edit")
            end)
        end)
        vim.o.undoreload = undo
        vim.fn.winrestview(view)
        if not read_ok then error(read_err, 0) end
    end)
    vim.o.undoreload = undo
    s.owned_renaming = nil
    if not ok then return false, tostring(err) end
    if hash(s.buf) ~= expected then return false, "owned move read different content" end
    return true
end

local function mtime(path)
    local st = uv.fs_stat(path)
    return st and (st.mtime.sec .. "." .. st.mtime.nsec) or ""
end

local function valid(s)
    local thread = couch.thread()
    return states[s.buf] == s and vim.api.nvim_buf_is_loaded(s.buf)
        and thread and thread.scope == s.thread.scope and thread.tag == s.thread.tag
        and namespace() == s.namespace and (canonical(vim.api.nvim_buf_get_name(s.buf)) == s.path
            or (s.move and canonical(vim.api.nvim_buf_get_name(s.buf)) == s.move.new_path))
end

-- A raw completion belongs to one controller incarnation. Managed native
-- reads retain it, but may briefly unload the buffer inside synchronous IO.
local function completed(s, callback)
    local incarnation = s.incarnation
    return function(...)
        if states[s.buf] ~= s or s.incarnation ~= incarnation then return end
        local args = { n = select("#", ...), ... }
        local function deliver()
            if valid(s) and s.incarnation == incarnation then callback(unpack(args, 1, args.n)) end
        end
        if s.reading or require("parley.session_sync").is_buffer_read(s.buf) then
            s.reading = true
            s.completions = s.completions or {}
            s.completions[#s.completions + 1] = deliver
        else deliver() end
    end
end

local function band(s, message, highlight)
    for _, win in ipairs(vim.fn.win_findbuf(s.buf)) do
        local old = s.bands[win]
        if message ~= "" then
            if not old then old = { before = vim.wo[win].winbar }; s.bands[win] = old end
            old.installed = "%#" .. (highlight or "WarningMsg") .. "# " .. message:gsub("%%", "%%%%") .. "%="
            vim.wo[win].winbar = old.installed
        elseif old then
            if vim.wo[win].winbar == old.installed then vim.wo[win].winbar = old.before end
            s.bands[win] = nil
        end
    end
end

local function show_feedback(s, message, is_error)
    local ss = require("parley.session_sync")
    if ss.set_submission_feedback(s.buf, message, is_error) then
        s.feedback = nil
        band(s, "")
    else
        local view = ss.feedback_view(message, is_error)
        s.feedback = { label = view.label, hl = view.hl, is_error = is_error }
        band(s, view.label, view.hl)
    end
end

local function clear_feedback(s)
    if not s.feedback then return end
    s.feedback = nil
    band(s, s.model.snapshot().phase == "unknown" and "Couch unavailable: agentic state unknown" or "")
end

local function cache(s, registration, remove)
    local root = state_root()
    local lease = require("parley.document_lease").acquire(s.namespace, "known-cache", { root = root })
    if not lease then return nil end -- cache loss means unknown, never plain.
    local directory = root .. "/document-cache/" .. vim.fn.sha256(s.namespace)
    local made = pcall(require("parley.fs").ensure_dir, directory, 448)
    if not made then lease.release(); return nil end
    local path, temporary = directory .. "/known.json", directory .. "/next.json"
    -- The one declared cache temp belongs to this namespace lease, including
    -- recovery after writer death. No sibling glob or age cleanup is used.
    if uv.fs_lstat(temporary) then uv.fs_unlink(temporary) end
    local entries = {}
    local st = uv.fs_stat(path)
    if st and st.size <= 1024 * 1024 then
        local f = io.open(path, "rb")
        if f then
            local bytes = f:read("*a"); f:close()
            local ok, decoded = pcall(vim.json.decode, bytes)
            if ok and type(decoded) == "table" and decoded.version == 1 and type(decoded.entries) == "table" then
                for _, entry in ipairs(decoded.entries) do
                    if #entries >= 256 then break end
                    if type(entry) == "table" then
                        local r = lifecycle.classify_reply("lookup", 0, { Code = "ok", Registration = entry.registration }, vim.NIL)
                        if r.kind == "registered" and type(entry.at) == "number" then entries[#entries + 1] = entry end
                    end
                end
            end
        end
    end
    local found
    for i = #entries, 1, -1 do
        if entries[i].registration.File == s.path then
            found = entries[i].registration
            if registration or remove then table.remove(entries, i) end
        end
    end
    if registration then entries[#entries + 1] = { registration = registration, at = os.time() } end
    if registration or remove then
        table.sort(entries, function(a, b) return a.at > b.at end)
        while #entries > 256 do table.remove(entries) end
        local bytes = vim.json.encode({ version = 1, entries = entries })
        if #bytes <= 1024 * 1024 then
            local written = require("parley.helper").write_file_atomic(bytes, path, { temp_path = function() return temporary end })
            if not written then lease.release(); return nil end
        end
    end
    lease.release()
    return found
end

local function adopt(s, registration)
    local feedback = s.feedback
    s.feedback = nil
    band(s, "")
    local ss = require("parley.session_sync")
    ss.attach(s.buf, registration)
    if feedback then ss.set_submission_feedback(s.buf, feedback.label, feedback.is_error) end
    if s.outstanding or vim.bo[s.buf].modified then
        ss.acquire_observed(s.buf, { baseline = s.baseline or s.content, loaded = s.loaded, outstanding = true })
    end
    s.outstanding, s.baseline = false, nil
    cache(s, registration)
end

local function ensure_retry()
    if retry_timer then return end
    retry_timer = uv.new_timer()
    retry_timer:start(5000, 5000, vim.schedule_wrap(function() retry_loaded() end))
end

local function execute(s, effects)
    for _, effect in ipairs(effects) do
        if not valid(s) then return end
        local kind = effect.kind
        if kind == "lookup" or kind == "register" then
            local args = kind == "register" and { effect.witness.path, effect.owner } or { effect.witness.path }
            s.request = registry.request(kind, args, effect.witness, completed(s, function(result)
                if not valid(s) then return end
                s.request = nil
                if kind == "register" and not effect.resume_only and s.saved_hash and hash(s.buf) ~= s.saved_hash then
                    dispatch(s, { type = "changed" })
                end
                if kind == "lookup" and result.kind == "absent" then cache(s, nil, true) end
                dispatch(s, { type = "reply", witness = effect.witness, result = result })
                if s.model.snapshot().phase == "unknown" then ensure_retry() end
                if s.queued_submit and not s.model.snapshot().operation then
                    s.queued_submit = false
                    M.submit(s.buf)
                end
            end))
        elseif kind == "save" then
            local ss = require("parley.session_sync")
            local ok, err
            if ss.is_session_sync(s.buf) then ok, err = ss.prepare_submit(s.buf)
            else ok, err = pcall(vim.api.nvim_buf_call, s.buf, function() vim.cmd("stopinsert"); vim.cmd("silent write") end) end
            if ok then s.saved_hash = hash(s.buf) end
            dispatch(s, { type = "saved", witness = effect.witness, ok = not not ok, error = err, hash = s.saved_hash })
        elseif kind == "attach" then adopt(s, effect.registration)
        elseif kind == "detach_turn" then
            local ss = require("parley.session_sync")
            local token, err = ss.begin_move(s.buf)
            local ok = token ~= nil
            if token then ok, err = ss.abort_move(s.buf, token) end
            if ok then ss.detach(s.buf) end
            dispatch(s, { type = "turn_detached", witness = effect.witness, ok = ok, error = err })
        elseif kind == "move" then
            if s.move then s.move.witness = effect.witness end
        elseif kind == "rename" then
            s.request = registry.request("rename", { effect.old_path, effect.new_path }, effect.witness, completed(s, function(result)
                if valid(s) then dispatch(s, { type = "reply", witness = effect.witness, result = result }) end
            end))
        elseif kind == "finish_move" then
            local moving = s.move
            local ok, err = require("parley.session_sync").finish_move(s.buf, moving.token, effect.registration)
            if not ok then notify(err); return end
            cache(s, nil, true)
            s.path = effect.new_path
            cache(s, effect.registration)
            s.loaded, s.content = mtime(s.path), hash(s.buf)
            require("parley.session_sync").release_if_baseline(s.buf)
            if moving.metadata_done then moving.metadata_done({ kind = "registered", registration = effect.registration }) end
        elseif kind == "send" then
            require("parley.session_sync").send_registered(s.buf, effect.registration, completed(s, function(result)
                if valid(s) then
                    dispatch(s, { type = "sent", witness = effect.witness, ok = result.code == 0,
                        error = result.stderr, display_time = os.date("%H:%M") })
                end
            end))
        elseif kind == "feedback" then
            show_feedback(s, effect.message, false)
        elseif kind == "band" then
            if s.feedback then band(s, s.feedback.label, s.feedback.hl) else band(s, effect.message) end
            if effect.message ~= "" then ensure_retry() else s.baseline, s.outstanding = nil, false end
        elseif kind == "notify" or kind == "reconcile" then
            local message = effect.message or effect.error or "Operation outcome pending; Alt+Return retries confirmation"
            show_feedback(s, "operation failed: " .. tostring(message), true)
            notify(message)
        elseif kind == "cancel" then
            if s.request then s.request.cancel(); s.request = nil end
        end
    end
end

dispatch = function(s, event)
    event.now_ms = event.now_ms or uv.hrtime() / 1000000
    execute(s, s.model.dispatch(event))
end

retry_loaded = function()
    local remaining = false
    for _, s in pairs(states) do
        if valid(s) and not s.recovery_pending and s.model.snapshot().phase == "unknown" then
            remaining = true
            dispatch(s, { type = "open" })
        end
    end
    if not remaining and retry_timer then retry_timer:stop(); retry_timer:close(); retry_timer = nil end
end

function M.attach(buf)
    if states[buf] then
        if states[buf].reading then return true end
        if valid(states[buf]) then return true end
        M.detach(buf)
    end
    local ns = namespace()
    local path = canonical(vim.api.nvim_buf_get_name(buf))
    if not ns or path == "" or not require("parley").is_markdown(buf, vim.api.nvim_buf_get_name(buf)) then return false end
    serial = serial + 1
    local s = { buf = buf, path = path, namespace = ns, thread = couch.thread(), incarnation = serial,
        bands = {}, content = hash(buf), loaded = mtime(path) }
    local known = cache(s)
    s.model = lifecycle.new({ path = path, namespace = ns, incarnation = serial, registration = known })
    states[buf] = s
    if known then adopt(s, known) end
    local function attach_edits()
        if s.edits_attached then return end
        s.content = hash(buf)
        s.edits_attached = vim.api.nvim_buf_attach(buf, false, {
            on_lines = function()
                if states[buf] ~= s then return true end
                local previous = s.content; s.content = hash(buf)
                if vim.bo[buf].modified then
                    if previous ~= s.content then
                        clear_feedback(s)
                        dispatch(s, { type = "invalidate_confirmation" })
                    end
                    s.revision = (s.revision or 0) + 1
                    if not M.identity(buf) then
                        s.baseline = s.baseline or previous
                        s.outstanding = s.content ~= s.baseline
                    end
                    local phase = s.model.snapshot().phase
                    if phase == "busy" then dispatch(s, { type = "changed" }) end
                end
            end,
            on_reload = function()
                s.content = hash(buf)
                clear_feedback(s)
                dispatch(s, { type = "invalidate_confirmation" })
                if s.model.snapshot().phase == "busy" then dispatch(s, { type = "changed" }) end
            end,
            on_detach = function() s.edits_attached = false end,
        })
    end
    attach_edits()
    s.group = vim.api.nvim_create_augroup("ParleyAgenticDocument" .. buf, { clear = true })
    vim.api.nvim_create_autocmd({ "BufReadPost", "FileChangedShellPost" }, { group = s.group, buffer = buf, callback = function()
        if s.content ~= hash(buf) then
            s.revision = (s.revision or 0) + 1
            clear_feedback(s)
            dispatch(s, { type = "invalidate_confirmation" })
            if s.model.snapshot().operation then dispatch(s, { type = "changed" }) end
        end
        attach_edits()
        if s.reading then
            -- Resume after native IO and all read observers have reconciled.
            vim.schedule(function()
                if states[buf] ~= s then return end
                s.reading = nil
                local pending = s.completions or {}
                s.completions = nil
                for _, callback in ipairs(pending) do callback() end
            end)
        end
    end })
    vim.api.nvim_create_autocmd("BufUnload", { group = s.group, buffer = buf, callback = function()
        if require("parley.session_sync").is_buffer_read(buf) then
            s.reading = true
            return
        end
        M.detach(buf)
        vim.api.nvim_create_autocmd("BufReadPost", { buffer = buf, once = true, callback = function()
            M.attach(buf)
        end })
    end })
    vim.api.nvim_create_autocmd("BufWipeout", { group = s.group, buffer = buf, callback = function() M.detach(buf) end })
    vim.api.nvim_create_autocmd("BufWinEnter", { group = s.group, buffer = buf, callback = function() M.recheck(buf) end })
    install_migration_hooks(s)
    if not recover_migration(s) then dispatch(s, { type = "open" }) end
    return true
end

function M.identity(buf)
    local s = states[buf]
    return s and s.model.snapshot().registration or nil
end

function M.status(buf)
    return states[buf] and states[buf].model.snapshot() or nil
end

function M.recheck(buf)
    local s = states[buf]
    if s and s.reading then return end
    if s and not valid(s) then M.detach(buf); M.attach(buf); return end
    if s and valid(s) then
        if s.recovery_pending then recover_migration(s) else dispatch(s, { type = "open" }) end
    end
end

function M.submit(buf)
    if not M.attach(buf) then return false end
    local s = states[buf]
    if s.reading or not valid(s) then return true end
    if s.recovery_pending then recover_migration(s); return true end
    local snapshot = s.model.snapshot()
    if snapshot.phase == "pending" then dispatch(s, { type = "retry" }); return true end
    if snapshot.operation then
        if not snapshot.registration and snapshot.phase == "probing" and snapshot.operation.witness.operation == "lookup"
            and not snapshot.operation.args.submit then s.queued_submit = true end
        return true
    end
    local revision = s.revision
    if snapshot.registration then dispatch(s, { type = "submit", owner = snapshot.registration.Owner }); return true end
    if s.resolving then return true end
    s.resolving = true
    couch.own_slot(completed(s, function(_, own)
        s.resolving = false
        if not valid(s) or s.revision ~= revision then return end
        if not own then
            show_feedback(s, "submit failed: cannot resolve this pane's agent", true)
            notify("cannot resolve this pane's agent; nothing submitted")
            return
        end
        dispatch(s, { type = "submit", owner = couch.slot(own) })
    end))
    return true
end

local function bounded_request(operation, arguments)
    local result
    local child = registry.request(operation, arguments, {}, function(value) result = value end)
    local ready = vim.wait(2600, function() return result ~= nil end, 10)
    if not ready then child.cancel(); return { kind = "unavailable", error = "Couch deadline exceeded" } end
    return result
end

local function migration_busy(s)
    local snapshot = s.model.snapshot()
    local operation = snapshot.operation
    return s.reading or s.move or s.recovery_pending or s.resolving or s.queued_submit
        or snapshot.phase == "pending"
        or (operation and (operation.witness.operation ~= "lookup" or operation.args.submit))
end

local function path_busy(path)
    for _, s in pairs(states) do
        if s.path == path and (valid(s) or s.reading) and migration_busy(s) then return true end
    end
    return false
end

-- Public Parley movers must reserve the identity before touching OLD. A plain
-- document keeps the existing mover; unavailable membership refuses only the
-- move, leaving ordinary editing available.
function M.move_membership(path)
    if not namespace() then return false end
    local key = canonical(path)
    if path_busy(key) then return nil, "finish the pending document operation before moving" end
    if require("parley.chat_parser").is_chat_filename(vim.fs.basename(path)) then
        local lines = require("parley.helper").chat_lines(path)
        if lines and not require("parley").not_chat(nil, path, lines) then return false end
    end
    local result = bounded_request("lookup", { key })
    -- Waiting for Couch pumps editor events; a submit may have started meanwhile.
    if path_busy(key) then return nil, "finish the pending document operation before moving" end
    if result.kind == "registered" then return true, result.registration end
    if result.kind == "absent" then
        local header = require("parley.session_sync").parse_header(vim.fn.readfile(path, "", 40))
        if header then return true, { legacy = true, Owner = header.owner } end
        return false
    end
    return nil, result.error or "document membership unavailable; retry the move when Couch returns"
end

function M.move_path(old_path, new_path)
    local caller_path = old_path
    local member, identity = M.move_membership(old_path)
    if member == nil then return true, nil, identity end
    if not member then return false end
    old_path, new_path = canonical(old_path), canonical(new_path)
    local buf = require("parley.helper").buffer_for(old_path, true)
    if not buf then buf = vim.fn.bufadd(old_path); vim.fn.bufload(buf) end
    if not M.attach(buf) then return true, nil, "registered document could not be attached" end
    local s, ss = states[buf], require("parley.session_sync")
    local snapshot = s.model.snapshot()
    if migration_busy(s) then
        return true, nil, "finish the pending document operation before moving"
    end
    if s.request then s.request.cancel(); s.request = nil end
    if identity.legacy then
        ss.attach(buf)
        local saved, save_error = ss.prepare_submit(buf)
        if not saved then return true, nil, save_error end
        local admitted = bounded_request("register", { caller_path, identity.Owner })
        if admitted.kind ~= "registered" then return true, nil, admitted.error or "legacy registration unavailable" end
        identity = admitted.registration
    end
    reseed(s, identity, snapshot.receipt)
    adopt(s, identity)
    local saved, save_error = ss.prepare_submit(buf)
    if not saved then return true, nil, save_error end
    local target = bounded_request("lookup", { new_path })
    if migration_busy(s) then return true, nil, "document operation started during destination confirmation" end
    if target.kind ~= "absent" then return true, nil, "destination membership is occupied or unknown" end
    local lease, lease_error = require("parley.document_lease").acquire(s.namespace, identity.ID, { root = state_root() })
    if not lease then return true, nil, lease_error.message end
    if vim.fn.filereadable(old_path .. ".lock") == 0 then
        local acquired, acquire_error = ss.acquire_observed(buf, { baseline = hash(buf), outstanding = true })
        if not acquired then lease.release(); return true, nil, acquire_error end
    end
    local token, token_error = ss.begin_move(buf)
    if not token then lease.release(); return true, nil, token_error end
    local moving = { token = token, lease = lease, old_path = old_path, new_path = new_path,
        identity = identity, content = hash(buf) }
    s.move = moving
    local operation, err = require("parley.document_move").begin(s.namespace, identity, new_path, {
        root = state_root(), lease = lease, destination_registered = false, move_document = true,
        old_lock = token.lock, new_lock = token.lock, baseline = token.baseline,
        install_new = function() return ss.install_move_lock(buf, token, new_path) end,
        document_moved = function()
            return acknowledge_owned_move(s, new_path, moving.content)
        end,
        metadata = function(_, cb)
            moving.metadata_done = cb
            dispatch(s, { type = "moved", witness = moving.witness, ok = true })
        end,
    })
    if not operation then
        moving.error, moving.journal_pending = err.message, err.kind == "pending"
        if not moving.journal_pending then
            ss.abort_move(buf, token); lease.release(); s.move = nil; ss.release_if_baseline(buf)
        end
        return true, nil, err.message
    end
    moving.operation = operation
    dispatch(s, { type = "rename", new_path = new_path })
    advance_move(s)
    local complete = vim.wait(3000, function() return s.move == nil end, 10)
    if not complete then return true, nil, "document move pending; preserve its journal and reopen to recover" end
    return true, new_path
end

advance_move = function(s)
    local moving = s.move
    if not moving or not moving.operation or not moving.witness then return end
    require("parley.document_move").advance(moving.operation, function(result)
        if states[s.buf] ~= s then return end
        if result.kind == "registered" then s.move = nil
        else
            notify(result.error or "Migration is pending; preserve the journal for recovery")
            if s.model.snapshot().operation and s.model.snapshot().operation.witness.operation == "move" then
                dispatch(s, { type = "moved", witness = moving.witness, ok = false, error = result.error })
            end
        end
    end)
end

recover_migration = function(s, fresh_write)
    if s.recovering then return true end
    local mover = require("parley.document_move")
    local pending, scan_error = mover.pending(s.namespace, { root = state_root() })
    if not pending then
        s.recovery_pending = true
        band(s, "Pending document move: " .. scan_error.message)
        return true
    end
    local journal
    for _, entry in ipairs(pending) do
        if entry.old == s.path or entry.new == s.path then journal = entry; break end
    end
    if not journal then s.recovery_pending = nil; return false end
    s.recovery_pending = true
    if journal.new ~= s.path and not journal.document_move then
        band(s, "Pending document move: open " .. journal.new .. " to recover")
        return true
    end
    s.recovering = true
    local ss, token = require("parley.session_sync"), nil
    local content = hash(s.buf)
    local operation, err = mover.recover(s.namespace, journal.id, {
        root = state_root(), old_path = journal.old, new_path = journal.new,
        new_written = fresh_write == true,
        reconcile = function()
            if token then return true end
            local restore_error
            token, restore_error = ss.restore_move(s.buf, journal.registration, journal.new, journal.protection)
            return token ~= nil, restore_error
        end,
        document_moved = function()
            local ok, name_error = acknowledge_owned_move(s, journal.new, content)
            if ok then s.path = journal.new end
            return ok, name_error
        end,
        finish = function(_, result)
            local ok, finish_error = ss.finish_move(s.buf, token, result.registration)
            if not ok then return false, finish_error end
            cache({ namespace = s.namespace, path = journal.old }, nil, true)
            band(s, "")
            reseed(s, result.registration, s.model.snapshot().receipt)
            cache(s, result.registration)
            ss.release_if_baseline(s.buf)
            return true
        end,
    }, function(result)
        if states[s.buf] ~= s then return end
        s.recovering = false
        if result.kind == "registered" then
            s.move, s.recovery_pending = nil, nil
        else
            if s.move and s.move.operation then s.move.operation.release(); s.move = nil end
            band(s, "Pending document move: " .. tostring(result.error))
        end
    end)
    if not operation then
        s.recovering = false
        band(s, "Pending document move: " .. err.message)
    elseif s.recovery_pending then s.move = { operation = operation, new_path = journal.new, token = token } end
    return true
end

install_migration_hooks = function(s)
    local ss = require("parley.session_sync")
    local function refuse(message) error("agentic document migration: " .. tostring(message), 0) end
    vim.api.nvim_create_autocmd("BufFilePre", { group = s.group, buffer = s.buf, callback = function()
        if s.owned_renaming then return end
        if s.move then
            if s.move.error and not s.move.operation and not s.move.journal_pending then
                s.move.cancel_attempt = true
                return
            end
            refuse("finish the pending move before another rename")
        end
        if migration_busy(s) then
            refuse("document operation is still in progress")
        end
        local identity = M.identity(s.buf)
        if not identity then
            local legacy = ss.identity(s.buf)
            local result
            if legacy then
                if not legacy.Owner then refuse("legacy document owner unavailable") end
                result = bounded_request("register", { s.path, legacy.Owner })
            else
                result = bounded_request("lookup", { s.path })
            end
            if migration_busy(s) then refuse("document operation started during membership confirmation") end
            if result.kind ~= "registered" and result.kind ~= "absent" then
                refuse(result.error or "document membership unavailable")
            end
            if s.request then s.request.cancel(); s.request = nil end
            -- New model witnesses must never alias a cancelled open probe.
            reseed(s, result.registration)
            if result.kind == "absent" then return end -- positively plain; never registers.
            adopt(s, result.registration)
            identity = result.registration
        end
        if s.model.snapshot().operation then refuse("document operation is still in progress") end
        local lease, lease_err = require("parley.document_lease").acquire(s.namespace, identity.ID,
            { root = state_root() })
        if not lease then refuse(lease_err.message) end
        -- Protect a free-to-free handoff too: registry publication and local
        -- completion are different process events. This synthetic turn is
        -- released after confirmation only if no edit left its baseline.
        if vim.fn.filereadable(identity.File .. ".lock") == 0 then
            local acquired, acquire_error = ss.acquire_observed(s.buf, { baseline = hash(s.buf), outstanding = true })
            if not acquired then lease.release(); refuse(acquire_error or "cannot protect migration") end
        end
        local token, err = ss.begin_move(s.buf)
        if not token then lease.release(); refuse(err) end
        s.move = { token = token, lease = lease, old_path = s.path, identity = identity }
    end })
    vim.api.nvim_create_autocmd("BufFilePost", { group = s.group, buffer = s.buf, callback = function()
        if s.owned_renaming then return end
        local moving = s.move
        if not moving then
            -- A never-submitted rename stays plain, but future submission must
            -- target the new canonical name rather than a stale open-time path.
            s.path = canonical(vim.api.nvim_buf_get_name(s.buf))
            dispatch(s, { type = "changed", path = s.path })
            M.recheck(s.buf)
            return
        end
        moving.new_path = canonical(vim.api.nvim_buf_get_name(s.buf))
        if moving.cancel_attempt then
            moving.cancel_attempt = nil
            if moving.new_path ~= moving.old_path then refuse("return to " .. moving.old_path .. " before retrying this refused move") end
            local ok, err = ss.abort_move(s.buf, moving.token)
            if not ok then refuse(err) end
            moving.lease.release()
            s.move = nil
            ss.release_if_baseline(s.buf)
            return
        end
        local target = bounded_request("lookup", { moving.new_path })
        if target.kind ~= "absent" then moving.error = "destination membership is occupied or unknown"; refuse(moving.error) end
        local operation, err = require("parley.document_move").begin(s.namespace, moving.identity, moving.new_path, {
            root = state_root(), lease = moving.lease, destination_registered = false,
            old_lock = moving.token.lock, new_lock = moving.token.lock, baseline = moving.token.baseline,
            install_new = function() return ss.install_move_lock(s.buf, moving.token, moving.new_path) end,
            metadata = function(_, cb)
                moving.metadata_done = cb
                dispatch(s, { type = "moved", witness = moving.witness, ok = true })
            end,
        })
        if not operation then moving.error, moving.journal_pending = err.message, err.kind == "pending"; refuse(moving.error) end
        moving.operation = operation
        dispatch(s, { type = "rename", new_path = moving.new_path })
    end })
    vim.api.nvim_create_autocmd("BufWritePre", { group = s.group, buffer = s.buf, callback = function()
        if s.move and (s.move.error or not s.move.operation) then refuse(s.move.error or "migration preflight incomplete") end
    end })
    vim.api.nvim_create_autocmd("BufWritePost", { group = s.group, buffer = s.buf, callback = function()
        if s.recovery_pending then recover_migration(s, true) elseif s.move then advance_move(s) end
    end })
end

function M.detach(buf)
    local s = states[buf]
    if not s then return end
    s.model.dispatch({ type = "detach" })
    states[buf] = nil
    if s.request then s.request.cancel() end
    if s.move then
        if s.move.operation then s.move.operation.release() elseif s.move.lease then s.move.lease.release() end
    end
    band(s, "")
    if s.group then pcall(vim.api.nvim_del_augroup_by_id, s.group) end
    require("parley.session_sync").detach(buf)
    retry_loaded()
end

return M
