-- Unit tests for lua/parley/comment/view.lua (#312): the PURE geometry of 🤖
-- markers on one line — where each marker is, its anchor and its turns.
-- #386: nothing is hidden, so a marker reads as its full text.
local view = require("parley.comment.view")

local function sub(line, r) return line:sub(r[1] + 1, r[2]) end

describe("comment.view.layout", function()
    it("hides nothing: a marker carries no hidden or reply ranges (#386)", function()
        for _, line in ipairs({
            "see 🤖[why?]{because}[ok] here", "🤖[why?]{because}", "a 🤖{insert this} b",
            "the 🤖<quick fox>[too cute]{agree}[more] jumps", "x 🤖~old~{new} y", "a 🤖<X> b",
        }) do
            for _, m in ipairs(view.layout(line)) do
                assert.is_nil(m.hidden, line)
                assert.is_nil(m.reply, line)
            end
        end
    end)
    it("a marker spans its whole text", function()
        local line = "see 🤖[why?]{because}[ok] here"
        local m = view.layout(line)[1]
        assert.equals("🤖[why?]{because}[ok]", line:sub(m.start + 1, m.stop))
    end)
    it("quoted names X as its anchor", function()
        local line = "the 🤖<quick fox>[too cute]{agree}[more] jumps"
        local m = view.layout(line)[1]
        assert.equals("quoted", m.kind)
        assert.equals("quick fox", sub(line, m.visible))
        assert.equals("ParleyReviewQuoted", m.visible[3])
    end)
    it("strike names D as its anchor", function()
        local line = "x 🤖~old~{new} y"
        local m = view.layout(line)[1]
        assert.equals("old", sub(line, m.visible))
        assert.equals("ParleyReviewStrike", m.visible[3])
    end)
    it("an empty anchor has nothing to color", function()
        assert.is_nil(view.layout("🤖<>[c]")[1].visible)
    end)
    it("colors each turn's brackets by speaker", function()
        local line = "🤖[a]{b}[c]"
        local hl = {}
        for _, t in ipairs(view.layout(line)[1].turns_hl) do
            hl[#hl + 1] = line:sub(t[1] + 1, t[2]) .. "=" .. t[3]
        end
        assert.same({ "[a]=ParleyReviewUser", "{b}=ParleyReviewAgent", "[c]=ParleyReviewUser" }, hl)
    end)
    it("an unclosed opener is broken", function()
        local m = view.layout("start 🤖[never closed")[1]
        assert.is_true(m.broken)
        assert.is_nil(m.turns_hl)
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
        local line = "🤖[c1] and 🤖<A>[c2]"
        local ms = view.layout(line)
        assert.equals(2, #ms)
        assert.equals("🤖[c1]", line:sub(ms[1].start + 1, ms[1].stop))
        assert.equals("A", sub(line, ms[2].visible))
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
                for _, t in ipairs(m.turns_hl or {}) do spans[#spans + 1] = t end
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
