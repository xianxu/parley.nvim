-- Unit tests for lua/parley/tools/builtin/propose_edits.lua
--
-- propose_edits is the P2 (artifact-workbench) edit tool: a real registered
-- builtin whose handler applies a batch of {old_string,new_string,explain}
-- edits to file_path via skill_edits.compute_edits. Making it a real tool means
-- P2's edit-apply flows through the SAME dispatcher execute_call path (cwd-scope
-- + the M5 backup prelude) as every chat tool — no special-casing.

local propose_edits = require("parley.tools.builtin.propose_edits")
local types = require("parley.tools.types")

local function tmpfile(content)
    local path = vim.fn.tempname() .. "-propose-edits.md"
    vim.fn.writefile(vim.split(content, "\n", { plain = true }), path)
    return path
end

local function read(path)
    return table.concat(vim.fn.readfile(path), "\n")
end

describe("propose_edits tool definition", function()
    it("is a valid write ToolDefinition", function()
        local ok, err = types.validate_definition(propose_edits)
        assert.is_true(ok, tostring(err))
        assert.are.equal("propose_edits", propose_edits.name)
        assert.are.equal("write", propose_edits.kind)
        assert.is_true(propose_edits.needs_backup)
    end)
end)

describe("propose_edits handler", function()
    it("applies a batch of edits to file_path", function()
        local path = tmpfile("alpha beta gamma")
        local res = propose_edits.handler({
            file_path = path,
            edits = {
                { old_string = "alpha", new_string = "ALPHA", explain = "a" },
                { old_string = "gamma", new_string = "GAMMA", explain = "g" },
            },
        })
        assert.is_falsy(res.is_error)
        assert.are.equal("ALPHA beta GAMMA", read(path))
        assert.matches("2", res.content) -- reports applied count
        vim.fn.delete(path)
    end)

    it("errors and leaves the file unchanged on a non-unique old_string", function()
        local path = tmpfile("ab ab")
        local res = propose_edits.handler({
            file_path = path,
            edits = { { old_string = "ab", new_string = "X", explain = "e" } },
        })
        assert.is_true(res.is_error)
        assert.are.equal("ab ab", read(path)) -- untouched
        vim.fn.delete(path)
    end)

    it("errors on a missing file_path", function()
        local res = propose_edits.handler({ edits = {} })
        assert.is_true(res.is_error)
        assert.matches("file_path", res.content)
    end)

    it("errors on missing/invalid edits", function()
        local res = propose_edits.handler({ file_path = "/tmp/x.md" })
        assert.is_true(res.is_error)
        assert.matches("edits", res.content)
    end)
end)
