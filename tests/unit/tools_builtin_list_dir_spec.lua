-- Tests for lua/parley/tools/builtin/list_dir.lua

local list_dir_def = require("parley.tools.builtin.list_dir")
local handler = list_dir_def.handler

describe("list_dir tool", function()
    it("lists files in current directory", function()
        local r = handler({ path = "." })
        assert.is_false(r.is_error)
        assert.truthy(r.content:match("ARCH%.md"))
        assert.truthy(r.content:match("lua/"))
    end)

    it("directories have trailing slash", function()
        local r = handler({ path = "." })
        assert.is_false(r.is_error)
        assert.truthy(r.content:match("lua/\n") or r.content:match("lua/$"))
    end)

    it("shallow listing does not recurse", function()
        local r = handler({ path = ".", max_depth = 1 })
        assert.is_false(r.is_error)
        -- Should have lua/ but not lua/parley/
        assert.truthy(r.content:match("lua/"))
        assert.falsy(r.content:match("lua/parley/"))
    end)

    it("max_depth=2 recurses one level", function()
        local r = handler({ path = ".", max_depth = 2 })
        assert.is_false(r.is_error)
        assert.truthy(r.content:match("lua/parley/"))
    end)

    it("returns error for non-existent path", function()
        local r = handler({ path = "nonexistent_dir_xyz" })
        assert.is_true(r.is_error)
        assert.truthy(r.content:match("does not exist"))
    end)

    it("returns error for missing path", function()
        local r = handler({})
        assert.is_true(r.is_error)
        assert.truthy(r.content:match("missing"))
    end)

    it("excludes hidden files", function()
        local r = handler({ path = ".", max_depth = 1 })
        assert.is_false(r.is_error)
        assert.falsy(r.content:match("%.git"))
    end)

    it("returns relative paths", function()
        local r = handler({ path = "." })
        assert.is_false(r.is_error)
        local first_line = r.content:match("^([^\n]+)")
        assert.falsy(first_line:match("^/"), "paths should be relative, got: " .. first_line)
    end)
end)
