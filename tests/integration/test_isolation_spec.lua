-- A spec run outside the harness's isolated HOME/XDG must never execute (#342).
-- A direct `nvim -u tests/minimal_init.vim` with the operator's environment once
-- wrote their real cliproxy catalog cache. The init now refuses before any test.
local init = vim.fn.getcwd() .. "/tests/minimal_init.vim"

describe("test isolation guard", function()
    local scratch
    before_each(function()
        scratch = vim.uv.fs_realpath(vim.fn.tempname()) or vim.fn.tempname()
        vim.fn.mkdir(scratch, "p")
        scratch = vim.uv.fs_realpath(scratch)
    end)
    after_each(function() vim.fn.delete(scratch, "rf") end)

    -- A child on the harness init that would write a sentinel under its data dir.
    local function child(env, cwd)
        local base = { PATH = vim.env.PATH, NVIM_TEST_PLENARY = vim.env.NVIM_TEST_PLENARY, TMPDIR = scratch .. "/tmp" }
        vim.fn.mkdir(scratch .. "/tmp", "p")
        local result = vim.system({ vim.v.progpath, "-n", "--headless", "--noplugin", "-u", init,
            "-c", "lua vim.fn.mkdir(vim.fn.stdpath('data'), 'p'); vim.fn.writefile({'x'}, vim.fn.stdpath('data') .. '/sentinel')",
            "-c", "qa!" }, { text = true, cwd = cwd, clear_env = true, env = vim.tbl_extend("force", base, env) }):wait(10000)
        return result
    end
    local function roots(root)
        return { HOME = root .. "/home", XDG_CONFIG_HOME = root .. "/config", XDG_DATA_HOME = root .. "/data",
            XDG_STATE_HOME = root .. "/state", XDG_CACHE_HOME = root .. "/cache" }
    end

    it("refuses to run before any command when the env carries no isolation marker", function()
        local env = roots(scratch .. "/real")
        local result = child(env)
        assert.is_not.equals(0, result.code)
        assert.matches("not isolated", result.stderr)
        assert.matches("make test%-spec", result.stderr)
        assert.equals(0, vim.fn.filereadable(env.XDG_DATA_HOME .. "/nvim/sentinel"))
    end)

    it("refuses when HOME or an XDG root lies outside the marked root", function()
        local env = roots(scratch .. "/inside")
        env.PARLEY_TEST_ENV_ROOT = scratch .. "/inside"
        env.XDG_DATA_HOME = scratch .. "/elsewhere/data"
        local result = child(env)
        assert.is_not.equals(0, result.code)
        assert.matches("XDG_DATA_HOME", result.stderr)
        assert.equals(0, vim.fn.filereadable(env.XDG_DATA_HOME .. "/nvim/sentinel"))
    end)

    it("fails closed when the isolation check itself cannot load", function()
        -- From a directory without parley, `set rtp+=.` adds nothing and the
        -- require fails: the run must still stop, never proceed unguarded.
        local env = roots(scratch .. "/inside")
        env.PARLEY_TEST_ENV_ROOT = scratch .. "/inside"
        local result = child(env, scratch)
        assert.is_not.equals(0, result.code)
        assert.matches("isolation check could not run", result.stderr)
        assert.equals(0, vim.fn.filereadable(env.XDG_DATA_HOME .. "/nvim/sentinel"))
    end)

    it("runs normally when every root is inside the marked root", function()
        local env = roots(scratch .. "/inside")
        env.PARLEY_TEST_ENV_ROOT = scratch .. "/inside"
        local result = child(env)
        assert.equals(0, result.code, result.stderr)
        assert.equals(1, vim.fn.filereadable(env.XDG_DATA_HOME .. "/nvim/sentinel"))
    end)
end)
