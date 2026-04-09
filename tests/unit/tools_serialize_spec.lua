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
