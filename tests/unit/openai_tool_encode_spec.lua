-- Unit tests for wire_openai.encode_tools / encode_tool_choice (#198).
--
-- OpenAI wraps every tool in a `function` envelope:
--   { type = "function", function = { name, description, parameters } }
-- where `parameters` is the JSON Schema that Anthropic calls `input_schema`.
--
-- Parley's internal ToolDefinition carries extra fields (handler, kind,
-- needs_backup) that must NOT reach the API — same contract as the
-- anthropic encoder, different envelope.

local wire = require("parley.tools.wire_openai")

local function fresh_def(name, desc, schema)
    return {
        name = name,
        description = desc or ("Test tool " .. name),
        input_schema = schema or { type = "object" },
        handler = function() end,
        kind = "read",
    }
end

describe("wire_openai.encode_tools", function()
    it("wraps a ToolDefinition in the function envelope", function()
        local out = wire.encode_tools({
            fresh_def("read_file", "Read a file.", {
                type = "object",
                properties = { path = { type = "string" } },
                required = { "path" },
            }),
        })

        assert.equals(1, #out)
        assert.equals("function", out[1].type)
        assert.equals("read_file", out[1]["function"].name)
        assert.equals("Read a file.", out[1]["function"].description)
        assert.same({
            type = "object",
            properties = { path = { type = "string" } },
            required = { "path" },
        }, out[1]["function"].parameters)
    end)

    it("preserves order across several definitions", function()
        local out = wire.encode_tools({
            fresh_def("a"), fresh_def("b"), fresh_def("c"),
        })
        assert.equals(3, #out)
        assert.equals("a", out[1]["function"].name)
        assert.equals("b", out[2]["function"].name)
        assert.equals("c", out[3]["function"].name)
    end)

    it("drops internal ToolDefinition fields", function()
        local def = fresh_def("x")
        def.needs_backup = true
        local out = wire.encode_tools({ def })

        -- Neither the envelope nor the inner function object may carry them.
        assert.is_nil(out[1].handler)
        assert.is_nil(out[1].kind)
        assert.is_nil(out[1].needs_backup)
        assert.is_nil(out[1]["function"].handler)
        assert.is_nil(out[1]["function"].kind)
        assert.is_nil(out[1]["function"].needs_backup)
        assert.is_nil(out[1]["function"].input_schema)
    end)

    -- THE case that bites in Lua: an empty table JSON-encodes as `[]`, and
    -- OpenAI rejects an array where an object schema belongs. The anthropic
    -- content-block path already hit this (chat_respond.lua, #155).
    it("encodes an empty input_schema as {} rather than []", function()
        local out = wire.encode_tools({ fresh_def("noargs", "No arguments.", {}) })
        assert.equals("{}", vim.json.encode(out[1]["function"].parameters))
    end)

    it("encodes a nil input_schema as {} rather than null", function()
        local def = fresh_def("noargs")
        def.input_schema = nil
        local out = wire.encode_tools({ def })
        assert.equals("{}", vim.json.encode(out[1]["function"].parameters))
    end)

    it("returns an empty list for nil input", function()
        assert.same({}, wire.encode_tools(nil))
    end)

    it("returns an empty list for an empty list", function()
        assert.same({}, wire.encode_tools({}))
    end)

    it("encodes the whole tools array as a JSON array", function()
        -- Guards the outer shape too: `tools` must be a list, not an object.
        local encoded = vim.json.encode(wire.encode_tools({ fresh_def("a") }))
        assert.equals("[", encoded:sub(1, 1))
    end)
end)

describe("wire_openai.encode_tool_choice", function()
    it("wraps the tool name in the function envelope", function()
        assert.same(
            { type = "function", ["function"] = { name = "propose_edits" } },
            wire.encode_tool_choice("propose_edits")
        )
    end)

    it("differs from the anthropic spelling", function()
        -- The reason tool_choice is wire knowledge at all: the two families
        -- spell a forced tool differently, so skill manifests carry the NAME
        -- and the wire shapes it (#198).
        local anthropic = require("parley.tools.wire_anthropic")
        assert.are_not.same(
            anthropic.encode_tool_choice("propose_edits"),
            wire.encode_tool_choice("propose_edits")
        )
    end)
end)
