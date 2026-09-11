-- #227: highlighting must not blank or shimmer while typing. Every edit splices
-- the buffer's structure so it stays aligned; an edit it cannot apply exactly
-- leaves it approximate — still rendering — until one scheduled rebuild.
local tmp_dir = vim.fn.tempname() .. "-parley-typing"
vim.fn.mkdir(tmp_dir, "p")
local parley = require("parley")
parley.setup({ chat_dir = tmp_dir, state_dir = tmp_dir .. "/state", providers = {}, api_keys = {} })

local decoration = require("tests.helpers.decoration")
local highlighter = require("parley.highlighter")
local model = require("parley.highlight_structure")

-- The operator's shape: a chat whose last question is being typed, above a
-- managed footnote footer (the row-indexed value a stale structure gets wrong).
local CHAT = {
    "---", "topic: t", "file: f.md", "---", "",
    "💬: Astrophotography.",           -- 5
    "what should I buy first?",       -- 6
    "",                               -- 7
    "🤖: [Claude]",                    -- 8
    "🧠: legacy thought",              -- 9
    "",                               -- 10
    "Start with a tracking mount.",   -- 11
    "",                               -- 12
    "💬: follow up",                   -- 13
    "",                               -- 14  <- typing happens here
    "",                               -- 15
    "[^mount]: a motorized base",     -- 16
}

local DRAFT = { "# notes", "", "=== draft ===", "first", "", "=== end ===", "after" }

local function open(lines, kind)
    local buf = vim.api.nvim_create_buf(false, true)
    vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
    parley._parley_bufs[buf] = kind or "chat"
    local win = vim.api.nvim_get_current_win()
    vim.api.nvim_win_set_buf(win, buf)
    assert.is_truthy(highlighter.rebuild_structure(buf))
    return buf, win
end

local function oracle(buf)
    return model.build(vim.api.nvim_buf_get_lines(buf, 0, -1, false), model.patterns(parley.config))
end

-- The whole-buffer row map a structure produces; comparing live against
-- oracle(buf) compares exactly what differs between an incremental and a
-- clean render.
local function decorations(buf, win, structure)
    local last = vim.api.nvim_buf_line_count(buf) - 1
    return highlighter._compute_window_decorations(win, buf, 0, last, nil, structure)
end

local function count_builds(buf)
    local n = 0
    require("parley.line_reader").set_observer(buf, function(event)
        if event.operation == "structure_build" then n = n + 1 end
    end)
    return function() return n end
end

-- One real buffer edit per keystroke, so Neovim's on_lines reports each exactly
-- as it would an insert-mode key. ASCII only; "\n" is Enter.
local function type_text(buf, row, col, text, each)
    for i = 1, #text do
        local ch = text:sub(i, i)
        if ch == "\n" then
            vim.api.nvim_buf_set_text(buf, row, col, row, col, { "", "" })
            row, col = row + 1, 0
        else
            vim.api.nvim_buf_set_text(buf, row, col, row, col, { ch })
            col = col + 1
        end
        if each then each() end
    end
    return row, col
end

local function delete_scratch_bufs()
    for _, buf in ipairs(vim.api.nvim_list_bufs()) do
        if vim.api.nvim_buf_is_valid(buf) and vim.api.nvim_buf_get_name(buf) == "" then
            pcall(vim.api.nvim_buf_delete, buf, { force = true })
        end
    end
end

-- Every stub and seam swap registers its undo here and after_each unwinds
-- them, so a failing assertion cannot leak a stub into later tests. (One did:
-- a failed test left nvim__redraw stubbed, and the real-clock test then failed
-- for a reason that had nothing to do with it.)
local cleanups = {}
local function on_cleanup(fn) cleanups[#cleanups + 1] = fn end
local function run_cleanups()
    for i = #cleanups, 1, -1 do cleanups[i]() end
    cleanups = {}
end
--- Replace tbl[key] until the test ends; the returned function undoes it early.
local function patch(tbl, key, value)
    local previous = tbl[key]
    tbl[key] = value
    local function unpatch() tbl[key] = previous end
    on_cleanup(unpatch)
    return unpatch
end

describe("highlighting while typing (#227)", function()
    local deferrals

    before_each(function()
        deferrals = decoration.manual_deferrals()
        on_cleanup(highlighter._set_repair_deferral(deferrals.factory))
    end)

    after_each(function()
        run_cleanups()
        delete_scratch_bufs()
    end)

    it("renders every frame exactly like a clean rebuild while typing a list with Enter", function()
        local buf, win = open(CHAT)
        local provider = decoration.capture_provider(parley)
        local text = "1. a mount\n2. a camera\n3. patience"
        local frames = 0
        type_text(buf, 14, 0, text, function()
            frames = frames + 1
            local cache = highlighter._structure_cache(buf)
            assert.is_false(cache.dirty, "ordinary typing must splice exactly")
            -- The whole structure, not just what row 0's viewport consumes:
            -- a scrolled window reads state_before at its own top row.
            assert.are.same(oracle(buf), cache.structure)
            local drawn = decoration.frame(provider, win, buf, 0, vim.api.nvim_buf_line_count(buf) - 1)
            assert.is_truthy(drawn, "a frame drew nothing")
            assert.is_true(decoration.has(drawn, 13, "ParleyQuestion"))
            assert.are.same(decorations(buf, win, oracle(buf)), decorations(buf, win, cache.structure))
        end)
        assert.equals(#text, frames)
        assert.equals(0, deferrals.starts)
    end)

    it("keeps a markdown draft background on every draft row while typing inside it", function()
        local buf, win = open(DRAFT, "markdown")
        type_text(buf, 3, 5, " line\nsecond\n", function()
            local cache = highlighter._structure_cache(buf)
            assert.is_false(cache.dirty)
            assert.are.same(decorations(buf, win, oracle(buf)), decorations(buf, win, cache.structure))
        end)
    end)

    it("still draws rows outside a line-count edit", function()
        local buf, win = open(CHAT)
        local provider = decoration.capture_provider(parley)
        vim.api.nvim_buf_set_lines(buf, 14, 14, false, { "", "" })
        local drawn = decoration.frame(provider, win, buf, 0, vim.api.nvim_buf_line_count(buf) - 1)
        assert.is_truthy(drawn)
        assert.is_true(decoration.has(drawn, 5, "ParleyQuestion"), "question above the edit")
        assert.is_true(decoration.has(drawn, 18, "ParleyFootnote"), "footer below it, shifted")
        assert.is_false(decoration.has(drawn, 16, "ParleyFootnote"), "old footer row is typing now")
    end)

    it("renders an approximate structure and repairs it without any convergence event", function()
        local buf, win = open(CHAT)
        local provider = decoration.capture_provider(parley)
        local builds = count_builds(buf)
        local calls = { hqb = 0, redraw = {} }
        local original_hqb = highlighter.highlight_question_block
        patch(highlighter, "highlight_question_block", function(...)
            calls.hqb = calls.hqb + 1
            return original_hqb(...)
        end)
        patch(vim.api, "nvim__redraw", function(opts) calls.redraw[#calls.redraw + 1] = opts end)

        vim.api.nvim_buf_set_lines(buf, 14, 15, false, { "```lua" })
        local cache = highlighter._structure_cache(buf)
        assert.is_true(cache.dirty)
        assert.is_truthy(decoration.frame(provider, win, buf, 0, 16), "fail open while dirty")
        assert.equals(1, deferrals.pending())
        assert.equals(0, builds())

        assert.equals(1, deferrals.fire())
        assert.is_false(cache.dirty)
        assert.are.same(oracle(buf), cache.structure)
        assert.equals(1, builds())
        assert.equals(0, calls.hqb)
        assert.are.same({ { buf = buf, valid = false } }, calls.redraw)
    end)

    it("costs one rebuild per burst on a long chat: each dirtying edit restarts the one pending repair", function()
        local lines, target = require("tests.perf.chat_typing").build_fixture(5000)
        local buf = open(lines)
        local builds = count_builds(buf)
        vim.api.nvim_buf_set_lines(buf, target, target, false, { "```" })
        local text = "local x = 1\nprint(x)\n"
        type_text(buf, target + 1, 0, text)
        assert.equals(1 + #text, deferrals.starts, "every edit on a dirty cache restarts the repair")
        assert.equals(1, deferrals.pending(), "restart, never queue")
        assert.equals(0, builds(), "nothing rebuilt mid-burst")
        deferrals.fire()
        assert.equals(1, builds())
        assert.is_false(highlighter._structure_cache(buf).dirty)
    end)

    it("never schedules a rebuild for a plain-text burst with Enter on a long chat", function()
        local lines, target = require("tests.perf.chat_typing").build_fixture(5000)
        local buf = open(lines)
        local builds = count_builds(buf)
        type_text(buf, target - 1, #lines[target], "\nhello\nworld")
        assert.equals(0, deferrals.starts)
        assert.equals(0, builds())
        assert.are.same(oracle(buf), highlighter._structure_cache(buf).structure)
    end)

    it("reports each splice's real work to the observer the #170 gates read", function()
        -- BR-4: the O(n) copy of a line-count edit must reach record_work, or
        -- a rebuild or deep copy could land on the keystroke path unseen.
        local lines, target = require("tests.perf.chat_typing").build_fixture(5000)
        local buf = open(lines)
        local events = {}
        require("parley.line_reader").set_observer(buf, function(event)
            if event.operation == "structure_replace" then events[#events + 1] = event end
        end)
        type_text(buf, target - 1, #lines[target], "\n") -- Enter: one row becomes two
        type_text(buf, target, 0, "xy")                   -- blank → text, then text → text
        assert.equals(3, #events)
        assert.equals(4, events[1].structure_rows_processed) -- 2 classified + 2 walked
        assert.equals(2 * 5001, events[1].structure_entries_copied)
        assert.equals(2, events[2].structure_rows_processed) -- the token changed: a splice
        assert.equals(2 * 5001, events[2].structure_entries_copied)
        assert.equals(1, events[3].structure_rows_processed) -- same token: shared, no copy
        assert.equals(0, events[3].structure_entries_copied)
    end)

    it("keeps a repair when the experimental redraw API refuses", function()
        local buf = open(CHAT)
        patch(vim.api, "nvim__redraw", function() error("E5555: nvim__redraw is gone") end)
        vim.api.nvim_buf_set_lines(buf, 14, 15, false, { "```lua" })
        assert.has_no.errors(function() deferrals.fire() end)
        assert.is_false(highlighter._structure_cache(buf).dirty)
        assert.are.same(oracle(buf), highlighter._structure_cache(buf).structure)
    end)

    it("closes a pending repair on teardown so a late fire touches nothing", function()
        local buf = open(CHAT)
        vim.api.nvim_buf_set_lines(buf, 14, 15, false, { "💬: new" })
        local deferral = deferrals.all[1]
        local late = deferral.pending
        highlighter.clear_structure(buf)
        assert.is_true(deferral.closed)
        local builds = count_builds(buf)
        late()
        assert.equals(0, builds())
        assert.is_nil(highlighter._structure_cache(buf))
    end)

    it("closes a pending repair when Nvim detaches the buffer", function()
        -- Called directly: deleting the buffer would also run the BufUnload
        -- autocmd's clear_structure, hiding whether on_detach tears down alone.
        local buf = open(CHAT)
        vim.api.nvim_buf_set_lines(buf, 14, 15, false, { "💬: new" })
        local deferral = deferrals.all[1]
        highlighter._structure_cache(buf).on_detach(nil, buf)
        assert.is_true(deferral.closed)
        assert.is_nil(highlighter._structure_cache(buf))
    end)

    it("resyncs when a splice throws instead of erroring on every keystroke", function()
        local buf = open(CHAT)
        local unpatch = patch(model, "replace", function() error("forced splice failure") end)
        local ok = pcall(vim.api.nvim_buf_set_lines, buf, 14, 14, false, { "x" })
        unpatch()
        assert.is_true(ok)
        local cache = highlighter._structure_cache(buf)
        assert.is_false(cache.dirty)
        assert.are.same(oracle(buf), cache.structure)
    end)

    it("drops a cache it cannot realign, then recovers on the next rebuild", function()
        local buf, win = open(CHAT)
        local provider = decoration.capture_provider(parley)
        local unpatch_replace = patch(model, "replace", function() error("splice") end)
        local unpatch_build = patch(model, "build", function() error("build") end)
        pcall(vim.api.nvim_buf_set_lines, buf, 14, 14, false, { "x" })
        unpatch_replace()
        unpatch_build()
        assert.is_nil(highlighter._structure_cache(buf))
        assert.is_false(provider.on_win(nil, win, buf, 0, 5))
        assert.is_truthy(highlighter.rebuild_structure(buf))
        vim.api.nvim_buf_set_lines(buf, 14, 14, false, { "y" })
        assert.are.same(oracle(buf), highlighter._structure_cache(buf).structure)
    end)

    it("stays aligned through Nvim's empty-buffer line", function()
        local buf = open(CHAT)
        vim.api.nvim_buf_set_lines(buf, 0, -1, false, {})
        assert.equals(1, #highlighter._structure_cache(buf).structure.fingerprints)
        vim.api.nvim_buf_set_lines(buf, 0, -1, false, { "💬: a", "b", "c" })
        assert.are.same(oracle(buf), highlighter._structure_cache(buf).structure)
    end)

    it("keeps the structure aligned with the buffer across random real edits", function()
        -- The unit property test models on_lines ranges; this one takes them
        -- from Neovim itself, including multi-line set_text joins and splits.
        local VOCAB = { "prose", "", "```", "💬: q", "🤖: a", "🧠: r", "🧠:[END]", "[^n]: f", "=== d ===" }
        math.randomseed(2270)
        local buf = open(CHAT)
        for step = 1, 400 do
            local n = vim.api.nvim_buf_line_count(buf)
            local pick = math.random(4)
            local repl = {}
            for i = 1, math.random(1, 3) do repl[i] = VOCAB[math.random(#VOCAB)] end
            if pick == 1 then
                local sr = math.random(0, n - 1)
                local er = math.random(sr, math.min(n - 1, sr + 2))
                local sl = vim.api.nvim_buf_get_lines(buf, sr, sr + 1, false)[1]
                local el = vim.api.nvim_buf_get_lines(buf, er, er + 1, false)[1]
                local sc = math.random(0, 1) == 0 and 0 or #sl
                local ec = (er == sr) and #sl or (math.random(0, 1) == 0 and 0 or #el)
                vim.api.nvim_buf_set_text(buf, sr, sc, er, ec, repl)
            elseif pick == 2 then
                local at = math.random(0, n)
                vim.api.nvim_buf_set_lines(buf, at, at, false, repl)
            elseif pick == 3 then
                local s = math.random(0, n - 1)
                vim.api.nvim_buf_set_lines(buf, s, math.min(n, s + math.random(1, 2)), false, {})
            else
                local s = math.random(0, n - 1)
                vim.api.nvim_buf_set_lines(buf, s, s + 1, false, repl)
            end
            local cache = highlighter._structure_cache(buf)
            local want = oracle(buf)
            local context = "step " .. step
            assert.equals(vim.api.nvim_buf_line_count(buf), #cache.structure.fingerprints, context)
            assert.are.same(want.fingerprints, cache.structure.fingerprints, context)
            assert.equals(want.footer_start0, cache.structure.footer_start0, context)
            assert.are.same(want.draft_ranges, cache.structure.draft_ranges, context)
            if cache.dirty then
                deferrals.fire() -- the repair; exact state is then required below
                assert.is_false(cache.dirty, context)
            end
            assert.are.same(want.state_before, cache.structure.state_before, context)
        end
    end)

    it("resyncs on a :checktime reload instead of detaching", function()
        local path = tmp_dir .. "/reload.md"
        vim.fn.writefile(CHAT, path)
        -- noautocmd: no BufEnter, so buffer_lifecycle never adopts this buffer
        -- and nothing but the structure cache's own on_reload can repair it.
        vim.cmd("noautocmd edit " .. vim.fn.fnameescape(path))
        local buf = vim.api.nvim_get_current_buf()
        on_cleanup(function()
            pcall(vim.api.nvim_buf_delete, buf, { force = true })
            vim.fn.delete(path)
        end)
        parley._parley_bufs[buf] = "chat"
        assert.is_truthy(highlighter.rebuild_structure(buf))
        patch(vim.o, "autoread", true)
        vim.fn.writefile({ "💬: replaced", "body", "[^a]: note" }, path)
        local now = os.time() + 5
        vim.uv.fs_utime(path, now, now)
        vim.cmd("checktime " .. buf)
        local cache = highlighter._structure_cache(buf)
        assert.is_truthy(cache, "reload detached the structure cache")
        assert.is_false(cache.dirty)
        assert.are.same(oracle(buf), cache.structure)
    end)
end)

describe("the test harness's repair default (#227)", function()
    after_each(function()
        run_cleanups()
        delete_scratch_bufs()
    end)

    it("arms no real repair unless a spec opts into the clock", function()
        -- The rule for every spec, not an install in each one: any spec that
        -- edits a parley buffer and pumps the loop would otherwise take a
        -- 250 ms rebuild it never ordered.
        assert.equals("1", vim.env.PARLEY_TEST_MODE, "tests/minimal_init.vim must export the harness signal")
        local buf = open(CHAT)
        vim.api.nvim_buf_set_lines(buf, 14, 15, false, { "```lua" })
        assert.is_true(highlighter._structure_cache(buf).dirty)
        vim.wait(600, function() return false end)
        assert.is_true(highlighter._structure_cache(buf).dirty, "a real repair fired under the test harness")
    end)
end)

describe("highlighting repair on the real clock (#227)", function()
    after_each(function()
        run_cleanups()
        delete_scratch_bufs()
    end)

    it("fires the production timer, rebuilds, and invalidates the window for repaint", function()
        on_cleanup(highlighter._set_repair_deferral(nil, 20))
        local buf = open(CHAT)
        local builds = count_builds(buf)
        -- A second provider counts lines actually redrawn in this window.
        local counted = 0
        local ns = vim.api.nvim_create_namespace("parley-227-redraw-probe")
        vim.api.nvim_set_decoration_provider(ns, {
            on_win = function(_, _, wbuf) return wbuf == buf end,
            on_line = function() counted = counted + 1 end,
        })
        on_cleanup(function() vim.api.nvim_set_decoration_provider(ns, {}) end)
        vim.cmd("redraw")
        vim.api.nvim_buf_set_lines(buf, 14, 15, false, { "```lua" })
        vim.cmd("redraw")
        assert.is_true(highlighter._structure_cache(buf).dirty)
        -- Reset BEFORE waiting: whether the main loop flushes the invalidation
        -- inside vim.wait or only at the explicit redraw below, it is counted.
        -- Without the repair's invalidation nothing redraws at all — the text
        -- has not changed since the last redraw.
        counted = 0
        assert.is_true(vim.wait(2000, function() return not highlighter._structure_cache(buf).dirty end, 5),
            "repair never fired")
        vim.cmd("redraw")
        assert.equals(1, builds())
        assert.are.same(oracle(buf), highlighter._structure_cache(buf).structure)
        assert.is_true(counted >= 10, "repair did not invalidate the window: " .. counted .. " lines redrawn")
    end)
end)
