-- Integration tests for lua/parley/discovery/local_types.lua
--
-- LocalTypeDiscovery is the grep-backed *production* behind the registry
-- interface: it discovers a repo's NOVEL `type:` values (those not already in
-- the parley-shipped base) and synthesizes a minimal `local` TypeDescriptor
-- for each. Real `rg` over a temp fixture dir — no network, no mocks.

local local_types = require("parley.discovery.local_types")
local descriptor = require("parley.discovery.descriptor")

local function by_name(list, name)
    for _, d in ipairs(list) do
        if d.name == name then
            return d
        end
    end
    return nil
end

local function write(path, type_value)
    local lines = type_value and { "---", "type: " .. type_value, "---", "body" } or { "no frontmatter" }
    vim.fn.writefile(lines, path)
end

describe("local_types.discover", function()
    local root = vim.fn.tempname() .. "-parley-discovery-local"

    before_each(function()
        vim.fn.mkdir(root, "p")
        write(root .. "/a.md", "pensive") -- in base → excluded
        write(root .. "/b.md", "widget") -- novel
        write(root .. "/c.md", "gadget") -- novel
        write(root .. "/d.md", "widget-spec") -- novel + hyphen guard
        write(root .. "/e.md", nil) -- no type: → ignored
    end)

    after_each(function()
        vim.fn.delete(root, "rf")
    end)

    it("returns only novel types (base subtracted), incl. hyphenated values", function()
        local got = local_types.discover(root, { "pensive", "prose", "continuation" })
        local names = vim.tbl_map(function(d) return d.name end, got)
        table.sort(names)
        assert.are.same({ "gadget", "widget", "widget-spec" }, names)
    end)

    it("synthesizes a valid `local` frontmatter descriptor per novel type", function()
        local got = local_types.discover(root, { "pensive" })
        local widget = by_name(got, "widget")
        assert.is_not_nil(widget)
        local ok, err = descriptor.validate(widget)
        assert.is_true(ok, tostring(err))
        assert.are.equal("local", widget.scope)
        assert.are.equal("frontmatter", widget.matcher.kind)
        assert.are.equal("type", widget.matcher.field)
        assert.are.equal("widget", widget.matcher.value)
    end)

    it("returns an empty list when the repo has no novel types", function()
        local only_base = vim.fn.tempname() .. "-parley-discovery-base-only"
        vim.fn.mkdir(only_base, "p")
        write(only_base .. "/x.md", "pensive")
        local got = local_types.discover(only_base, { "pensive" })
        assert.are.same({}, got)
        vim.fn.delete(only_base, "rf")
    end)

    it("ignores files with no `type:` frontmatter", function()
        local got = local_types.discover(root, { "pensive", "widget", "gadget", "widget-spec" })
        -- every novel type is also in base_names here → nothing left
        assert.are.same({}, got)
    end)
end)
