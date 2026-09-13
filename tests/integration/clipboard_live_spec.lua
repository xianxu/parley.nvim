-- #231 conformance: the REAL macOS recipe against the REAL clipboard.
-- Opt-in (PARLEY_LIVE_CLIPBOARD=1) because it replaces the clipboard's
-- contents. Preservation precondition (BR-10): the test mutates the clipboard
-- ONLY when it could snapshot the current contents as text; a non-text
-- clipboard (an image, a file) is skipped before any mutation, and a
-- restoration that does not read back identical text fails loudly. The
-- precondition and restore check are exercised with a stateful fake `sys`
-- below, so the policy is tested even where the live check never runs.
local ci = require("parley.clipboard_image")

--- The clipboard guard, parametrised by `sys(argv) -> stdout, ok` so a fake
--- can drive it. Returns a table { skip = reason } | { restore = fn }.
local function clipboard_guard(sys)
    local saved, ok = sys({ "osascript", "-e", "the clipboard as text" })
    if not ok then
        return { skip = "the clipboard holds non-text content that cannot be preserved; skipped before any mutation" }
    end
    saved = saved:gsub("\n$", "")
    return {
        restore = function()
            sys({ "osascript", "-e", "on run argv", "-e", "set the clipboard to (item 1 of argv)", "-e", "end run", saved })
            local back, ok2 = sys({ "osascript", "-e", "the clipboard as text" })
            back = (back or ""):gsub("\n$", "")
            if not ok2 or back ~= saved then
                return nil, ("clipboard NOT restored: expected %d chars, read back %s"):format(#saved, ok2 and (#back .. " chars") or "a non-text clipboard")
            end
            return true
        end,
    }
end

local function real_sys(argv)
    local out = vim.fn.system(argv)
    return out, vim.v.shell_error == 0
end

describe("clipboard preservation policy (stateful fake)", function()
    -- A fake clipboard: `text` or `image` content; records every `set`.
    local function fake_clipboard(content)
        local state = { content = content, sets = {} }
        state.sys = function(argv)
            local joined = table.concat(argv, " ")
            if joined:find("the clipboard as text", 1, true) then
                if state.content.text then return state.content.text .. "\n", true end
                return "execution error: Can’t make some data into the expected type. (-2700)", false
            end
            if joined:find("set the clipboard to", 1, true) then
                state.sets[#state.sets + 1] = argv[#argv]
                state.content = { text = argv[#argv] }
                return "", true
            end
            error("unexpected argv " .. joined)
        end
        return state
    end

    it("skips before any mutation when the clipboard is not text", function()
        local clip = fake_clipboard({ image = true })
        local guard = clipboard_guard(clip.sys)
        assert.matches("cannot be preserved", guard.skip)
        assert.same({}, clip.sets, "nothing was written to the clipboard")
    end)

    it("restores the exact text and verifies the read-back", function()
        local clip = fake_clipboard({ text = "keep me" })
        local guard = clipboard_guard(clip.sys)
        assert.is_nil(guard.skip)
        clip.sys({ "osascript", "-e", "set the clipboard to \"scratch\"" })
        assert.is_true(guard.restore())
        assert.equals("keep me", clip.content.text)
    end)

    it("reports a restoration that does not read back", function()
        -- A clipboard that swallows writes: the snapshot succeeds, the
        -- restore's set is accepted, but the read-back is something else.
        local clip = fake_clipboard({ text = "keep me" })
        local inner = clip.sys
        local guard = clipboard_guard(function(argv)
            if table.concat(argv, " "):find("set the clipboard", 1, true) then
                clip.content = { text = "other" } -- the write did not take
                return "", true
            end
            return inner(argv)
        end)
        assert.is_nil(guard.skip)
        local ok, err = guard.restore()
        assert.is_nil(ok)
        assert.matches("NOT restored", err)
    end)
end)

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
        local guard = clipboard_guard(real_sys)
        if guard.skip then
            pending(guard.skip)
            return
        end
        local repo = vim.fn.fnamemodify(debug.getinfo(1, "S").source:sub(2), ":p:h:h:h")
        local png = repo .. "/tests/fixtures/one_pixel.png"

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
            assert.is_true(bytes ~= nil and require("parley.assets").looks_like("image/png", bytes), "a structurally valid PNG came back")

            vim.fn.system({ "osascript", "-e", "set the clipboard to \"plain text\"" })
            status, msg = read_once()
            assert.equals("no_image", status)
            assert.matches("expected type", msg)
        end)
        local restored, rerr = guard.restore()
        assert(ok, err)
        assert(restored, rerr)
    end)
end)
