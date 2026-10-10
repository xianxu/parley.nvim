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
