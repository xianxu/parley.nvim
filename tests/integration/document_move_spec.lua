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
        assert.is_true(vim.wait(3000, function() return result ~= nil end))
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
        assert.is_true(vim.wait(3000, function() return result ~= nil end))
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
        assert.is_true(vim.wait(3000, function() return metadata ~= nil end))
        assert.is_nil(result); assert.equals(1, calls)
        assert.equals('---\nparent: ../new.md\n---\n[parent](../new.md#anchor)\nunchanged\n', read(root .. '/new.side/child.md'))
        assert.equals('binary\0payload', read(root .. '/new.side/binary.bin'))
        assert.equals('parent\n', read(old))
        assert.equals('busy', select(2, begin()).kind)
        metadata({ kind = 'registered', registration = registration(new), changed = false })
        assert.is_true(vim.wait(3000, function() return result ~= nil end))
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
        assert.is_true(journal.document_move); assert.is_false(journal.steps.document_moved)
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
        assert.is_false(journal.steps.document_moved); assert.is_false(journal.new_witness)
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
        local operation = assert(begin({ fs = fs }))
        write(new, 'parent\n'); assert.equals('pending', advance(operation).kind)
        assert.is_truthy(uv.fs_stat(root .. '/new.side')); operation.release()
        assert.equals('registered', assert(recover()).kind)
        assert.matches('../new.md', read(root .. '/new.side/child.md'), 1, true)
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
        vim.fn.mkdir(root .. '/new.side', 'p'); assert.is_nil(begin()); vim.fn.delete(root .. '/new.side', 'd')
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
end)
