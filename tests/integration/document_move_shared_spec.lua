local fixtures = require('tests.helpers.review_move_fixtures')
local projection = require('parley.document_move_plan')
local fixtures_ok, exported_cases = pcall(fixtures.load)
local function copy(t)
    local out = {}; for k, v in pairs(t) do out[k] = v end; return out
end
-- Extend the pinned legacy fixtures locally: the package remains the sole producer
-- of exported bytes, while these variants qualify the monthly reader layout.
local function monthly_variant(base)
    local case = { name = base.name .. '-monthly-grandchild', old = base.old, new = base.new,
        before = copy(base.before), after = copy(base.after), monthly = true }
    local child = '2026-10/23-monthly.md'
    local grandchild = '2026-11/01-follow-up.md'
    for _, state in ipairs({ 'before', 'after' }) do
        local stem = state == 'before' and 'design' or 'spec'
        local side = stem .. '.side/'
        case[state][stem .. '.md'] = case[state][stem .. '.md']:gsub(
            'discussions:\n', 'discussions:\n  - doc: "' .. side .. child .. '" # monthly index\n', 1)
            .. '\n[monthly](' .. side .. child .. '#details)\n'
        case[state][side .. child] = '---\nparent: "../../' .. stem .. '.md" # actual root\n'
            .. 'opaque: {future: [keep, "design.side/raw"]}\ndiscussions:\n'
            .. '  - doc: "../' .. grandchild .. '" # same owning root\n---\n'
            .. '[root](../../' .. stem .. '.md#details)\n'
            .. '[child](../' .. grandchild .. '#answer)\n'
            .. '[flat](../01-why-per-file.md)\n'
        case[state][side .. grandchild] = '---\nparent: "../' .. child .. '" # actual side parent\n'
            .. 'opaque: [null, {future: "untouched"}]\n---\n'
            .. '[parent](../' .. child .. '#details)\n'
            .. '[root](../../' .. stem .. '.md#details)\n'
        case[state][side .. '2026-11/opaque.bin'] = 'opaque\0bytes\255\n'
    end
    if base.name == 'move-orphan' then
        case.before['spec.side/2026-09/older.md'] = '---\nfuture: {opaque: true}\n---\norphan\0bytes\n'
        case.after['spec_1.side/2026-09/older.md'] = case.before['spec.side/2026-09/older.md']
    end
    return case
end
local function qualification_cases()
    local cases = fixtures.load()
    local count = #cases
    for i = 1, count do cases[#cases + 1] = monthly_variant(cases[i]) end
    return cases
end
local qualification_ok, cases = pcall(qualification_cases)
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
    it('loads the exported move fixtures independently of other review examples', function()
        assert.is_true(fixtures_ok, tostring(exported_cases))
        assert.is_true(qualification_ok, tostring(cases))
        assert.is_true(#exported_cases > 0)
        for _, case in ipairs(exported_cases) do assert.matches('^move%-', case.name) end
    end)
    it('matches every exported after byte and path', function()
        for _, case in ipairs(qualification_cases()) do
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

    for _, case in ipairs(qualification_ok and cases or {}) do
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
            assert.equals(2, operation.journal.version)
            assert.same(operation.journal, vim.json.decode(read_bytes(operation.journal_path)))
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
            if case.monthly then
                local model = require('parley.side_tree_model')
                local side = tree .. '/spec.side/'
                local chain = model.chain(side .. '2026-11/01-follow-up.md', function(path)
                    return model.parse(vim.split(read_bytes(path), '\n', { plain = true }), vim.fs.dirname(path))
                end)
                assert.same({ new, side .. '2026-10/23-monthly.md', side .. '2026-11/01-follow-up.md' }, chain.paths)
                assert.is_nil(chain.marker)
            end
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
                if under(path, source_side) and not path:sub(#source_side + 2):find('/', 1, true)
                    and parent and parent:sub(1, 3) ~= '../' then
                    assert.equals(bytes, read_bytes(tree .. '/' .. target_side .. path:sub(#source_side + 1)))
                end
            end
        end)
    end
end)
