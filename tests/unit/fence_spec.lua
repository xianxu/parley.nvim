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
        local bodies, markers = fence.scan({
            "🤖: [A]", "```text", "📎: read_file id=x", "```", "💬: q2",
        }, is_marker)
        assert.is_nil(markers[3])
        assert.is_nil(fence.body_rows(bodies)[5])
    end)

    it("marks a real tool body and stops at its close", function()
        local bodies, markers = fence.scan({
            "📎: read id=1", "```", "a", "b", "```", "💬: q2",
        }, is_marker)
        assert.is_true(markers[1])
        assert.same({ first = 3, last = 4, close = 5 }, bodies[1])
        local rows = fence.body_rows(bodies)
        assert.is_true(rows[3])
        assert.is_true(rows[4])
        assert.is_nil(rows[5])
    end)

    -- BR-55: the property the removed tool_body tests pinned, restored. A body
    -- opens on the line IMMEDIATELY after its marker. Accepting one further
    -- down marks genuine prose — including a real question — as body, which
    -- suppresses both the parser's classification and verify_anchors' guard.
    it("requires the body opener on the line right after the marker", function()
        local bodies = fence.scan({
            "📎: read id=1", "some prose", "```", "💬: a real question", "```",
        }, is_marker)
        assert.is_nil(bodies[1])
        assert.is_nil(fence.body_rows(bodies)[4])
    end)

    it("treats an unclosed opener as text rather than swallowing the rest", function()
        local bodies = fence.scan({
            "🤖: [A]", "```", "never closed", "💬: q2", "🤖: [A]",
        }, is_marker)
        assert.is_nil(fence.body_rows(bodies)[4])
    end)

    it("keeps in-body markers as content inside a real tool body", function()
        local bodies, markers = fence.scan({
            "📎: read id=1", "````", "💬: quoted", "📎: quoted", "````", "💬: real",
        }, is_marker)
        local rows = fence.body_rows(bodies)
        assert.is_true(rows[3])
        assert.is_true(rows[4])
        assert.is_nil(markers[4])
        assert.is_nil(rows[6])
    end)
end)

-- #203: the close search is bounded by column-0 structural markers, so a body
-- can never span one. Asserted on scan's own bodies/markers model rather than a
-- downstream exchange count — the rule lives here, so it is pinned here.
describe("fence.scan body bounds (#203)", function()
    local fence = require("parley.fence")

    -- Row 1 is the tool marker; rows carrying a bare 💬: are structural.
    local function scan(lines)
        return fence.scan(lines,
            function(_, row) return row == 1 end,
            function(line) return line:match("^💬:") ~= nil end)
    end

    it("takes the matching close when nothing structural intervenes", function()
        local bodies = scan({ "📎: r", "```", "content", "```", "after" })
        assert.is_not_nil(bodies[1])
        assert.equals(3, bodies[1].first)
        assert.equals(3, bodies[1].last)
        assert.equals(4, bodies[1].close)
    end)

    it("refuses a close that lies beyond a structural marker", function()
        -- The bare fence on the last row belongs to some other pair; taking it
        -- would swallow the question between.
        local bodies = scan({ "📎: r", "```", "never closed", "💬: q", "```" })
        assert.message("body latched onto a close belonging to another pair")
            .is_nil(bodies[1])
    end)

    it("refuses when the opener has no close at all", function()
        local bodies = scan({ "📎: r", "```", "truncated mid-write" })
        assert.is_nil(bodies[1])
    end)

    it("still reports the marker even when the body is refused", function()
        local _, markers = scan({ "📎: r", "```", "x", "💬: q", "```" })
        assert.message("a refused body must not also lose its marker")
            .is_true(markers[1])
    end)

    it("keeps a nested shorter fence inside a longer body", function()
        local bodies = scan({ "📎: r", "````", "```", "inner", "```", "````" })
        assert.is_not_nil(bodies[1])
        assert.equals(6, bodies[1].close)
    end)
end)

-- #203 BR-1: the structural bound belongs to TOOL BODIES only. Applying it to
-- the depth search for ordinary fenced blocks makes a block containing a marker
-- fail to establish depth, so its closer reads as an opener and the marker
-- becomes structural — BR-43 exactly. The suite stayed green when this broke,
-- so the shape is pinned here, at the scan, rather than downstream.
describe("fence.scan depth for ordinary blocks (#203 BR-1)", function()
    local fence = require("parley.fence")

    it("keeps a marker quoted in an ordinary fenced block non-structural", function()
        local lines = { "```text", "📎: read_file id=x", "```", "💬: q" }
        local _, markers = fence.scan(lines,
            function(line) return line:match("^📎:") ~= nil end,
            function(line) return line:match("^[💬🤖📎🔧📝]") ~= nil end)
        assert.message("an ordinary block stopped establishing depth, so its "
            .. "quoted marker became structural (BR-43)")
            .is_nil(markers[2])
    end)

    it("still establishes depth when the block spans several markers", function()
        local lines = { "```text", "💬: a", "🤖: b", "```", "📎: r", "```", "x", "```" }
        local _, markers = fence.scan(lines,
            function(line) return line:match("^📎:") ~= nil end,
            function(line) return line:match("^[💬🤖📎🔧📝]") ~= nil end)
        assert.is_nil(markers[2])
        assert.message("the real marker after the block was lost").is_true(markers[5])
    end)
end)
