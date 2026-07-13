local parley = require("parley")
parley.setup({ providers = {}, api_keys = {} })

local chat_respond = require("parley.chat_respond")

describe("chat_respond managed footnote boundary", function()
    it("uses define grammar for leading-whitespace footnote definitions", function()
        local lines = { "body", "", "---", "  [^term]: definition", "\t[^other]: second" }
        assert.equals(2, chat_respond._trailing_footnote_boundary(lines, 0))
    end)
end)
