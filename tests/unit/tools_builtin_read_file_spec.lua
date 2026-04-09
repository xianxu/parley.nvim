-- Unit tests for lua/parley/tools/builtin/read_file.lua
--
-- Real handler that reads a file from disk and returns its content
-- with 1-indexed line numbers. PURE: no cwd-scope check (dispatcher
-- enforces that), no caching, no vim-buffer interaction. Accepts
-- optional line_start / line_end range; returns is_error=true for
-- missing files or bad inputs.
--
-- Handlers intentionally omit the `id` field on their result — the
-- dispatcher stamps it at execute time. See types.lua ToolResult
-- contract note.

local read_file = require("parley.tools.builtin.read_file")

-- Sandbox-friendly scratch dir honoring $TMPDIR per the 5f3d9fc sweep.
local tmp_base = (os.getenv("TMPDIR") or "/tmp") .. "/claude/parley-test-read-file-" .. os.time()
vim.fn.mkdir(tmp_base, "p")

-- Write a fresh scratch file for each test so content is deterministic.
local function write_scratch(name, lines)
    local path = tmp_base .. "/" .. name
    vim.fn.writefile(lines, path)
    return path
end

describe("read_file handler: happy path", function()
    it("returns content with 1-indexed line numbers", function()
        local path = write_scratch("a.txt", { "first", "second", "third" })
        local result = read_file.handler({ path = path })
        assert.is_false(result.is_error)
        -- Each line prefixed with its line number; exact format is
        -- "%5d  %s" by convention (5-col right-aligned number + 2 spaces)
        assert.matches("%s*1%s+first", result.content)
        assert.matches("%s*2%s+second", result.content)
        assert.matches("%s*3%s+third", result.content)
    end)

    it("returns empty content for an empty file", function()
        local path = write_scratch("empty.txt", {})
        local result = read_file.handler({ path = path })
        assert.is_false(result.is_error)
        assert.equals("", result.content)
    end)

    it("handles a single-line file", function()
        local path = write_scratch("one.txt", { "only line" })
        local result = read_file.handler({ path = path })
        assert.is_false(result.is_error)
        assert.matches("1%s+only line", result.content)
    end)

    it("stamps name field on the result for dispatcher serialization", function()
        local path = write_scratch("named.txt", { "x" })
        local result = read_file.handler({ path = path })
        assert.equals("read_file", result.name)
    end)
end)

describe("read_file handler: line range", function()
    it("respects line_start inclusive", function()
        local path = write_scratch("range.txt", { "a", "b", "c", "d", "e" })
        local result = read_file.handler({ path = path, line_start = 3 })
        assert.is_false(result.is_error)
        assert.not_matches("1%s+a", result.content)
        assert.not_matches("2%s+b", result.content)
        assert.matches("3%s+c", result.content)
        assert.matches("4%s+d", result.content)
        assert.matches("5%s+e", result.content)
    end)

    it("respects line_end inclusive", function()
        local path = write_scratch("range2.txt", { "a", "b", "c", "d", "e" })
        local result = read_file.handler({ path = path, line_end = 2 })
        assert.is_false(result.is_error)
        assert.matches("1%s+a", result.content)
        assert.matches("2%s+b", result.content)
        assert.not_matches("3%s+c", result.content)
    end)

    it("respects both line_start and line_end", function()
        local path = write_scratch("range3.txt", { "a", "b", "c", "d", "e" })
        local result = read_file.handler({ path = path, line_start = 2, line_end = 4 })
        assert.is_false(result.is_error)
        assert.not_matches("1%s+a", result.content)
        assert.matches("2%s+b", result.content)
        assert.matches("3%s+c", result.content)
        assert.matches("4%s+d", result.content)
        assert.not_matches("5%s+e", result.content)
    end)

    it("line_start beyond EOF returns empty content (not an error)", function()
        local path = write_scratch("short.txt", { "a", "b" })
        local result = read_file.handler({ path = path, line_start = 10 })
        assert.is_false(result.is_error)
        assert.equals("", result.content)
    end)

    it("line_start == line_end returns exactly one line", function()
        local path = write_scratch("exact.txt", { "a", "b", "c" })
        local result = read_file.handler({ path = path, line_start = 2, line_end = 2 })
        assert.is_false(result.is_error)
        assert.matches("2%s+b", result.content)
        assert.not_matches("1%s+a", result.content)
        assert.not_matches("3%s+c", result.content)
    end)
end)

describe("read_file handler: error cases", function()
    it("returns is_error=true when path is missing", function()
        local result = read_file.handler({})
        assert.is_true(result.is_error)
        assert.matches("path", result.content)
    end)

    it("returns is_error=true when path is not a string", function()
        local result = read_file.handler({ path = 42 })
        assert.is_true(result.is_error)
        assert.matches("path", result.content)
    end)

    it("returns is_error=true when file does not exist", function()
        local result = read_file.handler({ path = tmp_base .. "/does_not_exist.txt" })
        assert.is_true(result.is_error)
        assert.matches("cannot", result.content)
    end)
end)

describe("read_file handler: purity", function()
    it("does not mutate input", function()
        local input = { path = write_scratch("purity.txt", { "x" }) }
        local before = vim.deepcopy(input)
        read_file.handler(input)
        assert.same(before, input)
    end)

    it("returns same output for same input (deterministic)", function()
        local path = write_scratch("determ.txt", { "one", "two" })
        local r1 = read_file.handler({ path = path })
        local r2 = read_file.handler({ path = path })
        assert.equals(r1.content, r2.content)
        assert.equals(r1.is_error, r2.is_error)
    end)

    it("does not stamp the id field (dispatcher's job)", function()
        local path = write_scratch("noid.txt", { "x" })
        local result = read_file.handler({ path = path })
        -- id may be nil OR empty string — contract is "absent or blank,
        -- dispatcher sets it". Handlers must not fabricate an id.
        assert.is_true(result.id == nil or result.id == "")
    end)
end)
