-- Architectural fitness function for the harness's one destructive recipe.
--
-- `make test-clean-env` runs first in every `make test`, and it produced two
-- Important review findings in a row on #202:
--
--   * the ownership defect — it wiped "$(TEST_ENV_ROOT)" verbatim, and that is
--     a documented override that propagates to the sub-make, so
--     `make test TEST_ENV_ROOT=/some/where` expanded to `rm -rf /some/where`;
--   * the quoting defect — an unquoted path list word-splits, so a checkout at
--     `~/my code/parley.nvim` expanded to `rm -rf ~/my`.
--
-- The rule both violate: **a destructive recipe may only remove paths the tool
-- itself constructed and can name literally, each quoted individually.**
--
-- This asserts that rule *itself* — the removed set must equal the set the
-- harness builds, exactly — rather than a proxy like "every path is inside the
-- repo or the scratch root". The first draft of this guard used that proxy and
-- waved `rm -rf "$(CURDIR)"` straight through, because $(CURDIR) is contained
-- in $(CURDIR). A guard that only rejects the shapes already seen is not a
-- guard for the rule (ARCH-PURPOSE).
--
-- It reads the *expansion* rather than the source text, which is the only
-- reading that catches the quoting shape. Adding a legitimate new scratch leaf
-- means updating EXPECTED_LEAVES here — that is the fitness function working,
-- not friction.

-- The leaves PREP_TEST_ENV constructs under the scratch root, and the pre-#202
-- in-repo dirs test-clean-env still retires. Anything else in the recipe's
-- argument list is a path the harness did not build.
local SCRATCH_LEAVES = { "home", "xdg", "tmp" }
local LEGACY_LEAVES = { ".test-home", ".test-xdg", ".test-tmp" }

local function run(cmd)
    local out = vim.fn.system(cmd)
    assert.equals(0, vim.v.shell_error, cmd .. " failed:\n" .. out)
    return out
end

--- The `rm -rf` argument list, split exactly as /bin/sh would split it.
local function rm_arguments(make_cmd)
    local recipe
    for line in run(make_cmd):gmatch("[^\n]+") do
        local args = line:match("^%s*rm%s+%-rf%s+(.+)$")
        if args then
            assert.is_nil(recipe, "expected exactly one rm -rf line, got a second: " .. line)
            recipe = args
        end
    end
    assert.is_not_nil(recipe, "test-clean-env no longer runs rm -rf; update this guard")

    -- `set --`, not `eval set --`: make hands the recipe to `sh -c`, which parses
    -- it ONCE. eval would parse twice, consuming the quotes on the first pass and
    -- re-splitting "a b" into two words — which would report a false violation on
    -- a correctly quoted recipe.
    local script = vim.fn.tempname() .. "-split.sh"
    vim.fn.writefile({ "set -- " .. recipe, 'printf "%s\\n" "$@"' }, script)
    local words = {}
    for word in run("sh " .. vim.fn.shellescape(script)):gmatch("[^\n]+") do
        table.insert(words, word)
    end
    return words
end

--- make reports $(CURDIR) as the *physical* path, so a checkout reached through
--- a symlink (on macOS every /tmp/... path is really /private/tmp/...) expands
--- to a spelling the caller's own string does not match. Ask the same authority
--- make uses rather than canonicalizing by hand — these probe paths need not
--- exist yet, which rules out resolve()-style normalization.
local function physical(dir)
    return (run(("cd %s && pwd -P"):format(vim.fn.shellescape(dir))):gsub("%s+$", ""))
end

--- The exact set test-clean-env is allowed to remove, given the two roots it
--- derives from.
local function expected_removals(scratch_root, checkout)
    local expected = {}
    for _, leaf in ipairs(SCRATCH_LEAVES) do
        expected[scratch_root .. "/" .. leaf] = true
    end
    for _, leaf in ipairs(LEGACY_LEAVES) do
        expected[checkout .. "/" .. leaf] = true
    end
    return expected
end

local function assert_removes_exactly(words, expected)
    local seen = {}
    for _, word in ipairs(words) do
        assert.is_true(expected[word] == true,
            ("rm -rf targets %q, which is not a path the harness constructs"):format(word))
        seen[word] = true
    end
    for path in pairs(expected) do
        assert.is_true(seen[path] == true,
            ("rm -rf no longer removes %q — update this guard if that is intended"):format(path))
    end
end

describe("arch: test-clean-env only deletes what the harness built", function()
    it("removes exactly the harness-built leaves, never the caller-supplied root", function()
        -- A space in the probe root exercises the quoting half of the rule too.
        local probe = vim.fn.tempname() .. "/probe root"
        local words = rm_arguments(("make -f Makefile.parley -n test-clean-env TEST_ENV_ROOT=%s")
            :format(vim.fn.shellescape(probe)))
        assert.is_true(#words > 0, "rm -rf expanded to no arguments")
        assert_removes_exactly(words, expected_removals(probe, physical(vim.fn.getcwd())))
    end)

    it("stays word-tight when the checkout path contains a space", function()
        -- $(CURDIR) drives the legacy in-repo paths and cannot be overridden from
        -- here, so run the recipe from a copy under a spaced directory.
        local dir = vim.fn.tempname() .. "/space test"
        vim.fn.mkdir(dir, "p")
        run(("cp %s %s"):format(vim.fn.shellescape(vim.fn.getcwd() .. "/Makefile.parley"),
            vim.fn.shellescape(dir .. "/Makefile.parley")))

        local probe = vim.fn.tempname() .. "/probe root"
        local words = rm_arguments(("cd %s && make -f Makefile.parley -n test-clean-env TEST_ENV_ROOT=%s")
            :format(vim.fn.shellescape(dir), vim.fn.shellescape(probe)))
        assert_removes_exactly(words, expected_removals(probe, physical(dir)))
    end)

    it("wipes before the suite starts, not partway through it", function()
        -- What the recursive $(MAKE) ordering in the `test` recipe exists to
        -- guarantee: prerequisite order only holds under serial make, so a
        -- regression to `test: test-clean-env lint ...` would let `make -j`
        -- schedule the wipe into a running suite.
        local wipe, first_use
        local index = 0
        for line in run("make -n test"):gmatch("[^\n]+") do
            index = index + 1
            if not wipe and line:match("^%s*rm%s+%-rf%s") then wipe = index end
            if not first_use and (line:match("mkdir%s+%-p") or line:match("nvim%s")) then
                first_use = index
            end
        end
        assert.is_not_nil(wipe, "make test no longer wipes the scratch")
        assert.is_not_nil(first_use, "make test no longer creates or uses the scratch")
        assert.is_true(wipe < first_use,
            ("the wipe is emitted at line %d, after the scratch is first used at line %d")
                :format(wipe, first_use))
    end)
end)
