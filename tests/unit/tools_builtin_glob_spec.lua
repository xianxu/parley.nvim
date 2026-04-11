-- Tests for lua/parley/tools/builtin/glob.lua

local glob_def = require("parley.tools.builtin.glob")
local handler = glob_def.handler

describe("glob tool", function()
    it("finds lua files recursively with **/*.lua", function()
        local r = handler({ pattern = "**/*.lua" })
        assert.is_false(r.is_error)
        assert.truthy(r.content:match("lua/parley/init%.lua"))
    end)

    it("finds markdown files in root with *.md", function()
        local r = handler({ pattern = "*.md" })
        assert.is_false(r.is_error)
        assert.truthy(r.content:match("ARCH%.md"))
        -- Should NOT include files in subdirectories
        assert.falsy(r.content:match("lua/"))
    end)

    it("finds files in a subdirectory with lua/**/*.lua", function()
        local r = handler({ pattern = "lua/**/*.lua" })
        assert.is_false(r.is_error)
        assert.truthy(r.content:match("lua/parley/init%.lua"))
        -- Should NOT include test files
        assert.falsy(r.content:match("tests/"))
    end)

    it("supports path parameter as base directory", function()
        local r = handler({ pattern = "*.lua", path = "lua/parley/tools" })
        assert.is_false(r.is_error)
        assert.truthy(r.content:match("init%.lua"))
        assert.truthy(r.content:match("serialize%.lua"))
    end)

    it("returns empty for non-matching pattern", function()
        local r = handler({ pattern = "**/*.nonexistent_extension_xyz" })
        assert.is_false(r.is_error)
        assert.equals("", r.content)
    end)

    it("returns error for missing pattern", function()
        local r = handler({})
        assert.is_true(r.is_error)
        assert.truthy(r.content:match("missing"))
    end)

    it("excludes hidden files and directories", function()
        local r = handler({ pattern = "**/*" })
        assert.is_false(r.is_error)
        assert.falsy(r.content:match("%.git/"))
    end)

    it("returns relative paths, not absolute", function()
        local r = handler({ pattern = "**/*.lua" })
        assert.is_false(r.is_error)
        local first_line = r.content:match("^([^\n]+)")
        assert.falsy(first_line:match("^/"), "paths should be relative, got: " .. first_line)
    end)
end)
