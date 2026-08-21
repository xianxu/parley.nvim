local structure = require("parley.answer_structure")
local patterns = require("parley.highlight_structure").patterns({
    chat_memory = { enable = true, reasoning_prefix = "🧠:", summary_prefix = "📝:" },
})

local function kinds(result)
    return vim.tbl_map(function(section) return section.kind end, result.sections)
end

describe("answer_structure.reduce", function()
    it("splits every semantic answer entity with exact spans", function()
        local result = structure.reduce({
            "hello", "", "🧠: think", "detail", "", "answer", "",
            "📝: short", "", "🔧: read id=x", "```json", "{}", "```",
            "", "📎: read id=x", "```", "ok", "```",
        }, patterns)

        assert.same({ "text", "thinking", "text", "summary", "tool_use", "tool_result" }, kinds(result))
        assert.same({ 3, 4 }, { result.sections[2].line_start, result.sections[2].line_end })
        assert.same({ 8, 8 }, { result.sections[4].line_start, result.sections[4].line_end })
        assert.same({ 10, 13 }, { result.sections[5].line_start, result.sections[5].line_end })
        assert.is_true(result.work.rows_visited <= 18)
    end)

    it("keeps blank paragraphs inside explicitly terminated thinking", function()
        local result = structure.reduce({
            "🧠: first", "", "second", "🧠:[END]", "", "answer",
        }, patterns)
        assert.same({ "thinking", "text" }, kinds(result))
        assert.same({ 1, 4 }, { result.sections[1].line_start, result.sections[1].line_end })
    end)

    it("uses a provisional legacy boundary until the explicit end arrives", function()
        local provisional = structure.reduce({ "🧠: first", "", "second" }, patterns, { streaming = true })
        assert.same({ "thinking", "text" }, kinds(provisional))
        assert.same({ 1, 1 }, { provisional.sections[1].line_start, provisional.sections[1].line_end })

        local reconciled = structure.reduce({ "🧠: first", "", "second", "🧠:[END]" }, patterns,
            { streaming = true })
        assert.same({ "thinking" }, kinds(reconciled))
        assert.same({ 1, 4 }, { reconciled.sections[1].line_start, reconciled.sections[1].line_end })
    end)

    it("does not treat inline marker-like prose as structure", function()
        local result = structure.reduce({ "ordinary 📝: prose", "and 🔧: prose" }, patterns)
        assert.same({ "text" }, kinds(result))
        assert.same({ 1, 2 }, { result.sections[1].line_start, result.sections[1].line_end })
    end)
end)

-- #200 M2: the tool-section scanner closed on ANY >=3-backtick run, because
-- highlight_structure classifies every such line as `fence`. A tool body whose
-- content contains a nested ``` block therefore ended early, and its tail was
-- emitted as unfoldable `text` — violating "tool blocks are always folded".
describe("tool sections with nested fences (#200)", function()
    local answer_structure = require("parley.answer_structure")
    local patterns = require("parley.highlight_structure").patterns({})

    it("keeps a nested shorter fence inside the tool section", function()
        local lines = {
            "📎: read_file",
            "````",
            "here is a markdown file:",
            "```lua",
            "print('hi')",
            "```",
            "end of file",
            "````",
            "",
            "📝: read the file",
        }
        local sections = answer_structure.reduce(lines, patterns).sections
        assert.equals("tool_result", sections[1].kind)
        assert.equals(1, sections[1].line_start)
        assert.message("section ended at the nested fence instead of the matching one")
            .equals(8, sections[1].line_end)
        assert.equals("summary", sections[2].kind)
    end)

    it("still ends a plain tool section at its own matching fence", function()
        local lines = {
            "📎: read_file", "```", "ok", "```", "", "📝: done",
        }
        local sections = answer_structure.reduce(lines, patterns).sections
        assert.equals("tool_result", sections[1].kind)
        assert.equals(4, sections[1].line_end)
        assert.equals("summary", sections[2].kind)
    end)

    -- An unterminated fence must not swallow the rest of the answer: stop at
    -- the next structural boundary so later blocks still segment.
    it("stops an unterminated fence at the next boundary", function()
        local lines = {
            "📎: read_file", "````", "body that never closes", "",
            "📝: summary anyway", "text after",
        }
        local sections = answer_structure.reduce(lines, patterns).sections
        assert.equals("tool_result", sections[1].kind)
        assert.message("an unterminated fence swallowed the following summary")
            .is_true(sections[1].line_end < 5)
        local kinds = {}
        for _, s in ipairs(sections) do kinds[#kinds + 1] = s.kind end
        assert.message("summary was lost: " .. vim.inspect(kinds))
            .is_true(vim.tbl_contains(kinds, "summary"))
    end)
end)

-- BR-29: the unterminated-fence rewind was gated on `cursor > #lines`, which is
-- equally true when the fence closed ON the last line. A correctly closed body
-- containing a BOUNDARY-classified line was then truncated at its opener.
describe("tool section closing on the last line (#200 BR-29)", function()
    local answer_structure = require("parley.answer_structure")
    local patterns = require("parley.highlight_structure").patterns({})

    it("keeps a body whose close is the final line of the span", function()
        local lines = {
            "📎: read_file",
            "```",
            "📝: a summary marker quoted inside the body",
            "```",
        }
        local sections = answer_structure.reduce(lines, patterns).sections
        assert.equals(1, #sections)
        assert.equals("tool_result", sections[1].kind)
        assert.message("body truncated at its opener despite closing correctly")
            .equals(4, sections[1].line_end)
    end)

    it("keeps a body with an in-body question closing on the final line", function()
        local lines = {
            "🔧: read_file",
            "````",
            "💬: quoted question",
            "```",
            "nested",
            "```",
            "````",
        }
        local sections = answer_structure.reduce(lines, patterns).sections
        assert.equals("tool_use", sections[1].kind)
        assert.equals(7, sections[1].line_end)
    end)
end)
