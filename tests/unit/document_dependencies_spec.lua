local dependencies

local function coordinates(count)
    local positions, handles = {}, {}
    for i = 1, count do
        handles[i] = { id = i }
        positions[handles[i]] = i - 1
    end
    local eof = {}
    positions[eof] = count
    local calls = 0
    local index = dependencies.new({ rank = function(handle)
        calls = calls + 1
        return positions[handle]
    end })
    return index, handles, positions, eof, function() return calls end
end

local function ok(result)
    assert.equals("ok", result.status)
    return result
end

describe("document dependency index", function()
    before_each(function()
        local loaded, module = pcall(require, "parley.document.dependencies")
        assert.is_true(loaded, tostring(module))
        dependencies = module
    end)

    it("finds the earliest inclusive overlap and coalesces duplicate origins", function()
        local index, h = coordinates(12)
        ok(index:add(h[5], h[8]))
        ok(index:add(h[2], h[3]))
        ok(index:add(h[2], h[10]))
        ok(index:add(h[2], h[4]))
        assert.equals(h[2], ok(index:restart_origin(7, 7)).origin)
        assert.equals(h[2], ok(index:restart_origin(9, 9)).origin)
        assert.is_nil(ok(index:restart_origin(10, 11)).origin)
        assert.equals(1, ok(index:remove_from(h[5])).removed)
        assert.equals(h[2], ok(index:restart_origin(7, 7)).origin)
    end)

    it("resolves shifted endpoints and reports a deleted witness as stale", function()
        local index, h, positions = coordinates(20)
        ok(index:add(h[10], h[15]))
        -- A disjoint insertion before the dependency preserves handle order.
        for i = 1, #h do positions[h[i]] = positions[h[i]] + 7 end
        assert.is_nil(ok(index:restart_origin(9, 10)).origin)
        assert.equals(h[10], ok(index:restart_origin(20, 20)).origin)
        positions[h[15]] = nil
        assert.equals("stale", index:restart_origin(20, 20).status)
        assert.equals("stale", index:add(h[2], h[15]).status)
    end)

    it("keeps mutations atomic when their node budget is exhausted", function()
        local index, h = coordinates(100)
        for i = 1, 99, 2 do ok(index:add(h[i], h[i + 1])) end
        local before = ok(index:restart_origin(98, 99)).origin
        assert.equals("budget", index:remove_from(h[20], { budget = 1 }).status)
        assert.equals(before, ok(index:restart_origin(98, 99)).origin)
        assert.equals("budget", index:add(h[1], h[100], { budget = 1 }).status)
        assert.equals(before, ok(index:restart_origin(98, 99)).origin)
        local query = index:restart_origin(98, 99, { budget = 1 })
        assert.equals("budget", query.status)
        assert.equals(1, query.work.dependency_nodes_visited)
    end)

    it("matches an exhaustive dependency oracle across seeded edit histories", function()
        local index, h, positions, eof = coordinates(250)
        local flat = {}
        local seed = 918273
        local function random(n)
            seed = (seed * 48271) % 2147483647
            return seed % n + 1
        end
        for step = 1, 1200 do
            if step % 4 ~= 0 then
                local a = random(#h)
                local b = a + random(#h - a + 1) - 1
                local last = step % 7 == 0 and eof or h[b]
                ok(index:add(h[a], last))
                if not flat[h[a]] or positions[last] > positions[flat[h[a]]] then flat[h[a]] = last end
            else
                local first = random(positions[eof] + 1) - 1
                local last = math.min(positions[eof], first + random(4) - 1)
                local expected
                for origin, endpoint in pairs(flat) do
                    if positions[origin] <= last and positions[endpoint] >= first
                        and (not expected or positions[origin] < positions[expected]) then expected = origin end
                end
                local actual = ok(index:restart_origin(first, last)).origin
                assert.equals(expected, actual)
                if expected then
                    local cut = positions[expected]
                    ok(index:remove_from(expected))
                    for origin in pairs(flat) do if positions[origin] >= cut then flat[origin] = nil end end
                end
                -- Mutate the coordinate authority only AFTER retiring affected
                -- certificates. Surviving handles keep order, never cached rows.
                if step % 8 == 0 then
                    local retained = {}
                    for _, handle in ipairs(h) do
                        local position = positions[handle]
                        if position >= first and position < last then
                            positions[handle] = nil
                        else
                            retained[#retained + 1] = handle
                            if position >= last then positions[handle] = position - (last - first) end
                        end
                    end
                    h = retained
                    positions[eof] = positions[eof] - (last - first)
                else
                    for handle, position in pairs(positions) do
                        if position >= first then positions[handle] = position + 1 end
                    end
                    local inserted = {}
                    positions[inserted] = first
                    local offset = 1
                    while h[offset] and positions[h[offset]] < first do offset = offset + 1 end
                    table.insert(h, offset, inserted)
                end
            end
        end
    end)

    it("does not publish a candidate when an inspected endpoint is stale", function()
        local index, h, positions = coordinates(20)
        ok(index:add(h[2], h[5]))
        ok(index:add(h[10], h[15]))
        local old = positions[h[15]]
        positions[h[15]] = nil
        assert.equals("stale", index:add(h[1], h[3]).status)
        positions[h[15]] = old
        assert.is_nil(ok(index:restart_origin(0, 0)).origin)
        assert.equals(h[10], ok(index:restart_origin(14, 14)).origin)
    end)

    it("finds thousands of negative EOF dependencies without enumerating matches", function()
        local index, h, positions, eof, calls = coordinates(50000)
        for i = 1, #h do ok(index:add(h[i], eof)) end
        local before = calls()
        local result = ok(index:restart_origin(positions[eof], positions[eof], { budget = 128 }))
        assert.equals(h[1], result.origin)
        assert.is_true(result.work.dependency_nodes_visited <= 64)
        assert.is_true(calls() - before <= 64)
        local removed = ok(index:remove_from(h[2], { budget = 512 }))
        assert.equals(49999, removed.removed)
        assert.equals(h[1], ok(index:restart_origin(positions[eof], positions[eof])).origin)
    end)
    it("bounds dependency and actual sequence navigation at fifty thousand origins", function()
        local sequence = require("parley.document.sequence")
        local values = {}
        for i = 1, 50010 do values[i] = { rows = 1, bytes = 2, metadata = {} } end
        local seq = sequence.new(values)
        local spans = sequence.query(seq, 0, #values)
        local index = dependencies.new({ rank = function(handle)
            local position = sequence.rank(seq, handle)
            return position and position.row
        end })
        local eof = sequence.eof(seq)
        for i = 11, #spans do ok(index:add(spans[i].handle, eof)) end
        sequence.stats(seq, true)
        local result = ok(index:restart_origin(50010, 50010, { budget = 128 }))
        local rank_work = sequence.stats(seq, true)
        assert.equals(spans[11].handle, result.origin)
        assert.is_true(result.work.dependency_nodes_visited <= 64)
        assert.is_true(rank_work.nodes_visited <= 2048)
        assert.is_true(rank_work.entries_visited <= 2048)

        -- A preceding edit does not intersect any dependency. No rekeying or
        -- endpoint sweep is permitted: use the same handles against the new root.
        assert.is_nil(ok(index:restart_origin(1, 1)).origin)
        sequence.splice(seq, 1, 1, { { rows = 3, bytes = 6, opaque = true } })
        sequence.stats(seq, true)
        result = ok(index:restart_origin(50013, 50013, { budget = 128 }))
        rank_work = sequence.stats(seq, true)
        assert.equals(spans[11].handle, result.origin)
        assert.equals(13, sequence.rank(seq, result.origin).row)
        assert.is_true(result.work.dependency_nodes_visited <= 64)
        assert.is_true(rank_work.nodes_visited <= 2048)
        assert.is_true(rank_work.entries_visited <= 2048)

        local removed = ok(index:remove_from(spans[25011].handle, { budget = 512 }))
        rank_work = sequence.stats(seq, true)
        assert.equals(25000, removed.removed)
        assert.is_true(removed.work.dependency_nodes_visited <= 512)
        assert.is_true(rank_work.nodes_visited <= 4096)
        assert.is_true(rank_work.entries_visited <= 4096)
    end)

end)
