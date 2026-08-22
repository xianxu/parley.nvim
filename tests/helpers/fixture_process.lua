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
--- @return userdata|nil handle, fun(): boolean exited, string|nil err
--- On failure `handle` is nil and `err` carries libuv's reason — assert with it
--- (`assert.is_not_nil(handle, err)`), or an ENOENT on the fixture path reads
--- only as "expected not nil".
function M.spawn(script, args, extra_env)
    -- Fold into a keyed map before flattening: libuv passes duplicate keys
    -- straight through and the child's lookup resolves the *parent's* entry, so
    -- appending would let a same-named variable in the caller's shell silently
    -- override what a spec asked for.
    local merged = vim.fn.environ()
    -- Keep Python from writing __pycache__ next to the fixture, inside the repo.
    merged.PYTHONDONTWRITEBYTECODE = "1"
    for name, value in pairs(extra_env or {}) do
        merged[name] = value
    end

    local env = {}
    for name, value in pairs(merged) do
        table.insert(env, name .. "=" .. value)
    end

    local exited = false
    local handle, err
    handle, err = uv.spawn(script, { args = args, env = env }, function()
        exited = true
        if handle and not handle:is_closing() then
            handle:close()
        end
    end)
    return handle, function() return exited end, err
end

return M
