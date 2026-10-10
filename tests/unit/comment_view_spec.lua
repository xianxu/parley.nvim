-- Unit tests for lua/parley/comment/view.lua (#312): the PURE geometry of 🤖
-- markers on one line — what is hidden (with which conceal char), what stays
-- visible, where the cursor may rest.
local view = require("parley.comment.view")

-- Apply hidden ranges (conceal chars) to show what the user sees.
local function shown(line)
    local cuts = {}
    for _, m in ipairs(view.layout(line)) do
        for _, h in ipairs(m.hidden or {}) do cuts[#cuts + 1] = h end
    end
    table.sort(cuts, function(a, b) return a[1] < b[1] end)
    local out, i = {}, 0
    for _, h in ipairs(cuts) do
        out[#out + 1] = line:sub(i + 1, h[1]) .. h[3]
        i = h[2]
    end
    out[#out + 1] = line:sub(i + 1)
    return table.concat(out)
end

describe("comment.view.layout", function()
    it("collapses every turn but a last human one", function()
        assert.equals("see 🤖[…]{…}[ok] here", shown("see 🤖[why?]{because}[ok] here"))
    end)
    it("a chain ending on the robot collapses entirely", function()
        assert.equals("🤖[…]{…}", shown("🤖[why?]{because}"))
        assert.equals("a 🤖{…} b", shown("a 🤖{insert this} b"))
    end)
    it("a lone human turn stays visible while it is being written", function()
        assert.equals("🤖[why?]", shown("🤖[why?]"))
        assert.equals("🤖[a]", shown("🤖[a]"))
        assert.equals("🤖[]", shown("🤖[]"))
    end)
    it("a robot proposal answered by the human", function()
        assert.equals("a 🤖{…}[hm] b", shown("a 🤖{insert this}[hm] b"))
    end)
    it("quoted shows X, the collapsed chain, and the last human turn", function()
        local line = "the 🤖<quick fox>[too cute]{agree}[more] jumps"
        assert.equals("the quick fox[…]{…}[more] jumps", shown(line))
        local m = view.layout(line)[1]
        assert.equals("quoted", m.kind)
        assert.equals("quick fox", line:sub(m.visible[1] + 1, m.visible[2]))
        assert.equals("ParleyReviewQuoted", m.visible[3])
        assert.equals("more", line:sub(m.reply[1] + 1, m.reply[2]))
    end)
    it("a fresh quoted marker shows X[] ready for typing", function()
        assert.equals("a X[] b", shown("a 🤖<X>[] b"))
    end)
    it("strike shows D struck plus the collapsed proposal", function()
        local line = "x 🤖~old~{new} y"
        assert.equals("x old{…} y", shown(line))
        assert.equals("ParleyReviewStrike", view.layout(line)[1].visible[3])
    end)
    it("colors each turn's brackets by speaker", function()
        local line = "🤖[a]{b}[c]"
        local hl = {}
        for _, t in ipairs(view.layout(line)[1].turns_hl) do
            hl[#hl + 1] = line:sub(t[1] + 1, t[2]) .. "=" .. t[3]
        end
        assert.same({ "[a]=ParleyReviewUser", "{b}=ParleyReviewAgent", "[c]=ParleyReviewUser" }, hl)
    end)
    it("an unclosed opener is broken, nothing hidden", function()
        local m = view.layout("start 🤖[never closed")[1]
        assert.is_true(m.broken)
        assert.is_nil(m.hidden)
    end)
    it("a chain ending in an unclosed opener is broken (#125 multi-line cut)", function()
        assert.is_true(view.layout("🤖<X>[open")[1].broken)
        assert.is_true(view.layout("🤖[a]{open")[1].broken)
    end)
    it("an unmatched ~ stays prose", function()
        assert.same({}, view.layout("see 🤖~/path for it"))
    end)
    it("ignores 🤖: chat prefix and plain 🤖", function()
        assert.same({}, view.layout("🤖: hello 🤖 there"))
    end)
    it("ignores markers in inline code", function()
        assert.same({}, view.layout("use `🤖[x]` syntax"))
    end)
    it("handles two markers on one line", function()
        assert.equals("🤖[c1] and A[c2]", shown("🤖[c1] and 🤖<A>[c2]"))
    end)
    it("an empty anchor keeps its delimiters", function()
        assert.equals("🤖<>[c]", shown("🤖<>[c]"))
    end)
    it("quoted-only marker shows X", function()
        assert.equals("a X b", shown("a 🤖<X> b"))
    end)
    -- Property: over generated lines seeded with whole, truncated and nested
    -- markers, every range is in bounds, ranges don't overlap, and every
    -- boundary sits on a UTF-8 char start (never inside 🤖's 4 bytes).
    it("ranges are in-bounds, disjoint, on char boundaries", function()
        local atoms = { "🤖", "🤖", "[", "]", "{", "}", "<", ">", "~", "a", " ", "é", "`" }
        math.randomseed(312)
        local function on_boundary(line, col)
            return col == #line or vim.str_utf_start(line, col + 1) == 0
        end
        for _ = 1, 3000 do
            local parts = {}
            for _ = 1, math.random(0, 14) do parts[#parts + 1] = atoms[math.random(#atoms)] end
            local line = table.concat(parts)
            local spans = {}
            for _, m in ipairs(view.layout(line)) do
                assert.is_true(m.start >= 0 and m.start < m.stop and m.stop <= #line, line)
                for _, h in ipairs(m.hidden or {}) do spans[#spans + 1] = h end
                if m.visible then spans[#spans + 1] = m.visible end
            end
            table.sort(spans, function(a, b) return a[1] < b[1] end)
            local last = 0
            for _, r in ipairs(spans) do
                assert.is_true(r[1] >= last and r[1] <= r[2] and r[2] <= #line, line)
                assert.is_true(on_boundary(line, r[1]) and on_boundary(line, r[2]), line)
                last = r[2]
            end
        end
    end)
end)

describe("comment.view.snap (normal mode)", function()
    local line = "ab 🤖<X>[c]{d} z"
    local ms = view.layout(line)
    local m = ms[1]
    local max = #line - 1
    it("moving right onto the hidden 🤖< lands on X", function()
        assert.equals(m.visible[1], view.snap(ms, m.start - 1, m.start, max))
    end)
    it("moving left onto it lands before the marker", function()
        assert.equals(m.start - 1, view.snap(ms, m.visible[1], m.visible[1] - 1, max))
    end)
    it("never rests inside a collapsed turn — not even its first byte", function()
        local h = m.hidden[3] -- the `d` of {d}
        assert.equals(h[2], view.snap(ms, h[1] - 1, h[1], max))
        assert.equals(h[1] - 1, view.snap(ms, h[2], h[2] - 1, max))
    end)
    it("the brackets and the editable last turn are legal rests", function()
        local l = "🤖[a]{b}[edit me]"
        local b = view.layout(l)
        for col = b[1].reply[1], b[1].reply[2] do
            assert.is_nil(view.snap(b, 0, col, #l - 1))
        end
    end)
    it("a leftward landing backs up to a multibyte char start", function()
        local l = "a 🤖<é>[c] z"
        local q = view.layout(l)
        local h2 = q[1].hidden[2] -- the `>`
        assert.equals(q[1].visible[1], view.snap(q, h2[2], h2[1], #l - 1, l))
    end)
    it("visible text never snaps", function()
        assert.is_nil(view.snap(ms, 0, 1, max))
    end)
end)

describe("comment.view.snap (insert mode: insertion points)", function()
    local function snap(ms, l, prev, col) return view.snap(ms, prev, col, #l, l, true) end
    it("typing in a fresh 🤖[] stays inside its brackets", function()
        local l = "x 🤖[] y"
        local ms = view.layout(l)
        local inside = ms[1].reply[1]
        assert.is_nil(snap(ms, l, inside, inside))
        local typed = "x 🤖[a] y" -- after the first character
        local ms2 = view.layout(typed)
        assert.is_nil(snap(ms2, typed, ms2[1].reply[2], ms2[1].reply[2]))
    end)
    it("before the 🤖 and after the marker are outside it", function()
        local l = "ab 🤖<X>[c]{d} z"
        local ms = view.layout(l)
        assert.is_nil(snap(ms, l, 0, ms[1].start))
        assert.is_nil(snap(ms, l, #l, ms[1].stop))
    end)
    it("both ends of the anchor are inside X", function()
        local l = "ab 🤖<X>[c]{d} z"
        local ms = view.layout(l)
        assert.is_nil(snap(ms, l, 0, ms[1].visible[1]))
        assert.is_nil(snap(ms, l, 0, ms[1].visible[2]))
    end)
    it("points inside a collapsed turn or between turns move to an allowed one", function()
        local l = "🤖[a]{bbb}[last] z"
        local ms = view.layout(l)
        local m = ms[1]
        local inside_b = m.hidden[2][1] + 1
        assert.equals(m.reply[1], snap(ms, l, inside_b - 1, inside_b)) -- rightward → into [last]
        assert.equals(m.start, snap(ms, l, inside_b + 1, inside_b))    -- leftward → before 🤖
    end)
end)

describe("comment.view.marker_at", function()
    local ms = view.layout("ab 🤖[c] z 🤖[x")
    it("finds the marker under the cursor", function()
        assert.equals(ms[1], view.marker_at(ms, ms[1].start))
    end)
    it("ignores prose and broken markers", function()
        assert.is_nil(view.marker_at(ms, 0))
        assert.is_nil(view.marker_at(ms, ms[2].start))
    end)
end)

describe("comment.view.has_marker", function()
    it("is true only for a rendered marker", function()
        assert.is_true(view.has_marker("a 🤖[c] b"))
        assert.is_false(view.has_marker("🤖: chat prefix"))
        assert.is_false(view.has_marker("🤖[unclosed"))
        assert.is_false(view.has_marker("plain"))
    end)
end)
