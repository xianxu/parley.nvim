-- #242: the scenario table's judge is pure. A matching outcome has no
-- mismatches, and each expectation catches the outcome that violates it.
local T = require("tests.helpers.provider_scenario_table")
local P = T.PROFILES.anthropic
local function row(id)
    for _, r in ipairs(T.ROWS) do if r.id == id then return r end end
    error("no row " .. id)
end

describe("provider scenario table (#242)", function()
    it("every row names its provider columns, and only known ones", function()
        for _, r in ipairs(T.ROWS) do
            assert.is_truthy(next(r.applies), r.id)
            for p in pairs(r.applies) do
                assert.is_truthy(({ anthropic = 1, openai = 1, googleai = 1, cliproxy = 1 })[p], r.id .. ": " .. p)
            end
        end
        assert.equals(#T.ROWS, #T.rows_for("anthropic"))
    end)

    it("a matching outcome has no mismatches", function()
        assert.same({}, T.mismatches(row("S1"), { response = "Hello, world! 👋", errors = {} }, P))
        assert.same({}, T.mismatches(row("S4/429"), { failure = { http_status = 429, body = "rate limit hit" },
            requests = { {} } }, P))
        assert.same({}, T.mismatches(row("S7b"), { failure = { exit = "stdout reader failed" }, chunks = { "Hello," } }, P))
    end)

    it("each expectation catches the outcome that violates it", function()
        local cases = {
            { "S1", { response = "Hello" , errors = {} } },
            { "S1", { response = "Hello, world! 👋", errors = { "boom" } } },
            { "S1", { response = "Hello, world! 👋", errors = {}, failure = {} } },
            { "S3", { response = "Starting the answer and then ", warnings = {} } },
            { "S4/429", { response = "x" } }, -- completed instead of failing
            { "S4/429", { failure = { http_status = 429, body = "rate limit" }, requests = { {}, {} } } }, -- retried
            { "S5", { response = "The answer was cut off at the cap", warnings = { "something else" } } },
            { "S6", { response = "Hello, world! 👋", raw_at_first_chunk = 900, raw_bytes = 900, elapsed_ms = 10 } },
            { "S7b", { failure = { exit = "stdout reader failed" }, chunks = { "Hello,", "Hello," } } },
            { "S7a", { failure = { exit = "curl 18", streamed = true }, partial = "" } },
            { "no_stop", { response = "Hello, world! 👋", ending = "done" } },
            { "thinking", { response = "Hello, world! 👋", progress = {} } },
            { "S2", { response = "Done: the tool result was received.", first_call_id = "a",
                requests = { { json = {} }, { json = { messages = { { content = { { type = "tool_result", tool_use_id = "b" } } } } } } } } },
        }
        for _, c in ipairs(cases) do
            assert.is_true(#T.mismatches(row(c[1]), c[2], P) > 0, c[1] .. " accepted " .. vim.inspect(c[2]))
        end
    end)
end)
