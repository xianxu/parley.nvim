local Embedded = require("tests.helpers.embedded_nvim")
local arrival = require("tests.helpers.arrival")

describe("Alt+o with no target", function()
    local child, root, source
    local function exec(code, ...) return child:exec(code, ...) end
    local function await(predicate) assert.is_true(vim.wait(arrival.MS, predicate, 10)) end
    before_each(function()
        root = vim.fn.resolve(vim.fn.tempname()) .. "-no-target"
        vim.fn.mkdir(root, "p")
        source = root .. "/source.md"
        vim.fn.writefile({ "error" }, source)
        child = Embedded.start({ ui = { 100, 30 } })
        exec([[
            local root, source = ...
            vim.env.PARLEY_REPO_MODE = "0"
            vim.o.swapfile = false
            vim.cmd("cd " .. vim.fn.fnameescape(root))
            local p = require("parley")
            p.setup({ repo_root = false, breadcrumb = { enable = false },
                chat_dir = root .. "/chats", state_dir = root .. "/state",
                providers = {}, api_keys = {} })
            vim.cmd("edit " .. vim.fn.fnameescape(source))
            vim.bo.filetype = "markdown"
            local open = p.cmd.OpenFileUnderCursor
            p.cmd.OpenFileUnderCursor = function() open(); _G.completed = true end
            p.setup_markdown_keymaps(vim.api.nvim_get_current_buf())
            _G.painted = {}
            local set = vim.api.nvim_set_option_value
            vim.api.nvim_set_option_value = function(name, value, opts)
                if name == "winbar" then painted[#painted + 1] = value end
                return set(name, value, opts)
            end
            vim.v.errmsg = ""
        ]], root, source)
    end)
    after_each(function()
        if child then child:stop() end
        if root then vim.fn.delete(root, "rf") end
    end)
    local function press(insert, at_end)
        if insert then
            child:input(at_end and "A" or "i")
            await(function() return child:request("nvim_get_mode").mode == "i" end)
        end
        child:input("<M-o>")
        await(function()
            local mode = child:request("nvim_get_mode") -- fast even at hit-enter
            assert.is_false(mode.blocking, "Alt+o entered a message prompt: " .. mode.mode)
            return exec("return completed == true")
        end)
    end
    for _, insert in ipairs({ false, true }) do
        for _, original in ipairs({ "", "operator custom bar" }) do
            for _, text in ipairs({ "error", "" }) do
                it("quietly flashes and restores " .. (original == "" and "an absent" or "an existing")
                    .. " bar for " .. (text == "" and "blank text" or "a missing file")
                    .. " in " .. (insert and "Insert" or "Normal"), function()
                    exec([[
                        local text, original = ...
                        vim.api.nvim_buf_set_lines(0, 0, -1, false, { text })
                        vim.bo.modified = false
                        vim.wo.winbar, vim.wo.winhighlight = original, "StatusLine:Search"
                    ]], text, original)
                    press(insert)
                    await(function() return exec([[
                        for _, bar in ipairs(painted) do
                            if bar:find("No file to open", 1, true) then return true end
                        end
                        return false
                    ]]) end)
                    await(function() return exec("return vim.wo.winbar == ...", original) end)
                    assert.equals("StatusLine:Search", exec("return vim.wo.winhighlight"))
                    assert.equals("", exec("return vim.v.errmsg"))
                    assert.equals(source, exec("return vim.api.nvim_buf_get_name(0)"))
                    assert.same({ 1, 0 }, exec("return vim.api.nvim_win_get_cursor(0)"))
                    assert.same({ text }, exec("return vim.api.nvim_buf_get_lines(0, 0, -1, false)"))
                    assert.equals(insert and "i" or "n", child:request("nvim_get_mode").mode)
                    child:input(insert and "z" or "iz")
                    await(function() return exec("return vim.api.nvim_get_current_line():sub(1, 1) == 'z'") end)
                end)
            end
        end
    end
    it("still opens a real bare path through native gf", function()
        local target = root .. "/target.txt"
        vim.fn.writefile({ "destination" }, target)
        exec([[vim.api.nvim_buf_set_lines(0, 0, -1, false, { "target.txt" }); vim.bo.modified = false]])
        press(false)
        assert.equals(target, exec("return vim.api.nvim_buf_get_name(0)"))
        assert.is_false(exec([[
            for _, bar in ipairs(painted) do
                if bar:find("No file to open", 1, true) then return true end
            end
            return false
        ]]))
    end)
    it("keeps explicit missing-link diagnostics", function()
        exec([[
            _G.messages = {}
            vim.notify = function(message) messages[#messages + 1] = tostring(message) end
            vim.api.nvim_buf_set_lines(0, 0, -1, false, { "[missing](absent.md)" })
            vim.bo.modified = false
        ]])
        press(false)
        assert.is_true(exec([[
            for _, message in ipairs(messages) do
                if message:find("not found", 1, true) or message:find("Not found", 1, true) then return true end
            end
            return false
        ]]))
        assert.same({}, exec("return painted"))
    end)
    it("does not suppress a real native open failure", function()
        vim.fn.writefile({ "destination" }, root .. "/target.txt")
        local outcome = exec([[
            vim.o.hidden, vim.o.autowrite, vim.o.autowriteall = false, false, false
            vim.api.nvim_buf_set_lines(0, 0, -1, false, { "target.txt" })
            local ok, err = pcall(require("parley").cmd.OpenFileUnderCursor)
            return { ok = ok, error = tostring(err) }
        ]])
        assert.is_false(outcome.ok)
        assert.matches("E37:", outcome.error)
        assert.same({}, exec("return painted"))
    end)
    it("retains native no-target errors for direct smart gf", function()
        local outcome = exec([[
            local ok, err = pcall(require("parley").cmd.ResolveRefOrGotoFile)
            return { ok = ok, error = tostring(err) }
        ]])
        assert.is_false(outcome.ok)
        assert.matches("E447:", outcome.error)
    end)
    it("drops a notice queued before navigation", function()
        local bars = exec([[
            require("parley.document_band").flash_notice(vim.api.nvim_get_current_win(), "No file to open")
            vim.cmd("enew")
            vim.wait(require("parley.document_band").PULSE_MS * 7) -- absence: entire finite pulse lifetime
            return painted
        ]])
        assert.same({}, bars)
        -- The next RPC runs after the scheduled pulse setup.
        assert.same({}, exec("return painted"))
    end)

    it("preserves an underlying operator lock cell", function()
        local original = exec([[
            _G.owner = require("parley.document_band").new(vim.api.nvim_get_current_buf())
            owner.render({ state = "operator", hl = "ParleySessionSyncOperator", unsent = true })
            return vim.wo.winbar
        ]])
        press(false)
        await(function() return exec([[
            for _, bar in ipairs(painted) do
                if bar:find("No file to open", 1, true) and bar:find("yours", 1, true) then return true end
            end
            return false
        ]]) end)
        await(function() return exec("return vim.wo.winbar == ...", original) end)
        exec("owner.clear()")
    end)

    for _, original in ipairs({ "", "operator custom bar" }) do
        for _, case in ipairs({
            { text = "error", col = 1 }, { text = "error", col = 2 },
            { text = "error", col = 4 }, { text = "error", col = 5 },
            { text = "café字", col = 5 }, { text = "café字", col = 8 },
        }) do
            it("preserves insertion byte " .. case.col .. " in " .. case.text
                .. " with " .. (original == "" and "no bar" or "a custom bar"), function()
                exec([[
                    local text, col, original = ...
                    vim.api.nvim_buf_set_lines(0, 0, -1, false, { text })
                    vim.bo.modified = false
                    vim.api.nvim_win_set_cursor(0, { 1, col })
                    vim.wo.winbar = original
                ]], case.text, case.col, original)
                press(true, case.col == #case.text)
                await(function() return child:request("nvim_get_mode").mode == "i" end)
                assert.same({ 1, case.col }, exec("return vim.api.nvim_win_get_cursor(0)"))
                child:input("Z")
                local expected = case.text:sub(1, case.col) .. "Z" .. case.text:sub(case.col + 1)
                await(function() return exec("return vim.api.nvim_get_current_line() == ...", expected) end)
            end)
        end
    end

end)
