local tags = require("parley.question_tags")
local entity = require("parley.entity_range")
local refs = require("parley.reference_candidates")
local cfg = require("parley.config")

describe("review tag consumer ownership", function()
    it("preserves only valid chat metadata in model context", function()
        local lines = { "@@local@@", "@@chat@@", "## Tagged", "Body.", "@@chat@@", "", "## Untagged",
            "```", "@@chat@@", "# Literal", "```", "@@./file.md@@" }
        local expected = vim.deepcopy(lines)
        table.remove(expected, 5)
        table.remove(expected, 1)
        assert.equals(table.concat(expected, "\n"), tags.context_text(table.concat(lines, "\n"), cfg))
    end)
    it("does not enumerate valid chat metadata as a reference", function()
        local lines = { "@@chat@@", "## Tagged", "@@chat@@", "", "@@ordinary@@" }
        local found = refs.collect(lines, { first = 1, last = #lines }, { config = cfg, transcript = false })
        assert.equals(2, #found)
        assert.equals(3, found[1].row)
        assert.equals("ordinary", found[2].target)
    end)
    it("moves a tag with its section from the heading or tag row", function()
        local lines = { "# Prior", "first", "@@chat@@", "# Tagged", "body", "", "@@chat@@", "# Next", "tail" }
        assert.same({ kind = "section", first = 1, last = 2 }, entity.range(nil, lines, 1))
        for _, row in ipairs({ 3, 4 }) do
            for _, inner in ipairs({ false, true }) do
                assert.same({ kind = "section", first = inner and 5 or 3, last = inner and 5 or 6 },
                    entity.range(nil, lines, row, { inner = inner }))
            end
        end
        assert.same({ kind = "section", first = 7, last = 9 }, entity.range(nil, lines, 8))
    end)
    it("does not pull the following tag into a preceding paragraph", function()
        local lines = { "Body.", "@@chat@@", "## Tagged", "tail" }
        assert.same({ kind = "paragraph", first = 1, last = 1 }, entity.range(nil, lines, 1))
    end)
    it("retains existing editing levels and rejects code/setext/misplaced association", function()
        for _, lines in ipairs({ { "@@chat@@", "#### Deep", "body" },
            { "@@chat@@", "Title", "=====" }, { "```", "@@chat@@", "# Literal", "```" },
            { "@@chat@@", "", "# Gap" } }) do
            local found = entity.range(nil, lines, lines[1] == "```" and 2 or 1)
            assert.is_true(found == nil or found.kind ~= "section")
        end
        local lines = { "@@chat@@", "## Tagged", "tail" }
        local items = tags.apply_outline({ { type = "annotation", display = " → chat", value = { lnum = 1 } },
            { type = "heading", display = "  ## Tagged", value = { lnum = 2 } } }, lines, cfg)
        assert.equals(1, #items)
        assert.equals(1, items[1].value.tag_lnum)
    end)
    it("carries real overlimit chat lookup uncertainty through editing and navigation", function()
        local parser = require("parley.chat_parser")
        local lines = { "# topic: lookup", "- file: lookup.md", "---", "", "💬: q", "🤖: [A]",
            "@@chat@@", "## Protected", string.rep("x", 1024 * 1024) }
        local parsed = parser.parse_chat(lines, 3, cfg)
        assert.is_nil(parsed.review_tags)
        assert.is_truthy(parsed.review_tag_error:find("1 MiB", 1, true))
        assert.is_truthy(tags.content(parsed.exchanges[1].answer):find("@@chat@@", 1, true),
            "uncertain metadata must survive context projection")
        local range, err = entity.range(parsed, lines, 8)
        assert.is_nil(range)
        assert.equals(parsed.review_tag_error, err)
        local nav, code, projection, nav_err = entity.navigation_range(parsed, lines, 8)
        assert.is_nil(nav); assert.is_nil(code); assert.is_nil(projection)
        assert.equals(parsed.review_tag_error, nav_err)
    end)
    it("does not retry unavailable lookup from the real parsed chat", function()
        local core = require("parley.skills.review.chat_structure")
        local parser = require("parley.chat_parser")
        local snapshot, calls = core.snapshot, 0
        core.snapshot = function() calls = calls + 1; return nil, "native parser unavailable fixture" end
        local ok, err = pcall(function()
            local lines = { "# topic: lookup", "- file: lookup.md", "---", "", "💬: q", "🤖: [A]",
                "@@chat@@", "## Protected", "body" }
            local parsed = parser.parse_chat(lines, 3, cfg)
            assert.is_nil(parsed.review_tags)
            assert.equals("native parser unavailable fixture", parsed.review_tag_error)
            local range, lookup_err = entity.range(parsed, lines, 8)
            assert.is_nil(range)
            assert.equals(parsed.review_tag_error, lookup_err)
            local _, _, _, nav_err = entity.navigation_range(parsed, lines, 8)
            assert.equals(parsed.review_tag_error, nav_err)
            assert.equals(1, calls)
        end)
        core.snapshot = snapshot
        assert.is_true(ok, tostring(err))
    end)
    it("keeps ordinary chats usable beyond the review lookup limit", function()
        local parser = require("parley.chat_parser")
        local lines = { "# topic: ordinary", "- file: ordinary.md", "---", "", "💬: q", "🤖: [A]",
            "## Ordinary", string.rep("x", 1024 * 1024) }
        local parsed = parser.parse_chat(lines, 3, cfg)
        assert.is_nil(parsed.review_tag_error)
        assert.same({}, parsed.review_tags)
        assert.same({ kind = "section", first = 7, last = 8 }, entity.range(parsed, lines, 7))
    end)
    it("shares one native association across paged live outline headings", function()
        local outline = require("parley.outline")
        local Document = require("parley.document")
        local core = require("parley.skills.review.chat_structure")
        local lines = {}
        for index = 1, 12 do
            lines[#lines + 1] = "@@chat@@"
            lines[#lines + 1] = "## Heading " .. index
            lines[#lines + 1] = "body"
        end
        local buf = vim.api.nvim_create_buf(false, true)
        vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
        Document.drain(Document.attach(buf, { schedule = false }), 100000)
        local snapshot, calls = core.snapshot, 0
        core.snapshot = function(source) calls = calls + 1; return snapshot(source) end
        local items, cursor = {}, nil
        local ok, err = pcall(function()
            repeat
                local page, state = outline._build_picker_items(buf, cfg, { is_chat = false, cursor = cursor })
                vim.list_extend(items, page)
                cursor = state.cursor
            until not cursor
        end)
        core.snapshot = snapshot
        vim.api.nvim_buf_delete(buf, { force = true })
        assert.is_true(ok, tostring(err))
        assert.equals(1, calls)
        assert.equals(12, #items)
        for index, item in ipairs(items) do
            assert.equals("heading", item.type)
            assert.equals(index * 3 - 2, item.value.tag_lnum)
        end
    end)

end)
