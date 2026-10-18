-- The tagged reducer snapshot is the v2 checkpoint authority. Creating the
-- initial prepared intent is separate from advancing/restoring that authority.
local arch = require('tests.arch.arch_helper')

local function source(path) return table.concat(vim.fn.readfile(path), '\n') end
local function outside_dispatcher(text)
    local first = assert(text:find('local function dispatch(', 1, true))
    local last = assert(text:find('\nfunction M.document_ready(', first, true))
    return text:sub(1, first - 1) .. text:sub(last)
end
local function forbidden(text)
    local outside = outside_dispatcher(text)
    return outside:find('model%.step%s*%(') ~= nil
        or outside:find('[%w_]+%.state%s*=') ~= nil
        or outside:find('[%w_]+%.state%s*,') ~= nil
end

describe('arch: one v2 document migration checkpoint owner (#373)', function()
    it('detects a second writer and a reducer call outside the dispatcher', function()
        local shell = 'local function dispatch()\nend\nfunction M.document_ready()\nend\n'
        assert.is_false(forbidden(shell))
        assert.is_true(forbidden(shell .. 'operation.state = next_state'))
        assert.is_true(forbidden(shell .. 'model.step(record, event)'))
    end)
    it('keeps transition calls and snapshot replacement in the dispatcher', function()
        local text = source('lua/parley/document_move.lua')
        -- Admission constructs, but never advances, the initial prepared state.
        local admission = 'journal.state = initial_state'
        local start = assert(text:find(admission, 1, true))
        text = text:sub(1, start - 1) .. text:sub(start):gsub('journal%.state = initial_state', 'admitted = initial_state', 1)
        -- The v1 structural validator receives a detached compatibility copy.
        text = text:gsub('shadow%.version, shadow%.state = 1, nil', 'compatibility_copy = nil', 1)
        assert.is_false(forbidden(text), 'a second v2 checkpoint owner bypasses dispatcher observations')
        for _, file in ipairs(arch.worktree_files({ 'lua/**/*.lua' })) do
            if file ~= 'lua/parley/document_move.lua' and file ~= 'lua/parley/document_move_state.lua' then
                assert.is_nil(source(file):match('require%s*%(["\']parley%.document_move_state["\']%s*%)'),
                    file .. ' must use the leased mover, not the reducer')
            end
        end
    end)
end)
