-- Native observer boundary for the Python census; no test init or plugins.
local path = debug.getinfo(1, "S").source:sub(2)
local repo = vim.fs.dirname(vim.fs.dirname(path))
package.path = repo .. "/?.lua;" .. package.path
local Processes = require("tests.helpers.test_processes")
local base, phase, grace = arg[1], arg[2], tonumber(arg[3])
local ok, result = pcall(Processes.census, base, vim.env.PARLEY_TEST_PROCESS_DIR,
    { grace_ms = math.min(1000, math.max(0, grace or 0) * 1000), report_only = arg[4] == "snapshot" })
if not ok then io.stdout:write("owned process census unknown: " .. tostring(result) .. "\n"); os.exit(2) end
for _, message in ipairs(result.messages) do io.stdout:write("owned process census: " .. message .. "\n") end
if result.unknown or (not result.ok and arg[4] ~= "snapshot") then
    io.stdout:write("owned process census unknown: retained evidence\n"); os.exit(2)
end
if result.leaked and phase == "after" then os.exit(1) end
io.stdout:write("owned process census verified\n")
os.exit(0)
