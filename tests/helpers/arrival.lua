-- The one suite arrival budget (#370, #374). A positive wait,
-- `assert(vim.wait(arrival.MS, cond))`, returns the moment its outcome arrives,
-- so its bound costs a passing run nothing; a short literal only turns machine
-- load into a flake. The budget is the product's longest round-trip deadline
-- (agentic_submit_timeout_ms). A spec that observes a product deadline of its
-- own waits on that instead, as session_sync_spec does.
--
-- Absence checks (`vim.wait(200)` and then assert nothing happened) keep their
-- short fixed waits; there the bound is the test's cost. A positive wait whose
-- bound IS the property under test keeps its literal with a trailing
-- `-- bound: <reason>` comment. tests/arch/arrival_budget_spec.lua refuses any
-- other literal.
local M = {}

M.MS = 15000

return M
