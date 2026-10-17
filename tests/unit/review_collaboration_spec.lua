local routing = require('parley.skills.review.collaboration')
local function doc(value, body)
    local lines = { '---', 'collaboration-mode: ' .. value, '---' }
    for _, line in ipairs(body) do lines[#lines + 1] = line end
    return lines
end

describe('local collaboration routing', function()
    it('defaults ordinary questions to editable discussion', function()
        local plan = assert(routing.resolve({ 'why 🤖[why?]' }))
        assert.equals('discussion', plan.mode_by_row[1])
        assert.is_true(plan.editable)
        assert.is_true(plan.discussion)
        assert.same({}, plan.chat)
    end)

    it('resolves normalized names, repeated headings, levels six and nearest inheritance', function()
        local plan = assert(routing.resolve(doc('{chat: ["  OPS (open) "], collaboration: ["Detail"]}', {
            'preamble', '# Ops', 'a', '#### Child', 'b', '###### Detail', 'c',
            '#### Other', 'd', '# Else', 'e', '## OPS (again)', 'f',
        })))
        assert.equals('discussion', plan.mode_by_row[4])
        assert.equals('chat', plan.mode_by_row[5])
        assert.equals('chat', plan.mode_by_row[8])
        assert.equals('collaboration', plan.mode_by_row[9])
        assert.equals('collaboration', plan.mode_by_row[10])
        assert.equals('chat', plan.mode_by_row[12])
        assert.equals('discussion', plan.mode_by_row[14])
        assert.equals('chat', plan.mode_by_row[16])
    end)

    it('ignores fenced headings with matching delimiter and length', function()
        local plan = assert(routing.resolve(doc('{chat: ["Hidden"]}', {
            '````lua', '```', '# Hidden', '````', '~~~', '# Hidden', '~~~',
            '####### Hidden', '# Open',
        })))
        assert.same({}, plan.chat)
        assert.equals(1, #plan.warnings)
        assert.equals('discussion', plan.mode_by_row[12])
    end)

    it('rejects unknown modes and normalized conflicts even for dangling names', function()
        for _, value in ipairs({ 'unknown', '{default: bad}', '{bad: [Ops]}',
                '{chat: ["NOTES (open)"], collaboration: [notes]}' }) do
            local plan, err = routing.resolve(doc(value, { '# Else' }))
            assert.is_nil(plan)
            assert.is_string(err)
        end
    end)

    it('identifies all-chat documents and protects frontmatter and exact chat spans', function()
        local lines = doc('{chat: [Ops]}', { '# Notes', 'alpha', '# Ops', 'secret 🤖[chat]', '# Other', 'beta' })
        local plan = assert(routing.resolve(lines))
        assert.same({ 'Ops' }, plan.chat)
        assert.is_nil(routing.validate_edits(table.concat(lines, '\n'), { { old_string = 'alpha', new_string = 'ALPHA' } }))
        for _, old in ipairs({ 'secret', 'alpha\n# Ops', 'alpha\n', 'collaboration-mode:' }) do
            assert.is_string(routing.validate_edits(table.concat(lines, '\n'), { { old_string = old, new_string = 'changed' } }))
        end
        plan = assert(routing.resolve(doc('chat', { '', '# Only', 'item' })))
        assert.is_false(plan.editable)
        assert.is_false(plan.discussion)
        assert.is_true(#plan.chat > 0)
    end)
end)
