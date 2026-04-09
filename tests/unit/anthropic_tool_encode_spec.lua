-- Unit tests for M.anthropic_encode_tools in lua/parley/providers.lua
--
-- Pure table-transformation function: takes a list of ToolDefinitions
-- and returns the Anthropic-specific payload shape for the `tools`
-- field (per https://docs.anthropic.com/en/docs/build-with-claude/tool-use).
--
-- Each Anthropic tool entry has: { name, description, input_schema }.
-- Parley's internal ToolDefinition carries additional fields (handler,
-- kind, needs_backup) that are NOT sent to the API — the encoder drops
-- them so the payload stays clean.

local providers = require("parley.providers")
local registry = require("parley.tools")

local function fresh_def(name, desc, schema)
    return {
        name = name,
        description = desc or ("Test tool " .. name),
        input_schema = schema or { type = "object" },
        handler = function() end,
        kind = "read",
    }
end

describe("providers.anthropic_encode_tools", function()
    before_each(function()
        registry.reset()
    end)

    it("converts a single ToolDefinition to the Anthropic payload shape", function()
        registry.register(fresh_def("read_file", "Read a file.", {
            type = "object",
            properties = { path = { type = "string" } },
            required = { "path" },
        }))
        local defs = registry.select({ "read_file" })
        local payload = providers.anthropic_encode_tools(defs)

        assert.is_table(payload)
        assert.equals(1, #payload)
        assert.equals("read_file", payload[1].name)
        assert.equals("Read a file.", payload[1].description)
        assert.equals("object", payload[1].input_schema.type)
        assert.is_table(payload[1].input_schema.properties)
        assert.is_table(payload[1].input_schema.required)
    end)

    it("converts multiple definitions preserving input order", function()
        registry.register(fresh_def("alpha"))
        registry.register(fresh_def("beta"))
        registry.register(fresh_def("gamma"))
        local defs = registry.select({ "gamma", "alpha", "beta" })
        local payload = providers.anthropic_encode_tools(defs)

        assert.equals(3, #payload)
        assert.equals("gamma", payload[1].name)
        assert.equals("alpha", payload[2].name)
        assert.equals("beta", payload[3].name)
    end)

    it("returns an empty table on empty input", function()
        assert.same({}, providers.anthropic_encode_tools({}))
    end)

    it("returns an empty table on nil input", function()
        assert.same({}, providers.anthropic_encode_tools(nil))
    end)

    it("drops handler field from output (not sent to API)", function()
        registry.register(fresh_def("read_file"))
        local defs = registry.select({ "read_file" })
        local payload = providers.anthropic_encode_tools(defs)
        assert.is_nil(payload[1].handler)
    end)

    it("drops kind and needs_backup metadata (dispatcher-internal only)", function()
        registry.register({
            name = "write_file",
            description = "Write a file.",
            input_schema = { type = "object" },
            handler = function() end,
            kind = "write",
            needs_backup = true,
        })
        local defs = registry.select({ "write_file" })
        local payload = providers.anthropic_encode_tools(defs)
        assert.is_nil(payload[1].kind)
        assert.is_nil(payload[1].needs_backup)
    end)
end)
