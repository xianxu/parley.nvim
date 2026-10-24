-- BR-1: retired/ignored values must not erase independent recognized evidence.
-- Expected notices follow landed ariadne 5a17f789... pkg/sidedoc/chat.go.
local value = require('parley.skills.review.collaboration_value')
local structure = require('parley.skills.review.chat_structure')
local policy = require('parley.skills.review.chat_policy')
local collaboration = require('parley.skills.review.collaboration')
local legacy_notice = 'collaboration-mode map is a legacy key; its chat sections are read as @@chat@@'

local function document(body)
    local lines = {'---'}
    for line in (body .. '\n'):gmatch('(.-)\n') do lines[#lines+1] = line end
    lines[#lines+1] = '---'
    local heading = #lines + 1
    lines[#lines+1] = '# Notes'
    lines[#lines+1] = '1. operator text'
    lines[#lines+1] = ''
    lines[#lines+1] = '🤖[tighten this]'
    return lines, heading
end
local function project(body)
    local lines, heading = document(body)
    local facts, err = structure.snapshot(lines)
    assert.is_nil(err)
    return policy.scan(lines, facts), lines, heading
end
local function assert_protected(body, notices, whole)
    local scan, lines, heading = project(body)
    assert.same({{heading=whole and 0 or heading, finish=#lines,
        source=whole and 'legacy-scalar' or 'legacy-map',legacy=true}}, scan.sections)
    assert.same(notices, scan.notices)
    local text = table.concat(lines, '\n')
    local input={review_asks={{line=#lines-1,col=0,raw='🤖[tighten this]',kind='command'}}}
    local err = collaboration.validate_edits(text,
        {{old_string='operator text',new_string='CHANGED',explain='must remain operator-owned'}}, input)
    assert.is_string(err, 'the actual local admission guard must preserve this item')
    assert.is_nil(collaboration.validate_edits(text,
        {{old_string='🤖[tighten this]',new_string='Done.',explain='ordinary command'}}, input))
end

local ignored_scalars = {'false','true','42','-7','null','~',"''",'discussion',''}
describe('independent legacy evidence preservation', function()
    for _, scalar in ipairs(ignored_scalars) do
        for _, form in ipairs({'flow','block'}) do
            it('preserves named chat beside default '..scalar..' in '..form..' form', function()
                local body = form=='flow' and ('collaboration-mode: {chat: [Notes], default: '..scalar..'}')
                    or ('collaboration-mode:\n  chat: [Notes]\n  default: '..scalar)
                local rendered = scalar=="''" and '' or scalar
                assert_protected(body, {legacy_notice,
                    'collaboration-mode map default: '..rendered..' is retired and ignored'})
            end)
            it('ignores unrelated '..scalar..' without losing named chat in '..form..' form', function()
                local body = form=='flow' and ('collaboration-mode: {chat: [Notes], discussion: '..scalar..'}')
                    or ('collaboration-mode:\n  chat: [Notes]\n  discussion: '..scalar)
                assert_protected(body, {legacy_notice})
            end)
        end
    end
    for _, form in ipairs({'flow','block'}) do
        it('does not let an empty ignored member erase whole-document chat in '..form..' form', function()
            local body = form=='flow' and 'collaboration-mode: {default: chat, discussion:}'
                or 'collaboration-mode:\n  default: chat\n  discussion:'
            assert_protected(body, {legacy_notice}, true)
        end)
        it('preserves whole-document chat beside an empty chat member in '..form..' form', function()
            local body = form=='flow' and 'collaboration-mode: {default: chat, chat:}'
                or 'collaboration-mode:\n  default: chat\n  chat:'
            assert_protected(body, {legacy_notice}, true)
        end)
        it('retains named chat beside sequence-valued default in '..form..' form', function()
            local body = form=='flow' and 'collaboration-mode: {chat: [Notes], default: [false, 42, null]}'
                or 'collaboration-mode:\n  chat: [Notes]\n  default:\n    - false\n    - 42\n    - null'
            assert_protected(body, {legacy_notice,'collaboration-mode map default:  is retired and ignored'})
        end)
        it('ignores mixed scalar lists under unrelated members in '..form..' form', function()
            local body = form=='flow' and 'collaboration-mode: {chat: [Notes], discussion: [false, 42, null]}'
                or 'collaboration-mode:\n  chat: [Notes]\n  discussion:\n    - false\n    - 42\n    - null'
            assert_protected(body, {legacy_notice})
        end)
        it('retains valid chat names while noticing unmatched implicit scalar names in '..form..' form', function()
            local body = form=='flow' and 'collaboration-mode: {chat: [Notes, false, 42, null, ""]}'
                or 'collaboration-mode:\n  chat:\n    - Notes\n    - false\n    - 42\n    - null\n    - ""'
            assert_protected(body, {legacy_notice,
                'collaboration-mode map name "false" matches no heading',
                'collaboration-mode map name "42" matches no heading',
                'collaboration-mode map name "null" matches no heading'})
        end)
    end
    for _, form in ipairs({'flow','block'}) do
        it('preserves a recognized default beside an ignored false member in '..form..' form', function()
            local body = form=='flow' and 'collaboration-mode: {discussion: false, default: chat}'
                or 'collaboration-mode:\n  discussion: false\n  default: chat'
            assert_protected(body, {legacy_notice}, true)
        end)
        for _, member in ipairs({'default','discussion'}) do
            for _, first in ipairs({true,false}) do
                it('refuses actual operator mutation with '..member..' false '..tostring(first)..' in '..form, function()
                    local chat, ignored = 'chat: [Notes]', member..': false'
                    local left, right = first and ignored or chat, first and chat or ignored
                    local body = form=='flow' and ('collaboration-mode: {'..left..', '..right..'}')
                        or ('collaboration-mode:\n  '..left..'\n  '..right)
                    local lines = document(body)
                    local err = collaboration.validate_edits(table.concat(lines,'\n'),
                        {{old_string='operator text',new_string='CHANGED',explain='unsafe operator mutation'}},
                        {review_asks={{line=#lines-1,col=0,raw='🤖[tighten this]',kind='command'}}})
                    assert.is_string(err)
                end)
            end
        end
    end
    it('preserves the older strict parse API for ignored implicit YAML values', function()
        for _, body in ipairs({'collaboration-mode: {chat: [Notes], default: false}',
            'collaboration-mode:\n  chat: [Notes]\n  discussion: false'}) do
            local parsed, err = value.parse(document(body))
            assert.is_nil(parsed)
            assert.is_string(err)
        end
    end)
end)

local unread_maps = {
    'collaboration-mode: {chat: [Notes], other: {nested: false}}',
    'collaboration-mode: {other: {nested: false}, chat: [Notes]}',
    'collaboration-mode:\n  chat: [Notes]\n  other:\n    nested: false',
    'collaboration-mode:\n  other:\n    nested: false\n  chat: [Notes]',
}
describe('unread declared legacy map safety', function()
    for index, body in ipairs(unread_maps) do
        it('carries typed unread-map evidence for unsupported node order '..index, function()
            local facts, err = structure.snapshot(document(body))
            assert.is_nil(err)
            assert.is_true(facts.unread_legacy_map)
            assert.is_truthy(facts.legacy_error)
            assert.same({'frontmatter could not be read, so any legacy mode keys in it were not read'},
                policy.scan(document(body), facts).notices)
        end)
        it('refuses actual local source mutation for unsupported node order '..index, function()
            local lines = document(body)
            local plan, err = collaboration.resolve(lines)
            assert.is_nil(plan)
            assert.matches('use Couch review',err,1,true)
            local input={review_asks={{line=#lines-1,col=0,raw='🤖[tighten this]',kind='command'}}}
            for _, old in ipairs({'operator text','🤖[tighten this]'}) do
                local denied=collaboration.validate_edits(table.concat(lines,'\n'),
                    {{old_string=old,new_string='CHANGED',explain='unsafe source mutation'}},input)
                assert.matches('use Couch review',denied,1,true)
            end
        end)
    end
    it('keeps ordinary body commands available without a declared collaboration map', function()
        for _, body in ipairs({'notes: "collaboration-mode: {chat: [Notes]}"',
            '...\npresentation: inline', '[unsupported root]',
            'collaboration-mode: discussion', 'collaboration-mode: false', 'collaboration-mode: [chat]',
            'collaboration-mode: *missing', 'collaboration-mode: !custom {chat: [Notes]}',
            'collaboration-mode: "{chat: [Notes]}"', 'collaboration-mode: "unterminated',
            'collaboration-mode:\n  # merely a comment: not a map\nnotes: "unterminated'}) do
            local lines=document(body)
            local facts=assert(structure.snapshot(lines))
            assert.is_not_true(facts.unread_legacy_map)
            assert.is_table(collaboration.resolve(lines))
            assert.is_nil(collaboration.validate_edits(table.concat(lines,'\n'),
                {{old_string='🤖[tighten this]',new_string='Done.',explain='ordinary command'}},
                {review_asks={{line=#lines-1,col=0,raw='🤖[tighten this]',kind='command'}}}))
        end
    end)
end)


-- The declaration witness must survive failures BEFORE the decoder sees values.
local early_failures = {
    {'flow root-value quote, chat first', 'collaboration-mode: {chat: [Notes], other: "unterminated}'},
    {'flow root-value quote, other first', 'collaboration-mode: {other: "unterminated, chat: [Notes]}'},
    {'block first-member quote', 'collaboration-mode:\n  other: "unterminated\n  chat: [Notes]'},
    {'block first-member quote after comment', 'collaboration-mode:\n  # merely a comment: not a field\n  other: "unterminated\n  chat: [Notes]'},
    {'block later-member quote', 'collaboration-mode:\n  chat: [Notes]\n  other: "unterminated'},
    {'flow delimiter balance', 'collaboration-mode: {chat: [Notes], other: [broken}'},
    {'duplicate outer key, map first', 'collaboration-mode: {chat: [Notes]}\ncollaboration-mode: discussion'},
    {'duplicate outer key, map last', 'collaboration-mode: discussion\ncollaboration-mode: {chat: [Notes]}'},
    {'duplicate map key', 'collaboration-mode: {chat: [Notes], default: false, default: chat}'},
}
describe('early declared-map witness preservation', function()
    for _, example in ipairs(early_failures) do
        it('refuses source mutation after '..example[1], function()
            local lines=document(example[2])
            local facts=assert(structure.snapshot(lines))
            assert.is_true(facts.unread_legacy_map)
            assert.is_truthy(facts.legacy_error)
            local plan,err=collaboration.resolve(lines)
            assert.is_nil(plan)
            assert.matches('use Couch review',err,1,true)
            assert.matches('use Couch review',collaboration.validate_edits(table.concat(lines,'\n'),
                {{old_string='operator text',new_string='CHANGED',explain='unsafe operator mutation'}},
                {review_asks={{line=#lines-1,col=0,raw='🤖[tighten this]',kind='command'}}}),1,true)
        end)
    end
end)


describe('unread fence declaration preflight', function()
    for _, fence in ipairs({'---\r', ' --- '}) do
        it('retains reachable map proof under '..vim.inspect(fence), function()
            local lines=document('collaboration-mode: {chat: [Notes]}')
            lines[1],lines[3]=fence,fence
            local facts=assert(structure.snapshot(lines))
            assert.is_true(facts.unread_legacy_map)
            assert.is_truthy(facts.legacy_error)
            local plan,err=collaboration.resolve(lines)
            assert.is_nil(plan)
            assert.matches('use Couch review',err,1,true)
            assert.matches('use Couch review',collaboration.validate_edits(table.concat(lines,'\n'),
                {{old_string='operator text',new_string='CHANGED',explain='unsafe mutation'}},
                {review_asks={{line=#lines-1,col=0,raw='🤖[tighten this]',kind='command'}}}),1,true)
        end)
        it('keeps no-declaration body command under '..vim.inspect(fence), function()
            local lines=document('presentation: inline')
            lines[1],lines[3]=fence,fence
            local facts=assert(structure.snapshot(lines))
            assert.is_not_true(facts.unread_legacy_map)
            assert.is_table(collaboration.resolve(lines))
            assert.is_nil(collaboration.validate_edits(table.concat(lines,'\n'),
                {{old_string='🤖[tighten this]',new_string='Done.',explain='ordinary command'}},
                {review_asks={{line=#lines-1,col=0,raw='🤖[tighten this]',kind='command'}}}))
        end)
    end
end)
