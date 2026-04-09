-- Unit tests for builtin tool registration.
--
-- At M1, all six builtin tools (read_file, list_dir, grep, glob,
-- edit_file, write_file) ship as stubs returning `is_error=true` with
-- a "not yet implemented" body. Real handlers land in M2–M5. This
-- spec verifies that:
--
--   1. `parley.tools.register_builtins()` registers exactly the six
--      expected names.
--   2. Each builtin is a valid ToolDefinition per types.validate_definition.
--   3. Each stub handler returns is_error=true (they MUST be stubs
--      at M1; real handlers replace them in later milestones).
--   4. `register_builtins()` is idempotent — calling it twice does
--      not duplicate or error.

local registry = require("parley.tools")
local types = require("parley.tools.types")

local EXPECTED_BUILTINS = {
    "read_file",
    "list_dir",
    "grep",
    "glob",
    "edit_file",
    "write_file",
}

describe("register_builtins", function()
    before_each(function()
        registry.reset()
    end)

    it("registers all six expected builtin names", function()
        registry.register_builtins()
        local names = registry.list_names()
        table.sort(names)
        local expected = vim.deepcopy(EXPECTED_BUILTINS)
        table.sort(expected)
        assert.same(expected, names)
    end)

    it("each builtin passes types.validate_definition", function()
        registry.register_builtins()
        for _, name in ipairs(EXPECTED_BUILTINS) do
            local def = registry.get(name)
            assert.is_not_nil(def, "missing builtin: " .. name)
            local ok, err = types.validate_definition(def)
            assert.is_true(ok, "invalid builtin " .. name .. ": " .. tostring(err))
        end
    end)

    it("each builtin has a non-empty description", function()
        registry.register_builtins()
        for _, name in ipairs(EXPECTED_BUILTINS) do
            local def = registry.get(name)
            assert.is_string(def.description)
            assert.is_true(#def.description > 0)
        end
    end)

    it("each builtin has an object-typed input_schema", function()
        registry.register_builtins()
        for _, name in ipairs(EXPECTED_BUILTINS) do
            local def = registry.get(name)
            assert.is_table(def.input_schema)
            assert.equals("object", def.input_schema.type)
        end
    end)

    it("each M1 stub handler returns is_error=true", function()
        registry.register_builtins()
        for _, name in ipairs(EXPECTED_BUILTINS) do
            local def = registry.get(name)
            local result = def.handler({})
            assert.is_table(result)
            assert.is_true(result.is_error, name .. " stub should return is_error=true")
            assert.is_string(result.content)
        end
    end)

    it("is idempotent — calling register_builtins twice does not error", function()
        registry.register_builtins()
        registry.register_builtins()
        local names = registry.list_names()
        assert.equals(6, #names)
    end)

    it("write-type builtins declare kind = 'write'", function()
        registry.register_builtins()
        assert.equals("write", registry.get("edit_file").kind)
        assert.equals("write", registry.get("write_file").kind)
    end)

    it("write_file declares needs_backup = true (for M5 dispatcher)", function()
        registry.register_builtins()
        assert.is_true(registry.get("write_file").needs_backup)
    end)

    it("edit_file declares needs_backup = false (delta is in the call)", function()
        registry.register_builtins()
        -- needs_backup may be false or nil (both mean no backup)
        local edit = registry.get("edit_file")
        assert.is_true(edit.needs_backup == false or edit.needs_backup == nil)
    end)

    it("read-type builtins declare kind = 'read' (or nil defaulting to read)", function()
        registry.register_builtins()
        for _, name in ipairs({ "read_file", "list_dir", "grep", "glob" }) do
            local kind = registry.get(name).kind
            assert.is_true(kind == "read" or kind == nil,
                name .. " expected kind 'read' or nil, got " .. tostring(kind))
        end
    end)
end)
