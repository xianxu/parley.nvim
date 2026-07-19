local exchange_model = require("parley.exchange_model")

describe("fold_projection", function()
    it("projects only positive semantic fold blocks in block order", function()
        local model = exchange_model.new(4)
        model:add_exchange(2)
        model:add_block(1, "agent_header", 1)
        model:add_block(1, "thinking", 2)
        model:add_block(1, "text", 3)
        model:add_block(1, "summary", 1)
        model:add_block(1, "tool_use", 4)
        model:add_block(1, "tool_result", 2)
        model:add_block(1, "thinking", 0)

        model:add_exchange(1)
        model:add_block(2, "agent_header", 1)
        model:add_block(2, "summary", 2)

        local projection = require("parley.fold_projection")
        assert.same({
            { block_index = 3, kind = "thinking", start_0 = 10, end_0 = 11 },
            { block_index = 5, kind = "summary", start_0 = 17, end_0 = 17 },
            { block_index = 6, kind = "tool_use", start_0 = 19, end_0 = 22 },
            { block_index = 7, kind = "tool_result", start_0 = 24, end_0 = 25 },
        }, projection.desired_folds(model, 1))
        assert.same({
            { block_index = 3, kind = "summary", start_0 = 31, end_0 = 32 },
        }, projection.desired_folds(model, 2))
        assert.same({}, projection.desired_folds(model, 3))
    end)

    it("loads without a Neovim global", function()
        local path = vim.api.nvim_get_runtime_file("lua/parley/fold_projection.lua", false)[1]
        local loader = assert(loadfile(path))
        local saved_vim = _G.vim
        _G.vim = nil
        local ok, projection = pcall(loader)
        _G.vim = saved_vim

        assert.is_true(ok)
        assert.is_function(projection.desired_folds)
    end)
end)
