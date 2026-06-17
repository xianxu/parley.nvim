-- Unit tests for lua/parley/review.lua — parse_markers
-- (Edit-application coverage lives in skill_edits_spec + tools_builtin_propose_edits_spec.)

local review = require("parley.review")

describe("parse_markers", function()
    it("parses a human-initiated marker (ready)", function()
        local markers = review.parse_markers({ "Hello 🤖[fix this] world" })
        assert.equals(1, #markers)
        assert.equals(0, markers[1].line)
        assert.equals(1, #markers[1].sections)
        assert.equals("user", markers[1].sections[1].type)
        assert.equals("fix this", markers[1].sections[1].text)
        assert.is_true(markers[1].ready)
        assert.is_false(markers[1].pending)
    end)

    it("parses an agent-initiated marker (pending)", function()
        local markers = review.parse_markers({ "🤖{typo here}" })
        assert.equals(1, #markers)
        assert.equals(1, #markers[1].sections)
        assert.equals("agent", markers[1].sections[1].type)
        assert.is_false(markers[1].ready)
        assert.is_true(markers[1].pending)
    end)

    it("agent-initiated with human response is ready", function()
        local markers = review.parse_markers({ "🤖{typo here}[ok fix it]" })
        assert.equals(1, #markers)
        assert.equals(2, #markers[1].sections)
        assert.is_true(markers[1].ready)
        assert.is_false(markers[1].pending)
    end)

    it("human comment with agent question is pending", function()
        local markers = review.parse_markers({ "🤖[comment]{which part?}" })
        assert.equals(1, #markers)
        assert.equals(2, #markers[1].sections)
        assert.is_false(markers[1].ready)
        assert.is_true(markers[1].pending)
    end)

    it("full round-trip ending with human is ready", function()
        local markers = review.parse_markers({ "🤖[offensive]{which part?}[the joke]" })
        assert.equals(1, #markers)
        assert.equals(3, #markers[1].sections)
        assert.is_true(markers[1].ready)
    end)

    it("full round-trip ending with agent is pending", function()
        local markers = review.parse_markers({ "🤖{finding}[noted]{more detail?}" })
        assert.equals(1, #markers)
        assert.equals(3, #markers[1].sections)
        assert.is_true(markers[1].pending)
    end)

    it("empty agent section is not pending", function()
        local markers = review.parse_markers({ "🤖{}" })
        assert.equals(1, #markers)
        assert.is_false(markers[1].pending)
        assert.is_false(markers[1].ready)
    end)

    it("empty user section is not ready", function()
        local markers = review.parse_markers({ "🤖{finding}[]" })
        assert.equals(1, #markers)
        assert.is_false(markers[1].ready)
        assert.is_false(markers[1].pending)
    end)

    it("handles multiple markers on the same line", function()
        local markers = review.parse_markers({ "🤖[first] text 🤖[second]" })
        assert.equals(2, #markers)
        assert.equals("first", markers[1].sections[1].text)
        assert.equals("second", markers[2].sections[1].text)
    end)

    it("handles markers on different lines", function()
        local markers = review.parse_markers({
            "Line one 🤖[fix this]",
            "Line two is fine",
            "Line three 🤖{rewrite}",
        })
        assert.equals(2, #markers)
        assert.equals(0, markers[1].line)
        assert.equals(2, markers[2].line)
        assert.is_true(markers[1].ready)
        assert.is_true(markers[2].pending)
    end)

    it("skips markers inside fenced code blocks", function()
        local markers = review.parse_markers({
            "Before",
            "```",
            "🤖[inside code fence]",
            "```",
            "🤖[outside code fence]",
        })
        assert.equals(1, #markers)
        assert.equals(4, markers[1].line)
        assert.equals("outside code fence", markers[1].sections[1].text)
    end)

    it("skips markers inside fenced code blocks with language tag", function()
        local markers = review.parse_markers({
            "```lua",
            "🤖{inside}",
            "```",
            "🤖{outside}",
        })
        assert.equals(1, #markers)
        assert.equals("outside", markers[1].sections[1].text)
    end)

    it("skips markers inside inline code spans", function()
        local markers = review.parse_markers({ "Use `🤖[not a marker]` for examples" })
        assert.equals(0, #markers)
    end)

    it("skips markers inside double-backtick inline code", function()
        local markers = review.parse_markers({ "Use ``🤖{not a marker}`` for examples" })
        assert.equals(0, #markers)
    end)

    it("parses markers outside inline code on same line", function()
        local markers = review.parse_markers({ "`code` then 🤖[real marker]" })
        assert.equals(1, #markers)
        assert.equals("real marker", markers[1].sections[1].text)
    end)

    it("handles unclosed code fence (extends to end)", function()
        local markers = review.parse_markers({
            "```",
            "🤖[inside unclosed]",
            "more text",
        })
        assert.equals(0, #markers)
    end)

    it("handles nested brackets in user comment", function()
        local markers = review.parse_markers({ "🤖[comment with [nested] brackets]" })
        assert.equals(1, #markers)
        assert.equals("comment with [nested] brackets", markers[1].sections[1].text)
    end)

    it("handles nested curly braces in agent section", function()
        local markers = review.parse_markers({ "🤖{question with {nested} braces}[ok]" })
        assert.equals(2, #markers[1].sections)
        assert.equals("question with {nested} braces", markers[1].sections[1].text)
    end)

    it("returns empty list when no markers present", function()
        local markers = review.parse_markers({ "Just normal text", "Nothing to see here" })
        assert.equals(0, #markers)
    end)

    it("ignores 🤖 not followed by brackets", function()
        local markers = review.parse_markers({ "The character 🤖 alone" })
        assert.equals(0, #markers)
    end)

    it("captures the raw marker text", function()
        local markers = review.parse_markers({ "text 🤖{comment}[response] more" })
        assert.equals("🤖{comment}[response]", markers[1].raw)
    end)

    it("records correct column position", function()
        -- "text " is 5 bytes, so 🤖 starts at byte 6 (0-indexed: 5)
        local markers = review.parse_markers({ "text 🤖[finding]" })
        assert.equals(5, markers[1].col)
    end)

    -- ── <quoted-body> first-slot semantics (#123) ──────────────────────
    it("parses 🤖<Q>[U] — quoted body + ready human turn", function()
        local markers = review.parse_markers({ "🤖<the term>[what is this?]" })
        assert.equals(1, #markers)
        local m = markers[1]
        assert.is_not_nil(m.quoted)
        assert.equals("the term", m.quoted.text)
        assert.equals(1, #m.sections)
        assert.equals("user", m.sections[1].type)
        assert.equals("what is this?", m.sections[1].text)
        assert.is_true(m.ready)
        assert.is_false(m.pending)
    end)

    it("parses 🤖<Q>{A} — quoted body + pending agent turn", function()
        local markers = review.parse_markers({ "🤖<phrase>{rewrite suggestion}" })
        assert.equals(1, #markers)
        assert.equals("phrase", markers[1].quoted.text)
        assert.equals(1, #markers[1].sections)
        assert.equals("agent", markers[1].sections[1].type)
        assert.is_true(markers[1].pending)
        assert.is_false(markers[1].ready)
    end)

    it("parses 🤖<Q> alone — quoted body, no sections (idle)", function()
        local markers = review.parse_markers({ "🤖<just a quote>" })
        assert.equals(1, #markers)
        assert.equals("just a quote", markers[1].quoted.text)
        assert.equals(0, #markers[1].sections)
        assert.is_false(markers[1].ready)
        assert.is_false(markers[1].pending)
    end)

    it("parses empty 🤖<>[U]", function()
        local markers = review.parse_markers({ "🤖<>[hi]" })
        assert.equals(1, #markers)
        assert.is_not_nil(markers[1].quoted)
        assert.equals("", markers[1].quoted.text)
        assert.equals(1, #markers[1].sections)
        assert.is_true(markers[1].ready)
    end)

    it("parses 🤖~D~ strike marker (deletion proposal, never ready)", function()
        local markers = review.parse_markers({ "before 🤖~obsolete~ after" })
        assert.equals(1, #markers)
        assert.is_not_nil(markers[1].strike)
        assert.equals("obsolete", markers[1].strike.text)
        assert.is_nil(markers[1].quoted)
        assert.is_false(markers[1].ready)
        assert.is_false(markers[1].pending)
    end)

    it("skips 🤖~D~ inside fenced code blocks", function()
        local markers = review.parse_markers({
            "```",
            "🤖~inside fence~",
            "```",
            "🤖~outside fence~",
        })
        assert.equals(1, #markers)
        assert.equals(3, markers[1].line)
        assert.equals("outside fence", markers[1].strike.text)
    end)

    it("parses chain 🤖<Q>[U1]{A1}[U2]", function()
        local markers = review.parse_markers({ "🤖<term>[what?]{a thing}[ah]" })
        assert.equals(1, #markers)
        assert.equals("term", markers[1].quoted.text)
        assert.equals(3, #markers[1].sections)
        assert.equals("user", markers[1].sections[1].type)
        assert.equals("agent", markers[1].sections[2].type)
        assert.equals("user", markers[1].sections[3].type)
        assert.is_true(markers[1].ready)
    end)

    it("handles nested angle brackets in quoted body", function()
        local markers = review.parse_markers({ "🤖<text with <inner> bits>[ok]" })
        assert.equals(1, #markers)
        assert.equals("text with <inner> bits", markers[1].quoted.text)
    end)

    it("marker without <> has quoted = nil", function()
        local markers = review.parse_markers({ "🤖[plain feedback]" })
        assert.equals(1, #markers)
        assert.is_nil(markers[1].quoted)
    end)

    it("does not recognize <> after [] / {} as quoted body", function()
        -- After an opening section, the parser stops at the first non-bracket char.
        -- <y> following ] is plain text, not a quoted body.
        local markers = review.parse_markers({ "🤖[x]<y>" })
        assert.equals(1, #markers)
        assert.is_nil(markers[1].quoted)
        assert.equals(1, #markers[1].sections)
        assert.equals("x", markers[1].sections[1].text)
    end)

    it("captures raw marker text including <>", function()
        local markers = review.parse_markers({ "x 🤖<q>[u]{a} y" })
        assert.equals("🤖<q>[u]{a}", markers[1].raw)
    end)
end)

describe("parse_markers multi-line (#000125)", function()
    it("parses a {} agent section that spans lines (pending)", function()
        local markers = review.parse_markers({
            "### 🤖{2026-05-29 — local-only brains",
            "",
            "body paragraph ends here.}",
        })
        assert.equals(1, #markers)
        assert.equals(0, markers[1].line)   -- opener line (the heading)
        assert.equals(4, markers[1].col)    -- 0-based col of 🤖 after "### "
        assert.is_true(markers[1].pending)
        assert.equals(1, #markers[1].sections)
        assert.equals("agent", markers[1].sections[1].type)
        assert.equals("2026-05-29 — local-only brains\n\nbody paragraph ends here.", markers[1].sections[1].text)
    end)

    it("parses a [] human section that spans lines (ready)", function()
        local markers = review.parse_markers({
            "prose 🤖[please rewrite this",
            "across two lines]",
        })
        assert.equals(1, #markers)
        assert.is_true(markers[1].ready)
        assert.equals("please rewrite this\nacross two lines", markers[1].sections[1].text)
    end)

    it("parses a <> quoted body that spans lines", function()
        local markers = review.parse_markers({
            "🤖<the exact phrase",
            "continued>[fix it]",
        })
        assert.equals(1, #markers)
        assert.is_not_nil(markers[1].quoted)
        assert.equals("the exact phrase\ncontinued", markers[1].quoted.text)
        assert.is_true(markers[1].ready)
    end)

    it("matches nested braces across lines", function()
        local markers = review.parse_markers({
            "🤖{outer {inner",
            "still inner} outer}",
        })
        assert.equals(1, #markers)
        assert.equals("outer {inner\nstill inner} outer", markers[1].sections[1].text)
    end)

    it("does NOT recognize an unterminated opener (graceful fallback)", function()
        local markers = review.parse_markers({
            "🤖{never closes",
            "still open",
            "and on and on",
        })
        assert.equals(0, #markers)
    end)

    it("runaway guard: close beyond the line budget is not matched", function()
        local lines = { "🤖{open" }
        for _ = 1, 60 do table.insert(lines, "filler") end  -- > MULTILINE_LINE_BUDGET (50)
        table.insert(lines, "close}")
        local markers = review.parse_markers(lines)
        assert.equals(0, #markers)
    end)

    it("a } inside a fenced code block does not close a prose marker", function()
        local markers = review.parse_markers({
            "🤖{question about code",
            "```lua",
            "local x = {}",   -- the } here must NOT close the marker
            "```",
            "real close here}",
        })
        assert.equals(1, #markers)
        assert.is_true(markers[1].pending)
        -- section text spans through the fence to the real close
        assert.is_truthy(markers[1].sections[1].text:find("real close here", 1, true))
    end)

    it("a } inside an inline-code span does not close a prose marker", function()
        local markers = review.parse_markers({
            "🤖{see `foo}` then",
            "really close}",
        })
        assert.equals(1, #markers)
        assert.equals("see `foo}` then\nreally close", markers[1].sections[1].text)
    end)

    it("~~ strike stays single-line: an unterminated ~ across lines is not a strike", function()
        local markers = review.parse_markers({
            "🤖~delete this",
            "but tilde never closes on this line",
        })
        assert.equals(0, #markers)
    end)

    it("budget is per-section: a 2-section marker may total > budget lines", function()
        -- Each section stays under the 50-line budget, but the marker as a whole
        -- spans ~70 lines. This pins the per-section reset (see lesson #5) — the
        -- runaway guard bounds a single *stray* opener, not a well-formed marker.
        local lines = { "🤖[" }
        for _ = 1, 35 do table.insert(lines, "u") end
        table.insert(lines, "]{")            -- close [], open {} contiguously
        for _ = 1, 35 do table.insert(lines, "a") end
        table.insert(lines, "}")
        local markers = review.parse_markers(lines)
        assert.equals(1, #markers)
        assert.equals(2, #markers[1].sections)
        assert.is_true(markers[1].pending)
    end)

    it("first marker terminated, a second marker after it is still found", function()
        local markers = review.parse_markers({
            "🤖{first spans",
            "to here} and then 🤖[second]",
        })
        assert.equals(2, #markers)
        assert.is_true(markers[1].pending)
        assert.equals(0, markers[1].line)   -- first opener on line 0
        assert.is_true(markers[2].ready)
        assert.equals(1, markers[2].line)   -- second marker on line 1
        assert.equals("second", markers[2].sections[1].text)
    end)
end)
