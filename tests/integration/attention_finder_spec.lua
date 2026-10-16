-- #354 M2: the attention finder. Strategy: each user path runs against the
-- stateful fake Couch (its registry owes and folds IDs), with the picker, the
-- clock and #353's file_history seam injected, checked by what the operator
-- sees (rows) and what the store keeps; plus a probe counter for the limit
-- of 4, and observations that land after the finder closed.
local Attention = require("parley.attention")
local Store = require("parley.attention_store")
local Model = require("parley.attention_model")
local Couch = require("tests.helpers.fake_couch")
local logger = require("parley.logger")
local p = require("parley")

local root, registry, saved, warnings, now

local function await(predicate, why)
    assert.is_true(vim.wait(10000, predicate, 10), why)
end

-- Apply `event` to the store at the test clock and wait for it.
local function apply(event)
    local done
    Store.apply(event, { now = now }, function() done = true end)
    await(function() return done end, "store apply never finished")
end

-- A file on disk with a submit `id` recorded and owed by the fake Couch.
local function submitted(name, id, breadcrumb)
    local path = root .. "/" .. name
    if vim.fn.filereadable(path) == 0 then vim.fn.writefile({ "# " .. name }, path) end
    Couch.owe(registry, path, id)
    apply({ type = "submitted", path = path, id = id, breadcrumb = breadcrumb })
    return path
end

-- A picker that records what the finder showed and lets the test select.
local function fake_picker()
    local picker = { opened = nil, updates = 0, closed = false }
    picker.open = function(opts)
        picker.opened = opts
        picker.items = opts.items
        return {
            update = function(items)
                if picker.closed then return end
                picker.items, picker.updates = items, picker.updates + 1
            end,
            selected = function() return picker.items[1] end,
        }
    end
    picker.rows = function()
        return vim.tbl_map(function(item) return vim.trim(item.display:gsub("%s+%d%d:%d%d$", "")) end, picker.items or {})
    end
    return picker
end

-- Open the finder and wait until its refresh has finished.
local function open(options)
    local refreshed
    options = vim.tbl_extend("force", { store = { now = now }, home = root, on_refreshed = function() refreshed = true end }, options or {})
    Attention.open(options)
    await(function() return refreshed end, "the finder's refresh never finished")
end

-- Selecting goes through a picker that selects `path` as soon as it opens.
local function open_and_select(path, history)
    local done
    Attention.open({ picker = { open = function(opts)
        local item = vim.tbl_filter(function(i) return i.value == path end, opts.items)[1]
        assert(item, "no row for " .. path)
        vim.schedule(function() opts.on_select(item) end)
        return { update = function() end }
    end }, store = { now = now }, home = root, history = history or {}, on_selected = function() done = true end,
        run = function() end })
    await(function() return done end, "select never finished")
end

describe("attention finder", function()
    before_each(function()
        root = vim.fn.resolve(vim.fn.tempname()); vim.fn.mkdir(root, "p")
        registry = root .. "/registry.json"
        Couch.write(root, root .. "/sent", root .. "/argv")
        saved = { path = vim.env.PATH, registry = vim.env.FAKE_COUCH_REGISTRY, mode = vim.env.FAKE_COUCH_REGISTRY_MODE,
            status = vim.env.FAKE_COUCH_STATUS, state_dir = p.config.state_dir, warning = logger.warning,
            attention = p.config.attention }
        vim.env.PATH = root .. "/bin:" .. vim.env.PATH
        vim.env.FAKE_COUCH_REGISTRY, vim.env.FAKE_COUCH_REGISTRY_MODE, vim.env.FAKE_COUCH_STATUS = registry, nil, nil
        p.config.state_dir = root .. "/state"
        p.config.attention = { seen_grace_minutes = 60 }
        warnings = {}
        logger.warning = function(message) warnings[#warnings + 1] = message end
        now = 1000
    end)
    after_each(function()
        vim.env.PATH, vim.env.FAKE_COUCH_REGISTRY = saved.path, saved.registry
        vim.env.FAKE_COUCH_REGISTRY_MODE, vim.env.FAKE_COUCH_STATUS = saved.mode, saved.status
        p.config.state_dir, logger.warning, p.config.attention = saved.state_dir, saved.warning, saved.attention
        vim.cmd("silent! %bwipeout!")
        vim.fn.delete(root, "rf")
    end)

    it("lists entries at once, then shows a folded submit as answered", function()
        submitted("a.md", "m1")
        now = 1001
        local b = submitted("b.md", "m2")
        Couch.fold(registry, b, "m2")
        local picker = fake_picker()
        local shown
        Attention.open({ picker = { open = function(opts)
            shown = vim.deepcopy(opts.items)
            return picker.open(opts)
        end }, store = { now = now }, home = root, on_refreshed = function() picker.done = true end })
        await(function() return picker.done end, "refresh never finished")
        assert.equals(2, #shown)
        assert.matches("^waiting", shown[1].display)
        assert.same({ "answered   b.md  ~", "waiting    a.md  ~" }, picker.rows())
        assert.is_true(picker.updates >= 1)
    end)

    it("selecting an answered entry opens it, marks it seen and restores its breadcrumb", function()
        local a = submitted("a.md", "m1", { version = 1, paths = { "/r.md" } })
        Couch.fold(registry, a, "m1")
        open({ picker = fake_picker() })
        assert.equals("answered", Model.state_of(Store.load().entries[a]))
        local restored
        now = 2000
        open_and_select(a, { restore = function(win, value) restored = { win, value }; return true end })
        assert.equals(a, vim.api.nvim_buf_get_name(0))
        assert.equals("seen", Model.state_of(Store.load().entries[a]))
        assert.same({ vim.api.nvim_get_current_win(), { version = 1, paths = { "/r.md" } } }, restored)
        assert.same({}, warnings)
    end)

    it("a refused restore keeps the ordinary open and shows the reason", function()
        local a = submitted("a.md", "m1", { version = 1 })
        open_and_select(a, { restore = function() return false, "stale breadcrumb" end })
        assert.equals(a, vim.api.nvim_buf_get_name(0))
        assert.matches("breadcrumb not restored: stale breadcrumb", warnings[#warnings])
    end)

    it("selecting a waiting entry opens it and leaves it waiting", function()
        local a = submitted("a.md", "m1")
        open_and_select(a)
        assert.equals(a, vim.api.nvim_buf_get_name(0))
        assert.equals("waiting", Model.state_of(Store.load().entries[a]))
    end)

    it("a missing file is reported and nothing opens", function()
        local a = submitted("a.md", "m1")
        local before = vim.api.nvim_get_current_buf()
        os.remove(a)
        open_and_select(a)
        assert.equals(before, vim.api.nvim_get_current_buf())
        assert.matches("no longer exists", warnings[#warnings])
    end)

    it("a probe Couch cannot answer marks the row ? and never reads as answered", function()
        local a = submitted("a.md", "m1")
        Couch.fold(registry, a, "m1")
        vim.env.FAKE_COUCH_REGISTRY_MODE = "unsupported"
        local picker = fake_picker()
        open({ picker = picker })
        assert.same({ "waiting  ? a.md  ~" }, picker.rows())
        -- No ledger for the file at all is not evidence either.
        vim.env.FAKE_COUCH_REGISTRY_MODE = nil
        local b = root .. "/b.md"
        vim.fn.writefile({ "# b" }, b)
        apply({ type = "submitted", path = b, id = "m9" })
        picker = fake_picker()
        open({ picker = picker })
        assert.equals("waiting", Model.state_of(Store.load().entries[b]))
        assert.equals("no Couch ledger for this file", Store.load().entries[b].unknown)
    end)

    -- ARCH-ORDER, through the glue: a probe that started before a newer submit
    -- returns without that submit's ID, and must not answer it.
    it("a probe that started before a newer submit leaves that submit waiting", function()
        local a = submitted("a.md", "m1")
        local held
        local run = function(argv, cb)
            held = function() require("parley.couch").query(argv, cb) end
        end
        local refreshed
        Attention.refresh({ run = run, store = { now = now } }, nil, function() refreshed = true end)
        await(function() return held ~= nil end, "the probe never started")
        -- While it runs: the operator submits again, and the agent folds the first.
        now = now + 1
        Couch.owe(registry, a, "m2")
        apply({ type = "submitted", path = a, id = "m2" })
        Couch.fold(registry, a, "m1")
        Couch.fold(registry, a, "m2") -- even with m2 gone too, the probe predates it
        held()
        await(function() return refreshed end, "the probe never finished")
        local entry = Store.load().entries[a]
        assert.equals("waiting", Model.state_of(entry))
        assert.same({ "m2" }, vim.tbl_keys(entry.pending))
    end)

    it("runs at most 4 probes at once", function()
        for i = 1, 9 do submitted(("f%d.md"):format(i), "m" .. i) end
        local active, peak = 0, 0
        local run = function(argv, cb)
            active = active + 1
            peak = math.max(peak, active)
            return require("parley.couch").query(argv, function(data)
                active = active - 1
                cb(data)
            end)
        end
        open({ picker = fake_picker(), run = run })
        assert.equals(4, peak)
        assert.equals(0, active)
    end)

    it("a seen entry leaves after the grace, on the next open", function()
        local a = submitted("a.md", "m1")
        Couch.fold(registry, a, "m1")
        open({ picker = fake_picker() })
        apply({ type = "opened", path = a })
        now = now + 3599
        local picker = fake_picker()
        open({ picker = picker })
        assert.same({ "seen       a.md  ~" }, picker.rows())
        now = now + 1
        picker = fake_picker()
        open({ picker = picker })
        assert.same({}, picker.rows())
    end)

    it("an observation landing after the finder closed still reaches the store", function()
        local a = submitted("a.md", "m1")
        Couch.fold(registry, a, "m1")
        local picker = fake_picker()
        picker.closed = true -- closed before any probe returned
        open({ picker = picker })
        assert.equals(0, picker.updates)
        assert.equals("answered", Model.state_of(Store.load().entries[a]))
    end)

    it("is bound to <M-u> and :ParleyAttention", function()
        local registry_entries = require("parley.keybinding_registry").entries
        local entry = vim.tbl_filter(function(e) return e.id == "attention" end, registry_entries)[1]
        assert.equals("<M-u>", entry.default_key)
        assert.equals("<M-u>", require("parley.config").global_shortcut_attention.shortcut)
        -- setup() makes a :Parley<Name> command of every M.cmd entry.
        assert.equals("function", type(p.cmd.Attention))
    end)
end)
