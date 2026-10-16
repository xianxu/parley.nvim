-- The isolation rule (#342): pure checks, plus cliproxy refusing to write
-- outside the isolated root in test mode.
local iso = require("parley.test_isolation")

describe("test_isolation.check", function()
    local root = "/scratch/env"
    local function env(over)
        return vim.tbl_extend("force", { PARLEY_TEST_ENV_ROOT = root, HOME = root .. "/home",
            XDG_CONFIG_HOME = root .. "/xdg/config", XDG_DATA_HOME = root .. "/xdg/data", XDG_STATE_HOME = root .. "/xdg/state",
            XDG_CACHE_HOME = root .. "/xdg/cache" }, over or {})
    end

    it("accepts every root inside the marked root", function()
        assert.same({}, iso.check(env()))
    end)
    it("refuses an environment with no marker", function()
        local reasons = iso.check(env({ PARLEY_TEST_ENV_ROOT = "" }))
        assert.equals(1, #reasons)
        assert.matches("PARLEY_TEST_ENV_ROOT is unset", reasons[1])
    end)
    it("names each root outside the marked one", function()
        local reasons = iso.check(env({ HOME = "/Users/operator", XDG_CONFIG_HOME = "/Users/operator/.config" }))
        assert.equals(2, #reasons)
        assert.matches("^HOME=/Users/operator is outside", reasons[1])
        assert.matches("^XDG_CONFIG_HOME=", reasons[2])
    end)
    it("refuses a root that is unset, and a prefix that is not a parent", function()
        assert.matches("XDG_DATA_HOME is unset", iso.check(env({ XDG_DATA_HOME = "" }))[1])
        assert.matches("XDG_CONFIG_HOME is unset", iso.check(env({ XDG_CONFIG_HOME = "" }))[1])
        assert.equals(1, #iso.check(env({ HOME = root .. "-sibling/home" })))
    end)
    it("resolves links before comparing", function()
        local real = vim.uv.fs_realpath(vim.fn.tempname()) or vim.fn.tempname()
        vim.fn.mkdir(real .. "/target", "p")
        real = vim.uv.fs_realpath(real)
        local link = real .. "/link"
        assert(vim.uv.fs_symlink(real .. "/target", link))
        assert.is_true(iso.inside(real .. "/target", link .. "/data"))
        assert.is_false(iso.inside(real .. "/target", real .. "/other"))
        vim.fn.delete(real, "rf")
    end)
end)

-- An operator who exports a root the harness does not pin would have every
-- harness run refused (#342 close review): TEST_ENV must pin each one.
describe("the harness pins every guarded root", function()
    it("assigns each test_isolation root inside TEST_ENV", function()
        local line
        for _, l in ipairs(vim.fn.readfile("Makefile.parley")) do
            if l:match("^TEST_ENV = ") then line = l end
        end
        assert.is_not_nil(line, "Makefile.parley defines TEST_ENV")
        assert.matches('PARLEY_TEST_ENV_ROOT="%$%(TEST_ENV_ROOT%)"', line)
        for _, name in ipairs(iso.ROOTS) do
            assert.matches(" " .. name .. '="%$%(TEST_', line, name .. " is not pinned by TEST_ENV")
        end
    end)
end)

describe("cliproxy data root under test mode", function()
    local cliproxy = require("parley.cliproxy")
    after_each(function() cliproxy._set_data_dir(nil) end)

    it("runs under the harness's marker", function()
        assert.equals("1", vim.env.PARLEY_TEST_MODE)
        assert.same({}, iso.check())
    end)
    it("refuses a root outside the isolated env instead of writing there", function()
        cliproxy._set_data_dir("/Users/operator/.local/share/nvim/parley/cliproxy")
        local ok, err = pcall(cliproxy._catalog_path)
        assert.is_false(ok)
        assert.matches("refusing data root", tostring(err))
    end)
    it("allows the isolated default and a tempname override", function()
        assert.is_true(pcall(cliproxy._catalog_path))
        cliproxy._set_data_dir(vim.fn.tempname())
        assert.is_true(pcall(cliproxy._catalog_path))
    end)
end)
