-- Unit tests for lua/parley/comment/thread.lua (#312): a marker's chain laid
-- out like a parley chat (`💬: ` human, `🤖: ` robot, continuation lines) and
-- joined back into one single-line marker.
local thread = require("parley.comment.thread")
local drill_in = require("parley.drill_in")

local function marker(raw) return drill_in.parse(raw)[1] end
local function prefix_of(raw)
    local m = marker(raw)
    return raw:sub(1, (m.sections[1] and m.sections[1].byte_start or #raw + 1) - 1)
end
local function round_trip(raw)
    local lines, _, appended = thread.to_lines(marker(raw))
    return thread.from_lines(prefix_of(raw), lines, appended)
end

describe("comment.thread", function()
    it("lays out one prefixed turn per line with a trailing reply slot", function()
        local lines, roles = thread.to_lines(marker("🤖<X>[why]{because}"))
        assert.same({ "💬: why", "🤖: because", "💬: " }, lines)
        assert.same({ "user", "agent", "user" }, roles)
    end)
    it("a <br> continues the turn on an unprefixed line", function()
        local lines, roles = thread.to_lines(marker("🤖[a<br>b]{c}"))
        assert.same({ "💬: a", "b", "🤖: c", "💬: " }, lines)
        assert.same({ "user", "user", "agent", "user" }, roles)
    end)
    it("an empty robot turn reads as a bare 🤖:", function()
        assert.same({ "💬: q", "🤖: ", "💬: next", "💬: " }, (thread.to_lines(marker("🤖[q]{}[next]"))))
    end)
    it("a marker with no turns opens with just the reply slot", function()
        assert.same({ "💬: " }, (thread.to_lines(marker("🤖<X>"))))
    end)
    it("an existing empty [] is the reply slot, not doubled (fresh <M-q> marker)", function()
        local lines, _, appended = thread.to_lines(marker("🤖<sel>[]"))
        assert.same({ "💬: " }, lines)
        assert.is_false(appended)
        assert.equals("🤖<sel>[comment]", thread.from_lines("🤖<sel>", { "💬: comment" }, appended))
    end)
    it("keeps a meaningful empty [] (`{R}[]` = go ahead)", function()
        assert.equals("🤖{R}[]", round_trip("🤖{R}[]"))
    end)
    it("round-trips fixed single-line markers", function()
        for _, raw in ipairs({ "🤖[q]", "🤖<X>[q]{a}[q2]", "🤖~D~{N}", "🤖{p}[h]", "🤖[a<br>b]{c}",
            "🤖<X>[]", "🤖[q]{}[next]", "🤖[cell\\<br>two]" }) do
            assert.equals(raw, round_trip(raw))
        end
    end)
    -- Property: from_lines(prefix, to_lines(m)) == raw over generated
    -- single-line markers (random anchor, 1–4 turns of text drawn from words,
    -- spaces, <br>, escaped <br> and balanced [] / {} pairs).
    it("round-trips generated markers", function()
        math.randomseed(312)
        local words = { "a", "b c", "x<br>y", "[n]", "{m}", "é", "t [u] v", "cell\\<br>two", "" }
        for _ = 1, 500 do
            local prefix = ({ "🤖", "🤖<Q>", "🤖~D~" })[math.random(3)]
            local raw = prefix
            for _ = 1, math.random(1, 4) do
                local user = math.random(2) == 1
                raw = raw .. (user and "[" or "{") .. words[math.random(#words)] .. (user and "]" or "}")
            end
            assert.equals(raw, round_trip(raw), raw)
        end
    end)
    it("appends a multi-line reply as one <br>-encoded turn", function()
        assert.equals("🤖<X>[q]{a}[line1<br>line2]",
            thread.from_lines("🤖<X>", { "💬: q", "🤖: a", "💬: line1", "line2" }, true))
    end)
    it("drops an empty appended reply and trailing blank lines", function()
        assert.equals("🤖[q]", thread.from_lines("🤖", { "💬: q", "💬: " }, true))
        assert.equals("🤖[q]", thread.from_lines("🤖", { "💬: q", "", "💬:   ", "" }, true))
    end)
    it("refuses text that would break the marker's brackets", function()
        local raw, err = thread.from_lines("🤖", { "💬: q", "💬: oops ] here" }, true)
        assert.is_nil(raw)
        assert.truthy(err)
        assert.is_nil((thread.from_lines("🤖", { "🤖: a { b" }, true)))
    end)
    it("refuses text before the first prefixed turn", function()
        local raw, err = thread.from_lines("🤖", { "loose words", "💬: q" }, true)
        assert.is_nil(raw)
        assert.truthy(err)
    end)
    it("roles: continuation lines inherit, prefixes switch", function()
        assert.same({ "user", "user", "agent", "agent", "user" },
            thread.roles({ "💬: a", "more", "🤖: b", "more", "💬: c" }))
    end)
end)
