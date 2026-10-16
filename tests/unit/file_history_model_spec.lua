local model = require("parley.file_history_model")

local function entry(path, row, col)
    return { path = path, cursor = { row = row, col = col } }
end

local function visit(history, path, row, col, limit)
    return model.transition(history, { kind = "visit", path = path, cursor = { row = row, col = col } }, limit)
end

describe("file_history_model.transition", function()
    it("backs through distinct paths and stops at the root", function()
        local history = visit(nil, "A", 1, 2)
        history = visit(history, "B", 3, 4)
        history = visit(history, "C", 5, 6)

        local next_history, target = model.transition(history, { kind = "back" })
        assert.are.same(entry("B", 3, 4), target)
        assert.are.equal(2, next_history.index)
        next_history, target = model.transition(next_history, { kind = "back" })
        assert.are.same(entry("A", 1, 2), target)
        assert.are.equal(1, next_history.index)
        local at_root = next_history
        next_history, target = model.transition(next_history, { kind = "back" })
        assert.is_nil(target)
        assert.are.same(at_root, next_history)
    end)

    it("updates same-path cursor without adding a visit or dropping forward entries", function()
        local history = visit(nil, "A", 1, 2)
        history = visit(history, "B", 3, 4)
        history = visit(history, "C", 5, 6)
        history = model.transition(history, { kind = "back" })
        history = visit(history, "B", 8, 9)

        assert.are.equal(3, #history.entries)
        assert.are.equal(2, history.index)
        assert.are.same(entry("B", 8, 9), history.entries[2])
        assert.are.same(entry("C", 5, 6), history.entries[3])
    end)

    it("restores each visit cursor and allows nonadjacent repeated paths", function()
        local history = visit(nil, "A", 1, 2)
        history = visit(history, "B", 3, 4)
        history = visit(history, "A", 5, 6)

        assert.are.same({ entry("A", 1, 2), entry("B", 3, 4), entry("A", 5, 6) }, history.entries)
        local _, target = model.transition(history, { kind = "back" })
        assert.are.same(entry("B", 3, 4), target)
    end)

    it("truncates forward history when visiting another path after back", function()
        local history = visit(nil, "A", 1, 1)
        history = visit(history, "B", 2, 2)
        history = visit(history, "C", 3, 3)
        history = model.transition(history, { kind = "back" })
        history = visit(history, "D", 4, 4)

        assert.are.same({ entry("A", 1, 1), entry("B", 2, 2), entry("D", 4, 4) }, history.entries)
        assert.are.equal(3, history.index)
    end)

    it("updates snapshots only for the current path", function()
        local history = visit(nil, "A", 1, 2)
        history = visit(history, "B", 3, 4)
        local unchanged = model.transition(history, { kind = "snapshot", path = "A", cursor = { row = 8, col = 9 } })
        assert.are.same(history, unchanged)
        local updated = model.transition(history, { kind = "snapshot", path = "B", cursor = { row = 8, col = 9 } })
        assert.are.same(entry("B", 8, 9), updated.entries[2])
        assert.are.same(entry("B", 3, 4), history.entries[2])
    end)

    it("does not mutate shared history or event cursors", function()
        local cursor = { row = 1, col = 2 }
        local source = { entries = { { path = "A", cursor = cursor } }, index = 1 }
        local sibling = source
        local event_cursor = { row = 3, col = 4 }
        local next_history = model.transition(source, { kind = "visit", path = "B", cursor = event_cursor })
        local sibling_history = model.transition(sibling, { kind = "visit", path = "C", cursor = { row = 5, col = 6 } })
        event_cursor.row = 99

        assert.are.equal(1, #source.entries)
        assert.are.same(source, sibling)
        assert.are.same({ row = 3, col = 4 }, next_history.entries[2].cursor)
        assert.are.same({ row = 5, col = 6 }, sibling_history.entries[2].cursor)
        assert.are.same({ path = "A", cursor = { row = 1, col = 2 } }, source.entries[1])
        assert.are_not.equal(source, next_history)
        assert.are_not.equal(cursor, next_history.entries[1].cursor)
    end)

    it("uses a default cap of 200 and honors a smaller cap", function()
        local history
        for index = 1, 205 do
            history = visit(history, tostring(index), index, index)
        end
        assert.are.equal(200, #history.entries)
        assert.are.equal("6", history.entries[1].path)
        assert.are.equal(200, history.index)

        history = visit(nil, "A", 1, 1)
        history = visit(history, "B", 2, 2)
        history = visit(history, "C", 3, 3, 2)
        assert.are.equal(2, #history.entries)
        assert.are.equal("B", history.entries[1].path)
        assert.are.equal("C", history.entries[2].path)
    end)
end)

describe("file_history_model breadcrumb installation", function()
    local function trail(paths)
        return { version = 1, paths = paths, omitted = 0 }
    end

    it("copies trails through visits, snapshots and Back without changing legacy entry shapes", function()
        local supplied = trail({ "/A" })
        local history = model.transition(nil, { kind = "visit", path = "/A", cursor = { row = 2, col = 3 }, trail = supplied })
        supplied.paths[1] = "/changed"
        history = model.transition(history, { kind = "snapshot", path = "/A", cursor = { row = 4, col = 5 } })
        history = visit(history, "/A", 6, 7)
        assert.are.same(trail({ "/A" }), history.entries[1].trail)
        history = visit(history, "/B", 1, 0)
        local _, target = model.transition(history, { kind = "back" })
        assert.are.same(trail({ "/A" }), target.trail)
        target.trail.paths[1] = "/mutated"
        assert.are.same(trail({ "/A" }), history.entries[1].trail)
    end)

    it("replaces provisional destination and keeps earlier unrelated history and cursors", function()
        local history = visit(nil, "/X", 8, 9)
        history = visit(history, "/C", 10, 11)
        local value = trail({ "/A", "/B", "/C" })
        local cursors = { { row = 1, col = 0 }, { row = 2, col = 3 }, { row = 10, col = 11 } }
        local installed = model.install_trail(history, value, cursors)
        assert.are.equal(4, installed.index)
        assert.are.equal("/X", installed.entries[1].path)
        assert.are.same(trail({ "/A", "/B" }), installed.entries[3].trail)
        local previous, target = model.transition(installed, { kind = "back" })
        assert.are.equal("/B", target.path)
        assert.are.same(cursors[2], target.cursor)
        previous, target = model.transition(previous, { kind = "back" })
        assert.are.equal("/A", target.path)
        previous, target = model.transition(previous, { kind = "back" })
        assert.are.equal("/X", target.path)
        value.paths[1] = "/changed"
        cursors[1].row = 99
        assert.are.equal("/A", installed.entries[2].trail.paths[1])
        assert.are.equal(1, installed.entries[2].cursor.row)
        assert.are.equal(2, #history.entries)
    end)

    it("coalesces longest ordered suffix overlap and discards forward entries", function()
        local history = visit(nil, "/X", 1, 0)
        history = visit(history, "/A", 2, 0)
        history = visit(history, "/B", 3, 0)
        history = visit(history, "/C", 4, 0)
        history = visit(history, "/forward", 5, 0)
        history = model.transition(history, { kind = "back" })
        local installed = model.install_trail(history, trail({ "/A", "/B", "/C" }), {})
        assert.are.equal(4, #installed.entries)
        assert.are.same({ "/X", "/A", "/B", "/C" }, vim.tbl_map(function(e) return e.path end, installed.entries))
        assert.are.same(trail({ "/A", "/B" }), installed.entries[3].trail)
    end)

    it("preserves repeated paths in chains and caps older visits first", function()
        local installed = model.install_trail(nil, trail({ "/A", "/B", "/A", "/C" }), {}, 3)
        assert.are.same({ "/B", "/A", "/C" }, vim.tbl_map(function(e) return e.path end, installed.entries))
        assert.are.equal(3, installed.index)
        assert.are.same(trail({ "/A", "/B", "/A", "/C" }), installed.entries[3].trail)
    end)
    it("keeps generated independent window histories coherent across install and Back", function()
        local windows = {}
        for step = 1, 100 do
            local slot = step % 2 + 1
            local other = windows[3 - slot] and vim.deepcopy(windows[3 - slot])
            local paths = { "/root" .. slot, "/branch" .. (step % 5), "/leaf" .. step }
            local current = visit(windows[slot], paths[3], step, slot)
            local original = vim.deepcopy(current)
            local installed = model.install_trail(current, trail(paths), {
                { row = slot, col = 0 }, { row = step + 1, col = 2 }, { row = step, col = slot },
            }, 20)
            assert.are.same(original, current)
            assert.are.same(other, windows[3 - slot])
            assert.is_true(#installed.entries <= 20)
            for _, item in ipairs(installed.entries) do
                if item.trail then assert.are.equal(item.path, item.trail.paths[#item.trail.paths]) end
            end
            local back, target = model.transition(installed, { kind = "back" })
            assert.are.equal(paths[2], target.path)
            assert.are.same({ row = step + 1, col = 2 }, target.cursor)
            back, target = model.transition(back, { kind = "back" })
            assert.are.equal(paths[1], target.path)
            windows[slot] = installed
        end
    end)

end)
