-- side-quest (#225): the only spec in tests/unit that called setup() without a
-- chat_dir/state_dir, so it prepared the REAL XDG dirs and shared them with
-- every other spec the 8-way runner had in flight. It failed once during #225's
-- round-3 verification and passed alone — a flake in the suite whose exit code
-- the close gate trusts. Hermetic now, like its neighbours.
local tmp_dir = vim.fn.tempname() .. "-parley-footnote"
vim.fn.mkdir(tmp_dir, "p")

local parley = require("parley")
parley.setup({
    chat_dir = tmp_dir,
    state_dir = tmp_dir .. "/state",
    providers = {},
    api_keys = {},
})

local chat_respond = require("parley.chat_respond")

describe("chat_respond managed footnote boundary", function()
    it("uses define grammar for leading-whitespace footnote definitions", function()
        local lines = { "body", "", "---", "  [^term]: definition", "\t[^other]: second" }
        assert.equals(2, chat_respond._trailing_footnote_boundary(lines, 0))
    end)
end)
