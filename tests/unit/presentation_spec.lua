-- presentation (#383): the document's `presentation:` key, and where a round's
-- spans land in the buffer. Pure: plain line tables, no buffer.
local presentation = require("parley.presentation")

local function span(start, finish, old, new, explain)
    return { start = start, ["end"] = finish, old = old, new = new, explain = explain }
end

local function round(spans)
    return { result_hash = "match", spans = spans }
end

describe("presentation.value", function()
    it("reads canonical presence and reports unknown values without consulting a shadowed alias", function()
        for _, value in ipairs({ 'direct', 'propose', '', 'unknown' }) do
            local actual, warnings = presentation.value({ '---', 'presentation: propose',
                'presentation-mode: ' .. value, '---' })
            assert.equals((value == '' or value == 'unknown') and 'highlight' or value, actual)
            assert.is_table(warnings)
            if value == 'unknown' then assert.truthy(table.concat(warnings, ';'):find('unknown', 1, true)) end
        end
    end)

    it("does not let an unrelated processing error change presentation", function()
        local actual = presentation.value({ '---', 'presentation-mode: direct',
            'processing-mode: free-form', 'processing-mode: copy-editing', '---' })
        assert.equals('direct', actual)
    end)

    it("reads the key, and highlights when it is missing or an unknown scalar", function()
        assert.equals("highlight", presentation.value({ "# no frontmatter" }))
        assert.equals("propose", presentation.value({ "---", "presentation: propose", "---" }))
        assert.equals("direct", presentation.value({ "---", 'presentation: "direct"', "---" }))
        assert.equals("highlight", presentation.value({ "---", "presentation: shout", "---" }))
    end)

    it("refuses selected non-string scalar presentations without guessing highlight", function()
        for _, key in ipairs({ "presentation-mode", "presentation" }) do
            for _, value in ipairs({ "42", "true", "null" }) do
                local document = { "---", key .. ": " .. value, "---", "body" }
                local before = vim.deepcopy(document)
                local mode, warnings = presentation.value(document)
                assert.is_nil(mode, document[2])
                assert.is_table(warnings)
                assert.truthy(table.concat(warnings, ";"):find("line 2", 1, true), vim.inspect(warnings))
                assert.same(before, document)
            end
        end
        local mode, warnings = presentation.value({ "---", 'presentation-mode: "42"', "---" })
        assert.equals("highlight", mode, "an unknown string retains the warned-highlight policy")
        assert.truthy(table.concat(warnings, ";"):find("unknown value 42", 1, true), vim.inspect(warnings))
    end)

    it("refuses unsupported header representations with no mode and a named line", function()
        for _, header in ipairs({
            { "metadata:", "  topic: notes" }, { "metadata: |", "  retained text" },
            { "metadata: [one, two]" }, { "metadata: &named retained" }, { "metadata: !text retained" },
        }) do
            local document = { "---" }
            vim.list_extend(document, header)
            vim.list_extend(document, { "presentation-mode: highlight", "---", "body" })
            local before = vim.deepcopy(document)
            local mode, warnings = presentation.value(document)
            assert.is_nil(mode, header[1])
            assert.is_table(warnings)
            assert.truthy(table.concat(warnings, ";"):find("line 2", 1, true), vim.inspect(warnings))
            assert.same(before, document)
        end
        local mode, warnings = presentation.value({ "---", "presentation: propose" })
        assert.is_nil(mode)
        assert.truthy(table.concat(warnings, ";"):find("line ", 1, true), vim.inspect(warnings))
    end)

    it("keeps legacy collaboration maps semantically readable without guessing presentation", function()
        local document = { "---", "collaboration-mode:", "  default: discussion", "  chat: [Questions]",
            "presentation-mode: propose", "---", "# Questions" }
        assert.equals("propose", presentation.value(document))
    end)

    it("reads presentation alongside literal quotes in an already-started root plain scalar", function()
        assert.equals("direct", presentation.value({ "---", 'title: A, "unfinished',
            "presentation-mode: direct", "---", "body" }))
    end)
end)

describe("presentation.kind (#387)", function()
    it("is delete with no new text, add with no old text, change otherwise", function()
        assert.equals("delete", presentation.kind("gone", ""))
        assert.equals("delete", presentation.kind("gone", nil))
        assert.equals("add", presentation.kind("", "new"))
        assert.equals("add", presentation.kind(nil, "new"))
        assert.equals("change", presentation.kind("old", "new"))
    end)
end)

describe("presentation.decorations", function()
    local lines = { "# Title", "the new text here", "tail" }

    it("takes the positions as given when the hash matches", function()
        local d = presentation.decorations(round({ span({ 1, 4 }, { 1, 12 }, "old", "new text", "why") }), lines, "match")
        assert.same({ { lnum = 1, col = 4, end_lnum = 1, end_col = 12, message = "why", kind = "change" } }, d)
    end)

    it("re-anchors by the new text when the hash differs, nearest the old position", function()
        local moved = { "# Title", "inserted", "x", "the new text here", "x new text" }
        local d = presentation.decorations(round({ span({ 1, 4 }, { 1, 12 }, "old", "new text") }), moved, "other")
        assert.same({ { lnum = 3, col = 4, end_lnum = 3, end_col = 12, message = "changed by the agent",
            kind = "change" } }, d)
    end)

    it("drops a span whose new text is gone", function()
        assert.same({}, presentation.decorations(round({ span({ 1, 4 }, { 1, 12 }, "old", "vanished") }), lines, "other"))
    end)

    -- #387: a deletion leaves no trace, matched hash or not.
    it("yields nothing for a deletion", function()
        local r = round({ span({ 2, 0 }, { 2, 0 }, "gone line\nand more", "") })
        assert.same({}, presentation.decorations(r, lines, "match"))
        assert.same({}, presentation.decorations(r, lines, "other"))
    end)

    -- #387: empty old text means added; anything else, changed.
    it("classifies a span with no old text as added, any other as changed", function()
        local d = presentation.decorations(round({
            span({ 1, 4 }, { 1, 12 }, "", "new text"),
            span({ 2, 0 }, { 2, 4 }, "head", "tail"),
        }), lines, "match")
        assert.same({ "add", "change" }, { d[1].kind, d[2].kind })
    end)

    it("keeps a multi-line span's end line", function()
        local d = presentation.decorations(round({ span({ 1, 4 }, { 2, 2 }, "", "new text here\nta") }), lines, "match")
        assert.same({ 1, 4, 2, 2 }, { d[1].lnum, d[1].col, d[1].end_lnum, d[1].end_col })
    end)

    it("re-anchors a matched-hash span whose text isn't there", function()
        -- A hand-edited sidecar: the hash matches but the positions don't.
        local d = presentation.decorations(round({ span({ 0, 0 }, { 0, 8 }, "", "new text") }), lines, "match")
        assert.same({ 1, 4, 1, 12 }, { d[1].lnum, d[1].col, d[1].end_lnum, d[1].end_col })
    end)

    it("places at most MAX_SPANS spans", function()
        local spans = {}
        for i = 1, presentation.MAX_SPANS + 1 do spans[i] = span({ 0, 0 }, { 0, 1 }, "", "#") end
        assert.equals(presentation.MAX_SPANS, #presentation.decorations(round(spans), lines, "match"))
    end)

    -- Couch's positions are untrusted input, even on a hash match: a seeded
    -- random sweep over malformed and out-of-range spans, multibyte and CR text,
    -- and empty or repeated new text. Nothing raises, and every placed position
    -- lies inside the lines.
    it("never raises and never places outside the lines", function()
        math.randomseed(383)
        local function rand(n) return math.random(n) - 1 end
        local junk_seen = 0
        local alphabet = { "a", "b", " ", "é", "\r", "→", "x" }
        local function word(n)
            local out = {}
            for i = 1, n do out[i] = alphabet[rand(#alphabet) + 1] end
            return table.concat(out)
        end
        local junk = { "x", -1, 1.5, {}, { 1 }, { "a", 0 } }
        local function position()
            if rand(5) == 0 then
                junk_seen = junk_seen + 1
                return junk[rand(#junk) + 1]
            end
            return { rand(8) - 1, rand(12) - 1 }
        end
        for _ = 1, 500 do
            local doc = {}
            for i = 1, rand(5) + 1 do doc[i] = word(rand(10)) end
            local spans = {}
            for i = 1, rand(6) do
                local new = rand(4) == 0 and "" or (rand(3) == 0 and doc[1]:sub(1, 2) or word(rand(4)))
                spans[i] = rand(10) == 0 and "junk"
                    or { start = position(), ["end"] = position(), old = rand(9) == 0 and 7 or word(2), new = new,
                        explain = rand(2) == 0 and "e" or nil }
            end
            local ok, out = pcall(presentation.decorations, round(spans), doc, rand(2) == 0 and "match" or "other")
            assert.is_true(ok, tostring(out))
            for _, d in ipairs(out) do
                for _, p in ipairs({ { d.lnum, d.col }, { d.end_lnum, d.end_col } }) do
                    assert.is_true(p[1] >= 0 and p[1] < #doc and p[2] >= 0 and p[2] <= #doc[p[1] + 1],
                        vim.inspect({ d = d, doc = doc }))
                end
                assert.is_true(d.end_lnum > d.lnum or (d.end_lnum == d.lnum and d.end_col >= d.col))
            end
        end
        assert.is_true(junk_seen > 50, "the sweep must reach malformed positions")
    end)
end)
