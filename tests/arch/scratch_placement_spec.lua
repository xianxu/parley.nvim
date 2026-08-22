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
end)
