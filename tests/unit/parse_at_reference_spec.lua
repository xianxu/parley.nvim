-- Unit tests for M._parse_at_reference in lua/parley/init.lua
--
-- Uses canonical @@ref@@ syntax with explicit closing marker.

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
    it("returns nil when no @@ref@@ found in line", function()
        local result = parley._parse_at_reference("This is a line without any markers", 10)
        assert.is_nil(result)
    end)

    it("returns nil when unclosed @@ (no closing @@)", function()
        local result = parley._parse_at_reference("See @@/path/to/file.txt for details", 10)
        assert.is_nil(result)
    end)

    it("returns path for single @@ref@@", function()
        local result = parley._parse_at_reference("See @@/path/to/file.txt@@ for details", 10)
        assert.equals("/path/to/file.txt", result)
    end)

    it("trims whitespace inside markers", function()
        local result = parley._parse_at_reference("See @@  /path/to/file.txt  @@ ok", 10)
        assert.equals("/path/to/file.txt", result)
    end)

    it("returns first ref when cursor near first of two references", function()
        local line = "Check @@/first/file.txt@@ and @@/second/file.txt@@"
        local result = parley._parse_at_reference(line, 10) -- near first @@
        assert.equals("/first/file.txt", result)
    end)

    it("returns second ref when cursor near second of two references", function()
        local line = "Check @@/first/file.txt@@ and @@/second/file.txt@@"
        local result = parley._parse_at_reference(line, 40) -- near second @@
        assert.equals("/second/file.txt", result)
    end)

    it("handles path with spaces inside markers", function()
        local result = parley._parse_at_reference("@@/path with spaces/file.txt@@", 5)
        assert.equals("/path with spaces/file.txt", result)
    end)

    it("handles URL reference", function()
        local result = parley._parse_at_reference("See @@https://example.com/page@@ for info", 10)
        assert.equals("https://example.com/page", result)
    end)

    it("cursor after all references returns last reference", function()
        local line = "@@/first/file@@ @@/second/file@@"
        local result = parley._parse_at_reference(line, 100)
        assert.equals("/second/file", result)
    end)

    it("cursor before all references returns first reference", function()
        local line = "Some text @@/first/file@@ @@/second/file@@"
        local result = parley._parse_at_reference(line, 1)
        assert.is_not_nil(result)
    end)

    it("returns nil when only @@ with nothing between markers", function()
        local result = parley._parse_at_reference("See @@@@", 5)
        assert.is_nil(result)
    end)
end)
