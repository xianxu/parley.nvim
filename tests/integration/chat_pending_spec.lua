local chat_pending = require("parley.chat_pending")
local logger = require("parley.logger")

local uv = vim.uv or vim.loop

local function fake_runtime()
    local now = 0
    local queue = {}
    local timers = {}
    local next_timer = 0

    local scheduler = {}
    scheduler.enqueue = function(callback)
        table.insert(queue, callback)
    end
    local function register(delay, repeating, callback)
        next_timer = next_timer + 1
        local timer = {
            due = now + delay,
            interval = repeating and delay or nil,
            callback = callback,
            closed = false,
        }
        timers[next_timer] = timer
        return function()
            if timer.closed then
                return
            end
            timer.closed = true
        end
    end
    scheduler.after = function(delay, callback)
        return register(delay, false, callback)
    end
    scheduler.every = function(delay, callback)
        return register(delay, true, callback)
    end

    local runtime = {
        clock = { now_ms = function() return now end },
        scheduler = scheduler,
    }
    function runtime:drain()
        while #queue > 0 do
            local callback = table.remove(queue, 1)
            callback()
        end
    end
    function runtime:advance(milliseconds)
        now = now + milliseconds
        local again = true
        while again do
            again = false
            for _, timer in pairs(timers) do
                if not timer.closed and timer.due <= now then
                    if timer.interval then
                        timer.due = timer.due + timer.interval
                    else
                        timer.closed = true
                    end
                    timer.callback()
                    again = true
                end
            end
        end
    end
    function runtime:fire_earliest_timer_early()
        local earliest
        for _, timer in pairs(timers) do
            if not timer.closed and (not earliest or timer.due < earliest.due) then
                earliest = timer
            end
        end
        assert(earliest, "expected an open timer")
        if earliest.interval then
            earliest.due = earliest.due + earliest.interval
        else
            earliest.closed = true
        end
        earliest.callback()
    end
    function runtime:open_timer_count()
        local count = 0
        for _, timer in pairs(timers) do
            if not timer.closed then
                count = count + 1
            end
        end
        return count
    end
    return runtime
end

local function scratch()
    local buf = vim.api.nvim_create_buf(false, true)
    vim.api.nvim_set_current_buf(buf)
    vim.api.nvim_buf_set_lines(buf, 0, -1, false, { "assistant:" })
    return buf
end

local function extmark(buf)
    local namespace = vim.api.nvim_get_namespaces().parley_chat_pending
    assert.is_truthy(namespace)
    local marks = vim.api.nvim_buf_get_extmarks(buf, namespace, 0, -1, { details = true })
    if #marks == 0 then
        return nil
    end
    assert.equals(1, #marks)
    return marks[1]
end

local function virtual_text(buf)
    local mark = extmark(buf)
    if not mark then
        return nil
    end
    return mark[4].virt_lines[1][1][1], mark
end

local function start_fake(buf, runtime, opts)
    opts = opts or {}
    local emitted = opts.emitted or {}
    local session = chat_pending.start({
        buf = buf,
        agent = opts.agent or "Test Agent",
        anchor_line = 0,
        lease_valid = opts.lease_valid or function() return true end,
        emit_content = function(qid, chunk)
            table.insert(emitted, { qid, chunk })
        end,
        choose_verb_index = opts.choose_verb_index or function() return 1 end,
        on_discard = opts.on_discard,
        clock = runtime.clock,
        scheduler = runtime.scheduler,
    })
    runtime:drain()
    return session, emitted
end

describe("chat pending extmark adapter", function()
    local buffers = {}
    local runtimes = {}

    local function new_runtime()
        local runtime = fake_runtime()
        table.insert(runtimes, runtime)
        return runtime
    end

    after_each(function()
        chat_pending.cancel_all("test teardown")
        for _, runtime in ipairs(runtimes) do
            runtime:drain()
        end
        vim.wait(20, function() return false end, 1)
        for _, buf in ipairs(buffers) do
            if vim.api.nvim_buf_is_valid(buf) then
                vim.api.nvim_buf_delete(buf, { force = true })
            end
        end
        buffers = {}
        runtimes = {}
    end)

    local function new_scratch()
        local buf = scratch()
        table.insert(buffers, buf)
        return buf
    end

    it("returns copied identity only for an active pending session", function()
        local buf = new_scratch()
        local runtime = new_runtime()
        start_fake(buf, runtime, { agent = "Claude" })

        local identity = chat_pending.identity(buf)
        assert.same({ agent = "Claude" }, identity)
        identity.agent = "mutated"
        assert.same({ agent = "Claude" }, chat_pending.identity(buf))
        assert.is_nil(chat_pending.identity(99999))
    end)

    it("synchronously retires only one stale session and is idempotent", function()
        local first_buf = new_scratch()
        local second_buf = new_scratch()
        local first_runtime = new_runtime()
        local second_runtime = new_runtime()
        local discarded = {}
        start_fake(first_buf, first_runtime, {
            agent = "Claude",
            on_discard = function(event, reason) table.insert(discarded, { event, reason }) end,
        })
        start_fake(second_buf, second_runtime, { agent = "OpenAI" })
        first_runtime:advance(1000)
        first_runtime:drain()
        assert.is_not_nil(extmark(first_buf))

        assert.is_true(chat_pending.retire_stale_now(first_buf, "history"))

        assert.is_nil(chat_pending.identity(first_buf))
        assert.same({ agent = "OpenAI" }, chat_pending.identity(second_buf))
        assert.is_nil(extmark(first_buf))
        assert.equals(0, first_runtime:open_timer_count())
        assert.same({ { "stale", "history" } }, discarded)
        assert.is_false(chat_pending.retire_stale_now(first_buf, "history"))
        assert.same({ { "stale", "history" } }, discarded)
    end)

    it("contains a throwing discard callback while completing retirement", function()
        local buf = new_scratch()
        local runtime = new_runtime()
        local logs = {}
        local original_error = logger.error
        logger.error = function(message) table.insert(logs, tostring(message)) end
        start_fake(buf, runtime, {
            on_discard = function() error("PRIVATE_DISCARD_SECRET" .. string.rep("x", 1000)) end,
        })

        assert.has_no.errors(function()
            assert.is_true(chat_pending.retire_stale_now(buf, "history"))
        end)
        logger.error = original_error

        assert.is_nil(chat_pending.identity(buf))
        assert.is_nil(extmark(buf))
        assert.equals(0, runtime:open_timer_count())
        assert.equals(1, #logs)
        assert.is_truthy(logs[1]:find("discard terminal callback failed", 1, true))
        assert.is_nil(logs[1]:find("PRIVATE_DISCARD_SECRET", 1, true))
        assert.is_true(#logs[1] <= 160)
    end)

    it("reveals a virtual playful line only after one second", function()
        local buf = new_scratch()
        local runtime = new_runtime()
        start_fake(buf, runtime)

        assert.is_nil(extmark(buf))
        runtime:advance(999)
        runtime:drain()
        assert.is_nil(extmark(buf))
        runtime:advance(1)
        assert.is_nil(extmark(buf), "timer callbacks must not touch UI before enqueue drains")
        runtime:drain()

        local text, mark = virtual_text(buf)
        assert.equals("⠙ Baking", text)
        assert.equals(0, mark[2])
        assert.is_false(mark[4].virt_lines_above)
        assert.is_true(mark[4].invalidate)
        assert.same({ "assistant:" }, vim.api.nvim_buf_get_lines(buf, 0, -1, false))
    end)

    it("renders the complete capitalized everyday cooking verb pool", function()
        local expected = {
            "Baking", "Brewing", "Caramelizing", "Chopping", "Concocting", "Cooking",
            "Crafting", "Cultivating", "Fermenting", "Garnishing", "Kneading",
            "Marinating", "Mulling", "Noodling", "Percolating", "Puttering", "Seasoning",
            "Simmering", "Sketching", "Sprouting", "Steeping", "Stewing", "Tinkering",
            "Toasting", "Unfurling", "Whisking", "Working", "Zesting",
        }

        for index, verb in ipairs(expected) do
            local buf = new_scratch()
            local runtime = new_runtime()
            local observed_count
            start_fake(buf, runtime, {
                choose_verb_index = function(count)
                    observed_count = count
                    return index
                end,
            })

            runtime:advance(1000)
            runtime:drain()

            assert.equals(#expected, observed_count)
            assert.equals("⠙ " .. verb, virtual_text(buf))
        end
    end)

    it("rearms a one-shot timer delivered before its reducer deadline", function()
        local buf = new_scratch()
        local runtime = new_runtime()
        start_fake(buf, runtime)

        runtime:fire_earliest_timer_early()
        runtime:drain()
        assert.is_nil(extmark(buf))
        assert.is_truthy(runtime:open_timer_count() > 0)
        runtime:advance(999)
        runtime:drain()
        assert.is_nil(extmark(buf))
        runtime:advance(1)
        runtime:drain()
        assert.equals("⠙ Baking", virtual_text(buf))
    end)

    it("animates only the glyph and rotates verbs on activity and idle", function()
        local buf = new_scratch()
        local runtime = new_runtime()
        local choices = { 2, 3, 28 }
        local choice = 0
        local session = start_fake(buf, runtime, {
            choose_verb_index = function()
                choice = choice + 1
                return choices[choice] or 1
            end,
        })
        runtime:advance(1000)
        runtime:drain()
        local first = virtual_text(buf)
        assert.equals("⠙ Brewing", first)

        runtime:advance(120)
        runtime:drain()
        local framed = virtual_text(buf)
        assert.matches("^⠹ Brewing$", framed)

        session:activity("q")
        assert.equals(framed, virtual_text(buf))
        runtime:drain()
        local active = virtual_text(buf)
        assert.matches("^⠹ Caramelizing$", active)

        runtime:advance(14999)
        runtime:drain()
        assert.matches(" Caramelizing$", virtual_text(buf))
        runtime:advance(1)
        runtime:drain()
        assert.matches(" Zesting$", virtual_text(buf))
    end)

    it("repaints at the extmark's tracked row after text moves the anchor", function()
        local buf = new_scratch()
        local runtime = new_runtime()
        start_fake(buf, runtime)
        runtime:advance(1000)
        runtime:drain()
        assert.equals(0, extmark(buf)[2])

        vim.api.nvim_buf_set_lines(buf, 0, 0, false, { "inserted above" })
        assert.equals(1, extmark(buf)[2], "Neovim must move the pending mark with its anchor")
        runtime:advance(120)
        runtime:drain()

        assert.equals(1, extmark(buf)[2], "animation repaint reset the tracked row")
        assert.matches("^⠹ Baking$", virtual_text(buf))
    end)

    it("uses a hidden tip update for the first reveal", function()
        local buf = new_scratch()
        local runtime = new_runtime()
        local session = start_fake(buf, runtime)
        vim.api.nvim_buf_set_lines(buf, 1, 1, false, { "generated tip" })

        session:tip_written(1)
        runtime:advance(1000)
        runtime:drain()

        assert.equals(1, extmark(buf)[2])
        assert.equals("⠙ Baking", virtual_text(buf))
    end)

    it("repairs invalidating writes synchronously without changing lifecycle state", function()
        local buf = new_scratch()
        local runtime = new_runtime()
        local session, emitted = start_fake(buf, runtime)
        runtime:advance(1000)
        runtime:drain()
        session:content("q", "one")
        session:content("q", "two")
        runtime:drain()

        local text, mark = virtual_text(buf)
        local mark_id = mark[1]
        local state = session.state
        local minimum_timer = session.timers.minimum
        local frame_timer = session.timers.frame
        runtime:advance(120)
        assert.is_true(session:before_write())
        vim.api.nvim_buf_set_lines(buf, 0, 1, false, { "answer", "pending" })
        session:tip_written(1)

        local repaired_text, repaired_mark = virtual_text(buf)
        assert.equals(mark_id, repaired_mark[1])
        assert.equals(text, repaired_text)
        assert.equals(1, repaired_mark[2])
        assert.equals(state, session.state)
        assert.equals(minimum_timer, session.timers.minimum)
        assert.equals(frame_timer, session.timers.frame)

        runtime:drain()
        assert.is_true(chat_pending.is_active(buf), "queued frame must see the repaired mark")
        assert.equals(mark_id, extmark(buf)[1])
        assert.equals(1, extmark(buf)[2])

        local completions = 0
        session:complete("q", function() completions = completions + 1 end)
        runtime:drain()
        runtime:advance(880)
        runtime:drain()
        assert.same({ { "q", "one" }, { "q", "two" } }, emitted)
        assert.equals(1, completions)
        assert.is_false(chat_pending.is_active(buf))

        session:tip_written(0)
        assert.is_nil(extmark(buf))
        assert.equals(1, completions)
    end)

    it("rejects a write when progress was invalidated before the writer callback", function()
        local buf = new_scratch()
        local runtime = new_runtime()
        local session = start_fake(buf, runtime)
        runtime:advance(1000)
        runtime:drain()

        vim.api.nvim_buf_set_lines(buf, 0, 1, false, { "externally replaced" })
        assert.is_false(session:before_write())
        assert.is_false(chat_pending.is_active(buf))

        session:tip_written(0)
        assert.is_nil(extmark(buf))
    end)

    it("stages content until the minimum and flushes it in FIFO order", function()
        local buf = new_scratch()
        local runtime = new_runtime()
        local session, emitted = start_fake(buf, runtime)
        runtime:advance(1000)
        runtime:drain()

        session:content("q", "one")
        session:content("q", "two")
        runtime:drain()
        assert.same({}, emitted)
        assert.is_truthy(extmark(buf))

        runtime:advance(1000)
        runtime:drain()
        assert.same({ { "q", "one" }, { "q", "two" } }, emitted)
        assert.is_nil(extmark(buf))
    end)

    it("cancels every playful timer when fast content releases waiting", function()
        local buf = new_scratch()
        local runtime = new_runtime()
        local session, emitted = start_fake(buf, runtime)

        runtime:advance(500)
        session:content("q", "fast")
        runtime:drain()
        assert.same({ { "q", "fast" } }, emitted)
        assert.is_nil(extmark(buf))
        assert.equals(0, runtime:open_timer_count())

        runtime:advance(15000)
        runtime:drain()
        assert.is_nil(extmark(buf))
        assert.equals(0, runtime:open_timer_count())
    end)

    it("keeps fast semantic status but cancels every playful timer", function()
        local buf = new_scratch()
        local runtime = new_runtime()
        local session = start_fake(buf, runtime)

        runtime:advance(500)
        session:progress("q", { message = "Reasoning" })
        runtime:drain()
        assert.equals("Reasoning", virtual_text(buf))
        assert.equals(0, runtime:open_timer_count())

        runtime:advance(15000)
        runtime:drain()
        assert.equals("Reasoning", virtual_text(buf))
        assert.equals(0, runtime:open_timer_count())
    end)

    it("renders semantic status in the same extmark while content streams", function()
        local buf = new_scratch()
        local runtime = new_runtime()
        local session, emitted = start_fake(buf, runtime)
        runtime:advance(1000)
        runtime:drain()
        local playful_mark = extmark(buf)[1]

        session:progress("q", { message = "Searching files" })
        runtime:drain()
        runtime:advance(1000)
        runtime:drain()
        local status, mark = virtual_text(buf)
        assert.equals("Searching files", status)
        assert.equals(playful_mark, mark[1])

        session:content("q", "answer")
        runtime:drain()
        assert.same({ { "q", "answer" } }, emitted)
        assert.equals("Searching files", virtual_text(buf))
        session:activity("q")
        runtime:drain()
        assert.equals(0, runtime:open_timer_count(), "released sessions do not restart playful timers")
        local mark_at_completion = true
        session:complete("q", function() mark_at_completion = extmark(buf) end)
        runtime:drain()
        assert.is_nil(mark_at_completion, "status is hidden before the completion continuation")
    end)

    it("hides without changing real lines or the undo sequence", function()
        local buf = new_scratch()
        local runtime = new_runtime()
        local session = start_fake(buf, runtime)
        local before_lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
        local before_undo = vim.fn.undotree().seq_cur
        runtime:advance(1000)
        runtime:drain()
        session:cancel("user")
        runtime:drain()

        assert.is_nil(extmark(buf))
        assert.same(before_lines, vim.api.nvim_buf_get_lines(buf, 0, -1, false))
        assert.equals(before_undo, vim.fn.undotree().seq_cur)
        assert.equals(0, runtime:open_timer_count())
    end)

    it("completes after the minimum and invokes the continuation once", function()
        local buf = new_scratch()
        local runtime = new_runtime()
        local session = start_fake(buf, runtime)
        runtime:advance(1000)
        runtime:drain()
        local completions = 0
        local continuation = function() completions = completions + 1 end

        session:complete("q", continuation)
        session:complete("q", continuation)
        runtime:drain()
        assert.equals(0, completions)
        runtime:advance(1000)
        runtime:drain()
        assert.equals(1, completions)
        assert.equals(0, runtime:open_timer_count())
    end)

    it("contains emitter failures without logging callback data", function()
        local buf = new_scratch()
        local runtime = new_runtime()
        local emitted = {}
        local session = chat_pending.start({
            buf = buf,
            agent = "Test Agent",
            anchor_line = 0,
            lease_valid = function() return true end,
            emit_content = function(_qid, chunk)
                if chunk == "private chunk" then
                    error("private thrown secret")
                end
                table.insert(emitted, chunk)
            end,
            choose_verb_index = function() return 1 end,
            clock = runtime.clock,
            scheduler = runtime.scheduler,
        })
        runtime:drain()
        runtime:advance(1000)
        runtime:drain()
        session:content("q", "private chunk")
        session:content("q", "public tail")
        local completed = 0
        session:complete("q", function() completed = completed + 1 end)
        runtime:drain()

        local logs = {}
        local original_error = logger.error
        logger.error = function(message) table.insert(logs, message) end
        runtime:advance(1000)
        runtime:drain()
        logger.error = original_error

        assert.same({ "public tail" }, emitted)
        assert.equals(1, completed)
        assert.is_nil(extmark(buf))
        assert.equals(0, runtime:open_timer_count())
        local combined = table.concat(logs, "\n")
        assert.is_truthy(combined:find("chat pending content emitter callback failed", 1, true))
        assert.is_nil(combined:find("private chunk", 1, true))
        assert.is_nil(combined:find("private thrown secret", 1, true))
    end)

    it("surfaces owned failures after staged partial output", function()
        local buf = new_scratch()
        local runtime = new_runtime()
        local session, emitted = start_fake(buf, runtime)
        runtime:advance(1000)
        runtime:drain()
        session:content("q", "partial")
        runtime:drain()
        local surfaced = {}
        session:failure("q", "broken", function(err) table.insert(surfaced, err) end)
        runtime:drain()

        assert.same({ { "q", "partial" } }, emitted)
        assert.same({ "broken" }, surfaced)
        assert.is_nil(extmark(buf))
    end)

    it("hides released semantic status before surfacing failure", function()
        local buf = new_scratch()
        local runtime = new_runtime()
        local session = start_fake(buf, runtime)
        session:progress("q", { message = "Remote tool running" })
        runtime:drain()
        assert.equals("Remote tool running", virtual_text(buf))
        local mark_at_failure = true
        session:failure("q", "broken", function() mark_at_failure = extmark(buf) end)
        runtime:drain()
        assert.is_nil(mark_at_failure)
    end)

    it("cancels stale leases and deleted buffers with every timer", function()
        local buf = new_scratch()
        local runtime = new_runtime()
        local valid = true
        local session, emitted = start_fake(buf, runtime, {
            lease_valid = function() return valid end,
        })
        valid = false
        session:content("q", "discard")
        runtime:drain()
        assert.same({}, emitted)
        assert.equals(0, runtime:open_timer_count())

        local second_buf = new_scratch()
        local second_runtime = new_runtime()
        start_fake(second_buf, second_runtime)
        vim.api.nvim_buf_delete(second_buf, { force = true })
        second_runtime:advance(1000)
        second_runtime:drain()
        assert.equals(0, second_runtime:open_timer_count())
    end)

    it("invokes discard hooks once for cancel, frame-stale, and buffer-invalid", function()
        local cases = {
            {
                drive = function(session, _buf, runtime)
                    session:cancel("user")
                    session:cancel("again")
                    runtime:drain()
                end,
                expected = "cancel",
            },
            {
                drive = function(_session, _buf, runtime, set_valid)
                    runtime:advance(1000)
                    runtime:drain()
                    set_valid(false)
                    runtime:advance(120)
                    runtime:drain()
                end,
                expected = "stale",
            },
            {
                drive = function(_session, buf, runtime)
                    vim.api.nvim_buf_delete(buf, { force = true })
                    runtime:advance(1000)
                    runtime:drain()
                end,
                expected = "invalid",
            },
        }
        for _, case in ipairs(cases) do
            local buf = new_scratch()
            local runtime = new_runtime()
            local valid = true
            local calls = {}
            local session = chat_pending.start({
                buf = buf,
                agent = "Test Agent",
                anchor_line = 0,
                lease_valid = function() return valid end,
                emit_content = function() end,
                choose_verb_index = function() return 1 end,
                on_discard = function(kind) table.insert(calls, kind) end,
                clock = runtime.clock,
                scheduler = runtime.scheduler,
            })
            runtime:drain()
            assert.is_true(chat_pending.is_active(buf))
            case.drive(session, buf, runtime, function(value) valid = value end)
            assert.same({ case.expected }, calls)
            assert.is_false(chat_pending.is_active(buf))
        end
    end)

    it("releases ownership before a reentrant discard hook", function()
        local buf = new_scratch()
        local runtime = new_runtime()
        local replacement
        local session = chat_pending.start({
            buf = buf,
            agent = "Test Agent",
            anchor_line = 0,
            lease_valid = function() return true end,
            emit_content = function() end,
            choose_verb_index = function() return 1 end,
            on_discard = function()
                replacement = start_fake(buf, runtime)
            end,
            clock = runtime.clock,
            scheduler = runtime.scheduler,
        })
        runtime:drain()
        session:cancel("replace")
        runtime:drain()
        assert.is_truthy(replacement)
        assert.is_true(chat_pending.is_active(buf))
    end)

    it("contains and redacts throwing discard hooks", function()
        local buf = new_scratch()
        local runtime = new_runtime()
        local logs = {}
        local original_error = logger.error
        logger.error = function(message) table.insert(logs, message) end
        local session = chat_pending.start({
            buf = buf,
            agent = "Test Agent",
            anchor_line = 0,
            lease_valid = function() return true end,
            emit_content = function() end,
            choose_verb_index = function() return 1 end,
            on_discard = function() error("discarded private secret") end,
            clock = runtime.clock,
            scheduler = runtime.scheduler,
        })
        runtime:drain()
        session:cancel("private cancel reason")
        runtime:drain()
        logger.error = original_error

        assert.is_false(chat_pending.is_active(buf))
        local combined = table.concat(logs, "\n")
        assert.is_truthy(combined:find("chat pending discard terminal callback failed", 1, true))
        assert.is_nil(combined:find("discarded private secret", 1, true))
        assert.is_nil(combined:find("private cancel reason", 1, true))
        assert.is_truthy(start_fake(buf, runtime))
    end)

    it("does not invoke discard hooks for completion or provider failure", function()
        for _, terminal in ipairs({ "complete", "failure" }) do
            local buf = new_scratch()
            local runtime = new_runtime()
            local discarded = 0
            local session = chat_pending.start({
                buf = buf,
                agent = "Test Agent",
                anchor_line = 0,
                lease_valid = function() return true end,
                emit_content = function() end,
                choose_verb_index = function() return 1 end,
                on_discard = function() discarded = discarded + 1 end,
                clock = runtime.clock,
                scheduler = runtime.scheduler,
            })
            runtime:drain()
            if terminal == "complete" then
                session:complete("q", function() end)
            else
                session:failure("q", "provider", function() end)
            end
            runtime:drain()
            assert.equals(0, discarded)
            assert.is_false(chat_pending.is_active(buf))
        end
    end)

    it("frame ticks terminate a shown session whose lease became stale", function()
        local buf = new_scratch()
        local runtime = new_runtime()
        local valid = true
        start_fake(buf, runtime, {
            lease_valid = function() return valid end,
        })
        runtime:advance(1000)
        runtime:drain()
        runtime:advance(1000)
        runtime:drain()
        assert.is_truthy(extmark(buf))
        assert.is_truthy(runtime:open_timer_count() > 0)

        valid = false
        runtime:advance(120)
        runtime:drain()
        assert.is_nil(extmark(buf))
        assert.equals(0, runtime:open_timer_count())
    end)

    it("enforces one active session per buffer and cancel_all is idempotent", function()
        local buf = new_scratch()
        local runtime = new_runtime()
        local session = start_fake(buf, runtime)
        assert.has_error(function() start_fake(buf, runtime) end)
        local recursive
        session:complete("q", function() recursive = start_fake(buf, runtime) end)
        runtime:drain()
        assert.is_truthy(recursive, "a completion may install the recursive leg")
        chat_pending.cancel_all("user")
        chat_pending.cancel_all("user")
        runtime:drain()
        assert.equals(0, runtime:open_timer_count())

        local replacement = start_fake(buf, runtime)
        assert.is_truthy(replacement)
    end)

    it("does not publish sessions whose initializer fails", function()
        for _, chooser in ipairs({
            function() error("chooser failed") end,
            function() return 99 end,
        }) do
            local buf = new_scratch()
            local runtime = new_runtime()
            assert.has_error(function()
                chat_pending.start({
                    buf = buf,
                    agent = "Test Agent",
                    anchor_line = 0,
                    lease_valid = function() return true end,
                    emit_content = function() end,
                    choose_verb_index = chooser,
                    clock = runtime.clock,
                    scheduler = runtime.scheduler,
                })
            end)
            local cancelled = pcall(chat_pending.cancel_all, "after failed initializer")
            assert.is_true(cancelled)
            assert.is_false(chat_pending.is_active(buf))
            runtime:drain()

            local retry = start_fake(buf, runtime)
            assert.is_truthy(retry)
            assert.is_true(chat_pending.is_active(buf))
            retry:cancel("done")
            runtime:drain()
            assert.is_false(chat_pending.is_active(buf))
        end
    end)

    it("uses the production scheduler to leave a real uv fast event", function()
        local buf = new_scratch()
        local session = chat_pending.start({
            buf = buf,
            agent = "Test Agent",
            anchor_line = 0,
            lease_valid = function() return true end,
            emit_content = function() end,
            choose_verb_index = function() return 1 end,
        })
        local timer = uv.new_timer()
        local source_was_fast = false
        local callback_returned = false
        timer:start(1, 0, function()
            source_was_fast = vim.in_fast_event()
            session:progress("q", { message = "Remote tool running" })
            callback_returned = true
            timer:stop()
            timer:close()
        end)
        assert.is_true(vim.wait(1000, function() return callback_returned end, 5))
        assert.is_true(source_was_fast)
        assert.is_true(vim.wait(1000, function()
            return virtual_text(buf) == "Remote tool running"
        end, 5))
        assert.is_false(vim.in_fast_event())
        session:cancel("done")
    end)
end)
