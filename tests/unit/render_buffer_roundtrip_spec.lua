-- Round-trip test: parser-recorded line spans agree with the
-- positions() projection over render_buffer for every fixture.
-- See Task 1.5 of #90.

local chat_parser = require("parley.chat_parser")
local rb = require("parley.render_buffer")
local cfg = require("parley.config")

local FIXTURES = {
    "single-user",
    "simple-chat",
    "one-round-tool-use",
    "two-round-tool-use",
    "mixed-text-and-tools",
    "tool-error",
    "dynamic-fence-stress",
}

local function read_file_lines(path)
    local f = assert(io.open(path, "r"))
    local lines = {}
    for line in f:lines() do
        table.insert(lines, line)
    end
    f:close()
    return lines
end

describe("render_buffer.positions agrees with parser-recorded spans", function()
    for _, name in ipairs(FIXTURES) do
        it(name .. " parses and projects consistently", function()
            local lines = read_file_lines("tests/fixtures/transcripts/" .. name .. ".md")
            local parsed = chat_parser.parse_chat(lines, chat_parser.find_header_end(lines), cfg)
            local positions = rb.positions(parsed)
            assert.equals(#parsed.exchanges, #positions.exchanges,
                name .. ": exchange count mismatch")
            for ex_idx, ex in ipairs(parsed.exchanges) do
                if ex.answer and ex.answer.sections then
                    local p_secs = positions.exchanges[ex_idx].answer.sections
                    assert.equals(#ex.answer.sections, #p_secs,
                        name .. " ex " .. ex_idx .. ": section count mismatch")
                    for s_idx, s in ipairs(ex.answer.sections) do
                        assert.equals(s.line_start, p_secs[s_idx].line_start,
                            name .. " ex " .. ex_idx .. " sec " .. s_idx .. " line_start")
                        assert.equals(s.line_end, p_secs[s_idx].line_end,
                            name .. " ex " .. ex_idx .. " sec " .. s_idx .. " line_end")
                    end
                end
            end
        end)
    end
end)

describe("render_buffer.agent_header_lines", function()
    it("returns blank-prefix-blank pattern", function()
        assert.same({ "", "🤖: [Claude]", "" }, rb.agent_header_lines("[Claude]"))
    end)

    it("appends suffix when provided", function()
        assert.same({ "", "🤖: [Claude][🔧]", "" }, rb.agent_header_lines("[Claude]", "[🔧]"))
    end)

    it("handles nil prefix/suffix", function()
        assert.same({ "", "🤖: ", "" }, rb.agent_header_lines())
    end)
end)

describe("render_buffer.raw_request_fence_lines", function()
    it("emits a typed json fence around the payload", function()
        local lines = rb.raw_request_fence_lines({ a = 1, b = "x" })
        assert.equals("", lines[1])
        assert.matches('^```json %{"type": "request"%}$', lines[2])
        assert.equals("```", lines[#lines])
        -- middle lines contain the JSON
        local body = table.concat(lines, "\n")
        assert.matches('"a"', body)
        assert.matches('"b"', body)
    end)
end)
