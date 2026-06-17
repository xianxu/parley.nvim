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

describe("propose_edits via dispatcher.execute_call (cwd-scope keystone)", function()
    -- The reason propose_edits is a real tool: routing edit-apply through
    -- execute_call inherits the cwd-scope guard via the file_path field. Pin it
    -- end-to-end (the handler-only tests above bypass the dispatcher).
    local registry = require("parley.tools")
    local dispatcher = require("parley.tools.dispatcher")
    local cwd

    before_each(function()
        registry.register_builtins() -- propose_edits is in BUILTIN_NAMES
        cwd = vim.fn.tempname() .. "-pe-cwd"
        vim.fn.mkdir(cwd, "p")
    end)
    after_each(function()
        vim.fn.delete(cwd, "rf")
    end)

    it("applies edits when file_path is inside cwd", function()
        local path = cwd .. "/doc.md"
        vim.fn.writefile({ "alpha beta" }, path)
        local res = dispatcher.execute_call(
            { id = "t1", name = "propose_edits", input = {
                file_path = path,
                edits = { { old_string = "alpha", new_string = "ALPHA", explain = "a" } },
            } },
            registry,
            { cwd = cwd }
        )
        assert.is_falsy(res.is_error)
        assert.are.equal("ALPHA beta", table.concat(vim.fn.readfile(path), "\n"))
    end)

    it("refuses a file_path outside cwd (the cwd-scope guard fires)", function()
        local outside = vim.fn.tempname() .. "-pe-outside.md"
        vim.fn.writefile({ "x" }, outside)
        local res = dispatcher.execute_call(
            { id = "t2", name = "propose_edits", input = {
                file_path = outside,
                edits = { { old_string = "x", new_string = "y", explain = "e" } },
            } },
            registry,
            { cwd = cwd }
        )
        assert.is_true(res.is_error)
        assert.matches("outside working directory", res.content)
        assert.are.equal("x", table.concat(vim.fn.readfile(outside), "\n")) -- untouched
        vim.fn.delete(outside)
    end)
end)
