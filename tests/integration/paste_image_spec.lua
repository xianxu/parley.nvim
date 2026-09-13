-- tests/integration/paste_image_spec.lua
--
-- The <M-v> paste flow (#231) end-to-end through the config seam: the
-- fixture stands in for osascript. One case per row of the plan's ordering
-- table (State and ordering), plus the key's registry resolution.
local root = vim.fn.tempname() .. "-parley-paste"
vim.fn.mkdir(root, "p")
local repo = vim.fn.fnamemodify(debug.getinfo(1, "S").source:sub(2), ":p:h:h:h")
-- Named so the plan's Integration-points row `fake_clipboard` resolves to a
-- definition (tests/arch/single_source_sweeps_spec.lua "every symbol … exists").
local fake_clipboard = repo .. "/tests/fixtures/fake_clipboard"
local png = repo .. "/tests/fixtures/one_pixel.png"
local log = root .. "/clipboard.log"

local parley = require("parley")
local function setup_parley(assets_config)
    parley.setup({
        chat_dir = root,
        state_dir = vim.fn.tempname() .. "-parley-paste-state",
        providers = {},
        api_keys = {},
        assets = assets_config,
    })
end
setup_parley({ clipboard_cmd = { fake_clipboard, "{out}" } })
local assets = require("parley.assets")

local TS = "2026-09-10.14-20-03.112"

local function open_chat(name, lines)
    local path = root .. "/" .. name
    vim.fn.writefile(lines, path)
    vim.cmd("edit " .. vim.fn.fnameescape(path))
    return vim.api.nvim_get_current_buf(), path
end

local function chat_lines()
    return { "---", "topic: Paste", "file: x.md", "model: m", "provider: openai", "---", "", "💬: look at this", "and this" }
end

local function wait_for(pred, ms)
    return vim.wait(ms or 3000, pred, 20)
end

local function line_count(buf)
    return #vim.api.nvim_buf_get_lines(buf, 0, -1, false)
end

local function reads()
    return vim.fn.filereadable(log) == 1 and #vim.fn.readfile(log) or 0
end

local function bytes_of(path)
    return assets.default_io.read(path, assets.MAX_BYTES + 1)
end

local notices
local function notify(msg, level)
    notices[#notices + 1] = { msg = msg, level = level }
end

describe("paste image (#231)", function()
    before_each(function()
        notices = {}
        os.remove(log)
        vim.env.PARLEY_FAKE_CLIPBOARD_LOG = log
    end)
    after_each(function()
        vim.env.PARLEY_FAKE_CLIPBOARD = nil
        vim.cmd("silent! %bwipeout!")
        vim.fn.delete(root, "rf")
        vim.fn.mkdir(root, "p")
    end)

    it("saves the clipboard PNG under assets/<ts>/ and inserts the link after the cursor line", function()
        vim.env.PARLEY_FAKE_CLIPBOARD = "png:" .. png
        local buf, path = open_chat(TS .. "_paste.md", chat_lines())
        vim.api.nvim_win_set_cursor(0, { 8, 0 }) -- the 💬: line

        parley.paste_image(buf, { notify = notify })

        assert.is_true(wait_for(function() return line_count(buf) == 10 end), "link inserted")
        local lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
        local att = assets.parse_attachment(lines[9])
        assert.is_not_nil(att, "line 9 is an attachment: " .. lines[9])
        assert.equals(TS, att.ts)
        assert.equals("and this", lines[10], "the following line is untouched")
        local abs = root .. "/" .. att.path
        assert.equals(1, vim.fn.filereadable(abs))
        assert.equals(bytes_of(png), bytes_of(abs), "bytes are the clipboard bytes")
        assert.matches("pasted assets/", notices[#notices].msg)
        assert.equals(1, reads(), "one clipboard read")
        -- Harness $TMPDIR is a symlink (/tmp → /private/tmp): resolve both sides.
        assert.equals(vim.fn.resolve(path), vim.fn.resolve(vim.api.nvim_buf_get_name(buf)))
    end)

    it("declines a text clipboard, writes nothing, and says why", function()
        vim.env.PARLEY_FAKE_CLIPBOARD = "text"
        local buf = open_chat(TS .. "_text.md", chat_lines())
        vim.api.nvim_win_set_cursor(0, { 8, 0 })

        parley.paste_image(buf, { notify = notify })

        assert.is_true(wait_for(function() return #notices > 0 end))
        assert.matches("nothing pasted", notices[1].msg)
        assert.matches("expected type", notices[1].msg, "the tool's own words are shown")
        assert.equals("info", notices[1].level)
        assert.equals(9, line_count(buf))
        assert.equals(0, vim.fn.isdirectory(root .. "/assets"), "no folder created")
    end)

    it("reports a broken tool as a failure with its stderr", function()
        vim.env.PARLEY_FAKE_CLIPBOARD = "broken"
        local buf = open_chat(TS .. "_broken.md", chat_lines())
        parley.paste_image(buf, { notify = notify })
        assert.is_true(wait_for(function() return #notices > 0 end))
        assert.equals("warn", notices[1].level)
        assert.matches("exit 2: boom", notices[1].msg)
        assert.equals(9, line_count(buf))
    end)

    it("declines a markdown file without a timestamp name, without reading the clipboard", function()
        vim.env.PARLEY_FAKE_CLIPBOARD = "png:" .. png
        local buf = open_chat("notes.md", { "# note" })
        parley.paste_image(buf, { notify = notify })
        assert.equals(1, #notices)
        assert.matches("timestamp%-named chat", notices[1].msg)
        assert.equals(0, reads())
    end)

    it("notices a missing clipboard capability once, keeps probing, recovers, and resets on setup", function()
        local available, probes = false, 0
        local function host_env()
            return {
                sysname = "Linux", manager = "apt", wayland = false,
                executable = function(tool)
                    probes = probes + 1
                    return available and tool == "xclip"
                end,
            }
        end
        local function runner(argv, done)
            assert(assets.default_io.write(argv[#argv], bytes_of(png)))
            done(0, "")
        end
        local paste = require("parley.paste_image")
        setup_parley({})
        local buf = open_chat(TS .. "_dependency.md", chat_lines())

        paste.paste(buf, { config = parley.config, notify = notify, host_env = host_env, runner = runner })
        assert.equals(1, #notices)
        assert.equals("Parley: no clipboard image tool found: apt install xclip or apt install wl-clipboard", notices[1].msg)
        assert.equals(2, probes)

        paste.paste(buf, { config = parley.config, notify = notify, host_env = host_env, runner = runner })
        assert.equals(1, #notices, "the same missing capability is quiet")
        assert.equals(4, probes, "a quiet attempt still probes every candidate")

        available = true
        paste.paste(buf, { config = parley.config, notify = notify, host_env = host_env, runner = runner })
        assert.is_true(wait_for(function() return line_count(buf) == 10 end), "a newly available tool works without setup")
        assert.equals(5, probes)

        available = false
        setup_parley({})
        paste.paste(buf, { config = parley.config, notify = notify, host_env = host_env, runner = runner })
        assert.equals(3, #notices, "setup starts a new notice generation")
        assert.matches("apt install xclip", notices[3].msg, 1, true)
        assert.equals(7, probes)
        setup_parley({ clipboard_cmd = { fake_clipboard, "{out}" } })
    end)

    it("reports an invalid custom clipboard command on every attempt", function()
        local paste = require("parley.paste_image")
        setup_parley({ clipboard_cmd = { "fake-without-output-token" } })
        local buf = open_chat(TS .. "_bad_config.md", chat_lines())
        local deps = {
            config = parley.config,
            notify = notify,
            host_env = function()
                return { sysname = "Linux", manager = "apt", wayland = false, executable = function() return false end }
            end,
        }
        paste.paste(buf, deps)
        paste.paste(buf, deps)
        assert.equals(2, #notices)
        assert.matches("assets.clipboard_cmd must contain the {out} token", notices[1].msg, 1, true)
        assert.equals(notices[1].msg, notices[2].msg)
        setup_parley({ clipboard_cmd = { fake_clipboard, "{out}" } })
    end)

    it("the link lands where the cursor was, even if lines were inserted above meanwhile", function()
        vim.env.PARLEY_FAKE_CLIPBOARD = "slow:" .. png
        local buf = open_chat(TS .. "_race.md", chat_lines())
        vim.api.nvim_win_set_cursor(0, { 9, 0 }) -- "and this"
        parley.paste_image(buf, { notify = notify })
        -- Typing above before the tool answers: the anchor must follow.
        vim.api.nvim_buf_set_lines(buf, 6, 6, false, { "inserted above" })
        assert.is_true(wait_for(function() return line_count(buf) == 11 end))
        local lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
        assert.equals("and this", lines[10])
        assert.is_not_nil(assets.parse_attachment(lines[11]))
    end)

    it("discards the image when the buffer was closed before the tool answered", function()
        vim.env.PARLEY_FAKE_CLIPBOARD = "slow:" .. png
        local buf = open_chat(TS .. "_closed.md", chat_lines())
        parley.paste_image(buf, { notify = notify })
        vim.api.nvim_buf_delete(buf, { force = true })
        assert.is_true(wait_for(function() return #notices > 0 end))
        assert.matches("buffer was closed", notices[1].msg)
        assert.equals(0, vim.fn.isdirectory(root .. "/assets"), "no bytes without a transcript line")
    end)

    it("refuses a second paste while one is in flight on the same buffer", function()
        vim.env.PARLEY_FAKE_CLIPBOARD = "slow:" .. png
        local buf = open_chat(TS .. "_twice.md", chat_lines())
        parley.paste_image(buf, { notify = notify })
        parley.paste_image(buf, { notify = notify })
        assert.matches("already in progress", notices[1].msg)
        assert.is_true(wait_for(function() return line_count(buf) == 10 end))
        assert.equals(1, reads(), "the second key spawned nothing")
        -- and the flight is over: a third paste is accepted. Wait for ITS link,
        -- not the log line — the fixture logs before it sleeps, and a paste
        -- still in flight when this case returns would notify into the next
        -- case's table (nothing outlives a paste: ARCH-ORDER).
        parley.paste_image(buf, { notify = notify })
        assert.is_true(wait_for(function() return line_count(buf) == 11 end))
        assert.equals(2, reads())
    end)

    it("relays a save failure as nothing pasted, leaving the buffer untouched", function()
        vim.env.PARLEY_FAKE_CLIPBOARD = "png:" .. png
        -- The assets path is a plain FILE, so save's mkdir cannot succeed.
        vim.fn.writefile({ "not a folder" }, root .. "/" .. assets.DIR)
        local buf = open_chat(TS .. "_nowrite.md", chat_lines())
        parley.paste_image(buf, { notify = notify })
        assert.is_true(wait_for(function() return #notices > 0 end))
        assert.matches("nothing pasted", notices[1].msg)
        assert.matches("could not create", notices[1].msg)
        assert.equals("error", notices[1].level)
        assert.equals(9, line_count(buf), "no link without bytes")
        assert.equals(1, reads())
    end)

    -- C3 (BR-3): every launch or insertion failure is a complete terminal
    -- transition — in-flight cleared, temp removed, one notice, no residue —
    -- proven by a successful paste on the same buffer straight afterwards.

    it("a clipboard_cmd that cannot be launched is one notice, and the next paste is accepted", function()
        local buf = open_chat(TS .. "_nolaunch.md", chat_lines())
        vim.api.nvim_win_set_cursor(0, { 8, 0 })
        local saved_cmd = parley.config.assets.clipboard_cmd
        parley.config.assets.clipboard_cmd = { "/nonexistent/parley-clipboard-tool", "{out}" }
        local ok, err = pcall(function()
            parley.paste_image(buf, { notify = notify })
            assert.is_true(wait_for(function() return #notices > 0 end), "the launch failure notifies")
        end)
        parley.config.assets.clipboard_cmd = saved_cmd
        assert.is_true(ok, tostring(err))
        assert.equals(1, #notices)
        assert.matches("nothing pasted — could not start /nonexistent/parley%-clipboard%-tool", notices[1].msg)
        assert.equals("warn", notices[1].level)
        assert.equals(9, line_count(buf))
        assert.equals(0, vim.fn.isdirectory(root .. "/assets"))

        -- The flight is over: the same buffer pastes again, no "already in progress".
        vim.env.PARLEY_FAKE_CLIPBOARD = "png:" .. png
        parley.paste_image(buf, { notify = notify })
        assert.is_true(wait_for(function() return line_count(buf) == 10 end), "second paste inserted its link")
        for _, n in ipairs(notices) do
            assert.is_nil(n.msg:find("already in progress", 1, true), n.msg)
        end
        assert.equals(1, reads())
    end)

    it("a nomodifiable buffer is refused BEFORE saving: no file, no folder, buffer unchanged", function()
        vim.env.PARLEY_FAKE_CLIPBOARD = "png:" .. png
        local buf = open_chat(TS .. "_nomod.md", chat_lines())
        vim.api.nvim_win_set_cursor(0, { 8, 0 })
        vim.bo[buf].modifiable = false
        local ok, err = pcall(function()
            parley.paste_image(buf, { notify = notify })
            assert.is_true(wait_for(function() return #notices > 0 end))
        end)
        vim.bo[buf].modifiable = true
        assert.is_true(ok, tostring(err))
        assert.equals(1, #notices)
        assert.matches("nothing pasted", notices[1].msg)
        assert.matches("modifiable", notices[1].msg)
        assert.equals(9, line_count(buf), "buffer unchanged")
        assert.equals(0, vim.fn.isdirectory(root .. "/assets"), "nothing saved for a link that cannot land")
        assert.equals(1, reads())

        parley.paste_image(buf, { notify = notify })
        assert.is_true(wait_for(function() return line_count(buf) == 10 end), "the next paste is accepted")
        assert.equals(2, reads())
    end)

    it("an insertion failure after the save rolls the asset back: no file, no empty folder", function()
        vim.env.PARLEY_FAKE_CLIPBOARD = "png:" .. png
        local buf = open_chat(TS .. "_noinsert.md", chat_lines())
        vim.api.nvim_win_set_cursor(0, { 8, 0 })
        local buffer_edit = require("parley.buffer_edit")
        local saved_insert = buffer_edit.insert_lines_at
        buffer_edit.insert_lines_at = function()
            error("E21: Cannot make changes (simulated)")
        end
        local ok, err = pcall(function()
            parley.paste_image(buf, { notify = notify })
            assert.is_true(wait_for(function() return #notices > 0 end))
        end)
        buffer_edit.insert_lines_at = saved_insert
        assert.is_true(ok, tostring(err))
        assert.equals(1, #notices)
        assert.matches("nothing pasted — could not insert the link", notices[1].msg)
        assert.matches("E21", notices[1].msg, "the insertion error is shown")
        assert.equals("error", notices[1].level)
        assert.equals(9, line_count(buf), "no link")
        assert.same({}, vim.fn.glob(root .. "/assets/**", false, true), "no file under assets/")
        assert.equals(0, vim.fn.isdirectory(root .. "/assets/" .. TS), "the folder this paste created is gone")
        assert.equals(0, vim.fn.isdirectory(root .. "/assets"), "and so is the empty parent")
        assert.equals(1, reads())

        parley.paste_image(buf, { notify = notify })
        assert.is_true(wait_for(function() return line_count(buf) == 10 end), "the next paste is accepted")
        assert.matches("pasted assets/", notices[#notices].msg)
    end)

    it("an insertion failure never removes a folder that existed before the paste", function()
        vim.env.PARLEY_FAKE_CLIPBOARD = "png:" .. png
        local folder = root .. "/assets/" .. TS
        vim.fn.mkdir(folder, "p")
        vim.fn.writefile({ "older" }, folder .. "/older.png")
        local buf = open_chat(TS .. "_keepfolder.md", chat_lines())
        local buffer_edit = require("parley.buffer_edit")
        local saved_insert = buffer_edit.insert_lines_at
        buffer_edit.insert_lines_at = function()
            error("simulated")
        end
        local ok, err = pcall(function()
            parley.paste_image(buf, { notify = notify })
            assert.is_true(wait_for(function() return #notices > 0 end))
        end)
        buffer_edit.insert_lines_at = saved_insert
        assert.is_true(ok, tostring(err))
        assert.matches("could not insert", notices[1].msg)
        assert.same({ "older.png" }, vim.fn.readdir(folder), "only the rolled-back file is gone")
    end)

    it("<M-v> is a parley_buffer entry resolving to n/i through the registry", function()
        local reg = require("parley.keybinding_registry")
        local entry
        for _, e in ipairs(reg.entries) do
            if e.id == "paste_image" then entry = e end
        end
        assert.is_not_nil(entry)
        assert.equals("parley_buffer", entry.scope)
        local keys, modes = reg.resolve_keys(entry, parley.config)
        assert.same({ "<M-v>" }, keys)
        assert.same({ "n", "i" }, modes)
    end)
end)

describe("paste image: shrink on save (#244)", function()
    local png_gen = require("tests.helpers.png_gen")
    local fake_sips = repo .. "/tests/fixtures/fake_sips"
    local jpg = repo .. "/tests/fixtures/one_pixel.jpg"
    local slog = root .. "/sips.log"
    local big_png = root .. "/big.png"

    local function shrink_runs()
        return vim.fn.filereadable(slog) == 1 and vim.fn.readfile(slog) or {}
    end
    local function setup_with(assets_cfg)
        parley.setup({
            chat_dir = root, state_dir = vim.fn.tempname() .. "-parley-paste-state",
            providers = {}, api_keys = {},
            assets = vim.tbl_extend("force", { clipboard_cmd = { fake_clipboard, "{out}" } }, assets_cfg),
        })
    end
    local function paste_and_wait(buf)
        parley.paste_image(buf, { notify = notify })
        assert.is_true(wait_for(function() return #notices > 0 end), "a notice arrived")
        return notices[#notices]
    end

    before_each(function()
        notices = {}
        os.remove(slog)
        vim.env.PARLEY_FAKE_SIPS_LOG = slog
        vim.fn.mkdir(root, "p")
        assets.default_io.write(big_png, png_gen.png_bytes(1800, 4)) -- over the edge, small in bytes
        vim.env.PARLEY_FAKE_CLIPBOARD = "png:" .. big_png
    end)
    after_each(function()
        vim.env.PARLEY_FAKE_SIPS = nil
        vim.env.PARLEY_FAKE_SIPS_LOG = nil
        vim.env.PARLEY_FAKE_CLIPBOARD = nil
        vim.env.PARLEY_FAKE_CLIPBOARD_LOG = nil
        vim.cmd("silent! %bwipeout!")
        vim.fn.delete(root, "rf")
        setup_with({})
    end)

    it("a PNG over the edge lands as .jpg with both sizes in the notice; the tool got the capped edge", function()
        setup_with({ shrink_cmd = { fake_sips, "--resampleHeightWidthMax", "{max}", "{in}", "--out", "{out}" } })
        vim.env.PARLEY_FAKE_SIPS = "ok:" .. jpg
        local buf = open_chat(TS .. "_big.md", chat_lines())
        vim.api.nvim_win_set_cursor(0, { 8, 0 })
        local n = paste_and_wait(buf)
        assert.matches("pasted assets/.*%.jpg %(", n.msg)
        assert.matches("→", n.msg)
        assert.equals("info", n.level)
        local att = assets.parse_attachment(vim.api.nvim_buf_get_lines(buf, 8, 9, false)[1])
        assert.equals(bytes_of(jpg), bytes_of(root .. "/" .. att.path))
        local runs = shrink_runs()
        assert.equals(1, #runs)
        local args = vim.json.decode(runs[1])
        assert.same({ "--resampleHeightWidthMax", "1600" }, { args[1], args[2] })
    end)

    it("a small PNG is stored byte-identical and the tool is never run", function()
        setup_with({ shrink_cmd = { fake_sips, "--resampleHeightWidthMax", "{max}", "{in}", "--out", "{out}" } })
        vim.env.PARLEY_FAKE_SIPS = "ok:" .. jpg
        local small = root .. "/small.png"
        assert(assets.default_io.write(small, png_gen.png_bytes(200, 200))) -- about 120 KB
        vim.env.PARLEY_FAKE_CLIPBOARD = "png:" .. small
        local buf = open_chat(TS .. "_small.md", chat_lines())
        vim.api.nvim_win_set_cursor(0, { 8, 0 })
        local n = paste_and_wait(buf)
        assert.matches("pasted assets/.*%.png$", n.msg)
        local att = assets.parse_attachment(vim.api.nvim_buf_get_lines(buf, 8, 9, false)[1])
        assert.equals(bytes_of(small), bytes_of(root .. "/" .. att.path))
        assert.same({}, shrink_runs())
    end)

    it("a tool that returns garbage keeps the original PNG and says which tool", function()
        setup_with({ shrink_cmd = { fake_sips, "--resampleHeightWidthMax", "{max}", "{in}", "--out", "{out}" } })
        vim.env.PARLEY_FAKE_SIPS = "garbage"
        local buf = open_chat(TS .. "_garbage.md", chat_lines())
        vim.api.nvim_win_set_cursor(0, { 8, 0 })
        local n = paste_and_wait(buf)
        assert.matches("pasted assets/.*%.png — original kept: .*fake_sips wrote something that is not a JPEG", n.msg)
        assert.equals("warn", n.level)
        local att = assets.parse_attachment(vim.api.nvim_buf_get_lines(buf, 8, 9, false)[1])
        assert.equals(bytes_of(big_png), bytes_of(root .. "/" .. att.path))
    end)

    it("no tool at all: original stored, one warning names what to install, the next paste is quiet", function()
        setup_with({ shrink_cmd = nil })
        -- Hide every real tool from the probe for this case.
        require("parley.image_shrink").configure(parley.config.assets, {
            sysname = "Darwin", manager = "brew", executable = function() return false end,
        })
        local buf = open_chat(TS .. "_notool.md", chat_lines())
        vim.api.nvim_win_set_cursor(0, { 8, 0 })
        local n1 = paste_and_wait(buf)
        assert.matches("original kept: no image shrink tool found: sips ships with macOS or brew install imagemagick", n1.msg)
        assert.equals("warn", n1.level)
        notices = {}
        vim.api.nvim_win_set_cursor(0, { 8, 0 })
        local n2 = paste_and_wait(buf)
        assert.matches("pasted assets/.*%.png$", n2.msg)
        assert.equals("info", n2.level)
    end)

    it("disabling shrinking preserves a large PNG and never runs the configured tool", function()
        setup_with({ shrink = false, shrink_cmd = { fake_sips, "{in}", "{out}", "{max}" } })
        vim.env.PARLEY_FAKE_SIPS = "garbage"
        local buf = open_chat(TS .. "_disabled.md", chat_lines())
        vim.api.nvim_win_set_cursor(0, { 8, 0 })
        local notice = paste_and_wait(buf)
        local att = assets.parse_attachment(vim.api.nvim_buf_get_lines(buf, 8, 9, false)[1])
        assert.equals(bytes_of(big_png), bytes_of(root .. "/" .. att.path))
        assert.matches("%.png$", notice.msg)
        assert.same({}, shrink_runs())
    end)
end)
