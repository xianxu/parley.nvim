-- Production response lifecycle with a stateful, manually driven transport.
local parley = require("parley")
local pending = require("parley.chat_pending")
local root = vim.fn.tempname() .. "-ownership"
vim.fn.mkdir(root, "p")
parley.setup({
    chat_dir = root, state_dir = root .. "/state", providers = {}, api_keys = {},
    default_agent = "OwnershipFixture",
    agents = {
        { name = "Choose a model", disable = true },
        { name = "OwnershipFixture", provider = "anthropic",
          model = { model = "fixture" }, system_prompt = "Fixture", tools = {} },
    },
})

local function text(buf)
    return table.concat(vim.api.nvim_buf_get_lines(buf, 0, -1, false), "\n")
end

local function settle(predicate)
    assert.is_true(vim.wait(1500, predicate, 5), "scheduled response did not settle")
end

describe("chat ownership containment", function()
    local old_query, old_stop, old_stop_owner, buffers, calls
    local sequence = 0

    before_each(function()
        buffers, calls = {}, {}
        old_query, old_stop, old_stop_owner = parley.dispatcher.query, parley.tasker.stop, parley.tasker.stop_owner
        parley.dispatcher.query = function(buf, _, _, handler, completion, _, _, _, _, _, opts)
            local id = "ownership-" .. tostring(#calls + 1)
            local call = { buf = buf, id = id, owner = opts and opts.generation_id or id,
                handler = handler, complete = completion, running = true }
            calls[#calls + 1] = call
            parley.tasker.set_query(id, { buf = buf, response = "Generated answer" })
        end
        parley.tasker.stop = function()
            for _, call in ipairs(calls) do call.running = false end
        end
        parley.tasker.stop_owner = function(owner)
            for _, call in ipairs(calls) do
                if call.owner == owner then call.running = false end
            end
        end
    end)

    after_each(function()
        pending.cancel_all("fixture cleanup")
        parley.dispatcher.query, parley.tasker.stop, parley.tasker.stop_owner = old_query, old_stop, old_stop_owner
        for _, buf in ipairs(buffers) do
            if vim.api.nvim_buf_is_valid(buf) then vim.api.nvim_buf_delete(buf, { force = true }) end
        end
    end)

    local function start()
        sequence = sequence + 1
        local file = root .. ("/2026-09-14.12-00-%02d.001_fixture.md"):format(sequence)
        vim.fn.writefile({ "# topic: Ownership fixture", "- file: fixture.md", "---", "", "💬: First question", "" }, file)
        vim.cmd("edit " .. vim.fn.fnameescape(file))
        local buf = vim.api.nvim_get_current_buf()
        buffers[#buffers + 1] = buf
        vim.api.nvim_win_set_cursor(0, { 5, 0 })
        parley.chat_respond({ range = 0 })
        settle(function() return calls[#calls] and calls[#calls].buf == buf end)
        local call = calls[#calls]
        call.handler(call.id, "Generated answer")
        settle(function() return text(buf):find("Generated answer", 1, true) ~= nil end)
        return buf, call
    end

    it("preserves a question typed ahead through completion without adding a duplicate prompt", function()
        local buf, call = start()
        local tail = { "", "💬: My next question", "still composing" }
        vim.api.nvim_buf_set_lines(buf, -1, -1, false, tail)
        call.complete(call.id)
        settle(function() return pending.identity(buf) == nil end)
        local result = text(buf)
        assert.is_truthy(result:find(table.concat(tail, "\n"), 1, true), result)
        local _, questions = result:gsub("💬:", "")
        assert.equals(2, questions, "completion must not add another prompt after typing ahead")
    end)

    it("preserves non-marker human text appended before completion", function()
        local buf, call = start()
        vim.api.nvim_buf_set_lines(buf, -1, -1, false, { "", "unfinished human text" })
        call.complete(call.id)
        settle(function() return pending.identity(buf) == nil end)
        assert.is_truthy(text(buf):find("unfinished human text", 1, true))
    end)

    it("a deleted answer's late chunk cancels its owner without stopping another chat", function()
        local first, a = start()
        local second, b = start()
        for row, line in ipairs(vim.api.nvim_buf_get_lines(first, 0, -1, false)) do
            if line:find("🤖:", 1, true) then
                vim.api.nvim_buf_set_lines(first, row - 1, row, false, {})
                break
            end
        end
        a.handler(a.id, "late")
        settle(function() return pending.identity(first) == nil end)
        assert.is_false(a.running, "deleted answer must cancel its transport owner")
        assert.is_true(b.running, "unrelated chat transport must remain running")
        b.handler(b.id, " survives")
        settle(function() return text(second):find(" survives", 1, true) ~= nil end)
    end)
end)
