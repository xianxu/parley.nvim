local git_markdown_source = require("parley.git_markdown_source")
local failure_kind = require("parley.finder_scan").FAILURE_KIND

local uv = vim.uv or vim.loop
local fixture = vim.fn.getcwd() .. "/tests/fixtures/fake_git_file_list"

local function wait_for(predicate)
    assert(vim.wait(3000, predicate, 10), "timed out waiting for Git file list")
end

describe("Git Markdown source process protocol", function()
    before_each(function()
        assert(uv.fs_chmod(fixture, 493))
    end)

    it("parses incremental NUL records and preserves newline paths", function()
        local result
        git_markdown_source.list({
            root = "/tmp/chunked",
            root_ordinal = 2,
            executable = fixture,
        }, function(value) result = value end)

        wait_for(function() return result ~= nil end)

        assert.same({
            root_ordinal = 2,
            status = "success",
            paths = { "alpha.md", "line\nbreak.md" },
        }, result)
    end)

    it("discards staged stdout on nonzero exit and bounds diagnostics", function()
        local result
        git_markdown_source.list({
            root = "/tmp/nonzero",
            root_ordinal = 1,
            executable = fixture,
        }, function(value) result = value end)

        wait_for(function() return result ~= nil end)

        assert.equals("failed", result.status)
        assert.equals(failure_kind.process_exit, result.failure.kind)
        assert.is_nil(result.paths)
        assert.is_true(#result.failure.diagnostic <= 512)
    end)

    it("fails an unterminated path fragment above the fixed cap", function()
        local result
        git_markdown_source.list({
            root = "/tmp/overlong",
            root_ordinal = 1,
            executable = fixture,
        }, function(value) result = value end)

        wait_for(function() return result ~= nil end)

        assert.equals("failed", result.status)
        assert.equals(failure_kind.path_fragment_too_long, result.failure.kind)
    end)

    it("cancels idempotently and suppresses delayed completion", function()
        local complete_count = 0
        local handle = git_markdown_source.list({
            root = "/tmp/delayed",
            root_ordinal = 1,
            executable = fixture,
        }, function() complete_count = complete_count + 1 end)

        handle:cancel()
        handle:cancel()
        vim.wait(400, function() return false end, 10)

        assert.is_true(handle:is_cancelled())
        assert.equals(0, complete_count)
    end)

    it("closes the process handle when a cancelled child exits later", function()
        local pipes = {}
        local exit_callback
        local process = { closed = false }
        function process:is_closing() return self.closed end
        function process:kill() return true end
        function process:close() self.closed = true end

        local fake_uv = {
            new_pipe = function()
                local pipe = { closed = false }
                function pipe:is_closing() return self.closed end
                function pipe:read_start(callback) self.callback = callback end
                function pipe:read_stop() end
                function pipe:close() self.closed = true end
                pipes[#pipes + 1] = pipe
                return pipe
            end,
            spawn = function(_, _, callback)
                exit_callback = callback
                return process
            end,
        }
        local complete_count = 0
        local handle = git_markdown_source.list({
            root = "/repo",
            root_ordinal = 1,
            uv = fake_uv,
        }, function() complete_count = complete_count + 1 end)

        handle:cancel()
        assert.is_false(process.closed)
        exit_callback(0)

        assert.is_true(process.closed)
        assert.equals(0, complete_count)
    end)
end)

local function write(path, lines)
    vim.fn.mkdir(vim.fn.fnamemodify(path, ":h"), "p")
    vim.fn.writefile(lines or { "# markdown" }, path)
end

local function git(git_executable, root, ...)
    local command = { git_executable, "-C", root, ... }
    vim.fn.system(command)
    assert.equals(0, vim.v.shell_error, table.concat(command, " "))
end

describe("real Git Markdown listing", function()
    local root
    local home
    local git_executable
    local env

    before_each(function()
        root = vim.fn.tempname() .. "-git-markdown"
        home = vim.fn.tempname() .. "-git-home"
        vim.fn.mkdir(root, "p")
        vim.fn.mkdir(home .. "/xdg", "p")
        git_executable = vim.fn.exepath("git")
        assert.are_not.equal("", git_executable)

        local excludes = home .. "/global-ignore"
        write(excludes, { "global.md" })
        write(home .. "/gitconfig", { "[core]", "\texcludesFile = " .. excludes })
        env = {
            "HOME=" .. home,
            "XDG_CONFIG_HOME=" .. home .. "/xdg",
            "GIT_CONFIG_GLOBAL=" .. home .. "/gitconfig",
            "GIT_CONFIG_NOSYSTEM=1",
            "PATH=" .. (vim.env.PATH or ""),
        }

        git(git_executable, root, "init", "-q")
        write(root .. "/tracked.md")
        git(git_executable, root, "add", "tracked.md")
        write(root .. "/.gitignore", { "*.md", "!free.md", "!line*" })
        write(root .. "/free.md")
        write(root .. "/ignored.md")
        write(root .. "/global.md")
        write(root .. "/line\nbreak.md")
        write(root .. "/.git/hidden.md")
        vim.fn.mkdir(root .. "/nested", "p")
        git(git_executable, root .. "/nested", "init", "-q")
        write(root .. "/nested/inside.md")
    end)

    after_each(function()
        vim.fn.delete(root, "rf")
        vim.fn.delete(home, "rf")
    end)

    it("returns tracked plus untracked nonignored Markdown without descending nested repos", function()
        local result
        git_markdown_source.list({
            root = root,
            root_ordinal = 1,
            executable = git_executable,
            env = env,
        }, function(value) result = value end)

        wait_for(function() return result ~= nil end)

        assert.equals("success", result.status)
        assert.same({ "free.md", "line\nbreak.md", "tracked.md" }, result.paths)
    end)

    it("maps nonrepositories and missing executables to root failures", function()
        local nonrepo = vim.fn.tempname() .. "-nonrepo"
        vim.fn.mkdir(nonrepo, "p")
        local results = {}
        git_markdown_source.list({
            root = nonrepo,
            root_ordinal = 1,
            executable = git_executable,
            env = env,
        }, function(value) results[1] = value end)
        git_markdown_source.list({
            root = nonrepo,
            root_ordinal = 2,
            executable = nonrepo .. "/missing-git",
            env = env,
        }, function(value) results[2] = value end)

        wait_for(function() return results[1] and results[2] end)
        vim.fn.delete(nonrepo, "rf")

        assert.equals(failure_kind.process_exit, results[1].failure.kind)
        assert.equals(failure_kind.process_spawn, results[2].failure.kind)
    end)
end)
