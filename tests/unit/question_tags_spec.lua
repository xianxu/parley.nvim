local tags = require("parley.question_tags")
local cfg = { chat_user_prefix = "💬:", chat_assistant_prefix = "🤖:" }

describe("question preface association", function()
    it("recognizes whole-line tags without changing spelling", function()
        assert.equals("polar alignment", tags.parse_tag("@@polar alignment@@"))
        assert.equals("_", tags.parse_tag("@@_@@"))
        for _, line in ipairs({ "@@@@", "see @@tag@@", " @@tag@@", "@@tag@@ trailing" }) do
            assert.is_nil(tags.parse_tag(line))
        end
    end)
    it("attaches only the immediate eligible predecessor", function()
        local lines = { "@@header@@", "💬: ignored", "@@earlier@@", "@@label@@", "💬: q", "@@standalone@@", "", "💬: next" }
        assert.same({ [5] = { line_start = 4, line_end = 4, content = "@@label@@", label = "label" } },
            tags.associations(lines, cfg, 2))
    end)
    it("excludes fenced tags and supports configured question prefixes", function()
        local lines = { "Q: first", "A: answer", "```", "@@literal@@", "Q: second", "@@custom@@", "Q: third" }
        local custom = { chat_user_prefix = "Q:", chat_assistant_prefix = "A:" }
        assert.same({ [7] = { line_start = 6, line_end = 6, content = "@@custom@@", label = "custom" } },
            tags.associations(lines, custom))
    end)
    it("omits local prefaces but keeps reference prefaces", function()
        assert.equals("question", tags.compose_question(nil, "question"))
        assert.equals("question", tags.compose_question("@@_@@", "question"))
        assert.equals("@@./notes.md@@\nquestion", tags.compose_question("@@./notes.md@@", "question"))
    end)
end)

describe("question preface outline projection", function()
    local function item(kind, row, display)
        return { type = kind, value = { lnum = row, file = "/chat.md" }, display = display }
    end
    it("labels the question row, preserves indentation and source inputs", function()
        local lines = { "@@polar@@", "💬: hidden question text" }
        local items = { item("annotation", 1, "      → polar"), item("question", 2, "      💬: hidden question text") }
        local before = vim.deepcopy(items)
        local result = tags.apply_outline(items, lines, cfg)
        assert.same({ { type = "question", display = "      💬: polar", value = { file = "/chat.md", lnum = 2, tag_lnum = 1 } } }, result)
        assert.same(before, items)
        assert.equals(1, tags.initial_index(result, "/chat.md", 1))
    end)
    it("uses the configured question prefix for labels", function()
        local custom = { chat_user_prefix = "Q:", chat_assistant_prefix = "A:" }
        local result = tags.apply_outline({ item("question", 2, "    Q: wording") },
            { "@@label@@", "Q: wording" }, custom)
        assert.equals("    Q: label", result[1].display)
    end)
    it("hides anonymous tags and their adjacent questions only", function()
        local lines = { "@@_@@", "💬: hidden", "@@_@@", "", "💬: visible", "@@last@@" }
        local items = { item("annotation", 1, "  → _"), item("question", 2, "  💬: hidden"),
            item("annotation", 3, "  → _"), item("question", 5, "  💬: visible"), item("annotation", 6, "  → last") }
        assert.same({ items[4], items[5] }, tags.apply_outline(items, lines, cfg))
    end)
    it("maps a tag to its question in the right file", function()
        local items = { item("question", 4, "  other"), item("question", 8, "  label") }
        items[1].value.file = "/child.md"
        items[2].value.tag_lnum = 7
        assert.equals(2, tags.initial_index(items, "/chat.md", 7))
        assert.equals(2, tags.initial_index(items, "/chat.md", 8))
    end)
end)

-- Classify source rows, never already-trimmed message content.
describe("local tag context projection", function()
    it("keeps inline, indented, incomplete and reference forms", function()
        local lines = { "@@local@@", "@@_@@", "text @@inline@@", " @@indented@@",
            "@@tag@@ trailing", "@@@@", "@@unfinished", "@@./notes.md@@", "@@https://example.test@@",
            "@@/absolute@@", "@@~/home@@", "@@../parent@@", "@@http://example.test@@" }
        assert.equals(table.concat(lines, "\n", 3), tags.context_text(table.concat(lines, "\n"), cfg))
    end)
    it("keeps fenced text across mixed and shorter fence runs", function()
        local text = "````lua\n```\n@@one@@\n~~~\n@@two@@\n````\n@@local@@"
        assert.equals(text:sub(1, -11), tags.context_text(text, cfg))
    end)
    it("uses configured turn boundaries after an unmatched fence", function()
        local text = "```\n@@literal@@\nQ+: question\n@@local@@"
        assert.equals("```\n@@literal@@\nQ+: question", tags.context_text(text, { chat_user_prefix = "Q+:" }))
    end)
end)
