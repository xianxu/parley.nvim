-- Unit tests for lua/parley/drill_in.lua
-- See workshop/issues/000123-quoted-body-marker-syntax.md for the grammar.

local drill_in = require("parley.drill_in")

describe("drill_in.parse", function()
    it("parses a basic 🤖<T>[Q] drill-in marker", function()
        local markers = drill_in.parse("foo 🤖<Term>[What is this?] bar")
        assert.equals(1, #markers)
        local m = markers[1]
        assert.is_not_nil(m.quoted)
        assert.equals("Term", m.quoted.text)
        assert.equals(1, #m.sections)
        assert.equals("user", m.sections[1].type)
        assert.equals("What is this?", m.sections[1].text)
        assert.is_true(m.has_quoted_body)
        assert.is_true(m.ready)
        assert.is_false(m.pending)
    end)

    it("supports multi-line text inside <> and []", function()
        local markers = drill_in.parse("🤖<multi\nline term>[multi\nline question]")
        assert.equals(1, #markers)
        assert.equals("multi\nline term", markers[1].quoted.text)
        assert.equals("multi\nline question", markers[1].sections[1].text)
        assert.is_true(markers[1].ready)
    end)

    it("flags non-<T> (plain review) markers as has_quoted_body=false", function()
        local markers = drill_in.parse("🤖[just a comment]")
        assert.equals(1, #markers)
        assert.is_false(markers[1].has_quoted_body)
        assert.is_true(markers[1].ready)
    end)

    it("treats legacy 🤖{T}[Q] as plain review syntax (no quoted body)", function()
        -- Pre-#123 drill-ins are now parsed as {agent}[user]: not has_quoted_body.
        local markers = drill_in.parse("🤖{Old}[Q]")
        assert.equals(1, #markers)
        assert.is_false(markers[1].has_quoted_body)
        assert.equals("agent", markers[1].sections[1].type)
        assert.is_true(markers[1].ready)
    end)

    it("classifies pending when last section is non-empty {}", function()
        local markers = drill_in.parse("🤖<T>[Q]{A}")
        assert.equals(1, #markers)
        assert.is_false(markers[1].ready)
        assert.is_true(markers[1].pending)
    end)

    it("returns empty list when no markers", function()
        assert.equals(0, #drill_in.parse("plain text without any markers"))
    end)

    it("returns multiple markers in document order", function()
        local markers = drill_in.parse("🤖<A>[Qa] mid 🤖<B>[Qb]")
        assert.equals(2, #markers)
        assert.equals("A", markers[1].quoted.text)
        assert.equals("B", markers[2].quoted.text)
        assert.is_true(markers[1].byte_start < markers[2].byte_start)
    end)

    -- ── Edge cases (#123 review) ────────────────────────────────────
    it("normalizes empty 🤖<>[U] to no quoted body", function()
        -- Empty <> carries no information — treat it the same as a no-quote
        -- marker so downstream gather/resolve don't have to special-case it.
        local markers = drill_in.parse("🤖<>[ask]")
        assert.equals(1, #markers)
        assert.is_nil(markers[1].quoted)
        assert.is_false(markers[1].has_quoted_body)
        assert.is_true(markers[1].ready)
    end)

    it("ignores 🤖<unclosed [U] (malformed) — no marker emitted", function()
        -- An opening `<` without a matching `>` short-circuits the parser; the
        -- inner `[U]` is never consumed. Pinning this so a future refactor
        -- can't quietly change to recognizing the inner section.
        local markers = drill_in.parse("🤖<noclose [Q]")
        assert.equals(0, #markers)
    end)

    it("`>` inside [] / {} closes the <> early (parser limitation)", function()
        -- find_matching_bracket only depth-tracks the same bracket pair, so a
        -- `>` appearing inside a later `[` is still seen as the closer of `<`.
        -- Result: `🤖<a [b> c]` parses with quoted="a [b" and zero sections.
        -- Pinning this behavior; if it ever needs to change, the test must
        -- be updated explicitly.
        local markers = drill_in.parse("🤖<a [b> c]")
        assert.equals(1, #markers)
        assert.equals("a [b", markers[1].quoted.text)
        assert.equals(0, #markers[1].sections)
    end)

    -- ── ~X~ deletion family (#124 M1) ────────────────────────────────
    it("parses 🤖~D~ as a strike-only marker (deletion proposal)", function()
        local markers = drill_in.parse("foo 🤖~delete me~ bar")
        assert.equals(1, #markers)
        local m = markers[1]
        assert.is_not_nil(m.strike)
        assert.equals("delete me", m.strike.text)
        assert.is_nil(m.quoted)
        assert.equals(0, #m.sections)
        assert.is_false(m.ready)
        assert.is_false(m.pending)
    end)

    it("parses 🤖~D~{N} as strike + agent replacement", function()
        local markers = drill_in.parse("🤖~old~{new}")
        assert.equals(1, #markers)
        assert.equals("old", markers[1].strike.text)
        assert.is_nil(markers[1].quoted)
        assert.equals(1, #markers[1].sections)
        assert.equals("agent", markers[1].sections[1].type)
        assert.equals("new", markers[1].sections[1].text)
    end)

    it("parses 🤖~D~[N] as strike + human replacement", function()
        local markers = drill_in.parse("🤖~old~[new]")
        assert.equals(1, #markers)
        assert.equals("old", markers[1].strike.text)
        assert.equals(1, #markers[1].sections)
        assert.equals("user", markers[1].sections[1].type)
        assert.equals("new", markers[1].sections[1].text)
    end)

    it("parses 🤖~D~[H]{R} chain (strike + dialogue)", function()
        local markers = drill_in.parse("🤖~old~[question]{answer}")
        assert.equals(1, #markers)
        assert.equals("old", markers[1].strike.text)
        assert.equals(2, #markers[1].sections)
        assert.equals("user", markers[1].sections[1].type)
        assert.equals("question", markers[1].sections[1].text)
        assert.equals("agent", markers[1].sections[2].type)
        assert.equals("answer", markers[1].sections[2].text)
    end)

    it("rejects multi-line ~X~ (bounded to a single line to avoid false positives)", function()
        -- Multi-line strike would silently absorb tildes on later lines
        -- (e.g. ~/path), so the lexer stops at \n. Operator marks each
        -- line separately if they need to delete a multi-line span.
        local markers = drill_in.parse("🤖~line one\nline two~")
        assert.equals(0, #markers)
    end)

    it("first ~ wins within a line — `🤖~D~/path` truncates at the path tilde", function()
        -- Pinning the within-line false-positive boundary. If the
        -- operator writes a strike followed by a `~/path` on the same
        -- line, the lexer binds the `~` of `~/` as the closer. Documented
        -- gotcha; mitigations are (a) avoid path tildes adjacent to a
        -- marker, or (b) use `<X>` (which depth-counts) when quoting.
        local markers = drill_in.parse("🤖~old~/path~")
        assert.equals(1, #markers)
        assert.equals("old", markers[1].strike.text)
        -- The trailing `/path~` is plain text — no second marker.
    end)

    it("records byte_end at the closing ~", function()
        -- `x ` = 2 bytes; 🤖 = 4 bytes (pos 3..6); `~D~` = 3 bytes
        -- (pos 7..9). byte_start = 7 (opening ~); byte_end = 9 (closing ~).
        local markers = drill_in.parse("x 🤖~D~ y")
        assert.equals(1, #markers)
        assert.equals(7, markers[1].strike.byte_start)
        assert.equals(9, markers[1].strike.byte_end)
    end)

    it("parses back-to-back strike markers 🤖~A~🤖~B~", function()
        local markers = drill_in.parse("🤖~A~🤖~B~")
        assert.equals(2, #markers)
        assert.equals("A", markers[1].strike.text)
        assert.equals("B", markers[2].strike.text)
        assert.is_true(markers[1].byte_start < markers[2].byte_start)
    end)

    it("normalizes empty 🤖~~[H] to no strike", function()
        -- Same posture as empty <> normalization: empty strike carries no
        -- information, drop it so downstream paths don't special-case it.
        local markers = drill_in.parse("🤖~~[ask]")
        assert.equals(1, #markers)
        assert.is_nil(markers[1].strike)
        assert.equals(1, #markers[1].sections)
        assert.equals("ask", markers[1].sections[1].text)
    end)

    it("ignores 🤖~unclosed [N] (malformed) — no marker emitted", function()
        -- Mirror of the <unclosed case: an opening `~` without a matching
        -- closer short-circuits the parser. Pinning so a refactor can't
        -- silently start recognizing the inner [N].
        local markers = drill_in.parse("🤖~noclose [N]")
        assert.equals(0, #markers)
    end)

    it("<X> and ~Y~ are mutually exclusive — second slot ignored", function()
        -- After `<X>` is consumed, the chain only accepts [/{; a leading `~`
        -- is plain text. Marker = quote-only, no sections.
        local markers = drill_in.parse("🤖<X>~Y~")
        assert.equals(1, #markers)
        assert.equals("X", markers[1].quoted.text)
        assert.is_nil(markers[1].strike)
        assert.equals(0, #markers[1].sections)
    end)

    it("reverse mutual exclusion — 🤖~Y~<X> keeps strike, drops <X>", function()
        local markers = drill_in.parse("🤖~Y~<X>")
        assert.equals(1, #markers)
        assert.equals("Y", markers[1].strike.text)
        assert.is_nil(markers[1].quoted)
        assert.equals(0, #markers[1].sections)
    end)
end)

describe("drill_in.gather_and_strip", function()
    it("converts 🤖<Q>[U] to a block and strips inline to Q", function()
        local blocks, new_text = drill_in.gather_and_strip(
            "this is 🤖<RedShift>[what is this?] cool"
        )
        assert.equals(1, #blocks)
        assert.equals("RedShift", blocks[1].quoted)
        assert.equals(1, #blocks[1].sections)
        assert.equals("what is this?", blocks[1].sections[1].text)
        assert.equals("this is RedShift cool", new_text)
    end)

    it("strips 🤖[U] (no quote) and infers an anchor from preceding prose (#127)", function()
        local blocks, new_text = drill_in.gather_and_strip(
            "preamble 🤖[just ask] tail"
        )
        assert.equals(1, #blocks)
        -- #127: the unquoted marker now carries an inferred anchor (the
        -- preceding prose), not nil. Only one word precedes it here.
        assert.equals("preamble", blocks[1].quoted)
        assert.equals("just ask", blocks[1].sections[1].text)
        -- Inline replacement is still empty — the snippet is NOT re-inserted
        -- (it's already present in the reply); only the marker is removed.
        assert.equals("preamble  tail", new_text)
    end)

    it("strips ready chain 🤖<Q>[U1]{A1}[U2]", function()
        local blocks, new_text = drill_in.gather_and_strip(
            "x 🤖<term>[Q1]{A1}[Q2] y"
        )
        assert.equals(1, #blocks)
        assert.equals("term", blocks[1].quoted)
        assert.equals(3, #blocks[1].sections)
        assert.equals("x term y", new_text)
    end)

    it("strips ready chain without <> (anchor inferred from preceding prose, #127)", function()
        local blocks, new_text = drill_in.gather_and_strip(
            "x 🤖[Q1]{A1}[Q2] y"
        )
        assert.equals(1, #blocks)
        -- #127: unquoted chain gets an inferred anchor ("x" precedes it).
        assert.equals("x", blocks[1].quoted)
        assert.equals(3, #blocks[1].sections)
        assert.equals("x  y", new_text)
    end)

    it("handles multiple ready markers in document order", function()
        local blocks, new_text = drill_in.gather_and_strip("🤖<A>[Qa] mid 🤖<B>[Qb]")
        assert.equals(2, #blocks)
        assert.equals("A", blocks[1].quoted)
        assert.equals("B", blocks[2].quoted)
        assert.equals("A mid B", new_text)
    end)

    it("leaves pending markers and bare {A} annotations untouched", function()
        local blocks, new_text = drill_in.gather_and_strip(
            "🤖{annotation} 🤖<T>[Q] 🤖<T2>[Q2]{A2}"
        )
        assert.equals(1, #blocks)
        assert.equals("T", blocks[1].quoted)
        assert.equals("🤖{annotation} T 🤖<T2>[Q2]{A2}", new_text)
    end)

    it("handles multi-line content correctly", function()
        local blocks, new_text = drill_in.gather_and_strip(
            "x 🤖<multi\nline term>[multi\nline question] y"
        )
        assert.equals(1, #blocks)
        assert.equals("multi\nline term", blocks[1].quoted)
        assert.equals("multi\nline question", blocks[1].sections[1].text)
        assert.equals("x multi\nline term y", new_text)
    end)

    it("returns original text when there are no ready markers", function()
        local input = "plain 🤖<T>{A}"  -- has <> but ends in {} (pending)
        local blocks, new_text = drill_in.gather_and_strip(input)
        assert.equals(0, #blocks)
        assert.equals(input, new_text)
    end)

    -- ── ~X~ markers are NOT gathered (#124 M1) ───────────────────────
    it("leaves 🤖~D~ untouched (deletion proposal, not a question)", function()
        local input = "x 🤖~delete~ y"
        local blocks, new_text = drill_in.gather_and_strip(input)
        assert.equals(0, #blocks)
        assert.equals(input, new_text)
    end)

    it("leaves 🤖~D~[N] untouched even though chain ends in [] (replacement, not a question)", function()
        -- ~D~[N] is a human-authored replacement proposal per spec. The
        -- presence of a trailing [] would normally make it "ready" for
        -- chat-respond, but the strike presence overrides — replacements
        -- are not questions to the agent.
        local input = "x 🤖~old~[new] y"
        local blocks, new_text = drill_in.gather_and_strip(input)
        assert.equals(0, #blocks)
        assert.equals(input, new_text)
    end)
end)

describe("drill_in.gather_edit_plan", function()
    local function apply(text, edits)
        for i = #edits, 1, -1 do
            local edit = edits[i]
            text = text:sub(1, edit.start_byte - 1)
                .. edit.replacement
                .. text:sub(edit.end_byte)
        end
        return text
    end

    local function assert_plan(input, opts, expected_edits, expected_text)
        local blocks, transformed, edits = drill_in.gather_edit_plan(input, opts)
        assert.same(expected_edits, edits)
        assert.equals(expected_text, transformed)
        assert.equals(transformed, apply(input, edits))

        local old_blocks, old_text = drill_in.gather_and_strip(input, opts)
        assert.same(blocks, old_blocks)
        assert.equals(transformed, old_text)
        return blocks
    end

    it("returns a 1-based half-open replacement for an explicit marker", function()
        local blocks = assert_plan(
            "x 🤖<Q>[U] y",
            nil,
            { { start_byte = 3, end_byte = 13, replacement = "Q" } },
            "x Q y"
        )
        assert.equals("Q", blocks[1].quoted)
        assert.equals("U", blocks[1].sections[1].text)
    end)

    it("returns bracket insertions and marker removal for an inferred anchor", function()
        local prose = "alpha beta gamma delta epsilon zeta eta theta iota kappa"
        local input = prose .. " 🤖[ask]"
        local marker_start = #prose + 2
        local blocks = assert_plan(input, { bracket = true }, {
            { start_byte = 1, end_byte = 1, replacement = "[" },
            { start_byte = #prose + 1, end_byte = #input + 1, replacement = "]" },
        }, "[" .. prose .. "]")
        assert.equals(prose, blocks[1].quoted)
        assert.equals(marker_start, drill_in.parse(input)[1].byte_start)
    end)

    it("keeps multiline marker coordinates in the original text", function()
        local input = "x\n🤖<multi\nline>[ask]\ny"
        assert_plan(input, nil, {
            { start_byte = 3, end_byte = 24, replacement = "multi\nline" },
        }, "x\nmulti\nline\ny")
    end)

    it("sorts multiple marker replacements without overlap", function()
        assert_plan("🤖<A>[Qa] mid 🤖<B>[Qb]", nil, {
            { start_byte = 1, end_byte = 12, replacement = "A" },
            { start_byte = 17, end_byte = 28, replacement = "B" },
        }, "A mid B")
    end)

    it("lets the first interacting inferred anchor own decoration without losing later comments", function()
        local prose = "alpha beta gamma delta epsilon zeta eta theta iota kappa"
        local input = prose .. " 🤖[first] 🤖[second]"
        local first_start = #prose + 2
        local first_end = first_start + #"🤖[first]"
        local second_start = first_end + 1
        local blocks = assert_plan(input, { bracket = true }, {
            { start_byte = 1, end_byte = 1, replacement = "[" },
            { start_byte = #prose + 1, end_byte = first_end, replacement = "]" },
            { start_byte = second_start, end_byte = #input + 1, replacement = "" },
        }, "[" .. prose .. "] ")
        assert.equals(2, #blocks)
        assert.equals(prose, blocks[1].quoted)
        assert.equals(prose, blocks[2].quoted)
    end)
end)

-- ─── #127: inferred snippet anchors for unquoted markers ───────────────
describe("drill_in.generate_snippet (#127)", function()
    -- Return the only marker in `text` (helper).
    local function marker_in(text, n)
        local ms = drill_in.parse(text)
        return ms[n or 1]
    end

    -- ── inline: prose precedes the marker on its line ──────────────────
    it("inline: grabs the preceding sentence when ≥10 words are present", function()
        local text = "Germany had been rearming in secret all through the nineteen twenties already 🤖[source?] here"
        assert.equals(
            "Germany had been rearming in secret all through the nineteen twenties already",
            drill_in.generate_snippet(text, marker_in(text))
        )
    end)

    it("inline: a <10-word current sentence extends back across the boundary", function()
        local text = "This matters a lot. It really does 🤖[why?] now."
        -- "It really does" (3) < 10 → prepend "This matters a lot." (4) → 7 words.
        assert.equals(
            "This matters a lot. It really does",
            drill_in.generate_snippet(text, marker_in(text))
        )
    end)

    it("inline: caps at 20 words, keeping the words nearest the marker with a … prefix", function()
        local words = {}
        for i = 1, 25 do table.insert(words, "w" .. i) end
        local text = table.concat(words, " ") .. " 🤖[q] end"
        local last20 = {}
        for i = 6, 25 do table.insert(last20, words[i]) end
        local expect = "… " .. table.concat(last20, " ")
        assert.equals(expect, drill_in.generate_snippet(text, marker_in(text)))
    end)

    it("inline: strips a neighboring marker's raw bytes out of the window", function()
        local text = "context here 🤖<x>[c0] more words after 🤖[c1] end"
        -- The 🤖[c1] window includes the raw 🤖<x>[c0]; it must not leak in.
        assert.equals(
            "context here more words after",
            drill_in.generate_snippet(text, marker_in(text, 2))
        )
    end)

    -- ── standalone: marker is its own blank-separated paragraph ─────────
    it("standalone: anchors to the previous paragraph's first sentence", function()
        local text = "Para one sentence here. More of it.\n\n🤖[comment]\n\nPara two."
        assert.equals(
            "Para one sentence here.",
            drill_in.generate_snippet(text, marker_in(text))
        )
    end)

    it("standalone: degrades to empty when there is no previous prose block", function()
        local text = "🤖[comment]\n\nSome paragraph follows."
        assert.equals("", drill_in.generate_snippet(text, marker_in(text)))
    end)

    -- ── degradation + classification edges ─────────────────────────────
    it("inline at reply start (prose only after the marker) degrades to empty", function()
        local text = "🤖[note] this is the very first line"
        assert.equals("", drill_in.generate_snippet(text, marker_in(text)))
    end)

    it("bare marker mid-paragraph (no blank separation) is treated as inline", function()
        local text = "first line of the paragraph here\n🤖[comment]\nsecond line continues"
        assert.equals(
            "first line of the paragraph here",
            drill_in.generate_snippet(text, marker_in(text))
        )
    end)

    -- ── turn boundaries: never pull an anchor across a speaker prefix ───
    it("standalone: stops at a turn prefix instead of crossing into the user turn", function()
        local text = "💬: tell me about tanks\n\n🤖:[Agent]\n\n🤖[expand here]\n\nTanks mattered a lot."
        -- 🤖:[Agent] header is the marker's own turn start — the user's
        -- question above it must NOT become the agent comment's anchor.
        assert.equals(
            "",
            drill_in.generate_snippet(text, marker_in(text), { boundaries = { "💬:", "🤖:" } })
        )
    end)

    it("standalone: anchors to the prior paragraph within the same turn, not across the header", function()
        local text = "🤖:[Agent]\n\nFirst paragraph of the answer here.\n\n🤖[expand]\n\nsecond"
        assert.equals(
            "First paragraph of the answer here.",
            drill_in.generate_snippet(text, marker_in(text), { boundaries = { "💬:", "🤖:" } })
        )
    end)

    it("forgiving: mis-snaps on an abbreviation period (documented limitation)", function()
        local text = "Dr. Smith presented the findings clearly.\n\n🤖[c]\n\nx"
        -- "Dr." reads as a sentence end; accepted per the meaning-anchor
        -- philosophy (a verbatim near-anchor still routes attention).
        assert.equals("Dr.", drill_in.generate_snippet(text, marker_in(text)))
    end)
end)

-- #127: gather_and_strip end-to-end — quoted unchanged, mixed order, inference.
describe("drill_in.gather_and_strip + inferred anchors (#127)", function()
    it("explicit <Q> is unchanged — no inference for quoted markers (regression)", function()
        local blocks = drill_in.gather_and_strip("lots of prose before 🤖<Q>[ask] and after")
        assert.equals(1, #blocks)
        assert.equals("Q", blocks[1].quoted)
    end)

    it("mixes quoted + unquoted markers in document order, each anchored", function()
        local blocks, new_text = drill_in.gather_and_strip(
            "alpha beta 🤖[c1] gamma delta 🤖<Term>[c2] epsilon"
        )
        assert.equals(2, #blocks)
        assert.equals("alpha beta", blocks[1].quoted) -- inferred
        assert.equals("Term", blocks[2].quoted)        -- explicit
        -- Inferred snippet is NOT re-inserted; explicit quote IS restored.
        assert.equals("alpha beta  gamma delta Term epsilon", new_text)
    end)

    it("threads boundaries through to suppress a cross-turn anchor", function()
        local text = "💬: a question\n\n🤖:[Agent]\n\n🤖[expand]\n\nbody"
        local blocks = drill_in.gather_and_strip(text, { boundaries = { "💬:", "🤖:" } })
        assert.equals(1, #blocks)
        assert.is_nil(blocks[1].quoted) -- no anchor recoverable within the turn
    end)
end)

describe("drill_in.chat_boundaries (#127)", function()
    it("maps the default config prefixes, de-nil'd and ordered", function()
        assert.same(
            { "💬:", "🤖:", "🧠:", "📝:", "🔧:", "📎:", "🌿:" },
            drill_in.chat_boundaries({})
        )
    end)

    it("uses the first element when chat_assistant_prefix is a table", function()
        local b = drill_in.chat_boundaries({ chat_assistant_prefix = { "🤖:", "[{{agent}}]" } })
        assert.equals("🤖:", b[2])
    end)

    it("honors overrides and appends chat_local_prefix when set", function()
        local b = drill_in.chat_boundaries({ chat_user_prefix = "U>", chat_local_prefix = "L>" })
        assert.equals("U>", b[1])
        assert.equals("L>", b[#b]) -- local prefix appended last
    end)
end)

-- #127: generate_snippet reports the byte range of the prose it drew from, so a
-- caller can enclose the span in place.
describe("drill_in.generate_snippet span range (#127)", function()
    it("returns the inline span's absolute byte range", function()
        local text = "preamble words here 🤖[just ask] tail"
        local m = drill_in.parse(text)[1]
        local snip, s, e = drill_in.generate_snippet(text, m)
        assert.equals("preamble words here", snip)
        assert.equals(1, s)                       -- "preamble" starts at byte 1
        assert.equals(19, e)                      -- "here" ends at byte 19
        assert.equals("preamble words here", text:sub(s, e))
    end)

    it("returns the standalone span's byte range (prev paragraph first sentence)", function()
        local text = "Para one here. More of it.\n\n🤖[c]\n\nx"
        local m = drill_in.parse(text)[1]
        local snip, s, e = drill_in.generate_snippet(text, m)
        assert.equals("Para one here.", snip)
        assert.equals("Para one here.", text:sub(s, e)) -- range maps to the verbatim sentence
    end)

    it("returns nil range when no anchor is recoverable", function()
        local text = "🤖[c]\n\nbody"
        local m = drill_in.parse(text)[1]
        local snip, s, e = drill_in.generate_snippet(text, m)
        assert.equals("", snip)
        assert.is_nil(s)
        assert.is_nil(e)
    end)
end)

-- #127: opts.bracket encloses the referenced span in [] in place.
describe("drill_in.gather_and_strip bracket=true (#127)", function()
    it("brackets an explicit <Q> inline as [Q]", function()
        local _, new_text = drill_in.gather_and_strip(
            "this is 🤖<RedShift>[what?] cool", { bracket = true }
        )
        assert.equals("this is [RedShift] cool", new_text)
    end)

    it("brackets an inferred inline span, absorbing the marker into the close", function()
        local blocks, new_text = drill_in.gather_and_strip(
            "preamble words here 🤖[just ask] tail", { bracket = true }
        )
        assert.equals("[preamble words here] tail", new_text)
        assert.equals("preamble words here", blocks[1].quoted) -- next-turn quote stays unbracketed
    end)

    it("brackets a standalone inferred span and removes the marker", function()
        local _, new_text = drill_in.gather_and_strip(
            "Para one here. More of it.\n\n🤖[expand]\n\nnext", { bracket = true }
        )
        -- The prev-paragraph first sentence is enclosed; the marker line empties.
        assert.equals("[Para one here.] More of it.\n\n\n\nnext", new_text)
    end)

    it("default (no bracket) leaves the inline replacement bare", function()
        local _, new_text = drill_in.gather_and_strip("this is 🤖<RedShift>[what?] cool")
        assert.equals("this is RedShift cool", new_text) -- regression: unchanged
    end)

    it("brackets multiple markers (explicit + inferred) in one pass", function()
        local _, new_text = drill_in.gather_and_strip(
            "alpha beta 🤖[c1] gamma delta 🤖<Term>[c2] epsilon", { bracket = true }
        )
        assert.equals("[alpha beta] gamma delta [Term] epsilon", new_text)
    end)
end)

-- ─── §5 resolution table (#124 M2) ─────────────────────────────────────
-- Pure resolve(marker, mode) implementing the spec §5 table:
--   ref=nil, chain=[H]                → "" (both)
--   ref=quote(X), chain=[H]           → X  (both)
--   ref=quote(X), chain=[H]{R}        → X  (both)
--   ref=nil, chain={R}                → R (accept) / "" (reject)
--   ref=nil, chain=[H]{R}             → "" (both)
--   ref=nil, chain={R}[H]             → "" (both)
--   ref=strike(D), chain=∅            → "" (accept) / D  (reject)
--   ref=strike(D), chain={N}          → N (accept) / D  (reject)
--   ref=strike(D), chain=[N]          → N (accept) / D  (reject)
--   long chains                       → anchor's kept text (both)
describe("drill_in.resolve (pure)", function()
    local function only(text)
        local markers = drill_in.parse(text)
        assert.equals(1, #markers, "expected exactly one marker in: " .. text)
        return markers[1]
    end

    it("🤖[H] → empty (both modes)", function()
        local m = only("🤖[hello]")
        assert.equals("", drill_in.resolve(m, "accept"))
        assert.equals("", drill_in.resolve(m, "reject"))
    end)

    it("🤖<X>[H] → X (both modes)", function()
        local m = only("🤖<keep>[asks]")
        assert.equals("keep", drill_in.resolve(m, "accept"))
        assert.equals("keep", drill_in.resolve(m, "reject"))
    end)

    it("🤖<X>[H]{R} → X (both modes, commentary chain discarded)", function()
        local m = only("🤖<keep>[asks]{replies}")
        assert.equals("keep", drill_in.resolve(m, "accept"))
        assert.equals("keep", drill_in.resolve(m, "reject"))
    end)

    it("🤖{R} → R (accept) / empty (reject)", function()
        local m = only("🤖{insert me}")
        assert.equals("insert me", drill_in.resolve(m, "accept"))
        assert.equals("", drill_in.resolve(m, "reject"))
    end)

    it("🤖[H]{R} → empty (both, commentary chain)", function()
        local m = only("🤖[question]{answer}")
        assert.equals("", drill_in.resolve(m, "accept"))
        assert.equals("", drill_in.resolve(m, "reject"))
    end)

    it("🤖{R}[H] → empty (both, commentary chain)", function()
        local m = only("🤖{suggest}[reply]")
        assert.equals("", drill_in.resolve(m, "accept"))
        assert.equals("", drill_in.resolve(m, "reject"))
    end)

    it("🤖~D~ → empty (accept) / D (reject)", function()
        local m = only("🤖~delete me~")
        assert.equals("", drill_in.resolve(m, "accept"))
        assert.equals("delete me", drill_in.resolve(m, "reject"))
    end)

    it("🤖~D~{N} → N (accept) / D (reject)", function()
        local m = only("🤖~old~{new}")
        assert.equals("new", drill_in.resolve(m, "accept"))
        assert.equals("old", drill_in.resolve(m, "reject"))
    end)

    it("🤖~D~[N] → N (accept) / D (reject)", function()
        local m = only("🤖~old~[new]")
        assert.equals("new", drill_in.resolve(m, "accept"))
        assert.equals("old", drill_in.resolve(m, "reject"))
    end)

    it("🤖[H]{R}[H']{R'} (long commentary chain) → empty (both)", function()
        local m = only("🤖[q1]{a1}[q2]{a2}")
        assert.equals("", drill_in.resolve(m, "accept"))
        assert.equals("", drill_in.resolve(m, "reject"))
    end)

    it("🤖<X>[H]{R}[H']{R'} → X (both, anchor wins)", function()
        local m = only("🤖<X>[q1]{a1}[q2]{a2}")
        assert.equals("X", drill_in.resolve(m, "accept"))
        assert.equals("X", drill_in.resolve(m, "reject"))
    end)

    it("🤖~D~{N}[H]{R} (strike + dialogue past proposal) → fall back to base deletion", function()
        -- Only the spec's enumerated forms (~D~, ~D~{N}, ~D~[N]) get the
        -- replacement-on-accept semantics. Longer chains are ambiguous —
        -- e.g. [H]{R} after a strike could be dialogue about whether to
        -- delete at all. Fall back to base deletion to avoid guessing.
        local m = only("🤖~D~{N}[discuss]{further}")
        assert.equals("", drill_in.resolve(m, "accept"))
        assert.equals("D", drill_in.resolve(m, "reject"))
    end)

    it("🤖~D~[H]{R} (strike + dialogue) accept does not splice the human's commentary", function()
        -- Pinning the fix: previously sections[1].text was returned
        -- unconditionally on accept, which would splice "is this right?"
        -- into the prose. Now falls back to base deletion.
        local m = only("🤖~old~[is this right?]{yes, delete it}")
        assert.equals("", drill_in.resolve(m, "accept"))
        assert.equals("old", drill_in.resolve(m, "reject"))
    end)

    -- Additional coverage (per M2 review nit #2): pin edge cases the spec
    -- doesn't enumerate, so a refactor can't quietly change behavior.
    it("🤖<X> (anchor, no chain) → X both modes", function()
        local m = only("🤖<keep me>")
        assert.equals("keep me", drill_in.resolve(m, "accept"))
        assert.equals("keep me", drill_in.resolve(m, "reject"))
    end)

    it("🤖<X>{R} (anchor + agent only) → X both modes", function()
        local m = only("🤖<keep>{suggest}")
        assert.equals("keep", drill_in.resolve(m, "accept"))
        assert.equals("keep", drill_in.resolve(m, "reject"))
    end)

    it("🤖{R}{R'} (consecutive agent sections, no anchor) → empty both", function()
        -- Pinning: not a proposal (proposal is bare {R} only). Two
        -- consecutive {R} blocks are dialogue (or malformed); resolve
        -- to empty rather than silently accept the last one.
        local m = only("🤖{first}{second}")
        assert.equals("", drill_in.resolve(m, "accept"))
        assert.equals("", drill_in.resolve(m, "reject"))
    end)

    it("rejects garbage mode with an assertion", function()
        local m = only("🤖[hello]")
        assert.has_error(function() drill_in.resolve(m, "Accept") end)
        assert.has_error(function() drill_in.resolve(m, nil) end)
    end)
end)

describe("drill_in.accept_at and reject_at", function()
    it("accept at cursor inside 🤖{R} splices in R", function()
        local input = "x 🤖{insert me} y"
        local new_text, m = drill_in.accept_at(input, 7)
        assert.is_not_nil(m)
        assert.equals("x insert me y", new_text)
    end)

    it("reject at cursor inside 🤖{R} removes the marker", function()
        local input = "x 🤖{insert me} y"
        local new_text, m = drill_in.reject_at(input, 7)
        assert.is_not_nil(m)
        assert.equals("x  y", new_text)
    end)

    it("accept at cursor inside 🤖~D~{N} splices in N", function()
        local input = "x 🤖~old~{new} y"
        local new_text, m = drill_in.accept_at(input, 7)
        assert.is_not_nil(m)
        assert.equals("x new y", new_text)
    end)

    it("reject at cursor inside 🤖~D~{N} restores D", function()
        local input = "x 🤖~old~{new} y"
        local new_text, m = drill_in.reject_at(input, 7)
        assert.is_not_nil(m)
        assert.equals("x old y", new_text)
    end)

    it("accept at cursor inside 🤖<X>[H] preserves X", function()
        local input = "x 🤖<keep>[ask] y"
        local new_text, m = drill_in.accept_at(input, 7)
        assert.is_not_nil(m)
        assert.equals("x keep y", new_text)
    end)

    it("returns nil + unchanged text when cursor is outside any marker", function()
        local input = "before 🤖{R} after"
        local new_text, m = drill_in.accept_at(input, 1)
        assert.is_nil(m)
        assert.equals(input, new_text)
        new_text, m = drill_in.reject_at(input, 1)
        assert.is_nil(m)
        assert.equals(input, new_text)
    end)

    it("only touches the marker the cursor sits in (not others)", function()
        local input = "🤖{first} 🤖{second}"
        -- cursor on second marker: "🤖{first} " = 4+1+5+1+1 = 12 bytes; pick 14
        local new_text, m = drill_in.accept_at(input, 14)
        assert.is_not_nil(m)
        assert.equals("🤖{first} second", new_text)
    end)

    it("accepts at the marker's leading 🤖 byte (boundary)", function()
        local input = "x 🤖{R} y"
        -- byte 3 = first byte of 🤖
        local new_text, m = drill_in.accept_at(input, 3)
        assert.is_not_nil(m)
        assert.equals("x R y", new_text)
    end)

    it("accepts at the marker's trailing closing bracket (boundary)", function()
        local input = "x 🤖{R} y"
        -- 🤖=4 + {R}=3 = 7 bytes; marker spans 3..9. cursor at 9 = `}`.
        local new_text, m = drill_in.accept_at(input, 9)
        assert.is_not_nil(m)
        assert.equals("x R y", new_text)
    end)

    it("adjacent markers 🤖{R1}🤖{R2}: cursor on second's 🤖 picks the second", function()
        local input = "🤖{R1}🤖{R2}"
        -- First marker: 🤖=4 + {R1}=4 = 8 bytes (1..8). Second 🤖 starts at 9.
        local new_text, m = drill_in.accept_at(input, 9)
        assert.is_not_nil(m)
        assert.equals("🤖{R1}R2", new_text)
    end)

    it("multi-line replacement positions correctly via 🤖{multi\\nline}", function()
        local input = "before 🤖{line1\nline2} after"
        -- cursor inside the {} somewhere; pick 12 (inside "line1")
        local new_text, m = drill_in.accept_at(input, 12)
        assert.is_not_nil(m)
        assert.equals("before line1\nline2 after", new_text)
    end)

    it("rejects 🤖~D~{N} at cursor restores D", function()
        local input = "x 🤖~old~{new} y"
        local new_text, m = drill_in.reject_at(input, 7)
        assert.is_not_nil(m)
        assert.equals("x old y", new_text)
    end)
end)

describe("drill_in.format_block", function()
    it("formats <Q>[U] as `> [Q]`, blank, then U (#141)", function()
        local lines = drill_in.format_block({
            quoted = "RedShift",
            sections = { { type = "user", text = "what is this?" } },
        })
        assert.same({ "> [RedShift]", "", "what is this?" }, lines)
    end)

    it("formats [U] (no quote) as just U", function()
        local lines = drill_in.format_block({
            quoted = nil,
            sections = { { type = "user", text = "just ask" } },
        })
        assert.same({ "just ask" }, lines)
    end)

    it("brackets the whole multi-line Q: [ on first line, ] on last (#141)", function()
        local lines = drill_in.format_block({
            quoted = "foo\nbar",
            sections = { { type = "user", text = "Q1\nQ2" } },
        })
        assert.same({ "> [foo", "> bar]", "", "Q1", "Q2" }, lines)
    end)

    it("formats <Q>[U1]{A1}[U2] chain with a blank before the prompt (#141)", function()
        local lines = drill_in.format_block({
            quoted = "term",
            sections = {
                { type = "user", text = "U1" },
                { type = "agent", text = "A1" },
                { type = "user", text = "U2" },
            },
        })
        assert.same({
            "> [term]",
            "> User: U1",
            "> Agent: A1",
            "",
            "U2",
        }, lines)
    end)

    it("formats no-quote [U1]{A1}[U2] chain (no leading > line, blank before prompt)", function()
        local lines = drill_in.format_block({
            quoted = nil,
            sections = {
                { type = "user", text = "U1" },
                { type = "agent", text = "A1" },
                { type = "user", text = "U2" },
            },
        })
        assert.same({
            "> User: U1",
            "> Agent: A1",
            "",
            "U2",
        }, lines)
    end)

    it("multi-line chain section continuation lines stay quoted", function()
        local lines = drill_in.format_block({
            quoted = "Q",
            sections = {
                { type = "user", text = "u1 line a\nu1 line b" },
                { type = "agent", text = "a1" },
                { type = "user", text = "final" },
            },
        })
        assert.same({
            "> [Q]",
            "> User: u1 line a",
            "> u1 line b",
            "> Agent: a1",
            "",
            "final",
        }, lines)
    end)
end)

describe("drill_in.format_blocks", function()
    it("joins multiple blocks with a single blank-line separator", function()
        local lines = drill_in.format_blocks({
            { quoted = "A", sections = { { type = "user", text = "Qa" } } },
            { quoted = "B", sections = { { type = "user", text = "Qb" } } },
        })
        assert.same({ "> [A]", "", "Qa", "", "> [B]", "", "Qb" }, lines)
    end)

    it("returns empty table for empty block list", function()
        assert.same({}, drill_in.format_blocks({}))
    end)
end)

describe("drill_in.bracket_at (#141)", function()
    it("returns the [..] span covering the cursor column", function()
        assert.equals("[quoted text]", drill_in.bracket_at("a [quoted text] b", 5))
    end)

    it("includes the brackets when the cursor is on `[` or `]`", function()
        local line = "x [foo] y"
        assert.equals("[foo]", drill_in.bracket_at(line, 3)) -- on [
        assert.equals("[foo]", drill_in.bracket_at(line, 7)) -- on ]
    end)

    it("returns nil when the cursor is outside any bracket", function()
        assert.is_nil(drill_in.bracket_at("a [foo] b", 1))
        assert.is_nil(drill_in.bracket_at("no brackets here", 4))
    end)

    it("returns nil for unbalanced or missing brackets / nil input", function()
        assert.is_nil(drill_in.bracket_at("a [foo", 4))
        assert.is_nil(drill_in.bracket_at(nil, 1))
    end)

    it("picks the pair covering the cursor among multiple", function()
        local line = "[a] [b] [c]"
        assert.equals("[b]", drill_in.bracket_at(line, 6))
        assert.equals("[c]", drill_in.bracket_at(line, 10))
    end)
end)

describe("drill_in.wrap", function()
    it("wraps text as 🤖<T>[]", function()
        assert.equals("🤖<Term>[]", drill_in.wrap("Term"))
    end)

    it("wraps multi-line text", function()
        assert.equals("🤖<line one\nline two>[]", drill_in.wrap("line one\nline two"))
    end)
end)

describe("drill_in.append_blocks", function()
    it("appends with one blank-line separator when lines exist", function()
        local lines = { "💬: my question" }
        local blocks = { { quoted = "Term", sections = { { type = "user", text = "What?" } } } }
        local result = drill_in.append_blocks(lines, blocks)
        assert.same({ "💬: my question", "", "> [Term]", "", "What?" }, result)
    end)

    it("trims trailing empties before adding separator", function()
        local lines = { "💬: question", "", "" }
        local blocks = { { quoted = "T", sections = { { type = "user", text = "Q" } } } }
        local result = drill_in.append_blocks(lines, blocks)
        assert.same({ "💬: question", "", "> [T]", "", "Q" }, result)
    end)

    it("no separator when input lines are empty", function()
        local blocks = { { quoted = "T", sections = { { type = "user", text = "Q" } } } }
        local result = drill_in.append_blocks({}, blocks)
        assert.same({ "> [T]", "", "Q" }, result)
    end)

    it("returns input unchanged when blocks is empty", function()
        assert.same({ "a", "b" }, drill_in.append_blocks({ "a", "b" }, {}))
    end)

    it("joins multiple blocks with internal blank-line separators", function()
        local result = drill_in.append_blocks({ "🤖" }, {
            { quoted = "A", sections = { { type = "user", text = "Qa" } } },
            { quoted = "B", sections = { { type = "user", text = "Qb" } } },
        })
        assert.same({ "🤖", "", "> [A]", "", "Qa", "", "> [B]", "", "Qb" }, result)
    end)
end)

describe("drill_in.narrow_replace_range (#133)", function()
    it("targets only the marker's line range (not the whole buffer)", function()
        local old = { "keep a", "MARKER here", "keep b" }
        local new_text = "keep a\nresolved\nkeep b"
        -- byte_start = the 'M' of MARKER; byte_end = end of that line
        local bs = #("keep a\n") + 1
        local be = #("keep a\nMARKER here")
        local start0, end0, region = drill_in.narrow_replace_range(old, new_text, bs, be)
        assert.are.equal(1, start0) -- 0-based: only line 2 (index 1)
        assert.are.equal(2, end0)
        assert.same({ "resolved" }, region)
        -- applying region over old[start0..end0] reconstructs new_text (lines
        -- before/after the marker are untouched → their decorations ride)
        local rebuilt = { old[1], region[1], old[3] }
        assert.are.equal(new_text, table.concat(rebuilt, "\n"))
    end)

    it("handles a line-count change (resolution adds a line)", function()
        local old = { "x", "M", "y" }
        local new_text = "x\nA\nB\ny" -- marker line 2 → two lines
        local start0, end0, region = drill_in.narrow_replace_range(old, new_text, #("x\n") + 1, #("x\nM"))
        assert.are.equal(1, start0)
        assert.are.equal(2, end0)
        assert.same({ "A", "B" }, region)
    end)
end)
