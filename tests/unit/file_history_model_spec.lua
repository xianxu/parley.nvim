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
