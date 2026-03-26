-- Unit tests for M.build_ancestor_messages in lua/parley/chat_respond.lua
--
-- build_ancestor_messages is pure logic: given an ordered ancestor chain
-- (oldest first), emit Q+A message pairs up to each level's branch_after index.

local chat_respond = require("parley.chat_respond")
local build = chat_respond.build_ancestor_messages

-- Helper to build a minimal exchange
local function exchange(q, a, summary)
    local ex = {
        question = { content = q, line_start = 1, file_references = {} },
    }
    if a then
        ex.answer = { content = a, line_start = 2 }
    end
    if summary then
        ex.summary = { content = summary }
    end
    return ex
end

describe("build_ancestor_messages", function()

    it("returns empty list for empty chain", function()
        assert.are.same({}, build({}))
    end)

    it("single ancestor, all exchanges included (branch_after = total)", function()
        local chain = {
            {
                exchanges = { exchange("q1", "a1"), exchange("q2", "a2") },
                branch_after = 2,
            },
        }
        local msgs = build(chain)
        assert.are.same({
            { role = "user",      content = "q1" },
            { role = "assistant", content = "a1" },
            { role = "user",      content = "q2" },
            { role = "assistant", content = "a2" },
        }, msgs)
    end)

    it("branch_after limits which exchanges are included", function()
        local chain = {
            {
                exchanges = { exchange("q1", "a1"), exchange("q2", "a2"), exchange("q3", "a3") },
                branch_after = 1,
            },
        }
        local msgs = build(chain)
        assert.are.same({
            { role = "user",      content = "q1" },
            { role = "assistant", content = "a1" },
        }, msgs)
    end)

    it("branch_after = 0 includes no exchanges", function()
        local chain = {
            {
                exchanges = { exchange("q1", "a1") },
                branch_after = 0,
            },
        }
        assert.are.same({}, build(chain))
    end)

    it("uses summary content instead of full answer when present", function()
        local chain = {
            {
                exchanges = { exchange("q1", "full answer", "short summary") },
                branch_after = 1,
            },
        }
        local msgs = build(chain)
        assert.are.same({
            { role = "user",      content = "q1" },
            { role = "assistant", content = "short summary" },
        }, msgs)
    end)

    it("question without answer only emits the user message", function()
        local chain = {
            {
                exchanges = { exchange("q1", nil) },
                branch_after = 1,
            },
        }
        local msgs = build(chain)
        assert.are.same({
            { role = "user", content = "q1" },
        }, msgs)
    end)

    it("two ancestor levels concatenated in order (grandparent then parent)", function()
        local chain = {
            {
                -- grandparent: 3 exchanges, branch was after exchange 2
                exchanges = { exchange("gp1", "ga1"), exchange("gp2", "ga2"), exchange("gp3", "ga3") },
                branch_after = 2,
            },
            {
                -- parent: 2 exchanges, branch was after exchange 1
                exchanges = { exchange("p1", "pa1"), exchange("p2", "pa2") },
                branch_after = 1,
            },
        }
        local msgs = build(chain)
        assert.are.same({
            { role = "user",      content = "gp1" },
            { role = "assistant", content = "ga1" },
            { role = "user",      content = "gp2" },
            { role = "assistant", content = "ga2" },
            { role = "user",      content = "p1" },
            { role = "assistant", content = "pa1" },
        }, msgs)
    end)

    it("three ancestor levels: great-grandparent → grandparent → parent", function()
        local chain = {
            { exchanges = { exchange("ggp1", "gga1") }, branch_after = 1 },
            { exchanges = { exchange("gp1", "gpa1"), exchange("gp2", "gpa2") }, branch_after = 2 },
            { exchanges = { exchange("p1", "pa1") }, branch_after = 1 },
        }
        local msgs = build(chain)
        assert.are.same({
            { role = "user",      content = "ggp1" },
            { role = "assistant", content = "gga1" },
            { role = "user",      content = "gp1" },
            { role = "assistant", content = "gpa1" },
            { role = "user",      content = "gp2" },
            { role = "assistant", content = "gpa2" },
            { role = "user",      content = "p1" },
            { role = "assistant", content = "pa1" },
        }, msgs)
    end)

end)
