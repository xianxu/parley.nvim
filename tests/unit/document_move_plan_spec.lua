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
    it('shares Markdown filename classification and derives side stems without damaging dotfiles', function()
        for _, extension in ipairs({ '.md', '.markdown', '.MD', '.mdown', '.mkd', '.mkdn' }) do
            assert.is_true(plan.is_markdown_path('/repo/file' .. extension))
            assert.equals('/repo/file.side', plan.side_path('/repo/file' .. extension))
        end
        assert.is_false(plan.is_markdown_path('/repo/file'))
        assert.is_false(plan.is_markdown_path('/repo/file.txt'))
        assert.equals('/repo/file.side', plan.side_path('/repo/file'))
        assert.equals('/repo/.hidden.side', plan.side_path('/repo/.hidden'))
        assert.equals('/repo.dir/file.part.side', plan.side_path('/repo.dir/file.part.markdown'))
    end)
    for _, extension in ipairs({ '.markdown', '.MD', '.mdown', '' }) do
        it('projects registered parent and supported child filenames for ' .. (extension ~= '' and extension or 'extensionless'), function()
            local old_parent, new_parent = '/repo/old' .. extension, '/repo/new' .. extension
            local o = observations(); o.entries = {}
            for _, child_extension in ipairs({ '.markdown', '.MD', '.mdown' }) do
                local path = '/repo/old.side/child' .. child_extension
                o.entries[#o.entries + 1] = { path = path, resolved = path, type = 'file',
                    bytes = '---\nparent: ../old' .. extension .. '\n---\n[up](../old' .. extension .. '#anchor)\n' }
            end
            local result = assert(plan.project(old_parent, new_parent, o))
            assert.equals('/repo/old.side', result.effects[1].old)
            assert.equals('/repo/new.side', result.effects[1].new)
            assert.equals(5, #result.effects)
            for index = 2, 4 do
                assert.equals('rewrite_parent', result.effects[index].kind)
                assert.truthy(result.effects[index].after:find('../new' .. extension .. '#anchor', 1, true))
            end
        end)
    end
    it('rewrites extension-only rename backlinks in the same side directory without moving it', function()
        local o = observations(); o.target_side_exists = true
        local path = '/repo/project.side/child.MD'
        o.entries = { { path = path, resolved = path, type = 'file', bytes = '[up](../project.md#anchor)' } }
        local result = assert(plan.project('/repo/project.md', '/repo/project.markdown', o))
        assert.equals(2, #result.effects)
        assert.same({ kind = 'rewrite_parent', path = path, before = '[up](../project.md#anchor)',
            after = '[up](../project.markdown#anchor)' }, result.effects[1])
        assert.equals('rename_metadata', result.effects[2].kind)
        assert.equals('stable-7', result.effects[2].id)
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
    it('keeps tilde blocks closed only by matching fence kind and sufficient width', function()
        local input = '  ~~~~md\n[inside](../../project.md)\n```\n~~~\n'
            .. '[still inside](../../project.md)\n  ~~~~\n[outside](../../project.md#x)\n'
        local expected = input:gsub('%[outside%]%(%.%./%.%./project%.md', '[outside](../../renamed.md')
        assert.equals(expected, plan.rewrite_parent(input, children, parents))
    end)
    it('leaves code, escaped links and unrelated text byte-identical', function()
        local bytes = '```md\n[parent](../../project.md)\n```\n`[parent](../../project.md)`\n\\[parent](../../project.md)\nordinary [other](else.md)\n'
        assert.equals(bytes, plan.rewrite_parent(bytes, children, parents))
    end)
end)

-- #359: the move needs no Couch round trip except an overwrite of an existing
-- file. One decision from what parley already knows (rows 1-4, 8-9 of the
-- plan's state table), and one projection of the outcome (rows 1, 5-7).
describe('move_preflight (#359)', function()
    local plan = require('parley.document_move_plan')
    local registered = { ID = 'id-1', File = '/repo/a.md', Owner = 'parley.nvim:4' }

    it('proceeds at once for a registered document (row 1)', function()
        assert.same({ proceed = true }, plan.move_preflight({ identity = registered, new_exists = false }))
    end)
    it('proceeds without asking for a plain move onto an existing file without overwrite (begin decides)', function()
        assert.same({ proceed = true }, plan.move_preflight({ identity = registered, new_exists = true }))
    end)
    it('renames a positively plain document plainly (row 2)', function()
        assert.same({ plain = true }, plan.move_preflight({ identity = 'plain', new_exists = true, overwrite = true }))
    end)
    it('refuses at once, nothing moved, and starts the lookup when the identity is unknown (row 3)', function()
        assert.same({ refuse = 'identity', lookup = true, message = plan.MOVE_TEXT.identity },
            plan.move_preflight({ identity = 'unknown' }))
    end)
    it('registers a legacy session file first, refusing this move (row 4)', function()
        assert.same({ refuse = 'legacy', register = true, message = plan.MOVE_TEXT.legacy },
            plan.move_preflight({ identity = 'plain', legacy = 'tl' }))
        assert.same({ refuse = 'legacy', register = true, message = plan.MOVE_TEXT.legacy },
            plan.move_preflight({ identity = 'unknown', legacy = 'tl' }))
    end)
    it('asks Couch inline only for an overwrite of an existing file (rows 8-9)', function()
        assert.same({ wait_destination = true },
            plan.move_preflight({ identity = registered, new_exists = true, overwrite = true }))
    end)
    it('words the refusals as the table does', function()
        assert.equals("move not confirmed: Couch hasn't confirmed this document yet; nothing moved. Run the move again",
            plan.MOVE_TEXT.identity)
        assert.equals('move not confirmed: registering this document first; nothing moved. Run the move again',
            plan.MOVE_TEXT.legacy)
    end)
end)

describe('move_outcome (#359)', function()
    local plan = require('parley.document_move_plan')
    local new_path = '/repo/archive/b.md'

    it('is confirming while the metadata rename is out (row 1)', function()
        assert.same({ state = 'confirming', band = 'moving: confirming with Couch', action = 'none' },
            plan.move_outcome({ moved = true, new_path = new_path }))
    end)
    it('finishes in the background past the deadline, saving still works (row 5)', function()
        assert.same({ state = 'background', band = 'move not confirmed: finishing in the background',
            action = 'none', warning = true }, plan.move_outcome({ moved = true, overdue = true, new_path = new_path }))
    end)
    it('names the pasteable forget command for a stale registration at NEW (row 6)', function()
        assert.same({ state = 'conflict', action = 'forget', band = 'move not confirmed: /repo/archive/b.md is registered'
            .. ' to another document. Run: couch --session-sync forget /repo/archive/b.md, then reopen' },
            plan.move_outcome({ moved = true, new_path = new_path,
                result = { kind = 'unavailable', code = 'target-conflict', error = 'destination registered' } }))
    end)
    it('quotes a NEW path the shell would split, so the command pastes as is', function()
        local outcome = plan.move_outcome({ moved = true, new_path = "/repo/my notes/it's.md",
            result = { kind = 'unavailable', code = 'target-conflict' } })
        assert.matches([[Run: couch %-%-session%-sync forget '/repo/my notes/it'\''s%.md', then reopen$]], outcome.band)
    end)
    it('asks for a reopen when the reply was lost or uncertain (row 7)', function()
        local pending = { state = 'pending', band = 'move pending: reopen to recover', action = 'reopen' }
        assert.same(pending, plan.move_outcome({ moved = true, new_path = new_path, result = { kind = 'uncertain' } }))
        assert.same(pending, plan.move_outcome({ moved = true, new_path = new_path,
            result = { kind = 'unavailable', error = 'timed out' } }))
        assert.same(pending, plan.move_outcome({ moved = false, new_path = new_path }))
    end)
    it('clears when Couch confirmed the rename', function()
        assert.same({ state = 'done', band = '', action = 'none' },
            plan.move_outcome({ moved = true, new_path = new_path, result = { kind = 'registered' } }))
    end)
end)
