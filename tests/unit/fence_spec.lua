local fence = require("parley.fence")

-- #200 M2: one grammar for fenced tool bodies. Three consumers had written it
-- independently — serialize (correctly, twice), answer_structure (closing on any
-- >=3-backtick run), and chat_parser (correctly, but as its own tracker).
describe("fence grammar", function()
    -- BR-43 root cause: a too-strict info string makes a genuine opener
    -- invisible, and its CLOSER is then read as an opener — every downstream
    -- scanner shifts by one fence and the guards blind themselves. CommonMark
    -- allows any info string that contains no backtick.
    it("accepts any CommonMark info string", function()
        assert.equals(3, fence.open_len('```json {"type": "request"}'))
        assert.equals(3, fence.open_len("``` lua extra"))
        assert.equals(4, fence.open_len("````  spaced  info  "))
        assert.equals(3, fence.open_len("```text"))
        -- A backtick in the info string is not a fence, per CommonMark.
        assert.is_nil(fence.open_len("``` has ` a backtick"))
    end)

    it("recognises an opening fence of three or more backticks", function()
        assert.equals(3, fence.open_len("```"))
        assert.equals(4, fence.open_len("````"))
        assert.equals(3, fence.open_len("```json"))
        assert.equals(4, fence.open_len("````json"))
        assert.equals(3, fence.open_len("```lua"))
        assert.is_nil(fence.open_len("``"))
        assert.is_nil(fence.open_len("plain text"))
        -- Prose after the ticks IS a valid info string per CommonMark; what
        -- disqualifies a line is a backtick inside it.
        assert.equals(3, fence.open_len("``` some prose here"))
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




-- BR-43: fence DEPTH is the requirement every earlier attempt missed. A marker
-- written inside an ordinary fenced block is not a marker, and treating it as
-- one makes that block's closer look like a body opener.
describe("depth-aware scan", function()
    local function is_marker(line)
        return line:match("^🔧:") ~= nil or line:match("^📎:") ~= nil
    end

    it("ignores a tool marker written inside an ordinary fenced block", function()
        local body, markers = fence.scan({
            "🤖: [A]", "```text", "📎: read_file id=x", "```", "💬: q2",
        }, is_marker)
        assert.is_nil(markers[3])
        assert.is_nil(body[5])
    end)

    it("marks a real tool body and stops at its close", function()
        local body, markers = fence.scan({
            "📎: read id=1", "```", "a", "b", "```", "💬: q2",
        }, is_marker)
        assert.is_true(markers[1])
        assert.is_true(body[3])
        assert.is_true(body[4])
        assert.is_nil(body[5])
        assert.is_nil(body[6])
    end)

    it("treats an unclosed opener as text rather than swallowing the rest", function()
        local body = fence.scan({
            "🤖: [A]", "```", "never closed", "💬: q2", "🤖: [A]",
        }, is_marker)
        assert.is_nil(body[4])
    end)

    it("keeps in-body markers as content inside a real tool body", function()
        local body, markers = fence.scan({
            "📎: read id=1", "````", "💬: quoted", "📎: quoted", "````", "💬: real",
        }, is_marker)
        assert.is_true(body[3])
        assert.is_true(body[4])
        assert.is_nil(markers[4])
        assert.is_nil(body[6])
    end)
end)
