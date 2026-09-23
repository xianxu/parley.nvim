-- #220: every process the test harness starts names its end (ARCH-FUNERAL).
--
-- lua/ is covered by tests/arch/spawn_seam_spec.lua; this is the tests/ half.
-- A spec spawn goes through fixture_process, a blocking fixture watches its
-- parent, both watchdogs handle being orphaned during startup, and the manual
-- remedy must use the ps listing that works on macOS.
local arch = require("tests.arch.arch_helper")

local SEAM = "tests/helpers/fixture_process.lua"
local CANNOT_BLOCK = {
    ["tests/fixtures/fake_clipboard"] = "one conversion, bounded by PARLEY_FAKE_CLIPBOARD_DELAY_MS",
    ["tests/fixtures/fake_git_file_list"] = "prints a file list and exits",
    ["tests/fixtures/fake_packaging_curl"] = "one canned response",
    ["tests/fixtures/fake_packaging_upgrade_brew"] = "one canned upgrade transcript",
    ["tests/fixtures/fake_ps"] = "prints PARLEY_FAKE_PS_ROWS and exits",
    ["tests/fixtures/fake_sdlc"] = "one canned sdlc response",
    ["tests/fixtures/fake_tart"] = "one canned VM response",
    ["tests/fixtures/fake_vocabulary"] = "one canned export",
    ["tests/fixtures/orphan_me.sh"] = "exits immediately by design; it creates the orphan",
}

local function uncommented(path)
    local kept = {}
    for _, line in ipairs(vim.fn.readfile(path)) do
        kept[#kept + 1] = line:match("^%s*[#%-][#%-]?") and "" or line
    end
    return table.concat(kept, "\n")
end

describe("arch: fixture process lifecycle", function()
    it("no spec or helper spawns outside the fixture seam", function()
        local offenders, seam_spawns = {}, 0
        local files = arch.worktree_files({ "tests/**/*.lua" })
        assert.is_true(#files > 0, "selected no files")
        for _, file in ipairs(files) do
            for line_number, raw in ipairs(vim.fn.readfile(file)) do
                if not raw:match("^%s*%-%-") and raw:find("uv%.spawn%(") then
                    if file == SEAM then
                        seam_spawns = seam_spawns + 1
                    else
                        offenders[#offenders + 1] = file .. ":" .. line_number
                    end
                end
            end
        end
        assert.equals(1, seam_spawns, SEAM .. " must hold exactly one uv.spawn")
        table.sort(offenders)
        assert.same({}, offenders, "spawn through tests.helpers.fixture_process")
    end)

    it("every executable fixture either watches its parent or declares why it cannot block", function()
        assert.is_truthy(uncommented("tests/fixtures/loopback_http.py"):find("exit_with_parent%s*%("),
            "LoopbackHTTPServer must install the watchdog it supplies to fixtures")
        local files, seen, offenders = {}, {}, {}
        for _, file in ipairs(arch.worktree_files({ "tests/fixtures/*" })) do
            if vim.fn.executable(file) == 1 then
                files[#files + 1] = file
                seen[file] = true
                if not CANNOT_BLOCK[file] then
                    local text = uncommented(file)
                    if not text:find("exit_with_parent%s*%(")
                        and not text:find("LoopbackHTTPServer%s*%(") then
                        offenders[#offenders + 1] = file .. ": no parent-death watchdog"
                    end
                end
            end
        end
        for file in pairs(CANNOT_BLOCK) do
            if not seen[file] then offenders[#offenders + 1] = file .. ": stale exemption" end
        end
        for _, file in ipairs({ "fake_cliproxy", "fake_github_releases", "fake_sse_server" }) do
            local path = "tests/fixtures/" .. file
            assert.is_true(seen[path] == true, path .. " missing from executable corpus")
        end
        -- The login and slow-conversion paths never construct an HTTP server.
        for _, file in ipairs({ "fake_cliproxy", "fake_sips" }) do
            local path = "tests/fixtures/" .. file
            if not uncommented(path):find("exit_with_parent%s*%(") then
                offenders[#offenders + 1] = path .. ": non-server path lacks direct watchdog"
            end
        end
        table.sort(offenders)
        assert.same({}, offenders)
        -- run_without_dns.py and run_packaging_vm.py are mode 644, outside
        -- this executable-fixture corpus.
        assert.equals(13, #files, "expected 9 finite fixtures and 4 watched fixtures")
    end)

    it("both watchdogs recognize a parent already reparented to init", function()
        local pair = {
            { path = "tests/fixtures/fixture_watchdog.py", peer = "tests/helpers/exit_with_parent.lua" },
            { path = "tests/helpers/exit_with_parent.lua", peer = "tests/fixtures/fixture_watchdog.py" },
        }
        local offenders = {}
        for _, member in ipairs(pair) do
            local text = table.concat(vim.fn.readfile(member.path), "\n")
            if not text:find("return%s+ppid%s*==%s*1%s+or") then
                offenders[#offenders + 1] = member.path .. ": no ppid == 1 rule"
            end
            if not text:find(member.peer, 1, true) then
                offenders[#offenders + 1] = member.path .. ": no cross-reference to " .. member.peer
            end
        end
        assert.same({}, offenders)
    end)

    it("TOOLING.md's remedy uses ps, and warns about pgrep", function()
        local doc = table.concat(vim.fn.readfile("TOOLING.md"), "\n")
        assert.is_truthy(doc:find("ps %-Ao"), "no ps-based listing command")
        assert.is_truthy(doc:find("pgrep"), "no pgrep caveat")
        assert.is_nil(doc:match("\n%s*pgrep %-f"), "TOOLING.md offers a pgrep remedy")
    end)
end)
