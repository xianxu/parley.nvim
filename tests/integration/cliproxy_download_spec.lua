-- Integration test for M2 auto_download (issue #131).
-- Serves a fixture release over a local HTTP server (no network) and verifies
-- download → checksum-verify → extract, AND that a tampered checksum is refused.

local uv = vim.uv or vim.loop
local cliproxy = require("parley.cliproxy")
local cc = require("parley.cliproxy_config")

local function free_port()
    local s = uv.new_tcp()
    s:bind("127.0.0.1", 0)
    local port = s:getsockname().port
    s:close()
    return port
end

local function wait_listening(port)
    vim.wait(5000, function()
        local ok = false
        local c = uv.new_tcp()
        c:connect("127.0.0.1", port, function(err)
            ok = err == nil
            c:close()
        end)
        vim.wait(100, function() return false end)
        return ok
    end, 50)
end

-- Fixture + HTTP server built once at file load (plenary busted has no setup()).
local version = "9.9.9"
local asset = cc.asset_name(version, cc.platform())
local serve_dir = vim.fn.tempname()
local sums_path = serve_dir .. "/v" .. version .. "/checksums.txt"
local good_sha, base_url, http_handle
do
    local vdir = serve_dir .. "/v" .. version
    vim.fn.mkdir(vdir, "p")
    local stage = vim.fn.tempname()
    vim.fn.mkdir(stage, "p")
    vim.fn.writefile({ "#!/bin/sh", "echo fake-cliproxy" }, stage .. "/cli-proxy-api")
    vim.fn.system({ "chmod", "+x", stage .. "/cli-proxy-api" })
    local asset_path = vdir .. "/" .. asset
    vim.fn.system({ "tar", "-czf", asset_path, "-C", stage, "cli-proxy-api" })
    good_sha = vim.trim(vim.fn.system({ "shasum", "-a", "256", asset_path })):match("^(%x+)")
    vim.fn.writefile({ good_sha .. "  " .. asset }, sums_path)

    local port = free_port()
    http_handle = uv.spawn("python3",
        { args = { "-m", "http.server", tostring(port) }, cwd = serve_dir }, function() end)
    assert(http_handle, "failed to start fixture http server")
    base_url = "http://127.0.0.1:" .. port
    wait_listening(port)
    -- reap the server when this test nvim exits
    vim.api.nvim_create_autocmd("VimLeavePre", {
        callback = function()
            pcall(function()
                if http_handle and not http_handle:is_closing() then
                    http_handle:kill("sigkill")
                end
            end)
        end,
    })
end

describe("cliproxy auto_download", function()
    before_each(function()
        -- start each case from a clean managed bin dir
        local mb = cliproxy.managed_binary()
        if mb then
            vim.fn.delete(mb)
        end
        -- restore the good checksums (a prior case may have tampered it)
        vim.fn.writefile({ good_sha .. "  " .. asset }, sums_path)
    end)

    it("downloads, checksum-verifies, and extracts the binary", function()
        local bin, err = cliproxy.download({ version = version, base_url = base_url })
        assert.is_truthy(bin, "download failed: " .. tostring(err))
        assert.equals(1, vim.fn.executable(bin))
        assert.equals(bin, cliproxy.managed_binary())
    end)

    it("makes the downloaded binary discoverable", function()
        cliproxy.download({ version = version, base_url = base_url })
        -- nothing on PATH override needed: managed dir is in discover_binary's chain
        local saved = require("parley").config
        require("parley").config = { cliproxy = { manage = true } }
        assert.equals(cliproxy.managed_binary(), cliproxy.discover_binary())
        require("parley").config = saved
    end)

    it("REFUSES to install on a checksum mismatch", function()
        -- tamper the served checksum
        vim.fn.writefile({ ("0"):rep(64) .. "  " .. asset }, sums_path)
        local bin, err = cliproxy.download({ version = version, base_url = base_url })
        assert.is_nil(bin)
        assert.is_truthy(err and err:find("checksum mismatch"))
        assert.is_nil(cliproxy.managed_binary()) -- nothing installed
    end)
end)
