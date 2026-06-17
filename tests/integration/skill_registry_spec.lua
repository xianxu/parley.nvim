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

describe("skill_registry.current — real plugin skills as manifests", function()
    -- The bundled review + voice-apply load (via the disk provider over the
    -- real plugin root) as VALID declarative manifests. This only proves they
    -- discover as conformant manifests; routing them through the chat loop is
    -- M2/M3/M4.
    local reg = registry.current()

    it("discovers review as a valid global manifest with the expected fields", function()
        local review = reg.get("review")
        assert.is_not_nil(review, "review not discovered: " .. vim.inspect(reg.names()))
        assert.are.equal("global", review.scope)
        assert.is_true(review.activation.manual)
        assert.is_function(review.source)
    end)

    it("discovers voice-apply as a valid global manifest", function()
        local voice = reg.get("voice-apply")
        assert.is_not_nil(voice, "voice-apply not discovered: " .. vim.inspect(reg.names()))
        assert.are.equal("global", voice.scope)
        assert.is_true(voice.activation.manual)
        assert.is_function(voice.source)
    end)
end)
