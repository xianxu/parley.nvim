-- #231 conformance: the REAL macOS recipe against the REAL clipboard.
-- Opt-in (PARLEY_LIVE_CLIPBOARD=1) because it replaces the clipboard's
-- contents; it saves the text it finds (only when it is text) and restores it
-- on every path, assertion failures included. Skips on non-Darwin hosts.
local ci = require("parley.clipboard_image")

describe("clipboard recipe conformance (live, opt-in)", function()
    it("reads back a PNG placed on the clipboard, and declines text", function()
        if os.getenv("PARLEY_LIVE_CLIPBOARD") ~= "1" then
            pending("set PARLEY_LIVE_CLIPBOARD=1 to run against the real clipboard")
            return
        end
        local env = ci.host_env()
        if env.sysname ~= "Darwin" then
            pending("the live check models osascript; this host is " .. env.sysname)
            return
        end
        local repo = vim.fn.fnamemodify(debug.getinfo(1, "S").source:sub(2), ":p:h:h:h")
        local png = repo .. "/tests/fixtures/one_pixel.png"

        local saved = vim.fn.system({ "osascript", "-e", "the clipboard as text" })
        local had_text = vim.v.shell_error == 0
        saved = saved:gsub("\n$", "")
        local function restore()
            if had_text then
                vim.fn.system({ "osascript", "-e", "on run argv", "-e", "set the clipboard to (item 1 of argv)", "-e", "end run", saved })
            end
        end

        local function read_once()
            local out = vim.fn.tempname() .. ".png"
            local status, msg
            ci.read_png(ci.RECIPES.darwin, out, function(s, m) status, msg = s, m end)
            vim.wait(ci.TIMEOUT_MS + 500, function() return status ~= nil end, 20)
            local bytes = require("parley.assets").default_io.read(out, 1024 * 1024)
            os.remove(out)
            return status, msg, bytes
        end

        local ok, err = pcall(function()
            vim.fn.system({ "osascript", "-e", "on run argv",
                "-e", "set the clipboard to (read (POSIX file (item 1 of argv)) as «class PNGf»)", "-e", "end run", png })
            local status, msg, bytes = read_once()
            assert.equals("ok", status, msg)
            assert.is_true(bytes ~= nil and bytes:sub(1, 8) == "\137PNG\r\n\26\n", "a PNG came back")
            assert.is_true(require("parley.assets").looks_like("image/png", bytes), "a structurally valid PNG came back")

            vim.fn.system({ "osascript", "-e", "set the clipboard to \"plain text\"" })
            status, msg = read_once()
            assert.equals("no_image", status)
            assert.matches("expected type", msg)
        end)
        restore()
        assert(ok, err)
    end)
end)
