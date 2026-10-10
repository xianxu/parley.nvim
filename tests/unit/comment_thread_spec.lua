-- Unit tests for lua/parley/comment/thread.lua (#312): a marker's chain laid
-- out one turn per float line and joined back into one single-line marker.
local thread = require("parley.comment.thread")
local drill_in = require("parley.drill_in")

local function marker(raw) return drill_in.parse(raw)[1] end
local function prefix_of(raw)
    local m = marker(raw)
    return raw:sub(1, (m.sections[1] and m.sections[1].byte_start or #raw + 1) - 1)
end

describe("comment.thread", function()
    it("lays out one turn per line with a trailing empty reply", function()
        local lines, roles = thread.to_lines(marker("🤖<X>[why]{because}"))
        assert.same({ "[why]", "{because}", "[]" }, lines)
        assert.same({ "user", "agent", "user" }, roles)
    end)
    it("splits <br> turns across float lines", function()
        local lines, roles = thread.to_lines(marker("🤖[a<br>b]"))
        assert.same({ "[a", "b]", "[]" }, lines)
        assert.same({ "user", "user", "user" }, roles)
    end)
    it("a marker with no turns opens with just the empty reply", function()
        assert.same({ "[]" }, (thread.to_lines(marker("🤖<X>"))))
    end)
    it("round-trips fixed single-line markers", function()
        for _, raw in ipairs({ "🤖[q]", "🤖<X>[q]{a}[q2]", "🤖~D~{N}", "🤖{p}[h]", "🤖[a<br>b]{c}" }) do
            assert.equals(raw, thread.from_lines(prefix_of(raw), (thread.to_lines(marker(raw)))))
        end
    end)
    -- Property: from_lines(prefix, to_lines(m)) == raw over generated
    -- single-line markers (random anchor, 1–4 turns of text drawn from words,
    -- spaces, <br> and balanced [] / {} pairs).
    it("round-trips generated markers", function()
        math.randomseed(312)
        local words = { "a", "b c", "x<br>y", "[n]", "{m}", "é", "t [u] v", "cell\\<br>two" }
        for _ = 1, 500 do
            local prefix = ({ "🤖", "🤖<Q>", "🤖~D~" })[math.random(3)]
            local raw = prefix
            for _ = 1, math.random(1, 4) do
                local user = math.random(2) == 1
                raw = raw .. (user and "[" or "{") .. words[math.random(#words)] .. (user and "]" or "}")
            end
            assert.equals(raw, thread.from_lines(prefix, (thread.to_lines(marker(raw)))), raw)
        end
    end)
    it("appends a multi-line reply as one <br>-encoded turn", function()
        assert.equals("🤖<X>[q]{a}[line1<br>line2]",
            thread.from_lines("🤖<X>", { "[q]", "{a}", "[line1", "line2]" }))
    end)
    it("drops an empty trailing reply", function()
        assert.equals("🤖[q]", thread.from_lines("🤖", { "[q]", "[]" }))
        assert.equals("🤖[q]", thread.from_lines("🤖", { "[q]", "[  ]", "" }))
    end)
    it("rejects unbalanced brackets", function()
        local raw, err = thread.from_lines("🤖", { "[q]", "[oops" })
        assert.is_nil(raw)
        assert.truthy(err)
    end)
    it("rejects stray text between turns", function()
        local raw, err = thread.from_lines("🤖", { "[q]", "loose words", "[r]" })
        assert.is_nil(raw)
        assert.truthy(err)
    end)
end)
