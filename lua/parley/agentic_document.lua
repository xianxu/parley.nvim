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

-- The executor has just proven NEW's bytes under the document lease. A buffer-name
-- API rename leaves Neovim's "not edited" flag set, so ordinary writes (including
-- auto-save) would refuse NEW with E13. A non-bang native read acknowledges it;
-- never force a write or discard an edit made during the handoff.
local function read_moved_document(s, path, expected, after, alternate_after)
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
    local observed = hash(s.buf)
    if observed ~= after and observed ~= alternate_after then
        -- The native read may clear 'modified' after a BufReadPost edit. Keep
        -- the differing text visibly unsaved so a later reopen cannot discard it.
        vim.bo[s.buf].modified = true
        return false, "move read different or modified content"
    end
    if vim.bo[s.buf].modified then
        return false, "move read different or modified content"
    end
    return true
end
local function acknowledge_owned_move(s, path, expected)
    return read_moved_document(s, path, expected, expected)
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

-- The IO dispatcher owns raw-byte witnesses. This boundary owns editor-content
-- hashes and refuses a changed buffer before the guarded native reread.
local function editor_snapshot(s, moving)
    return function()
        if states[s.buf] ~= s or not vim.api.nvim_buf_is_loaded(s.buf) or vim.bo[s.buf].modified
            or not moving.content or hash(s.buf) ~= moving.content then
            return nil, "buffer changed before document move"
        end
        return moving.content
    end
end
local function projected_editor_hash(buf, old_path, new_path)
    local projected, projection_error = require("parley.document_move_plan").rewrite_side_references(
        table.concat(vim.api.nvim_buf_get_lines(buf, 0, -1, false), "\n"), old_path, new_path)
    if not projected then return nil, projection_error end
    return vim.fn.sha256(vim.json.encode(vim.split(projected, "\n", { plain = true })))
end
local function parent_rewritten(s, moving)
    return function(operation, proof)
        if states[s.buf] ~= s or not vim.api.nvim_buf_is_loaded(s.buf)
            or not s.recovering and s.move ~= moving or type(proof) ~= "table"
            or proof.path ~= moving.new_path or canonical(vim.api.nvim_buf_get_name(s.buf)) ~= proof.path then
            return false, "document move editor incarnation changed"
        end
        local before = moving.content
        if not before then return false, "document move lacks an editor preimage" end
        -- BufReadPost edits can end with 'modified' cleared by the native read.
        -- Derive the expected editor postimage from the same pure rewrite used
        -- for disk bytes, keeping line-ending/encoding normalization in Neovim.
        local expected, projection_error = projected_editor_hash(s.buf, operation.old, operation.new)
        if not expected then return false, projection_error end
        local read, read_error = read_moved_document(s, proof.path, before, expected)
        if not read then return false, read_error end
        local baseline_before = proof.before_editor_hash or before
        local synced, protection = require("parley.session_sync").synchronize_move(s.buf, moving.token, baseline_before)
        if not synced then return false, protection end
        s.loaded, s.content = mtime(proof.path), hash(s.buf)
        moving.content = s.content
        return true, protection
    end
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

-- A deadline from the operator's config, else the shipped default (config.lua
-- is the one place the numbers live).
local function config_ms(key)
    local value = (require("parley").config or {})[key]
    if type(value) == "number" and value > 0 then return value end
    return require("parley.config")[key]
end

local function band(s, message, highlight)
    if message == "" then s.renderer.clear()
    else
        local plain = s.model.snapshot().phase == "plain"
        s.renderer.render({ overlay = true, state = plain and "plain" or "unknown",
            hl = plain and "WinBar" or "WarningMsg",
            feedback = { label = message, hl = highlight or "WarningMsg" } })
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

-- A move's state lives on `s.move` (the `moving` table) from its reservation
-- until Couch confirms it. The fields, in the order they can become set:
--   token, lease, old_path, identity   reserved (BufFilePre / move_path)
--   new_path, operation                journaled: document_move.begin
--   witness                            the model issued the move
--   metadata_done                      the document moved; Couch's rename is out
--   overdue                            ...past the submit deadline (row 5)
--   answered                           Couch replied: confirmed, or refused/lost
--   pending_error                      advance reported pending on the spot
--   error, journal_pending             refused before or at begin
-- `s.move` returns to nil on confirmation, or on an abort before anything moved.
-- move_outcome projects rows 1 and 5-7 from (moved, overdue, the reply).

-- forward declaration: show_move is defined below, used by moving_metadata.
local show_move

-- document_move's metadata step for an owned move or rename: hand the rename
-- to the model, then show it confirming, and finishing in the background past
-- the submit deadline (#359, rows 1 and 5).
local function moving_metadata(s, moving)
    return function(_, cb)
        moving.metadata_done = cb
        dispatch(s, { type = "moved", witness = moving.witness, ok = true })
        if s.move ~= moving then return end
        show_move(s, moving)
        vim.defer_fn(function()
            if states[s.buf] ~= s or s.move ~= moving or moving.answered then return end
            moving.overdue = true
            show_move(s, moving)
        end, config_ms("agentic_submit_timeout_ms"))
    end
end

-- What the operator sees of a move once its document moved (#359): the plan's
-- state table, one row at a time, through the submit feedback surface.
show_move = function(s, moving, result)
    local version = moving.version or moving.operation and moving.operation.journal.version
    local view = require("parley.document_move_plan").move_outcome({ moved = true, new_path = moving.new_path,
        overdue = moving.overdue, result = result, forward_only = version == 2 })
    -- session_sync holds its winbar still while it is moving, so the band
    -- carries the move, styled as submit feedback is.
    if view.band == "" then band(s, ""); return view end
    local styled = require("parley.session_sync").feedback_view(view.band, view.action ~= "none" and view.action ~= "wait")
    band(s, styled.label, view.warning and "WarningMsg" or styled.hl)
    return view
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


-- #357: one submit at a time per document, from the press to its outcome. The
-- editor never waits on it; past the deadline the band says so and offers the
-- one action (Alt+Return), while a send already issued keeps running, since
-- killing it cannot tell delivered from not.
local NOT_CONFIRMED = "not confirmed: submit again"

local function end_submit(s)
    local submitting = s.submitting
    s.submitting = nil
    if submitting and submitting.timer then submitting.timer:stop(); submitting.timer:close() end
end

local function begin_submit(s)
    end_submit(s)
    local submitting = { timer = uv.new_timer() }
    s.submitting = submitting
    show_feedback(s, "submitting…", false)
    local ms = config_ms("agentic_submit_timeout_ms")
    submitting.timer:start(ms, 0, vim.schedule_wrap(function()
        if s.submitting ~= submitting or not valid(s) then return end
        submitting.overdue = true
        show_feedback(s, NOT_CONFIRMED .. " · Couch did not answer within " .. math.ceil(ms / 1000) .. " s", true)
    end))
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
            end), { timeout_ms = config_ms("agentic_submit_timeout_ms") })
        elseif kind == "save" then
            local ss = require("parley.session_sync")
            local ok, err
            if ss.is_session_sync(s.buf) then ok, err = ss.prepare_submit(s.buf)
            else ok, err = pcall(vim.api.nvim_buf_call, s.buf, function() vim.cmd("stopinsert"); vim.cmd("silent write") end) end
            if ok then s.saved_hash = hash(s.buf) end
            dispatch(s, { type = "saved", witness = effect.witness, ok = not not ok, error = err, hash = s.saved_hash })
        elseif kind == "attach" then adopt(s, effect.registration)
        elseif kind == "resubmit" then
            end_submit(s)
            M.submit(s.buf)
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
            -- The band says "finishing in the background" at the submit deadline;
            -- the rename itself gets three of them before its reply counts as
            -- lost (#359: the file already moved, so waiting costs nothing).
            s.request = registry.request("rename", { effect.old_path, effect.new_path }, effect.witness, completed(s, function(result)
                if valid(s) then dispatch(s, { type = "reply", witness = effect.witness, result = result }) end
            end), { timeout_ms = 3 * config_ms("agentic_submit_timeout_ms") })
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
                    local submitting = s.submitting
                    dispatch(s, { type = "sent", witness = effect.witness, ok = result.code == 0,
                        error = result.stderr, display_time = os.date("%H:%M") })
                    -- A delivery the model doesn't announce (the body moved on
                    -- meanwhile) still ends this submit: its deadline is moot.
                    if s.submitting == submitting then end_submit(s) end
                end
            end))
        elseif kind == "feedback" then
            end_submit(s)
            show_feedback(s, effect.message, false)
        elseif kind == "band" then
            if effect.message == "" then end_submit(s) end -- the document turned out plain
            if s.feedback then band(s, s.feedback.label, s.feedback.hl) else band(s, effect.message) end
            if effect.message ~= "" then ensure_retry() else s.baseline, s.outstanding = nil, false end
        elseif kind == "reconcile" and effect.operation == "rename" and s.move and s.move.new_path then
            -- Moved on disk; Couch refused or lost the metadata rename (rows 6, 7).
            s.move.answered = true
            local view = show_move(s, s.move, { kind = "unavailable", code = effect.code, error = effect.error })
            -- The band may cut a long path; the notification keeps the whole
            -- command for pasting.
            notify(view.band .. (effect.error and (" (" .. effect.error .. ")") or ""))
        elseif kind == "notify" or kind == "reconcile" then
            local message = effect.message or effect.error or "Operation outcome pending; Alt+Return retries confirmation"
            if s.submitting then
                end_submit(s)
                show_feedback(s, NOT_CONFIRMED .. " · " .. tostring(message), true)
            else
                show_feedback(s, "operation failed: " .. tostring(message), true)
            end
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
        renderer = require("parley.document_band").new(buf), content = hash(buf), loaded = mtime(path) }
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
        -- A guarded mechanical move read checks its editor preimage and the IO
        -- dispatcher rechecks the raw postimage. It must not stale its own move
        -- witness; other rereads still invalidate an outstanding mutation.
        if s.content ~= hash(buf) and not s.owned_renaming then
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
    if snapshot.phase == "pending" then
        -- The operator pressed again. A pending registration is confirmed and
        -- then submitted afresh (the model's `resubmit`, #357); a pending rename
        -- or move is only confirmed.
        local resubmit = snapshot.pending and snapshot.pending.witness.operation == "register"
        if resubmit then begin_submit(s) end
        dispatch(s, { type = "retry", submit = resubmit })
        return true
    end
    if snapshot.operation then
        if s.submitting then
            -- Join the submit in flight: never a second couch --send-to (#357).
            show_feedback(s, s.submitting.overdue and "submitting… still waiting for Couch" or "submitting…", false)
            return true
        end
        if not snapshot.registration and snapshot.phase == "probing" and snapshot.operation.witness.operation == "lookup"
            and not snapshot.operation.args.submit then s.queued_submit = true end
        return true
    end
    local revision = s.revision
    if snapshot.registration then
        begin_submit(s)
        dispatch(s, { type = "submit", owner = snapshot.registration.Owner })
        return true
    end
    if s.resolving then return true end
    begin_submit(s)
    s.resolving = true
    couch.own_slot(completed(s, function(_, own)
        s.resolving = false
        if not valid(s) or s.revision ~= revision then end_submit(s); return end
        if not own then
            end_submit(s)
            show_feedback(s, "submit failed: cannot resolve this pane's agent", true)
            notify("cannot resolve this pane's agent; nothing submitted")
            return
        end
        dispatch(s, { type = "submit", owner = couch.slot(own) })
    end))
    return true
end

-- The one inline Couch question a move still asks (#359): BufFilePost's check of
-- an existing NEW before a :saveas! overwrite, since Neovim writes it before
-- Couch could refuse. The buffer is already renamed there, so its recovery
-- says to rename back first. The registry's own timer is set past this wait,
-- so this one decides.
local function bounded_request(operation, arguments)
    local ms = config_ms("agentic_move_timeout_ms")
    local result
    local child = registry.request(operation, arguments, {}, function(value) result = value end, { timeout_ms = ms + 1000 })
    local ready = vim.wait(ms, function() return result ~= nil end, 10)
    if not ready then
        child.cancel()
        return { kind = "unavailable", unconfirmed = true, error = ("move not confirmed: Couch did not answer within %d s;"
            .. " nothing moved. Run the move again"):format(math.ceil(ms / 1000)) }
    end
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

-- What parley already knows about a path's identity, without asking Couch
-- (#359): the loaded model's registration, then the namespace cache, then the
-- loaded model's positive absence or an earlier background answer. Anything
-- else is unknown.
-- A background lookup's "absent" answers the rerun only for a while: past
-- M.ANSWER_TTL_MS it is unknown again, so a registration made since (by an agent,
-- for a file parley never loaded) is asked about, not moved past. Both tables are
-- bounded: answers expire, and at most one request per path is out.
M.ANSWER_TTL_MS = 60000
local answered = {} -- [namespace .. "\0" .. path] = expiry (uv.now() ms)
local asking = {}   -- the same key while its background request is out
local function prune_answers()
    local now = uv.now()
    for slot, expiry in pairs(answered) do
        if expiry <= now then answered[slot] = nil end
    end
end
local function known_identity(ns, key)
    local loaded
    for _, s in pairs(states) do
        if s.path == key and valid(s) then loaded = s; break end
    end
    local registration = loaded and loaded.model.snapshot().registration
    if registration then return registration, loaded end
    local cached = cache({ namespace = ns, path = key })
    if cached then return cached, loaded end
    if loaded and loaded.model.snapshot().phase == "plain" then return "plain", loaded end
    local expiry = not loaded and answered[ns .. "\0" .. key]
    if expiry and expiry > uv.now() then return "plain" end
    return "unknown", loaded
end

-- A refused move starts the one request whose answer lets the rerun proceed.
local function ask_in_background(ns, key, loaded, operation, owner)
    if loaded and operation == "lookup" then M.recheck(loaded.buf); return end
    local slot = ns .. "\0" .. key
    if asking[slot] then return end
    asking[slot] = true
    local args = operation == "register" and { key, owner } or { key }
    registry.request(operation, args, {}, function(result)
        asking[slot] = nil
        if result.kind == "registered" then
            answered[slot] = nil
            cache({ namespace = ns, path = key }, result.registration)
            -- A loaded buffer adopts it, so its rename's rerun sees the identity.
            if loaded and states[loaded.buf] == loaded and valid(loaded) and not loaded.model.snapshot().operation then
                reseed(loaded, result.registration)
                adopt(loaded, result.registration)
            end
        elseif result.kind == "absent" then
            prune_answers()
            answered[slot] = uv.now() + M.ANSWER_TTL_MS
        end
    end, { timeout_ms = config_ms("agentic_submit_timeout_ms") })
end

-- Public Parley movers must reserve the identity before touching OLD. A plain
-- document keeps the existing mover. Nothing here waits on Couch (#359): an
-- unknown identity refuses at once, with nothing moved, and asks in the
-- background so the rerun has the answer.
function M.move_membership(path)
    local ns = namespace()
    if not ns then return false end
    local key = canonical(path)
    if path_busy(key) then return nil, "finish the pending document operation before moving" end
    if require("parley.chat_parser").is_chat_filename(vim.fs.basename(path)) then
        local lines = require("parley.helper").chat_lines(path)
        if lines and not require("parley").not_chat(nil, path, lines) then return false end
    end
    local identity, loaded = known_identity(ns, key)
    local legacy
    if type(identity) ~= "table" then
        local header = require("parley.session_sync").parse_header(vim.fn.readfile(path, "", 40))
        legacy = header and header.owner
    end
    local decision = require("parley.document_move_plan").move_preflight({ identity = identity, legacy = legacy })
    if decision.proceed then return true, identity end
    if decision.plain then return false end
    ask_in_background(ns, key, loaded, decision.register and "register" or "lookup", legacy)
    return nil, decision.message
end

function M.move_path(old_path, new_path)
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
    reseed(s, identity, snapshot.receipt)
    adopt(s, identity)
    local saved, save_error = ss.prepare_submit(buf)
    if not saved then return true, nil, save_error end
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
        -- Couch's rename is the authority on NEW (#359): no lookup first.
        root = state_root(), lease = lease, destination_registered = "authority", move_document = true,
        old_lock = token.lock, new_lock = token.lock, baseline = token.baseline,
        install_new = function() return ss.install_move_lock(buf, token, new_path) end,
        document_moved = function()
            return acknowledge_owned_move(s, new_path, moving.content)
        end,
        editor_snapshot = editor_snapshot(s, moving),
        parent_rewritten = parent_rewritten(s, moving),
        metadata = moving_metadata(s, moving),
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
    -- The document, its side folder and backlinks moved synchronously; only
    -- Couch's metadata rename is still out, and the journal carries it (#359).
    -- A failed name handoff also leaves the journal pending, after the file
    -- itself moved: that is no success either.
    if not require("parley.document_move").document_ready(operation) or moving.pending_error then
        return true, nil, moving.error or "document move pending; preserve its journal and reopen to recover"
    end
    return true, new_path
end

advance_move = function(s)
    local moving = s.move
    if not moving or not moving.operation or not moving.witness then return end
    moving.content = moving.content or hash(s.buf)
    require("parley.document_move").advance(moving.operation, function(result)
        if states[s.buf] ~= s then return end
        if result.orphan_destination and not moving.orphan_notified then
            moving.orphan_notified = true
            notify("Retained side documents at " .. result.orphan_destination)
        end
        if result.kind == "registered" then
            moving.answered = true
            if moving.new_path then show_move(s, moving, result) end
            s.move = nil
        else
            moving.pending_error = result.error or "document move pending"
            notify(result.error or "Migration is pending; preserve the journal for recovery")
            if moving.operation.journal.version == 2 then show_move(s, moving, result) end
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
    local moving = { new_path = journal.new, content = content, version = journal.version }
    local operation, err = mover.recover(s.namespace, journal.id, {
        root = state_root(), old_path = journal.old, new_path = journal.new,
        new_written = fresh_write == true,
        reconcile = function()
            if token then return true end
            local restore_error
            token, restore_error = ss.restore_move(s.buf, journal.registration, journal.new, journal.protection)
            moving.token = token
            return token ~= nil, restore_error
        end,
        document_moved = function()
            -- Recovery may read an already published mechanical parent rewrite.
            -- Accept only that projection or the captured editor preimage; a
            -- read autocmd's other edit must remain unsaved before any reread.
            local projected
            if journal.version == 2 then
                local projection_error
                projected, projection_error = projected_editor_hash(s.buf, journal.old, journal.new)
                if not projected then return false, projection_error end
            end
            local ok, name_error = read_moved_document(s, journal.new, moving.content, moving.content, projected)
            if ok then s.path = journal.new; moving.content = hash(s.buf) end
            return ok, name_error
        end,
        editor_snapshot = editor_snapshot(s, moving),
        parent_rewritten = parent_rewritten(s, moving),
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
            if result.orphan_destination then notify("Retained side documents at " .. result.orphan_destination) end
            s.move, s.recovery_pending = nil, nil
        else
            if s.move and s.move.operation then s.move.operation.release(); s.move = nil end
            if journal.version == 2 then show_move(s, moving, result)
            else band(s, "Pending document move: " .. tostring(result.error)) end
        end
    end)
    if not operation then
        s.recovering = false
        if journal.version == 2 then show_move(s, moving, { kind = "pending", error = err.message })
        else band(s, "Pending document move: " .. err.message) end
    elseif s.recovery_pending then
        moving.operation, moving.token = operation, token
        s.move = moving
    end
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
            -- #359: no wait. What parley knows decides, and a refusal leaves
            -- the name unchanged while the answer is fetched in the background.
            local known = known_identity(s.namespace, s.path)
            local legacy = ss.identity(s.buf)
            if legacy and not legacy.Owner then refuse("legacy document owner unavailable") end
            local decision = require("parley.document_move_plan").move_preflight({
                identity = known, legacy = legacy and legacy.Owner })
            if decision.plain then return end -- positively plain; never registers.
            if decision.refuse then
                ask_in_background(s.namespace, s.path, s, decision.register and "register" or "lookup",
                    legacy and legacy.Owner)
                refuse(decision.message)
            end
            if s.request then s.request.cancel(); s.request = nil end
            -- New model witnesses must never alias a cancelled open probe.
            reseed(s, known)
            adopt(s, known)
            identity = known
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
        -- Only an overwrite of an existing file asks Couch first (rows 8, 9):
        -- Neovim writes it before Couch's rename could refuse. Otherwise the
        -- rename is the authority on NEW (#359).
        local overwrite = vim.fn.filereadable(moving.new_path) == 1
        local decision = require("parley.document_move_plan").move_preflight({ identity = moving.identity,
            new_exists = overwrite, overwrite = overwrite })
        if decision.wait_destination then
            local target = bounded_request("lookup", { moving.new_path })
            if target.unconfirmed then
                -- Neovim already renamed the buffer here, so "run it again" alone
                -- would not do: renaming back aborts this move (cancel_attempt).
                moving.error = ("rename not confirmed: Couch did not answer within %d s;"
                    .. " rename back to %s, then run it again"):format(math.ceil(config_ms("agentic_move_timeout_ms") / 1000), moving.old_path)
                refuse(moving.error)
            end
            if target.kind ~= "absent" then moving.error = "destination membership is occupied or unknown"; refuse(moving.error) end
        end
        local operation, err = require("parley.document_move").begin(s.namespace, moving.identity, moving.new_path, {
            root = state_root(), lease = moving.lease, destination_registered = overwrite and false or "authority",
            parent_bytes = table.concat(vim.api.nvim_buf_get_lines(s.buf, 0, -1, false), "\n"),
            old_lock = moving.token.lock, new_lock = moving.token.lock, baseline = moving.token.baseline,
            install_new = function() return ss.install_move_lock(s.buf, moving.token, moving.new_path) end,
            editor_snapshot = editor_snapshot(s, moving),
            parent_rewritten = parent_rewritten(s, moving),
            metadata = moving_metadata(s, moving),
        })
        if not operation then
            moving.error, moving.journal_pending = err.message, err.kind == "pending"
            if not moving.journal_pending then
                -- A refused admission has changed no file bytes or destination
                -- protection. Abort that local name change with the same token.
                s.owned_renaming = true
                local named, name_error = pcall(vim.api.nvim_buf_set_name, s.buf, moving.old_path)
                s.owned_renaming = nil
                if named then
                    local aborted, abort_error = ss.abort_move(s.buf, moving.token)
                    if aborted then
                        moving.lease.release(); s.move = nil; ss.release_if_baseline(s.buf)
                    else moving.error = moving.error .. "; " .. tostring(abort_error) end
                else moving.error = moving.error .. "; " .. tostring(name_error) end
            end
            refuse(moving.error)
        end
        moving.operation = operation
        dispatch(s, { type = "rename", new_path = moving.new_path })
    end })
    vim.api.nvim_create_autocmd("BufWritePre", { group = s.group, buffer = s.buf, callback = function()
        if s.move and (s.move.error or not s.move.operation) then refuse(s.move.error or "migration preflight incomplete") end
    end })
    vim.api.nvim_create_autocmd("BufWritePost", { group = s.group, buffer = s.buf, callback = function()
        -- A move whose metadata rename is still out keeps running; saving the
        -- document meanwhile must not start it again (#359).
        if s.recovery_pending then recover_migration(s, true)
        elseif s.move and s.move.operation and s.move.operation.running then
            local recorded, record_error = require("parley.document_move").record_write(s.move.operation)
            if not recorded then
                -- The file is saved; only the move's recovery proof is stale.
                notify("saved, but the pending move could not record this write; a reopen may not recover it: "
                    .. tostring(record_error))
            end
        elseif s.move then advance_move(s) end
    end })
end

function M.detach(buf)
    local s = states[buf]
    if not s then return end
    end_submit(s)
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
