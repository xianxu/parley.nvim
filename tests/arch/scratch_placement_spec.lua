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

-- Whether path lies strictly below dir (both already canonical).
local function is_under(dir, path)
    return path:sub(1, #dir + 1) == dir .. "/"
end

local function assert_outside_repo(label, path)
    local repo = canonical(vim.fn.getcwd())
    local target = canonical(path)
    assert.is_not_nil(target, label .. " must be set")
    assert.is_false(target == repo or is_under(repo, target),
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

    it("nvim's temp directory is the harness TMPDIR, not a fallback (#423)", function()
        -- A $TMPDIR nvim refuses (too long, unusable) silently becomes /tmp/nvim.<user>.
        local tmp = canonical(vim.env.TMPDIR)
        assert.is_not_nil(tmp, "$TMPDIR must be set")
        local made = canonical(vim.fn.fnamemodify(vim.fn.tempname(), ":h"))
        assert.is_true(is_under(tmp, made),
            ("vim.fn.tempname() is under %s, not $TMPDIR %s"):format(made, tmp))
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
    -- Every spelling of the class, not only the ones #381 swept: Python's
    -- dir= with any /tmp path or Path('/tmp'); shell mktemp by template,
    -- -p or --tmpdir; Lua opening or making a literal /tmp path.
    local FIXED_TMP = {
        { lang = "python", pattern = "dir%s*=%s*[%w_.]*%(?%s*['\"]/tmp[/'\"]" },
        -- A mktemp command can sit inside any language (vim.fn.system,
        -- subprocess), so these read every file.
        -- Quotes and commas may separate the words (a Python argv list).
        { pattern = "mktemp.-[%s'\",]/tmp/" },
        { pattern = "mktemp.-%-p[%s'\",]*/tmp" },
        { pattern = "mktemp.-%-%-tmpdir[=%s'\",]*/tmp" },
        { lang = "lua", pattern = "io%.open%(%s*['\"]/tmp/" },
        { lang = "lua", pattern = "mkdir%(%s*['\"]/tmp" },
        { lang = "lua", pattern = "writefile%(.-,%s*['\"]/tmp/" },
    }
    -- A rule is scoped to a language only where it would otherwise misfire:
    -- Lua's `dir = f("/tmp/…")` is a path string, not Python's dir= keyword.
    local function lang_of(path)
        if path:match("%.py$") then return "python" end
        if path:match("%.lua$") then return "lua" end
        return "shell"
    end
    local function fixed_tmp_roots(files)
        local found = {}
        for _, path in ipairs(files) do
            local ok, lines = pcall(vim.fn.readfile, path)
            local lang = lang_of(path)
            for n, line in ipairs(ok and lines or {}) do
                for _, rule in ipairs(FIXED_TMP) do
                    if (rule.lang == nil or rule.lang == lang) and line:find(rule.pattern) then
                        found[#found + 1] = ("%s:%d: %s"):format(path, n, vim.trim(line))
                    end
                end
            end
        end
        return found
    end

    it("no script or test roots a temp dir at a fixed /tmp", function()
        local files = require("tests.arch.arch_helper").worktree_files({ "tests", "scripts", "Makefile*" })
        assert.is_true(#files > 50, "the scan found almost no files")
        assert.same({}, fixed_tmp_roots(files))
    end)

    it("the /tmp guard sees every spelling it refuses, and passes the fallbacks", function()
        local dir = vim.fn.tempname()
        vim.fn.mkdir(dir, "p")
        -- Spelled in pieces, so this spec's own source never matches the scan.
        local tmp = "/" .. "tmp"
        local refused = {
            py = { "tempfile.TemporaryDirectory(prefix='x-', dir='" .. tmp .. "')",
                "tempfile.mkdtemp(dir='" .. tmp .. "/')", "tempfile.mkdtemp(dir='" .. tmp .. "/sub')",
                "tempfile.mkdtemp(dir=Path('" .. tmp .. "'))", "subprocess.run(['mktemp', '-d', '-p', '" .. tmp .. "'])" },
            sh = { "d=$(mktemp -d " .. tmp .. "/x.XXXXXX)", "d=$(mktemp -d -p " .. tmp .. " x.XXXXXX)",
                "d=$(mktemp -d --tmpdir=" .. tmp .. " x.XXXXXX)" },
            lua = { 'io.open("' .. tmp .. '/x", "w")', 'vim.fn.mkdir("' .. tmp .. '/x", "p")',
                'vim.fn.writefile({ "a" }, "' .. tmp .. '/x")', 'vim.fn.system("mktemp -d ' .. tmp .. '/x.XXXXXX")' },
        }
        local allowed = {
            py = { 'tempfile.TemporaryDirectory(dir=os.environ.get("TMPDIR") or "' .. tmp .. '")' },
            sh = { 'd=$(mktemp -d "${TMPDIR:-' .. tmp .. '}/x.XXXXXX")' },
            lua = { 'vim.fn.writefile({ "' .. tmp .. '/only/content" }, path)', 'vim.fn.mkdir(scratch .. "' .. tmp .. '", "p")' },
        }
        local files, expected = {}, 0
        for ext, lines in pairs(refused) do
            local path = dir .. "/x." .. ext
            vim.fn.writefile(vim.list_extend(vim.deepcopy(lines), allowed[ext]), path)
            files[#files + 1], expected = path, expected + #lines
        end
        local found = fixed_tmp_roots(files)
        vim.fn.delete(dir, "rf")
        assert.equals(expected, #found, vim.inspect(found))
        for _, hit in ipairs(found) do
            local n = tonumber(hit:match(":(%d+):"))
            local ext = hit:match("x%.(%a+):")
            assert.is_true(n <= #refused[ext], "an allowed fallback was refused: " .. hit)
        end
    end)
end)

-- #422: the same rule, checked once before PREP_TEST_ENV creates anything. An
-- inside-checkout review put TMPDIR in the clone; the zero-config spec then
-- found the clone's marker and wrote a chat into its workshop/parley.
describe("arch: the pre-write placement guard", function()
    -- Every root is relative to base (the guard runs with cwd = base), so the
    -- fixtures stay short however long the accepted harness TMPDIR is (#423).
    local marker = require("parley.config").repo_marker
    local script = vim.fn.getcwd() .. "/scripts/test-placement.sh"
    local base
    before_each(function()
        base = vim.fn.tempname()
        vim.fn.mkdir(base .. "/checkout", "p")
        base = vim.uv.fs_realpath(base)
    end)
    after_each(function() vim.fn.delete(base, "rf") end)

    local function guard(root)
        return vim.system({ script, root, "checkout", marker }, { cwd = base, text = true }):wait()
    end

    it("refuses a root under a marked tree and creates nothing there", function()
        vim.fn.mkdir(base .. "/clone", "p")
        vim.fn.writefile({}, base .. "/clone/" .. marker)
        local result = guard("clone/.sdlc-review/tmp/parley-test-env/key")
        assert.equals(1, result.code, result.stderr)
        assert.matches("is under " .. vim.pesc(base .. "/clone") .. ", which carries " .. vim.pesc(marker), result.stderr)
        assert.equals(0, vim.fn.isdirectory(base .. "/clone/.sdlc-review"))
    end)

    it("refuses a root that carries the marker itself", function()
        vim.fn.mkdir(base .. "/root", "p")
        vim.fn.writefile({}, base .. "/root/" .. marker)
        assert.equals(1, guard("root").code)
    end)

    it("ignores a marker-named directory, as repo detection does", function()
        vim.fn.mkdir(base .. "/scratch/" .. marker, "p")
        assert.equals(0, guard("scratch/" .. marker .. "/env").code)
        assert.is_nil(require("parley.repo_mode").detect_root(base .. "/scratch/" .. marker, marker))
    end)

    it("refuses a root inside the checkout even without a marker", function()
        local result = guard("checkout/.test-env")
        assert.equals(1, result.code, result.stderr)
        assert.matches("inside the checkout", result.stderr)
    end)

    it("accepts an unmarked root outside the checkout, existing or not", function()
        assert.equals(0, guard("scratch/not/yet").code)
        vim.fn.mkdir(base .. "/scratch/now", "p")
        assert.equals(0, guard("scratch/now").code)
    end)

    local function limit()
        for _, line in ipairs(vim.fn.readfile(script)) do
            local n = line:match("^TMPDIR_MAX=(%d+)$")
            if n then return tonumber(n) end
        end
    end
    -- A relative root whose TMPDIR (root .. "/tmp") is exactly n bytes, built from unit.
    local function root_of(n, unit)
        unit = unit or "a"
        local body = n - #"/tmp"
        assert(body % #unit == 0, "length must be a multiple of the unit")
        return string.rep(unit, body / #unit)
    end

    it("refuses a root whose TMPDIR Neovim would ignore, and creates nothing (#423)", function()
        local max = limit()
        assert.equals(0, guard(root_of(max)).code)
        local result = guard(root_of(max + 1))
        assert.equals(1, result.code, result.stderr)
        assert.matches(("is %d bytes; Neovim ignores a TMPDIR over %d bytes"):format(max + 1, max), result.stderr)
        assert.equals(0, vim.fn.isdirectory(base .. "/" .. root_of(max + 1)))
    end)

    it("counts the TMPDIR limit in bytes, not characters (#423)", function()
        -- "é" is two bytes: fewer characters than the limit, more bytes.
        local max = limit()
        local root = root_of(max + 1 + (max + 1 - #"/tmp") % 2, "é")
        local result = guard(root)
        assert.equals(1, result.code, result.stderr)
        assert.matches(("is %d bytes"):format(#root + #"/tmp"), result.stderr)
    end)

    it("reports a marker before the TMPDIR length", function()
        vim.fn.mkdir(base .. "/clone", "p")
        vim.fn.writefile({}, base .. "/clone/" .. marker)
        local result = guard("clone/" .. root_of(limit() + 1 - #"clone/"))
        assert.equals(1, result.code, result.stderr)
        assert.matches("which carries", result.stderr)
    end)

    it("pins the TMPDIR limit to the running Neovim (#423)", function()
        -- Neovim checks $TMPDIR as given, then separately limits its absolute
        -- path to about 234 bytes. The probe pads a relative "t" with "./" to an
        -- exact raw length. Its absolute path stays base/t, inside that second
        -- limit at any base the harness accepts.
        local max = limit()
        vim.fn.mkdir(base .. "/t", "p")
        local function used(n)
            local dir = string.rep("./", math.floor((n - 1) / 2)) .. (n % 2 == 1 and "t" or "t/")
            assert(#dir == n)
            local out = vim.system({ vim.v.progpath, "--clean", "--headless", "-i", "NONE",
                "-c", "lua io.stdout:write(vim.fn.tempname())", "-c", "qa!" },
                { cwd = base, text = true, env = { TMPDIR = dir } }):wait(10000)
            assert.equals(0, out.code, out.stderr)
            return is_under(base .. "/t", out.stdout)
        end
        assert.is_true(used(max), "Neovim refused a TMPDIR of the guard's limit, " .. max .. " bytes")
        assert.is_false(used(max + 1), "Neovim accepted a TMPDIR over the guard's limit, " .. max .. " bytes")
    end)

    it("is wired into PREP_TEST_ENV with the configured marker", function()
        local makefile = table.concat(vim.fn.readfile("Makefile.parley"), "\n")
        assert.matches("\nREPO_MARKER := " .. vim.pesc(marker) .. "\n", makefile)
        assert.matches('define PREP_TEST_ENV\n"%$%(CURDIR%)/scripts/test%-placement%.sh" "%$%(TEST_ENV_ROOT%)" "%$%(CURDIR%)" "%$%(REPO_MARKER%)" &&', makefile)
    end)
end)
