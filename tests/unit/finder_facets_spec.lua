local finder_facets = require("parley.finder_facets")

local function facets(entry)
    return entry.facets
end

describe("finder facets", function()
    describe("discover", function()
        it("deduplicates and sorts non-empty keys before the untagged key", function()
            local calls = 0
            local entries = {
                { facets = { "beta", "alpha" } },
                { facets = { "alpha" } },
                { facets = { "" } },
            }

            local got = finder_facets.discover(entries, function(entry)
                calls = calls + 1
                return facets(entry)
            end)

            assert.same({ "alpha", "beta", "" }, got)
            assert.equals(3, calls)
        end)

        it("returns an empty list when no facets are discovered", function()
            assert.same({}, finder_facets.discover({ { facets = {} } }, facets))
        end)
    end)

    describe("merge_state", function()
        it("enables new keys while retaining prior and temporarily absent choices", function()
            local previous = { alpha = false, missing = false }

            local got = finder_facets.merge_state(previous, { "alpha", "beta" })

            assert.same({ alpha = false, beta = true, missing = false }, got)
            assert.same({ alpha = false, missing = false }, previous)
        end)

        it("starts with every discovered key enabled", function()
            assert.same({ alpha = true, beta = true }, finder_facets.merge_state(nil, { "alpha", "beta" }))
        end)
    end)

    describe("state transitions", function()
        it("toggles only the requested key without mutating state", function()
            local state = { alpha = true, beta = false }

            local got = finder_facets.toggle(state, "alpha")

            assert.same({ alpha = false, beta = false }, got)
            assert.same({ alpha = true, beta = false }, state)
        end)

        it("sets every retained key without mutating state", function()
            local state = { alpha = false, missing = true }

            assert.same({ alpha = true, missing = true }, finder_facets.set_all(state, true))
            assert.same({ alpha = false, missing = false }, finder_facets.set_all(state, false))
            assert.same({ alpha = false, missing = true }, state)
        end)
    end)

    describe("filter", function()
        local entries = {
            { id = "both", facets = { "alpha", "beta" } },
            { id = "alpha", facets = { "alpha" } },
            { id = "untagged", facets = { "" } },
            { id = "none", facets = {} },
        }

        local function ids(items)
            return vim.tbl_map(function(item) return item.id end, items)
        end

        it("uses OR semantics and preserves entry order", function()
            local got = finder_facets.filter(entries, { alpha = false, beta = true, [""] = false }, facets)

            assert.same({ "both" }, ids(got))
        end)

        it("includes untagged entries through the empty-string facet", function()
            local got = finder_facets.filter(entries, { alpha = false, beta = false, [""] = true }, facets)

            assert.same({ "untagged" }, ids(got))
        end)

        it("returns no mapped entries when every facet is disabled", function()
            local got = finder_facets.filter(entries, { alpha = false, beta = false, [""] = false }, facets)

            assert.same({}, got)
        end)

        it("does not mutate the input list", function()
            finder_facets.filter(entries, { alpha = true, beta = true, [""] = true }, facets)
            assert.equals(4, #entries)
        end)
    end)

    describe("project", function()
        it("projects discovered keys in order", function()
            assert.same({
                { label = "alpha", enabled = false },
                { label = "beta", enabled = true },
                { label = "", enabled = true },
            }, finder_facets.project({ "alpha", "beta", "" }, { alpha = false, beta = true, [""] = true }))
        end)

        it("returns nil without discovered facets", function()
            assert.is_nil(finder_facets.project({}, {}))
        end)
    end)
end)
