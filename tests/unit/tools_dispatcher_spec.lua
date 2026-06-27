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

describe("resolve_path_in_cwd allowed_roots (#140)", function()
    local cwd, root
    before_each(function()
        local n = math.random(0, 0xFFFFFF)
        cwd = tmp_base .. "/cwd140-" .. n
        root = tmp_base .. "/root140-" .. n -- a sibling dir to allow
        vim.fn.mkdir(cwd, "p")
        vim.fn.mkdir(root, "p")
    end)

    it("accepts a file inside an absolute allowed root", function()
        local target = root .. "/readme.md"
        vim.fn.writefile({ "hi" }, target)
        local abs, err = dispatcher.resolve_path_in_cwd(target, cwd, { root })
        assert.is_nil(err)
        assert.equals(canonical(target), abs)
    end)

    it("accepts a path reached via a relative-to-cwd root (../sibling)", function()
        local target = root .. "/readme.md"
        vim.fn.writefile({ "hi" }, target)
        local rel_root = "../" .. vim.fs.basename(root)
        local abs, err = dispatcher.resolve_path_in_cwd(target, cwd, { rel_root })
        assert.is_nil(err)
        assert.equals(canonical(target), abs)
    end)

    it("rejects a path outside cwd and all configured roots, naming the knob", function()
        local outside = tmp_base .. "/elsewhere140-" .. math.random(0, 0xFFFFFF) .. ".txt"
        vim.fn.writefile({ "no" }, outside)
        local abs, err = dispatcher.resolve_path_in_cwd(outside, cwd, { root })
        assert.is_nil(abs)
        assert.matches("configured read roots", err)
        assert.matches("tool_read_roots", err)
    end)

    it("accepts a symlink in cwd whose real path is inside an allowed root", function()
        local target = root .. "/real.md"
        vim.fn.writefile({ "x" }, target)
        vim.loop.fs_symlink(target, cwd .. "/link.md")
        local abs, err = dispatcher.resolve_path_in_cwd("link.md", cwd, { root })
        assert.is_nil(err)
        assert.equals(canonical(target), abs)
    end)

    it("rejects a symlink whose real path escapes cwd and all roots", function()
        local outside = tmp_base .. "/secret140-" .. math.random(0, 0xFFFFFF) .. ".txt"
        vim.fn.writefile({ "secret" }, outside)
        vim.loop.fs_symlink(outside, cwd .. "/escape.md")
        local abs, err = dispatcher.resolve_path_in_cwd("escape.md", cwd, { root })
        assert.is_nil(abs)
        assert.matches("configured read roots", err)
    end)

    it("empty roots list scopes to cwd but still reports the read-roots hint", function()
        local outside = tmp_base .. "/x140-" .. math.random(0, 0xFFFFFF) .. ".txt"
        vim.fn.writefile({ "no" }, outside)
        local abs, err = dispatcher.resolve_path_in_cwd(outside, cwd, {})
        assert.is_nil(abs)
        assert.matches("tool_read_roots", err)
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

describe("page_lines (#139)", function()
    local function make(n)
        local t = {}
        for i = 1, n do t[i] = "L" .. i end
        return table.concat(t, "\n")
    end

    it("returns content unchanged with no footer when it fits", function()
        local text, total = dispatcher.page_lines(make(50), 1, 200)
        assert.equals(50, total)
        assert.equals(make(50), text)
        assert.is_nil(text:match("lines %d"))
    end)

    it("windows to [offset, offset+limit) and appends a next-page footer", function()
        local text, total = dispatcher.page_lines(make(1000), 1, 200)
        assert.equals(1000, total)
        assert.matches("L200\n", text)
        assert.is_nil(text:match("L201\n"))
        assert.matches("lines 1%-200 of 1000", text)
        assert.matches("offset=201", text)
    end)

    it("pages a middle window and points at the next page", function()
        local text = dispatcher.page_lines(make(1000), 201, 200)
        assert.matches("^L201\n", text)
        assert.matches("lines 201%-400 of 1000", text)
        assert.matches("offset=401", text)
    end)

    it("marks end-of-output on the final window (no next page)", function()
        local text = dispatcher.page_lines(make(250), 201, 200)
        assert.matches("lines 201%-250 of 250", text)
        assert.matches("end of output", text)
        assert.is_nil(text:match("offset="))
    end)

    it("reports an empty window when offset is past the end", function()
        local text, total = dispatcher.page_lines(make(10), 50, 200)
        assert.equals(10, total)
        assert.matches("no lines at offset 50", text)
    end)

    it("drops a spurious trailing-newline line from the count", function()
        local _, total = dispatcher.page_lines("a\nb\n", 1, 200)
        assert.equals(2, total)
    end)

    it("clamps offset/limit to sane minimums", function()
        local text = dispatcher.page_lines(make(10), 0, 0)
        assert.matches("^L1", text)
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
        assert.matches("not available", result.content)
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

    it("read tools reach configured read_roots; write tools stay cwd-confined (#140)", function()
        local n = math.random(0, 0xFFFFFF)
        local cwd = tmp_base .. "/gate-cwd-" .. n
        local root = tmp_base .. "/gate-root-" .. n
        vim.fn.mkdir(cwd, "p")
        vim.fn.mkdir(root, "p")
        local target = root .. "/doc.md"
        vim.fn.writefile({ "x" }, target)

        local echo_path = function(input)
            return { content = "ran: " .. (input.file_path or ""), is_error = false }
        end
        registry.register({ name = "rd", kind = "read", description = "r",
            input_schema = { type = "object" }, handler = echo_path })
        registry.register({ name = "wr", kind = "write", description = "w",
            input_schema = { type = "object" }, handler = echo_path })

        local opts = { cwd = cwd, read_roots = { root } }
        -- READ tool: the configured root is honored → handler runs on the file.
        local rd = dispatcher.execute_call(
            { id = "g1", name = "rd", input = { file_path = target } }, registry, opts)
        assert.matches("ran: ", rd.content)
        assert.equals(false, rd.is_error)
        -- WRITE tool: same path + same roots, but writes ignore read_roots → rejected.
        local wr = dispatcher.execute_call(
            { id = "g2", name = "wr", input = { file_path = target } }, registry, opts)
        assert.is_true(wr.is_error)
        assert.matches("outside working directory", wr.content)
        -- Prove the write path took the nil-roots branch (not the read message).
        assert.is_nil(wr.content:match("configured read roots"))
    end)

    it("a tool with ABSENT kind is treated as read (kind defaults to read) (#140)", function()
        local n = math.random(0, 0xFFFFFF)
        local cwd = tmp_base .. "/nokind-cwd-" .. n
        local root = tmp_base .. "/nokind-root-" .. n
        vim.fn.mkdir(cwd, "p")
        vim.fn.mkdir(root, "p")
        local target = root .. "/doc.md"
        vim.fn.writefile({ "x" }, target)
        -- No `kind` field → defaults to read → must honor configured roots
        -- (gate is `~= "write"`, matching @readonly's contract).
        registry.register({
            name = "nokind",
            description = "n",
            input_schema = { type = "object" },
            handler = function(input)
                return { content = "ran: " .. (input.file_path or ""), is_error = false }
            end,
        })
        local res = dispatcher.execute_call(
            { id = "g3", name = "nokind", input = { file_path = target } },
            registry, { cwd = cwd, read_roots = { root } })
        assert.matches("ran: ", res.content)
        assert.equals(false, res.is_error)
    end)

    it("canonicalizes every element of a read tool's paths array (#144)", function()
        local n = math.random(0, 0xFFFFFF)
        local cwd = tmp_base .. "/paths-cwd-" .. n
        vim.fn.mkdir(cwd, "p")
        vim.fn.mkdir(cwd .. "/sub", "p")
        local one = cwd .. "/one.txt"
        local two = cwd .. "/sub/two.txt"
        vim.fn.writefile({ "one" }, one)
        vim.fn.writefile({ "two" }, two)

        registry.register({
            name = "paths_read",
            kind = "read",
            description = "reads paths",
            input_schema = { type = "object" },
            handler = function(input)
                return { content = table.concat(input.paths, "\n"), is_error = false }
            end,
        })

        local res = dispatcher.execute_call(
            { id = "pa1", name = "paths_read", input = { paths = { "one.txt", "sub/../sub/two.txt" } } },
            registry,
            { cwd = cwd }
        )
        assert.is_false(res.is_error)
        assert.truthy(res.content:find(canonical(one), 1, true))
        assert.truthy(res.content:find(canonical(two), 1, true))
    end)

    it("rejects a read tool's paths array when any element escapes (#144)", function()
        local n = math.random(0, 0xFFFFFF)
        local cwd = tmp_base .. "/paths-escape-cwd-" .. n
        vim.fn.mkdir(cwd, "p")
        local outside = tmp_base .. "/paths-outside-" .. n .. ".txt"
        vim.fn.writefile({ "outside" }, outside)

        registry.register({
            name = "paths_read_escape",
            kind = "read",
            description = "reads paths",
            input_schema = { type = "object" },
            handler = function()
                return { content = "should not run", is_error = false }
            end,
        })

        local res = dispatcher.execute_call(
            { id = "pa2", name = "paths_read_escape", input = { paths = { "missing.txt", outside } } },
            registry,
            { cwd = cwd, read_roots = {} }
        )
        assert.is_true(res.is_error)
        assert.matches("tool_read_roots", res.content)
        assert.not_matches("should not run", res.content)
    end)

    it("canonicalizes a read tool's default_path before handler execution (#144)", function()
        local n = math.random(0, 0xFFFFFF)
        local cwd = tmp_base .. "/default-path-cwd-" .. n
        vim.fn.mkdir(cwd, "p")

        registry.register({
            name = "default_path_read",
            kind = "read",
            default_path = ".",
            description = "reads default path",
            input_schema = { type = "object" },
            handler = function(input)
                return { content = input.path, is_error = false }
            end,
        })

        local res = dispatcher.execute_call(
            { id = "dp1", name = "default_path_read", input = {} },
            registry,
            { cwd = cwd }
        )
        assert.is_false(res.is_error)
        assert.equals(canonical(cwd), res.content)
    end)

    local function rows(n, prefix)
        local t = {}
        for i = 1, n do t[i] = (prefix or "row") .. i end
        return table.concat(t, "\n")
    end

    it("pages output + strips offset/limit from the handler input (#139)", function()
        local seen
        registry.register({ name = "lines", kind = "read", description = "x",
            input_schema = { type = "object" },
            handler = function(input) seen = input; return { content = rows(1000), is_error = false } end })
        local res = dispatcher.execute_call(
            { id = "p1", name = "lines", input = { offset = 1, limit = 5 } }, registry, { page_limit = 200 })
        assert.is_nil(seen.offset) -- handler never sees pager params
        assert.is_nil(seen.limit)
        assert.matches("row5\n", res.content)
        assert.is_nil(res.content:match("row6\n"))
        assert.matches("lines 1%-5 of 1000", res.content)
    end)

    it("applies the configured default page_limit when limit is omitted (#139)", function()
        registry.register({ name = "big", kind = "read", description = "x",
            input_schema = { type = "object" },
            handler = function() return { content = rows(300), is_error = false } end })
        local res = dispatcher.execute_call(
            { id = "p2", name = "big", input = {} }, registry, { page_limit = 200 })
        assert.matches("lines 1%-200 of 300", res.content)
    end)

    it("clamps a requested limit above the max (#139)", function()
        registry.register({ name = "huge", kind = "read", description = "x",
            input_schema = { type = "object" },
            handler = function() return { content = rows(5000), is_error = false } end })
        local res = dispatcher.execute_call(
            { id = "p3", name = "huge", input = { limit = 999999 } }, registry, { page_limit = 200 })
        assert.matches("lines 1%-2000 of 5000", res.content)
    end)

    it("does NOT window a self_paginates tool (read_file-style) (#139)", function()
        registry.register({ name = "selfpage", kind = "read", self_paginates = true, description = "x",
            input_schema = { type = "object" },
            handler = function(input)
                return { content = "off=" .. tostring(input.offset) .. "\n" .. rows(1000), is_error = false }
            end })
        local res = dispatcher.execute_call(
            { id = "p4", name = "selfpage", input = { offset = 7, limit = 3 } }, registry, { page_limit = 200 })
        assert.matches("off=7", res.content) -- handler saw offset (not stripped)
        assert.is_nil(res.content:match("lines %d+%-%d+ of")) -- no dispatcher pager footer
    end)

    it("registry injects offset/limit into read tools, not write/self-paginating (#139)", function()
        registry.register({ name = "rd", kind = "read", description = "x",
            input_schema = { type = "object", properties = {} }, handler = function() return { content = "" } end })
        registry.register({ name = "wr", kind = "write", description = "x",
            input_schema = { type = "object", properties = {} }, handler = function() return { content = "" } end })
        registry.register({ name = "sp", kind = "read", self_paginates = true, description = "x",
            input_schema = { type = "object", properties = {} }, handler = function() return { content = "" } end })
        assert.is_not_nil(registry.get("rd").input_schema.properties.offset)
        assert.is_not_nil(registry.get("rd").input_schema.properties.limit)
        assert.is_nil(registry.get("wr").input_schema.properties.offset)
        assert.is_nil(registry.get("sp").input_schema.properties.offset)
    end)

    it("does NOT window a write tool's multi-line output (#139)", function()
        -- The dispatcher pager gate must exclude writes (like the registry's
        -- injection gate): paging a write would advertise a destructive re-run.
        registry.register({ name = "wbig", kind = "write", description = "x",
            input_schema = { type = "object" },
            handler = function() return { content = rows(1000, "w"), is_error = false } end })
        local res = dispatcher.execute_call(
            { id = "w1", name = "wbig", input = {} }, registry, { page_limit = 200 })
        assert.is_nil(res.content:match("lines %d+%-%d+ of")) -- not windowed
    end)
end)
