local fence = require("parley.fence")

-- #200 M2: one grammar for fenced tool bodies. Three consumers had written it
-- independently — serialize (correctly, twice), answer_structure (closing on any
-- >=3-backtick run), and chat_parser (correctly, but as its own tracker).
describe("fence grammar", function()
    it("recognises an opening fence of three or more backticks", function()
        assert.equals(3, fence.open_len("```"))
        assert.equals(4, fence.open_len("````"))
        assert.equals(3, fence.open_len("```json"))
        assert.equals(4, fence.open_len("````json"))
        assert.equals(3, fence.open_len("```lua"))
        assert.is_nil(fence.open_len("``"))
        assert.is_nil(fence.open_len("plain text"))
        -- An info string is a bare word; prose after the ticks is not a fence.
        assert.is_nil(fence.open_len("``` some prose here"))
    end)

    it("closes only on a bare run of the same length", function()
        assert.is_true(fence.closes("````", 4))
        assert.is_false(fence.closes("```", 4))    -- shorter: body content
        assert.is_false(fence.closes("`````", 4))  -- longer: not this pair
        assert.is_false(fence.closes("````json", 4))
        assert.is_false(fence.closes("text", 4))
    end)

    it("picks a fence strictly longer than any run in the content", function()
        assert.equals("```", fence.for_content("no backticks here"))
        assert.equals("````", fence.for_content("a ``` block"))
        assert.equals("`````", fence.for_content("a ```` block"))
        assert.equals("```", fence.for_content(""))
    end)

    -- The grammar scans arbitrary model output, so pin the invariant rather
    -- than a handful of literals.
    it("always picks a fence that its own content cannot close", function()
        local bodies = {
            "", "plain", "`", "``", "```", "````````",
            "``` ```` `````", "a\n```\nb\n````\nc", "`\n``\n```\n",
            "```json\n{}\n```", "text with ` inline ` ticks",
            "```\n```\n```\n", "\n\n```\n",
        }
        for _, body in ipairs(bodies) do
            local open = fence.for_content(body)
            local n = fence.open_len(open)
            assert.message(("for_content(%q) -> %q is not a valid opener")
                :format(body, open)).is_true(n ~= nil)
            for line in (body .. "\n"):gmatch("([^\n]*)\n") do
                assert.message(("body line %q closes its own fence %q")
                    :format(line, open)).is_false(fence.closes(line, n))
            end
        end
    end)

    it("accepts every fence chat_parser's tracker accepts", function()
        -- The shape chat_parser.lua:461 matched before deriving from here.
        for _, line in ipairs({ "```", "````", "```json", "```lua", "```py_3" }) do
            local legacy = line:match("^(`+)[%w_%-]*%s*$")
            assert.message(("legacy pattern accepted %q; grammar must too"):format(line))
                .equals(legacy and #legacy or nil, fence.open_len(line))
        end
    end)
end)

describe("fence body extraction", function()
    it("returns the body between a matching pair", function()
        local body, open_at, close_at = fence.extract_body({
            "📎: read_file", "```", "line one", "line two", "```", "after",
        })
        assert.equals("line one\nline two", body)
        assert.equals(2, open_at)
        assert.equals(5, close_at)
    end)

    it("keeps a nested shorter fence inside the body", function()
        local body = fence.extract_body({
            "📎: read_file", "````", "here is markdown:", "```lua",
            "print('hi')", "```", "end", "````",
        })
        assert.equals("here is markdown:\n```lua\nprint('hi')\n```\nend", body)
    end)

    -- A longer run must not close a shorter pair. serialize's reader used a
    -- `%1` backreference, which matches a PREFIX of a longer run.
    it("does not close on a run longer than the opener", function()
        local body = fence.extract_body({
            "📎: x", "```", "a", "`````", "b", "```",
        })
        assert.equals("a\n`````\nb", body)
    end)

    it("returns nil for an unterminated fence", function()
        assert.is_nil(fence.extract_body({ "📎: x", "```", "a", "b" }))
    end)

    it("returns nil when no fence opens", function()
        assert.is_nil(fence.extract_body({ "📎: x", "plain", "text" }))
    end)
end)

describe("fence / serialize parity", function()
    local serialize = require("parley.tools.serialize")

    it("renders an opening fence the grammar recognises, of the length it picks", function()
        for _, body in ipairs({ "plain", "has ``` inside", "has ```` inside" }) do
            local text = serialize.render_result({ id = "r1", name = "read_file", content = body })
            local opener = vim.split(text, "\n")[2]
            assert.equals(#fence.for_content(body), fence.open_len(opener))
        end
    end)

    it("round-trips a body through render_result and parse_result", function()
        for _, body in ipairs({ "plain", "```\nnested\n```", "````\ndeep\n````" }) do
            local parsed = serialize.parse_result(
                serialize.render_result({ id = "r1", name = "read_file", content = body }))
            assert.message(("round-trip lost content for %q"):format(body))
                .equals(body, parsed.content)
        end
    end)

    it("round-trips a tool call whose input serialises with backticks", function()
        for _, body in ipairs({ "plain", "has ``` inside" }) do
            local parsed = serialize.parse_call(serialize.render_call({
                id = "t1", name = "read_file", input = { body = body },
            }))
            assert.equals(body, parsed.input.body)
        end
    end)
end)
