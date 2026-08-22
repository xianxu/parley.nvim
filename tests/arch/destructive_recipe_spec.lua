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
-- itself constructed and can name literally, each quoted individually.** A
-- comment saying so is not a guard, so this asserts it against the *expansion*
-- rather than the source text — word-split exactly as the shell would, which is
-- the only reading that catches the quoting shape.

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

local function is_within(path, root)
    return path == root or path:sub(1, #root + 1) == root .. "/"
end

describe("arch: test-clean-env only deletes what the harness built", function()
    it("never targets the caller-supplied root, only leaves beneath it", function()
        -- A space in the probe root exercises the quoting half of the rule too.
        local probe = vim.fn.tempname() .. "/probe root"
        local repo = vim.fn.getcwd()
        local words = rm_arguments(("make -f Makefile.parley -n test-clean-env TEST_ENV_ROOT=%s")
            :format(vim.fn.shellescape(probe)))

        assert.is_true(#words > 0, "rm -rf expanded to no arguments")
        for _, word in ipairs(words) do
            assert.equals("/", word:sub(1, 1),
                ("%q is not an absolute path — the argument list word-split"):format(word))
            assert.is_false(word == probe,
                "rm -rf targets the caller-supplied TEST_ENV_ROOT itself, not a leaf the harness built")
            assert.is_true(is_within(word, probe) or is_within(word, repo),
                ("%q is outside both the scratch root and the repo"):format(word))
            assert.is_false(is_within(probe, word) and word ~= probe,
                ("%q is an ancestor of the scratch root"):format(word))
        end
    end)

    it("stays word-tight when the checkout path contains a space", function()
        -- $(CURDIR) drives the legacy in-repo paths, and it cannot be overridden
        -- from here — so run the recipe from a copy under a spaced directory.
        local dir = vim.fn.tempname() .. "/space test"
        vim.fn.mkdir(dir, "p")
        run(("cp %s %s"):format(vim.fn.shellescape(vim.fn.getcwd() .. "/Makefile.parley"),
            vim.fn.shellescape(dir .. "/Makefile.parley")))

        local words = rm_arguments(("cd %s && make -f Makefile.parley -n test-clean-env")
            :format(vim.fn.shellescape(dir)))

        for _, word in ipairs(words) do
            assert.equals("/", word:sub(1, 1),
                ("%q is not an absolute path — the argument list word-split"):format(word))
            assert.is_false(is_within(dir, word) and word ~= dir,
                ("%q is an ancestor of the checkout — a split fragment"):format(word))
        end
    end)
end)
