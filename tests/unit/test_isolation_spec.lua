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

-- #365: no ambient Couch, Pair or terminal-owner name reaches a spec.
describe("test_isolation.ambient", function()
    it("names every COUCH_*, PAIR_* and terminal owner, sorted, and nothing else", function()
        assert.same({ "COUCH_THREAD_SCOPE", "COUCH_THREAD_TAG", "KITTY_WINDOW_ID", "PAIR_SLOT", "TMUX" },
            iso.ambient({ COUCH_THREAD_TAG = "t", COUCH_THREAD_SCOPE = "s", PAIR_SLOT = "4", TMUX = "x",
                KITTY_WINDOW_ID = "1", HOME = "/h", PATH = "/bin",
                PARLEY_TEST_MODE = "1", NVIM = "the harness parent", XCOUCH_Y = "not a prefix" }))
    end)
    it("is empty for the allowlist", function()
        assert.same({}, iso.ambient({ PATH = "/bin", HOME = "/h", TMPDIR = "/t", SHELL = "/bin/sh", LANG = "C" }))
    end)
end)

-- #365: a target that starts nvim without the allowlist launcher would leak the
-- operator's environment again; every launch line names scripts/test-env.sh.
describe("every harness nvim starts through the allowlist launcher", function()
    it("has no nvim launch in Makefile.parley outside scripts/test-env.sh", function()
        local launches, bare = 0, {}
        for n, l in ipairs(vim.fn.readfile("Makefile.parley")) do
            if not l:match("^%s*#") and (l:match("[%s'\"]nvim %-") or l:match("[%s'\"]nvim$")) then
                launches = launches + 1
                if not (l:find("$(TEST_RUN) nvim", 1, true) or l:find('scripts/test-env.sh" nvim', 1, true)) then
                    bare[#bare + 1] = n .. ": " .. vim.trim(l)
                end
            end
        end
        assert.is_true(launches >= 7, "found only " .. launches .. " nvim launches; the scan is stale")
        assert.same({}, bare)
    end)
    it("strips PARLEY_LIVE_COUCH from every launch but check-couch-actors-live, and logs per target", function()
        local lines, carrying, test_run = vim.fn.readfile("Makefile.parley"), {}, nil
        for n, l in ipairs(lines) do
            if l:match("^TEST_RUN = ") then test_run = l end
            if l:match("^SENTINEL_LOG = ") then assert.truthy(l:find("$@", 1, true), "SENTINEL_LOG is not per target") end
            if not l:match("^%s*#") and l:find('scripts/test-env.sh" nvim', 1, true)
                and not l:find('env -u PARLEY_LIVE_COUCH "$(CURDIR)/scripts/test-env.sh" nvim', 1, true) then
                carrying[#carrying + 1] = n
            end
        end
        assert.truthy(test_run and test_run:find("env -u PARLEY_LIVE_COUCH", 1, true), "TEST_RUN keeps the Couch flag")
        assert.equals(1, #carrying, "launches that keep PARLEY_LIVE_COUCH: " .. vim.inspect(carrying))
        local target
        for i = carrying[1], 1, -1 do
            target = lines[i]:match("^([%w-]+):")
            if target then break end
        end
        assert.equals("check-couch-actors-live", target)
    end)
end)

-- #365 close review: every target that runs specs checks the sentinel after
-- them, and the launcher never puts a value on an argument list (only names).
describe("the sentinel gate and the launcher's argv", function()
    it("runs SENTINEL_CHECK in every target that runs the orphan gate", function()
        local orphans, sentinel = 0, 0
        for _, l in ipairs(vim.fn.readfile("Makefile.parley")) do
            if l:find("$(ORPHANS) --phase after", 1, true) then orphans = orphans + 1 end
            if l:find("$(SENTINEL_CHECK) || rc=1", 1, true) then sentinel = sentinel + 1 end
        end
        assert.is_true(orphans >= 9, "the scan is stale: " .. orphans)
        assert.equals(orphans, sentinel)
    end)
    it("builds no NAME=value argument except PATH, SHELL and the sentinel log", function()
        local built = {}
        for _, l in ipairs(vim.fn.readfile("scripts/test-env.sh")) do
            if not l:match("^%s*#") then
                for name in l:gmatch('"([A-Z_][A-Z0-9_]*)=%$') do built[#built + 1] = name end
            end
        end
        table.sort(built)
        assert.same({ "PARLEY_TEST_SENTINEL_LOG", "PATH" }, built)
        assert.is_nil(table.concat(vim.fn.readfile("scripts/test-env.sh"), "\n"):find('eval "value=', 1, true))
    end)
end)
