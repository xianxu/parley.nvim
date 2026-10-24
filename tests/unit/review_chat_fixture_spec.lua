-- Conformance to the shipped v4 before-fixtures. The case Reply supplies the
-- expected structural outcome; side-document writes remain the Couch owner's job.
local structure = require('parley.skills.review.chat_structure')
local policy = require('parley.skills.review.chat_policy')
local export_path = assert(vim.api.nvim_get_runtime_file('lua/parley/skills/review/export.json', false)[1])
local root = vim.fn.fnamemodify(export_path, ':h')
local function read(path)
    local file = assert(io.open(path, 'rb'))
    local bytes = file:read('*a')
    file:close()
    return bytes
end
local manifest = vim.json.decode(read(export_path))
assert(manifest.schema == 'ariadne/universal-review-export' and manifest.version == 4)
local members = {}
for _, member in ipairs(manifest.members) do members[member.path] = member end
local function fixture(path, name)
    local member = assert(members[path], 'fixture must be exported: ' .. path)
    assert.equals('fixture', member.role)
    assert.equals(name, member.name)
    local bytes = read(root .. '/' .. path)
    assert.equals(member.bytes, #bytes)
    assert.equals(member.sha256, vim.fn.sha256(bytes))
    return bytes
end
local function load(name)
    local case_text = fixture('examples/' .. name .. '/case.md', name)
    local submitted = assert(case_text:match('\nsubmitted: ([^\r\n]+)'))
    local before = fixture('examples/' .. name .. '/before/' .. submitted, name)
    local lines = vim.split(before, '\n', {plain=true})
    if lines[#lines] == '' then table.remove(lines) end
    return lines, assert(case_text:match('\n## Reply\n(.*)'))
end
local cases = {
    ['chat-tag'] = {
        sections={{heading=4,finish=11,source='tag',legacy=false}}, tags={3}, misplaced={}, notices={},
        items={{line=5,finish=6,answered=true},{line=7,finish=7,answered=false},{line=8,finish=8,answered=false}},
    },
    ['chat-tag-misplaced'] = {sections={},tags={},misplaced={3},items={},notices={}},
    ['legacy-chat-scalar'] = {
        sections={{heading=0,finish=13,source='legacy-scalar',legacy=true}},tags={},misplaced={},
        items={{line=9,finish=9,answered=false},{line=13,finish=13,answered=false}},
        notices={'collaboration-mode: chat is a legacy key; read as @@chat@@ for the whole document'},
    },
    ['legacy-chat-map'] = {
        sections={{heading=9,finish=12,source='legacy-map',legacy=true}},tags={},misplaced={},
        items={{line=11,finish=11,answered=false}},
        notices={'collaboration-mode map is a legacy key; its chat sections are read as @@chat@@',
            'collaboration-mode map default: discussion is retired and ignored'},
    },
    ['legacy-chat-comment'] = {
        sections={{heading=9,finish=11,source='legacy-comment',legacy=true}},tags={},misplaced={},
        items={{line=11,finish=11,answered=false}},
        notices={'collaboration-mode: discussion is retired and ignored: one collaborative mode applies',
            'retired keys ignored: presentation-mode, processing-mode',
            '<!-- collaboration-mode: chat; processing-mode: copy-editing; presentation-mode: propose --> at line 10 is a legacy key; read as @@chat@@'},
    },
    ['legacy-keys-ignored'] = {
        sections={},tags={},misplaced={},items={},
        notices={'collaboration-mode: collaboration is retired and ignored: one collaborative mode applies',
            'retired keys ignored: presentation, presentation-mode, process-instruction, processing-instruction, processing-mode'},
    },
}
local function check(expected, scan, items, reply)
    assert.same(expected.sections, scan.sections)
    assert.same(expected.tags, scan.tags)
    assert.same(expected.misplaced, scan.misplaced)
    local extents = {}
    for _, item in ipairs(items) do extents[#extents+1]={line=item.line,finish=item.finish,answered=item.answered} end
    assert.same(expected.items, extents)
    local actual_notices, wanted_notices = vim.deepcopy(scan.notices), vim.deepcopy(expected.notices)
    table.sort(actual_notices); table.sort(wanted_notices)
    assert.same(wanted_notices, actual_notices)
    for _, notice in ipairs(expected.notices) do assert.is_truthy(reply:find(notice, 1, true)) end
end
local function project(name)
    local lines, reply = load(name)
    local facts, err = structure.snapshot(lines)
    assert.is_nil(err)
    local scan = policy.scan(lines, facts)
    return scan, policy.items(lines, scan), reply
end

describe('shipped chat fixture conformance', function()
    for _, name in ipairs({'chat-tag','chat-tag-misplaced','legacy-chat-scalar','legacy-chat-map','legacy-chat-comment','legacy-keys-ignored'}) do
        it(name .. ' has the expected sections, item extents and notices', function()
            check(cases[name], project(name))
        end)
    end
    it('detects an omitted tag or chat policy in the fixture projection', function()
        local scan, items, reply = project('chat-tag')
        local missing_tag = vim.deepcopy(scan)
        missing_tag.tags = {}
        assert.is_false(pcall(check, cases['chat-tag'], missing_tag, items, reply))
        local missing_policy = vim.deepcopy(scan)
        missing_policy.sections = {}
        assert.is_false(pcall(check, cases['chat-tag'], missing_policy, items, reply))
    end)
end)
