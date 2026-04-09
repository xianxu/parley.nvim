-- Unit tests for lua/parley/tools/dispatcher.lua
--
-- The tool dispatcher is the DRY safety layer that sits between the
-- tool_loop driver and individual handler functions. Handlers stay
-- pure (see types.lua ToolResult contract); every safety concern
-- lives here so there's one place to audit and one place to fix:
--
--   - resolve_path_in_cwd: cwd-scope check with symlink resolution
--   - truncate:            byte-length cap with trailing marker
--   - execute_call:        pcall-guarded handler invocation,
--                          stamps id/name on result, truncates,
--                          returns a well-shaped ToolResult no
--                          matter how the handler misbehaves
--
-- M2 Task 2.3 lands the read-path helpers. Dirty-buffer guard,
-- .parley-backup, and checktime-reload come in M5 Task 5.6.

local dispatcher = require("parley.tools.dispatcher")
local registry = require("parley.tools")

-- Shared sandbox-friendly tmp base.
local tmp_base = (os.getenv("TMPDIR") or "/tmp") .. "/claude/parley-test-tools-dispatcher-" .. os.time()
vim.fn.mkdir(tmp_base, "p")

-- Returns the canonical real path of a directory after fs_realpath
-- normalization, so tests compare apples to apples on macOS
-- (/tmp → /private/tmp etc).
local function canonical(path)
    return vim.loop.fs_realpath(path) or path
end

describe("resolve_path_in_cwd", function()
    local cwd
    before_each(function()
        cwd = tmp_base .. "/cwd-" .. math.random(0, 0xFFFFFF)
        vim.fn.mkdir(cwd, "p")
    end)

    it("resolves a relative path inside cwd to an absolute path", function()
        local target = cwd .. "/inside.txt"
        vim.fn.writefile({ "hi" }, target)
        local abs, err = dispatcher.resolve_path_in_cwd("inside.txt", cwd)
        assert.is_nil(err)
        assert.equals(canonical(target), abs)
    end)

    it("accepts an absolute path that lies inside cwd", function()
        local target = cwd .. "/inside.txt"
        vim.fn.writefile({ "hi" }, target)
        local abs, err = dispatcher.resolve_path_in_cwd(target, cwd)
        assert.is_nil(err)
        assert.equals(canonical(target), abs)
    end)

    it("rejects an absolute path outside cwd", function()
        local outside = tmp_base .. "/outside.txt"
        vim.fn.writefile({ "oops" }, outside)
        local abs, err = dispatcher.resolve_path_in_cwd(outside, cwd)
        assert.is_nil(abs)
        assert.is_string(err)
        assert.matches("outside working directory", err)
    end)

    it("rejects a relative path that escapes cwd via ..", function()
        local outside = tmp_base .. "/escape.txt"
        vim.fn.writefile({ "oops" }, outside)
        local abs, err = dispatcher.resolve_path_in_cwd("../escape.txt", cwd)
        assert.is_nil(abs)
        assert.matches("outside working directory", err)
    end)

    it("rejects a nested .. that ultimately escapes cwd", function()
        local abs, err = dispatcher.resolve_path_in_cwd("sub/../../outside.txt", cwd)
        assert.is_nil(abs)
        assert.matches("outside working directory", err)
    end)

    it("accepts a nested .. that stays within cwd", function()
        vim.fn.mkdir(cwd .. "/sub", "p")
        vim.fn.writefile({ "x" }, cwd .. "/inside.txt")
        local abs, err = dispatcher.resolve_path_in_cwd("sub/../inside.txt", cwd)
        assert.is_nil(err)
        assert.equals(canonical(cwd .. "/inside.txt"), abs)
    end)

    it("resolves symlinks pointing INSIDE cwd", function()
        vim.fn.writefile({ "target" }, cwd .. "/real.txt")
        -- Create a symlink inside cwd pointing to another file inside cwd
        vim.loop.fs_symlink(cwd .. "/real.txt", cwd .. "/link.txt")
        local abs, err = dispatcher.resolve_path_in_cwd("link.txt", cwd)
        assert.is_nil(err)
        assert.equals(canonical(cwd .. "/real.txt"), abs)
    end)

    it("REJECTS symlinks whose real path escapes cwd", function()
        -- Create a file outside cwd and a symlink inside cwd pointing to it.
        -- The symlink's lexical path is inside cwd but fs_realpath resolves
        -- outside. resolve_path_in_cwd MUST reject.
        local outside = tmp_base .. "/outside-target.txt"
        vim.fn.writefile({ "secret" }, outside)
        vim.loop.fs_symlink(outside, cwd .. "/escape_link.txt")
        local abs, err = dispatcher.resolve_path_in_cwd("escape_link.txt", cwd)
        assert.is_nil(abs)
        assert.matches("outside working directory", err)
    end)

    it("accepts a path to a NEW file (parent dir inside cwd, file doesn't exist)", function()
        -- write_file creates new files; the resolver must handle
        -- paths whose basename doesn't exist yet by realpath'ing the
        -- parent and appending the basename.
        local abs, err = dispatcher.resolve_path_in_cwd("new_file.txt", cwd)
        assert.is_nil(err)
        assert.equals(canonical(cwd) .. "/new_file.txt", abs)
    end)

    it("rejects a new file whose parent dir does not exist", function()
        local abs, err = dispatcher.resolve_path_in_cwd("nonexistent_dir/new.txt", cwd)
        assert.is_nil(abs)
        assert.is_string(err)
    end)

    it("rejects non-string path", function()
        local abs, err = dispatcher.resolve_path_in_cwd(nil, cwd)
        assert.is_nil(abs)
        assert.matches("path", err)
    end)

    it("rejects empty string path", function()
        local abs, err = dispatcher.resolve_path_in_cwd("", cwd)
        assert.is_nil(abs)
        assert.matches("path", err)
    end)
end)

describe("truncate", function()
    it("returns content unchanged when under the byte cap", function()
        assert.equals("hello", dispatcher.truncate("hello", 100))
    end)

    it("returns content unchanged when exactly at the byte cap", function()
        assert.equals("12345", dispatcher.truncate("12345", 5))
    end)

    it("truncates with trailing marker when over the cap", function()
        local out = dispatcher.truncate(string.rep("x", 100), 10)
        assert.equals("xxxxxxxxxx", out:sub(1, 10))
        assert.matches("truncated: 90 bytes omitted", out)
    end)

    it("handles nil content as empty string (no error)", function()
        assert.equals("", dispatcher.truncate(nil, 100))
    end)

    it("handles zero-length content", function()
        assert.equals("", dispatcher.truncate("", 100))
    end)
end)

describe("execute_call", function()
    before_each(function()
        registry.reset()
        registry.register({
            name = "echo",
            kind = "read",
            description = "Echo input",
            input_schema = { type = "object" },
            handler = function(input)
                return { content = "echo: " .. (input.message or ""), is_error = false, name = "echo" }
            end,
        })
    end)
    after_each(function()
        registry.register_builtins()
    end)

    it("looks up the tool, runs the handler, and stamps id+name", function()
        local call = { id = "toolu_01", name = "echo", input = { message = "hi" } }
        local result = dispatcher.execute_call(call, registry, {})
        assert.equals("toolu_01", result.id)
        assert.equals("echo", result.name)
        assert.equals("echo: hi", result.content)
        assert.equals(false, result.is_error)
    end)

    it("returns is_error on unknown tool name, with name in the message", function()
        local call = { id = "toolu_02", name = "nonexistent", input = {} }
        local result = dispatcher.execute_call(call, registry, {})
        assert.is_true(result.is_error)
        assert.matches("unknown tool", result.content)
        assert.matches("nonexistent", result.content)
        assert.equals("toolu_02", result.id)
    end)

    it("pcall-guards a raising handler and returns is_error", function()
        registry.register({
            name = "explode",
            kind = "read",
            description = "Raises on call",
            input_schema = { type = "object" },
            handler = function() error("boom") end,
        })
        local call = { id = "toolu_03", name = "explode", input = {} }
        local result = dispatcher.execute_call(call, registry, {})
        assert.is_true(result.is_error)
        assert.matches("handler error", result.content)
        assert.matches("boom", result.content)
        assert.equals("toolu_03", result.id)
        assert.equals("explode", result.name)
    end)

    it("handles a handler that returns non-table (defensive)", function()
        registry.register({
            name = "bad_return",
            kind = "read",
            description = "Returns a string",
            input_schema = { type = "object" },
            handler = function() return "not a table" end,
        })
        local call = { id = "toolu_04", name = "bad_return", input = {} }
        local result = dispatcher.execute_call(call, registry, {})
        assert.is_true(result.is_error)
        assert.matches("non%-table", result.content)
        assert.equals("toolu_04", result.id)
    end)

    it("truncates oversized content when max_bytes is provided", function()
        registry.register({
            name = "big",
            kind = "read",
            description = "Returns lots of data",
            input_schema = { type = "object" },
            handler = function()
                return { content = string.rep("x", 500), is_error = false, name = "big" }
            end,
        })
        local call = { id = "toolu_05", name = "big", input = {} }
        local result = dispatcher.execute_call(call, registry, { max_bytes = 100 })
        assert.matches("truncated: %d+ bytes omitted", result.content)
        assert.is_true(#result.content < 500)
    end)

    it("stamps id even on unknown-tool errors", function()
        local result = dispatcher.execute_call(
            { id = "toolu_06", name = "ghost", input = {} },
            registry,
            {}
        )
        assert.equals("toolu_06", result.id)
    end)

    it("stamps id even when handler raises", function()
        registry.register({
            name = "raiser",
            kind = "read",
            description = "x",
            input_schema = { type = "object" },
            handler = function() error("nope") end,
        })
        local result = dispatcher.execute_call(
            { id = "toolu_07", name = "raiser", input = {} },
            registry,
            {}
        )
        assert.equals("toolu_07", result.id)
        assert.is_true(result.is_error)
    end)
end)
