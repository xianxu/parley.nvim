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

    it('rejects overlapping or non-snapshot replacements before they can shift protected bytes', function()
        assert.is_string(routing.validate_edits('alpha\n# Chat\nsecret', {
            { old_string = 'alpha', new_string = 'x' }, { old_string = 'pha', new_string = '' },
        }))
        assert.is_string(routing.validate_edits('original', { { old_string = 'created by a prior call', new_string = '' } }))
    end)
end)

-- Exercise production resolve, not only its YAML value parser: names and ATX
-- headings have their own edge scans. CPU time excludes suite queue waits.
describe('routing admission scan work', function()
    it('bounds heading and assigned-name scans at representative input sizes', function()
        for _, n in ipairs({ 5000, 10000, 20000 }) do
            local name = 'A' .. string.rep(' ', n) .. 'Z'
            local start = os.clock()
            local plain = assert(routing.resolve({ '# ' .. name, 'body' }))
            assert.equals('discussion', plain.mode_by_row[2])
            local assigned = assert(routing.resolve(doc('{chat: ["' .. name .. '"]}', { '# ' .. name, 'body' })))
            assert.equals('chat', assigned.mode_by_row[5])
            assert.same({}, assigned.warnings)
            assert.is_true(os.clock() - start < 1)
        end
    end)
    it('bounds closing-hash and parenthesized-suffix scans including malformed suffixes', function()
        local start = os.clock()
        local spaces = string.rep(' ', 20000)
        local plan = assert(routing.resolve(doc('{chat: [Ops]}', { '# Ops' .. spaces .. '###', 'body' })))
        assert.equals('chat', plan.mode_by_row[5])
        plan = assert(routing.resolve({ '# Ops' .. spaces .. 'Z###', 'body' }))
        assert.equals('discussion', plan.mode_by_row[2])
        assert.equals('ops', routing.normalize('Ops' .. spaces .. '(a (nested) annotation)'))
        local malformed = string.rep('(', 20000) .. 'unfinished'
        assert.equals(malformed, routing.normalize(malformed))
        assert.equals(string.rep('(', 19999), routing.normalize(string.rep('(', 20000) .. 'x)'))
        assert.is_true(os.clock() - start < 1)
    end)
    it('bounds fence recognition and rejected heading shapes', function()
        local start = os.clock()
        local spaces = string.rep(' ', 20000)
        local hashes = string.rep('#', 20000)
        local plan = assert(routing.resolve({
            spaces .. '# Ops', hashes, '````lua', '# Hidden',
            '````' .. spaces, '# Visible', '~~~' .. spaces, '# Hidden too', '~~~',
        }))
        assert.equals('discussion', plan.mode_by_row[9])
        assert.is_true(os.clock() - start < 1)
    end)
    it('preserves ATX and single trailing annotation semantics', function()
        assert.equals('ops (first)', routing.normalize(' OPS (first) (second) '))
        assert.equals('ops (unfinished', routing.normalize('Ops (unfinished'))
        local plan = assert(routing.resolve(doc('{chat: [Ops]}', {
            '#Ops', '    # Ops', '# Ops ###  ', 'body', '# Else###', 'other', '#', 'empty',
        })))
        assert.equals('discussion', plan.mode_by_row[4])
        assert.equals('discussion', plan.mode_by_row[5])
        assert.equals('chat', plan.mode_by_row[7])
        assert.equals('discussion', plan.mode_by_row[9])
        assert.equals('discussion', plan.mode_by_row[11])
    end)
end)
