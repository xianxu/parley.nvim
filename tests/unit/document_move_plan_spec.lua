local plan


local old, new = '/repo/project.md', '/repo/archive/renamed.md'
local children = { old = '/repo/project.side/deep/child.md', new = '/repo/archive/renamed.side/deep/child.md' }
local parents = { old = old, new = new }
local function observations()
    return { id = 'stable-7', old_exists = true, new_exists = true, new_written = true,
        destination_registered = false, side_exists = true, target_side_exists = false,
        entries = { { path = children.old, resolved = children.old, type = 'file',
            bytes = '---\nparent: ../../project.md\n---\n[parent](../../project.md#section)\n' } } }
end

describe('document move projection', function()
    before_each(function()
        local ok, module = pcall(require, 'parley.document_move_plan')
        assert.is_true(ok, tostring(module))
        plan = module
    end)
    it('orders contained side and backlink effects before the exact metadata tuple', function()
        local r = assert(plan.project(old, new, observations()))
        assert.equals('stable-7', r.id)
        assert.same({ old, new }, { r.old, r.new })
        assert.same({ 'move_side', 'rewrite_parent', 'rename_metadata' }, {
            r.effects[1].kind, r.effects[2].kind, r.effects[3].kind })
        assert.equals('/repo/project.side', r.effects[1].old)
        assert.equals('/repo/archive/renamed.side', r.effects[1].new)
        assert.equals(children.new, r.effects[2].path)
        assert.equals('---\nparent: ../../renamed.md\n---\n[parent](../../renamed.md#section)\n', r.effects[2].after)
        assert.same({ kind = 'rename_metadata', id = 'stable-7', old = old, new = new }, r.effects[3])
    end)
    it('waits for successful native write without deleting the old saveas copy', function()
        local o = observations(); o.new_written = false; o.new_exists = false
        assert.same({ { kind = 'wait_new_write', path = new } }, assert(plan.project(old, new, o)).effects)
        o.new_written = true
        assert.is_nil(plan.project(old, new, o))
    end)
    it('refuses occupied destinations and untrustworthy observations', function()
        for _, field in ipairs({ 'target_side_exists', 'destination_registered' }) do
            local o = observations(); o[field] = true
            assert.is_nil(plan.project(old, new, o), field)
        end
        for _, entry in ipairs({
            { path = '/outside/x.md', resolved = '/outside/x.md', type = 'file' },
            { path = children.old, resolved = '/outside/x.md', type = 'link' },
            { path = '/repo/project.side/../escape.md', resolved = '/repo/escape.md', type = 'file' },
            { path = children.old, resolved = '/outside/x.md', type = 'file' },
        }) do
            local o = observations(); o.entries = { entry }
            assert.is_nil(plan.project(old, new, o))
        end
        for _, path in ipairs({ 'relative.md', '/repo//x.md', '/repo/../x.md', '/repo/x.md\0bad' }) do
            assert.is_nil(plan.project(path, new, observations()))
        end
        local o = observations(); o.entries[2] = o.entries[1]
        assert.is_nil(plan.project(old, new, o))
        o = observations(); o.entries[3] = o.entries[1]; o.entries[1] = nil
        assert.is_nil(plan.project(old, new, o))
    end)
    it('bounds entry and Markdown workloads', function()
        local o = observations(); o.entries = {}
        for i = 1, 513 do
            local path = '/repo/project.side/' .. i .. '.md'
            o.entries[i] = { path = path, resolved = path, type = 'file', bytes = '' }
        end
        assert.is_nil(plan.project(old, new, o))
    end)
end)

describe('parent backlink rewriting', function()
    before_each(function()
        local ok, module = pcall(require, 'parley.document_move_plan')
        assert.is_true(ok, tostring(module))
        plan = module
    end)
    it('preserves quote styles, comments, fragments, CRLF and unrelated bytes', function()
        for _, value in ipairs({ '../../project.md#intro', '"../../project.md#intro"', "'../../project.md#intro'" }) do
            local input = '---\r\nparent: ' .. value .. ' # comment\r\nother: untouched\r\n---\r\n'
                .. '[up](../../project.md#body) [other](else.md) raw ../../project.md\r\n'
            local expected = input:gsub('parent: (.-)project%.md', 'parent: %1renamed.md')
                :gsub('%[up%]%(%.%./%.%./project%.md', '[up](../../renamed.md')
            local result = assert(plan.rewrite_parent(input, children, parents))
            assert.equals(expected, result)
            assert.equals(result, plan.rewrite_parent(result, children, parents))
        end
    end)
    it('uses moved-child-relative paths, preserving absent and unrelated parents', function()
        local child = { old = '/repo/project.side/child.md', new = '/else/new.side/child.md' }
        local parent = { old = old, new = '/else/new.md' }
        assert.equals('[up](../new.md#x)', plan.rewrite_parent('[up](../project.md#x)', child, parent))
        assert.equals('---\nother: x\n---\nnone', plan.rewrite_parent('---\nother: x\n---\nnone', child, parent))
        assert.equals('---\nparent: elsewhere.md\n---', plan.rewrite_parent('---\nparent: elsewhere.md\n---', child, parent))
    end)
    it('refuses malformed or ambiguous parent data rather than partially rewriting', function()
        for _, input in ipairs({
            '---\nparent: "../../project.md\n---',
            '---\nparent: ../../project.md\nparent: other.md\n---',
            '---\nparent: ../../project.md',
            '---\nparent: [../../project.md]\n---',
            '---\nparent: "../../project.md" trailing\n---',
            '[parent](../../project.md',
            '[parent](../../project.md "title")',
        }) do
            local result, err = plan.rewrite_parent(input, children, parents)
            assert.is_nil(result, input); assert.is_string(err)
        end
    end)
    it('leaves code, escaped links and unrelated text byte-identical', function()
        local bytes = '```md\n[parent](../../project.md)\n```\n`[parent](../../project.md)`\n\\[parent](../../project.md)\nordinary [other](else.md)\n'
        assert.equals(bytes, plan.rewrite_parent(bytes, children, parents))
    end)
end)
