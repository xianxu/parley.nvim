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
    local calls, restore, buf, opened

    -- A chat loaded from disk with `text`, cursor on `row`; becomes current.
    local function open(text, row)
        seq = seq + 1
        local path = tmp_dir .. '/2026-03-01-undo-' .. seq .. '.md'
        vim.fn.writefile(text, path)
        vim.cmd('silent edit! ' .. vim.fn.fnameescape(path))
        local b = vim.api.nvim_get_current_buf()
        vim.api.nvim_win_set_cursor(0, { row or 5, 0 })
        F.setup(b)
        opened[#opened + 1] = b
        return b
    end

    before_each(function()
        calls, restore = Fixture.install(parley)
        opened = {}
        buf = open(ORIGINAL)
    end)
    after_each(function()
        for _, b in ipairs(opened) do
            if vim.api.nvim_buf_is_valid(b) then Respond.cancel_responses(b) end
        end
        restore()
        for _, b in ipairs(opened) do
            if vim.api.nvim_buf_is_valid(b) then vim.api.nvim_buf_delete(b, { force = true }) end
        end
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
    local function settle(session, b)
        wait_for(function() return Respond.response_snapshot(session).status == 'terminal' end)
        wait_for(function() return F.flush(b or buf) == 'idle' end)
    end
    local function finish(session, call, b)
        call.running = false; call.complete(call.id)
        settle(session, b)
    end
    -- The auto-save prep_md installs: a write bumps changedtick, no text.
    local function save() vim.api.nvim_buf_call(buf, function() vim.cmd('silent! write') end) end
    local function undo(b) vim.api.nvim_buf_call(b or buf, function() vim.cmd('silent undo') end) end

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
        -- Two questions from the start: no user edit sits between the answers.
        local two = { '# topic: Undo', '- file: undo.md', '---', '', '💬: first question', '',
            '💬: second question', '' }
        buf = open(two, 5)
        local session, call = submit()
        stream(call, { 'first answer' })
        finish(session, call)
        local rows = lines(buf)
        local second = 0
        for i, l in ipairs(rows) do if l == '💬: second question' then second = i end end
        vim.api.nvim_win_set_cursor(0, { second, 0 })
        session, call = submit()
        stream(call, { 'second answer' })
        finish(session, call)
        undo()
        assert.is_false(has(buf, 'second answer'), 'the second answer survived its undo')
        assert.is_true(has(buf, 'first answer'), 'one undo removed both answers')
        undo()
        assert.same(two, lines(buf))
    end)

    -- Regenerating clears the old answer, then writes the new one: two undo
    -- steps, so the first u shows the cleared state rather than an answer that
    -- looks unchanged (operator, 2026-09-28).
    it('undoes a regenerated answer in two steps: cleared, then the old answer', function()
        local answered = { '# topic: Undo', '- file: undo.md', '---', '', '💬: question', '',
            '🤖:[FixtureAnthropic]', 'old answer', '' }
        buf = open(answered, 5)
        local session, call = submit()
        stream(call, { 'new', ' answer' }, save)
        finish(session, call)
        assert.is_true(has(buf, 'new answer'))
        assert.is_false(has(buf, 'old answer'))
        undo()
        assert.is_false(has(buf, 'new answer'), 'the new answer survived its undo')
        assert.is_false(has(buf, 'old answer'), 'one undo went past the cleared state')
        assert.is_true(has(buf, '💬: question'))
        undo()
        assert.same(answered, lines(buf))
    end)

    it('keeps two chats streaming at once as one entry each', function()
        local first_buf = buf
        local session_a, call_a = submit()
        local other = open({ '# topic: Other', '- file: other.md', '---', '', '💬: other question', '' })
        local session_b, call_b = submit()
        for i, chunk in ipairs({ 'alpha', ' beta', ' gamma' }) do
            stream(call_a, { chunk }, save)
            stream(call_b, { ('%d'):format(i) })
            vim.api.nvim_buf_call(other, function() vim.cmd('silent! write') end)
        end
        finish(session_a, call_a, first_buf)
        finish(session_b, call_b, other)
        assert.is_true(has(first_buf, 'alpha beta gamma') and has(other, '123'))
        undo(first_buf)
        assert.same(ORIGINAL, lines(first_buf))
        assert.is_true(has(other, '123'), 'undo in one chat touched the other')
        undo(other)
        assert.same({ '# topic: Other', '- file: other.md', '---', '', '💬: other question', '' }, lines(other))
    end)

    -- A reload replaces the buffer's text from disk: it ends the answer's undo
    -- block (the editor re-attaches), but must not corrupt what undo can reach.
    it('leaves an undoable history when the chat reloads mid-stream', function()
        local session, call = submit()
        stream(call, { 'before', ' reload' })
        save()
        vim.api.nvim_buf_call(buf, function() vim.cmd('silent edit!') end)
        stream(call, { ' after' })
        call.running = false; call.complete(call.id)
        wait_for(function() return Respond.response_snapshot(session).status == 'terminal' end)
        for _ = 1, 10 do
            if vim.deep_equal(ORIGINAL, lines(buf)) then break end
            local ok, err = pcall(undo)
            assert.is_true(ok, tostring(err))
        end
        assert.same(ORIGINAL, lines(buf))
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
