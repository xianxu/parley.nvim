-- Integration tests for lua/parley/skill_registry.lua
--
-- discover(providers) unions every provider's manifests into one registry,
-- deduping by name. Providers are injected (lists of manifests) so the union
-- logic needs no real filesystem.
--
-- Precedence: LAST provider wins (later in the stack overrides earlier), so the
-- default stack {plugin, user, repo, virtual} lets a user/repo skill shadow a
-- plugin default of the same name. (Operator-confirmable policy.)

local registry = require("parley.skill_registry")

local function m(name, body)
    return {
        name = name,
        description = name .. " desc",
        scope = "global",
        activation = { manual = true },
        source = function()
            return body or name
        end,
    }
end

local function fake_provider(manifests)
    return {
        list = function()
            return manifests
        end,
    }
end

describe("skill_registry.discover", function()
    it("unions all providers' manifests; get/names expose them", function()
        local reg = registry.discover({
            fake_provider({ m("alpha"), m("beta") }),
            fake_provider({ m("gamma") }),
        })
        assert.is_not_nil(reg.get("alpha"))
        assert.is_not_nil(reg.get("beta"))
        assert.is_not_nil(reg.get("gamma"))
        local names = reg.names()
        table.sort(names)
        assert.are.same({ "alpha", "beta", "gamma" }, names)
    end)

    it("dedupes by name with LAST-provider-wins precedence", function()
        local reg = registry.discover({
            fake_provider({ m("dup", "PLUGIN") }), -- earlier (base)
            fake_provider({ m("dup", "USER") }), -- later (override) → wins
        })
        local names = reg.names()
        assert.are.equal(1, #names, "dup should appear once")
        assert.are.equal("USER", reg.get("dup").source({}))
    end)

    it("preserves first-appearance order in names()", function()
        local reg = registry.discover({
            fake_provider({ m("alpha"), m("dup", "A") }),
            fake_provider({ m("dup", "B"), m("beta") }),
        })
        assert.are.same({ "alpha", "dup", "beta" }, reg.names())
    end)

    it("returns nil for an unknown name", function()
        local reg = registry.discover({ fake_provider({ m("alpha") }) })
        assert.is_nil(reg.get("nope"))
    end)

    it("drops invalid manifests rather than sinking discovery", function()
        local bad = { name = "broken" } -- missing required fields → invalid
        local reg = registry.discover({ fake_provider({ m("ok"), bad }) })
        assert.is_not_nil(reg.get("ok"))
        assert.is_nil(reg.get("broken"))
    end)
end)
