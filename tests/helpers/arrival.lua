-- The one suite arrival budget (#370, #374). A positive wait,
-- `assert(vim.wait(arrival.MS, cond))`, returns the moment its outcome arrives,
-- so its bound costs a passing run nothing; a short literal only turns machine
-- load into a flake. The budget is the product's Couch submit deadline,
-- agentic_submit_timeout_ms, read from its default so the two cannot drift
-- (15 s). Longer product waits exist (a rename gets three of them, and the
-- cliproxy live waits use 2 * MS). A spec that observes a product deadline of
-- its own waits on that instead, as session_sync_spec does.
--
-- Absence checks (`vim.wait(200)` and then assert nothing happened) keep their
-- short fixed waits; there the bound is the test's cost. A positive wait whose
-- bound IS the property under test keeps its literal with a trailing
-- `-- bound: <reason>` comment (absence checks say `-- absence:`, teardown
-- drains `-- drain:`). tests/arch/arrival_budget_spec.lua refuses any other bound.
local M = {}

M.MS = require("parley.config").agentic_submit_timeout_ms

return M
