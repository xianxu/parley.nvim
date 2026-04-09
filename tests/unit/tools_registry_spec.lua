-- Unit tests for lua/parley/tools/init.lua
--
-- The tool registry owns a mutable table mapping tool name → ToolDefinition.
-- It exposes:
--   register(def)    — insert (validates via types), raises on bad input
--   get(name)        — lookup by name, returns the definition or nil
--   list_names()     — returns a list of registered names (unsorted)
--   select(names)    — returns a list of definitions matching the given
--                      names, preserving order, raising on unknown names
--   reset()          — clear the registry (idempotent across setup() calls
--                      and useful for test isolation)
--
-- Registry state is module-level; reset() is called in before_each to
-- avoid cross-test leakage.

local registry = require("parley.tools")

local function make_def(name)
    return {
        name = name,
        description = "Test tool " .. name,
        input_schema = { type = "object" },
        handler = function() end,
    }
end

describe("tool registry", function()
    before_each(function()
        registry.reset()
    end)

    describe("register", function()
        it("accepts and stores a valid definition", function()
            local def = make_def("foo")
            registry.register(def)
            assert.equals(def, registry.get("foo"))
        end)

        it("raises on invalid definition (missing name)", function()
            local ok, err = pcall(registry.register, { description = "x" })
            assert.is_false(ok)
            assert.matches("name", err)
        end)

        it("raises on invalid definition (empty name)", function()
            local ok, err = pcall(registry.register, {
                name = "",
                description = "x",
                input_schema = {},
                handler = function() end,
            })
            assert.is_false(ok)
            assert.matches("name", err)
        end)

        it("raises on non-table input", function()
            local ok, err = pcall(registry.register, "not a def")
            assert.is_false(ok)
            assert.matches("table", err)
        end)

        it("overwrites when registering the same name twice", function()
            local first = make_def("foo")
            local second = make_def("foo")
            registry.register(first)
            registry.register(second)
            assert.equals(second, registry.get("foo"))
            assert.not_equal(first, registry.get("foo"))
        end)
    end)

    describe("get", function()
        it("returns nil for unknown names", function()
            assert.is_nil(registry.get("nonexistent"))
        end)

        it("returns the definition for a registered name", function()
            local def = make_def("foo")
            registry.register(def)
            assert.equals(def, registry.get("foo"))
        end)
    end)

    describe("list_names", function()
        it("returns empty list when registry is empty", function()
            assert.same({}, registry.list_names())
        end)

        it("returns all registered names", function()
            registry.register(make_def("alpha"))
            registry.register(make_def("beta"))
            registry.register(make_def("gamma"))
            local names = registry.list_names()
            table.sort(names)
            assert.same({ "alpha", "beta", "gamma" }, names)
        end)
    end)

    describe("select", function()
        it("returns matching definitions in the order given", function()
            local a = make_def("alpha")
            local b = make_def("beta")
            local c = make_def("gamma")
            registry.register(a)
            registry.register(b)
            registry.register(c)
            local subset = registry.select({ "gamma", "alpha" })
            assert.equals(2, #subset)
            assert.equals(c, subset[1])
            assert.equals(a, subset[2])
        end)

        it("returns an empty list for an empty input", function()
            registry.register(make_def("alpha"))
            assert.same({}, registry.select({}))
        end)

        it("raises on unknown tool name with the offending name in the message", function()
            registry.register(make_def("alpha"))
            local ok, err = pcall(registry.select, { "nonexistent" })
            assert.is_false(ok)
            assert.matches("nonexistent", err)
        end)

        it("raises on the first unknown name even when some are known", function()
            registry.register(make_def("alpha"))
            local ok, err = pcall(registry.select, { "alpha", "nonexistent" })
            assert.is_false(ok)
            assert.matches("nonexistent", err)
        end)
    end)

    describe("reset", function()
        it("clears all registered tools", function()
            registry.register(make_def("alpha"))
            registry.register(make_def("beta"))
            registry.reset()
            assert.same({}, registry.list_names())
            assert.is_nil(registry.get("alpha"))
        end)

        it("is idempotent on an empty registry", function()
            registry.reset()
            registry.reset()
            assert.same({}, registry.list_names())
        end)
    end)
end)
