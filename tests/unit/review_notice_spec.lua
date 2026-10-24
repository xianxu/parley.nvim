local function notice()
    local ok, value = pcall(require, "parley.review_notice")
    assert.is_true(ok, "the stateless review notice helper must exist")
    assert.is_function(value.show)
    return value
end

describe("review notice history and bounded display", function()
    local saved, notifications
    before_each(function()
        saved = { notify = vim.notify, columns = vim.o.columns, exec = vim.api.nvim_exec2 }
        notifications = {}
        vim.notify = function(message, level) notifications[#notifications + 1] = { message = message, level = level } end
        vim.o.columns = 80
        vim.cmd("messages clear")
    end)
    after_each(function()
        vim.notify, vim.api.nvim_exec2 = saved.notify, saved.exec
        vim.o.columns = saved.columns
    end)

    it("retains exact Unicode, newlines, quotes and pipes as data in message history", function()
        local messages = { "notice 界 é\n'quoted' \"double\" | let g:parley_notice_injected = 1",
            "second exact notice" }
        notice().show(messages, "review: legacy keys ignored", vim.log.levels.WARN)
        local history = vim.fn.execute("messages")
        local first = assert(history:find(messages[1], 1, true))
        local second = assert(history:find(messages[2], 1, true))
        assert.is_true(first < second)
        assert.is_nil(vim.g.parley_notice_injected)
        assert.same({ { message = "review: legacy keys ignored :messages", level = vim.log.levels.WARN } }, notifications)
    end)

    it("reserves the history hint while truncating by shared display units", function()
        local text = require("parley.display_text")
        for _, columns in ipairs({ 80, 40, 32 }) do
            vim.o.columns = columns
            notifications = {}
            notice().show({ "the full notice stays intact" }, "review: " .. string.rep("界é", 20))
            assert.equals(1, #notifications)
            local displayed = notifications[1].message
            assert.is_true(text.width(displayed) <= math.min(48, columns - 16), displayed)
            assert.truthy(displayed:find("...", 1, true))
            assert.truthy(displayed:find(":messages", 1, true))
            assert.is_nil(displayed:find("�", 1, true))
        end
    end)

    it("normalizes short-summary whitespace without changing the full source", function()
        local full = "source\nkeeps\r\ntabs\tand spaces"
        notice().show({ full }, "review:\n questions\tdeferred")
        assert.equals("review: questions deferred :messages", notifications[1].message)
        assert.equals(vim.log.levels.INFO, notifications[1].level)
        assert.truthy(vim.fn.execute("messages"):find(full, 1, true))
    end)

    it("propagates capture failure before publishing a misleading recovery hint", function()
        local helper = notice()
        vim.api.nvim_exec2 = function() error("capture unavailable") end
        local ok, err = pcall(helper.show, { "preserve this full message" }, "review: deferred")
        assert.is_false(ok)
        assert.truthy(tostring(err):find("capture unavailable", 1, true))
        assert.same({}, notifications)
    end)
end)
