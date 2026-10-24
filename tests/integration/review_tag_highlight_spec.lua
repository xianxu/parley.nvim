local parley = require("parley")
local highlighter = require("parley.highlighter")
local Document = require("parley.document")
local core = require("parley.skills.review.chat_structure")
local buf
local scratch = vim.fn.tempname()
parley.setup({ chat_dir = scratch, state_dir = scratch .. "/state", providers = {}, api_keys = {} })

local function has(map, row, group)
    for _, mark in ipairs(map[row] or {}) do if mark.hl_group == group then return true end end
    return false
end

describe("review chat tags remain ordinary visible source", function()
    after_each(function()
        if buf and vim.api.nvim_buf_is_valid(buf) then vim.api.nvim_buf_delete(buf, { force = true }) end
    end)
    it("does not parse or tint standalone chat metadata while ordinary tags retain their style", function()
        local lines = { "@@chat@@", "## Tagged", "body", "@@chat@@", "", "@@local@@", "```", "@@chat@@", "# Literal", "```", "Inline @@chat@@", "  @@chat@@  " }
        for _, kind in ipairs({ "chat", "markdown" }) do
            buf = vim.api.nvim_create_buf(false, true)
            vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
            parley._parley_bufs[buf] = kind
            highlighter.setup(parley)
            local doc = highlighter.rebuild_structure(buf)
            assert.equals("idle", Document.drain(doc, 100000).status)
            local snapshot, calls = core.snapshot, 0
            core.snapshot = function(source) calls = calls + 1; return snapshot(source) end
            local ok, map = pcall(highlighter._compute_window_decorations, 0, buf, 0, 11, nil, doc)
            core.snapshot = snapshot
            assert.is_true(ok, tostring(map))
            assert.equals(0, calls)
            for _, row in ipairs({ 0, 3, 7, 11 }) do
                assert.is_false(has(map, row, "ParleyTag"))
                assert.is_false(has(map, row, "ParleyAnnotation"))
                assert.is_false(has(map, row, "ParleyFileReference"))
                for _, mark in ipairs(map[row] or {}) do assert.is_nil(mark.conceal) end
            end
            if kind == "chat" then
                assert.is_true(has(map, 5, "ParleyTag"))
                assert.is_true(has(map, 10, "ParleyTag"))
            end
            assert.same(lines, vim.api.nvim_buf_get_lines(buf, 0, -1, false))
            vim.api.nvim_buf_delete(buf, { force = true })
        end
    end)
end)
