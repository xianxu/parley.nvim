-- #234: the redraw walk in highlighter.lua steps rows through
-- highlight_structure's own enter_row/leave_row, so the state it paints each
-- row from must equal what `build` records as `state_before` for that row.
-- Over random documents (the #227 vocabulary), any rule added to only one side
-- turns this red.
local parley = require("parley")
local root = vim.fn.tempname() .. "-render-parity"
vim.fn.mkdir(root .. "/state", "p")
parley.setup({ chat_dir = root, state_dir = root .. "/state", providers = {}, api_keys = {},
    llm_onboarding = false })
local highlighter = require("parley.highlighter")
local structure = require("parley.highlight_structure")

local VOCAB = {
    "prose", "prose", "prose", "prose", "more prose", "", "", "   ",
    "```", "````", "=== d ===", "=== end ===",
    "💬: q", "🤖: a", "🧠: r", "🧠:[END]", "[^n]: f", "📝: s", "🔧: t", "📎: r",
    "🌿: b", "🔒: l",
}

describe("render walk state parity with build (#234)", function()
    after_each(function() highlighter._observe_render_state = nil end)

    it("paints every row from build's state_before, over random documents", function()
        math.randomseed(234)
        local patterns = structure.patterns(parley.config)
        local rows_checked, reasoning_rows = 0, 0
        local buf = vim.api.nvim_create_buf(false, true)
        parley._parley_bufs[buf] = "chat"
        vim.api.nvim_set_current_buf(buf)
        for _ = 1, 300 do
            local lines = {}
            for i = 1, math.random(1, 24) do lines[i] = VOCAB[math.random(#VOCAB)] end
            vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
            local built = structure.build(lines, patterns)
            local seen = {}
            highlighter._observe_render_state = function(row0, state) seen[row0 + 1] = state end
            highlighter._compute_window_decorations(vim.api.nvim_get_current_win(), buf, 0, #lines - 1, nil, built, 0)
            highlighter._observe_render_state = nil
            local context = "\nlines:\n" .. table.concat(lines, "\n")
            for row = 1, #lines do
                assert.is_table(seen[row], "the render walk did not reach row " .. row .. context)
                assert.are.same(built.state_before[row], seen[row], "row " .. row .. context)
                rows_checked = rows_checked + 1
                if built.state_before[row].in_reasoning then reasoning_rows = reasoning_rows + 1 end
            end
        end
        vim.api.nvim_buf_delete(buf, { force = true })
        -- Non-vacuity: the reasoning transitions are what #234 moved.
        assert.is_true(rows_checked > 2000, "rows checked: " .. rows_checked)
        -- Measured at seed 234: 3881 rows, 182 inside reasoning.
        assert.is_true(reasoning_rows > 100, "rows painted inside reasoning: " .. reasoning_rows)
    end)
end)
