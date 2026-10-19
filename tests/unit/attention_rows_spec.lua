-- #354 M2: the attention finder's rows. Pure: entries in, float_picker items out.
local Rows = require("parley.attention_rows")
local Model = require("parley.attention_model")

local function at(t) return ("%02d:%02d"):format(math.floor(t / 60), t % 60) end
local options = { home = "/home/me", clock = at }

local function entry(path, fields)
    return vim.tbl_extend("force", { path = path, pending = {}, submitted_at = 600 }, fields or {})
end

describe("attention_rows.items", function()
    -- Strategy: one row per state, checked whole (text, highlight span, value,
    -- search text); then the order and the unknown marker.
    local cases = {
        { "waiting", entry("/home/me/w/tl.md", { pending = { m1 = 600 } }), "waiting    tl.md  ~/w  10:00", "ParleyAttentionWaiting" },
        { "answered", entry("/srv/a.md", { answered_at = 700 }), "answered   a.md  /srv  10:00", "ParleyAttentionAnswered" },
        { "seen", entry("/srv/s.md", { answered_at = 700, seen_at = 800 }), "seen       s.md  /srv  10:00", "ParleyAttentionSeen" },
        { "unknown", entry("/srv/u.md", { pending = { m1 = 600 }, unknown = "unsupported" }), "waiting  ? u.md  /srv  10:00", "ParleyAttentionWaiting" },
        { "side", entry("/srv/a.side/s.md", { answered_at = 600, kind = "side", parent = "/srv/a.md" }), "answered ↳ s.md  /srv/a.side  10:00", "ParleyAttentionAnswered" },
    }
    for _, case in ipairs(cases) do
        it("renders a " .. case[1] .. " entry", function()
            local item = Rows.items({ case[2] }, options)[1]
            assert.equals(case[3], item.display)
            assert.same({ { 0, #case[3], case[4] } }, item.highlights)
            assert.equals(case[2].path, item.value)
            local parent = case[2].parent and (" " .. vim.fn.fnamemodify(case[2].parent, ":t")) or ""
            assert.equals(vim.fn.fnamemodify(case[2].path, ":t") .. " " .. vim.fn.fnamemodify(case[2].path, ":h") .. parent, item.search_text)
        end)
    end

    it("keeps the model's order: newest submit first", function()
        local state = Model.empty()
        for i, path in ipairs({ "/x/old.md", "/x/new.md" }) do
            state = Model.transition(state, { type = "submitted", path = path, id = "m" .. i }, i * 60)
        end
        local items = Rows.items(Model.list(state), options)
        assert.same({ "/x/new.md", "/x/old.md" }, vim.tbl_map(function(item) return item.value end, items))
    end)
end)


describe("attention tree rows", function()
    local function side(path, parent) return entry(path, { kind = "side", parent = parent }) end
    local function values(items) return vim.tbl_map(function(i) return i.value end, items) end

    it("groups nested children under parents, retaining root and sibling order", function()
        local input = { side("/grand.md", "/child.md"), entry("/new.md"), side("/child.md", "/old.md"),
            side("/sibling.md", "/old.md"), entry("/old.md"), side("/orphan.md", "/missing.md") }
        local before = vim.deepcopy(input)
        local rows = Rows.items(input, options)
        assert.same({ "/new.md", "/old.md", "/child.md", "/grand.md", "/sibling.md", "/orphan.md" }, values(rows))
        assert.matches("^  answered", rows[3].display)
        assert.matches("^    answered", rows[4].display)
        assert.matches("^answered", rows[6].display)
        assert.equals("/old.md", rows[3].parent_value)
        assert.equals("/child.md", rows[4].parent_value)
        assert.same(before, input)
    end)

    it("breaks cycles and self-parents without losing or duplicating entries", function()
        local rows = Rows.items({ side("/a", "/b"), side("/b", "/a"), side("/self", "/self") }, options)
        assert.same({ "/a", "/b", "/self" }, values(rows))
        assert.is_nil(rows[1].parent_value)
        assert.equals("/a", rows[2].parent_value)
        assert.is_nil(rows[3].parent_value)
    end)

    for _, shape in ipairs({
        { name = "self-cycle child", input = { { "leaf", "a" }, { "a", "a" } }, order = { "a", "leaf" } },
        { name = "multi-node cycle child", input = { { "leaf", "a" }, { "a", "b" }, { "b", "a" } },
            order = { "a", "leaf", "b" } },
        { name = "nested cycle descendants", input = { { "leaf", "child" }, { "child", "a" }, { "a", "b" }, { "b", "a" } },
            order = { "a", "child", "leaf", "b" } },
    }) do
        it("preserves parentage and search context for a " .. shape.name, function()
            local input = {}
            for _, pair in ipairs(shape.input) do input[#input + 1] = side("/" .. pair[1], "/" .. pair[2]) end
            local rows = Rows.items(input, options)
            local expected = vim.tbl_map(function(name) return "/" .. name end, shape.order)
            assert.same(expected, values(rows)) -- also proves every entry appears exactly once
            local by_value = {}
            for _, row in ipairs(rows) do by_value[row.value] = row end
            assert.is_nil(by_value["/a"].parent_value)
            for _, pair in ipairs(shape.input) do
                if pair[1] ~= "a" then assert.equals("/" .. pair[2], by_value["/" .. pair[1]].parent_value) end
            end
            local context = #shape.input == 4 and { "/a", "/child", "/leaf" } or { "/a", "/leaf" }
            assert.same(context, values(Rows.filter(rows, "leaf", function(_, text)
                return text:match("^leaf ") and 1 or nil
            end)))
        end)
    end

    it("bounds cycle recovery with newest descendants at N and 2N", function()
        for _, n in ipairs({ 16, 32 }) do
            local input, reads = {}, 0
            for i = n, 1, -1 do
                local parent = "/" .. (i == 1 and 1 or i - 1)
                input[#input + 1] = setmetatable(entry("/" .. i, { kind = "side" }), {
                    __index = function(_, key) if key == "parent" then reads = reads + 1; return parent end end,
                })
            end
            local rows = Rows.items(input, options)
            assert.equals(n, #rows)
            assert.is_true(reads <= 4 * n, "cycle parent walks repeated")
            local roots = 0
            for _, row in ipairs(rows) do if not row.parent_value then roots = roots + 1 end end
            assert.equals(1, roots)
            local found = Rows.filter(rows, "leaf", function(_, text) return text:match("^" .. n .. " ") and 1 end)
            assert.equals(n, #found)
        end
    end)

    it("retains matching descendants and ancestors once in tree order", function()
        assert.is_function(Rows.filter)
        local rows = Rows.items({ entry("/root"), side("/child", "/root"), side("/leaf", "/child"),
            side("/sibling", "/root"), entry("/other") }, options)
        local score = function(_, text) return text:find("leaf", 1, true) and 10 or nil end
        assert.same({ "/root", "/child", "/leaf" }, values(Rows.filter(rows, "leaf", score)))
        assert.same({}, Rows.filter(rows, "none", function() return nil end))
        assert.same(values(rows), values(Rows.filter(rows, "", function() error("empty query scored") end)))
    end)

    it("bounds layout parent reads and query scoring at N and 2N", function()
        assert.is_function(Rows.filter)
        for _, n in ipairs({ 16, 32 }) do
            local entries, reads, calls = {}, 0, 0
            for i = n, 1, -1 do
                local parent = i > 1 and ("/" .. (i - 1)) or nil
                entries[#entries + 1] = setmetatable(entry("/" .. i, { kind = "side" }), {
                    __index = function(_, key) if key == "parent" then reads = reads + 1; return parent end end,
                })
            end
            local rows = Rows.items(entries, options)
            assert.is_true(reads <= 4 * n, "repeated parent scans")
            local parent_reads = 0
            for _, row in ipairs(rows) do
                local parent = row.parent_value
                row.parent_value = nil
                setmetatable(row, { __index = function(_, key)
                    if key == "parent_value" then parent_reads = parent_reads + 1; return parent end
                end })
            end
            local found = Rows.filter(rows, "all", function() calls = calls + 1; return 1 end)
            assert.equals(n, #found)
            assert.equals(n, calls)
            assert.is_true(parent_reads <= n, "ancestor walks repeated retained edges")
        end
    end)
end)

describe("attention initial selection (#392)", function()
    it("chooses answer time without reordering the forest and includes a nested child", function()
        local entries = {
            entry("/new.md", { submitted_at = 900, answered_at = 800 }),
            entry("/child.md", { kind = "side", parent = "/parent.md", submitted_at = 500, answered_at = 100 }),
            entry("/seen.md", { answered_at = 10, seen_at = 20 }),
            entry("/parent.md", { pending = { m = 1 }, submitted_at = 200 }),
        }
        local before = vim.deepcopy(entries)
        local items, initial = Rows.items(entries, options)
        assert.same({ "/new.md", "/seen.md", "/parent.md", "/child.md" },
            vim.tbl_map(function(item) return item.value end, items))
        assert.equals(4, initial)
        assert.same(before, entries)
    end)
    it("keeps tree order on ties and falls back to submit time for a legacy answer", function()
        local _, initial = Rows.items({ entry("/a", { answered_at = 40 }), entry("/b", { answered_at = 40 }) }, options)
        assert.equals(1, initial)
        _, initial = Rows.items({ entry("/a", { answered_at = 40 }), entry("/legacy", { submitted_at = 30 }) }, options)
        assert.equals(2, initial)
    end)
    it("evaluates state once per entry at N and 2N", function()
        for _, count in ipairs({ 8, 16 }) do
            local entries, reads = {}, 0
            for i = 1, count do
                entries[i] = setmetatable({ path = "/" .. i .. ".md", submitted_at = 10,
                    answered_at = count - i }, { __index = function(_, key)
                    if key == "pending" then reads = reads + 1; return {} end
                end })
            end
            local _, initial = Rows.items(entries, options)
            assert.equals(count, reads)
            assert.equals(count, initial)
        end
    end)
    it("uses the top for waiting-only, seen-only and empty lists", function()
        for _, entries in ipairs({ {}, { entry("/waiting", { pending = { m = 1 } }) },
            { entry("/seen", { answered_at = 1, seen_at = 2 }) } }) do
            local _, initial = Rows.items(entries, options)
            assert.equals(1, initial)
        end
    end)
end)
