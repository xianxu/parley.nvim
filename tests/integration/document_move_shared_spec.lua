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
