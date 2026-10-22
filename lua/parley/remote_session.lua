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
    return record.retired or closing or by_buffer[record.buf] ~= record
end
-- A buffer's pure authority history can outlive its runtime consumer. Retired
-- IO remains associated with that exact epoch until all cleanup has completed.
local function release_consumer(record)
    local owned = record.epoch
    if not owned or record.released then return end
    record.released = true
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
            record.pending = record.pending + 1
            local request = { kind = effect.kind }
            record.requests[request] = true
            request.handle = registry.editor(effect.kind, effect.request, { attachment = record.attach, request = effect.witness }, function(result)
                record.requests[request] = nil
                record.pending = record.pending - 1
                if effect.kind == 'register' then
                    dispatch(record, { type = 'reply', witness = effect.witness, result = result })
                    if not retired(record) and result.kind ~= 'confirmed' then
                        notify(record, 'Remote view unavailable; reopen the file to retry')
                    end
                    report(record, result)
                end
                prune(record)
            end, record.options.client)
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
    if closing then callback({ kind = 'unavailable', error = 'editor is closing' }); return end
    local existing = by_buffer[buf]
    if existing then
        local state = existing.owner and existing.owner:snapshot()
        callback(state and state.result or { kind = 'unavailable', error = 'remote attachment pending' })
        return
    end
    local prepared = type(identity) == 'table' and model.prepare_request('lookup', {
        Namespace = identity.Namespace, DocumentID = identity.ID,
    })
    if not prepared or attachment_count >= 256 or current_file(buf) ~= identity.File then
        callback({ kind = 'unavailable', error = 'confirmed document identity unavailable or endpoint capacity reached' })
        return
    end
    local next_id, err = model.next_attach_id(counter)
    if not next_id then callback({ kind = 'unavailable', error = err }); return end
    counter = next_id
    local record = { buf = buf, attach = counter, pending = 0, allocating = true,
        options = options, callback = callback, identity = vim.deepcopy(identity), requests = {} }
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
            runtime.listen('s' .. slot, function(listening)
                record.allocating = false
                if listening.kind == 'listening' then
                    record.owner = model.new({ Namespace = record.identity.Namespace, DocumentID = record.identity.ID,
                        EditorIncarnation = incarnation, AttachID = record.attach, PID = uv.os_getpid(),
                        Socket = listening.path, Buffer = buf, Mode = 'desktop', File = record.identity.File })
                    if retired(record) then
                        dispatch(record, { type = 'detach' })
                        report(record, { kind = 'unavailable', error = 'attachment retired' })
                    else dispatch(record, { type = 'publish' }) end
                else
                    -- A partial listen may have durable marker residue. Keep
                    -- its slot reserved until explicit runtime teardown.
                    release_consumer(record)
                    report(record, listening)
                    if not retired(record) then notify(record, 'Remote view unavailable; reopen the file to retry') end
                end
                done(listening); prune(record)
            end)
        end)
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
function M.detach(buf)
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

--- Async explicit teardown (exit's one 500 ms batch is wired separately).
function M.close(callback)
    close_waiters[#close_waiters + 1] = callback or function() end
    closing = true
    local buffers = {}
    for buf in pairs(by_buffer) do buffers[#buffers + 1] = buf end
    for _, buf in ipairs(buffers) do M.detach(buf) end
    maybe_close()
end

return M
