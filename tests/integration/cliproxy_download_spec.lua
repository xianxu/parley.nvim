-- Integration test for installing a CLIProxyAPI release (#131 M2, #237).
-- Serves releases from tests/fixtures/fake_github_releases (no network) and
-- verifies download → checksum-verify → staged extract → atomic rename →
-- version record, and that a tampered checksum or a non-version is refused.

local uv = vim.uv or vim.loop
local cliproxy = require("parley.cliproxy")
local fake_releases = require("tests.helpers.fake_releases")

cliproxy._set_data_dir(vim.fn.tempname()) -- never touch the real ~/.local/share/nvim
local server = fake_releases.start()
cliproxy._set_releases_url(server.url)

describe("cliproxy download", function()
    before_each(function()
        local mb = cliproxy.managed_binary()
        if mb then
            vim.fn.delete(mb)
            vim.fn.delete(mb .. ".version")
        end
        fake_releases.publish(server, "9.9.9") -- also restores good checksums
    end)

    it("downloads, checksum-verifies, installs, and records the version", function()
        local bin, err = cliproxy.download({ version = "9.9.9" })
        assert.is_truthy(bin, "download failed: " .. tostring(err))
        assert.equals(1, vim.fn.executable(bin))
        assert.equals(bin, cliproxy.managed_binary())
        assert.equals("9.9.9", cliproxy.installed_version())
    end)

    it("makes the downloaded binary discoverable", function()
        cliproxy.download({ version = "9.9.9" })
        local saved = require("parley").config
        require("parley").config = { cliproxy = { manage = true } }
        assert.equals(cliproxy.managed_binary(), cliproxy.discover_binary())
        require("parley").config = saved
    end)

    it("replaces an installed binary by rename, so a running copy keeps its file", function()
        local bin = cliproxy.download({ version = "9.9.9" })
        local before = uv.fs_stat(bin).ino
        fake_releases.publish(server, "9.9.10")
        assert.is_truthy(cliproxy.download({ version = "9.9.10" }))
        assert.are_not.equal(before, uv.fs_stat(bin).ino)
        assert.equals("9.9.10", cliproxy.installed_version())
        assert.is_nil(uv.fs_stat(vim.fn.fnamemodify(bin, ":h:h") .. "/staging"), "staging left behind")
    end)

    it("REFUSES to install on a checksum mismatch, leaving the previous install", function()
        assert.is_truthy(cliproxy.download({ version = "9.9.9" }))
        fake_releases.publish(server, "9.9.11", { sha = ("0"):rep(64) })
        local bin, err = cliproxy.download({ version = "9.9.11" })
        assert.is_nil(bin)
        assert.is_truthy(err and err:find("checksum mismatch"))
        assert.equals("9.9.9", cliproxy.installed_version())
    end)

    it("refuses a version it would have to put in a URL unparsed", function()
        local bin, err = cliproxy.download({ version = "../../evil" })
        assert.is_nil(bin)
        assert.is_truthy(err:find("not a release version", 1, true))
    end)

    it("reads a missing or garbled version record as unknown", function()
        local bin = cliproxy.download({ version = "9.9.9" })
        vim.fn.writefile({ "not a version" }, bin .. ".version")
        assert.is_nil(cliproxy.installed_version())
        vim.fn.delete(bin .. ".version")
        assert.is_nil(cliproxy.installed_version())
    end)
end)
