local arrival = require("tests.helpers.arrival")
local uv = vim.uv or vim.loop

describe('durable leased document migration', function()
    local root, old, new, side, operations, children
    local function read(path)
        local f = assert(io.open(path, 'rb')); local bytes = f:read('*a'); f:close(); return bytes
    end
    local function write(path, bytes)
        vim.fn.mkdir(vim.fn.fnamemodify(path, ':h'), 'p')
        local f = assert(io.open(path, 'wb')); assert(f:write(bytes)); assert(f:close())
    end
    local function tree(base)
        local result = {}
        local function walk(directory)
            local scan = assert(uv.fs_scandir(directory))
            while true do
                local name = uv.fs_scandir_next(scan); if not name then break end
                local path = directory .. '/' .. name; local info = assert(uv.fs_lstat(path))
                local item = { type = info.type, inode = info.ino }
                if info.type == 'file' then item.bytes = read(path) end
                result[path:sub(#base + 2)] = item
                if info.type == 'directory' then walk(path) end
            end
        end
        walk(base); return result
    end
    local function registration(path) return { ID = 'stable-id', File = path, Owner = 'owner', RegisteredOwner = 'owner', RegisteredAt = 'now' } end
    local function move() return require('parley.document_move') end
    local function begin(options, target)
        options = vim.tbl_extend('force', { root = root .. '/state', destination_registered = false,
            metadata = function(op, cb) cb({ kind = 'registered', registration = registration(op.new), changed = false }) end,
        }, options or {})
        local operation, err = move().begin('ns', registration(old), target or new, options)
        if operation then operations[#operations + 1] = operation end
        return operation, err
    end
    local function advance(operation)
        local result
        move().advance(operation, function(value) result = value end)
        assert.is_true(vim.wait(arrival.MS, function() return result ~= nil end))
        return result
    end
    local function recover(options)
        local result
        local operation, err = move().recover('ns', 'stable-id', vim.tbl_extend('force', {
            root = root .. '/state', destination_registered = false,
            metadata = function(op, cb) cb({ kind = 'registered', registration = registration(op.new), changed = false }) end,
        }, options or {}), function(value) result = value end)
        if operation then operations[#operations + 1] = operation end
        if err then return nil, err end
        assert.is_true(vim.wait(arrival.MS, function() return result ~= nil end))
        return result, operation
    end
    before_each(function()
        root = vim.fn.tempname(); vim.fn.mkdir(root, 'p'); root = uv.fs_realpath(root)
        old, new = root .. '/old.md', root .. '/new.md'
        side = root .. '/old.side'
        operations, children = {}, {}
        write(old, 'parent\n')
        write(side .. '/child.md', '---\nparent: ../old.md\n---\n[parent](../old.md#anchor)\nunchanged\n')
        write(side .. '/binary.bin', 'binary\0payload')
    end)
    after_each(function()
        for _, operation in ipairs(operations) do operation.release() end
        for _, child in ipairs(children) do pcall(vim.fn.jobstop, child); vim.fn.jobwait({ child }, 1000) end
        vim.fn.delete(root, 'rf')
    end)

    for _, extension in ipairs({ '.markdown', '.MD', '.mdown', '' }) do
        it('migrates and recovers registered parent plus Markdown children for ' .. (extension ~= '' and extension or 'extensionless'), function()
            old, new = root .. '/old' .. extension, root .. '/new' .. extension
            -- macOS may resolve old.MD to the existing old.md fixture. Create
            -- the registered spelling fresh so this tests canonical paths.
            if extension ~= '.md' then assert(uv.fs_unlink(root .. '/old.md')) end
            write(old, 'parent\n')
            local before = '---\nparent: ../old' .. extension .. '\n---\n[up](../old' .. extension .. '#anchor)\n'
            write(side .. '/child.md', before)
            for _, child_extension in ipairs({ '.markdown', '.MD', '.mdown' }) do write(side .. '/extra' .. child_extension, before) end
            local operation, begin_err = begin({ metadata = function(_, cb) cb({ kind = 'unavailable', error = 'retry' }) end })
            assert(operation, begin_err and begin_err.error)
            write(new, 'parent\n')
            assert.equals('pending', advance(operation).kind)
            operation.release()
            local result, recover_err = recover()
            assert(result, recover_err and recover_err.error)
            assert.equals('registered', result.kind)
            local after = '---\nparent: ../new' .. extension .. '\n---\n[up](../new' .. extension .. '#anchor)\n'
            for _, child_name in ipairs({ 'child.md', 'extra.markdown', 'extra.MD', 'extra.mdown' }) do
                assert.equals(after, read(root .. '/new.side/' .. child_name))
            end
            assert.equals('parent\n', read(old))
            assert.is_nil(uv.fs_stat(operation.journal_path))
        end)
    end
    it('recovers an extension-only rename in place from mixed before/after backlink witnesses', function()
        new = root .. '/old.markdown'
        local directory_inode = assert(uv.fs_stat(side)).ino
        local before = '[up](../old.md#anchor)'
        write(side .. '/child.md', before); write(side .. '/z.MD', before)
        local fs = setmetatable({}, { __index = uv })
        local side_renames = 0
        fs.fs_rename = function(from, to)
            if from == side then side_renames = side_renames + 1 end
            if to == side .. '/z.MD' then return nil, 'interrupted second backlink' end
            return uv.fs_rename(from, to)
        end
        local operation, begin_err = begin({ fs = fs })
        assert(operation, begin_err and begin_err.error)
        write(new, 'parent\n')
        assert.equals('pending', advance(operation).kind)
        assert.equals('[up](../old.markdown#anchor)', read(side .. '/child.md'))
        assert.equals(before, read(side .. '/z.MD'))
        operation.release()
        local result = assert(recover())
        assert.equals('registered', result.kind); assert.equals('stable-id', result.registration.ID)
        assert.equals(0, side_renames)
        assert.equals(directory_inode, assert(uv.fs_stat(side)).ino)
        assert.equals('[up](../old.markdown#anchor)', read(side .. '/z.MD'))
        assert.equals('parent\n', read(old))
        assert.is_nil(uv.fs_stat(operation.journal_path))
    end)
    it('journals before effects and holds ownership through delayed metadata confirmation', function()
        local metadata, calls = nil, 0
        local operation = assert(begin({ metadata = function(op, cb)
            calls = calls + 1; assert.equals(old, op.old); assert.equals(new, op.new); metadata = cb
        end }))
        assert.is_truthy(uv.fs_stat(operation.journal_path)); assert.is_truthy(uv.fs_stat(side))
        assert.is_nil(uv.fs_stat(root .. '/new.side')); assert.is_nil(uv.fs_stat(new))
        write(new, 'parent\n')
        local result; move().advance(operation, function(value) result = value end)
        assert.is_true(vim.wait(arrival.MS, function() return metadata ~= nil end))
        assert.is_nil(result); assert.equals(1, calls)
        assert.equals('---\nparent: ../new.md\n---\n[parent](../new.md#anchor)\nunchanged\n', read(root .. '/new.side/child.md'))
        assert.equals('binary\0payload', read(root .. '/new.side/binary.bin'))
        assert.equals('parent\n', read(old))
        assert.equals('busy', select(2, begin()).kind)
        metadata({ kind = 'registered', registration = registration(new), changed = false })
        assert.is_true(vim.wait(arrival.MS, function() return result ~= nil end))
        assert.equals('registered', result.kind); assert.is_nil(uv.fs_stat(operation.journal_path))
    end)

    it('executes a journaled owned document rename before side effects and metadata', function()
        local named, metadata = 0, 0
        local operation = assert(begin({ move_document = true, baseline = { hash = 'owned-baseline' },
            document_moved = function(op)
                named = named + 1
                assert.is_nil(uv.fs_lstat(old)); assert.equals('parent\n', read(new))
                assert.is_truthy(uv.fs_lstat(side)); assert.equals('owned-baseline', op.baseline.hash)
                return true
            end,
            metadata = function(op, cb)
                metadata = metadata + 1; assert.equals(1, named)
                assert.is_nil(uv.fs_lstat(side)); assert.is_truthy(uv.fs_lstat(root .. '/new.side'))
                cb({ kind = 'registered', registration = registration(op.new), changed = true })
            end,
        }))
        local journal = vim.json.decode(read(operation.journal_path))
        assert.is_true(journal.document_move); assert.equals('prepared', journal.state.phase)
        local summaries = assert(move().pending('ns', { root = root .. '/state' }))
        assert.is_true(summaries[1].document_move)
        assert.equals('registered', advance(operation).kind)
        assert.equals(1, named); assert.equals(1, metadata)
        assert.is_nil(uv.fs_lstat(old)); assert.equals('parent\n', read(new))
        assert.matches('../new.md', read(root .. '/new.side/child.md'), 1, true)
        assert.is_nil(uv.fs_lstat(operation.journal_path))
    end)

    it('recovers an owned rename interrupted after filesystem publication before checkpoint', function()
        local fs = setmetatable({}, { __index = uv })
        fs.fs_rename = function(from, to)
            local ok, err = uv.fs_rename(from, to)
            if from == old and ok then return nil, 'interrupted after document rename' end
            return ok, err
        end
        fs.fs_rename_noreplace = fs.fs_rename
        local operation = assert(begin({ move_document = true, fs = fs }))
        assert.equals('pending', advance(operation).kind)
        assert.is_nil(uv.fs_lstat(old)); assert.equals('parent\n', read(new))
        local journal = vim.json.decode(read(operation.journal_path))
        assert.equals('document', journal.state.phase); assert.is_false(journal.new_witness)
        operation.release()
        local named = 0
        local result = assert(recover({ document_moved = function()
            named = named + 1; assert.is_nil(uv.fs_lstat(old)); return true
        end }))
        assert.equals('registered', result.kind); assert.equals(1, named)
        assert.matches('../new.md', read(root .. '/new.side/child.md'), 1, true)
    end)

    it('recovers an owned prepared intent while OLD still exists without a native write witness', function()
        local operation = assert(begin({ move_document = true })); operation.release()
        assert.is_truthy(uv.fs_lstat(old)); assert.is_nil(uv.fs_lstat(new))
        local result = assert(recover())
        assert.equals('registered', result.kind)
        assert.is_nil(uv.fs_lstat(old)); assert.equals('parent\n', read(new))
    end)

    -- #359: Couch's rename refuses an occupied destination, so a move may leave
    -- the check to it: the file moves at once and a conflict keeps the journal.
    it('journals a destination left to Couch, and keeps it pending on target-conflict', function()
        local operation = assert(begin({ move_document = true, destination_registered = 'authority',
            document_moved = function() return true end,
            metadata = function(_, cb) cb({ kind = 'unavailable', code = 'target-conflict', error = 'destination registered' }) end,
        }))
        local result = advance(operation)
        assert.equals('pending', result.kind)
        assert.equals('destination registered', result.error)
        assert.is_nil(uv.fs_lstat(old)); assert.equals('parent\n', read(new))
        assert.is_truthy(uv.fs_stat(operation.journal_path), 'the journal stays for recovery')
        local journal = vim.json.decode(read(operation.journal_path))
        assert.equals('metadata', journal.state.phase); assert.is_true(move().document_ready(operation))
    end)

    -- #359: the operator may save the moved document before Couch confirms. A
    -- recorded write keeps recovery provable; an unrecorded one does not.
    for _, recorded in ipairs({ true, false }) do
        it('recovers a move whose NEW was saved after the move ' .. (recorded and 'and recorded' or 'without a record'), function()
            local operation = assert(begin({ move_document = true, destination_registered = 'authority',
                document_moved = function() return true end,
                metadata = function() end, -- the rename never answers: the reply was lost
            }))
            move().advance(operation, function() end)
            assert.is_true(move().document_ready(operation))
            write(new, 'parent\nsaved by the operator\n')
            if recorded then assert.is_true(move().record_write(operation)) end
            operation.release()
            local result, recover_err = recover({ old_path = old, new_path = new, move_document = true,
                document_moved = function() return true end })
            assert.is_not_nil(result, vim.inspect(recover_err))
            if recorded then
                assert.equals('registered', result.kind, tostring(result.error))
                assert.equals('parent\nsaved by the operator\n', read(new))
            else
                assert.equals('pending', result.kind)
                assert.matches('NEW changed since its last recorded write', result.error, 1, true)
            end
        end)
    end

    it('refuses an occupied owned destination before creating a journal', function()
        write(new, 'foreign destination\n')
        local operation, err = begin({ move_document = true })
        if operation then operation.release() end
        assert.is_nil(operation); assert.equals('unavailable', err.kind)
        assert.equals('parent\n', read(old)); assert.equals('foreign destination\n', read(new))
        local summaries = assert(move().pending('ns', { root = root .. '/state' }))
        assert.equals(0, #summaries)
    end)

    it('refuses a foreign OLD edit before an owned document rename', function()
        local operation = assert(begin({ move_document = true }))
        write(old, 'foreign OLD\n')
        assert.equals('pending', advance(operation).kind)
        assert.equals('foreign OLD\n', read(old)); assert.is_nil(uv.fs_lstat(new))
        assert.is_truthy(uv.fs_lstat(side)); assert.is_truthy(uv.fs_lstat(operation.journal_path))
    end)

    it('refuses a same-content replacement of the captured OLD inode', function()
        local operation = assert(begin({ move_document = true }))
        assert(uv.fs_rename(old, root .. '/saved-old.md')); write(old, 'parent\n')
        assert.equals('pending', advance(operation).kind)
        assert.equals('parent\n', read(old)); assert.is_nil(uv.fs_lstat(new))
        assert.is_truthy(uv.fs_lstat(side))
    end)

    it('preserves a destination created after the owned intent was prepared', function()
        local operation = assert(begin({ move_document = true }))
        write(new, 'foreign NEW\n')
        assert.equals('pending', advance(operation).kind)
        assert.equals('parent\n', read(old)); assert.equals('foreign NEW\n', read(new))
        assert.is_truthy(uv.fs_lstat(side))
    end)

    it('atomically preserves NEW created after an absence observation before the owned rename', function()
        local fs, armed, raced = setmetatable({}, { __index = uv }), false, false
        fs.fs_lstat = function(path)
            if armed and path == new then
                if not raced then write(new, 'racing destination\n'); raced = true end
                return nil, 'ENOENT: stale absence observation', 'ENOENT'
            end
            return uv.fs_lstat(path)
        end
        local operation = assert(begin({ move_document = true, fs = fs }))
        armed = true
        assert.equals('pending', advance(operation).kind)
        assert.is_true(raced)
        assert.equals('racing destination\n', read(new)); assert.equals('parent\n', read(old))
        assert.is_truthy(uv.fs_lstat(side)); assert.is_truthy(uv.fs_lstat(operation.journal_path))
    end)

    it('does not infer an owned rename from equal NEW bytes on a different inode', function()
        local operation = assert(begin({ move_document = true }))
        assert(uv.fs_rename(old, root .. '/unrelated-old.md')); write(new, 'parent\n')
        assert.equals('pending', advance(operation).kind)
        assert.equals('parent\n', read(new)); assert.is_truthy(uv.fs_lstat(side))
        operation.release()
        local result = assert(recover())
        assert.equals('pending', result.kind); assert.is_truthy(uv.fs_lstat(operation.journal_path))
    end)

    it('validates owned move flags and still reads older version-one native journals', function()
        local operation = assert(begin({ metadata = function(_, cb) cb({ kind = 'unavailable' }) end }))
        write(new, 'parent\n'); assert.equals('pending', advance(operation).kind); operation.release()
        local original = vim.json.decode(read(operation.journal_path))
        original.version, original.state, original.parent, original.captured, original.orphan = 1, nil, nil, nil, nil
        table.remove(original.temps)
        original.steps = { document_moved = false, side_moved = true, rewritten = { ['child.md'] = true }, metadata = false }
        for _, field in ipairs({ 'document_move', 'document_moved' }) do
            local journal = vim.deepcopy(original)
            if field == 'document_move' then journal.document_move = 'invalid'
            else journal.steps.document_moved = 'invalid' end
            write(operation.journal_path, vim.json.encode(journal))
            local result, err = recover()
            assert.is_nil(result); assert.equals('pending', err.kind)
        end
        original.document_move = nil; original.steps.document_moved = nil
        write(operation.journal_path, vim.json.encode(original))
        assert.equals('registered', assert(recover()).kind)
    end)

    it('requires successful NEW write before moving side data or registry metadata', function()
        local calls = 0
        local operation = assert(begin({ metadata = function() calls = calls + 1 end }))
        assert.equals('pending', advance(operation).kind)
        assert.equals(0, calls); assert.is_truthy(uv.fs_stat(side)); assert.is_truthy(uv.fs_stat(operation.journal_path))
    end)

    it('retains uncertain metadata and recovers the same tuple without rollback', function()
        local operation = assert(begin({ metadata = function(_, cb) cb({ kind = 'unavailable', error = 'deadline' }) end }))
        write(new, 'parent\n'); assert.equals('pending', advance(operation).kind)
        assert.is_nil(uv.fs_stat(side)); assert.is_truthy(uv.fs_stat(root .. '/new.side'))
        assert.is_truthy(uv.fs_stat(operation.journal_path)); operation.release()
        local conflict, err = begin(nil, root .. '/different.md')
        assert.is_nil(conflict); assert.equals('pending', err.kind)
        local result = assert(recover())
        assert.equals('registered', result.kind); assert.is_nil(uv.fs_stat(operation.journal_path))
    end)

    it('recognizes a crash after side rename before the progress checkpoint', function()
        local fs = setmetatable({}, { __index = uv })
        fs.fs_rename = function(from, to)
            local ok, err = uv.fs_rename(from, to)
            if from == side and ok then return nil, 'interrupted after rename' end
            return ok, err
        end
        fs.fs_rename_noreplace = fs.fs_rename
        local operation = assert(begin({ fs = fs }))
        write(new, 'parent\n'); assert.equals('pending', advance(operation).kind)
        assert.is_truthy(uv.fs_stat(root .. '/new.side')); operation.release()
        assert.equals('registered', assert(recover()).kind)
        assert.matches('../new.md', read(root .. '/new.side/child.md'), 1, true)
    end)

    it('atomically preserves an empty foreign side directory created after an absence observation', function()
        local fs, armed, raced, foreign_inode = setmetatable({}, { __index = uv }), false, false, nil
        local destination = root .. '/new.side'
        fs.fs_lstat = function(path)
            if armed and path == destination then
                if not raced then
                    assert(uv.fs_mkdir(destination, 448)); raced = true
                    foreign_inode = assert(uv.fs_lstat(destination)).ino
                end
                return nil, 'ENOENT: stale absence observation', 'ENOENT'
            end
            return uv.fs_lstat(path)
        end
        local before = read(side .. '/child.md')
        local operation = assert(begin({ fs = fs }))
        write(new, 'parent\n'); armed = true
        assert.equals('pending', advance(operation).kind)
        assert.is_true(raced)
        assert.equals(foreign_inode, assert(uv.fs_lstat(destination)).ino)
        assert.is_nil(uv.fs_scandir_next(assert(uv.fs_scandir(destination))))
        assert.equals(before, read(side .. '/child.md'))
        assert.is_truthy(uv.fs_lstat(operation.journal_path))
    end)

    it('refuses changed backlink preimages before moving any side data', function()
        local operation = assert(begin())
        write(new, 'parent\n'); write(side .. '/child.md', 'foreign child\n')
        assert.equals('pending', advance(operation).kind)
        assert.equals('foreign child\n', read(side .. '/child.md'))
        assert.is_nil(uv.fs_stat(root .. '/new.side'))
    end)

    it('preserves a foreign backlink edit made while its replacement temp is written', function()
        local fs, descriptors, changed = setmetatable({}, { __index = uv }), {}, false
        fs.fs_open = function(path, ...)
            local fd, err = uv.fs_open(path, ...)
            if fd then descriptors[fd] = path end
            return fd, err
        end
        fs.fs_write = function(fd, bytes, offset)
            local count, err = uv.fs_write(fd, bytes, offset)
            if not changed and descriptors[fd] and descriptors[fd]:find('/new.side/', 1, true)
                and descriptors[fd]:match('%.tmp$') then
                changed = true
                write(root .. '/new.side/child.md', 'foreign during temp\n')
            end
            return count, err
        end
        local operation = assert(begin({ fs = fs }))
        write(new, 'parent\n')
        assert.equals('pending', advance(operation).kind)
        assert.is_true(changed)
        assert.equals('foreign during temp\n', read(root .. '/new.side/child.md'))
        assert.is_truthy(uv.fs_stat(operation.journal_path))
    end)

    it('rejects unconfirmed targets, side collisions and escaping symlinks before journaling', function()
        local op, err = begin({ destination_registered = true }); assert.is_nil(op); assert.is_truthy(err)
        op, err = move().begin('ns', registration(old), new, { root = root .. '/state' }); assert.is_nil(op); assert.is_truthy(err)
        write(new, 'existing destination'); vim.fn.mkdir(root .. '/new.side', 'p'); assert.is_nil(begin()); vim.fn.delete(root .. '/new.side', 'd'); assert(uv.fs_unlink(new))
        assert(uv.fs_symlink(old, side .. '/escape.md')); assert.is_nil(begin())
    end)

    it('refuses another editor execution or recovery while the original lease is held', function()
        local operation = assert(begin())
        local child = vim.fn.jobstart({ vim.v.progpath, '--clean', '--embed', '--headless', '-i', 'NONE' }, { rpc = true })
        children[#children + 1] = child
        vim.rpcrequest(child, 'nvim_exec_lua', 'vim.opt.rtp:append(...)', { vim.fn.getcwd() })
        local result = vim.rpcrequest(child, 'nvim_exec_lua', [[
            local root,old,new=...; local M=require('parley.document_move')
            local op,err=M.begin('ns',{ID='stable-id',File=old,Owner='owner'},new,{root=root,destination_registered=false})
            local recovery,re=M.recover('ns','stable-id',{root=root},function()end)
            return {first=err.kind,second=re.kind,created=op~=nil or recovery~=nil}
        ]], { root .. '/state', old, new })
        assert.same({ first = 'busy', second = 'busy', created = false }, result)
        assert.is_truthy(uv.fs_stat(operation.journal_path)); assert.is_truthy(uv.fs_stat(side))
    end)

    it('bounds pending journals and refuses oversized or corrupt recovery data', function()
        local directory = root .. '/state/document-moves/' .. vim.fn.sha256('ns')
        vim.fn.mkdir(directory, 'p')
        for n = 1, 32 do write(directory .. '/' .. vim.fn.sha256('other' .. n) .. '.json', '{}') end
        local op, err = begin(); assert.is_nil(op); assert.equals('limit', err.kind)
        vim.fn.delete(directory, 'rf'); vim.fn.mkdir(directory, 'p')
        local path = directory .. '/' .. vim.fn.sha256('stable-id') .. '.json'
        write(path, string.rep('x', 256 * 1024 + 1))
        local result, oversized = recover(); assert.is_nil(result); assert.equals('pending', oversized.kind)
        write(path, '{broken json')
        result, err = recover(); assert.is_nil(result); assert.equals('pending', err.kind)
        assert.equals('{broken json', read(path))
    end)

    it('rejects malformed journal witnesses before any recovery effects', function()
        local operation = assert(begin({ metadata = function(_, cb) cb({ kind = 'unavailable' }) end }))
        write(new, 'parent\n'); assert.equals('pending', advance(operation).kind); operation.release()
        local journal = vim.json.decode(read(operation.journal_path))
        journal.new_witness = true
        write(operation.journal_path, vim.json.encode(journal))
        local safe, recovered, err = pcall(move().recover, 'ns', 'stable-id', { root = root .. '/state' }, function() end)
        assert.is_true(safe)
        if recovered then operations[#operations + 1] = recovered end
        assert.is_nil(recovered); assert.equals('pending', err.kind)
        assert.is_truthy(uv.fs_stat(operation.journal_path))
    end)

    it('lists bounded validated pending tuples without acquiring their live execution leases', function()
        local operation = assert(begin({ old_lock = 'owned bytes', baseline = { hash = 'baseline' } }))
        assert.is_function(move().pending)
        local list, err = move().pending('ns', { root = root .. '/state' })
        assert.is_nil(err); assert.equals(1, #list)
        assert.equals('stable-id', list[1].id); assert.equals(old, list[1].old); assert.equals(new, list[1].new)
        assert.equals('owned bytes', list[1].protection.old_lock)
        assert.same({ hash = 'baseline' }, list[1].protection.baseline)
        assert.is_false(list[1].new_witness)
        local journal = vim.json.decode(read(operation.journal_path)); journal.id = 'forged-id'
        write(operation.journal_path, vim.json.encode(journal))
        list, err = move().pending('ns', { root = root .. '/state' })
        assert.is_nil(list); assert.equals('pending', err.kind)
    end)

    it('resumes a prepared journal only with an explicit fresh write and exact tuple witness', function()
        local operation = assert(begin()); operation.release()
        write(new, 'parent\n')
        local result, err = recover()
        assert.is_nil(result); assert.equals('pending', err.kind)
        result, err = recover({ new_written = true })
        assert.is_nil(result); assert.equals('pending', err.kind)
        result = assert(recover({ new_written = true, old_path = old, new_path = new }))
        assert.equals('registered', result.kind)
        assert.is_nil(uv.fs_stat(operation.journal_path))
    end)

    it('accepts a confirmed effective owner change with the same stable ID and NEW path', function()
        local operation = assert(begin({ metadata = function(_, cb)
            local changed = registration(new); changed.Owner = 'new-effective-owner'
            cb({ kind = 'registered', registration = changed })
        end }))
        write(new, 'parent\n')
        local result = advance(operation)
        assert.equals('registered', result.kind); assert.equals('new-effective-owner', result.registration.Owner)
    end)

    it('rejects forged cleanup manifests and preserves unrelated files', function()
        local operation = assert(begin()); operation.release()
        local journal = vim.json.decode(read(operation.journal_path))
        local unowned = root .. '/unowned.tmp'
        write(unowned, 'KEEP')
        journal.temps = { unowned }
        write(operation.journal_path, vim.json.encode(journal))
        local result, err = recover(); assert.is_nil(result); assert.equals('pending', err.kind)
        assert.equals('KEEP', read(unowned)); assert.is_truthy(uv.fs_stat(operation.journal_path))
    end)
    it('displaces an admitted orphan once and rewrites parent references before editor acknowledgement', function()
        local before = '---\r\ndiscussions:\r\n  - doc: "old.side/child.md" # keep\r\n---\r\n[child](old.side/child.md)\r\n'
        write(old, before); write(root .. '/new.side/orphan.md', 'orphan\0bytes')
        local inode = assert(uv.fs_stat(root .. '/new.side')).ino
        local synced = 0
        local operation, err = begin({ move_document = true, parent_rewritten = function(op, proof)
            synced = synced + 1
            assert.equals(new, proof.path); assert.equals(vim.fn.sha256(before), proof.before_hash)
            assert.equals(vim.fn.sha256(read(new)), proof.after_hash)
            assert.equals(proof.after_hash, proof.current_hash)
            assert.is_false(move().document_ready(op))
            return true
        end })
        assert(operation, err and err.error)
        assert.equals(2, operation.journal.version); assert.is_nil(operation.journal.steps)
        assert.equals('registered', advance(operation).kind)
        assert.equals(1, synced)
        assert.equals(inode, assert(uv.fs_stat(root .. '/new_1.side')).ino)
        assert.equals('orphan\0bytes', read(root .. '/new_1.side/orphan.md'))
        assert.equals(before:gsub('old.side/', 'new.side/'), read(new))
        assert.equals(root .. '/new_1.side', operation.orphan_destination)
    end)

    it('moves the pending proposal, discussions index, side folder and child backlink together (#389)', function()
        local marker = '🤖{ → \\[proposal\\](old.side/child.md)}'
        local before = '---\ndiscussions:\n  - doc: old.side/child.md\n---\n' .. marker .. '\n'
        write(old, before)
        local operation, err = begin({ move_document = true })
        assert(operation, err and err.error)
        assert.equals('registered', advance(operation).kind)
        assert.equals(before:gsub('old%.side/', 'new.side/'), read(new))
        assert.is_nil(uv.fs_stat(side))
        assert.equals('---\nparent: ../new.md\n---\n[parent](../new.md#anchor)\nunchanged\n',
            read(root .. '/new.side/child.md'))
        local destination = assert(read(new):match('%]%(([^)]+)%)'))
        assert.equals('new.side/child.md', destination)
        assert.truthy(uv.fs_stat(root .. '/' .. destination))
    end)

    it('scans pending-link documents once at N and 2N rather than once per link (#389)', function()
        local references = require('parley.reference_candidates')
        local original = references.markdown_spans
        local calls, scanned
        references.markdown_spans = function(lines, range, opts)
            calls = calls + 1
            for _, line in ipairs(lines) do scanned = scanned + #line + 1 end
            return original(lines, range, opts)
        end
        local ok, problem = pcall(function()
            local link = '🤖{ → ' .. string.char(92) .. '[proposal' .. string.char(92) .. '](old.side/child.md)}'
            for _, count in ipairs({ 8, 16 }) do
                calls, scanned = 0, 0
                local before = string.rep(link .. '\n', count)
                local after = assert(require('parley.document_move_plan').rewrite_side_references(before, old, new))
                assert.equals(before:gsub('old%.side/', 'new.side/'), after)
                assert.equals(1, calls)
                assert.equals(#before, scanned)
            end
        end)
        references.markdown_spans = original
        assert.is_true(ok, tostring(problem))
    end)

    it('captures native NEW raw bytes rather than predicting save serialization', function()
        local operation = assert(begin({ parent_bytes = '[draft](old.side/child.md)\n' }))
        write(new, '\239\187\191[draft](old.side/child.md)\r\n')
        assert.equals('registered', advance(operation).kind)
        assert.equals('\239\187\191[draft](new.side/child.md)\r\n', read(new))
    end)

    it('does not adopt saves before the parent editor generation is synchronized', function()
        local operation = assert(begin({ move_document = true, parent_rewritten = function() return nil, 'modified buffer' end }))
        assert.equals('pending', advance(operation).kind)
        assert.is_false(move().document_ready(operation))
        write(new, 'operator changed it\n')
        assert.is_nil(move().record_write(operation))
        assert.equals('operator changed it\n', read(new))
    end)

    it('recovers orphan publication without choosing another suffix', function()
        write(root .. '/new.side/orphan.md', 'keep')
        local fs = setmetatable({}, { __index = uv })
        fs.fs_rename_noreplace = function(from, to)
            local ok, err = uv.fs_rename(from, to)
            if from == root .. '/new.side' and ok then return nil, 'published before checkpoint' end
            return ok, err
        end
        local operation = assert(begin({ fs = fs, move_document = true }))
        assert.equals('pending', advance(operation).kind); operation.release()
        assert.equals('registered', assert(recover()).kind)
        assert.equals('keep', read(root .. '/new_1.side/orphan.md'))
        assert.is_nil(uv.fs_lstat(root .. '/new_2.side'))
    end)

    it('refuses a raced orphan suffix without replacing either folder', function()
        write(root .. '/new.side/orphan.md', 'keep')
        local operation = assert(begin({ move_document = true }))
        write(root .. '/new_1.side/foreign.md', 'foreign')
        assert.equals('pending', advance(operation).kind)
        assert.equals('keep', read(root .. '/new.side/orphan.md'))
        assert.equals('foreign', read(root .. '/new_1.side/foreign.md'))
        assert.equals('parent\n', read(old))
    end)

    it('refuses malformed actual native bytes before displacing its admitted orphan', function()
        write(root .. '/new.side/orphan.md', 'keep')
        local operation = assert(begin({ parent_bytes = 'draft\n' }))
        write(new, '---\ndiscussions: *ambiguous\n---\n')
        assert.equals('pending', advance(operation).kind)
        assert.equals('keep', read(root .. '/new.side/orphan.md'))
        assert.is_nil(uv.fs_lstat(root .. '/new_1.side'))
        assert.is_truthy(uv.fs_lstat(side))
    end)

    it('rejects forged orphan paths before touching unrelated bytes', function()
        write(root .. '/new.side/orphan.md', 'keep')
        local operation = assert(begin({ move_document = true })); operation.release()
        local journal = vim.json.decode(read(operation.journal_path))
        journal.orphan.path = root .. '/unrelated.side'
        write(operation.journal_path, vim.json.encode(journal))
        local result, err = recover()
        assert.is_nil(result); assert.equals('pending', err.kind)
        assert.equals('keep', read(root .. '/new.side/orphan.md'))
        assert.equals('parent\n', read(old))
    end)

    it('recovers parent rewrite publication without applying it twice', function()
        write(old, '[child](old.side/child.md)\n')
        local fs = setmetatable({}, { __index = uv })
        fs.fs_rename = function(from, to)
            local ok, err = uv.fs_rename(from, to)
            if to == new and from:match('%.tmp$') and ok then return nil, 'parent published before checkpoint' end
            return ok, err
        end
        local operation = assert(begin({ move_document = true, fs = fs }))
        assert.equals('pending', advance(operation).kind)
        assert.equals('[child](new.side/child.md)\n', read(new))
        operation.release()
        local named = 0
        local result = assert(recover({ document_moved = function(op)
            named = named + 1
            assert.equals('editor', op.journal.state.phase, 'parent publication proof must precede the recovered editor handoff')
            assert.equals('[child](new.side/child.md)\n', read(new))
            return true
        end }))
        assert.equals('registered', result.kind, result.error); assert.equals(1, named)
        assert.equals('[child](new.side/child.md)\n', read(new))
    end)

    it('accepts the outstanding metadata reply after a synchronized operator save', function()
        local reply
        local operation = assert(begin({ move_document = true, metadata = function(_, cb) reply = cb end }))
        local result; move().advance(operation, function(value) result = value end)
        assert.is_true(move().document_ready(operation)); assert.is_function(reply)
        write(new, 'saved while metadata pending\n')
        assert.is_true(move().record_write(operation))
        reply({ kind = 'registered', registration = registration(new) })
        assert.equals('registered', result.kind, result.error)
        assert.equals('saved while metadata pending\n', read(new))
    end)

    it('rechecks raw NEW after editor acknowledgement before adopting protection or metadata', function()
        local metadata = 0
        local operation = assert(begin({ move_document = true, baseline = 'baseline',
            parent_rewritten = function(op)
                write(new, 'foreign editor-autocmd write\n')
                return true, { old_lock = op.old_lock, new_lock = op.new_lock, baseline = 'new-baseline' }
            end,
            metadata = function(op, cb) metadata = metadata + 1; cb({ kind = 'registered', registration = registration(op.new) }) end,
        }))
        assert.equals('pending', advance(operation).kind)
        assert.equals(0, metadata); assert.equals('baseline', operation.journal.protection.baseline)
        assert.equals('editor', operation.journal.state.phase)
        assert.equals('foreign editor-autocmd write\n', read(new))
    end)

    it('persists the pre-rewrite editor hash and reuses it after interrupted editor synchronization', function()
        write(old, '[child](old.side/child.md)\n')
        local editor_hash = vim.fn.sha256(vim.json.encode({ '[child](old.side/child.md)' }))
        local operation = assert(begin({ move_document = true, editor_snapshot = function() return editor_hash end,
            parent_rewritten = function() return nil, 'editor interrupted' end }))
        assert.equals('pending', advance(operation).kind)
        assert.equals(editor_hash, operation.journal.parent.editor_before_hash)
        operation.release()
        local seen
        local result = assert(recover({ editor_snapshot = function() error('must not recapture') end,
            parent_rewritten = function(_, proof) seen = proof.before_editor_hash; return true end }))
        assert.equals('registered', result.kind, result.error); assert.equals(editor_hash, seen)
    end)

    it('preserves orphan contents whose name matches a future active-tree temporary', function()
        write(root .. '/new.side/orphan.md', 'keep')
        local operation = assert(begin({ move_document = true }))
        local temporary = operation.journal.temps[2]
        write(temporary, 'opaque orphan content, never owned by this operation')
        assert.equals('registered', advance(operation).kind)
        local displaced = root .. '/new_1.side/' .. vim.fn.fnamemodify(temporary, ':t')
        assert.equals('opaque orphan content, never owned by this operation', read(displaced))
    end)

    for _, kind in ipairs({ 'journal', 'parent' }) do
        it('preserves foreign bytes at a ' .. kind .. ' temporary instead of claiming cleanup ownership', function()
            write(old, '[child](old.side/child.md)\n')
            local operation = assert(begin({ move_document = true }))
            local temporary = kind == 'journal' and operation.journal.temps[1] or operation.journal.temps[#operation.journal.temps]
            write(temporary, 'foreign temporary bytes')
            local result = advance(operation)
            assert.equals('pending', result.kind)
            assert.equals('foreign temporary bytes', read(temporary))
            operation.release()
            local recovered, recovery_err = recover()
            assert.equals('pending', (recovered or recovery_err).kind)
            assert.equals('foreign temporary bytes', read(temporary))
        end)
    end

    it('consumes only the exactly reconstructed unpublished journal checkpoint after reobserving publication', function()
        write(root .. '/new.side/orphan.md', 'keep')
        local fs = setmetatable({}, { __index = uv })
        local published, candidate = false, nil
        fs.fs_rename_noreplace = function(from, to)
            local ok, err = uv.fs_rename(from, to)
            if from == root .. '/new.side' and ok then published = true end
            return ok, err
        end
        fs.fs_rename = function(from, to)
            if published and to:match('%.json$') then candidate = read(from); return nil, 'checkpoint interrupted' end
            return uv.fs_rename(from, to)
        end
        local operation = assert(begin({ move_document = true, fs = fs }))
        assert.equals('pending', advance(operation).kind); assert.is_string(candidate)
        local temporary = operation.journal.temps[1]
        operation.release(); write(temporary, candidate)
        assert.equals('registered', assert(recover()).kind)
        assert.equals('keep', read(root .. '/new_1.side/orphan.md'))
        assert.is_nil(uv.fs_lstat(temporary)); assert.is_nil(uv.fs_lstat(root .. '/new_2.side'))
    end)

    it('retains confirmed effective registration across an interrupted local finish', function()
        local effective = registration(new); effective.Owner = 'new-effective-owner'
        local operation = assert(begin({ move_document = true,
            metadata = function(_, cb) cb({ kind = 'registered', registration = effective, changed = true }) end,
            finish = function() return nil, 'local finish interrupted' end,
        }))
        assert.equals('pending', advance(operation).kind); operation.release()
        local finished
        local result = assert(recover({ finish = function(_, reply) finished = reply.registration; return true end }))
        assert.equals('registered', result.kind)
        assert.equals('new-effective-owner', finished.Owner)
        assert.same(effective, result.registration)
    end)

    it('revalidates raw NEW before completing an outstanding metadata reply', function()
        local reply, finished = nil, 0
        local operation = assert(begin({ move_document = true,
            metadata = function(_, cb) reply = cb end,
            finish = function() finished = finished + 1; return true end,
        }))
        local result; move().advance(operation, function(value) result = value end)
        assert.is_function(reply); write(new, 'unrecorded foreign NEW while metadata pending\n')
        reply({ kind = 'registered', registration = registration(new) })
        assert.is_not_nil(result); assert.equals('pending', result.kind)
        assert.equals(0, finished)
        assert.equals('unrecorded foreign NEW while metadata pending\n', read(new))
        assert.is_truthy(uv.fs_lstat(operation.journal_path))
    end)

    it('refuses bounded reducer allocation without throwing or retaining its lease', function()
        vim.fn.delete(side, 'rf')
        local deep = side
        for _ = 1, 4 do deep = deep .. '/' .. string.rep('d', 90) end
        for n = 1, 512 do
            write(deep .. '/' .. string.format('%03d-', n) .. string.rep('x', 70) .. '.md', '[up](' .. old .. ')')
        end
        local safe, operation, err = pcall(begin, { move_document = true })
        assert.is_true(safe, 'allocation refusal must return normally')
        assert.is_nil(operation); assert.equals('limit', err.kind)
        local lease, lease_err = require('parley.document_lease').acquire('ns', 'stable-id', { root = root .. '/state' })
        assert(lease, lease_err and lease_err.error); assert.is_true(lease.release())
        assert.equals('parent\n', read(old)); assert.is_nil(uv.fs_lstat(new))
    end)

    for _, before in ipairs({ 'parent\n', '[child](old.side/child.md)\n' }) do
        it('refuses a same-byte replacement of the current parent inode before ' .. (before:find('old.side', 1, true) and 'rewriting' or 'adopting a no-op'), function()
            write(old, before)
            local metadata = 0
            local operation = assert(begin({ move_document = true,
                document_moved = function()
                    assert(uv.fs_rename(new, root .. '/captured-new.md'))
                    write(new, before)
                    return true
                end,
                metadata = function(op, cb) metadata = metadata + 1; cb({ kind = 'registered', registration = registration(op.new) }) end,
            }))
            assert.equals('pending', advance(operation).kind)
            assert.equals(0, metadata); assert.equals(before, read(new))
        end)
    end

    for _, interrupted_at in ipairs({ 'metadata', 'parent' }) do
        it('proves recovered raw NEW before invoking the document name handoff from ' .. interrupted_at, function()
            local options = { move_document = true, metadata = function(_, cb) cb({ kind = 'unavailable', error = 'metadata interrupted' }) end }
            if interrupted_at == 'parent' then
                write(old, '[child](old.side/child.md)\n')
                local fs = setmetatable({}, { __index = uv })
                fs.fs_rename = function(from, to)
                    local ok, err = uv.fs_rename(from, to)
                    if to == new and from:match('%.tmp$') and ok then return nil, 'parent published before checkpoint' end
                    return ok, err
                end
                options.fs = fs
            end
            local operation = assert(begin(options))
            assert.equals('pending', advance(operation).kind)
            assert.equals(interrupted_at, operation.journal.state.phase)
            operation.release()
            write(new, 'unknown replacement after interruption\n')
            local names = 0
            local result = assert(recover({ document_moved = function() names = names + 1; return true end }))
            assert.equals('pending', result.kind)
            assert.equals(0, names, 'raw proof must precede any editor name/read handoff')
            assert.equals('unknown replacement after interruption\n', read(new))
            assert.is_truthy(uv.fs_lstat(operation.journal_path))
        end)
    end

    local function finalization_fixture(fault)
        local old_lock, new_lock = root .. '/old.lock', root .. '/new.lock'
        local before_old, before_new, editor = 'old protection', 'new protection', string.rep('e', 64)
        write(old_lock, before_old); write(new_lock, before_new)
        local fired, snapshots, applied, retired = false, 0, 0, 0
        local function lock(path) return uv.fs_lstat(path) and read(path) or false end
        local fs = setmetatable({}, { __index = uv })
        fs.fs_unlink = function(path)
            if fault == 'unlink' and path:match('%.json$') and not fired then fired = true; return nil, 'retirement interrupted' end
            return uv.fs_unlink(path)
        end
        fs.fs_rename = function(from, to)
            if fault and fault:match('^checkpoint:') and to:match('%.json$') and not fired then
                local candidate = vim.json.decode(read(from))
                local f = candidate.state and candidate.state.finalization or candidate.finalization
                local stage, after = fault:match('^checkpoint:([^:]+):([^:]+)$')
                if f and f.stage == stage then
                    fired = true
                    if after == 'after' then assert(uv.fs_rename(from, to)) end
                    return nil, 'finalization checkpoint interrupted'
                end
            end
            return uv.fs_rename(from, to)
        end
        local options = { fs = fs, move_document = true, old_lock = before_old, new_lock = before_new,
            finalization_snapshot = function()
                snapshots = snapshots + 1
                if lock(new_lock) ~= before_new or lock(old_lock) ~= before_old and lock(old_lock) ~= false then
                    return nil, 'snapshot protection changed'
                end
                return true, { old_lock_before = before_old, new_lock_before = before_new,
                    new_lock_after = false, editor_hash = editor }
            end,
            prepare_finalization = function(op, intent)
                applied = applied + 1
                if intent.document_hash ~= vim.fn.sha256(read(new)) or intent.editor_hash ~= editor then return nil, 'finalization content changed' end
                local old_value, new_value = lock(old_lock), lock(new_lock)
                if intent.stage == 'retire' then
                    if old_value ~= false or new_value ~= false then return nil, 'retired protection changed' end
                elseif (old_value ~= before_old and old_value ~= false) or (new_value ~= before_new and new_value ~= false) then
                    return nil, 'finalization protection changed'
                end
                if old_value then assert(uv.fs_unlink(old_lock)) end
                if fault == 'old' and not fired then fired = true; return nil, 'OLD cleanup interrupted' end
                if new_value then assert(uv.fs_unlink(new_lock)) end
                if fault == 'new' and not fired then fired = true; return nil, 'NEW cleanup interrupted' end
                assert.is_truthy(uv.fs_lstat(op.journal_path), 'journal must survive all protection effects')
                return true
            end,
            finish_retired = function(op)
                retired = retired + 1
                assert.is_nil(uv.fs_lstat(op.journal_path)); assert.is_false(lock(old_lock)); assert.is_false(lock(new_lock))
                return true
            end,
        }
        return options, function() return { snapshots = snapshots, applied = applied, retired = retired,
            old = lock(old_lock), new = lock(new_lock) } end,
            function(value) editor = value end
    end

    it('persists finalization intent before protection effects and retires before volatile adoption', function()
        local options, observed = finalization_fixture()
        local operation = assert(begin(options))
        assert.equals('registered', advance(operation).kind)
        local seen = observed(); assert.is_true(seen.snapshots > 0); assert.is_true(seen.applied > 0)
        assert.equals(1, seen.retired); assert.is_false(seen.old); assert.is_false(seen.new)
    end)
    for _, fault in ipairs({ 'old', 'new', 'unlink', 'checkpoint:handoff:before', 'checkpoint:handoff:after',
        'checkpoint:protection:before', 'checkpoint:protection:after', 'checkpoint:retire:before', 'checkpoint:retire:after' }) do
        it('replays finalization after ' .. fault .. ' without guessing released protection', function()
            local options, observed = finalization_fixture(fault)
            local operation = assert(begin(options)); assert.equals('pending', advance(operation).kind)
            assert.is_truthy(uv.fs_lstat(operation.journal_path)); assert.equals(0, observed().retired)
            local disk = vim.json.decode(read(operation.journal_path))
            operation.release()
            if disk.state and type(disk.state.finalization) == 'table' or type(disk.finalization) == 'table' then
                options.document_moved = function() error('finalization must not reread the document') end
                options.parent_rewritten = options.document_moved
            end
            local result = assert(recover(options)); assert.equals('registered', result.kind, result.error)
            assert.equals(1, observed().retired); assert.is_false(observed().old); assert.is_false(observed().new)
        end)
    end
    for _, changed in ipairs({ 'raw', 'editor', 'old-lock', 'new-lock' }) do
        it('preserves unknown ' .. changed .. ' during interrupted finalization', function()
            local options, observed, set_editor = finalization_fixture('old')
            local operation = assert(begin(options)); assert.equals('pending', advance(operation).kind); operation.release()
            if changed == 'raw' then write(new, 'foreign raw bytes')
            elseif changed == 'editor' then set_editor(string.rep('f', 64))
            elseif changed == 'old-lock' then write(root .. '/old.lock', 'foreign protection')
            else write(root .. '/new.lock', 'foreign protection') end
            local result = assert(recover(options)); assert.equals('pending', result.kind)
            assert.equals(0, observed().retired)
            if changed == 'raw' then assert.equals('foreign raw bytes', read(new)) end
            if changed == 'new-lock' then assert.equals('foreign protection', read(root .. '/new.lock')) end
            if changed == 'old-lock' then assert.equals('foreign protection', read(root .. '/old.lock')) end
        end)
    end

    it('replays the same finalizer from a version-one journal after NEW protection cleanup', function()
        local options, observed = finalization_fixture('new')
        local prepared = assert(begin(options)); prepared.release()
        local legacy = vim.json.decode(read(prepared.journal_path))
        legacy.version, legacy.state, legacy.parent, legacy.captured, legacy.editor_captured, legacy.orphan = 1, nil, nil, nil, nil, nil
        legacy.confirmation = nil; table.remove(legacy.temps)
        legacy.steps = { document_moved = false, side_moved = false, rewritten = {}, metadata = false }
        write(prepared.journal_path, vim.json.encode(legacy))
        local result, operation = recover(options)
        assert.equals('pending', result.kind); assert.is_false(observed().old); assert.is_false(observed().new)
        assert.equals(1, operation.journal.version); assert.equals('protection', move().finalization(operation).stage)
        local summaries = assert(move().pending('ns', { root = root .. '/state' }))
        assert.equals('protection', summaries[1].finalization.stage)
        operation.release()
        options.document_moved = function() error('legacy finalization must not repeat editor handoff') end
        assert.equals('registered', assert(recover(options)).kind); assert.equals(1, observed().retired)
    end)

    it('reports volatile retirement failure without inventing a pending durable migration', function()
        local options, observed = finalization_fixture()
        options.finish_retired = function() return nil, 'volatile adoption fault' end
        local operation = assert(begin(options)); local result = advance(operation)
        assert.equals('registered', result.kind); assert.matches('reopen', result.local_warning)
        assert.is_nil(uv.fs_lstat(operation.journal_path)); assert.is_true(operation.released)
        assert.is_false(observed().old); assert.is_false(observed().new)
    end)

    it('does not infer missing NEW protection from a handoff intent that never authorized release', function()
        local options, observed = finalization_fixture('checkpoint:protection:before')
        local operation = assert(begin(options)); assert.equals('pending', advance(operation).kind)
        assert.equals('handoff', move().finalization(operation).stage); operation.release()
        assert(uv.fs_unlink(root .. '/new.lock'))
        local result = assert(recover(options)); assert.equals('pending', result.kind)
        assert.equals('old protection', observed().old); assert.equals(0, observed().applied)
        assert.equals(0, observed().retired)
    end)

    it('leaves the complete document protection and journal tree identical for every geometry refusal', function()
        local cases = {
            { name = 'OLD under target without own side', old = 'parent.side/child.md', new = 'parent.md' },
            { name = 'OLD under target with own side', old = 'parent.side/child.md', new = 'parent.md', own_side = true },
            { name = 'NEW under source', old = 'source.md', new = 'source.side/nested/new.md', own_side = true },
            { name = 'suffix equals absent source', old = 'parent_1.md', new = 'parent.md', orphan = true },
            { name = 'document equals own side root', old = 'doc.side', new = 'new.md' },
            { name = 'destination equals side root', old = 'doc.md', new = 'doc.side' },
            { name = 'forged suffix outside target family', old = 'plain.md', new = 'next.md', orphan = true, forged = true },
            { name = 'shared root forged as distinct orphan', old = 'same.md', new = 'same.markdown', orphan = true, forged = true },
            { name = 'frozen suffix raced into absent source', old = 'parent_2.md', new = 'parent.md', orphan = true, frozen = true },
            { name = 'opaque suffix observation', old = 'plain.md', new = 'next.md', orphan = true, opaque = true },
        }
        for index, case in ipairs(cases) do
            local base = root .. '/geometry-' .. index
            old, new = base .. '/' .. case.old, base .. '/' .. case.new
            write(old, 'operator parent bytes\n')
            write(base .. '/protection.lock', 'opaque protection\0bytes')
            write(base .. '/retained-journals/previous.json', 'opaque journal bytes')
            if case.own_side then write(require('parley.document_move_plan').side_path(old) .. '/child.md', 'side child bytes') end
            if case.orphan then write(require('parley.document_move_plan').side_path(new) .. '/orphan.md', 'orphan bytes') end
            local installed = 0
            local options = { move_document = true, install_new = function() installed = installed + 1; return true end }
            if case.forged then options.geometry_preflight = { old = old, new = new, orphan_destination = base .. '/outside.side' } end
            if case.frozen then
                options.geometry_preflight = assert(move().preflight_geometry(old, new))
                write(options.geometry_preflight.orphan_destination .. '/racing.md', 'foreign suffix bytes')
            end
            if case.opaque then
                local fs = setmetatable({}, { __index = uv })
                local candidate = require('parley.document_move_plan').side_path(new):sub(1, -6) .. '_1.side'
                fs.fs_lstat = function(path)
                    if path == candidate then return nil, 'opaque suffix observation', 'EACCES' end
                    return uv.fs_lstat(path)
                end
                options.fs = fs
            end
            local before = tree(root)
            local operation, err = begin(options)
            if operation then operation.release() end
            assert.is_nil(operation, case.name)
            assert.matches(case.opaque and 'opaque suffix observation' or 'move to another name first', err.error, 1, true)
            assert.equals(0, installed, case.name); assert.same(before, tree(root), case.name)
        end
    end)

    for _, version in ipairs({ 1, 2 }) do
        it('refuses unsafe prepared version-' .. version .. ' geometry before recovery effects', function()
            local operation = assert(begin({ move_document = true })); operation.release()
            local journal = vim.json.decode(read(operation.journal_path))
            local unsafe_old = root .. '/new.side/nested.md'
            write(unsafe_old, 'parent\n')
            journal.old, journal.registration.File = unsafe_old, unsafe_old
            journal.old_witness = assert(uv.fs_stat(unsafe_old))
            if version == 1 then
                journal.version, journal.state, journal.parent, journal.captured, journal.editor_captured, journal.orphan = 1, nil, nil, nil, nil, nil
                journal.confirmation = nil; table.remove(journal.temps)
                journal.steps = { document_moved = false, side_moved = false, rewritten = {}, metadata = false }
            end
            write(operation.journal_path, vim.json.encode(journal))
            local before = tree(root)
            local result, err = recover()
            assert.is_nil(result); assert.matches('move to another name first', err.error, 1, true)
            assert.same(before, tree(root))
        end)
    end
    it('refuses a forged orphan suffix that aliases an uncaptured source during recovery', function()
        write(root .. '/new.side/orphan.md', 'orphan bytes')
        local operation = assert(begin({ move_document = true })); operation.release()
        local journal = vim.json.decode(read(operation.journal_path))
        local unsafe_old = root .. '/new_1.md'; write(unsafe_old, 'parent\n')
        journal.old, journal.registration.File = unsafe_old, unsafe_old
        journal.old_witness = assert(uv.fs_stat(unsafe_old))
        journal.side_witness, journal.entries, journal.state.side, journal.state.children = false, {}, false, {}
        journal.temps = { journal.temps[1], journal.temps[#journal.temps] }
        write(operation.journal_path, vim.json.encode(journal))
        local before = tree(root)
        local result, err = recover()
        assert.is_nil(result); assert.matches('move to another name first', err.error, 1, true)
        assert.same(before, tree(root)); assert.is_nil(uv.fs_lstat(root .. '/new_1.side'))
    end)

end)
