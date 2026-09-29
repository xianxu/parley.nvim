-- #282: one answer is one undo entry. The document editor joins an answer's
-- writes into one native undo block while its receipt (epoch, generation,
-- grant, undo sequence + changedtick) still matches. These drive real answers
-- through chat_respond with the stateful fixture transport and count `u`.
--
-- The chat is loaded from disk: a set_lines fixture would share an undo block
-- with the answer, and one `u` would empty the buffer.
local tmp_dir = (os.getenv('TMPDIR') or '/tmp') .. '/claude/parley-test-answer-undo-' .. os.time()
local parley = require('parley')
parley.setup({
    chat_dir = tmp_dir, state_dir = tmp_dir .. '/state', default_agent = 'FixtureAnthropic',
    agents = {
        { name = 'Choose a model', disable = true },
        { name = 'FixtureAnthropic', provider = 'anthropic', model = { model = 'claude-sonnet-5' },
            system_prompt = 'You are a helpful assistant.', tools = { '@all' } },
    },
    providers = {}, api_keys = {},
})
vim.fn.mkdir(tmp_dir, 'p')
vim.api.nvim_create_autocmd('VimLeavePre', { callback = function() vim.fn.delete(tmp_dir, 'rf') end })
local Respond = require('parley.chat_respond')
local F = require('parley.tool_folds')
local Fixture = require('tests.helpers.respond_fixture')

local ORIGINAL = { '# topic: Undo', '- file: undo.md', '---', '', '💬: question', '' }
local seq = 0

local function wait_for(predicate) assert.is_true(vim.wait(10000, predicate, 1), 'did not settle') end
local function lines(buf) return vim.api.nvim_buf_get_lines(buf, 0, -1, false) end
local function has(buf, text)
    for _, l in ipairs(lines(buf)) do if l:find(text, 1, true) then return true end end
    return false
end

describe('one answer is one undo entry (#282)', function()
    local calls, restore, buf

    before_each(function()
        calls, restore = Fixture.install(parley)
        seq = seq + 1
        local path = tmp_dir .. '/2026-03-01-undo-' .. seq .. '.md'
        vim.fn.writefile(ORIGINAL, path)
        vim.cmd('silent edit! ' .. vim.fn.fnameescape(path))
        buf = vim.api.nvim_get_current_buf()
        vim.api.nvim_win_set_cursor(0, { 5, 0 })
        F.setup(buf)
    end)
    after_each(function()
        Respond.cancel_responses(buf); restore()
        if vim.api.nvim_buf_is_valid(buf) then vim.api.nvim_buf_delete(buf, { force = true }) end
    end)

    local function submit()
        local before = #calls
        local session = assert(Respond.respond({ range = 0 }))
        wait_for(function() return #calls > before end)
        return session, calls[#calls]
    end
    -- One turn per chunk, as a real transport delivers them.
    local function stream(call, chunks, between)
        for _, chunk in ipairs(chunks) do
            local query = parley.tasker.get_query(call.id); query.response = query.response .. chunk
            call.output(call.id, chunk)
            vim.wait(20, function() return false end)
            if between then between() end
        end
    end
    local function settle(session)
        wait_for(function() return Respond.response_snapshot(session).status == 'terminal' end)
        wait_for(function() return F.flush(buf) == 'idle' end)
    end
    local function finish(session, call)
        call.running = false; call.complete(call.id)
        settle(session)
    end
    -- The auto-save prep_md installs: a write bumps changedtick, no text.
    local function save() vim.api.nvim_buf_call(buf, function() vim.cmd('silent! write') end) end
    local function undo() vim.api.nvim_buf_call(buf, function() vim.cmd('silent undo') end) end

    it('undoes a chunked answer in one step even when it is saved between chunks', function()
        local session, call = submit()
        stream(call, { 'Hello', ' world', '\nsecond line', '\nthird' }, save)
        finish(session, call)
        assert.is_true(has(buf, 'Hello world') and has(buf, 'third'))
        undo()
        assert.same(ORIGINAL, lines(buf))
    end)

    it('undoes an answer with two tool rounds in one step', function()
        local path = tmp_dir .. '/undo-tool-' .. seq .. '.txt'
        vim.fn.writefile({ 'fixture content' }, path)
        local session = submit()
        for round = 1, 2 do
            local call = calls[round]
            local prose = 'Checking ' .. round .. '.'
            stream(call, { prose })
            parley.tasker.get_query(call.id).raw_response = Fixture.tool_use_sse('tool-undo-' .. round, path, prose)
            call.running = false; call.complete(call.id)
            wait_for(function() return #calls == round + 1 end)
        end
        stream(calls[3], { 'done' })
        finish(session, calls[3])
        assert.is_true(has(buf, '📎:') and has(buf, 'done'))
        undo()
        assert.same(ORIGINAL, lines(buf))
    end)

    it('keeps two answers as two undo entries', function()
        local session, call = submit()
        stream(call, { 'first answer' })
        finish(session, call)
        -- Ask a second question in the prompt the answer left.
        local rows = lines(buf)
        local prompt = #rows
        while prompt > 0 and not vim.startswith(rows[prompt], '💬:') do prompt = prompt - 1 end
        vim.api.nvim_buf_set_lines(buf, prompt - 1, prompt, false, { '💬: second question' })
        vim.api.nvim_win_set_cursor(0, { prompt, 0 })
        session, call = submit()
        stream(call, { 'second answer' })
        finish(session, call)
        undo()
        assert.is_false(has(buf, 'second answer'), 'the second answer survived its undo')
        assert.is_true(has(buf, 'first answer'), 'one undo removed both answers')
    end)

    it('keeps a user edit made mid-stream as its own entry', function()
        local session, call = submit()
        stream(call, { 'Hello' })
        -- The writer applies a chunk on a later turn: edit only once it landed.
        wait_for(function() return has(buf, 'Hello') end)
        vim.api.nvim_buf_set_lines(buf, 0, 1, false, { '# topic: Edited' })
        stream(call, { ' world' })
        finish(session, call)
        undo() -- the answer written after the edit
        assert.equals('# topic: Edited', lines(buf)[1])
        assert.is_false(has(buf, 'Hello world'))
        undo() -- the user's edit
        assert.equals('# topic: Undo', lines(buf)[1])
        assert.is_true(has(buf, 'Hello'))
        undo() -- the answer written before the edit
        assert.same(ORIGINAL, lines(buf))
    end)

    it('undoes a cancelled partial answer in one step', function()
        local session, call = submit()
        stream(call, { 'partial', ' answer' }, save)
        Respond.cancel_responses(buf)
        settle(session)
        assert.is_true(has(buf, 'partial answer'))
        undo()
        assert.same(ORIGINAL, lines(buf))
    end)

    it('undoes an answer the provider failed mid-stream in one step', function()
        local session, call = submit()
        stream(call, { 'before', ' the failure' }, save)
        call.running = false; call.failure(call.id, 'fixture transport failure')
        settle(session)
        assert.is_true(has(buf, 'before the failure'))
        undo()
        assert.same(ORIGINAL, lines(buf))
    end)

    it('undoes an answer given after a reload in one step', function()
        save()
        vim.api.nvim_buf_call(buf, function() vim.cmd('silent edit!') end)
        F.setup(buf)
        vim.api.nvim_win_set_cursor(0, { 5, 0 })
        local session, call = submit()
        stream(call, { 'after', ' reload' }, save)
        finish(session, call)
        undo()
        assert.same(ORIGINAL, lines(buf))
    end)
end)
