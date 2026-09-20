-- Spawn a repo fixture executable, track it, and make sure it dies.
--
-- Several specs drive a fixture process, and they all need the same scaffolding:
-- the parent environment folded into uv.spawn's array form, the bytecode-cache
-- suppression that keeps Python from writing __pycache__ into the repo tree
-- (#202 — the suite must not write inside the tree it traverses), and a
-- close-on-exit handler so teardown can tell a reaped child from a live one.
-- One owner rather than several copies (ARCH-DRY).
--
-- Every process started here is registered and killed at VimLeavePre, so a spec
-- that never reaches its own teardown — a failing assertion, an error at load —
-- cannot orphan one (#220). Eight specs each kept a private copy of this table
-- and this loop, and every one of them bypassed this seam; the registry lives
-- with the spawn so a new spec inherits it rather than remembering it.
--
-- This is the normal-exit half only. A killed or wedged Neovim never runs
-- VimLeavePre, and that is the dominant case: the fixtures carry their own
-- parent-death watchdog for it (tests/fixtures/fixture_watchdog.py). The one
-- process here that CANNOT — the real cliproxyapi, spawned by
-- cliproxy_conformance_spec — is why this layer exists at all rather than being
-- subsumed by that watchdog.

local uv = vim.uv or vim.loop

local M = {}

-- Entries carry a monotonic sequence number, not an index: a process that exits
-- on its own is pruned, and indices would shift under a mark taken before it.
local registry = {} -- { { handle = <uv handle>, seq = <integer> }, … }
local last_seq = 0

--- A point in the registry. Everything spawned AFTER it is reaped by
--- `reap({ since = mark })`; everything before it is spared.
---
--- Two specs need this: cliproxy_update_spec and cliproxy_download_spec each
--- start a release server at FILE scope and point every case at it, so a blanket
--- reap in after_each would break every case after the first.
function M.mark()
    return last_seq
end

--- How many spawned processes are still running and tracked (after `since`).
---@param since integer|nil
function M.live(since)
    local n = 0
    for _, entry in ipairs(registry) do
        if not since or entry.seq > since then
            n = n + 1
        end
    end
    return n
end

--- Kill tracked processes and forget them. Idempotent.
---
--- SIGKILL by default, because this is teardown: nothing downstream observes the
--- shutdown. A spec that needs a graceful stop to be observable passes
--- `signal = "sigterm"` (fake_cliproxy models graceful shutdown under
--- PARLEY_FAKE_EXIT_DELAY_MS).
---@param opts { since: integer|nil, signal: string|nil }|nil
function M.reap(opts)
    opts = opts or {}
    local kept = {}
    for _, entry in ipairs(registry) do
        if opts.since and entry.seq <= opts.since then
            kept[#kept + 1] = entry
        else
            pcall(function()
                if not entry.handle:is_closing() then
                    entry.handle:kill(opts.signal or "sigkill")
                end
            end)
        end
    end
    registry = kept
end

vim.api.nvim_create_autocmd("VimLeavePre", { callback = function() M.reap() end })

--- @param script string absolute path to the fixture executable
--- @param args string[] arguments passed to it
--- @param extra_env table<string, string>|nil extra environment entries
--- @return userdata|nil handle, fun(): boolean exited, string|nil err, integer|nil pid
--- On failure `handle` is nil and `err` carries libuv's reason — assert with it
--- (`assert.is_not_nil(handle, err)`), or an ENOENT on the fixture path reads
--- only as "expected not nil". On SUCCESS the third value is nil and the pid is
--- the fourth; before #220 the pid was the third, but every caller bound it only
--- to feed an assert message.
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
    local handle, pid, err
    handle, pid = uv.spawn(script, { args = args, env = env }, function()
        exited = true
        for i, entry in ipairs(registry) do
            if entry.handle == handle then
                table.remove(registry, i)
                break
            end
        end
        if handle and not handle:is_closing() then
            handle:close()
        end
    end)
    if not handle then
        -- On failure libuv returns nil plus the message; `pid` holds it.
        err = pid
        return nil, function() return true end, err
    end
    last_seq = last_seq + 1
    registry[#registry + 1] = { handle = handle, seq = last_seq }
    return handle, function() return exited end, nil, pid
end

return M
