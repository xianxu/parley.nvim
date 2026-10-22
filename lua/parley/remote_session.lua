-- Private endpoint IO dispatcher. The pure attachment owns authority history;
-- this shell owns buffer witnesses, listeners and bounded CLI effects only.
local M = {}
local uv = vim.uv or vim.loop
local model = require('parley.remote_session_model')
local registry = require('parley.document_registry')
local runtime_source = require('parley.remote_runtime')
local incarnation = (uv.random(16):gsub('.', function(byte) return ('%02x'):format(byte:byte()) end))
local counter, runtime, epoch, closing
local attachment_count = 0
local by_buffer, by_attach, attachments, slots, waiting, io_queue, close_waiters = {}, {}, {}, {}, {}, {}, {}
local io_busy = false
local dispatch, maybe_close, get_runtime
local lifetimes, reopens = {}, {}
local lifecycle_group
local exit_state
M.EXIT_BUDGET_MS = 500

local function native_exiting() return type(vim.v.exiting) == 'number' end
local function is_closing() return closing or native_exiting() end

-- A retained effect belongs to the producer selected at admission, even after
-- the buffer is gone or the caller changes its options/environment. Keep the
-- runtime's stateful source object intact; only the CLI selection is copied.
local function owned_options(options)
    local client = vim.tbl_extend('force', {}, options.client or {})
    local binary = client.binary or 'couch'
    local resolved = vim.fn.exepath(binary)
    client.binary = resolved ~= '' and resolved or vim.fn.fnamemodify(binary, ':p')
    client.env = vim.tbl_extend('force', {}, vim.fn.environ(), client.env or {})
    client.clear_env = true
    return { runtime = options.runtime, client = client }
end

local function named_file(buf)
    if not vim.api.nvim_buf_is_valid(buf) then return nil end
    local name = vim.api.nvim_buf_get_name(buf)
    if name == '' then return nil end
    local path = vim.fn.fnamemodify(name, ':p')
    return uv.fs_realpath(path) or ((uv.fs_realpath(vim.fs.dirname(path)) or vim.fs.dirname(path)) .. '/' .. vim.fs.basename(path))
end

local function forget_lifetime(buf)
    local life = lifetimes[buf]
    lifetimes[buf], reopens[buf] = nil, nil
    if life and life.request then life.request.cancel(); life.request = nil end
end

local function watch_buffer(buf)
    if not lifecycle_group then
        lifecycle_group = vim.api.nvim_create_augroup('ParleyRemoteSession', { clear = true })
        vim.api.nvim_create_autocmd('BufUnload', { group = lifecycle_group, callback = function(event)
            if not lifetimes[event.buf] then return end
            if require('parley.session_sync').is_buffer_read(event.buf) then return end
            M.detach(event.buf)
            reopens[event.buf] = true
        end })
        vim.api.nvim_create_autocmd('BufWipeout', { group = lifecycle_group, callback = function(event)
            M.detach(event.buf)
        end })
        vim.api.nvim_create_autocmd('BufReadPost', { group = lifecycle_group, callback = function(event)
            if lifetimes[event.buf] or reopens[event.buf] then
                reopens[event.buf] = nil
                M.observe(event.buf)
            end
        end })
        vim.api.nvim_create_autocmd('BufFilePost', { group = lifecycle_group, callback = function(event)
            local life = lifetimes[event.buf]
            -- Couch-pane moves have their own admitted pause/finalize boundary.
            if life and not life.suspended and not require('parley.couch').thread()
                and life.path ~= named_file(event.buf) then
                M.detach(event.buf)
                M.observe(event.buf)
            end
        end })
    end
    local life = lifetimes[buf]
    if not life then
        life = { path = named_file(buf) }
        lifetimes[buf] = life
    end
    return life
end

local function notify(record, message)
    if record.notified then return end
    record.notified = true
    vim.notify(message, vim.log.levels.WARN)
end
local function report(record, result)
    if record.callback then
        local callback = record.callback; record.callback = nil
        callback(result)
    end
end
local function current_file(buf)
    if not vim.api.nvim_buf_is_valid(buf) then return nil end
    local path = vim.api.nvim_buf_get_name(buf)
    return path ~= '' and uv.fs_realpath(path) or nil
end
local function retired(record)
    return record.retired or is_closing() or by_buffer[record.buf] ~= record
end
-- A buffer's pure authority history can outlive its runtime consumer. Retired
-- IO remains associated with that exact epoch until all cleanup has completed.
local function release_consumer(record)
    local owned = record.epoch
    if not owned or record.released then return end
    record.released = true
    -- Acquisition is shared, but reservation/listen/publication belongs to
    -- this consumer. Retain and join that exact transaction even when another
    -- buffer still needs the epoch or its completion is already queued.
    if record.listen_operation then record.listen_operation.cancel() end
    owned.live = owned.live - 1
    if owned.live == 0 then
        owned.draining = true
        if owned.operation then owned.operation.cancel() end
    end
end
local function prune(record)
    if record.epoch and record.released and not record.allocating and record.pending == 0 and not record.stopping then
        record.epoch.retained = record.epoch.retained - 1
        record.epoch = nil
    end
    if attachments[record] and record.retired and not record.allocating and record.pending == 0 and not record.stopping then
        attachments[record] = nil
        by_attach[record.attach] = nil
        attachment_count = attachment_count - 1
    end
    maybe_close()
end

-- All mutations of one resource's ownership marker are ordered here. The
-- kernel lease still serializes this editor with other processes/startup sweep.
local function pump_io()
    if io_busy or #io_queue == 0 then maybe_close(); return end
    io_busy = true
    local job = table.remove(io_queue, 1)
    job(function()
        io_busy = false
        pump_io()
    end)
end
local function io(job)
    io_queue[#io_queue + 1] = job
    pump_io()
end
get_runtime = function(record, options, callback)
    if epoch and epoch.draining then
        waiting[record] = { options = options, callback = callback }
        -- A later explicit attach may retry exact cleanup once. There is no
        -- automatic loop after a busy or uncertain close.
        epoch.blocked = nil
        maybe_close()
        return
    end
    if not epoch then epoch = { live = 0, retained = 0, waiters = {} } end
    local owned = epoch
    record.epoch, record.released = owned, false
    owned.live, owned.retained = owned.live + 1, owned.retained + 1
    if owned.resource then callback({ kind = 'ready', runtime = owned.resource }); return end
    owned.waiters[record] = callback
    if owned.operation then return end
    options = vim.tbl_extend('force', {}, options or {}, { incarnation = incarnation })
    owned.operation = runtime_source.acquire(options, function(result)
        owned.operation = nil
        if result.kind == 'ready' then owned.resource, runtime = result.runtime, result.runtime end
        local callbacks = owned.waiters; owned.waiters = {}
        for _, ready in pairs(callbacks) do ready(result) end
        maybe_close()
    end)
end

local function stop_listener(record)
    -- Exit owns kernel retirement after its one observation window. It must
    -- not enqueue marker IO whose lease may be held by another process.
    if exit_state then return end
    if record.stopping or not record.slot then return end
    record.stopping = true
    local resource = record.epoch.resource
    io(function(done)
        resource.stop('s' .. record.slot, function(result)
            if result.kind == 'closed' then slots[record.slot] = nil end
            record.stopping = false
            done(result)
            prune(record)
        end)
    end)
end
local function effects(record, list)
    for _, effect in ipairs(list) do
        if effect.kind == 'stop_listener' then
            stop_listener(record)
        elseif effect.kind == 'notify' then
            notify(record, 'Remote view moved to another editor; reopen the file to take it back')
        elseif effect.kind == 'register' or effect.kind == 'unregister' then
            if exit_state then
                -- An admitted register can acknowledge after the frozen exit
                -- batch. Its exact cleanup is still unknown; never reactivate
                -- or extend shutdown with another request.
                exit_state.uncertain = true
            else
                record.pending = record.pending + 1
                local request = { kind = effect.kind }
                record.requests[request] = true
                request.handle = registry.editor(effect.kind, effect.request, { attachment = record.attach, request = effect.witness }, function(result)
                    record.requests[request] = nil
                    record.pending = record.pending - 1
                    if effect.kind == 'register' then
                        dispatch(record, { type = 'reply', witness = effect.witness, result = result })
                        local accepted = record.owner:snapshot().result
                        if not retired(record) and accepted.kind ~= 'confirmed' then
                            notify(record, 'Remote view unavailable; reopen the file to retry')
                        end
                        report(record, accepted)
                    end
                    prune(record)
                end, record.options.client)
            end
        end
    end
end
dispatch = function(record, event)
    if not record.owner then return end
    effects(record, record.owner:dispatch(event))
    local phase = record.owner:snapshot().phase
    if phase == 'superseded' or phase == 'unavailable' or phase == 'retired' then release_consumer(record) end
end
local function resume_waiters(result)
    local callbacks = waiting; waiting = {}
    for record, waiter in pairs(callbacks) do
        if retired(record) then waiter.callback({ kind = 'unavailable', error = 'attachment retired' })
        elseif result then waiter.callback(result)
        else get_runtime(record, waiter.options, waiter.callback) end
    end
end
maybe_close = function()
    if exit_state then return end
    local owned = epoch
    if owned and owned.draining and not owned.operation and owned.retained == 0
        and not io_busy and #io_queue == 0 and not owned.closing and not owned.blocked then
        owned.closing = true
        local function finished(result)
            owned.closing = false
            if result.kind == 'closed' then
                epoch, runtime, slots = nil, nil, {}
                resume_waiters()
            else
                owned.blocked = true
                resume_waiters({ kind = 'unavailable', error = result.error or 'runtime cleanup unconfirmed' })
            end
            maybe_close()
        end
        if owned.resource then owned.resource.close(finished)
        else finished({ kind = 'closed' }) end
        return
    end
    if closing and attachment_count == 0 and not io_busy and #io_queue == 0
        and (not epoch or epoch.blocked) then
        local callbacks = close_waiters; close_waiters = {}
        for _, callback in ipairs(callbacks) do callback() end
    end
end

--- Explicit confirmed-identity attachment; repeated lifecycle events reuse it.
--- A fresh attachment requires detach first. Options select the named runtime
--- process source and CLI transport; ordinary callers use their defaults.
function M.attach(buf, identity, callback, options)
    callback = callback or function() end
    options = options or {}
    if is_closing() then callback({ kind = 'unavailable', error = 'editor is closing' }); return end
    local existing = by_buffer[buf]
    if existing then
        local state = existing.owner and existing.owner:snapshot()
        callback(state and state.result or { kind = 'unavailable', error = 'remote attachment pending' })
        return
    end
    local next_id, err = model.next_attach_id(counter)
    if not next_id then callback({ kind = 'unavailable', error = err }); return end
    local context = type(identity) == 'table' and {
        Namespace = identity.Namespace, DocumentID = identity.ID, File = identity.File,
        EditorIncarnation = incarnation, AttachID = next_id, PID = uv.os_getpid(), Buffer = buf, Mode = 'desktop',
    }
    local valid, reason = model.validate_context(context, 'pending')
    if not valid or attachment_count >= 256 or current_file(buf) ~= context.File then
        callback({ kind = 'unavailable', error = reason or 'confirmed document identity unavailable or endpoint capacity reached' })
        return
    end
    local life = watch_buffer(buf)
    if life.suspended then callback({ kind = 'unavailable', error = 'document is moving' }); return end
    life.known = true
    counter = next_id
    local record = { buf = buf, attach = counter, pending = 0, allocating = true,
        options = owned_options(options), callback = callback, identity = vim.deepcopy(identity), context = context, requests = {} }
    attachments[record], by_buffer[buf], by_attach[record.attach] = true, record, record
    attachment_count = attachment_count + 1
    get_runtime(record, options.runtime, function(result)
        if result.kind ~= 'ready' or retired(record) then
            record.allocating = false
            release_consumer(record)
            report(record, { kind = 'unavailable', error = result.error or 'attachment retired' })
            if not retired(record) then notify(record, 'Remote view unavailable; reopen the file to retry') end
            prune(record); return
        end
        local slot
        for index = 1, 256 do if not slots[index] then slot = index; break end end
        if not slot then
            record.allocating = false
            release_consumer(record)
            report(record, { kind = 'unavailable', error = 'private listener capacity reached' })
            prune(record); return
        end
        slots[slot], record.slot = true, slot
        io(function(done)
            if retired(record) then
                slots[slot], record.allocating = nil, false
                report(record, { kind = 'unavailable', error = 'attachment retired' })
                done(); prune(record); return
            end
            record.listen_operation = runtime.listen('s' .. slot, function(listening)
                record.listen_operation = nil
                record.allocating = false
                local completion
                if listening.kind == 'listening' then
                    local allocated = vim.tbl_extend('force', {}, record.context, { Socket = listening.path })
                    local allocated_valid, allocated_reason = model.validate_context(allocated)
                    if allocated_valid then
                        local ok, owner, construction_error = pcall(model.new, allocated)
                        if ok and owner then record.owner = owner
                        else allocated_reason = ok and construction_error or owner end
                    end
                    if not record.owner then
                        listening = { kind = 'unavailable', error = tostring(allocated_reason or 'attachment construction rejected') }
                    end
                end
                if record.owner then
                    if retired(record) then
                        dispatch(record, { type = 'detach' })
                        completion = { kind = 'unavailable', error = 'attachment retired' }
                    else dispatch(record, { type = 'publish' }) end
                else
                    -- Join exact reservation cleanup even when another buffer
                    -- keeps this runtime alive. A refused cleanup retains the
                    -- slot; only proven cleanup permits reuse.
                    stop_listener(record)
                    release_consumer(record)
                    completion = listening
                end
                done(listening); prune(record)
                if completion then
                    report(record, completion)
                    if not retired(record) then notify(record, 'Remote view unavailable; reopen the file to retry') end
                end
            end)
        end)
    end)
end

--- Observe a loaded Markdown incarnation. In a Couch pane S1 supplies identity;
--- elsewhere discovery is one read-only lookup and never adopts a submit turn.
function M.observe(buf)
    if is_closing() or not vim.api.nvim_buf_is_valid(buf) or not vim.api.nvim_buf_is_loaded(buf) then return end
    local file = named_file(buf)
    if not file or vim.bo[buf].buftype ~= '' or not require('parley').is_markdown(buf, file) then return end
    local life = watch_buffer(buf)
    if life.suspended or life.known or life.discovered or require('parley.couch').thread() then return end
    life.discovered = true
    local token = {}
    life.lookup_token = token
    life.request = registry.request('lookup', { file }, {}, function(result)
        if lifetimes[buf] ~= life or life.lookup_token ~= token or life.suspended
            or named_file(buf) ~= file or not vim.api.nvim_buf_is_loaded(buf) then return end
        life.request = nil
        if result.kind == 'registered' then M.attach(buf, result.registration) end
    end)
end

--- Fixed, read-only producer handshake. A stale spelling never advertises.
function M.endpoint(query)
    if type(query) ~= 'table' then return nil end
    local record = by_buffer[query.Buffer]
    if not record or not record.owner or retired(record) or current_file(record.buf) ~= record.identity.File then return nil end
    return record.owner:endpoint(query)
end

--- Advisory only: Couch remains authority and future adapters fence every use.
function M.superseded(notice)
    if type(notice) ~= 'table' then return end
    local record = by_attach[notice.AttachID]
    if record and record.identity.ID == notice.DocumentID and record.identity.Namespace == notice.Namespace then
        dispatch(record, { type = 'superseded', notice = notice })
    end
end

function M.snapshot(buf)
    local record = by_buffer[buf]
    return record and record.owner and record.owner:snapshot() or nil
end
local function retire_attachment(buf)
    local record = by_buffer[buf]
    if not record then return end
    by_buffer[buf], record.retired = nil, true
    release_consumer(record)
    for request in pairs(record.requests) do
        if request.kind == 'register' then request.handle.cancel_unstarted() end
    end
    if waiting[record] then
        waiting[record] = nil
        record.allocating = false
        report(record, { kind = 'unavailable', error = 'attachment retired' })
    end
    dispatch(record, { type = 'detach' })
    if not record.owner and not record.allocating then report(record, { kind = 'unavailable', error = 'attachment retired' }) end
    prune(record)
end

function M.detach(buf)
    -- Native quit unloads buffers before VimLeavePre. v:exiting is then a
    -- numeric exit code (including zero), so reserve every known generation
    -- for exit's shared batch instead of starting per-buffer unregisters.
    if native_exiting() then return end
    forget_lifetime(buf)
    retire_attachment(buf)
end

--- The document mover owns the pause and supplies confirmed identity on resume.
function M.pause(buf)
    local life = watch_buffer(buf)
    life.suspended, life.lookup_token = true, nil
    if life.request then life.request.cancel(); life.request = nil end
    retire_attachment(buf)
end

function M.resume(buf, identity)
    local life = watch_buffer(buf)
    life.suspended, life.path = false, named_file(buf)
    M.attach(buf, identity)
end

--- Async explicit teardown (exit's one 500 ms batch is wired separately).
function M.close(callback)
    close_waiters[#close_waiters + 1] = callback or function() end
    closing = true
    local buffers = {}
    for buf in pairs(lifetimes) do buffers[#buffers + 1] = buf end
    for buf in pairs(by_buffer) do if not lifetimes[buf] then buffers[#buffers + 1] = buf end end
    for _, buf in ipairs(buffers) do M.detach(buf) end
    maybe_close()
end

--- VimLeavePre observes known generations for one shared bounded interval.
--- It neither waits for filesystem cleanup nor claims a lost reply is clean.
function M.exit()
    if exit_state then return vim.deepcopy(exit_state.result) end
    local deadline = uv.hrtime() / 1e6 + M.EXIT_BUDGET_MS
    exit_state = { uncertain = false, result = { kind = 'uncertain' } }
    closing = true
    local records, bindings, clients = {}, {}, {}
    for record in pairs(attachments) do
        records[#records + 1] = record
        if record.allocating then exit_state.uncertain = true end
        local state = record.owner and record.owner:snapshot()
        if state and state.binding then
            bindings[#bindings + 1] = state.binding
            clients[state.binding.Namespace] = clients[state.binding.Namespace] or record.options.client
        end
        if state and state.phase == 'unconfirmed' then exit_state.uncertain = true end
        for request in pairs(record.requests) do
            if request.kind == 'register' and not request.handle.cancel_unstarted() then exit_state.uncertain = true end
        end
    end
    local buffers = {}
    for buf in pairs(lifetimes) do buffers[#buffers + 1] = buf end
    for _, buf in ipairs(buffers) do forget_lifetime(buf) end
    for _, record in ipairs(records) do
        by_buffer[record.buf], record.retired = nil, true
        release_consumer(record)
        if waiting[record] then
            waiting[record], record.allocating = nil, false
            report(record, { kind = 'unavailable', error = 'editor is closing' })
        end
        -- Consume the model transition, but the frozen batch above owns its
        -- unregister effects. Late replies go through the same retired owner.
        if record.owner then record.owner:dispatch({ type = 'close' }) end
    end
    local batches = model.exit_batches(bindings, { EditorIncarnation = incarnation, PID = uv.os_getpid() })
    local pending, requests = 0, {}
    if not batches then exit_state.uncertain = true else
        for _, batch in ipairs(batches) do
            pending = pending + 1
            local options = vim.tbl_extend('force', {}, clients[batch.Namespace] or {}, { absolute_deadline_ms = deadline })
            local handle = registry.editor('unregister', batch, {}, function(result)
                pending = pending - 1
                if result.kind ~= 'confirmed' then exit_state.uncertain = true end
            end, options)
            requests[#requests + 1] = handle
        end
    end
    local remaining = math.max(0, math.floor(deadline - uv.hrtime() / 1e6))
    if pending > 0 and remaining > 0 then vim.wait(remaining, function() return pending == 0 end, 1) end
    if pending > 0 then
        exit_state.uncertain = true
        for _, handle in ipairs(requests) do handle.cancel() end
    end
    -- Existing observers must also end through their owned/joined transport:
    -- their Lua deadline cannot run once Neovim has left. Cancellation never
    -- supplies a missing generation or proves producer work was rolled back.
    for _, record in ipairs(records) do
        for request in pairs(record.requests) do request.handle.cancel() end
    end
    if epoch and epoch.resource then
        local stopped = epoch.resource.stop_listeners()
        if not stopped then exit_state.uncertain = true end
    end
    exit_state.result = { kind = exit_state.uncertain and 'uncertain' or 'closed' }
    return vim.deepcopy(exit_state.result)
end

return M
