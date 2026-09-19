-- #261/#255: the previous answer of a regenerating exchange, and its
-- substitution into request context. Pure — no buffer, no document.
local P = require("parley.previous_answer")

local function ex(line, question, answer)
    local e = { question = { line_start = line, line_end = line, content = question } }
    if answer then e.answer = { line_start = line + 2, line_end = line + 2, content = answer } end
    return e
end
local function chat() return { headers = {}, exchanges = { ex(5, "Q1", "new partial"), ex(9, "Q2", "A2") } } end
local old = { answer = { line_start = 40, line_end = 44, content = "old one" }, summary = { content = "old summary" } }

describe("previous_answer.substitute", function()
    it("replaces the matched exchange's answer, summary and reasoning", function()
        local out = P.substitute(chat(), { { row = 4, value = old } })
        assert.equals("old one", out.exchanges[1].answer.content)
        assert.equals("old summary", out.exchanges[1].summary.content)
        assert.is_nil(out.exchanges[1].reasoning)
        assert.same(chat().exchanges[2], out.exchanges[2])
    end)
    it("rebases the answer to follow its question", function()
        local out = P.substitute(chat(), { { row = 4, value = old } })
        assert.equals(6, out.exchanges[1].answer.line_start)
    end)
    it("never substitutes the exchange being answered", function()
        local out = P.substitute(chat(), { { row = 4, value = old } }, 1)
        assert.equals("new partial", out.exchanges[1].answer.content)
    end)
    it("changes nothing for a row that matches no question", function()
        assert.same(chat(), P.substitute(chat(), { { row = 6, value = old } }))
    end)
    it("returns the same table when there is nothing to substitute", function()
        local parsed = chat()
        assert.is_true(rawequal(parsed, P.substitute(parsed, {})))
        assert.is_true(rawequal(parsed, P.substitute(parsed, nil)))
    end)
    it("does not mutate its input", function()
        local parsed = chat(); local before = vim.deepcopy(parsed)
        P.substitute(parsed, { { row = 4, value = old } })
        assert.same(before, parsed)
    end)
end)

describe("previous_answer.capture", function()
    it("is nil without an answer", function() assert.is_nil(P.capture(ex(1, "Q"))) end)
    it("deep-copies, keeping structured content blocks", function()
        local e = ex(1, "Q", "text")
        e.answer.content_blocks = { { type = "tool_use", id = "t1", name = "read_file", input = {} } }
        local value = P.capture(e)
        value.answer.content_blocks[1].id = "changed"
        assert.equals("t1", e.answer.content_blocks[1].id)
    end)
end)
