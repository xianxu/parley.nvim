local Document = require('parley.document')

describe('document repair scheduling', function()
    it('lets native timers run before a multi-slice repair completes', function()
        local buf = vim.api.nvim_create_buf(false, true)
        local lines = {'💬: question', '🤖: answer'}
        for i = 3, 500 do lines[i] = 'body ' .. i end
        vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
        local doc = Document.attach(buf)
        local complete, heartbeat, armed = false, false, false
        Document.subscribe(doc, function(event)
            if event.kind ~= 'repair' then return end
            if event.result.status == 'idle' then complete = true end
            if not armed then
                armed = true
                vim.defer_fn(function() heartbeat = true end, 1)
            end
        end)
        local ran = vim.wait(10000, function() return heartbeat end, 1)
        local finished_before_heartbeat = complete
        Document.detach(doc)
        vim.api.nvim_buf_delete(buf, {force = true})
        assert.is_true(ran)
        assert.is_false(finished_before_heartbeat, 'repair must yield to native timers between slices')
    end)
    it('releases scheduled repair timers on reload and detach', function()
        local fake = require('tests.helpers.fake_document_editor').new({'💬: q', 'body'})
        local original = vim.defer_fn
        local timers = {}
        vim.defer_fn = function(callback, delay)
            local timer = original(callback, delay)
            timers[#timers + 1] = timer
            return timer
        end
        local doc
        local ok, err = pcall(function()
            doc = Document.attach(99881, {driver = fake.driver})
            assert.equals(1, #timers)
            fake:reload({'💬: replacement', 'body'})
            assert.is_true(timers[1]:is_closing())
            assert.equals(2, #timers)
            Document.detach(doc)
            assert.is_true(timers[2]:is_closing())
        end)
        vim.defer_fn = original
        if doc then Document.detach(doc) end
        assert.is_true(ok, err)
    end)
end)
