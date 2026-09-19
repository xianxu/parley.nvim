-- #261 M4: every wait a generation holds settles. The invariant: a generation
-- that enters `stopping` reaches `terminal` (within the kill bound), and
-- `Runner.stats().active` counts exactly the generations not yet terminal.
-- Each case arranges for one leaf never to call back, or to throw, then stops
-- the generation and asserts `terminal`. `after_each` asserts the count is back
-- at zero, so a leak fails the next case too.
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
        local subscribe = D.subscribe
        D.subscribe = function() error("subscribe exploded") end
        local runner, reason = Runner.start(doc, spec(doc, 2), fake.adapters)
        D.subscribe = subscribe
        assert.is_nil(runner)
        assert.truthy(tostring(reason):find("subscribe exploded", 1, true))
        assert.equals(0, Runner.stats().active)
        -- The region, the generation and the turn are free: the same start is admitted.
        local again = start(doc, fake.adapters)
        assert.equals(1, Runner.stats().active)
        Runner.cancel(again); Runner.drain(again, 1000)
        fake.preparations[1].callbacks.resolved(); Runner.drain(again, 1000)
    end)

    -- W1: an operation whose start threw has no handle to cancel through.
    it("W1: a preparation whose start threw still lets the generation end", function()
        local doc = document(); local fake = Fake.new()
        fake.adapters.prepare = function() error("prepare exploded") end
        local r = start(doc, fake.adapters)
        assert.equals("terminal", phase(r))
        assert.truthy(tostring(Runner.snapshot(r).failure):find("prepare exploded", 1, true))
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
        local append = D.append
        D.append = function() error("step exploded") end
        local ok, err = pcall(function()
            fake:output(1, "answer")
            assert.is_true(vim.wait(500, function() return final ~= nil end, 5), "the runner never reached terminal")
        end)
        D.append = append
        assert(ok, err)
        assert.equals("fault", final.outcome)
        assert.truthy(tostring(final.failure):find("step exploded", 1, true))
        assert.equals(1, kills)
        assert.equals(0, Runner.stats().active)
    end)
end)
