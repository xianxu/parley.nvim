local exchange_model = require("parley.exchange_model")
local projection = require("parley.fold_projection")

describe("tool_folds semantic policy", function()
    it("folds exactly auxiliary answer entities", function()
        local model = exchange_model.new(0)
        model:add_exchange(1)
        for _, kind in ipairs({ "agent_header", "thinking", "summary", "tool_use", "tool_result", "text" }) do
            model:add_block(1, kind, 1)
        end
        local kinds = {}
        for _, range in ipairs(projection.desired_folds(model, 1)) do kinds[#kinds + 1] = range.kind end
        assert.same({ "thinking", "summary", "tool_use", "tool_result" }, kinds)
    end)
end)


describe("tool_folds work accounting", function()
    it("counts outer groups and native commands in the real inventory and reconcile", function()
        local buf = vim.api.nvim_create_buf(false, true)
        local previous = vim.api.nvim_get_current_buf()
        vim.api.nvim_set_current_buf(buf)
        vim.api.nvim_buf_set_lines(buf, 0, -1, false, { "💬: q", "🤖: a", "a", "b", "c", "d", "e", "f" })
        local document = require("parley.document").attach(buf, { schedule = false })
        assert.equals("idle", require("parley.document").drain(document).status)
        vim.wo.foldmethod = "manual"
        vim.cmd("3,5fold")
        vim.cmd("3,4fold")
        vim.cmd("7,8fold")
        local reader = require("parley.line_reader")
        local counter = require("tests.perf.chat_typing").new_counter()
        local token = reader.set_observer(buf, function(e) counter:observe(e) end)
        require("parley.tool_folds").setup(buf)
        assert.equals("idle", require("parley.tool_folds").flush(buf))
        local work = counter:snapshot()
        reader.clear_observer(buf, token)
        vim.api.nvim_set_current_buf(previous)
        vim.api.nvim_buf_delete(buf, { force = true })
        -- #264: two outer groups (the nested 3,4 counts inside 3,5), each
        -- inventoried once and removed once by the diff reconcile.
        assert.equals(4, work.fold_groups_visited)
        -- Inventory: a zj before each group plus five commands per group (count,
        -- zC, zo, zj, restore); reconcile: one zD per removed group.
        assert.equals(14, work.native_fold_ops)
    end)
end)
