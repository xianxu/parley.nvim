-- Unit tests for pure functions in lua/parley/helper.lua
-- These functions only use Lua stdlib or vim.* calls that are safe headlessly.

local helper = require("parley.helper")

describe("helper.uuid", function()
    it("returns a string", function()
        assert.is_string(helper.uuid())
    end)

    it("matches the expected xxxxxxxx_xxxx_4xxx_yxxx_xxxxxxxxxxxx pattern", function()
        local uuid = helper.uuid()
        -- pattern: 8 hex _ 4 hex _ 4xxx _ yxxx _ 12 hex
        assert.is_truthy(uuid:match("^%x%x%x%x%x%x%x%x_%x%x%x%x_4%x%x%x_%x%x%x%x_%x%x%x%x%x%x%x%x%x%x%x%x$"))
    end)

    it("returns unique values on successive calls", function()
        local ids = {}
        for _ = 1, 20 do
            table.insert(ids, helper.uuid())
        end
        -- check all 20 are distinct
        local seen = {}
        for _, id in ipairs(ids) do
            assert.is_nil(seen[id], "duplicate uuid: " .. id)
            seen[id] = true
        end
    end)
end)

describe("helper.starts_with", function()
    it("returns true when string starts with prefix", function()
        assert.is_true(helper.starts_with("hello world", "hello"))
    end)

    it("returns true for empty prefix (always matches)", function()
        assert.is_true(helper.starts_with("anything", ""))
    end)

    it("returns false when string does not start with prefix", function()
        assert.is_false(helper.starts_with("hello world", "world"))
    end)

    it("returns false for partial prefix mismatch", function()
        assert.is_false(helper.starts_with("hello", "hell!"))
    end)

    it("returns true when string equals prefix exactly", function()
        assert.is_true(helper.starts_with("exact", "exact"))
    end)

    it("returns false when prefix is longer than string", function()
        assert.is_false(helper.starts_with("hi", "hello"))
    end)
end)

describe("helper.ends_with", function()
    it("returns true when string ends with suffix", function()
        assert.is_true(helper.ends_with("hello world", "world"))
    end)

    it("returns true for empty suffix (always matches)", function()
        assert.is_true(helper.ends_with("anything", ""))
    end)

    it("returns false when string does not end with suffix", function()
        assert.is_false(helper.ends_with("hello world", "hello"))
    end)

    it("returns true when string equals suffix exactly", function()
        assert.is_true(helper.ends_with("exact", "exact"))
    end)

    it("returns false when suffix is longer than string", function()
        assert.is_false(helper.ends_with("hi", "hello"))
    end)

    it("works with file extension patterns", function()
        assert.is_true(helper.ends_with("chat.md", ".md"))
        assert.is_false(helper.ends_with("chat.lua", ".md"))
    end)
end)
