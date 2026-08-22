-- Spawn a repo fixture executable and track its exit.
--
-- Two specs drive tests/fixtures/fake_sse_server, and both need the same
-- scaffolding: the parent environment folded into uv.spawn's array form, the
-- bytecode-cache suppression that keeps Python from writing __pycache__ into
-- the repo tree (#202 — the suite must not write inside the tree it traverses),
-- and a close-on-exit handler so teardown can tell a reaped child from a live
-- one. One owner rather than two copies (ARCH-DRY).

local uv = vim.uv or vim.loop

local M = {}

--- @param script string absolute path to the fixture executable
--- @param args string[] arguments passed to it
--- @param extra_env table<string, string>|nil extra environment entries
--- @return userdata handle, fun(): boolean exited
function M.spawn(script, args, extra_env)
    local env = {}
    for name, value in pairs(vim.fn.environ()) do
        table.insert(env, name .. "=" .. value)
    end
    -- Keep Python from writing __pycache__ next to the fixture, inside the repo.
    table.insert(env, "PYTHONDONTWRITEBYTECODE=1")
    for name, value in pairs(extra_env or {}) do
        table.insert(env, name .. "=" .. value)
    end

    local exited = false
    local handle
    handle = uv.spawn(script, { args = args, env = env }, function()
        exited = true
        if handle and not handle:is_closing() then
            handle:close()
        end
    end)
    return handle, function() return exited end
end

return M
