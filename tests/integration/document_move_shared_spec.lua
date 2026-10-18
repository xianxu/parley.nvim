local fixtures = require('tests.helpers.review_move_fixtures')
local projection = require('parley.document_move_plan')
local function copy(t)
    local out = {}; for k, v in pairs(t) do out[k] = v end; return out
end
local function under(path, root) return path:sub(1, #root + 1) == root .. '/' end
local function move_tree(tree, old, new)
    local moving = {}
    for path, bytes in pairs(tree) do
        if under(path, old) then moving[path] = bytes end
    end
    for path, bytes in pairs(moving) do
        tree[path] = nil; tree[new .. path:sub(#old + 1)] = bytes
    end
end
local function project_tree(case)
    local root, tree = '/shared/', copy(case.before)
    local old, new = root .. case.old, root .. case.new
    local source, target = projection.side_path(case.old), projection.side_path(case.new)
    local entries, source_exists, target_exists = {}, false, false
    for path, bytes in pairs(tree) do
        if under(path, source) then
            source_exists = true
            entries[#entries + 1] = { path = root .. path, resolved = root .. path, type = 'file', bytes = bytes }
        end
        if under(path, target) then target_exists = true end
    end
    local candidates = {}
    if target_exists then
        for n = 1, 4096 do
            local occupied = false
            local candidate = target:sub(1, -6) .. '_' .. n .. '.side'
            for path in pairs(tree) do if under(path, candidate) then occupied = true end end
            candidates[n] = occupied
            if not occupied then break end
        end
    end
    local plan = assert(projection.project(old, new, {
        id = 'fixture', old_exists = true, new_exists = true, new_written = true,
        destination_registered = false, new_absent_at_admission = true,
        side_exists = source_exists, target_side_exists = target_exists,
        entries = entries, parent_bytes = tree[case.old], orphan_candidates = candidates,
    }))
    tree[case.new], tree[case.old] = tree[case.old], nil
    for _, effect in ipairs(plan.effects) do
        if effect.kind == 'move_side' or effect.kind == 'move_orphan' then
            move_tree(tree, effect.old:sub(#root + 1), effect.new:sub(#root + 1))
        elseif effect.kind == 'rewrite_parent' or effect.kind == 'rewrite_document' then
            local path = effect.path:sub(#root + 1)
            assert.equals(effect.before, tree[path])
            tree[path] = effect.after
        else assert.equals('rename_metadata', effect.kind) end
    end
    return tree
end

describe('canonical exported move projections', function()
    it('matches every exported after byte and path', function()
        for _, case in ipairs(fixtures.load()) do
            assert.same(case.after, project_tree(case), case.name)
        end
    end)
end)

local arrival = require('tests.helpers.arrival')
local uv = vim.uv or vim.loop

local function read_bytes(path)
    local file = assert(io.open(path, 'rb'))
    local bytes = file:read('*a'); assert(file:close()); return bytes
end
local function write_bytes(path, bytes)
    vim.fn.mkdir(vim.fn.fnamemodify(path, ':h'), 'p')
    local file = assert(io.open(path, 'wb')); assert(file:write(bytes)); assert(file:close())
end
local function disk_tree(root)
    local result = {}
    local function visit(directory, prefix)
        local entries = assert(uv.fs_scandir(directory))
        while true do
            local name, kind = uv.fs_scandir_next(entries)
            if not name then break end
            local relative = prefix .. name
            if kind == 'directory' then visit(directory .. '/' .. name, relative .. '/')
            else
                assert.equals('file', kind, relative)
                result[relative] = read_bytes(directory .. '/' .. name)
            end
        end
    end
    visit(root, '')
    return result
end

describe('canonical exported moves through disk and the registry transport', function()
    local root, tree, client, saved, operations
    local environment = { 'PATH', 'FAKE_COUCH_REGISTRY', 'FAKE_COUCH_REGISTRY_MODE', 'FAKE_COUCH_STATUS',
        'FAKE_COUCH_REGISTRY_DELAY', 'FAKE_COUCH_REGISTRY_DELAY_OPS' }
    local function request(verb, args)
        local result
        client.request(verb, args, { path = args[1], generation = 1 }, function(value) result = value end)
        assert.is_true(vim.wait(arrival.MS, function() return result ~= nil end, 10), verb .. ' timed out')
        return result
    end
    before_each(function()
        root = vim.fn.tempname(); vim.fn.mkdir(root, 'p'); root = assert(uv.fs_realpath(root))
        tree = root .. '/tree'; vim.fn.mkdir(tree, 'p')
        operations, saved = {}, {}
        for _, key in ipairs(environment) do saved[key] = vim.env[key]; vim.env[key] = nil end
        require('tests.helpers.fake_couch').write(root, root .. '/sent', root .. '/argv')
        vim.env.PATH = root .. '/bin:' .. assert(saved.PATH)
        vim.env.FAKE_COUCH_REGISTRY = root .. '/registry.json'
        client = require('parley.document_registry')
    end)
    after_each(function()
        for _, operation in ipairs(operations or {}) do operation.release() end
        if client then client.shutdown() end
        -- Flush scheduled registry cancellation callbacks before restoring the environment.
        vim.wait(20, function() return false end, 5) -- drain: scheduled registry cancellations
        for _, key in ipairs(environment) do vim.env[key] = saved[key] end
        vim.fn.delete(root, 'rf')
    end)

    for _, case in ipairs(fixtures.load()) do
        it('matches the complete exported ' .. case.name .. ' result with stable ownership', function()
            for path, bytes in pairs(case.before) do write_bytes(tree .. '/' .. path, bytes) end
            local old, new = tree .. '/' .. case.old, tree .. '/' .. case.new
            local registered = request('register', { old, 'ops:0' })
            assert.equals('registered', registered.kind, registered.error)
            local original = registered.registration
            assert.equals(old, original.File)
            local mover = require('parley.document_move')
            -- No metadata override: advance uses document_registry's real subprocess transport.
            local operation, err = mover.begin('shared-move-fixture', original, new, {
                root = root .. '/state', move_document = true, destination_registered = false,
            })
            assert(operation, err and err.error)
            operations[#operations + 1] = operation
            local result
            mover.advance(operation, function(value) result = value end)
            assert.is_true(vim.wait(arrival.MS, function() return result ~= nil end, 10))
            assert.equals('registered', result.kind, result.error)
            assert.equals(original.ID, result.registration.ID)
            assert.equals(original.Owner, result.registration.Owner)
            assert.equals(original.RegisteredOwner, result.registration.RegisteredOwner)
            assert.equals(original.RegisteredAt, result.registration.RegisteredAt)
            assert.equals(new, result.registration.File)
            assert.equals('absent', request('lookup', { old }).kind)
            local binding = request('lookup', { new })
            assert.equals('registered', binding.kind, binding.error)
            assert.same(result.registration, binding.registration)
            assert.same(case.after, disk_tree(tree), case.name)
            assert.is_nil(uv.fs_lstat(operation.journal_path))
            local target_side = projection.side_path(case.new)
            local had_orphan = false
            for path in pairs(case.before) do if under(path, target_side) then had_orphan = true end end
            if had_orphan then
                -- Derive the expected suffix from the exported after tree rather than a case-name list.
                local orphan
                for path in pairs(case.after) do
                    local folder = path:match('^([^/]+%.side)/')
                    if folder and folder ~= target_side then
                        assert.is_true(not orphan or orphan == folder)
                        orphan = folder
                    end
                end
                assert.is_truthy(orphan)
                assert.equals(tree .. '/' .. orphan, result.orphan_destination)
                for path, bytes in pairs(case.before) do
                    if under(path, target_side) then
                        assert.equals(bytes, read_bytes(tree .. '/' .. orphan .. path:sub(#target_side + 1)))
                    end
                end
            else assert.is_nil(result.orphan_destination) end
            local source_side = projection.side_path(case.old)
            for path, bytes in pairs(case.before) do
                -- A side doc parented by another side doc has no root-relative parent rewrite.
                local parent = bytes:match('\nparent: ([^\n]+)\n')
                if under(path, source_side) and parent and parent:sub(1, 3) ~= '../' then
                    assert.equals(bytes, read_bytes(tree .. '/' .. target_side .. path:sub(#source_side + 1)))
                end
            end
        end)
    end
end)
