-- Architectural fitness function for the test harness's scratch placement.
--
-- The determinism of the whole suite rests on one invariant (#202): nothing the
-- harness writes may land inside the repo tree, because the find/grep/ack tool
-- specs traverse that tree while eight parallel jobs run, and a directory
-- vanishing mid-traversal makes `find` exit nonzero. Before this guard existed,
-- moving TEST_ENV_ROOT back under $(CURDIR) — or repointing nvim's swap
-- `directory` into the tree — would have gone unnoticed until the suite started
-- flaking again on unrelated specs.
--
-- Non-goals in the issue rejects a lint over *spec traversal roots*, and that
-- still stands: legitimate specs traverse cwd on purpose. This guards the
-- writer instead, which has no such false-positive problem.

local function canonical(path)
    if path == nil or path == "" then return nil end
    -- Resolve symlinks (/tmp -> /private/tmp on macOS) so the containment test
    -- compares like with like, and drop any trailing slash.
    local resolved = vim.fn.resolve(vim.fn.fnamemodify(path, ":p"))
    return (resolved:gsub("/+$", ""))
end

local function assert_outside_repo(label, path)
    local repo = canonical(vim.fn.getcwd())
    local target = canonical(path)
    assert.is_not_nil(target, label .. " must be set")
    assert.is_false(target == repo or target:sub(1, #repo + 1) == repo .. "/",
        ("%s resolves to %s, inside the repo at %s — the suite traverses this tree while writing (#202)")
            :format(label, target, repo))
end

describe("arch: harness scratch stays out of the repo tree", function()
    it("nvim's temp directory is outside the repo", function()
        -- tempname() is what every spec's scratch dir derives from, and it
        -- follows $TMPDIR. Asserting the produced path (not the env var) also
        -- covers nvim's fallback chain, whose last resort is the cwd.
        assert_outside_repo("vim.fn.tempname()", vim.fn.tempname())
    end)

    it("nvim's swap directory is outside the repo", function()
        for entry in vim.o.directory:gmatch("[^,]+") do
            assert_outside_repo("'directory' entry " .. entry, (entry:gsub("//$", "")))
        end
    end)

    for _, var in ipairs({ "HOME", "XDG_DATA_HOME", "XDG_STATE_HOME", "XDG_CACHE_HOME" }) do
        it("$" .. var .. " is outside the repo", function()
            assert_outside_repo("$" .. var, vim.env[var])
        end)
    end

    -- Each scratch root with a project-marked ancestor, or itself marked.
    -- tempname() names a file, so its directory is the root; $HOME is one (#338).
    local function marked_scratch(tempname, home)
        local marker = require("parley.config").repo_marker
        local found = {}
        for label, dir in pairs({ ["vim.fn.tempname()"] = vim.fn.fnamemodify(tempname, ":h"),
                ["$HOME"] = home }) do
            local root = require("parley.repo_mode").detect_root(dir, marker)
            if root then found[#found + 1] = ("%s (%s) sits under %s, which carries %s"):format(label, dir, root, marker) end
        end
        return found
    end

    it("scratch has no project-marked ancestor", function()
        -- Specs build profiles and "no project" scenarios under tempname(). A
        -- marked ancestor anywhere above it, this repo or any other, puts every
        -- such spec into project mode; the sweep under a TMPDIR in a marked
        -- tree failed 14 files (#338). Fail here, once, with the reason.
        assert.same({}, marked_scratch(vim.fn.tempname(), vim.env.HOME), "specs would enter project mode")
    end)

    it("the ancestor guard sees a marker in $HOME itself", function()
        local home = vim.fn.tempname()
        vim.fn.mkdir(home, "p")
        vim.fn.writefile({}, home .. "/" .. require("parley.config").repo_marker)
        local found = marked_scratch(vim.fn.tempname(), home)
        vim.fn.delete(home, "rf")
        assert.equals(1, #found)
        assert.matches("^%$HOME", found[1])
    end)

    -- #381 (#342's rule): a temp dir is made under $TMPDIR, never a fixed
    -- /tmp. Inside an agent's sandbox /tmp is denied, so a script or test that
    -- pins it fails on every Neovim version, and it bypasses the isolated
    -- TEST_ENV_ROOT. Shell `${TMPDIR:-/tmp}` and Python's `os.environ.get("TMPDIR")
    -- or "/tmp"` fall back to /tmp only when TMPDIR is unset, which is fine.
    local FIXED_TMP = {
        { lang = "python", pattern = "dir%s*=%s*['\"]/tmp['\"]" },
        { lang = "shell", pattern = "mktemp[^\n]-%s['\"]?/tmp/" },
    }
    local function fixed_tmp_roots(files)
        local found = {}
        for _, path in ipairs(files) do
            local ok, lines = pcall(vim.fn.readfile, path)
            for n, line in ipairs(ok and lines or {}) do
                for _, rule in ipairs(FIXED_TMP) do
                    if line:find(rule.pattern) then found[#found + 1] = ("%s:%d: %s"):format(path, n, vim.trim(line)) end
                end
            end
        end
        return found
    end

    it("no tracked script or test roots a temp dir at a fixed /tmp", function()
        local files = vim.fn.systemlist({ "git", "ls-files", "--", "tests", "scripts", "Makefile*" })
        assert.equals(0, vim.v.shell_error, "git ls-files failed")
        assert.is_true(#files > 50, "the scan found almost no files")
        assert.same({}, fixed_tmp_roots(files))
    end)

    it("the /tmp guard sees both forms it refuses, and passes the fallbacks", function()
        local dir = vim.fn.tempname()
        vim.fn.mkdir(dir, "p")
        -- Spelled in pieces, so this spec's own source never matches the scan.
        local tmp = "/" .. "tmp"
        vim.fn.writefile({ "tempfile.TemporaryDirectory(prefix='x-', dir='" .. tmp .. "')",
            'with tempfile.TemporaryDirectory(dir=os.environ.get("TMPDIR") or "' .. tmp .. '"):' }, dir .. "/a.py")
        vim.fn.writefile({ "d=$(mktemp -d " .. tmp .. "/x.XXXXXX)", 'd=$(mktemp -d "${TMPDIR:-' .. tmp .. '}/x.XXXXXX")' }, dir .. "/b.sh")
        local found = fixed_tmp_roots({ dir .. "/a.py", dir .. "/b.sh" })
        vim.fn.delete(dir, "rf")
        assert.equals(2, #found, vim.inspect(found))
        assert.matches("a%.py:1:", found[1])
        assert.matches("b%.sh:1:", found[2])
    end)
end)
