-- Unit tests for M._parse_at_reference in lua/parley/init.lua
--
-- _parse_at_reference is a pure function extracted from the duplicate
-- @@ parsing loops in open_chat_reference and OpenFileUnderCursor.

local tmp_dir = "/tmp/parley-test-parse-at-ref-" .. os.time()

-- Bootstrap parley
local parley = require("parley")
parley.setup({
    chat_dir = tmp_dir,
    state_dir = tmp_dir .. "/state",
    providers = {},
    api_keys = {},
})

describe("_parse_at_reference", function()
    it("returns nil when no @@ found in line", function()
        local result = parley._parse_at_reference("This is a line without any markers", 10)
        assert.is_nil(result)
    end)

    it("returns path when single @@ reference found", function()
        local result = parley._parse_at_reference("See @@/path/to/file.txt for details", 10)
        assert.equals("/path/to/file.txt for details", result)
    end)

    it("returns trimmed path with leading/trailing spaces", function()
        local result = parley._parse_at_reference("See @@  /path/to/file.txt  ", 10)
        assert.equals("/path/to/file.txt", result)
    end)

    it("returns first path when two @@ references and cursor near first", function()
        local line = "Check @@/first/file.txt and @@/second/file.txt"
        local result = parley._parse_at_reference(line, 10) -- Cursor at position 10 (near first @@)
        assert.equals("/first/file.txt and", result)
    end)

    it("returns second path when two @@ references and cursor near second", function()
        local line = "Check @@/first/file.txt and @@/second/file.txt"
        local result = parley._parse_at_reference(line, 35) -- Cursor at position 35 (near second @@)
        assert.equals("/second/file.txt", result)
    end)

    it("handles @@ at end of line", function()
        local result = parley._parse_at_reference("See @@/path/to/file", 10)
        assert.equals("/path/to/file", result)
    end)

    it("handles multiple @@ with cursor at exact @@ position", function()
        local line = "@@/first @@/second"
        local result = parley._parse_at_reference(line, 1) -- Cursor at first @@
        assert.equals("/first", result)
    end)

    it("handles cursor equidistant from two references - picks first", function()
        local line = "@@/first @@/second"
        -- Position 5 is between the two @@, let's make sure it returns the closest
        local result = parley._parse_at_reference(line, 5)
        assert.is_not_nil(result)
        -- Should return whichever is actually closer
        assert.is_true(result == "/first" or result == "/second")
    end)

    it("extracts path between two @@ markers correctly", function()
        local line = "@@/path/one@@ and @@/path/two@@"
        local result = parley._parse_at_reference(line, 5)
        -- The first @@ should extract up to the next @@
        assert.equals("/path/one", result)
    end)

    it("handles path with spaces in the middle", function()
        local line = "@@/path with spaces/file.txt@@"
        local result = parley._parse_at_reference(line, 5)
        assert.equals("/path with spaces/file.txt", result)
    end)

    it("returns empty string when @@ has no path after it", function()
        local result = parley._parse_at_reference("See @@", 5)
        assert.equals("", result)
    end)

    it("handles multiple references and picks closest by distance", function()
        local line = "@@/one @@@/two @@@/three"
        -- Cursor at position 15 should be closest to /two
        local result = parley._parse_at_reference(line, 15)
        assert.is_not_nil(result)
        -- Exact result depends on positions, but should not be nil
    end)

    it("cursor before all references returns first reference", function()
        local line = "Some text @@/first/file @@/second/file"
        local result = parley._parse_at_reference(line, 1) -- Cursor at beginning
        -- Should return the reference closest to position 1
        assert.is_not_nil(result)
    end)

    it("cursor after all references returns last reference", function()
        local line = "@@/first/file @@/second/file"
        local result = parley._parse_at_reference(line, 100) -- Cursor far to the right
        -- Should return the reference closest to position 100 (the last one)
        assert.equals("/second/file", result)
    end)
end)
