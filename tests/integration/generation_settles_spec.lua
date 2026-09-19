-- #261 M4: every wait a generation holds settles. The invariant: a generation
-- that enters `stopping` reaches `terminal` (within the kill bound), and
-- `Runner.stats().active` counts exactly the generations not yet terminal.
-- Each case arranges for one leaf never to call back, or to throw, then stops
-- the generation and asserts `terminal`. `after_each` asserts the count is back
-- at zero, so a leak fails the next case too.
-- Every wait M4 settles, and the test that pins each (#261 M4 review I4). The
-- list carries its evidence: the last case below checks that every spec and
-- case named here exists, so it cannot claim a test that is not there.
local WAITS = {
    { "W1", { "tests/integration/generation_settles_spec.lua", "W1: a preparation whose start threw" },
        { "tests/integration/generation_settles_spec.lua", "W1: a request whose start threw" },
        { "tests/integration/generation_settles_spec.lua", "W1: a tool whose start threw" } },
    { "W2", { "tests/integration/chat_onboarding_capture_spec.lua", "ends a response at Stop while its readiness picker never answers" },
        { "tests/integration/chat_remote_preparation_spec.lua", "ends at Stop without waiting on fetches" } },
    { "W3", { "tests/integration/chat_onboarding_capture_spec.lua", "ends a response at Stop while its readiness picker never answers" } },
    { "W4", { "tests/integration/unscoped_kill_spec.lua", "a content fetch for a generation runs in its scope" },
        { "tests/integration/unscoped_kill_spec.lua", "every content-fetch spawn runs in the scope it is handed" },
        { "tests/integration/chat_remote_preparation_spec.lua", "ends at Stop without waiting on fetches" } },
    { "W5", { "tests/integration/response_provider_spec.lua", "resolves a cancel during pre-query at once" },
        { "tests/integration/response_provider_spec.lua", "resolves a cancel during recovery at once" } },
    { "W6", { "tests/unit/vault_spec.lua", "V2: every failed refresh calls on_error" },
        { "tests/unit/providers_pre_query_spec.lua", "forwards the dispatcher's error callback to the bearer refresh" } },
    { "W7", { "tests/unit/dispatcher_query_spec.lua", "J0c: a throw while setting up the request aborts it" } },
    { "W8", { "tests/unit/dispatcher_query_spec.lua", "J0b: a recovery is not started once the owner stops mid-request" } },
    { "W9", { "tests/integration/generation_settles_spec.lua", "W1: a tool whose start threw" } },
    { "W10", dropped = "unreachable through public events: the machine refuses a first tool outcome only for a"
        .. " tool the tool layer never recorded, or one already supervised or final (plan Revisions)" },
    { "W11", { "tests/integration/generation_settles_spec.lua", "W11: a continuation whose start threw" } },
    { "W12", { "tests/integration/chat_onboarding_capture_spec.lua", "ends a response whose completion refuses to start" } },
    { "W13", { "tests/integration/response_completion_spec.lua", "settles its finalize failed when its step throws" },
        { "tests/unit/response_preparation_spec.lua", "settles failed when its step throws" },
        { "tests/unit/response_target_spec.lua", "cancels itself when its step throws" },
        { "tests/integration/response_topic_spec.lua", "retires failed when its step throws" },
        { "tests/integration/generation_settles_spec.lua", "fault: a runner step that throws" } },
    { "W14", { "tests/integration/generation_settles_spec.lua", "W14: a start that throws after registration" } },
    { "W15", { "tests/unit/chat_cancel_entry_spec.lua", "still cancel the session when the topic cancel throws" },
        { "tests/unit/chat_cancel_entry_spec.lua", "guard the topic cancel the terminal handler shares" },
        { "tests/integration/chat_onboarding_capture_spec.lua", "finishes its ending cleanup when the topic cancel throws" },
        { "tests/integration/batch_lifecycle_spec.lua", "still cancels the running responses when the batch cancel throws" } },
    { "W16", { "tests/integration/response_topic_spec.lua", "retires when its provider request throws" },
        { "tests/integration/response_topic_spec.lua", "answers a stop that arrives during its request once the request returns" },
        { "tests/integration/response_topic_spec.lua", "retires when '" },
        { "tests/integration/response_topic_spec.lua", "retires a started topic whose " } },
    { "W17", { "tests/integration/skill_invoke_spec.lua", "frees a stranded run when its buffer is unloaded" } },
    { "W18", { "tests/integration/response_completion_spec.lua", "settles failed on its own when cancelled before it writes" } },
}

local Runner = require("parley.generation_runner")
local D = require("parley.document")
local FakeEditor = require("tests.helpers.fake_document_editor")
local Fake = require("tests.helpers.fake_generation_runner")

local serial = 200000
local docs, runners = {}, {}
local function document()
    serial = serial + 1
    local editor = FakeEditor.new({ "💬: q", "draft", "🤖: first", "", "💬: q2", "🤖: second", "" })
    local doc = D.attach(serial, { driver = editor.driver, schedule = false }); docs[#docs + 1] = doc
    assert.equals("idle", D.drain(doc, 1000).status)
    return doc, editor
end
local function spec(doc, row, extra)
    local marker = D.query(doc, row, row + 1)[1]; local body = D.query(doc, row + 1, row + 2)[1]
    return vim.tbl_extend("force", { entity = marker.handle, first = marker.start_byte, last = body.end_byte - 1,
        input = { message = "frozen" }, dependencies = { { first = 0, last = 4 } }, schedule = false }, extra or {})
end
local function start(doc, adapters, extra)
    local runner, reason = Runner.start(doc, spec(doc, 2, extra), adapters)
    assert.is_not_nil(runner, reason); runners[#runners + 1] = runner
    Runner.drain(runner, 1000)
    return runner
end
local function phase(r) return Runner.snapshot(r).phase end

describe("every wait a generation holds settles", function()
    after_each(function()
        for _, r in ipairs(runners) do pcall(Runner.cancel, r); pcall(Runner.drain, r, 100) end
        for _, doc in ipairs(docs) do D.detach(doc) end
        runners, docs = {}, {}
        assert.equals(0, Runner.stats().active, "a generation leaked past its test")
    end)

    it("stats counts the generations not yet terminal", function()
        local doc = document(); local fake = Fake.new()
        local r = start(doc, fake.adapters)
        assert.equals(1, Runner.stats().active)
        fake:prepare(); Runner.drain(r, 1000)
        fake:output(1, "answer"); fake:complete(1); Runner.drain(r, 1000)
        assert.equals("terminal", phase(r))
        assert.equals(0, Runner.stats().active)
    end)

    -- W14: a start that throws after registering the generation.
    it("W14: a start that throws after registration releases everything it took", function()
        local doc = document(); local fake = Fake.new()
        local runner, reason
        require("tests.helpers.stub").with_stub(D, "subscribe", function() error("subscribe exploded") end, function()
            runner, reason = Runner.start(doc, spec(doc, 2), fake.adapters)
        end)
        assert.is_nil(runner)
        assert.truthy(tostring(reason):find("subscribe exploded", 1, true))
        assert.equals(0, Runner.stats().active)
        -- The region, the generation and the turn are free: the same start is admitted.
        local again = start(doc, fake.adapters)
        assert.equals(1, Runner.stats().active)
        Runner.cancel(again); Runner.drain(again, 1000)
        fake.preparations[1].callbacks.resolved(); Runner.drain(again, 1000)
    end)

    it("W14: a start whose first dispatch throws releases everything too", function()
        local doc = document(); local fake = Fake.new()
        local runner, reason
        require("tests.helpers.stub").with_stub(require("parley.generation"), "transition",
            function() error("dispatch exploded") end, function()
                runner, reason = Runner.start(doc, spec(doc, 2), fake.adapters)
            end)
        assert.is_nil(runner)
        assert.truthy(tostring(reason):find("dispatch exploded", 1, true))
        assert.equals(0, Runner.stats().active)
        local again = start(doc, fake.adapters)
        Runner.cancel(again); Runner.drain(again, 1000)
        fake.preparations[1].callbacks.resolved(); Runner.drain(again, 1000)
    end)

    -- W1: an operation whose start threw has no handle to cancel through.
    it("W1: a preparation whose start threw still lets the generation end", function()
        local doc = document(); local fake = Fake.new()
        fake.adapters.prepare = function() error("prepare exploded") end
        local r = start(doc, fake.adapters)
        assert.equals("terminal", phase(r))
        -- A Lua error is the diagnosis beside the outcome, not a token (#261 M5).
        assert.truthy(tostring(Runner.snapshot(r).diagnosis):find("prepare exploded", 1, true))
    end)

    it("W1: a request whose start threw still lets the generation end", function()
        local doc = document(); local fake = Fake.new()
        fake.adapters.request = function() error("request exploded") end
        local r = start(doc, fake.adapters)
        fake:prepare(); Runner.drain(r, 1000)
        assert.equals("terminal", phase(r))
    end)

    -- A tool round: the request declares calls, each starts through start_child.
    local function tool_adapters(fake, overrides)
        local children, rounds = {}, {}
        fake.adapters.start_child = function(ctx, cb)
            local item = { ctx = ctx, callbacks = cb }; children[#children + 1] = item; return item
        end
        fake.adapters.continue_round = function(ctx, cb)
            local item = { ctx = ctx, callbacks = cb }; rounds[#rounds + 1] = item; return item
        end
        for key, fn in pairs(overrides or {}) do fake.adapters[key] = fn end
        return children, rounds
    end
    local function declare(fake, r, calls)
        fake.requests[1].callbacks.round(calls)
        fake.requests[1].callbacks.complete(); fake.requests[1].callbacks.resolved()
        Runner.drain(r, 1000)
    end

    it("W1: a tool whose start threw is an unknown outcome, and the round goes on", function()
        local doc = document(); local fake = Fake.new()
        local _, rounds = tool_adapters(fake, { start_child = function() error("tool exploded") end })
        local r = start(doc, fake.adapters)
        fake:prepare(); Runner.drain(r, 1000)
        declare(fake, r, { { call_id = "c1", arguments = {} } })
        assert.equals(1, #rounds, "the round continued past a tool that never started")
        Runner.cancel(r); Runner.drain(r, 1000)
        -- The continuation has a handle, so its own adapter confirms the cancel.
        for _, cancellation in ipairs(fake.cancellations) do cancellation.resolved() end
        Runner.drain(r, 1000)
        assert.equals("terminal", phase(r))
    end)

    it("W11: a continuation whose start threw still lets the generation end", function()
        local doc = document(); local fake = Fake.new()
        local children = tool_adapters(fake, { continue_round = function() error("continuation exploded") end })
        local r = start(doc, fake.adapters)
        fake:prepare(); Runner.drain(r, 1000)
        declare(fake, r, { { call_id = "c1", arguments = {} } })
        children[1].callbacks.outcome("known", { content = "ok" }); children[1].callbacks.resolved()
        Runner.drain(r, 1000)
        assert.equals("terminal", phase(r))
    end)

    -- The scope kill: once, at whichever comes first of stopping and terminal.
    it("kills the generation's process scope once when it stops", function()
        local doc = document(); local fake = Fake.new(); local kills = {}
        fake.adapters.stopping = function(ctx) kills[#kills + 1] = ctx end
        local r = start(doc, fake.adapters)
        fake:prepare(); Runner.drain(r, 1000)
        Runner.cancel(r); Runner.drain(r, 1000)
        assert.equals(1, #kills)
        assert.equals(Runner.snapshot(r).generation, kills[1].generation)
        fake.requests[1].callbacks.resolved(); Runner.drain(r, 1000)
        assert.equals("terminal", phase(r))
        assert.equals(1, #kills, "stopping then terminal kills once")
    end)

    it("kills the scope at a successful terminal too, which never enters stopping", function()
        local doc = document(); local fake = Fake.new(); local kills = 0
        fake.adapters.stopping = function() kills = kills + 1 end
        local r = start(doc, fake.adapters)
        fake:prepare(); Runner.drain(r, 1000)
        fake:output(1, "answer"); fake:complete(1); Runner.drain(r, 1000)
        assert.equals("success", Runner.snapshot(r).outcome)
        assert.equals(1, kills)
    end)

    -- fault: the runner's own step threw. It is the one way to reach terminal
    -- with operations outstanding.
    it("fault: a runner step that throws kills the scope and ends the generation", function()
        local doc = document(); local fake = Fake.new(); local kills, final = 0, nil
        fake.adapters.stopping = function() kills = kills + 1 end
        fake.adapters.terminal = function(snapshot) final = snapshot end
        local r = start(doc, fake.adapters, { schedule = true })
        assert.is_true(vim.wait(500, function() return #fake.preparations == 1 end, 5))
        fake:prepare()
        assert.is_true(vim.wait(500, function() return #fake.requests == 1 end, 5))
        -- Only the scheduled step writes, so a throw here escapes nothing but the
        -- step itself: the Deferred's error path.
        require("tests.helpers.stub").with_stub(D, "append", function() error("step exploded") end, function()
            fake:output(1, "answer")
            assert.is_true(vim.wait(500, function() return final ~= nil end, 5), "the runner never reached terminal")
        end)
        assert.equals("fault", final.outcome)
        -- The Lua error is the diagnosis; `fault`'s own words come from the
        -- outcome, so the row has a reachable consumer (#261 M5 review round 4).
        assert.is_nil(final.failure)
        assert.truthy(tostring(final.diagnosis):find("step exploded", 1, true))
        -- One authority for "terminal": the snapshot reports what the host got.
        assert.equals("terminal", Runner.snapshot(r).phase)
        assert.equals("fault", Runner.snapshot(r).outcome)
        assert.equals(1, kills)
        assert.equals(0, Runner.stats().active)
    end)
end)

-- #261 M4 Task 4.5: the reported shape, end to end. A provider stream that
-- ignores SIGTERM is stopped, again and again: each Stop must reach terminal
-- through the SIGKILL escalation, so no slot is ever held. Before M3/M4 the 5th
-- submission in one buffer was refused with `generation limit`, the 17th across
-- reloads with `process generation limit`.
describe("a stopped response never holds a slot", function()
    local parley = require("parley")
    local Respond = require("parley.chat_respond")
    local Tasker = require("parley.tasker")
    local Vault = require("parley.vault")
    local FakeProcess = require("tests.helpers.fake_process")
    local root, path, buf, processes, now, old_secret, old_run, baseline
    local function wait(fn, what) assert.is_true(vim.wait(5000, fn, 1), what or "the response did not settle") end
    local function providers()
        local out = {}
        for _, p in pairs(processes.processes) do
            for _, arg in ipairs(p.args) do if arg == "--write-out" then out[#out + 1] = p end end
        end
        table.sort(out, function(a, b) return a.pid < b.pid end)
        return out
    end
    before_each(function()
        root = vim.fn.tempname() .. "-settles"; vim.fn.mkdir(root, "p")
        root = (vim.uv or vim.loop).fs_realpath(root)
        parley.setup({ chat_dir = root, state_dir = root .. "/state",
            providers = { openai = { endpoint = "http://127.0.0.1:9/fixture" } }, api_keys = {},
            default_agent = "SettleFixture", agents = { { name = "Choose a model", disable = true },
                { name = "SettleFixture", provider = "openai", model = { model = "fixture" }, system_prompt = "Fixture", tools = {} } } })
        old_secret, old_run = Vault.get_secret, Vault.run_with_secret
        Vault.get_secret = function() return "fixture-secret" end
        Vault.run_with_secret = function(_, fn) fn() end
        Tasker._reset(); Tasker._uv, processes = FakeProcess.new({ pipes_follow_holders = true })
        now = 0; Tasker._clock = function() return now end
        path = root .. "/2026-09-19.10-00-00.001_settles.md"
        vim.fn.writefile({ "# topic: Settles", "- file: settles.md", "---", "", "💬: first", "🤖: old", "old one", "",
            "💬: next", "draft" }, path)
        vim.cmd("edit " .. vim.fn.fnameescape(path)); buf = vim.api.nvim_get_current_buf()
        baseline = require("parley.generation_runner").stats().active
    end)
    after_each(function()
        Respond.cancel_responses(buf)
        for _, p in pairs(processes.processes) do p.ignores = {}; p:finish() end
        vim.wait(200, function() return Tasker.stats().active == 0 end, 5)
        Vault.get_secret, Vault.run_with_secret = old_secret, old_run
        Tasker._reset(); Tasker._uv = nil; Tasker._clock = nil
        if vim.api.nvim_buf_is_valid(buf) then vim.api.nvim_buf_delete(buf, { force = true }) end
        vim.fn.delete(root, "rf")
    end)
    local function cursor_on_first()
        for i, line in ipairs(vim.api.nvim_buf_get_lines(buf, 0, -1, false)) do
            if line == "💬: first" then vim.api.nvim_win_set_cursor(0, { i, 0 }); return end
        end
        error("question missing")
    end
    -- How a generation can be stopped from outside (#261 M4 review I3): the
    -- Done-when names them all, so each is driven against a live stream.
    local CAUSES = {
        stop = function() Respond.cancel_responses(buf) end,
        -- An edit inside the answer the stream is writing revokes its writer.
        edit = function(stream)
            stream:emit("stdout", 'data: {"choices":[{"delta":{"content":"partial answer"}}]}\n\n')
            local row
            wait(function()
                for i, line in ipairs(vim.api.nvim_buf_get_lines(buf, 0, -1, false)) do
                    if line:find("partial answer", 1, true) then row = i - 1; return true end
                end
            end, "the stream's output never landed")
            vim.api.nvim_buf_set_text(buf, row, 0, row, 0, { "human " })
        end,
        reload = function() vim.cmd("silent write"); vim.cmd("edit!") end,
        detach = function()
            vim.cmd("silent write"); vim.cmd("bdelete!")
            vim.cmd("edit " .. vim.fn.fnameescape(path)); buf = vim.api.nvim_get_current_buf()
        end,
    }
    -- Submit, let the stream start, stop it by `how`, and drive the kill
    -- escalation to its end.
    local function submit_and_stop(label, how)
        local D = require("parley.document")
        wait(function() return D.repair_step(D.get(buf)).status == "idle" end)
        cursor_on_first()
        local count = #providers()
        local session, reason = Respond.respond({ range = 0 })
        assert.is_not_nil(session, label .. ": refused: " .. tostring(reason))
        wait(function() return #providers() > count end, label .. ": no provider stream started")
        local stream = providers()[#providers()]
        stream.ignores = { [15] = true } -- the stream ignores SIGTERM
        CAUSES[how or "stop"](stream)
        -- The kill escalates at 2 s: advance the clock and fire the reconcile timers.
        wait(function()
            now = now + 500
            for _, timer in ipairs(processes.timers) do if timer.callback then timer:fire() end end
            return Respond.response_snapshot(session).status == "terminal"
        end, label .. ": a stopped response never reached terminal")
        wait(function() return Tasker.stats().active == 0 end, label .. ": its process was never released")
        assert.equals(baseline, require("parley.generation_runner").stats().active, label .. ": a slot is still held")
        local killed = false
        for _, sig in ipairs(processes.signals) do if sig.pid == stream.pid and sig.signal == 9 then killed = true end end
        assert.is_true(killed, label .. ": the stream was not killed")
    end

    for _, how in ipairs({ "stop", "edit", "reload", "detach" }) do
        it("ends a stream stopped by " .. how .. ", and admits the next submission", function()
            submit_and_stop(how .. " 1", how)
            submit_and_stop(how .. " 2", how)
        end)
    end

    it("admits the 5th Stop-and-resubmit in one buffer", function()
        for i = 1, 5 do submit_and_stop("submission " .. i) end
    end)

    it("admits the 17th Stop-and-resubmit across :e! reloads", function()
        for i = 1, 17 do
            submit_and_stop("submission " .. i)
            vim.cmd("silent write")
            vim.cmd("edit!")
        end
    end)

    it("admits a submission after :bd and reopening the same file", function()
        submit_and_stop("before :bd")
        local before = buf
        vim.cmd("silent write")
        vim.cmd("bdelete!")
        vim.cmd("edit " .. vim.fn.fnameescape(path)); buf = vim.api.nvim_get_current_buf()
        assert.equals(before, buf, "the buffer number is reused")
        submit_and_stop("after reopening")
    end)
end)

-- Whether `file` declares a case or block whose name starts with `case`. The
-- WAITS list itself is cut out first, so it cannot vouch for its own entries.
local function declares(file, case)
    local text = table.concat(vim.fn.readfile(file), "\n")
    text = text:gsub("local WAITS = %b{}", "")
    for _, opener in ipairs({ "it(", "describe(" }) do
        for _, quote in ipairs({ '"', "'" }) do
            if text:find(opener .. quote .. case, 1, true) or text:find(opener .. " " .. quote .. case, 1, true) then
                return true
            end
        end
    end
    return false
end

describe("the waits list", function()
    it("names W1 to W18, each with a test that exists, or the reason it was dropped", function()
        local problems = {}
        for i, row in ipairs(WAITS) do
            if row[1] ~= "W" .. i then problems[#problems + 1] = "row " .. i .. " is " .. tostring(row[1]) end
            if row.dropped then
                if #row > 1 then problems[#problems + 1] = row[1] .. " is dropped but names tests" end
            elseif #row < 2 then problems[#problems + 1] = row[1] .. " names no test"
            end
            for j = 2, #row do
                local file, case = row[j][1], row[j][2]
                if vim.fn.filereadable(file) == 0 then
                    problems[#problems + 1] = row[1] .. ": " .. file .. " does not exist"
                elseif not declares(file, case) then
                    problems[#problems + 1] = row[1] .. ": " .. file .. " has no case '" .. case .. "'"
                end
            end
        end
        assert.equals(18, #WAITS)
        assert.same({}, problems)
    end)
    it("cannot be satisfied by a case name it does not declare (counterfactual)", function()
        assert.is_false(declares("tests/integration/generation_settles_spec.lua", "W1: a preparation whose start threw!"))
        assert.is_false(declares("tests/integration/generation_settles_spec.lua", "no such case"))
        assert.is_true(declares("tests/integration/generation_settles_spec.lua", "W1: a preparation whose start threw"))
    end)
end)
