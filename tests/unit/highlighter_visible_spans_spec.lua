-- #293: the highlighter decorates only rows a window draws. A closed fold
-- shows one row, so its interior must not be queried or highlighted on every
-- redraw. visible_spans is checked against a brute-force row filter over
-- seeded random fold layouts.
local highlighter = require("parley.highlighter")

-- Disjoint closed folds within [0, size): { {start, stop}, ... }.
local function random_folds(size)
    local folds, row = {}, 0
    while row < size do
        row = row + math.random(0, 6)
        if row >= size then break end
        local stop = math.min(size - 1, row + math.random(0, 12))
        folds[#folds + 1] = { row, stop }
        row = stop + 1 + math.random(0, 4)
    end
    return folds
end

local function fold_end_of(folds)
    return function(row)
        for _, f in ipairs(folds) do
            if row >= f[1] and row <= f[2] then return f[2] end
        end
    end
end

-- A row is drawn unless a closed fold holds it after the fold's shown row,
-- which is its start, or `first` when the fold begins above the window.
local function drawn_rows(first, last, folds)
    local out = {}
    for row = first, last do
        local hidden = false
        for _, f in ipairs(folds) do
            if row > math.max(f[1], first) and row <= f[2] then hidden = true end
        end
        if not hidden then out[#out + 1] = row end
    end
    return out
end

describe("highlighter visible_spans (#293)", function()
    it("covers exactly the drawn rows, as ascending disjoint spans", function()
        math.randomseed(293)
        for _ = 1, 500 do
            local size = math.random(1, 80)
            local folds = random_folds(size)
            local first = math.random(0, size - 1)
            local last = math.random(first, size - 1)
            local spans = highlighter._visible_spans(first, last, fold_end_of(folds))
            local covered, previous = {}, nil
            for _, span in ipairs(spans) do
                assert.is_true(span[1] <= span[2], "empty span")
                if previous then
                    assert.is_true(span[1] > previous + 1, "spans overlap or touch: should have merged")
                end
                for row = span[1], span[2] do covered[#covered + 1] = row end
                previous = span[2]
            end
            assert.same(drawn_rows(first, last, folds), covered)
        end
    end)

    it("no folds is one span", function()
        assert.same({ { 3, 40 } }, highlighter._visible_spans(3, 40, function() end))
    end)
end)
