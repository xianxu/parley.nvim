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
    it('leaves the destination to Couch when it is the authority (#359)', function()
        local o = observations(); o.destination_registered = 'authority'
        local projected = assert(plan.project(old, new, o))
        assert.equals('rename_metadata', projected.effects[#projected.effects].kind)
        o.destination_registered = 'maybe'
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
        assert.same({ state = 'conflict', action = 'forget', band = 'move not confirmed: the destination is registered'
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

describe('forward-only v2 move view', function()
    local projection = require('parley.document_move_plan')
    it('exposes only moving/wait, done/none and interrupted/reopen', function()
        for _, overdue in ipairs({ false, true }) do
            local view = projection.move_outcome({ forward_only = true, moved = true, overdue = overdue })
            assert.equals('moving', view.state); assert.equals('wait', view.action)
        end
        local done = projection.move_outcome({ forward_only = true, moved = true, result = { kind = 'registered' } })
        assert.equals('done', done.state); assert.equals('none', done.action)
        for _, result in ipairs({ { kind = 'unavailable', error = 'owner unavailable' },
            { kind = 'uncertain', code = 'target-conflict', error = 'destination occupied' },
            { kind = 'pending', error = 'parent bytes changed' } }) do
            local view = projection.move_outcome({ forward_only = true, moved = true, result = result })
            assert.equals('interrupted', view.state); assert.equals('reopen', view.action)
            assert.truthy(view.band:find('reopen', 1, true))
            assert.truthy(view.band:find(result.error, 1, true))
            assert.falsy(view.band:find('forget', 1, true))
        end
    end)
end)


describe('moving parent side references', function()
    local projection = require('parley.document_move_plan')
    local from, to = '/repo/design.md', '/else/spec.md'
    it('rewrites quoted index scalars and wrapped links, retaining exact unrelated bytes', function()
        local before = '---\r\ndiscussions: # queue\r\n  - doc: "design.side/01-q.md" # keep\r\n  - doc: \'design.side/02-q.md\'\r\nother: untouched\r\n---\r\n'
            .. '→ [a long\r\nlabel](design.side/01-q.md#why) [other](else.side/q.md)\r\n'
        local after = before:gsub('design%.side/', 'spec.side/')
        assert.equals(after, projection.rewrite_side_references(before, from, to))
        assert.equals(after, projection.rewrite_side_references(after, from, to))
    end)
    it('keeps code and unrelated frontmatter fields byte identical', function()
        local before = '---\ndoc: design.side/q.md\nnotes: |\n  discussions:\n    - doc: design.side/q.md\n---\n'
            .. '```md\n[q](design.side/q.md)\n```\n`[q](design.side/q.md)`\n\\[q](design.side/q.md)\n'
        assert.equals(before, projection.rewrite_side_references(before, from, to))
    end)
    it('preserves paragraph-wide inline code in both reference rewrites', function()
        for _, newline in ipairs({ '\n', '\r\n' }) do
            for width = 1, 4 do
                local tick = string.rep('`', width)
                for _, middle in ipairs({ '[example' .. newline .. 'label]',
                    'example' .. newline .. '[label]', '[label]' }) do
                    local before = 'text ' .. tick .. middle .. '(design.side/q.md)' .. newline .. 'end ' .. tick .. newline
                    assert.equals(before, projection.rewrite_side_references(before, from, to))
                    before = 'text ' .. tick .. middle .. '(../design.md)' .. newline .. 'end ' .. tick .. newline
                    assert.equals(before, projection.rewrite_parent(before,
                        { old = '/repo/design.side/q.md', new = '/else/spec.side/q.md' },
                        { old = from, new = to }))
                end
            end
        end
    end)
    it('uses exact backtick runs and does not mask the next paragraph', function()
        local before = '`` code ` [x](design.side/q.md)\n`` [live](design.side/q.md)\n'
            .. '` unmatched\n\n[next](design.side/q.md)\n'
        local after = '`` code ` [x](design.side/q.md)\n`` [live](spec.side/q.md)\n'
            .. '` unmatched\n\n[next](spec.side/q.md)\n'
        assert.equals(after, projection.rewrite_side_references(before, from, to))
    end)
    it('distinguishes escaped openers and literal code delimiters from longer runs', function()
        local before = 'text `` code ``` [x](design.side/q.md)\n`` [live](design.side/q.md)\n'
            .. '\\` [escaped](design.side/q.md)\n\n'
            .. 'text ` code \\` [after](design.side/q.md)\n'
        local after = 'text `` code ``` [x](design.side/q.md)\n`` [live](spec.side/q.md)\n'
            .. '\\` [escaped](spec.side/q.md)\n\n'
            .. 'text ` code \\` [after](spec.side/q.md)\n'
        assert.equals(after, projection.rewrite_side_references(before, from, to))
    end)
    it('shares scanner block boundaries for code preservation and live rewrites', function()
        local boundaries = { '', '  ', '# Heading', '###### Heading', '---', '- - -', '***',
            '* * *', '___', '_ _ _', '===', '=', '--', '> quoted', '  > quoted',
            '- item', '+ item', '* item', '1. item', '2) item', '```\n```', '~~~\n~~~' }
        for _, boundary in ipairs(boundaries) do
            for _, target in ipairs({ 'design.side/q.md', '../design.md' }) do
                local before = '` unmatched\n' .. boundary .. '\n[live](' .. target .. ') `\n'
                local after = before:gsub('design', 'spec')
                local actual
                if target:sub(1, 2) == '..' then
                    actual = projection.rewrite_parent(before,
                        { old = '/repo/design.side/q.md', new = '/else/spec.side/q.md' },
                        { old = from, new = to })
                else actual = projection.rewrite_side_references(before, from, to) end
                assert.equals(after, actual, boundary)
            end
        end
        for _, start in ipairs({ '- text ', '+ text ', '* text ', '1. text ', '2) text ', 'ordinary ' }) do
            for _, target in ipairs({ 'design.side/q.md', '../design.md' }) do
                local before = start .. '` code\n   [literal](' .. target .. ')` [live](' .. target .. ')\n'
                local after = start .. '` code\n   [literal](' .. target .. ')` [live](' .. target:gsub('design', 'spec') .. ')\n'
                local actual
                if target:sub(1, 2) == '..' then
                    actual = projection.rewrite_parent(before,
                        { old = '/repo/design.side/q.md', new = '/else/spec.side/q.md' },
                        { old = from, new = to })
                else actual = projection.rewrite_side_references(before, from, to) end
                assert.equals(after, actual, start)
            end
        end
    end)
    it('refuses ambiguous relevant scalar and link syntax without a partial result', function()
        for _, front in ipairs({
            'discussions: [{doc: design.side/q.md}]',
            'discussions: *queue',
            'discussions:\n  - doc: design.side/q.md\n    doc: other.md',
            'discussions:\n  - doc: "design.side/q.md" trailing',
            'discussions:\n  - doc: [design.side/q.md]',
            'discussions:\n  - doc: design.side/q.md\ndiscussions: []',
        }) do
            local value, err = projection.rewrite_side_references('---\n' .. front .. '\n---\n[q](design.side/q.md)\n', from, to)
            assert.is_nil(value, front); assert.is_string(err)
        end
        local value, err = projection.rewrite_side_references('[q](design.side/q.md "title")', from, to)
        assert.is_nil(value); assert.is_string(err)
    end)
    it('keeps same-name directory moves and extension-only names unchanged', function()
        local before = '---\ndiscussions:\n  - doc: design.side/q.md\n---\n[q](design.side/q.md)'
        assert.equals(before, projection.rewrite_side_references(before, from, '/else/design.md'))
        assert.equals(before, projection.rewrite_side_references(before, from, '/else/design.markdown'))
    end)
    it('preserves uniformly indented roots and generated quote/comment variants', function()
        for indent = 0, 3 do
            for _, quote in ipairs({ '', "'", '"' }) do
                for _, comment in ipairs({ '', ' # keep' }) do
                    local padding = string.rep(' ', indent)
                    local before = '---\n' .. padding .. 'collaboration-mode: discussion\n' .. padding
                        .. 'discussions:\n' .. padding .. '  - doc: ' .. quote .. 'design.side/q.md' .. quote
                        .. comment .. '\n---\n[q](design.side/q.md)\n'
                    assert.equals(before:gsub('design%.side', 'spec.side'),
                        projection.rewrite_side_references(before, from, to))
                end
            end
        end
    end)
    it('bounds malformed bracket scans through the complete parent rewrite', function()
        local bytes = string.rep('[', 20000) .. '\n'
        local started = os.clock()
        assert.equals(bytes, projection.rewrite_side_references(bytes, from, to))
        assert.is_true(os.clock() - started < 0.25, '20KB malformed labels must not stall the move')
    end)
    it('bounds malformed destination openers through both complete rewrites', function()
        local bytes = string.rep('](', 10000) .. '\n'
        local started = os.clock()
        assert.equals(bytes, projection.rewrite_side_references(bytes, from, to))
        assert.equals(bytes, projection.rewrite_parent(bytes,
            { old = '/repo/design.side/q.md', new = '/else/spec.side/q.md' },
            { old = from, new = to }))
        assert.is_true(os.clock() - started < 0.25, '20KB malformed destinations must not stall either rewrite')
    end)
    it('rewrites only paths resolving inside the moved side tree, including absolute and dot-relative links', function()
        local before = '[absolute](/repo/design.side/q.md#x) [dot](./design.side/q.md) [other](/other/design.side/q.md)'
        local expected = '[absolute](/else/spec.side/q.md#x) [dot](./spec.side/q.md) [other](/other/design.side/q.md)'
        assert.equals(expected, projection.rewrite_side_references(before, from, to))
    end)
    it('selects the first observed free orphan suffix and requires absent NEW at admission', function()
        local o = observations()
        o.target_side_exists = true
        o.new_absent_at_admission = true
        o.orphan_candidates = { true, false }
        local result = assert(projection.project(old, new, o))
        assert.equals('/repo/archive/renamed_2.side', result.orphan_destination)
        assert.same({ kind = 'move_orphan', old = '/repo/archive/renamed.side',
            new = '/repo/archive/renamed_2.side' }, result.effects[1])
        o.new_absent_at_admission = false
        assert.is_nil(projection.project(old, new, o))
        o.new_absent_at_admission = true; o.orphan_candidates = { true }
        assert.is_nil(projection.project(old, new, o))
        o.orphan_candidates = {}; for i = 1, 4097 do o.orphan_candidates[i] = true end
        assert.is_nil(projection.project(old, new, o))
    end)
    it('exposes the validated orphan suffix before NEW is written without authorizing effects', function()
        local o = observations()
        o.target_side_exists, o.new_absent_at_admission = true, true
        o.orphan_candidates, o.new_exists, o.new_written = { true, false }, false, false
        local result = assert(projection.project(old, new, o))
        assert.equals('/repo/archive/renamed_2.side', result.orphan_destination)
        assert.same({ { kind = 'wait_new_write', path = new } }, result.effects)
    end)
    it('refuses ambiguous index syntax even before the native NEW write', function()
        local o = observations(); o.new_written = false; o.new_exists = false
        o.parent_bytes = '---\ndiscussions: *unknown\n---\n[q](project.side/q.md)'
        local value, err = projection.project(old, new, o)
        assert.is_nil(value); assert.is_string(err)
    end)
    it('projects parent bytes independently of whether a source side folder exists', function()
        local o = observations(); o.entries = {}; o.side_exists = false
        o.parent_bytes = '[q](project.side/q.md)'
        local r = assert(projection.project(old, new, o))
        assert.same({ kind = 'rewrite_document', path = new, before = o.parent_bytes,
            after = '[q](renamed.side/q.md)' }, r.effects[1])
    end)
    it('refuses interfering declared roots before generating any move effect', function()
        for _, case in ipairs({
            { '/repo/parent.side/child.md', '/repo/parent.md', false },
            { '/repo/parent.side/child.md', '/repo/parent.md', true },
            { '/repo/source.md', '/repo/source.side/nested/next.md', true },
            { '/repo/parent_1.md', '/repo/parent.md', false, { false } },
            { '/repo/doc.side', '/repo/new.md', false },
            { '/repo/doc.md', '/repo/doc.side', false },
        }) do
            local o = observations(); o.entries = {}; o.side_exists = case[3]
            o.target_side_exists = case[4] ~= nil or case[1]:find('parent.side/', 1, true) ~= nil
            o.new_absent_at_admission, o.new_exists, o.new_written = true, false, false
            o.orphan_candidates = case[4] or { false }
            local value, err = plan.project(case[1], case[2], o)
            assert.is_nil(value, case[1] .. ' -> ' .. case[2]); assert.matches('move to another name first', err, 1, true)
        end
    end)
    it('shares one pure geometry predicate with canonical suffix and shared-root rules', function()
        assert.is_function(plan.validate_geometry)
        for _, case in ipairs({
            { '/repo/parent_1.md', '/repo/parent.md', '/repo/parent_1.side' },
            { '/repo/old.md', '/repo/new.md', '/else/foreign.side' },
            { '/repo/old.md', '/repo/new.md', '/repo/new_0.side' },
            { '/repo/old.md', '/repo/new.md', '/repo/new_4097.side' },
            { '/repo/old.md', '/repo/old.markdown', '/repo/old_1.side' },
        }) do
            assert.is_nil(plan.validate_geometry(unpack(case)))
        end
        for _, case in ipairs({
            { '/repo/old.md', '/repo/old.markdown' },
            { '/repo/old.md', '/repo/archive/new.md', '/repo/archive/new_1.side' },
            { '/repo/old.md', '/repo/old.sidecar/new.md' },
        }) do assert.is_true(plan.validate_geometry(unpack(case))) end
    end)

end)
