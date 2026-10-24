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
