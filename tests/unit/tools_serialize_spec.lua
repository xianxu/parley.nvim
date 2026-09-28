-- Unit tests for lua/parley/tools/serialize.lua
--
-- The serialize module is the SINGLE SOURCE OF TRUTH for the `🔧:` /
-- `📎:` buffer representation. Render and parse are mirror operations
-- that must round-trip any ToolCall or ToolResult exactly. A dynamic-
-- length fence (backticks longer than any backtick run in the body)
-- is used so that LLM output containing ``` survives round-trip
-- unambiguously.

local serialize = require("parley.tools.serialize")

describe("serialize.render_call / parse_call", function()
    it("round-trips a minimal ToolCall", function()
        local call = { id = "toolu_01", name = "read_file", input = { path = "foo.txt" } }
        local rendered = serialize.render_call(call)
        assert.matches("🔧: read_file id=toolu_01", rendered)
        local parsed = serialize.parse_call(rendered)
        assert.same(call, parsed)
    end)

    it("round-trips a ToolCall with nested JSON input", function()
        local call = {
            id = "toolu_02",
            name = "edit_file",
            input = { path = "x", old_string = "a", new_string = "b\nc" },
        }
        local parsed = serialize.parse_call(serialize.render_call(call))
        assert.same(call, parsed)
    end)

    it("round-trips an empty input table", function()
        local call = { id = "toolu_03", name = "list_dir", input = {} }
        local rendered = serialize.render_call(call)
        local parsed = serialize.parse_call(rendered)
        assert.equals(call.id, parsed.id)
        assert.equals(call.name, parsed.name)
        -- vim.json.encode(empty table) produces "[]" in lua-cjson-like
        -- behavior; ensure parse recovers a table (maybe empty)
        assert.is_table(parsed.input)
    end)

    it("parse_call returns nil on missing prefix", function()
        assert.is_nil(serialize.parse_call("not a tool call"))
    end)

    it("parse_call tolerates missing fence body (empty input)", function()
        -- A malformed block without a fenced body; parse should still
        -- recover the header and return an empty input table.
        local parsed = serialize.parse_call("🔧: read_file id=toolu_04")
        assert.is_not_nil(parsed)
        assert.equals("toolu_04", parsed.id)
        assert.equals("read_file", parsed.name)
        assert.same({}, parsed.input)
    end)
end)

describe("serialize.render_result / parse_result", function()
    it("round-trips a successful ToolResult", function()
        local result = { id = "toolu_01", name = "read_file", content = "line1\nline2", is_error = false }
        local rendered = serialize.render_result(result)
        assert.matches("📎: read_file id=toolu_01", rendered)
        local parsed = serialize.parse_result(rendered)
        assert.equals(result.id, parsed.id)
        assert.equals(result.name, parsed.name)
        assert.equals(result.content, parsed.content)
        assert.equals(false, parsed.is_error)
    end)

    it("round-trips is_error=true with error=true tag in header", function()
        local result = { id = "toolu_02", name = "edit_file", content = "old_string not found", is_error = true }
        local rendered = serialize.render_result(result)
        assert.matches("error=true", rendered)
        local parsed = serialize.parse_result(rendered)
        assert.equals(true, parsed.is_error)
        assert.equals("old_string not found", parsed.content)
    end)

    it("round-trips an empty content string", function()
        local result = { id = "toolu_03", name = "write_file", content = "", is_error = false }
        local parsed = serialize.parse_result(serialize.render_result(result))
        assert.equals("", parsed.content)
        assert.equals(false, parsed.is_error)
    end)

    it("round-trips content with triple backticks (dynamic fence)", function()
        -- CRITICAL: tool output (e.g. read_file on a markdown file)
        -- commonly contains ``` fences. The serializer must pick a
        -- fence strictly longer than any backtick run in content.
        local result = {
            id = "toolu_04",
            name = "read_file",
            content = "```lua\nlocal x = 1\n```",
            is_error = false,
        }
        local rendered = serialize.render_result(result)
        -- Rendered must use a 4+-backtick fence since content has a 3-run
        assert.matches("````", rendered)
        local parsed = serialize.parse_result(rendered)
        assert.equals(result.content, parsed.content)
    end)

    it("round-trips content with four consecutive backticks", function()
        local result = {
            id = "toolu_05",
            name = "read_file",
            content = "````not-a-fence",
            is_error = false,
        }
        local parsed = serialize.parse_result(serialize.render_result(result))
        assert.equals(result.content, parsed.content)
    end)

    it("round-trips content with mixed backtick runs", function()
        -- Longest run is 5 → fence must be at least 6 backticks
        local result = {
            id = "toolu_06",
            name = "grep",
            content = "``` three\n``` four\n`````` six? no, five\n``````",
            is_error = false,
        }
        -- Recompute longest run manually for assertion
        local body = result.content
        local max_run = 0
        for run in body:gmatch("`+") do
            if #run > max_run then max_run = #run end
        end
        assert.is_true(max_run >= 5)

        local rendered = serialize.render_result(result)
        local parsed = serialize.parse_result(rendered)
        assert.equals(result.content, parsed.content)
    end)

    it("parse_result returns nil on missing prefix", function()
        assert.is_nil(serialize.parse_result("not a tool result"))
    end)

    it("is_error defaults to false when header lacks error=true tag", function()
        local parsed = serialize.parse_result("📎: read_file id=toolu_07\n```\nhello\n```")
        assert.is_not_nil(parsed)
        assert.equals(false, parsed.is_error)
    end)
end)

describe("serialize fence length invariant", function()
    -- The core correctness property: the opening fence and the
    -- closing fence of a rendered block MUST be the same length.
    -- Verified by inspection of rendered output for various content
    -- shapes.
    local function fence_runs(text)
        local runs = {}
        for fence in text:gmatch("(`+)\n") do
            table.insert(runs, #fence)
        end
        -- Also capture a trailing fence without a newline after it
        local trailing = text:match("(`+)$")
        if trailing then table.insert(runs, #trailing) end
        return runs
    end

    it("opening and closing fences match in length for empty content", function()
        local text = serialize.render_result({ id = "a", name = "t", content = "", is_error = false })
        local runs = fence_runs(text)
        assert.is_true(#runs >= 2)
        -- First and last fence runs should be equal length
        assert.equals(runs[1], runs[#runs])
    end)

    it("opening and closing fences scale past content's longest run", function()
        local body = string.rep("`", 7)
        local text = serialize.render_result({ id = "b", name = "t", content = body, is_error = false })
        local runs = fence_runs(text)
        -- Outer fence must be > 7
        assert.is_true(runs[1] >= 8, "expected fence >= 8, got " .. tostring(runs[1]))
        assert.equals(runs[1], runs[#runs])
    end)
end)

-- #200 M2: the reader used a `%1` backreference, which matches a PREFIX of a
-- longer run — so a body containing a run longer than its own opener was
-- silently truncated at that line. Reachable from a hand-edited transcript or
-- any tool output not produced by render_result.
describe("fenced body extraction (#200)", function()
    local serialize = require("parley.tools.serialize")

    it("does not truncate a result body at a run longer than its opener", function()
        local parsed = serialize.parse_result("📎: grep id=r1\n```\na\n`````\nb\n```")
        assert.equals("a\n`````\nb", parsed.content)
    end)

    -- parse_call is a separate reader path, so pin it on its own. The run must
    -- start a line to distinguish the two implementations: an inline run is
    -- never a candidate close, and render_call only ever emits single-line JSON.
    --
    -- The old backreference truncated the body to `{"a":1}`, which decodes —
    -- so a malformed block silently produced plausible input. Reading the whole
    -- body means the decode fails and input falls back to empty, which is the
    -- honest answer.
    it("does not truncate a call body at a run longer than its opener", function()
        local parsed = serialize.parse_call(
            '🔧: read_file id=t1\n```\n{"a":1}\n`````\ntrailing\n```')
        assert.same({}, parsed.input)
    end)

    -- Characterization, not a fix pin: the old backreference also handled a
    -- nested SHORTER fence. Kept so a future rewrite cannot lose it.
    it("keeps a nested shorter fence inside a result body", function()
        local parsed = serialize.parse_result(
            "📎: read_file id=r1\n````\nmd:\n```lua\nprint()\n```\nend\n````")
        assert.equals("md:\n```lua\nprint()\n```\nend", parsed.content)
    end)
end)

-- #291: a body line the lexer would read as a structural marker ends a tool
-- body early (fence.scan). render_result escapes it, so no producer needs to.
describe("serialize: structural lines in a result body (#291)", function()
    local highlight_structure = require("parley.highlight_structure")
    local patterns = highlight_structure.patterns(require("parley.config"))
    local function body_lines(rendered)
        local lines = vim.split(rendered, "\n", { plain = true })
        return vim.list_slice(lines, 3, #lines - 1)
    end
    local function assert_no_structural(rendered)
        for _, line in ipairs(body_lines(rendered)) do
            local kind = highlight_structure.classify(line, patterns).kind
            assert.message(("column-0 %s marker in body: %q"):format(kind, line))
                .is_false(highlight_structure.is_structural_kind(kind))
        end
    end
    local HOSTILE = {
        ["an ls line for a marker-named file"] = "a.md\n💬: notes.md\nz.md",
        ["stderr spliced after a prefixed line"] = "x.lua:1:ok\n📎: x id=1\n🔧: y id=2",
        ["every structural marker"] = "💬: q\n🤖: a\n📝: s\n🌿: b\n🔒: l",
        ["a line starting with the escape beside a marker"] = "\\💬: already escaped\n💬: raw\n\\plain",
        ["a marker on the last line with no newline"] = "ok\n🤖: tail",
        ["trailing newline"] = "💬: q\n",
    }
    for label, content in pairs(HOSTILE) do
        it("round-trips " .. label .. " without a column-0 marker", function()
            local rendered = serialize.render_result({ id = "r1", name = "ls", content = content })
            assert_no_structural(rendered)
            assert.truthy(rendered:match("^[^\n]* escaped=true\n"), "flagged")
            local parsed = serialize.parse_result(rendered)
            assert.equals(content, parsed.content)
        end)
    end
    it("keeps the error flag alongside the escape flag", function()
        local rendered = serialize.render_result({ id = "r1", name = "grep", content = "💬: x", is_error = true })
        assert.truthy(rendered:find("📎: grep id=r1 error=true escaped=true\n", 1, true))
        local parsed = serialize.parse_result(rendered)
        assert.is_true(parsed.is_error); assert.equals("💬: x", parsed.content)
    end)
    it("writes a result with no structural line byte-for-byte as before", function()
        local content = "\\not a marker\n  💬: indented is not column 0\nplain"
        assert.equals("📎: ls id=r1\n```\n" .. content .. "\n```",
            serialize.render_result({ id = "r1", name = "ls", content = content }))
    end)
    it("parses an old unflagged block exactly as before, backslashes included", function()
        local parsed = serialize.parse_result("📎: ls id=r1\n```\n\\💬: kept\n\\\\two\n```")
        assert.equals("\\💬: kept\n\\\\two", parsed.content)
    end)
    it("does not take a tool named like the flag for the flag", function()
        local parsed = serialize.parse_result("📎: escaped=true id=r1\n```\n\\x\n```")
        assert.equals("\\x", parsed.content)
    end)
end)
