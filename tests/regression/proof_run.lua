-- #242 regression proofs, run STANDALONE against a pre-fix tree:
--   cd <scratch worktree at the pre-fix parent>
--   nvim --headless -u NONE -l <branch>/tests/regression/proof_run.lua <branch>/tests/fixtures/fake_provider <case>
-- Only APIs present on BOTH trees are used (dispatcher.query positional
-- arguments, parley.logger, setup). The fake runs from the branch checkout, so
-- nothing is copied onto the old tree. Prints PROOF-REACHED <case> right
-- before the observation; a run without it is inconclusive, not a pass.
local fake, case = arg[1], arg[2]
vim.opt.rtp:prepend(vim.fn.getcwd())
local root = vim.fn.tempname() .. "-proof"
vim.fn.mkdir(root .. "/state", "p")
require("parley").setup({ chat_dir = root, state_dir = root .. "/state", providers = {}, api_keys = {} })
local D = require("parley.dispatcher")
local CASES = {
    cap_empty = { mode = "cap_empty" },
    inband_error_empty = { mode = "inband_error_empty" },
    throwing_handler = { mode = "ok", split = "every_byte", throw_at = 1 },
}
local c = assert(CASES[case], "unknown case " .. tostring(case))
local port = 20000 + math.random(0, 20000)
local proc = vim.system({ fake, "--dialect", "anthropic", "--port", tostring(port), "--mode", c.mode,
    "--split", c.split or "none" })
vim.wait(5000, function()
    local res = vim.system({ "curl", "-s", "-o", "/dev/null", "-w", "%{http_code}", "--max-time", "1",
        "http://127.0.0.1:" .. port .. "/nope", "-X", "POST" }, { text = true }):wait()
    return res.stdout == "404"
end, 50)
D.providers.anthropic = D.providers.anthropic or {}
D.providers.anthropic.endpoint = "http://127.0.0.1:" .. port .. "/v1/messages"
require("parley.vault").add_secret("anthropic", "sk-fake-proof")
local logger = require("parley.logger")
local lines, handled, done = {}, 0, false
logger.error = function(m) lines[#lines + 1] = "ERROR " .. tostring(m) end
logger.warning = function(m) lines[#lines + 1] = "WARN " .. tostring(m) end
local payload = D.prepare_payload({ { role = "user", content = "hi" } }, { model = "claude-sonnet-4-6" }, "anthropic")
payload.tools = nil -- a default setup offers tools (e.g. web search); the fake would answer tool_use
D.query(nil, "anthropic", payload, function()
    handled = handled + 1
    if c.throw_at and handled == c.throw_at then error("consumer invalidated mid-stream") end
end, nil, function(response) lines[#lines + 1] = "COMPLETE bytes=" .. #(response or ""); done = true end, nil, function(m) lines[#lines + 1] = "ABORT " .. tostring(m); done = true end,
    nil, function(_, failure) lines[#lines + 1] = "FAILURE " .. vim.inspect(failure):gsub("%s+", " "); done = true end,
    { deadline_ms = 120000 })
vim.wait(10000, function() return done end, 20)
vim.wait(300) -- let late chunks arrive, so a pre-fix tree can show it consumed them
pcall(function() proc:kill(15) end)
print("PROOF-REACHED " .. case)
print("RESULT " .. case .. " handled=" .. handled .. " done=" .. tostring(done))
for _, l in ipairs(lines) do print("LOG " .. l) end
vim.cmd("qa!")
