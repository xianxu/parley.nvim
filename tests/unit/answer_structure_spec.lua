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
