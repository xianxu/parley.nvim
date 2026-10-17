-- #354: the attention finder's one transition. Pure: states are derived from
-- pending IDs and the answered/seen times, never stored.
local Model = require("parley.attention_model")

local function run(events, state)
    state = state or Model.empty()
    for _, step in ipairs(events) do
        local event, now = step[1], step[2]
        state = Model.transition(state, event, now)
    end
    return state
end

local function submitted(path, id, breadcrumb) return { type = "submitted", path = path, id = id, breadcrumb = breadcrumb } end
local function observed(path, probed, owed) return { type = "observed", path = path, probed_ids = probed, owed_ids = owed } end

local function state_of(state, path)
    local entry = state.entries[path]
    return entry and Model.state_of(entry) or "absent"
end

-- An entry in each derived state, built only through events.
local SETUPS = {
    absent = {},
    waiting = { { submitted("/a.md", "m1"), 10 } },
    answered = { { submitted("/a.md", "m1"), 10 }, { observed("/a.md", { "m1" }, {}), 20 } },
    seen = { { submitted("/a.md", "m1"), 10 }, { observed("/a.md", { "m1" }, {}), 20 }, { { type = "opened", path = "/a.md" }, 30 } },
}

describe("attention_model.transition", function()
    -- Each event in each derived state, applied at t=100.
    local cases = {
        { "absent", submitted("/a.md", "m2"), "waiting" },
        { "waiting", submitted("/a.md", "m2"), "waiting" },
        { "answered", submitted("/a.md", "m2"), "waiting" },
        { "seen", submitted("/a.md", "m2"), "waiting" },
        { "absent", observed("/a.md", { "m1" }, {}), "absent" },
        { "waiting", observed("/a.md", { "m1" }, { "m1" }), "waiting" },
        { "waiting", observed("/a.md", { "m1" }, {}), "answered" },
        { "answered", observed("/a.md", { "m1" }, {}), "answered" },
        { "seen", observed("/a.md", { "m1" }, {}), "seen" },
        { "waiting", { type = "observe_failed", path = "/a.md", reason = "not-registered" }, "waiting" },
        { "absent", { type = "opened", path = "/a.md" }, "absent" },
        { "waiting", { type = "opened", path = "/a.md" }, "waiting" },
        { "answered", { type = "opened", path = "/a.md" }, "seen" },
        { "seen", { type = "opened", path = "/a.md" }, "seen" },
        { "waiting", { type = "sweep", grace = 1 }, "waiting" },
        { "answered", { type = "sweep", grace = 1 }, "answered" },
        { "seen", { type = "sweep", grace = 70 }, "absent" },
        { "seen", { type = "sweep", grace = 71 }, "seen" },
    }
    for _, case in ipairs(cases) do
        local from, event, to = case[1], case[2], case[3]
        it(event.type .. " on " .. from .. " → " .. to, function()
            local state = Model.transition(run(SETUPS[from]), event, 100)
            assert.equals(to, state_of(state, "/a.md"))
        end)
    end

    it("never mutates its input", function()
        local before = run(SETUPS.waiting)
        local snapshot = vim.deepcopy(before)
        Model.transition(before, observed("/a.md", { "m1" }, {}), 100)
        Model.transition(before, submitted("/b.md", "m9"), 100)
        assert.same(snapshot, before)
    end)

    it("stamps answered_at once, when the last pending ID leaves", function()
        local state = run({
            { submitted("/a.md", "m1"), 10 },
            { submitted("/a.md", "m2"), 11 },
            { observed("/a.md", { "m1", "m2" }, { "m2" }), 20 },
        })
        assert.equals("waiting", state_of(state, "/a.md"))
        state = run({ { observed("/a.md", { "m2" }, {}), 30 } }, state)
        assert.equals(30, state.entries["/a.md"].answered_at)
        state = run({ { observed("/a.md", { "m2" }, {}), 40 } }, state)
        assert.equals(30, state.entries["/a.md"].answered_at)
    end)

    it("keeps a submit that a probe started before (the stale probe)", function()
        local state = run({
            { submitted("/a.md", "m1"), 10 },
            -- The probe starts here and captures { m1 }; m1 is then folded.
            { submitted("/a.md", "m2"), 11 },
            -- Its result has neither m1 nor m2: m2 was sent after it started.
            { observed("/a.md", { "m1" }, {}), 12 },
        })
        assert.equals("waiting", state_of(state, "/a.md"))
        assert.same({ "m2" }, vim.tbl_keys(state.entries["/a.md"].pending))
    end)

    it("marks a failed probe unknown and clears it on the next success", function()
        local state = run({
            { submitted("/a.md", "m1"), 10 },
            { { type = "observe_failed", path = "/a.md", reason = "unsupported" }, 11 },
        })
        assert.equals("unsupported", state.entries["/a.md"].unknown)
        state = run({ { observed("/a.md", { "m1" }, { "m1" }), 12 } }, state)
        assert.is_nil(state.entries["/a.md"].unknown)
    end)

    it("replaces the breadcrumb and submitted_at on a new submit", function()
        local state = run({
            { submitted("/a.md", "m1", { trail = 1 }), 10 },
            { submitted("/a.md", "m2", { trail = 2 }), 20 },
        })
        assert.same({ trail = 2 }, state.entries["/a.md"].breadcrumb)
        assert.equals(20, state.entries["/a.md"].submitted_at)
    end)
end)

describe("attention_model properties over random event sequences", function()
    local paths = { "/a.md", "/b.md", "/c.md" }
    local function random_event(rng, ids)
        local path = paths[rng(#paths)]
        local kind = rng(5)
        if kind == 1 then
            ids.n = ids.n + 1
            return submitted(path, "m" .. ids.n)
        elseif kind == 2 then
            local probed, owed = {}, {}
            for i = 1, ids.n do
                if rng(2) == 1 then probed[#probed + 1] = "m" .. i end
                if rng(2) == 1 then owed[#owed + 1] = "m" .. i end
            end
            return observed(path, probed, owed)
        elseif kind == 3 then
            return { type = "observe_failed", path = path, reason = "x" }
        elseif kind == 4 then
            return { type = "opened", path = path }
        end
        return { type = "sweep", grace = rng(50) }
    end

    it("holds for 200 seeded sequences", function()
        for seed = 1, 200 do
            math.randomseed(seed)
            local rng = function(n) return math.random(n) end
            local state, ids = Model.empty(), { n = 0 }
            for step = 1, 40 do
                local event = random_event(rng, ids)
                local now = step * 10
                local before = state
                state = Model.transition(state, event, now)
                local old = before.entries[event.path]
                local new = state.entries[event.path]
                local was = old and Model.state_of(old) or "absent"
                local is = new and Model.state_of(new) or "absent"
                local context = ("seed %d step %d %s: %s → %s"):format(seed, step, event.type, was, is)
                -- A failed probe never changes the state.
                if event.type == "observe_failed" then assert.equals(was, is, context) end
                -- Only an observation reaches answered from waiting.
                if was == "waiting" and is == "answered" then assert.equals("observed", event.type, context) end
                -- A waiting entry is never swept.
                if event.type == "sweep" then
                    for path, entry in pairs(before.entries) do
                        if Model.state_of(entry) == "waiting" then assert.is_truthy(state.entries[path], context) end
                    end
                end
                -- An ID outside the probed set survives an observation.
                if event.type == "observed" and old then
                    local probed = {}
                    for _, id in ipairs(event.probed_ids) do probed[id] = true end
                    for id in pairs(old.pending) do
                        if not probed[id] then assert.is_truthy(new.pending[id], context) end
                    end
                end
            end
        end
    end)
end)

describe("attention_model bound, list and answered_unseen", function()
    -- `n` entries, submitted at t=1..n; `kinds(i)` picks each one's state.
    local function filled(n, kinds)
        local state = Model.empty()
        for i = 1, n do
            local path = ("/f%03d.md"):format(i)
            state = Model.transition(state, submitted(path, "m" .. i), i)
            local kind = kinds(i)
            if kind ~= "waiting" then state = Model.transition(state, observed(path, { "m" .. i }, {}), 1000 + i) end
            if kind == "seen" then state = Model.transition(state, { type = "opened", path = path }, 2000 + i) end
        end
        return state
    end
    local function count(state)
        return #Model.list(state)
    end

    it("drops the oldest seen entry first, then the oldest answered", function()
        local state = filled(Model.LIMIT, function(i)
            if i == 5 then return "seen" end
            if i <= 10 then return "answered" end
            return "waiting"
        end)
        state = Model.transition(state, submitted("/new.md", "x1"), 5000)
        assert.equals(Model.LIMIT, count(state))
        assert.is_nil(state.entries["/f005.md"])
        state = Model.transition(state, submitted("/new2.md", "x2"), 5001)
        assert.is_nil(state.entries["/f001.md"])
        assert.is_truthy(state.entries["/f002.md"])
    end)

    it("refuses a new path when every entry is waiting, and still takes a resubmit", function()
        local state = filled(Model.LIMIT, function() return "waiting" end)
        local refused, err = Model.transition(state, submitted("/new.md", "x1"), 5000)
        assert.equals("full", err)
        assert.is_nil(refused.entries["/new.md"])
        local resubmit, resubmit_err = Model.transition(state, submitted("/f001.md", "x2"), 5000)
        assert.is_nil(resubmit_err)
        assert.is_truthy(resubmit.entries["/f001.md"].pending.x2)
    end)

    it("lists newest submit first, ties by path, and counts answered entries", function()
        local state = run({
            { submitted("/b.md", "m1"), 10 },
            { submitted("/a.md", "m2"), 10 },
            { submitted("/c.md", "m3"), 20 },
            { observed("/a.md", { "m2" }, {}), 30 },
            { observed("/b.md", { "m1" }, {}), 30 },
            { { type = "opened", path = "/b.md" }, 40 },
        })
        local order = vim.tbl_map(function(entry) return entry.path end, Model.list(state))
        assert.same({ "/c.md", "/a.md", "/b.md" }, order)
        assert.equals(1, Model.answered_unseen(state))
    end)
end)

describe("attention_model side docs", function()
    local function discovered(path, parent, at) return { type = "discovered", path = path, parent = parent, at = at } end

    it("a discovered side doc is answered, not yet seen, and leaves by the same rule", function()
        local state = run({ { discovered("/a.side/s.md", "/a.md", 50), 60 } })
        local entry = state.entries["/a.side/s.md"]
        assert.equals("answered", Model.state_of(entry))
        assert.same({ "side", "/a.md", 50, 60 }, { entry.kind, entry.parent, entry.submitted_at, entry.recorded_at })
        state = run({ { { type = "opened", path = "/a.side/s.md" }, 70 }, { { type = "sweep", grace = 10 }, 79 } }, state)
        assert.equals("seen", state_of(state, "/a.side/s.md"))
        state = run({ { { type = "sweep", grace = 10 }, 80 } }, state)
        assert.equals("absent", state_of(state, "/a.side/s.md"))
        assert.equals(80, state.retired["/a.side/s.md"])
    end)

    it("a retired or already-known path is never rediscovered", function()
        local state = run({
            { submitted("/a.side/s.md", "m1"), 10 },
            { discovered("/a.side/s.md", "/a.md", 50), 60 },
        })
        assert.equals("waiting", state_of(state, "/a.side/s.md"))
        state = Model.empty()
        state.retired["/b.side/t.md"] = 5
        state = Model.transition(state, discovered("/b.side/t.md", "/b.md", 50), 60)
        assert.equals("absent", state_of(state, "/b.side/t.md"))
    end)

    it("an evicted side doc is retired too, and the retired set stays bounded", function()
        local state = Model.empty()
        for i = 1, Model.LIMIT do
            state = Model.transition(state, discovered(("/s%03d.md"):format(i), "/p.md", i), i)
        end
        state = Model.transition(state, discovered("/extra.md", "/p.md", 1000), 1000)
        assert.is_nil(state.entries["/s001.md"])
        assert.equals(1000, state.retired["/s001.md"])
        -- A full retired set drops its oldest path when one more retires.
        state = Model.empty()
        for i = 1, Model.LIMIT do state.retired["/r" .. i] = i end
        state = run({ { discovered("/new.md", "/p.md", 1), 3000 }, { { type = "opened", path = "/new.md" }, 3001 },
            { { type = "sweep", grace = 0 }, 3002 } }, state)
        assert.equals(Model.LIMIT, vim.tbl_count(state.retired))
        assert.is_nil(state.retired["/r1"])
        assert.equals(3002, state.retired["/new.md"])
    end)

    it("a batch applies its events in order, as one change", function()
        local state = Model.transition(Model.empty(), { type = "batch", events = {
            discovered("/a.side/1.md", "/a.md", 5), discovered("/a.side/2.md", "/a.md", 6),
            { type = "opened", path = "/a.side/1.md" },
        } }, 10)
        assert.same({ "/a.side/2.md", "/a.side/1.md" }, vim.tbl_map(function(e) return e.path end, Model.list(state)))
        assert.equals("seen", state_of(state, "/a.side/1.md"))
    end)
end)

describe("attention_model viewed", function()
    local function viewed(path, at) return { type = "viewed", path = path, at = at } end

    it("an answered entry viewed after its answer is seen", function()
        local state = run({ { viewed("/a.md", 25) } }, run(SETUPS.answered))
        assert.equals("seen", state_of(state, "/a.md"))
        assert.equals(25, state.entries["/a.md"].seen_at)
    end)

    it("a view before or at the answer changes nothing", function()
        local answered = run(SETUPS.answered) -- answered at 20
        assert.equals(answered, Model.transition(answered, viewed("/a.md", 15), 30))
        assert.equals(answered, Model.transition(answered, viewed("/a.md", 20), 30))
    end)

    it("a view of a waiting, seen or unknown path changes nothing", function()
        for _, setup in ipairs({ "waiting", "seen", "absent" }) do
            local state = run(SETUPS[setup])
            assert.equals(state, Model.transition(state, viewed("/a.md", 99), 100))
        end
    end)
end)
