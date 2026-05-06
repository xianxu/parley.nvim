-- Unit tests for lua/parley/raw_log.lua

local raw_log = require("parley.raw_log")

local function tmp_chat_path()
    local tmp = (os.getenv("TMPDIR") or "/tmp") .. "/claude/parley-test-raw-log-" .. os.time() .. "-" .. math.random(100000)
    vim.fn.mkdir(tmp, "p")
    return tmp .. "/2026-05-06.10-00-00.000-test.md"
end

local function read(path)
    local f = io.open(path, "r")
    if not f then return nil end
    local s = f:read("*a")
    f:close()
    return s
end

local function rm_dir(dir)
    pcall(vim.fn.delete, dir, "rf")
end

describe("raw_log.log_dir_for / log_path_for", function()
    it("uses the chat file's containing directory and basename-without-ext", function()
        local dir = raw_log.log_dir_for("/tmp/parley/2026-05-06.foo.md")
        assert.equals("/tmp/parley/.parley-logs/2026-05-06.foo", dir)
    end)

    it("returns the right path for each kind", function()
        assert.equals(
            "/tmp/parley/.parley-logs/x/exchange.md",
            raw_log.log_path_for("/tmp/parley/x.md", "exchange")
        )
        assert.equals(
            "/tmp/parley/.parley-logs/x/raw.md",
            raw_log.log_path_for("/tmp/parley/x.md", "raw")
        )
    end)
end)

describe("raw_log.next_turn_number", function()
    it("returns 1 for a missing file", function()
        local path = (os.getenv("TMPDIR") or "/tmp") .. "/claude/parley-nonexistent-" .. os.time() .. ".md"
        assert.equals(1, raw_log.next_turn_number(path))
    end)

    it("returns 1 for an empty file", function()
        local p = (os.getenv("TMPDIR") or "/tmp") .. "/claude/parley-empty-" .. os.time() .. ".md"
        local f = io.open(p, "w"); f:write(""); f:close()
        assert.equals(1, raw_log.next_turn_number(p))
        os.remove(p)
    end)

    it("counts existing ## Turn headers", function()
        local p = (os.getenv("TMPDIR") or "/tmp") .. "/claude/parley-turns-" .. os.time() .. ".md"
        local f = io.open(p, "w")
        f:write("# header\n\n## Turn 1 — ts\nbody\n\n## Turn 2 — ts\nbody\n")
        f:close()
        assert.equals(3, raw_log.next_turn_number(p))
        os.remove(p)
    end)
end)

describe("raw_log.write_exchange_turn", function()
    local chat_path
    before_each(function() chat_path = tmp_chat_path() end)
    after_each(function() rm_dir(raw_log.log_dir_for(chat_path)) end)

    it("creates the log directory and file with a header on first write", function()
        raw_log.write_exchange_turn(chat_path, { { role = "user", content = "hello" } })
        local content = read(raw_log.log_path_for(chat_path, "exchange"))
        assert.is_not_nil(content)
        assert.truthy(content:find("# Exchange log for ", 1, true))
        assert.truthy(content:find("## Turn 1 — ", 1, true))
        assert.truthy(content:find("### user", 1, true))
        assert.truthy(content:find("hello", 1, true))
    end)

    it("increments turn numbers across multiple writes", function()
        raw_log.write_exchange_turn(chat_path, { { role = "user", content = "first" } })
        raw_log.write_exchange_turn(chat_path, { { role = "user", content = "second" } })
        local content = read(raw_log.log_path_for(chat_path, "exchange"))
        assert.truthy(content:find("## Turn 1 — ", 1, true))
        assert.truthy(content:find("## Turn 2 — ", 1, true))
    end)

    it("no-ops when chat_path is empty", function()
        -- Should not error; nothing on disk.
        raw_log.write_exchange_turn("", { { role = "user", content = "x" } })
        raw_log.write_exchange_turn(nil, { { role = "user", content = "x" } })
    end)
end)

describe("raw_log.write_raw_turn", function()
    local chat_path
    before_each(function() chat_path = tmp_chat_path() end)
    after_each(function() rm_dir(raw_log.log_dir_for(chat_path)) end)

    it("writes the request, assembled, and sse subsections", function()
        raw_log.write_raw_turn(chat_path, {
            request = { model = "x", max_tokens = 4, messages = { { role = "user", content = "hi" } } },
            assembled = { stop_reason = "end_turn", content = { { type = "text", text = "yo" } } },
            sse_lines = { "event: foo", "data: {}", "" },
        })
        local content = read(raw_log.log_path_for(chat_path, "raw"))
        assert.is_not_nil(content)
        assert.truthy(content:find("# Raw log for ", 1, true))
        assert.truthy(content:find("## Turn 1 — ", 1, true))
        assert.truthy(content:find("### Request payload (yaml)", 1, true))
        assert.truthy(content:find("### Response (assembled, yaml)", 1, true))
        assert.truthy(content:find("### Response (raw SSE)", 1, true))
        assert.truthy(content:find("model: x", 1, true))
        assert.truthy(content:find("event: foo", 1, true))
    end)
end)
