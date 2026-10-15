-- Exercise the real mapping and event-loop mode transitions in a clean editor.
-- Command spies cannot prove that startinsert lands in the destination buffer.
describe("entity navigation native input", function()
    local child, root, source, target

    local function exec(code, ...)
        return vim.rpcrequest(child, "nvim_exec_lua", code, { ... })
    end

    local function keys(input)
        vim.rpcrequest(child, "nvim_input", input)
    end

    local function wait_for(code)
        assert.is_true(vim.wait(2000, function() return exec(code) end), code)
    end

    before_each(function()
        root = vim.fn.resolve(vim.fn.tempname()) .. "-entity-navigation"
        vim.fn.mkdir(root, "p")
        source, target = root .. "/source.md", root .. "/answer.md"
        vim.fn.writefile({ "# Answer", "The destination is a real file." }, target)
        child = vim.fn.jobstart({ vim.v.progpath, "--clean", "--embed", "--headless", "-i", "NONE" }, { rpc = true })
        vim.rpcrequest(child, "nvim_ui_attach", 100, 30, { rgb = true })
        exec([[
            local runtime, root = ...
            vim.opt.rtp:append(runtime)
            vim.cmd("cd " .. vim.fn.fnameescape(root))
            vim.env.PARLEY_REPO_MODE = "0"
            vim.o.swapfile = false
            _G.notifications = {}
            vim.notify = function(message) notifications[#notifications + 1] = message end
            require("parley").setup({
                repo_root = false,
                chat_dir = root .. "/chats",
                state_dir = root .. "/state",
                providers = {},
                api_keys = {},
            })
        ]], vim.fn.getcwd(), root)
    end)

    after_each(function()
        if child and child > 0 then
            vim.fn.jobstop(child)
            vim.fn.jobwait({ child }, 1000)
        end
        if root then vim.fn.delete(root, "rf") end
    end)

    local function open_source(lines, row, insert)
        vim.fn.writefile(lines, source)
        exec([[
            local source, target, row = ...
            _G.source, _G.target = source, target
            vim.cmd("edit " .. vim.fn.fnameescape(source))
            vim.bo.filetype = "markdown"
            require("parley").setup_markdown_keymaps(vim.api.nvim_get_current_buf())
            vim.api.nvim_win_set_cursor(0, { row, 0 })
        ]], source, target, row)
        assert.is_true(exec([[return vim.fn.maparg("<M-o>", "n", false, true).callback ~= nil]]))
        assert.is_true(exec([[return vim.fn.maparg("<M-o>", "i", false, true).callback ~= nil]]))
        if insert then
            keys("i")
            wait_for([[return vim.api.nvim_get_mode().mode == "i"]])
        end
    end

    for _, insert in ipairs({ false, true }) do
        local mode = insert and "Insert" or "Normal"
        for _, entity in ipairs({ "heading", "numbered continuation" }) do
            it("opens from " .. entity .. " in " .. mode .. " mode through <M-o>", function()
                local lines, row
                if entity == "heading" then
                    lines, row = { "## Question", "Some context", "[answer](answer.md)", "## Next" }, 1
                else
                    lines, row = { "## Questions", "7. Investigate this", "", "   continuation text",
                        "   [answer](answer.md)", "8. Another question" }, 4
                end
                open_source(lines, row, insert)
                keys("<M-o>")
                wait_for([[return vim.api.nvim_buf_get_name(0) == target]])
                wait_for(insert and [[return vim.api.nvim_get_mode().mode == "i"]]
                    or [[return vim.api.nvim_get_mode().mode == "n"]])
                assert.same({ "# Answer", "The destination is a real file." },
                    exec([[return vim.api.nvim_buf_get_lines(0, 0, -1, false)]]))
                assert.same(lines, vim.fn.readfile(source))
            end)
        end

        it("cancel preserves source cursor and " .. mode .. " mode", function()
            vim.fn.writefile({ "# Other" }, root .. "/other.md")
            local lines = { "## Choices", "[answer](answer.md)", "[other](other.md)" }
            open_source(lines, 1, insert)
            exec([[
                vim.ui.select = function(items, _, on_select)
                    _G.selection = { items = items, callback = on_select }
                end
            ]])
            keys("<M-o>")
            wait_for([[return _G.selection ~= nil]])
            assert.equals(2, exec([[return #selection.items]]))
            assert.equals(source, exec([[return vim.api.nvim_buf_get_name(0)]]))
            exec([[selection.callback(nil, nil)]])
            wait_for(insert and [[return vim.api.nvim_get_mode().mode == "i"]]
                or [[return vim.api.nvim_get_mode().mode == "n"]])
            assert.equals(source, exec([[return vim.api.nvim_buf_get_name(0)]]))
            assert.same({ 1, 0 }, exec([[return vim.api.nvim_win_get_cursor(0)]]))
            assert.same(lines, exec([[return vim.api.nvim_buf_get_lines(0, 0, -1, false)]]))
        end)
    end
end)
