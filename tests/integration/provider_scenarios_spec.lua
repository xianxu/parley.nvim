-- #242: the provider scenario table through the REAL path, dispatcher.query ->
-- curl -> out_reader, against tests/fixtures/fake_provider. One case per
-- (profile, row) that applies; the rows and the judge are pure data
-- (tests/helpers/provider_scenario_table.lua), and the fake is structurally
-- faithful, not intelligent (its bytes come from sse_dialects).
local scenarios = require("tests.helpers.provider_scenarios")
local scenario_table = require("tests.helpers.provider_scenario_table")
local fixture_process = require("tests.helpers.fixture_process")

for name, profile in pairs(scenario_table.PROFILES) do
    describe(name .. " through dispatcher -> curl -> fake_provider (#242)", function()
        local mark, log
        before_each(function()
            mark = fixture_process.mark()
            log = vim.fn.tempname() .. "-requests.jsonl"
            require("parley.tools").register_builtins()
        end)
        after_each(function()
            fixture_process.reap({ since = mark, signal = "sigterm" })
            vim.fn.delete(log) -- the spec owns the request log (PQ-4)
        end)

        for _, row in ipairs(scenario_table.rows_for(name)) do
            it(row.id .. " " .. row.name, function()
                local out = scenarios.run(row, profile, log)
                assert.same({}, scenario_table.mismatches(row, out, profile))
            end)
        end
    end)
end
