-- tests/unit/clipboard_image_spec.lua
--
-- Decision tables for the pure half of parley.clipboard_image (select,
-- argv_for, classify) and the interleaving seam of read_png: a synchronous
-- fake runner, a HELD fake runner (nothing settles until released), and the
-- default vim.system runner against `sh` (the real seam, including the
-- synthesized timeout message).
local ci = require("parley.clipboard_image")

local function env(sysname, wayland, tools)
    return {
        sysname = sysname,
        wayland = wayland,
        executable = function(t)
            return tools[t] == true
        end,
    }
end

local function write_file(path, bytes)
    local f = assert(io.open(path, "wb"))
    f:write(bytes)
    f:close()
end

local function tmp_png()
    return vim.fn.tempname() .. ".png"
end

describe("clipboard_image: constants and recipes", function()
    it("exposes the {out} token and a 5 s timeout", function()
        assert.equals("{out}", ci.OUT)
        assert.equals(5000, ci.TIMEOUT_MS)
    end)

    it("every recipe is data: tool, argv with exactly one whole {out}, install hint", function()
        for _, key in ipairs({ "darwin", "wayland", "x11" }) do
            local r = ci.RECIPES[key]
            assert.is_table(r, key)
            assert.is_string(r.tool, key .. ".tool")
            assert.is_string(r.install, key .. ".install")
            -- The tool is what select() probes with executable(): it is the
            -- argv head, or the program the sh wrapper execs.
            assert.is_truthy(r.argv[1] == r.tool or r.argv[3]:find(r.tool, 1, true), key .. ": tool matches argv")
            local n = 0
            for _, a in ipairs(r.argv) do
                if a == ci.OUT then
                    n = n + 1
                elseif a:find("{out}", 1, true) then
                    error(key .. ": {out} embedded in an argument: " .. a)
                end
            end
            assert.equals(1, n, key .. ": exactly one {out}")
        end
    end)

    it("Linux recipes hand the path to sh as $1, never inside the -c string", function()
        for _, key in ipairs({ "wayland", "x11" }) do
            local argv = ci.RECIPES[key].argv
            assert.equals("sh", argv[1])
            assert.equals("-c", argv[2])
            assert.is_truthy(argv[3]:find('"$1"', 1, true), key .. ": script reads $1")
            assert.equals(ci.OUT, argv[#argv], key .. ": {out} is the last argument")
        end
    end)
end)

describe("clipboard_image: select", function()
    it("Darwin uses osascript", function()
        local r, err = ci.select(nil, env("Darwin", false, { osascript = true }))
        assert.is_nil(err)
        assert.equals("osascript", r.tool)
        assert.equals(ci.RECIPES.darwin, r)
    end)

    it("Darwin ignores Linux tools and the WAYLAND_DISPLAY flag", function()
        local r = ci.select(nil, env("Darwin", true, { osascript = true, xclip = true, ["wl-paste"] = true }))
        assert.equals("osascript", r.tool)
    end)

    it("Darwin without osascript says it ships with macOS", function()
        local r, err = ci.select(nil, env("Darwin", false, { xclip = true }))
        assert.is_nil(r)
        assert.matches("no clipboard image tool found", err)
        assert.matches("osascript", err)
    end)

    it("Wayland prefers wl-paste, falls back to xclip", function()
        assert.equals("wl-paste", ci.select(nil, env("Linux", true, { ["wl-paste"] = true, xclip = true })).tool)
        assert.equals("wl-paste", ci.select(nil, env("Linux", true, { ["wl-paste"] = true })).tool)
        assert.equals("xclip", ci.select(nil, env("Linux", true, { xclip = true })).tool)
    end)

    it("X11 prefers xclip, falls back to wl-paste", function()
        assert.equals("xclip", ci.select(nil, env("Linux", false, { ["wl-paste"] = true, xclip = true })).tool)
        assert.equals("xclip", ci.select(nil, env("Linux", false, { xclip = true })).tool)
        assert.equals("wl-paste", ci.select(nil, env("Linux", false, { ["wl-paste"] = true })).tool)
    end)

    it("an unknown sysname takes the X11 order", function()
        assert.equals("xclip", ci.select(nil, env("FreeBSD", false, { ["wl-paste"] = true, xclip = true })).tool)
    end)

    it("names what to install when nothing is executable (both hints, in platform order)", function()
        local r, err = ci.select(nil, env("Linux", false, {}))
        assert.is_nil(r)
        assert.matches("no clipboard image tool found", err)
        assert.matches("xclip", err)
        assert.matches("wl%-clipboard", err)
        assert.is_true(err:find("xclip", 1, true) < err:find("wl-clipboard", 1, true), "x11 hint first on X11")

        local _, werr = ci.select(nil, env("Linux", true, {}))
        assert.is_true(werr:find("wl-clipboard", 1, true) < werr:find("xclip", 1, true), "wayland hint first on Wayland")
    end)

    it("a configured argv wins over the platform, without probing executables", function()
        local probed = false
        local e = env("Darwin", false, {})
        e.executable = function()
            probed = true
            return false
        end
        local r, err = ci.select({ "/x/fake", "--out", "{out}" }, e)
        assert.is_nil(err)
        assert.equals("/x/fake", r.tool)
        assert.same({ "/x/fake", "--out", "{out}" }, r.argv)
        assert.is_false(probed)
    end)

    it("a configured argv must contain {out} as a whole argument", function()
        local r, err = ci.select({ "/x/fake" }, env("Darwin", false, { osascript = true }))
        assert.is_nil(r)
        assert.matches("{out}", err, 1, true)

        r, err = ci.select({ "/x/fake", "--out={out}" }, env("Darwin", false, { osascript = true }))
        assert.is_nil(r, "an embedded {out} is not a whole argument")
        assert.matches("{out}", err, 1, true)
    end)

    it("an empty or non-list config falls through to the platform", function()
        assert.equals("osascript", ci.select({}, env("Darwin", false, { osascript = true })).tool)
        assert.equals("osascript", ci.select("osascript {out}", env("Darwin", false, { osascript = true })).tool)
    end)
end)

describe("clipboard_image: argv_for", function()
    it("substitutes {out} as a whole argument, once, anywhere", function()
        local r = { tool = "t", argv = { "t", "--to", "{out}", "{out}x", "x{out}" } }
        assert.same({ "t", "--to", "/p/a.png", "{out}x", "x{out}" }, ci.argv_for(r, "/p/a.png"))
    end)

    it("does not mutate the recipe", function()
        local r = { tool = "t", argv = { "t", "{out}" } }
        ci.argv_for(r, "/p/a.png")
        assert.same({ "t", "{out}" }, r.argv)
    end)

    it("the darwin recipe passes the path as the last argv element, never inside the script", function()
        local path = "/p/a b'\"$(x).png"
        local argv = ci.argv_for(ci.RECIPES.darwin, path)
        assert.equals("osascript", argv[1])
        assert.equals(path, argv[#argv])
        for i = 1, #argv - 1 do
            assert.is_nil(argv[i]:find(path, 1, true), "argv[" .. i .. "] carries the path")
            assert.is_nil(argv[i]:find("{out}", 1, true), "argv[" .. i .. "] still carries the token")
        end
    end)

    it("the Linux recipes pass the path as $1 (the argument after the sh name)", function()
        for _, key in ipairs({ "wayland", "x11" }) do
            local argv = ci.argv_for(ci.RECIPES[key], "/p/a b.png")
            assert.equals("sh", argv[#argv - 1])
            assert.equals("/p/a b.png", argv[#argv])
            assert.is_nil(argv[3]:find("/p/a b.png", 1, true))
        end
    end)
end)

describe("clipboard_image: classify", function()
    it("exit 0 with bytes is ok", function()
        local s, msg = ci.classify(0, "", 1234)
        assert.equals("ok", s)
        assert.is_nil(msg)
        assert.equals("ok", ci.classify(0, "some warning\n", 1))
    end)

    it("exit 0 with an empty or missing file is no_image", function()
        local s, msg = ci.classify(0, "", 0)
        assert.equals("no_image", s)
        assert.matches("no image", msg)
        s, msg = ci.classify(0, "", nil)
        assert.equals("no_image", s)
        assert.matches("no image", msg)
    end)

    it("exit 1 is no_image and carries the tool's trimmed stderr", function()
        local s, msg = ci.classify(1, "207:208: execution error: Can’t make some data into the expected type. (-2700)\n", 0)
        assert.equals("no_image", s)
        assert.matches("no image", msg)
        assert.matches("expected type", msg)
        assert.is_nil(msg:find("\n", 1, true), "trailing newline trimmed")
    end)

    it("exit 1 with silent stderr is still no_image", function()
        local s, msg = ci.classify(1, "", nil)
        assert.equals("no_image", s)
        assert.matches("no image", msg)
    end)

    it("exit 1 wins over a non-empty file (the tool said no)", function()
        assert.equals("no_image", ci.classify(1, "", 12))
    end)

    it("any other exit is failed with 'exit N: <stderr>' — 124 included", function()
        local s, msg = ci.classify(2, "boom\n", nil)
        assert.equals("failed", s)
        assert.equals("exit 2: boom", msg)

        s, msg = ci.classify(124, "osascript timed out after 5000 ms", nil)
        assert.equals("failed", s)
        assert.equals("exit 124: osascript timed out after 5000 ms", msg)

        s, msg = ci.classify(127, "sh: xclip: command not found\n", 0)
        assert.equals("failed", s)
        assert.equals("exit 127: sh: xclip: command not found", msg)

        s, msg = ci.classify(3, nil, 99)
        assert.equals("failed", s, "a non-zero, non-1 exit fails even with bytes on disk")
        assert.equals("exit 3: ", msg)
    end)
end)

describe("clipboard_image: host_env", function()
    it("probes the host: sysname, wayland flag, executable()", function()
        local e = ci.host_env()
        assert.is_string(e.sysname)
        assert.is_boolean(e.wayland)
        assert.is_function(e.executable)
        assert.is_true(e.executable("sh"))
        assert.is_false(e.executable("parley-no-such-tool-" .. os.time()))
    end)
end)

describe("clipboard_image: read_png", function()
    local recipe = { tool = "t", argv = { "t", "{out}" } }

    it("runs the recipe argv and classifies on the scheduled callback", function()
        local out = tmp_png()
        local seen_argv
        local runner = function(argv, on_complete)
            seen_argv = argv
            write_file(out, "PNG")
            on_complete(0, "")
        end
        local status, msg
        ci.read_png(recipe, out, function(s, m)
            status, msg = s, m
        end, runner)
        vim.wait(500, function()
            return status ~= nil
        end, 10)
        assert.same({ "t", out }, seen_argv)
        assert.equals("ok", status, msg)
        assert.is_nil(msg)
        os.remove(out)
    end)

    it("on_done is scheduled, not called inline, even when the runner answers synchronously", function()
        local out = tmp_png()
        local runner = function(_, on_complete)
            write_file(out, "PNG")
            on_complete(0, "")
        end
        local status
        ci.read_png(recipe, out, function(s)
            status = s
        end, runner)
        assert.is_nil(status, "settles on the main loop, after read_png returns")
        vim.wait(500, function()
            return status ~= nil
        end, 10)
        assert.equals("ok", status)
        os.remove(out)
    end)

    it("reports no_image with the tool's words when the tool exits 1", function()
        local out = tmp_png()
        local runner = function(_, on_complete)
            on_complete(1, "nothing of that type\n")
        end
        local status, msg
        ci.read_png(recipe, out, function(s, m)
            status, msg = s, m
        end, runner)
        vim.wait(500, function()
            return status ~= nil
        end, 10)
        assert.equals("no_image", status)
        assert.matches("nothing of that type", msg)
    end)

    it("reports no_image when the tool exits 0 but wrote nothing", function()
        local out = tmp_png()
        local runner = function(_, on_complete)
            write_file(out, "")
            on_complete(0, "")
        end
        local status
        ci.read_png(recipe, out, function(s)
            status = s
        end, runner)
        vim.wait(500, function()
            return status ~= nil
        end, 10)
        assert.equals("no_image", status)
        os.remove(out)
    end)

    it("reports failed with exit N and stderr", function()
        local out = tmp_png()
        local runner = function(_, on_complete)
            on_complete(124, "t timed out after 5000 ms")
        end
        local status, msg
        ci.read_png(recipe, out, function(s, m)
            status, msg = s, m
        end, runner)
        vim.wait(500, function()
            return status ~= nil
        end, 10)
        assert.equals("failed", status)
        assert.equals("exit 124: t timed out after 5000 ms", msg)
    end)

    it("a held callback reproduces the in-flight interleaving (ARCH-ORDER seam)", function()
        local out = tmp_png()
        local held
        local runner = function(_, on_complete)
            held = on_complete
        end
        local status
        ci.read_png(recipe, out, function(s)
            status = s
        end, runner)
        assert.is_function(held, "the runner was spawned")
        assert.is_nil(status, "nothing settles until the tool answers")
        vim.wait(50, function()
            return status ~= nil
        end, 10)
        assert.is_nil(status, "still nothing after the loop turns")

        -- The file appears while the paste is in flight; classification reads
        -- what is on disk at the moment the tool answers, not at spawn time.
        write_file(out, "PNG")
        held(0, "")
        vim.wait(500, function()
            return status ~= nil
        end, 10)
        assert.equals("ok", status)
        os.remove(out)
    end)

    it("the default runner spawns the argv through vim.system (a real sh)", function()
        local out = tmp_png()
        local sh_recipe = { tool = "sh", argv = { "sh", "-c", 'printf PNG > "$1"', "sh", "{out}" } }
        local status, msg
        ci.read_png(sh_recipe, out, function(s, m)
            status, msg = s, m
        end)
        vim.wait(2000, function()
            return status ~= nil
        end, 10)
        assert.equals("ok", status, msg)
        local f = assert(io.open(out, "rb"))
        assert.equals("PNG", f:read("*a"))
        f:close()
        os.remove(out)
    end)

    it("the default runner passes a real tool's exit 1 and stderr through", function()
        local out = tmp_png()
        local sh_recipe = { tool = "sh", argv = { "sh", "-c", 'echo "no such type" >&2; exit 1', "sh", "{out}" } }
        local status, msg
        ci.read_png(sh_recipe, out, function(s, m)
            status, msg = s, m
        end)
        vim.wait(2000, function()
            return status ~= nil
        end, 10)
        assert.equals("no_image", status)
        assert.matches("no such type", msg)
    end)

    it("the default runner synthesizes the timeout message on a silent 124", function()
        local out = tmp_png()
        local saved = ci.TIMEOUT_MS
        ci.TIMEOUT_MS = 100
        local sh_recipe = { tool = "slowtool", argv = { "sh", "-c", "sleep 5", "sh", "{out}" } }
        local status, msg
        local ok, err = pcall(function()
            ci.read_png(sh_recipe, out, function(s, m)
                status, msg = s, m
            end)
            vim.wait(3000, function()
                return status ~= nil
            end, 10)
        end)
        ci.TIMEOUT_MS = saved
        assert.is_true(ok, err)
        assert.equals("failed", status)
        assert.equals("exit 124: slowtool timed out after 100 ms", msg)
    end)
end)
