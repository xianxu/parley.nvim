-- Unit tests for lua/parley/define.lua (pure core).
-- See workshop/issues/000161-inline-term-definition.md and its plan.

local define = require("parley.define")

describe("define.slice_selection", function()
    local lines = { "the quick brown", "fox jumps over", "the lazy dog" }

    it("extracts a single-line span", function()
        -- select "quick" on line 1: 0-based cols [4,8] (inclusive end)
        assert.equals("quick", define.slice_selection(lines, 1, 4, 1, 8))
    end)

    it("extracts a multi-line span joined with newline", function()
        -- "brown" .. "\n" .. "fox"
        assert.equals("brown\nfox", define.slice_selection(lines, 1, 10, 2, 2))
    end)

    it("clamps an end column past line length", function()
        assert.equals("dog", define.slice_selection(lines, 3, 9, 3, 999))
    end)

    it("returns empty string for a reversed/empty span", function()
        assert.equals("", define.slice_selection(lines, 1, 5, 1, 4))
    end)
end)

describe("define.context_for_selection", function()
    local all_lines = {}
    for i = 1, 20 do
        all_lines[i] = "line " .. i
    end
    local parsed = {
        exchanges = {
            { question = { line_start = 3, line_end = 4 }, answer = { line_start = 5, line_end = 8 } },
            { question = { line_start = 10, line_end = 10 }, answer = nil },
        },
    }
    -- injected finder: idx if sel_line within [q.start, (a and a.end or q.end)]
    local function finder(pc, line)
        for i, ex in ipairs(pc.exchanges) do
            local lo = ex.question.line_start
            local hi = (ex.answer and ex.answer.line_end) or ex.question.line_end
            if line >= lo and line <= hi then
                return i, "question"
            end
        end
        return nil, nil
    end

    it("returns the enclosing exchange's lines (question..answer)", function()
        local ctx = define.context_for_selection(parsed, 6, all_lines, finder)
        assert.equals("line 3\nline 4\nline 5\nline 6\nline 7\nline 8", ctx)
    end)

    it("handles an answerless exchange (question only)", function()
        local ctx = define.context_for_selection(parsed, 10, all_lines, finder)
        assert.equals("line 10", ctx)
    end)

    it("falls back to the whole buffer when outside any exchange", function()
        local ctx = define.context_for_selection(parsed, 1, all_lines, finder)
        assert.equals(table.concat(all_lines, "\n"), ctx)
    end)
end)

describe("define.format_definition", function()
    it("composes 'TERM — definition'", function()
        local msg = define.format_definition("ASIN", "Amazon Standard Identification Number.", 200)
        assert.equals("ASIN — Amazon Standard Identification Number.", msg)
    end)

    it("hard-wraps to width", function()
        local msg = define.format_definition("X", string.rep("word ", 30), 40)
        for _, l in ipairs(vim.split(msg, "\n", { plain = true })) do
            assert.is_true(#l <= 40)
        end
    end)

    it("passes nil width through to the shared diagnostic formatter", function()
        local skill_render = require("parley.skill_render")
        local orig = skill_render.format_diagnostic_message
        local captured_width
        skill_render.format_diagnostic_message = function(text, width)
            captured_width = width
            return text
        end
        local ok, err = pcall(function()
            assert.equals("X — word", define.format_definition("X", "word"))
        end)
        skill_render.format_diagnostic_message = orig
        if not ok then error(err) end
        assert.is_nil(captured_width)
    end)

    it("trims a nil/blank definition to a safe string", function()
        assert.equals("X — (no definition)", define.format_definition("X", nil, 80))
    end)
end)

describe("define.bracket_edit", function()
    it("wraps a single-line span into a set_lines edit", function()
        -- "here is ASIN in context": ASIN at 0-based cols 8..11 inclusive
        local e = define.bracket_edit({ "here is ASIN in context" }, 1, 8, 1, 11)
        assert.are.equal(0, e.first0)
        assert.are.equal(1, e.last)
        assert.are.same({ "here is [ASIN] in context" }, e.lines)
    end)

    it("clamps end col past line length", function()
        local e = define.bracket_edit({ "the lazy dog" }, 1, 9, 1, 999)
        assert.are.same({ "the lazy [dog]" }, e.lines)
    end)

    it("wraps a multi-line span", function()
        local e = define.bracket_edit({ "brown fox", "jumps over", "the dog" }, 1, 6, 3, 2)
        assert.are.equal(0, e.first0)
        assert.are.equal(3, e.last)
        assert.are.same({ "brown [fox", "jumps over", "the] dog" }, e.lines)
    end)
end)

describe("define.diagnostic_span_after_bracket", function()
    it("anchors a single-line selection on the selected text after brackets", function()
        local span = define.diagnostic_span_after_bracket(3, 9, 3, 12)
        assert.are.same({
            lnum = 2,
            col = 9,
            end_lnum = 2,
            end_col = 13,
        }, span)
    end)

    it("anchors a multi-line selection without shifting the final line", function()
        local span = define.diagnostic_span_after_bracket(1, 7, 3, 3)
        assert.are.same({
            lnum = 0,
            col = 7,
            end_lnum = 2,
            end_col = 3,
        }, span)
    end)
end)

describe("define durable footnotes", function()
    it("slugifies a definition term into a markdown footnote id", function()
        assert.equals("amazon-standard-identification-number",
            define.footnote_id("Amazon Standard Identification Number"))
        assert.equals("asin", define.footnote_id("ASIN"))
    end)

    it("adds an inline footnote reference and appends a managed footer", function()
        local result = define.apply_definition_footnote(
            { "here is ASIN in context" },
            1, 8, 1, 11,
            "ASIN",
            "Amazon Standard Identification Number."
        )

        assert.are.same({
            "here is ASIN[^asin] in context",
            "",
            "---",
            "",
            "[^asin]: Amazon Standard Identification Number.",
        }, result.lines)
        assert.are.same({ lnum = 0, col = 8, end_lnum = 0, end_col = 19 }, result.diagnostic_span)
        assert.equals("asin", result.id)
        assert.equals("Amazon Standard Identification Number.", result.definition)
    end)

    it("updates an existing managed footnote instead of duplicating it", function()
        local result = define.apply_definition_footnote(
            {
                "ASIN is here",
                "",
                "---",
                "",
                "[^asin]: old definition",
            },
            1, 0, 1, 3,
            "ASIN",
            "Amazon Standard Identification Number."
        )

        assert.are.same({
            "ASIN[^asin] is here",
            "",
            "---",
            "",
            "[^asin]: Amazon Standard Identification Number.",
        }, result.lines)
    end)

    it("updates an existing inline reference without duplicating it", function()
        local result = define.apply_definition_footnote(
            {
                "ASIN[^asin] is here",
                "",
                "---",
                "",
                "[^asin]: old definition",
            },
            1, 0, 1, 3,
            "ASIN",
            "Updated definition."
        )

        assert.are.same({
            "ASIN[^asin] is here",
            "",
            "---",
            "",
            "[^asin]: Updated definition.",
        }, result.lines)
        assert.are.same({ lnum = 0, col = 0, end_lnum = 0, end_col = 11 }, result.diagnostic_span)
    end)

    it("strips only a final managed footnote footer", function()
        local text = table.concat({
            "answer text",
            "",
            "---",
            "",
            "[^asin]: Amazon Standard Identification Number.",
        }, "\n")

        assert.equals("answer text", define.strip_definition_footnote_footer(text))
    end)

    it("preserves ordinary horizontal rules that are not managed footnote footers", function()
        local text = table.concat({
            "answer text",
            "",
            "---",
            "",
            "not a footnote",
        }, "\n")

        assert.equals(text, define.strip_definition_footnote_footer(text))
    end)

    it("reports a dividerless managed footnote footer range from the first definition", function()
        local range = define.managed_footnote_footer_range({
            "answer text",
            "",
            "[^asin]: Amazon Standard Identification Number.",
        })

        assert.are.same({ start_line = 3, end_line = 3 }, range)
    end)

    it("reports a divider-based managed footnote footer range from the first definition", function()
        local range = define.managed_footnote_footer_range({
            "answer text",
            "",
            "---",
            "",
            "[^asin]: Amazon Standard Identification Number.",
        })

        assert.are.same({ start_line = 5, end_line = 5 }, range)
    end)

    it("reports the content trim start at an optional legacy divider", function()
        local start = define.managed_footnote_content_start({
            "answer text",
            "",
            "---",
            "",
            "[^asin]: Amazon Standard Identification Number.",
        })

        assert.equals(3, start)
    end)

    it("reports the content trim start at the first definition without a divider", function()
        local start = define.managed_footnote_content_start({
            "answer text",
            "",
            "[^asin]: Amazon Standard Identification Number.",
        })

        assert.equals(3, start)
    end)

    it("does not report ordinary horizontal rules as managed footnote footers", function()
        local range = define.managed_footnote_footer_range({
            "answer text",
            "",
            "---",
            "",
            "not a footnote",
        })

        assert.is_nil(range)
    end)

    it("keeps earlier horizontal-rule content and strips only the final managed footer", function()
        local text = table.concat({
            "answer text",
            "",
            "---",
            "",
            "ordinary body after a rule",
            "",
            "---",
            "",
            "[^asin]: Amazon Standard Identification Number.",
        }, "\n")

        assert.equals(table.concat({
            "answer text",
            "",
            "---",
            "",
            "ordinary body after a rule",
        }, "\n"), define.strip_definition_footnote_footer(text))
    end)

    it("strips a final dividerless managed footnote footer", function()
        local text = table.concat({
            "answer text",
            "",
            "[^asin]: Amazon Standard Identification Number.",
        }, "\n")

        assert.equals("answer text", define.strip_definition_footnote_footer(text))
    end)

    it("extracts persisted footnote diagnostics from the managed footer", function()
        local diagnostics = define.footnote_diagnostics({
            "here is ASIN[^asin] in context",
            "",
            "[^asin]: Amazon Standard Identification Number.",
        })

        assert.are.same({ {
            id = "asin",
            term = "ASIN",
            definition = "Amazon Standard Identification Number.",
            lnum = 0,
            col = 8,
            end_lnum = 0,
            end_col = 19,
        } }, diagnostics)
    end)

    it("uses a leading quoted footnote term to span a multi-word persisted anchor", function()
        local diagnostics = define.footnote_diagnostics({
            "We optimize against Advertising Cost of Sales[^acos] in the policy.",
            "",
            [=[[^acos]: "Advertising Cost of Sales". Ratio of ad spend to sales revenue.]=],
        })

        assert.are.same({ {
            id = "acos",
            term = "Advertising Cost of Sales",
            definition = "Ratio of ad spend to sales revenue.",
            lnum = 0,
            col = 20,
            end_lnum = 0,
            end_col = 52,
        } }, diagnostics)
    end)

    it("uses a leading backquoted footnote term to span a multi-word persisted anchor", function()
        local diagnostics = define.footnote_diagnostics({
            "We optimize against Advertising Cost of Sales[^acos] in the policy.",
            "",
            "[^acos]: `Advertising Cost of Sales`. Ratio of ad spend to sales revenue.",
        })

        assert.are.same({ {
            id = "acos",
            term = "Advertising Cost of Sales",
            definition = "Ratio of ad spend to sales revenue.",
            lnum = 0,
            col = 20,
            end_lnum = 0,
            end_col = 52,
        } }, diagnostics)
    end)

    it("matches a structured term already enclosed in body quotes", function()
        local diagnostics = define.footnote_diagnostics({
            [=[He called it "Advertising Cost of Sales"[^acos] in the transcript.]=],
            "",
            [=[[^acos]: "Advertising Cost of Sales". Ratio of ad spend to sales revenue.]=],
        })

        assert.are.same({ {
            id = "acos",
            term = "Advertising Cost of Sales",
            definition = "Ratio of ad spend to sales revenue.",
            lnum = 0,
            col = 14,
            end_lnum = 0,
            end_col = 47,
        } }, diagnostics)
    end)

    it("falls back to contiguous-token anchors when the structured term is not before the reference", function()
        local diagnostics = define.footnote_diagnostics({
            "We optimize against ACOS[^acos] in the policy.",
            "",
            [=[[^acos]: "Advertising Cost of Sales". Ratio of ad spend to sales revenue.]=],
        })

        assert.are.same({ {
            id = "acos",
            term = "Advertising Cost of Sales",
            definition = "Ratio of ad spend to sales revenue.",
            lnum = 0,
            col = 20,
            end_lnum = 0,
            end_col = 31,
        } }, diagnostics)
    end)

    it("uses the footnote id slug to recover an unstructured multi-word anchor", function()
        local diagnostics = define.footnote_diagnostics({
            "Lambda runs serverless functions[^serverless-functions] without servers.",
            "",
            "[^serverless-functions]: Function-as-a-service compute without server management.",
        })

        assert.are.same({ {
            id = "serverless-functions",
            term = "serverless functions",
            definition = "Function-as-a-service compute without server management.",
            lnum = 0,
            col = 12,
            end_lnum = 0,
            end_col = 55,
        } }, diagnostics)
    end)

    it("matches slug-derived anchors case-insensitively while preserving typed body text", function()
        local diagnostics = define.footnote_diagnostics({
            "Lambda runs Serverless Functions[^serverless-functions] without servers.",
            "",
            "[^serverless-functions]: Function-as-a-service compute without server management.",
        })

        assert.are.same({ {
            id = "serverless-functions",
            term = "Serverless Functions",
            definition = "Function-as-a-service compute without server management.",
            lnum = 0,
            col = 12,
            end_lnum = 0,
            end_col = 55,
        } }, diagnostics)
    end)

    it("extracts every inline reference to a managed footnote", function()
        local diagnostics = define.footnote_diagnostics({
            "ASIN[^asin] first, then SKU[^asin] second",
            "",
            "---",
            "",
            "[^asin]: Amazon Standard Identification Number.",
        })

        assert.are.equal(2, #diagnostics)
        assert.are.same({
            id = "asin",
            term = "ASIN",
            definition = "Amazon Standard Identification Number.",
            lnum = 0,
            col = 0,
            end_lnum = 0,
            end_col = 11,
        }, diagnostics[1])
        assert.are.same({
            id = "asin",
            term = "SKU",
            definition = "Amazon Standard Identification Number.",
            lnum = 0,
            col = 24,
            end_lnum = 0,
            end_col = 34,
        }, diagnostics[2])
    end)

    it("treats the first footnote definition as the footer even with trailing text", function()
        local diagnostics = define.footnote_diagnostics({
            "ASIN[^asin] in body",
            "",
            "[^asin]: Amazon Standard Identification Number.",
            "",
            "trailing body text",
        })

        assert.are.same({ {
            id = "asin",
            term = "ASIN",
            definition = "Amazon Standard Identification Number.",
            lnum = 0,
            col = 0,
            end_lnum = 0,
            end_col = 11,
        } }, diagnostics)
    end)
end)
