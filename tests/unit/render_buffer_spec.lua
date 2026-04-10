-- Unit tests for lua/parley/render_buffer.lua
--
-- Pure render layer that produces buffer lines from parsed sections.
-- See Tasks 1.3 + 1.4 of #90.

local rb = require("parley.render_buffer")

describe("render_buffer.render_section", function()
    it("renders a text section as its lines", function()
        local lines = rb.render_section({ kind = "text", text = "hello\nworld" })
        assert.same({ "hello", "world" }, lines)
    end)

    it("renders a single-line text section", function()
        local lines = rb.render_section({ kind = "text", text = "hi" })
        assert.same({ "hi" }, lines)
    end)

    it("renders an empty text section as a single empty line", function()
        local lines = rb.render_section({ kind = "text", text = "" })
        assert.same({ "" }, lines)
    end)

    it("renders a tool_use section using serialize.render_call", function()
        local lines = rb.render_section({
            kind = "tool_use",
            id = "toolu_X",
            name = "read_file",
            input = { path = "foo.txt" },
        })
        assert.matches("^🔧: read_file id=toolu_X$", lines[1])
        assert.matches("^```json", lines[2])
        assert.matches('"path"', lines[3])
        assert.equals("```", lines[4])
    end)

    it("renders a tool_result section using serialize.render_result", function()
        local lines = rb.render_section({
            kind = "tool_result",
            id = "toolu_X",
            name = "read_file",
            content = "hi",
            is_error = false,
        })
        assert.matches("^📎: read_file id=toolu_X$", lines[1])
        assert.matches("^```", lines[2])
        assert.equals("hi", lines[3])
        assert.matches("^```", lines[4])
    end)

    it("renders an error tool_result", function()
        local lines = rb.render_section({
            kind = "tool_result",
            id = "toolu_E",
            name = "read_file",
            content = "boom",
            is_error = true,
        })
        assert.matches("error=true", lines[1])
    end)

    it("raises on unknown kind", function()
        assert.has_error(function()
            rb.render_section({ kind = "weird" })
        end)
    end)
end)

describe("render_buffer.render_exchange", function()
    it("renders a question + simple text answer", function()
        local ex = {
            question = { content = "what?", line_start = 1, line_end = 1 },
            answer = {
                line_start = 3,
                line_end = 4,
                sections = {
                    { kind = "text", text = "the answer", line_start = 4, line_end = 4 },
                },
                content = "the answer",
            },
        }
        local lines = rb.render_exchange(ex)
        assert.same({ "💬: what?", "", "🤖:", "the answer" }, lines)
    end)

    it("renders an exchange with no answer (just the question)", function()
        local ex = {
            question = { content = "pending", line_start = 1, line_end = 1 },
        }
        local lines = rb.render_exchange(ex)
        assert.same({ "💬: pending" }, lines)
    end)

    it("renders mixed text + tool_use + tool_result + text", function()
        local ex = {
            question = { content = "q", line_start = 1, line_end = 1 },
            answer = {
                line_start = 3, line_end = 10,
                sections = {
                    { kind = "text", text = "checking" },
                    { kind = "tool_use", id = "T1", name = "read_file", input = { path = "x" } },
                    { kind = "tool_result", id = "T1", name = "read_file", content = "data", is_error = false },
                    { kind = "text", text = "done" },
                },
            },
        }
        local lines = rb.render_exchange(ex)
        assert.equals("💬: q", lines[1])
        assert.equals("", lines[2])
        assert.equals("🤖:", lines[3])
        assert.equals("checking", lines[4])
        assert.matches("^🔧:", lines[5])
        -- ... tool_use body lines ...
        assert.equals("done", lines[#lines])
    end)
end)
