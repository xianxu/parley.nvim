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

-- #290: the writer's fold ranges, from a receipt and each row's lexed kind.
describe("tool_folds.written_ranges", function()
    local F = require("parley.tool_folds")
    local function kinds(list) return function(row) return list[row + 1] end end
    local function receipt(kind, first_row, first_col, tip_row)
        return { kind = kind, first_row = first_row, first_col = first_col, tip = { row = tip_row } }
    end

    it("folds a block that starts its own row, marker through its last non-blank row", function()
        local rows = kinds({ "tool_result", "fence", "text", "fence", "blank", "blank" })
        assert.same({ { 0, 3 } }, (F.written_ranges(receipt("append", 0, 0, 5), -1, rows)))
    end)
    it("skips the prose row a round's first call continues (close review BR-1)", function()
        local rows = kinds({ "text", "blank", "tool_use", "fence", "text", "fence", "blank", "blank" })
        assert.same({ { 2, 5 } }, (F.written_ranges(receipt("append", 0, 13, 7), -1, rows)))
    end)
    it("folds nothing when the first byte's column is unknown", function()
        local rows = kinds({ "tool_use", "fence", "text", "fence", "blank" })
        assert.same({}, (F.written_ranges(receipt("append", 0, nil, 4), -1, rows)))
    end)
    it("folds nothing for an appended row that is not a tool marker", function()
        assert.same({}, (F.written_ranges(receipt("append", 0, 0, 1), -1, kinds({ "text", "blank" }))))
    end)
    it("rechecks a continued summary row, which completes a split prefix", function()
        local ranges, seen = F.written_ranges(receipt("output", 3, 2, 3), -1,
            kinds({ "text", "text", "text", "summary" }))
        assert.same({ { 3, 3 } }, ranges); assert.equals(3, seen)
    end)
    it("folds only summary rows at or after the high-water row", function()
        local rows = kinds({ "summary", "text", "summary" })
        local ranges, seen = F.written_ranges(receipt("output", 0, 0, 2), 1, rows)
        assert.same({ { 2, 2 } }, ranges); assert.equals(2, seen)
    end)
end)
