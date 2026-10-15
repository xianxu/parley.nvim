local candidates = require("parley.reference_candidates")

describe("reference candidates", function()
    it("enumerates Markdown links with the existing byte-span dialect", function()
        local line = "é [src:#12](src:a.lua:2) and [🌿:topic](chat.md)"
        local links = candidates.markdown_links(line)
        assert.equals(2, #links)
        assert.same({ text = "src:#12", url = "src:a.lua:2", start_col = 4, end_col = 25 }, links[1])
        for _, link in ipairs(links) do
            assert.equals("[" .. link.text .. "](" .. link.url .. ")", line:sub(link.start_col, link.end_col))
        end
        assert.same({}, candidates.markdown_links("[empty]() [unclosed](x"))
    end)

    it("keeps wrapped Markdown spans and masks references across continuation rows", function()
        local lines = { "é → [long #370", "  @@hidden@@ label](side.md) and #42" }
        local got = candidates.collect(lines, { first = 1, last = 2 })
        assert.equals(2, #got)
        assert.equals("markdown", got[1].kind)
        assert.equals("side.md", got[1].target)
        assert.equals(1, got[1].row)
        assert.equals(#"é → ", got[1].col)
        assert.equals(2, got[1].end_row)
        assert.equals(lines[2]:find(")", 1, true), got[1].end_col)
        assert.equals(2, got[1].fallback_row)
        assert.equals(lines[2]:find("side.md", 1, true) - 1, got[1].fallback_col)
        assert.equals("[long #370\n  @@hidden@@ label](side.md)", got[1].span)
        assert.equals("#42", got[2].target)
    end)

    it("does not complete wrapped links across blanks, fences, headings or range edges", function()
        for _, middle in ipairs({ "", "   ", "```", "~~~", "## Next" }) do
            local lines = { "[not closed", middle, "label](side.md)" }
            assert.same({}, candidates.collect(lines, { first = 1, last = 3 }))
        end
        assert.same({}, candidates.collect({ "[not closed", "label](side.md)" }, { first = 2, last = 2 }))
        assert.same({}, candidates.collect({ "[not closed", "still open (side.md)" }, { first = 1, last = 2 }))
        for _, next_item in ipairs({ "1. label](side.md)", "- label](side.md)" }) do
            assert.same({}, candidates.collect({ "[not closed", next_item }, { first = 1, last = 2 }))
        end
    end)

    it("confines wrapped spans to transcript markers and preserves plain Markdown fences", function()
        local patterns = require("parley.document.lexical").patterns({})
        for _, field in ipairs({"user_prefix", "assistant_prefix", "summary_prefix", "reasoning_prefix",
            "tool_use_prefix", "tool_result_prefix", "branch_prefix", "local_prefix"}) do
            local lines = {"[unfinished", patterns[field] .. " label](side.md)"}
            assert.same({}, candidates.markdown_spans(lines, {first = 1, last = 2}, {transcript = true}))
            local got = candidates.collect(lines, {first = 1, last = 2}, {transcript = true})
            for _, item in ipairs(got) do assert.is_not.equals("markdown", item.kind) end
            for _, fence in ipairs({"```", "~~~"}) do
                lines = {fence, patterns[field] .. " [long", "label](side.md)", fence}
                assert.same({}, candidates.markdown_spans(lines, {first = 1, last = 4}, {transcript = false}))
                assert.same({}, candidates.collect(lines, {first = 1, last = 4}, {transcript = false}))
            end
        end
    end)

    it("keeps wrapped labels within text paragraphs rather than neighboring Markdown blocks", function()
        for _, boundary in ipairs({"---", "- - -", "***", "* * *", "___", "_ _ _", "===", "=", "--",
            "> quoted", "  > quoted", "#### Heading", "###### Heading"}) do
            local lines = {"[unfinished", boundary, "label](side.md)"}
            assert.same({}, candidates.markdown_spans(lines, {first = 1, last = 3}), boundary)
            assert.same({}, candidates.collect(lines, {first = 1, last = 3}), boundary)
        end
        for _, continuation in ipairs({"= =", "    > text", "    #### text"}) do
            local got = candidates.markdown_spans({"[valid", continuation, "label](side.md)"},
                {first = 1, last = 3}, {transcript = false})
            assert.equals(1, #got, continuation)
        end
        local inline = candidates.collect({"> [inline](side.md)"}, {first = 1, last = 1})
        assert.equals(1, #inline)
        assert.equals("side.md", inline[1].target)
        for _, start in ipairs({"1. [valid", "- [valid", "💬: [valid"}) do
            local got = candidates.markdown_spans({start, "   label](side.md)"}, {first = 1, last = 2})
            assert.equals(1, #got)
            assert.equals("side.md", got[1].target)
        end
    end)

    it("enumerates only closed nonempty @@ spans and retains legacy starts", function()
        local line = "é @@  a@b.md  @@ and @@two.md@@ then @@unterminated"
        local refs = candidates.at_references(line)
        assert.equals(2, #refs)
        assert.equals("a@b.md", refs[1].content)
        assert.equals(4, refs[1].start)
        for _, ref in ipairs(refs) do
            assert.equals(ref.start, ref.start_col)
            assert.matches("^@@.*@@$", line:sub(ref.start_col, ref.end_col))
        end
        assert.same({}, candidates.at_references("@@@@ @@  @@"))
    end)

    it("preserves configurable branch-line parsing and topic cleanup", function()
        assert.same({ path = "chat.md", topic = "topic" }, candidates.branch_ref("🌱:  chat.md: topic ⚠️", "🌱:"))
        assert.same({ path = "chat.md", topic = "" }, candidates.branch_ref("🌱: chat.md", "🌱:"))
        assert.is_nil(candidates.branch_ref(" 🌱: chat.md", "🌱:"))
        assert.is_nil(candidates.branch_ref("🌿: chat.md", "🌱:"))
        assert.is_nil(candidates.branch_ref("🌱:  ", "🌱:"))
    end)

    it("keeps document order and repeated targets while masking nested reference spellings", function()
        local lines = {
            "#9 [@@hidden@@ #3](same.md) @@#4@@ #5 M2",
            "[again](same.md) [src](src:a.lua:3) [🌿:topic](chat.md)",
        }
        local got = candidates.collect(lines, { first = 1, last = 2 })
        local identities = {}
        for _, item in ipairs(got) do
            identities[#identities + 1] = { item.kind, item.row, item.target }
            assert.is_true(item.col >= 0)
            assert.is_true(item.end_col > item.col)
            assert.is_true(item.fallback_col >= item.col and item.fallback_col < item.end_col)
        end
        assert.same({
            { "artifact", 1, "#9" }, { "markdown", 1, "same.md" },
            { "at", 1, "#4" }, { "artifact", 1, "#5 M2" },
            { "markdown", 2, "same.md" }, { "markdown", 2, "src:a.lua:3" },
            { "markdown", 2, "chat.md" },
        }, identities)
        assert.equals("[", lines[1]:sub(got[2].col + 1, got[2].col + 1))
        assert.equals("same.md", lines[1]:sub(got[2].fallback_col + 1, got[2].fallback_col + #got[2].target))
    end)

    it("retains distinct selected spans among mixed Markdown and @@ occurrences", function()
        local line = "@@first@@ then [answer](answer.md) then @@last@@"
        local got = candidates.collect({ line }, { first = 1, last = 1 })
        assert.equals(3, #got)
        assert.equals("@@first@@", line:sub(got[1].col + 1, got[1].end_col))
        assert.equals("[answer](answer.md)", line:sub(got[2].col + 1, got[2].end_col))
        assert.equals("@@last@@", line:sub(got[3].col + 1, got[3].end_col))
    end)

    it("collects a branch path without absorbing a separate link in its topic", function()
        local got = candidates.collect({ "🌱: #42.md: see [answer](answer.md)" },
            { first = 1, last = 1 }, { branch_prefix = "🌱:" })
        assert.equals(2, #got)
        assert.equals("branch", got[1].kind)
        assert.equals("#42.md", got[1].target)
        assert.equals("markdown", got[2].kind)
    end)

    it("masks fenced samples with the shared lexical memo including closing delimiters", function()
        local lines = { "[before](a.md)", "~~~ [opener](x.md)", "[code](x.md) #2", "~~~ [closer](x.md)", "@@after@@" }
        local lexical = require("parley.document.lexical")
        local memo = lexical.code_block_memo(lines, lexical.patterns({}), true)
        local got = candidates.collect(lines, { first = 1, last = #lines }, { in_code = memo })
        assert.equals(2, #got)
        assert.equals("a.md", got[1].target)
        assert.equals("after", got[2].target)
        assert.same(got, candidates.collect(lines, { first = 1, last = #lines }))
    end)

    it("honors range bounds and transcript fence resets", function()
        local lines = { "[outside](x)", "```", "[hidden](x)", "💬: next", "[visible](a)", "[outside](y)" }
        local got = candidates.collect(lines, { first = 2, last = 5 })
        assert.equals(1, #got)
        assert.equals(5, got[1].row)
        assert.same({}, candidates.collect(lines, nil))
    end)

    it("enumerates a large entity without collapsing duplicate destinations", function()
        local lines = {}
        for i = 1, 5000 do lines[i] = "[answer](same.md)" end
        local got = candidates.collect(lines, { first = 1, last = #lines })
        assert.equals(5000, #got)
        assert.equals(5000, got[#got].row)
    end)
end)

describe("reference picker completion", function()
    local function origin()
        return { buf = 3, win = 4, tick = 5, generation = 6 }
    end
    local items = { { target = "first" }, { target = "second" } }

    it("opens the selected occurrence once and releases settled state", function()
        local state = candidates.begin_selection(origin(), items)
        assert.equals("pending", state.tag)
        local settled, effect = candidates.finish_selection(state, { index = 2, current = origin() })
        assert.same({ tag = "settled" }, settled)
        assert.same({ kind = "open", item = items[2] }, effect)
        local again, duplicate = candidates.finish_selection(settled, { index = 1, current = origin() })
        assert.same(settled, again)
        assert.same({ kind = "none" }, duplicate)
    end)

    it("rejects cancellation and every invalid index without a later opening", function()
        for _, event in ipairs({ {}, { index = 0 }, { index = -1 }, { index = 3 }, { index = 1.5 }, { index = "1" } }) do
            event.current = origin()
            local settled, effect = candidates.finish_selection(candidates.begin_selection(origin(), items), event)
            assert.same({ kind = "none" }, effect)
            local _, later = candidates.finish_selection(settled, { index = 1, current = origin() })
            assert.same({ kind = "none" }, later)
        end
    end)

    it("rejects edits, buffer/window switches and superseded command generations", function()
        for _, key in ipairs({ "buf", "win", "tick", "generation" }) do
            local current = origin()
            current[key] = current[key] + 1
            local settled, effect = candidates.finish_selection(candidates.begin_selection(origin(), items), { index = 1, current = current })
            assert.equals("settled", settled.tag)
            assert.same({ kind = "none" }, effect)
        end
    end)

    it("rejects deleted origins and incomplete current snapshots", function()
        local state = candidates.begin_selection(origin(), items)
        local _, missing = candidates.finish_selection(state, { index = 1 })
        assert.same({ kind = "none" }, missing)
        for _, key in ipairs({ "buf", "win", "tick", "generation" }) do
            local current = origin()
            current[key] = nil
            local _, effect = candidates.finish_selection(state, { index = 1, current = current })
            assert.same({ kind = "none" }, effect)
        end
    end)
end)
