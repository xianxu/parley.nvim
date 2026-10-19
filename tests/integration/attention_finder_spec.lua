-- #354 M2: the attention finder. Strategy: each user path runs against the
-- stateful fake Couch (its registry owes and folds IDs), with the picker, the
-- clock and #353's file_history seam injected, checked by what the operator
-- sees (rows) and what the store keeps; plus a probe counter for the limit
-- of 4, and observations that land after the finder closed.
local arrival = require("tests.helpers.arrival")
local Attention = require("parley.attention")
local Store = require("parley.attention_store")
local Model = require("parley.attention_model")
local Couch = require("tests.helpers.fake_couch")
local logger = require("parley.logger")
local p = require("parley")

local root, registry, saved, warnings, now

local function await(predicate, why)
    local ok = vim.wait(arrival.MS, predicate, 10)
    assert.is_true(ok, type(why) == "function" and why() or why)
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
            set_title = function(title) picker.title = title end,
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
            attention = p.config.attention, scope = vim.env.COUCH_THREAD_SCOPE, tag = vim.env.COUCH_THREAD_TAG,
            actors = vim.env.FAKE_COUCH_ACTORS }
        vim.env.PATH = root .. "/bin:" .. vim.env.PATH
        vim.env.FAKE_COUCH_REGISTRY, vim.env.FAKE_COUCH_REGISTRY_MODE, vim.env.FAKE_COUCH_STATUS = registry, nil, nil
        p.config.state_dir = root .. "/state"
        p.config.attention = { seen_grace_minutes = 60 }
        vim.env.COUCH_THREAD_SCOPE, vim.env.COUCH_THREAD_TAG = nil, nil
        warnings = {}
        logger.warning = function(message) warnings[#warnings + 1] = message end
        now = 1000
    end)
    after_each(function()
        vim.env.PATH, vim.env.FAKE_COUCH_REGISTRY = saved.path, saved.registry
        vim.env.FAKE_COUCH_REGISTRY_MODE, vim.env.FAKE_COUCH_STATUS = saved.mode, saved.status
        p.config.state_dir, logger.warning, p.config.attention = saved.state_dir, saved.warning, saved.attention
        vim.env.COUCH_THREAD_SCOPE, vim.env.COUCH_THREAD_TAG, vim.env.FAKE_COUCH_ACTORS = saved.scope, saved.tag, saved.actors
        vim.cmd("silent! %bwipeout!")
        vim.fn.delete(root, "rf")
    end)

    it("focuses the oldest scoped unread child, keeps tree order and scrolls it into view (#392)", function()
        local state = Model.empty()
        local function add(name, submitted_at, answered_at, slot, parent)
            local path = root .. "/" .. name
            vim.fn.writefile({ "body" }, path)
            state = Model.transition(state, { type = "submitted", path = path, id = name, slot = slot }, submitted_at)
            if answered_at then state = Model.transition(state,
                { type = "observed", path = path, probed_ids = { name }, owed_ids = {} }, answered_at) end
            if parent then state.entries[path].kind, state.entries[path].parent = "side", parent end
            return path
        end
        add("newer.md", 900, 800, "ops:0")
        add("outside.md", 850, 100, "echo:0")
        for i = 1, 24 do add("waiting" .. i .. ".md", 900 - i, nil, "ops:0") end
        local parent = add("parent.md", 40, nil, "ops:0")
        add("child.md", 30, 200, "ops:0", parent)
        local seen = add("seen.md", 20, 50, "ops:0")
        state = Model.transition(state, { type = "opened", path = seen }, 60)
        vim.fn.mkdir(vim.fn.fnamemodify(Store.path(), ":h"), "p")
        assert(require("parley.helper").table_to_file_atomic(state, Store.path()))
        local held = {}
        Attention.open({ store = { now = now }, own_slot = function(cb) cb({}, { Binding = { Slot = "ops:0" } }) end,
            run = function(argv, cb) held[argv[#argv]] = cb end })
        local prompt = vim.api.nvim_get_current_buf()
        local results
        for _, win in ipairs(vim.api.nvim_list_wins()) do
            if vim.api.nvim_win_get_config(win).relative ~= "" and vim.bo[vim.api.nvim_win_get_buf(win)].buftype ~= "prompt" then
                results = win
            end
        end
        assert(results, "finder results did not open")
        local function selected()
            local row = vim.api.nvim_win_get_cursor(results)[1]
            return vim.api.nvim_buf_get_lines(vim.api.nvim_win_get_buf(results), row - 1, row, false)[1]
        end
        local function visible()
            local view = vim.api.nvim_win_call(results, vim.fn.winsaveview)
            local row = vim.api.nvim_win_get_cursor(results)[1]
            assert.is_true(row >= view.topline and row < view.topline + vim.api.nvim_win_get_height(results))
        end
        local function toggle()
            vim.api.nvim_buf_call(prompt, function() vim.fn.maparg("<C-a>", "i", false, true).callback() end)
        end
        assert.truthy(selected():find("child.md", 1, true)); visible()
        local lines = vim.api.nvim_buf_get_lines(vim.api.nvim_win_get_buf(results), 0, -1, false)
        assert.truthy(lines[1]:find("newer.md", 1, true))
        assert.truthy(lines[#lines - 2]:find("parent.md", 1, true))
        assert.truthy(lines[#lines - 1]:find("child.md", 1, true))
        toggle(); assert.truthy(selected():find("outside.md", 1, true)); visible()
        toggle(); assert.truthy(selected():find("child.md", 1, true)); visible()
        -- An operator filter wins over the opening preference in either scope.
        vim.api.nvim_buf_set_lines(prompt, 0, -1, false, { "> newer" })
        vim.api.nvim_exec_autocmds("TextChanged", { buffer = prompt })
        assert.truthy(selected():find("newer.md", 1, true))
        toggle(); assert.truthy(selected():find("newer.md", 1, true))
        assert.equals("> newer", vim.api.nvim_buf_get_lines(prompt, 0, 1, false)[1])
        local pending_path, reply = next(held)
        assert(reply)({ Status = { Owed = {} } })
        await(function() return Model.state_of(Store.load().entries[pending_path]) == "answered" end, "probe never landed")
        assert.truthy(selected():find("newer.md", 1, true))
        vim.api.nvim_buf_call(prompt, function() vim.fn.maparg("<Esc>", "n", false, true).callback() end)
    end)

    it("toggles current/all scope and keeps that scope after late probe updates", function()
        local a, b, legacy = submitted("here.md", "m1"), submitted("there.md", "m2"), submitted("legacy.md", "m3")
        apply({ type = "submitted", path = a, id = "m1", slot = "ops:0" })
        apply({ type = "submitted", path = b, id = "m2", slot = "echo:0" })
        local picker, callbacks = fake_picker(), {}
        Attention.open({ picker = picker, store = { now = now },
            own_slot = function(cb) cb({}, { Binding = { Slot = "ops:0" } }) end,
            run = function(argv, cb) callbacks[argv[#argv]] = cb end })
        await(function() return picker.opened and callbacks[a] and callbacks[b] and callbacks[legacy] end, "finder did not open/probe")
        local function paths() return vim.tbl_map(function(i) return i.value end, picker.items) end
        assert.same({ a, legacy }, paths())
        assert.matches("ops:0", picker.opened.title, 1, true)
        local toggle = picker.opened.mappings[1]
        assert.same({ "<C-a>" }, toggle.key)
        toggle.fn()
        assert.same({ a, legacy, b }, paths())
        assert.equals("Attention — all slots", picker.title)
        callbacks[b]({ Status = { Owed = {} } })
        await(function() return Model.state_of(Store.load().entries[b]) == "answered" end, "probe did not land")
        assert.equals(3, #picker.items)
        toggle.fn()
        assert.equals("Attention — ops:0", picker.title)
        assert.same({ a, legacy }, paths())
        callbacks[a]({ Status = { Owed = {} } })
        callbacks[legacy]({ Status = { Owed = {} } })
        await(function() return Model.state_of(Store.load().entries[a]) == "answered" end, "late probe did not land")
        assert.same({ a, legacy }, paths())
    end)

    it("shows all outside Couch and warns when a live pane cannot be resolved", function()
        local a, b = submitted("a.md", "m1"), submitted("b.md", "m2")
        apply({ type = "submitted", path = b, id = "m2", slot = "echo:0" })
        local picker = fake_picker()
        open({ picker = picker, own_slot = function(cb) cb(nil) end })
        assert.equals(2, #picker.items)
        assert.equals(0, #picker.opened.mappings)
        open({ picker = picker, own_slot = function(cb) cb({}, nil) end })
        assert.equals(2, #picker.items)
        assert.matches("slot unavailable", warnings[#warnings])
        assert.is_truthy(Store.load().entries[a])
    end)

    it("resolves the pane with real Couch queries and installs the real picker toggle", function()
        local a, b = submitted("+++here.md", "m1"), submitted("+++there.md", "m2")
        apply({ type = "submitted", path = a, id = "m1", slot = "ops:0" })
        apply({ type = "submitted", path = b, id = "m2", slot = "echo:0" })
        vim.env.COUCH_THREAD_SCOPE, vim.env.COUCH_THREAD_TAG = "scope-attention", "tag-attention"
        vim.env.FAKE_COUCH_ACTORS = vim.json.encode({ Code = "ok", Actors = {
            { Binding = { Slot = "echo:0", Scope = "other", Tag = "other" } },
            { Binding = { Slot = "ops:0", Scope = "scope-attention", Tag = "tag-attention" } },
        } })
        local refreshed
        Attention.open({ store = { now = now }, on_refreshed = function() refreshed = true end })
        await(function() return refreshed end, "real finder never resolved/refreshed")
        local prompt = vim.api.nvim_get_current_buf()
        assert.equals("prompt", vim.bo[prompt].buftype)
        local function rows()
            for _, win in ipairs(vim.api.nvim_list_wins()) do
                local config = vim.api.nvim_win_get_config(win)
                local buf = vim.api.nvim_win_get_buf(win)
                if config.relative ~= "" and vim.bo[buf].buftype ~= "prompt" then
                    return vim.tbl_filter(function(line) return line:match("%S") end,
                        vim.api.nvim_buf_get_lines(buf, 0, -1, false)), config.title
                end
            end
        end
        assert.equals(1, #rows())
        vim.api.nvim_buf_set_lines(prompt, 0, -1, false, { "> +++" })
        vim.api.nvim_exec_autocmds("TextChanged", { buffer = prompt })
        local toggle = vim.api.nvim_buf_call(prompt, function() return vim.fn.maparg("<C-a>", "i", false, true).callback end)
        assert.is_function(toggle)
        toggle()
        assert.equals(2, #rows())
        assert.equals("> +++", vim.api.nvim_buf_get_lines(prompt, 0, 1, false)[1])
        toggle()
        assert.equals(1, #rows())
        vim.api.nvim_buf_call(prompt, function() vim.fn.maparg("<Esc>", "n", false, true).callback() end)
    end)

    it("searches nested children with ancestors and keeps scope through late updates", function()
        local parent, child, leaf, other = submitted("parent.md", "p"), submitted("child.md", "c"),
            submitted("+++leaf.md", "l"), submitted("unrelated.md", "o")
        -- Same stored identity/state as discovered side docs, plus one owed leaf for repaint.
        local state = Store.load()
        state.entries[parent].slot, state.entries[child].slot, state.entries[leaf].slot = "ops:0", "ops:0", "ops:0"
        state.entries[child].kind, state.entries[child].parent = "side", parent
        state.entries[leaf].kind, state.entries[leaf].parent = "side", child
        state.entries[other].slot = "echo:0"
        assert(require("parley.helper").table_to_file_atomic(state, Store.path()))
        local held, refreshed, opened = {}, false, nil
        Attention.open({ store = { now = now }, own_slot = function(cb) cb({}, { Binding = { Slot = "ops:0" } }) end,
            run = function(argv, cb) held[argv[#argv]] = cb end, on_refreshed = function() refreshed = true end,
            on_selected = function() opened = vim.api.nvim_buf_get_name(0) end })
        local prompt = vim.api.nvim_get_current_buf()
        local function rows()
            for _, win in ipairs(vim.api.nvim_list_wins()) do
                local cfg, buf = vim.api.nvim_win_get_config(win), vim.api.nvim_win_get_buf(win)
                if cfg.relative ~= "" and vim.bo[buf].buftype ~= "prompt" then
                    return vim.tbl_filter(function(l) return l:match("%S") end, vim.api.nvim_buf_get_lines(buf, 0, -1, false))
                end
            end
        end
        assert.equals(3, #rows())
        vim.api.nvim_buf_set_lines(prompt, 0, -1, false, { "> +++" })
        vim.api.nvim_exec_autocmds("TextChanged", { buffer = prompt })
        assert.equals(3, #rows())
        assert.matches("parent.md", rows()[1])
        assert.matches("child.md", rows()[2])
        assert.matches("^     waiting", rows()[3]) -- picker adds one selection column
        for _ = 1, 2 do
            vim.api.nvim_buf_call(prompt, function() vim.fn.maparg("<Down>", "i", false, true).callback() end)
        end
        vim.api.nvim_buf_call(prompt, function() vim.fn.maparg("<C-a>", "i", false, true).callback() end)
        assert.equals(3, #rows()) -- unrelated row still does not match
        for _, cb in pairs(held) do cb({ Status = { Owed = {} } }) end
        await(function() return refreshed end, "tree repaint did not finish")
        assert.equals(3, #rows())
        assert.equals("> +++", vim.api.nvim_buf_get_lines(prompt, 0, 1, false)[1])
        vim.api.nvim_buf_call(prompt, function() vim.fn.maparg("<CR>", "i", false, true).callback() end)
        await(function() return opened ~= nil end, "selected tree child never opened")
        assert.equals(leaf, opened)
    end)

    it("promotes a child when scope hides its parent and reattaches it in all slots", function()
        local parent, child = submitted("parent.md", "p"), submitted("child.md", "c")
        local state = Store.load()
        state.entries[parent].slot = "echo:0"
        state.entries[child].slot, state.entries[child].kind, state.entries[child].parent = "ops:0", "side", parent
        assert(require("parley.helper").table_to_file_atomic(state, Store.path()))
        local picker = fake_picker()
        open({ picker = picker, own_slot = function(cb) cb({}, { Binding = { Slot = "ops:0" } }) end })
        assert.equals(1, #picker.items)
        assert.matches("^waiting", picker.items[1].display)
        picker.opened.mappings[1].fn()
        assert.equals(parent, picker.items[1].value)
        assert.equals(child, picker.items[2].value)
        assert.matches("^  waiting", picker.items[2].display)
        picker.opened.mappings[1].fn()
        assert.equals(1, #picker.items)
        assert.matches("^waiting", picker.items[1].display)
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

    -- The real float_picker: a typed filter and the selected row survive a
    -- repaint landing mid-typing, and Enter opens the row the operator chose.
    it("uses a filter fixture that cannot typo-match a temporary path", function()
        local picker = require("parley.float_picker")
        -- The old q+ fixture typo-matches a random path token starting q.
        assert.is_not_nil(picker._fuzzy_score("q+", "beta.md /tmp/qzfixture"))
        assert.is_nil(picker._fuzzy_score("+++", "beta.md /tmp/qzfixture"))
        assert.is_not_nil(picker._fuzzy_score("+++", "+++alpha.md /tmp/qzfixture"))
    end)

    it("keeps the typed filter and the selected row across a live repaint", function()
        local alpha = submitted("+++alpha.md", "m1")
        now = now + 1
        local alto = submitted("+++alto.md", "m2")
        now = now + 1
        submitted("qzbeta.md", "m3") -- adversarial: the old q+ query typo-matched this token
        local held = {}
        local opened
        Attention.open({ store = { now = now }, home = root, history = {},
            run = function(argv, cb) held[#held + 1] = function() require("parley.couch").query(argv, cb) end end,
            on_selected = function() opened = vim.api.nvim_buf_get_name(0) end })
        local function float(kind)
            for _, win in ipairs(vim.api.nvim_list_wins()) do
                local config = vim.api.nvim_win_get_config(win)
                local buf = vim.api.nvim_win_get_buf(win)
                if config.relative ~= "" and (vim.bo[buf].buftype == "prompt") == (kind == "prompt") then return win, buf end
            end
        end
        local function results()
            local _, buf = float("results")
            return vim.tbl_filter(function(line) return line:match("%S") end, vim.api.nvim_buf_get_lines(buf, 0, -1, false))
        end
        local _, prompt = float("prompt")
        assert(prompt, "the real picker did not open")
        -- Punctuation-only +++ cannot prefix-match word tokens; no temp path has +.
        vim.api.nvim_buf_set_lines(prompt, 0, -1, false, { "> +++" })
        vim.api.nvim_exec_autocmds("TextChanged", { buffer = prompt })
        await(function() return #results() == 2 end, function()
            return "typeahead did not filter: " .. vim.inspect({ prompt = vim.api.nvim_buf_get_lines(prompt, 0, -1, false),
                rows = results(), mode = vim.api.nvim_get_mode().mode })
        end)
        -- Move to the second row (+++alpha.md, the older submit).
        vim.api.nvim_buf_call(prompt, function() vim.fn.maparg("<Down>", "i", false, true).callback() end)
        -- Meanwhile another editor submits a newer matching file (a row lands
        -- above the cursor on the next repaint) and the agent folds +++alto.md.
        now = now + 1
        submitted("+++new.md", "m4")
        Couch.fold(registry, alto, "m2")
        for _, release in ipairs(held) do release() end
        await(function() return vim.iter(results()):any(function(l) return l:find("answered", 1, true) ~= nil end) end,
            "the fold never repainted the open picker")
        assert.equals("> +++", vim.api.nvim_buf_get_lines(prompt, 0, 1, false)[1])
        assert.equals(3, #results())
        vim.api.nvim_buf_call(prompt, function() vim.fn.maparg("<CR>", "i", false, true).callback() end)
        await(function() return opened ~= nil end, "Enter opened nothing")
        assert.equals(alpha, opened)
    end)

    it("with the real picker closed, a late observation still reaches the store", function()
        local a = submitted("a.md", "m1")
        local held, refreshed
        Attention.open({ store = { now = now }, home = root, history = {},
            run = function(argv, cb) held = function() require("parley.couch").query(argv, cb) end end,
            on_refreshed = function() refreshed = true end })
        await(function() return held ~= nil end, "the probe never started")
        local prompt = vim.api.nvim_get_current_buf()
        assert.equals("prompt", vim.bo[prompt].buftype)
        vim.api.nvim_buf_call(prompt, function() vim.fn.maparg("<Esc>", "n", false, true).callback() end)
        await(function() return not vim.api.nvim_buf_is_valid(prompt) or vim.fn.bufwinid(prompt) == -1 end,
            "the picker never closed")
        Couch.fold(registry, a, "m1")
        held()
        await(function() return refreshed end, "the late probe never finished")
        assert.equals("answered", Model.state_of(Store.load().entries[a]))
    end)

    it("a probe that outlives its timeout reads as failed, never as answered", function()
        local a = submitted("a.md", "m1")
        Couch.fold(registry, a, "m1")
        vim.env.FAKE_COUCH_REGISTRY_MODE = "delay" -- the fake sleeps 1 s
        local picker = fake_picker()
        open({ picker = picker, timeout_ms = 200 })
        assert.same({ "waiting  ? a.md  ~" }, picker.rows())
        assert.equals("couch status unavailable", Store.load().entries[a].unknown)
    end)

    it("a probe that raises as it starts reads as couch unavailable", function()
        local a = submitted("a.md", "m1")
        open({ picker = fake_picker(), run = function() error("ENOENT: couch") end })
        assert.equals("waiting", Model.state_of(Store.load().entries[a]))
        assert.equals("couch status unavailable", Store.load().entries[a].unknown)
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

    it("is bound to <M-Space> and <C-y><Space>, and :ParleyAttention", function()
        local registry_entries = require("parley.keybinding_registry")
        local entry = vim.tbl_filter(function(e) return e.id == "attention" end, registry_entries.entries)[1]
        assert.same({ "<M-Space>", "<C-y><Space>" }, entry.default_key)
        assert.same({ "<M-Space>", "<C-y><Space>" }, require("parley.config").global_shortcut_attention.shortcut)
        -- The mappings themselves, as setup() registers them.
        local opened = 0
        registry_entries.register_global({ "global" }, require("parley.config"), { attention = function() opened = opened + 1 end })
        for _, key in ipairs({ "<M-Space>", "<C-y><Space>" }) do
            for _, mode in ipairs({ "n", "i" }) do
                local mapping = vim.fn.maparg(key, mode, false, true)
                assert.is_function(mapping.callback, ("no %s mapping in mode %s"):format(key, mode))
                mapping.callback()
            end
        end
        assert.equals(4, opened)
        -- setup() makes a :Parley<Name> command of every M.cmd entry.
        assert.equals("function", type(p.cmd.Attention))
    end)

    it("<C-y><Space> with the completion popup showing accepts it and types a space", function()
        local opened = 0
        require("parley.keybinding_registry").register_global({ "global" }, require("parley.config"),
            { attention = function() opened = opened + 1 end })
        local buf = vim.api.nvim_create_buf(true, true)
        vim.api.nvim_set_current_buf(buf)
        vim.api.nvim_buf_set_lines(buf, 0, -1, false, { "alphabet", "" })
        vim.api.nvim_win_set_cursor(0, { 2, 0 })
        local completeopt = vim.o.completeopt
        vim.o.completeopt = "menuone"
        -- Keyword completion opens the popup on "alphabet"; <C-y><Space> accepts it, then a space.
        vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes("Aal<C-n><C-y><Space>x<Esc>", true, false, true), "mx", false)
        vim.o.completeopt = completeopt
        assert.equals("alphabet x", vim.api.nvim_buf_get_lines(buf, 1, 2, false)[1])
        assert.equals(0, opened)
        -- Without a popup, the same keys open the finder.
        vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes("A<C-y><Space>", true, false, true), "mx", false)
        assert.equals(1, opened)
        vim.cmd("stopinsert")
    end)
end)

describe("attention finder: side docs the agent wrote", function()
    local function side(parent, name, lines, mtime)
        local folder = vim.fn.fnamemodify(parent, ":r") .. ".side"
        vim.fn.mkdir(folder, "p")
        local path = folder .. "/" .. name
        vim.fn.writefile(lines, path)
        if mtime then assert((vim.uv or vim.loop).fs_utime(path, mtime, mtime)) end
        return path
    end
    local DOC = { "---", "type: side-doc", "parent: ../a.md", "---", "", "# Answer" }

    before_each(function()
        root = vim.fn.resolve(vim.fn.tempname()); vim.fn.mkdir(root, "p")
        registry = root .. "/registry.json"
        Couch.write(root, root .. "/sent", root .. "/argv")
        saved = { path = vim.env.PATH, registry = vim.env.FAKE_COUCH_REGISTRY, state_dir = p.config.state_dir,
            attention = p.config.attention }
        vim.env.PATH = root .. "/bin:" .. vim.env.PATH
        vim.env.FAKE_COUCH_REGISTRY = registry
        p.config.state_dir = root .. "/state"
        p.config.attention = { seen_grace_minutes = 60 }
        now = 1000
    end)
    after_each(function()
        vim.env.PATH, vim.env.FAKE_COUCH_REGISTRY = saved.path, saved.registry
        p.config.state_dir, p.config.attention = saved.state_dir, saved.attention
        vim.fn.delete(root, "rf")
    end)

    it("lists a new side doc as answered, leaving by the same rule, and never brings it back", function()
        local a = submitted("a.md", "m1")
        local doc = side(a, "01-answer.md", DOC, 2000)
        side(a, "notes.md", { "# not a side doc" }, 2000)
        side(a, "00-old.md", DOC, 900) -- written before a.md entered the finder
        now = 2100
        local picker = fake_picker()
        open({ picker = picker })
        assert.same({ "waiting    a.md  ~", "answered ↳ 01-answer.md  ~/a.side" }, picker.rows())
        assert.equals(a, Store.load().entries[doc].parent)
        -- Opened from the finder: seen; past the grace: gone, and not rediscovered.
        apply({ type = "opened", path = doc })
        now = now + 3600
        picker = fake_picker()
        open({ picker = picker })
        assert.same({ "waiting    a.md  ~" }, picker.rows())
        assert.is_truthy(Store.load().retired[doc])
    end)

    it("finds a side doc's own side docs on the next open", function()
        local a = submitted("a.md", "m1")
        local doc = side(a, "01.md", DOC, 2000)
        local nested = side(doc, "02.md", DOC, 2001)
        now = 2100
        open({ picker = fake_picker() })
        assert.is_nil(Store.load().entries[nested])
        local picker = fake_picker()
        open({ picker = picker })
        assert.is_truthy(Store.load().entries[nested])
        assert.equals(doc, Store.load().entries[nested].parent)
    end)

    it("an agent rewrite brings a seen or retired side doc back; the operator's own save does not (#367)", function()
        local clock = Attention.clock
        Attention.clock = function() return now end
        local a = submitted("a.md", "m1")
        local doc = side(a, "01-answer.md", DOC, 2000)
        now = 2100
        open({ picker = fake_picker() })
        apply({ type = "opened", path = doc })
        -- The operator edits and saves the seen side doc in this editor.
        Attention.setup()
        vim.cmd("edit " .. vim.fn.fnameescape(doc))
        vim.api.nvim_buf_set_lines(0, -1, -1, false, { "my note" })
        vim.cmd("silent write")
        await(function() return Store.load().saved[doc] ~= nil end, "the save was never recorded")
        vim.cmd("enew")
        local picker = fake_picker()
        open({ picker = picker })
        assert.same({ "waiting    a.md  ~", "seen     ↳ 01-answer.md  ~/a.side" }, picker.rows())
        -- The agent rewrites it: answered again.
        side(a, "01-answer.md", DOC, 3000)
        picker = fake_picker()
        open({ picker = picker })
        assert.same({ "waiting    a.md  ~", "answered ↳ 01-answer.md  ~/a.side" }, picker.rows())
        -- Seen, then past the grace: retired; a later agent write brings it back.
        now = 3100
        apply({ type = "opened", path = doc })
        now = now + 3600
        open({ picker = fake_picker() })
        assert.is_truthy(Store.load().retired[doc])
        side(a, "01-answer.md", DOC, now + 10)
        picker = fake_picker()
        open({ picker = picker })
        assert.same({ "waiting    a.md  ~", "answered ↳ 01-answer.md  ~/a.side" }, picker.rows())
        assert.is_nil(Store.load().retired[doc])
        Attention.clock = clock
        pcall(vim.api.nvim_del_augroup_by_name, "ParleyAttentionViews")
        vim.cmd("silent! %bwipeout!")
    end)

    it("reads the side-doc type from frontmatter only", function()
        assert.is_true(Attention.is_side_doc({ "---", "type: side-doc", "---" }))
        assert.is_true(Attention.is_side_doc({ "---", "parent: x", 'type: "side-doc"', "---" }))
        assert.is_true(Attention.is_side_doc({ "---", "Type: side-doc # written by the agent", "---" }))
        assert.is_false(Attention.is_side_doc({ "---", "type: side-doc" })) -- an unclosed block
        assert.is_false(Attention.is_side_doc({ "---", "type: pensive", "---" }))
        assert.is_false(Attention.is_side_doc({ "# title", "type: side-doc" }))
        assert.is_false(Attention.is_side_doc({ "---", "title: x", "---", "type: side-doc" }))
        assert.is_false(Attention.is_side_doc({}))
    end)
end)

describe("attention finder: seen however the operator looks", function()
    before_each(function()
        root = vim.fn.resolve(vim.fn.tempname()); vim.fn.mkdir(root, "p")
        registry = root .. "/registry.json"
        Couch.write(root, root .. "/sent", root .. "/argv")
        saved = { path = vim.env.PATH, registry = vim.env.FAKE_COUCH_REGISTRY, state_dir = p.config.state_dir,
            attention = p.config.attention, clock = Attention.clock }
        vim.env.PATH = root .. "/bin:" .. vim.env.PATH
        vim.env.FAKE_COUCH_REGISTRY = registry
        p.config.state_dir = root .. "/state"
        p.config.attention = { seen_grace_minutes = 60 }
        now = 1000
        Attention.clock = function() return now end
    end)
    after_each(function()
        pcall(vim.api.nvim_del_augroup_by_name, "ParleyAttentionViews")
        vim.env.PATH, vim.env.FAKE_COUCH_REGISTRY = saved.path, saved.registry
        p.config.state_dir, p.config.attention, Attention.clock = saved.state_dir, saved.attention, saved.clock
        vim.cmd("silent! %bwipeout!")
        vim.fn.delete(root, "rf")
    end)

    -- An answered entry for a fresh file, known to this editor's view tracking.
    local function answered(name)
        local path = submitted(name, "m1")
        Couch.fold(registry, path, "m1")
        now = now + 10
        open({ picker = fake_picker() }) -- the probe answers it at `now`
        assert.equals("answered", Model.state_of(Store.load().entries[path]))
        Attention.setup()
        return path
    end

    it("focusing a window on an answered file makes it seen", function()
        local a = answered("a.md")
        now = now + 1
        vim.cmd("edit " .. vim.fn.fnameescape(a)) -- BufEnter
        await(function() return Model.state_of(Store.load().entries[a]) == "seen" end, "the view never counted")
        assert.equals(now, Store.load().entries[a].seen_at)
    end)

    it("moving the cursor in the current window counts, once the answer has arrived", function()
        local a = root .. "/a.md"
        vim.fn.writefile({ "# a", "two" }, a)
        vim.cmd("edit " .. vim.fn.fnameescape(a))
        local path = answered("a.md") -- answered while the file is already current
        now = now + 1
        vim.api.nvim_exec_autocmds("CursorMoved", { buffer = vim.api.nvim_get_current_buf() })
        await(function() return Model.state_of(Store.load().entries[path]) == "seen" end, "the cursor move never counted")
    end)

    -- An answered file shown in a window that is not current, put there
    -- without firing the view autocmds; returns that window.
    local function beside(path)
        vim.cmd("noautocmd vsplit " .. vim.fn.fnameescape(path))
        local win = vim.api.nvim_get_current_win()
        vim.cmd("noautocmd wincmd p")
        return win
    end

    it("a scroll counts for the current window only, not one beside it", function()
        local a = root .. "/a.md"
        vim.fn.writefile({ "# a" }, a)
        vim.cmd("edit " .. vim.fn.fnameescape(a))
        local path = answered("a.md") -- answered while the file is already current
        now = now + 1
        local other = root .. "/other.md"
        vim.fn.writefile({ "# other" }, other)
        local win = beside(other)
        vim.api.nvim_exec_autocmds("WinScrolled", { pattern = tostring(win) })
        vim.wait(100)
        assert.equals("answered", Model.state_of(Store.load().entries[path]))
        vim.api.nvim_exec_autocmds("WinScrolled", { pattern = tostring(vim.api.nvim_get_current_win()) })
        await(function() return Model.state_of(Store.load().entries[path]) == "seen" end, "the scroll never counted")
    end)

    it("entering a window that already shows an answered file makes it seen", function()
        local a = answered("a.md")
        now = now + 1
        local win = beside(a)
        vim.api.nvim_set_current_win(win) -- WinEnter
        await(function() return Model.state_of(Store.load().entries[a]) == "seen" end, "the window enter never counted")
    end)

    it("viewing a waiting file changes nothing", function()
        local a = submitted("a.md", "m1")
        Attention.setup()
        vim.cmd("edit " .. vim.fn.fnameescape(a))
        vim.wait(100)
        assert.equals("waiting", Model.state_of(Store.load().entries[a]))
    end)

    it("the finder leaves out the file in the current window", function()
        local a = submitted("a.md", "m1")
        now = now + 1
        submitted("b.md", "m2")
        vim.cmd("edit " .. vim.fn.fnameescape(a))
        local picker = fake_picker()
        open({ picker = picker })
        assert.same({ "waiting    b.md  ~" }, picker.rows())
    end)
end)
