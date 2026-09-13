-- Build CLIProxyAPI-shaped releases on disk and serve them with
-- tests/fixtures/fake_github_releases (#237). One owner for the release
-- fixture the download and update specs share (ARCH-DRY).
--
-- A published release's cli-proxy-api is a wrapper that execs
-- tests/fixtures/fake_cliproxy with PARLEY_FAKE_CPA_VERSION set to the
-- release's version, so "which release is running" is observable through the
-- same X-Cpa-Version header parley reads from the real binary. Both the server
-- and the wrapped proxy exit with the nvim that started them
-- (tests/fixtures/fixture_watchdog.py), so a crashed spec cannot orphan them.

local cc = require("parley.cliproxy_config")
local fixture_process = require("tests.helpers.fixture_process")
local ready_port = require("tests.helpers.ready_port")

local M = {}

local SERVER = vim.fn.getcwd() .. "/tests/fixtures/fake_github_releases"
local FAKE_PROXY = vim.fn.getcwd() .. "/tests/fixtures/fake_cliproxy"

local function sha256(path)
    local cmd = vim.fn.executable("sha256sum") == 1 and { "sha256sum", path } or { "shasum", "-a", "256", path }
    return vim.trim(vim.fn.system(cmd)):match("^(%x+)")
end

--- Start a release server over a fresh root.
---@param mode string|nil # "normal" (default) | "slow"
---@return table # { root, port, url, handle }
function M.start(mode)
    local root = vim.fn.tempname()
    vim.fn.mkdir(root, "p")
    local port = ready_port.free_port()
    local args = { "--port", tostring(port), "--root", root }
    if mode then
        vim.list_extend(args, { "--mode", mode })
    end
    local handle, _, err = fixture_process.spawn(SERVER, args)
    assert(handle, "failed to start fake_github_releases: " .. tostring(err))
    ready_port.wait_listening(port)
    local server = {
        root = root,
        port = port,
        handle = handle,
        url = ("http://127.0.0.1:%d/router-for-me/CLIProxyAPI/releases"):format(port),
    }
    vim.api.nvim_create_autocmd("VimLeavePre", {
        callback = function()
            M.stop(server)
        end,
    })
    return server
end

--- Stop a server started by M.start.
function M.stop(server)
    pcall(function()
        if server.handle and not server.handle:is_closing() then
            server.handle:kill("sigkill")
        end
    end)
end

--- Publish release `ver`: its tarball and checksums.txt, and (unless
--- `opts.latest == false`) make it the latest. `opts.sha` publishes a wrong
--- checksum.
---@return table # { asset, sha }
function M.publish(server, ver, opts)
    opts = opts or {}
    local vdir = server.root .. "/v" .. ver
    vim.fn.mkdir(vdir, "p")
    local stage = vim.fn.tempname()
    vim.fn.mkdir(stage, "p")
    vim.fn.writefile({
        "#!/bin/sh",
        "PARLEY_FAKE_CPA_VERSION=" .. vim.fn.shellescape(ver),
        -- parley spawns this detached; it must still exit with the spec's nvim (#220)
        "PARLEY_FAKE_EXIT_WITH_PARENT=1",
        "export PARLEY_FAKE_CPA_VERSION PARLEY_FAKE_EXIT_WITH_PARENT",
        "exec " .. vim.fn.shellescape(FAKE_PROXY) .. ' "$@"',
    }, stage .. "/cli-proxy-api")
    vim.fn.system({ "chmod", "+x", stage .. "/cli-proxy-api" })
    local asset = cc.asset_name(ver, cc.platform())
    local asset_path = vdir .. "/" .. asset
    vim.fn.system({ "tar", "-czf", asset_path, "-C", stage, "cli-proxy-api" })
    local sha = sha256(asset_path)
    vim.fn.writefile({ (opts.sha or sha) .. "  " .. asset }, vdir .. "/checksums.txt")
    if opts.latest ~= false then
        vim.fn.writefile({ ver }, server.root .. "/latest")
    end
    return { asset = asset, sha = sha }
end

--- Requests the server has answered, as "GET <path>" lines.
function M.requests(server)
    local ok, lines = pcall(vim.fn.readfile, server.root .. "/requests.log")
    return ok and lines or {}
end

function M.clear_requests(server)
    vim.fn.delete(server.root .. "/requests.log")
end

return M
