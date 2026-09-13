-- lua/parley/clipboard_image.lua
--
-- Read an image off the system clipboard into a PNG file (#231, decision 11).
--
-- Platform recipes are DATA: `RECIPES.<key> = { tool, argv, install }` where
-- `argv` carries the `{out}` token (`M.OUT`) as one WHOLE argument standing
-- for the path to write. The path never enters an osascript script or a
-- `sh -c` string — the darwin recipe reads it from `argv`, the Linux recipes
-- as `$1` (ARCH-SECURE). `config.assets.clipboard_cmd` supplies a recipe in
-- the same shape, which is how `tests/fixtures/fake_clipboard` stands in for
-- osascript through the very boundary production uses (ARCH-MOCK).
--
-- Classification is ONE rule for every recipe (measured 2026-09-12 on macOS;
-- wl-paste and xclip document the same exit code for "no such type"):
--   exit 0 + non-empty file → ok
--   exit 0 + empty/missing  → no_image   (the tool wrote nothing)
--   exit 1                  → no_image   (osascript: "Can’t make some data
--                                          into the expected type. (-2700)")
--   anything else           → failed, "exit N: <stderr>" (124 = timeout)
--
-- The spawn is the one seam: `read_png` runs the recipe through `runner`
-- (default `vim.system`, `TIMEOUT_MS`), stats the file with `uv.fs_stat`
-- inside the libuv callback, classifies, and SCHEDULES `on_done` onto the
-- main loop — so callers may use `vim.fn` / `vim.api` freely in `on_done`.
--
-- PURE except `read_png` (spawn) and `host_env` (probes the host).

local uv = vim.uv or vim.loop

local M = {}

--- The token a recipe's argv carries in place of the PNG path to write.
M.OUT = "{out}"

--- How long the tool may run before vim.system kills it (exit 124).
M.TIMEOUT_MS = 5000

--- Platform recipes. Each is `{ tool, argv, install }`; `argv` holds
--- exactly one `{out}` as a whole argument.
M.RECIPES = {
    -- Writes «class PNGf» to the path in argv (the script reads `item 1 of
    -- argv`; the path is never script text). On a text clipboard it exits 1,
    -- prints "Can’t make some data into the expected type. (-2700)" and
    -- leaves a 0-byte file — classify() reads that as no_image.
    darwin = {
        tool = "osascript",
        argv = {
            "osascript",
            "-e", "on run argv",
            "-e", "set p to POSIX file (item 1 of argv)",
            "-e", "set f to open for access p with write permission",
            "-e", "try",
            "-e", "set eof f to 0",
            "-e", "write (the clipboard as «class PNGf») to f",
            "-e", "close access f",
            "-e", "on error m",
            "-e", "close access f",
            "-e", "error m",
            "-e", "end try",
            "-e", "end run",
            "{out}",
        },
        install = "osascript ships with macOS",
    },
    -- `sh -c '… > "$1"' sh <out>`: the path is $1, an argument, never part
    -- of the -c string. wl-paste exits 1 when the clipboard holds no
    -- image/png.
    wayland = {
        tool = "wl-paste",
        argv = { "sh", "-c", 'exec wl-paste --type image/png > "$1"', "sh", "{out}" },
        install = "install wl-clipboard (wl-paste)",
    },
    -- Same shape; xclip exits 1 when the target is not offered.
    x11 = {
        tool = "xclip",
        argv = { "sh", "-c", 'exec xclip -selection clipboard -t image/png -o > "$1"', "sh", "{out}" },
        install = "install xclip",
    },
}

--- The host as select() sees it. Probed once per paste; tests pass their
--- own table in the same shape.
--- @return table { sysname: string, wayland: boolean, executable: fun(tool: string): boolean }
function M.host_env()
    local uname = uv.os_uname()
    return {
        sysname = uname and uname.sysname or "",
        wayland = (vim.env.WAYLAND_DISPLAY or "") ~= "",
        executable = function(tool)
            return vim.fn.executable(tool) == 1
        end,
    }
end

-- True when some element of argv IS the token (an embedded "{out}" inside a
-- longer argument does not count — the path is only ever a whole argument).
local function has_out_token(argv)
    for _, a in ipairs(argv) do
        if a == M.OUT then
            return true
        end
    end
    return false
end

-- Platform order: Darwin → darwin only; Wayland → wayland then x11; else
-- x11 then wayland.
local function platform_order(env)
    if env.sysname == "Darwin" then
        return { "darwin" }
    elseif env.wayland then
        return { "wayland", "x11" }
    end
    return { "x11", "wayland" }
end

--- Pick a recipe. A configured argv list wins verbatim (it must carry
--- `{out}`); otherwise the first executable platform recipe. The error
--- names what to install, in platform order.
--- @param config_cmd string[]|nil  `config.assets.clipboard_cmd`
--- @param env table  from host_env(), or a test's own
--- @return table|nil recipe, string|nil err
function M.select(config_cmd, env)
    if type(config_cmd) == "table" and #config_cmd > 0 then
        if not has_out_token(config_cmd) then
            return nil, "assets.clipboard_cmd must contain the " .. M.OUT .. " token (as its own argument) for the PNG path to write"
        end
        return { tool = config_cmd[1], argv = config_cmd, install = nil }
    end
    local hints = {}
    for _, key in ipairs(platform_order(env)) do
        local recipe = M.RECIPES[key]
        if env.executable(recipe.tool) then
            return recipe
        end
        hints[#hints + 1] = recipe.install
    end
    return nil, "no clipboard image tool found: " .. table.concat(hints, " or ")
end

--- The recipe's argv with every whole-argument `{out}` replaced by out_path.
--- The recipe itself is not mutated.
--- @param recipe table
--- @param out_path string
--- @return string[] argv
function M.argv_for(recipe, out_path)
    local argv = {}
    for i, a in ipairs(recipe.argv) do
        argv[i] = (a == M.OUT) and out_path or a
    end
    return argv
end

--- The one rule for every recipe (see the module header).
--- @param code integer  the tool's exit code (124 = vim.system timeout)
--- @param stderr string|nil  the tool's stderr; trimmed into the message
--- @param size integer|nil  bytes at out_path, nil when the file is missing
--- @return "ok"|"no_image"|"failed" status, string|nil message
function M.classify(code, stderr, size)
    local words = (stderr or ""):gsub("%s+$", "")
    if code == 0 then
        if size and size > 0 then
            return "ok"
        end
        return "no_image", "no image on the clipboard (the tool wrote nothing)"
    end
    if code == 1 then
        if words ~= "" then
            return "no_image", "no image on the clipboard (" .. words .. ")"
        end
        return "no_image", "no image on the clipboard"
    end
    return "failed", "exit " .. tostring(code) .. ": " .. words
end

-- The default runner: vim.system with the module timeout. Its callback runs
-- in a libuv context, so nothing here touches vim.fn. A kill on timeout
-- yields 124 with (usually) an empty stderr; the message is synthesized so
-- classify's "exit 124: …" names the tool and the budget.
local function system_runner(tool)
    return function(argv, on_complete)
        vim.system(argv, { text = true, timeout = M.TIMEOUT_MS }, function(res)
            local stderr = res.stderr or ""
            if res.code == 124 and stderr == "" then
                stderr = tool .. " timed out after " .. tostring(M.TIMEOUT_MS) .. " ms"
            end
            on_complete(res.code or 1, stderr)
        end)
    end
end

--- Spawn the recipe to write a PNG at out_path, then `on_done(status, msg)`
--- on the main loop (always via vim.schedule — never inline, even when the
--- runner answers synchronously).
--- @param recipe table  from select()
--- @param out_path string  where the tool writes; the caller owns the file
--- @param on_done fun(status: "ok"|"no_image"|"failed", msg: string|nil)
--- @param runner fun(argv: string[], on_complete: fun(code: integer, stderr: string))|nil
---        defaults to vim.system; tests inject a synchronous or held fake
function M.read_png(recipe, out_path, on_done, runner)
    local argv = M.argv_for(recipe, out_path)
    local run = runner or system_runner(recipe.tool)
    run(argv, function(code, stderr)
        -- uv.fs_stat is safe in a libuv callback; vim.fn is not.
        local st = uv.fs_stat(out_path)
        local status, msg = M.classify(code, stderr, st and st.size or nil)
        vim.schedule(function()
            on_done(status, msg)
        end)
    end)
end

return M
