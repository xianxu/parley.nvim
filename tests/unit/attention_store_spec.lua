-- #354: the attention store. Real files and a real document lease under a
-- temporary state directory; the corruption cases also run through
-- tests/helpers/sidecars.lua.
local Store = require("parley.attention_store")
local Model = require("parley.attention_model")
local logger = require("parley.logger")
local leases = require("parley.document_lease")

local parley = require("parley")

local function submitted(path, id) return { type = "submitted", path = path, id = id } end

-- Apply and wait for on_done; returns its arguments.
local function apply(event, options)
    local done, state, err = false, nil, nil
    Store.apply(event, options, function(s, e) done, state, err = true, s, e end)
    assert(vim.wait(2000, function() return done end, 5), "apply never finished")
    return state, err
end

describe("attention_store", function()
    local saved_dir, warnings, saved_warning, dir

    before_each(function()
        dir = vim.fn.tempname() .. "-attention"
        saved_dir = parley.config.state_dir
        parley.config.state_dir = dir
        warnings, saved_warning = {}, logger.warning
        logger.warning = function(message) warnings[#warnings + 1] = message end
    end)
    after_each(function()
        logger.warning = saved_warning
        parley.config.state_dir = saved_dir
        vim.fn.delete(dir, "rf")
    end)

    it("round-trips applied events, re-reading the file before each write", function()
        apply(submitted("/a.md", "m1"), { now = 10 })
        -- Another editor's write lands between ours.
        local other = Model.transition(Store.load(), submitted("/b.md", "m2"), 11)
        assert(require("parley.helper").table_to_file_atomic(other, Store.path()))
        local state = apply(submitted("/c.md", "m3"), { now = 12 })
        assert.same({ "/c.md", "/b.md", "/a.md" }, vim.tbl_map(function(e) return e.path end, Model.list(state)))
        assert.same(state, Store.load())
        assert.same({}, warnings)
    end)

    it("sweeps seen entries past the grace on every apply", function()
        apply(submitted("/a.md", "m1"), { now = 10 })
        apply({ type = "observed", path = "/a.md", probed_ids = { "m1" }, owed_ids = {} }, { now = 20 })
        apply({ type = "opened", path = "/a.md" }, { now = 30 })
        local kept = apply(submitted("/b.md", "m2"), { now = 89, grace = 60 })
        assert.is_truthy(kept.entries["/a.md"])
        local swept = apply(submitted("/b.md", "m3"), { now = 90, grace = 60 })
        assert.is_nil(swept.entries["/a.md"])
    end)

    it("takes the grace from attention.seen_grace_minutes", function()
        local saved = parley.config.attention
        parley.config.attention = { seen_grace_minutes = 15 }
        assert.equals(900, Store.grace_seconds())
        parley.config.attention = saved
    end)

    -- The parse boundary: whatever does not fit reads as empty, with one warning.
    local corrupt = {
        { "an unknown version", { version = 2, entries = {} } },
        { "a string version", { version = "1", entries = {} } },
        { "an entry keyed by another path", { version = 1, entries = { ["/a.md"] = { path = "/b.md", pending = {}, submitted_at = 1 } } } },
        { "an entry without a submit time", { version = 1, entries = { ["/a.md"] = { path = "/a.md", pending = {} } } } },
        { "an entry with a scalar pending", { version = 1, entries = { ["/a.md"] = { path = "/a.md", pending = 3, submitted_at = 1 } } } },
        { "a scalar retired set", { version = 1, entries = {}, retired = 3 } },
        { "a retired path with a string time", { version = 1, entries = {}, retired = { ["/s.md"] = "x" } } },
    }
    for _, case in ipairs(corrupt) do
        it("reads " .. case[1] .. " as no entries, warning once", function()
            local state = Store.parse(vim.deepcopy(case[2]), "fixture")
            assert.same({}, state.entries)
            assert.equals(1, #warnings)
        end)
    end

    it("round-trips side docs and retired paths", function()
        apply({ type = "discovered", path = "/a.side/s.md", parent = "/a.md", at = 5 }, { now = 10 })
        apply({ type = "opened", path = "/a.side/s.md" }, { now = 11 })
        local state = apply({ type = "sweep", grace = 0 }, { now = 12 })
        assert.same({ ["/a.side/s.md"] = 12 }, state.retired)
        assert.same(state, Store.load())
        assert.same({}, warnings)
    end)

    -- #367: the operator runs more than one parley Neovim; a save in one must
    -- read as the operator's in another. Each handle is its own module instance.
    it("an operator save recorded by one editor's store handle is seen by another's", function()
        local function handle()
            package.loaded["parley.attention_store"] = nil
            local fresh = require("parley.attention_store")
            package.loaded["parley.attention_store"] = Store
            return fresh
        end
        local here, there = handle(), handle()
        assert.are_not.equal(here, there)
        local done = false
        here.apply({ type = "submitted", path = "/a.md", id = "m1" }, { now = 10 }, function()
            here.apply({ type = "saved", path = "/a.side/s.md", mtime = "20.5" }, { now = 20 }, function() done = true end)
        end)
        assert(vim.wait(2000, function() return done end, 5), "apply never finished")
        local state = there.load()
        assert.same({ ["/a.side/s.md"] = "20.5" }, state.saved)
        local file = { path = "/a.side/s.md", parent = "/a.md", mtime_sec = 20, mtime_id = "20.5" }
        assert.same({}, Model.scan(state, { file }))
        assert.same({}, warnings)
    end)

    it("drops a wrongly typed save with one warning", function()
        local state = Store.parse({ version = 1, entries = {}, saved = { ["/a.side/s.md"] = 20, ["/a.side/t.md"] = "21.0" } }, "x")
        assert.same({ ["/a.side/t.md"] = "21.0" }, state.saved)
        assert.equals(1, #warnings)
    end)

    it("reads a missing or unparseable file as empty", function()
        assert.same(Model.empty(), Store.load())
        vim.fn.mkdir(Store.dir(), "p")
        vim.fn.writefile({ "{not json" }, Store.path())
        assert.same(Model.empty(), Store.load())
    end)

    it("retries a held lease and lands once it is released", function()
        vim.fn.mkdir(Store.dir(), "p")
        local held = assert(leases.acquire("attention", "store", { root = dir }))
        vim.defer_fn(function() held.release() end, 30)
        local state, err = apply(submitted("/a.md", "m1"), { now = 10, tries = 20, delay_ms = 10 })
        assert.is_nil(err)
        assert.is_truthy(state.entries["/a.md"])
        assert.same({}, warnings)
    end)

    it("reports a record lost when the lease stays held, and writes nothing", function()
        vim.fn.mkdir(Store.dir(), "p")
        local held = assert(leases.acquire("attention", "store", { root = dir }))
        local state, err = apply(submitted("/a.md", "m1"), { now = 10, tries = 3, delay_ms = 5 })
        held.release()
        assert.is_nil(state)
        assert.matches("store busy", err)
        assert.equals(1, #warnings)
        assert.matches("submitted for /a.md lost %(store busy%)", warnings[1])
        assert.equals(0, vim.fn.filereadable(Store.path()))
    end)

    it("warns when every entry is waiting and the submit is refused", function()
        local full = Model.empty()
        for i = 1, Model.LIMIT do full = Model.transition(full, submitted("/f" .. i .. ".md", "m" .. i), i) end
        vim.fn.mkdir(Store.dir(), "p")
        assert(require("parley.helper").table_to_file_atomic(full, Store.path()))
        local state, err = apply(submitted("/new.md", "x"), { now = 1000 })
        assert.equals("full", err)
        assert.is_nil(state.entries["/new.md"])
        assert.matches("/new.md was not recorded", warnings[1])
        local _, batch_err = apply({ type = "batch", events = { { type = "discovered", path = "/s.md", parent = "/p.md", at = 1 } } },
            { now = 1001 })
        assert.equals("full", batch_err)
        assert.matches("new side docs were not recorded", warnings[2])
    end)
end)
