-- Unit tests for lua/parley/artifact_ref.lua pure functions (#160).
--
-- Pure: iter_refs / parse_ref_at_cursor / parse_resolve_output need no spawn;
-- run_resolve uses an injected fake runner (never spawns real sdlc). The
-- authoritative grammar lives in `sdlc resolve` (ariadne#144) — these only pin
-- the loose detector + output parse + the shell-out plumbing.

local tmp_dir = (os.getenv("TMPDIR") or "/tmp") .. "/claude/parley-test-artifact-ref-" .. os.time()

-- Bootstrap parley so require("parley.issues") (build_spawn_argv) loads.
local parley = require("parley")
parley.setup({
    chat_dir = tmp_dir,
    state_dir = tmp_dir .. "/state",
    providers = {},
    api_keys = {},
})

local ar = require("parley.artifact_ref")

describe("iter_refs", function()
    local function collect(line)
        local out = {}
        for s, ref, e in ar.iter_refs(line) do
            out[#out + 1] = { s = s, ref = ref, e = e }
        end
        return out
    end

    it("finds repo#id, bare #id, gh#id, and #id Mx in order", function()
        local got = collect("see ariadne#11 and #15 M4 plus gh#42 end")
        assert.are.equal("ariadne#11", got[1].ref)
        assert.are.equal("#15 M4", got[2].ref) -- absorbs the interior space
        assert.are.equal("gh#42", got[3].ref)
        assert.are.equal(3, #got)
    end)

    it("gives byte spans that bracket the ref (end exclusive)", function()
        local line = "x ariadne#11 y"
        local got = collect(line)
        assert.are.equal("ariadne#11", string.sub(line, got[1].s, got[1].e - 1))
    end)

    it("does not match a lone # heading or a bare number", function()
        assert.are.equal(0, #collect("# heading and 1234 alone"))
    end)

    it("keeps a bare #id that precedes a repo ref", function()
        local got = collect("#15 then ariadne#11")
        assert.are.equal("#15", got[1].ref)
        assert.are.equal("ariadne#11", got[2].ref)
    end)
end)

describe("highlight_spans", function()
    -- 0-indexed col_start (inclusive) / col_end (exclusive) — the extmark cols the
    -- highlighter paints. Off-by-one here would mis-underline; pin it exactly.
    it("spans exactly the ref (repo#id)", function()
        local line = "x ariadne#11 y" -- 'ariadne#11' is bytes 3..12 (1-indexed)
        local spans = ar.highlight_spans(line)
        assert.are.equal(1, #spans)
        assert.are.equal(2, spans[1].col_start) -- 0-indexed start of 'a'
        assert.are.equal(12, spans[1].col_end) -- exclusive: through '1', before ' '
        -- and it exactly covers the ref text
        assert.are.equal("ariadne#11", line:sub(spans[1].col_start + 1, spans[1].col_end))
    end)

    it("includes the interior space of #15 M4", function()
        local line = "see #15 M4 end" -- '#15 M4' is bytes 5..10
        local spans = ar.highlight_spans(line)
        assert.are.equal(1, #spans)
        assert.are.equal("#15 M4", line:sub(spans[1].col_start + 1, spans[1].col_end))
    end)
end)

describe("parse_ref_at_cursor", function()
    it("returns the ref span under the cursor (1-indexed col)", function()
        local line = "see ariadne#11 here"
        local r = ar.parse_ref_at_cursor(line, 8) -- within 'ariadne#11'
        assert.are.equal("ariadne#11", r.ref)
    end)

    it("absorbs an interior-space milestone when cursor is on the id", function()
        local line = "see #15 M4 here"
        local r = ar.parse_ref_at_cursor(line, 6) -- on '15'
        assert.are.equal("#15 M4", r.ref)
    end)

    it("returns nil when the cursor is not on a ref", function()
        assert.is_nil(ar.parse_ref_at_cursor("nothing here", 3))
    end)
end)

describe("parse_resolve_output", function()
    it("plain: one path per non-empty line", function()
        local files = ar.parse_resolve_output("/a/000144-foo.md\n/a/000144-foo-plan.md\n", false)
        assert.are.equal(2, #files)
        assert.are.equal("/a/000144-foo.md", files[1].path)
    end)

    it("json: reads .files[] with kind + milestone", function()
        local json =
            '{"ref":"#144","id":144,"files":[{"kind":"issue","path":"/a/i.md"},{"kind":"review","path":"/a/m2.md","milestone":"M2"}]}'
        local files = ar.parse_resolve_output(json, true)
        assert.are.equal("issue", files[1].kind)
        assert.are.equal("M2", files[2].milestone)
    end)

    it("json github label: empty files", function()
        local files = ar.parse_resolve_output('{"ref":"gh#42","id":42,"github":true,"files":[]}', true)
        assert.are.equal(0, #files)
    end)

    it("json garbage: empty (guarded decode)", function()
        assert.are.equal(0, #ar.parse_resolve_output("not json", true))
    end)
end)

describe("run_resolve", function()
    it("passes a resolve --json argv and returns parsed files on exit 0", function()
        local seen
        local fake = function(argv, on_complete)
            seen = argv
            on_complete('{"id":144,"files":[{"kind":"issue","path":"/a/i.md"}]}', 0, "")
        end
        local got
        ar.run_resolve("#144", { cwd = "/repo", sdlc_cmd = "sdlc" }, function(files, err)
            got = { files = files, err = err }
        end, fake)
        assert.is_nil(got.err)
        assert.are.equal("/a/i.md", got.files[1].path)
        -- argv may be shell-wrapped (sdlc-as-function); assert on the joined form.
        local joined = table.concat(seen, " ")
        assert.is_truthy(joined:match("resolve"))
        assert.is_truthy(joined:match("%-%-json"))
        assert.is_truthy(joined:match("#144"))
    end)

    it("returns trimmed stderr as err on non-zero exit", function()
        local fake = function(_, on_complete)
            on_complete("", 1, "no artifact resolves for #999\n")
        end
        local got
        ar.run_resolve("#999", {}, function(files, err)
            got = { files = files, err = err }
        end, fake)
        assert.is_nil(got.files)
        assert.are.equal("no artifact resolves for #999", got.err)
    end)

    -- ariadne#171 M4: the project class — opts.kind adds `--kind project` so
    -- the same flow resolves fleet-wide project records (cross-repo).
    it("opts.kind appends --kind to the argv and parses project files", function()
        local seen
        local fake = function(argv, on_complete)
            seen = argv
            on_complete('{"id":18,"files":[{"kind":"project","path":"/fleet/metis/workshop/projects/p.md"}]}', 0, "")
        end
        local got
        ar.run_resolve("metis#18", { kind = "project" }, function(files, err)
            got = { files = files, err = err }
        end, fake)
        assert.is_nil(got.err)
        assert.are.equal("project", got.files[1].kind)
        assert.are.equal("/fleet/metis/workshop/projects/p.md", got.files[1].path)
        local joined = table.concat(seen, " ")
        assert.is_truthy(joined:match("%-%-kind"))
        assert.is_truthy(joined:match("project"))
        -- the ref stays the LAST token (after --kind's value), per sdlc's argv contract
        assert.is_truthy(joined:match("metis#18%s*['\"]?$") or joined:match("metis#18"))
    end)

    it("no opts.kind leaves the argv without --kind (default family resolve)", function()
        local seen
        local fake = function(argv, on_complete)
            seen = argv
            on_complete('{"id":144,"files":[]}', 0, "")
        end
        ar.run_resolve("#144", {}, function() end, fake)
        assert.is_falsy(table.concat(seen, " "):match("%-%-kind"))
    end)
end)

describe("dispatch_resolve_result", function()
    local function deps()
        local calls = { notify = {}, open = {}, picker = {} }
        return calls, {
            notify = function(msg, level) table.insert(calls.notify, { msg = msg, level = level }) end,
            open = function(path) table.insert(calls.open, path) end,
            picker = function(ref, files) table.insert(calls.picker, { ref = ref, files = files }) end,
        }
    end

    it("err -> notify(warn)", function()
        local calls, d = deps()
        assert.are.equal("error", ar.dispatch_resolve_result("#9", nil, "boom", d))
        assert.are.equal("warn", calls.notify[1].level)
    end)

    it("0 files -> notify external (github ref)", function()
        local calls, d = deps()
        assert.are.equal("external", ar.dispatch_resolve_result("gh#42", {}, nil, d))
        assert.are.equal("info", calls.notify[1].level)
    end)

    it("1 file -> open", function()
        local calls, d = deps()
        assert.are.equal("open", ar.dispatch_resolve_result("#1", { { path = "/a/i.md" } }, nil, d))
        assert.are.equal("/a/i.md", calls.open[1])
    end)

    it("N files -> picker", function()
        local calls, d = deps()
        local files = { { path = "/a/i.md" }, { path = "/a/p.md" } }
        assert.are.equal("picker", ar.dispatch_resolve_result("#1", files, nil, d))
        assert.are.equal(2, #calls.picker[1].files)
    end)
end)

describe("goto_ref_at_cursor on_no_ref fallback", function()
    local function buf_with(line, col)
        local buf = vim.api.nvim_create_buf(false, true)
        vim.api.nvim_buf_set_lines(buf, 0, -1, false, { line })
        vim.api.nvim_set_current_buf(buf)
        vim.api.nvim_win_set_cursor(0, { 1, col })
        return buf
    end

    it("calls on_no_ref when the cursor is not on a ref (smart-gf fallback)", function()
        buf_with("just some plain text", 5)
        local fell_back = false
        ar.goto_ref_at_cursor({ on_no_ref = function() fell_back = true end })
        assert.is_true(fell_back)
    end)

    it("notifies (default) when no on_no_ref is given and no ref under cursor", function()
        buf_with("just some plain text", 5)
        local notified
        local prev = vim.notify
        vim.notify = function(msg) notified = msg end
        ar.goto_ref_at_cursor() -- no opts → default notify path
        vim.notify = prev
        assert.is_truthy(notified and notified:match("no artifact ref"))
    end)

    -- #225 BR-3: this used to replace `ar.run_resolve` outright, which faked
    -- the module rather than the process and meant the real argv construction
    -- never ran here. `opts.runner` is run_resolve's own documented seam, now
    -- threaded through goto_ref_at_cursor so a caller can reach it.
    it("does NOT call on_no_ref when a ref is present (resolves instead)", function()
        buf_with("see ariadne#144 here", 10)
        local fell_back = false
        local argv_seen
        ar.goto_ref_at_cursor({
            on_no_ref = function() fell_back = true end,
            runner = function(argv, on_complete)
                argv_seen = table.concat(argv, " ")
                on_complete('{"files":[]}', 0, "")
            end,
        })
        assert.is_false(fell_back)
        assert.is_truthy(argv_seen and argv_seen:match("resolve"), "runner never reached: " .. tostring(argv_seen))
        assert.is_truthy(argv_seen:match("ariadne#144"), "argv lost the ref: " .. argv_seen)
    end)
end)

describe("goto_ref_at_cursor guarded completion", function()
    local saved, queued, opened, pickers, notices, complete

    before_each(function()
        ar._reset_inflight()
        -- Control the process and event-loop boundaries independently; the real
        -- entry point still builds argv and parses the resolver's JSON.
        saved = {
            schedule = vim.schedule,
            open_buf = parley.open_buf,
            picker_open = require("parley.float_picker").open,
            notify = vim.notify,
        }
        queued, opened, pickers, notices = {}, {}, {}, {}
        vim.schedule = function(fn) queued[#queued + 1] = fn end
        parley.open_buf = function(path) opened[#opened + 1] = path end
        require("parley.float_picker").open = function(opts) pickers[#pickers + 1] = opts end
        vim.notify = function(msg) notices[#notices + 1] = msg end
        local buf = vim.api.nvim_create_buf(false, true)
        vim.api.nvim_buf_set_lines(buf, 0, -1, false, { "see #327" })
        vim.api.nvim_set_current_buf(buf)
        vim.api.nvim_win_set_cursor(0, { 1, 5 })
    end)

    after_each(function()
        vim.schedule = saved.schedule
        parley.open_buf = saved.open_buf
        require("parley.float_picker").open = saved.picker_open
        vim.notify = saved.notify
    end)

    local function start(is_current)
        ar.goto_ref_at_cursor({
            is_current = is_current,
            runner = function(_, on_complete) complete = on_complete end,
        })
    end

    local function resolve(files)
        complete(vim.json.encode({ files = files }), 0, "")
    end

    it("drops a result invalidated before scheduled dispatch", function()
        local current = true
        start(function() return current end)
        resolve({ { path = "/a/i.md" }, { path = "/a/p.md" } })
        current = false
        queued[1]()
        assert.are.equal(0, #pickers)
        assert.are.equal(0, #opened)
        assert.are.equal(0, #notices)
    end)

    it("rechecks ownership immediately before opening a single result", function()
        local checks = 0
        start(function()
            checks = checks + 1
            return checks == 1
        end)
        resolve({ { path = "/a/i.md" } })
        queued[1]()
        assert.are.equal(0, #opened)
    end)

    it("schedules and opens only once for duplicate resolver completion", function()
        start(function() return true end)
        resolve({ { path = "/a/i.md" } })
        resolve({ { path = "/a/i.md" } })
        assert.are.equal(1, #queued)
        queued[1]()
        assert.are.same({ "/a/i.md" }, opened)
        resolve({ { path = "/a/i.md" } })
        assert.are.equal(1, #queued)
    end)

    it("rejects a stale family selection and consumes its callback", function()
        local current = true
        start(function() return current end)
        resolve({ { path = "/a/i.md" }, { path = "/a/p.md" } })
        queued[1]()
        assert.are.equal(1, #pickers)
        current = false
        pickers[1].on_select(pickers[1].items[1])
        current = true
        pickers[1].on_select(pickers[1].items[2])
        assert.are.equal(0, #opened)
    end)

    it("opens a current family selection only once", function()
        start(function() return true end)
        resolve({ { path = "/a/i.md" }, { path = "/a/p.md" } })
        queued[1]()
        pickers[1].on_select(pickers[1].items[2])
        pickers[1].on_select(pickers[1].items[1])
        assert.are.same({ "/a/p.md" }, opened)
    end)

    it("still resolves and opens without an ownership predicate", function()
        start(nil)
        resolve({ { path = "/a/i.md" } })
        queued[1]()
        assert.are.same({ "/a/i.md" }, opened)
    end)
end)

describe("goto_ref_at_cursor in-flight resolve (#226)", function()
    local saved, queued, opened, notices, spawns

    -- The runner seam records each spawn: its argv, its completion, and a fake
    -- vim.system handle whose kill() is observable.
    local function runner(argv, on_complete)
        local spawn = { argv = table.concat(argv, " "), complete = on_complete, killed = false }
        spawn.handle = { kill = function() spawn.killed = true end }
        spawns[#spawns + 1] = spawn
        return spawn.handle
    end

    local function on_line(line, col)
        local buf = vim.api.nvim_create_buf(false, true)
        vim.api.nvim_buf_set_lines(buf, 0, -1, false, { line })
        vim.api.nvim_set_current_buf(buf)
        vim.api.nvim_win_set_cursor(0, { 1, col })
        return buf
    end

    local function press(opts)
        opts = opts or {}
        opts.runner = runner
        ar.goto_ref_at_cursor(opts)
    end

    local function resolve(spawn, path)
        spawn.complete(vim.json.encode({ files = { { path = path } } }), 0, "")
    end

    local function drain()
        local q = queued
        queued = {}
        for _, fn in ipairs(q) do
            fn()
        end
    end

    before_each(function()
        ar._reset_inflight()
        saved = { schedule = vim.schedule, open_buf = parley.open_buf, notify = vim.notify }
        queued, opened, notices, spawns = {}, {}, {}, {}
        vim.schedule = function(fn) queued[#queued + 1] = fn end
        parley.open_buf = function(path) opened[#opened + 1] = path end
        vim.notify = function(msg) notices[#notices + 1] = msg end
    end)

    after_each(function()
        vim.schedule = saved.schedule
        parley.open_buf = saved.open_buf
        vim.notify = saved.notify
        ar._reset_inflight()
    end)

    it("spawns once and opens once for two presses on the same ref", function()
        on_line("see #327", 5)
        press()
        press()
        assert.are.equal(1, #spawns)
        assert.are.same({ "parley: still resolving #327" }, notices)
        resolve(spawns[1], "/a/327.md")
        drain()
        assert.are.same({ "/a/327.md" }, opened)
    end)

    it("lets a press on a different ref supersede the outstanding one", function()
        on_line("see #327 and #328", 5)
        press()
        vim.api.nvim_win_set_cursor(0, { 1, 14 })
        press()
        assert.are.equal(2, #spawns)
        assert.is_true(spawns[1].killed, "the superseded resolve was not killed")
        assert.is_false(spawns[2].killed)
        resolve(spawns[1], "/a/327.md") -- exited before the kill landed
        resolve(spawns[2], "/a/328.md")
        drain()
        assert.are.same({ "/a/328.md" }, opened)
    end)

    it("drops a result that lands after the user left the buffer", function()
        on_line("see #327", 5)
        press() -- no is_current from the caller: the default origin check
        on_line("somewhere else", 0)
        resolve(spawns[1], "/a/327.md")
        drain()
        assert.are.same({}, opened)
    end)

    it("drops a result that lands after the user left the window", function()
        on_line("see #327", 5)
        press()
        vim.cmd("split")
        resolve(spawns[1], "/a/327.md")
        drain()
        vim.cmd("close")
        assert.are.same({}, opened)
    end)

    it("forgets a finished resolve, so a later press on the same ref spawns again", function()
        on_line("see #327", 5)
        press()
        resolve(spawns[1], "/a/327.md")
        drain()
        press()
        assert.are.equal(2, #spawns)
        assert.are.same({}, notices)
    end)

    it("releases the key when the spawn raises", function()
        on_line("see #327", 5)
        assert.has_error(function()
            ar.goto_ref_at_cursor({ runner = function() error("ENOENT: sdlc") end })
        end)
        press()
        assert.are.equal(1, #spawns)
        assert.are.same({}, notices)
    end)

    it("lets the same ref pressed from another window supersede, and opens there", function()
        on_line("see #327", 5)
        press()
        vim.cmd("split")
        press()
        assert.are.equal(2, #spawns)
        assert.is_true(spawns[1].killed, "the first resolve was not superseded")
        assert.are.same({}, notices)
        resolve(spawns[1], "/a/327.md")
        resolve(spawns[2], "/a/327.md")
        drain()
        vim.cmd("close")
        assert.are.same({ "/a/327.md" }, opened)
    end)

    it("drops a family selection made after the user left the window", function()
        local picker_open = require("parley.float_picker").open
        local pickers = {}
        require("parley.float_picker").open = function(o) pickers[#pickers + 1] = o end
        on_line("see #327", 5)
        press() -- no is_current from the caller: the default origin check
        spawns[1].complete(vim.json.encode({ files = { { path = "/a/i.md" }, { path = "/a/p.md" } } }), 0, "")
        drain()
        vim.cmd("split")
        pickers[1].on_select(pickers[1].items[1])
        vim.cmd("close")
        require("parley.float_picker").open = picker_open
        assert.are.equal(1, #pickers)
        assert.are.same({}, opened)
    end)

    it("keys on the resolve kind, so a project jump is not the same question", function()
        on_line("see #327", 5)
        press()
        press({ kind = "project" })
        assert.are.equal(2, #spawns)
        assert.is_truthy(spawns[2].argv:find("--kind project", 1, true), spawns[2].argv)
    end)
end)

describe("family_picker_items", function()
    it("builds display/value with kind + milestone", function()
        local items = ar.family_picker_items({
            { path = "/a/000144-foo.md", kind = "issue" },
            { path = "/a/000144-foo-m2-review.md", kind = "review", milestone = "M2" },
        })
        assert.are.equal("/a/000144-foo.md", items[1].value)
        assert.is_truthy(items[1].display:match("issue"))
        assert.is_truthy(items[2].display:match("M2"))
        assert.is_truthy(items[2].display:match("000144%-foo%-m2%-review%.md"))
    end)
end)
