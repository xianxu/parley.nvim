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
    it("bare human chain shows 🤖[…]", function()
        assert.equals("see 🤖[…] here", shown("see 🤖[why?]{because}[ok] here"))
    end)
    it("single human turn shows 🤖[…]", function()
        assert.equals("🤖[…]", shown("🤖[why?]"))
    end)
    it("a one-char turn still shows 🤖[…]", function()
        assert.equals("🤖[…]", shown("🤖[a]"))
    end)
    it("empty 🤖[] stays as typed", function()
        assert.equals("🤖[]", shown("🤖[]"))
    end)
    it("bare robot proposal shows 🤖{…}", function()
        assert.equals("a 🤖{…} b", shown("a 🤖{insert this}[hm] b"))
    end)
    it("quoted shows only X, highlighted", function()
        local line = "the 🤖<quick fox>[too cute]{agree} jumps"
        assert.equals("the quick fox jumps", shown(line))
        local m = view.layout(line)[1]
        assert.equals("quoted", m.kind)
        assert.equals("quick fox", line:sub(m.visible[1] + 1, m.visible[2]))
        assert.equals("ParleyReviewQuoted", m.visible[3])
    end)
    it("strike shows only D with strike highlight", function()
        local line = "x 🤖~old~{new} y"
        assert.equals("x old y", shown(line))
        assert.equals("ParleyReviewStrike", view.layout(line)[1].visible[3])
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
        assert.equals("🤖[…] and A", shown("🤖[c1] and 🤖<A>[c2]"))
    end)
    it("an empty anchor hides nothing", function()
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

describe("comment.view.snap", function()
    local line = "ab 🤖<X>[c]{d} z"
    local ms = view.layout(line)
    local h1, h2 = ms[1].hidden[1], ms[1].hidden[2]
    local max = #line - 1
    it("moving right into a hidden range lands past it", function()
        assert.equals(h1[2], view.snap(ms, h1[1] - 1, h1[1], max)) -- onto X
        assert.equals(h2[2], view.snap(ms, h2[1] - 1, h2[1], max)) -- past the chain
    end)
    it("moving left into a hidden range lands before it", function()
        assert.equals(h2[1] - 1, view.snap(ms, h2[2], h2[2] - 1, max)) -- onto X
    end)
    it("never rests on the first byte of a hidden range", function()
        assert.is_not_nil(view.snap(ms, 0, h1[1], max))
        local l = "🤖[hidden text]"
        local bare = view.layout(l)
        assert.is_not_nil(view.snap(bare, 0, bare[1].hidden[1][1], #l - 1))
    end)
    it("crosses adjacent hidden ranges (bare chain …, closer)", function()
        local l = "🤖[abc] z"
        local b = view.layout(l)
        assert.equals(b[1].stop, view.snap(b, b[1].hidden[1][1] - 1, b[1].hidden[1][1], #l - 1))
    end)
    it("falls back to the other side at line end", function()
        local l = "z 🤖[abc]"
        local b = view.layout(l)
        local to = view.snap(b, b[1].hidden[1][1] - 1, b[1].hidden[1][1], #l - 1)
        assert.equals(b[1].hidden[1][1] - 1, to) -- the visible `[`
    end)
    it("returns nil when no visible byte exists", function()
        local l = "🤖<X>"
        local q = view.layout(l)
        -- only X is visible; a line of nothing but hidden bytes has no rest
        assert.equals(q[1].visible[1], view.snap(q, 0, 0, #l - 1))
    end)
    it("visible text never snaps", function()
        assert.is_nil(view.snap(ms, 0, 1, max))
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
