-- Exercise the real mapping and event-loop mode transitions in a clean editor.
-- Command spies cannot prove that startinsert lands in the destination buffer.
local arrival = require("tests.helpers.arrival")
local Embedded = require("tests.helpers.embedded_nvim")
describe("entity navigation native input", function()
    local child, root, source, target

    local function exec(code, ...)
        return child:exec(code, ...)
    end

    local function keys(input)
        child:input(input)
    end

    local function wait_for(code)
        assert.is_true(vim.wait(arrival.MS, function() return exec(code) end), code)
    end

    before_each(function()
        root = vim.fn.resolve(vim.fn.tempname()) .. "-entity-navigation"
        vim.fn.mkdir(root, "p")
        source, target = root .. "/source.md", root .. "/answer.md"
        vim.fn.writefile({ "# Answer", "The destination is a real file." }, target)
        child = Embedded.start({ ui = { 100, 30 } })
        exec([[
            local root = ...
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
        ]], root)
    end)

    after_each(function()
        if child then child:stop() end
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
                assert.same({ source, target }, exec([[return require("parley.file_history").snapshot(0).paths]]))
                assert.same(lines, vim.fn.readfile(source))
            end)
        end

        local list_cases = {
            {
                name = "tight unordered item prose before its inline link",
                lines = { "- Item one [other](other.md)", "- Item two [answer](answer.md)" },
                row = 2,
            },
            {
                name = "tight unordered item prose",
                lines = { "- Other [other](other.md)", "- Chosen item prose",
                    "  [answer](answer.md)", "- Last [last](last.md)" },
                row = 2,
            },
            {
                name = "tight unordered item continuation",
                lines = { "- Other [other](other.md)", "- Chosen item prose",
                    "  continuation text", "  [answer](answer.md)", "- Last [last](last.md)" },
                row = 3,
            },
            {
                name = "loose unordered item continuation",
                lines = { "- Other [other](other.md)", "", "- Chosen item prose", "",
                    "  continuation text", "  [answer](answer.md)", "", "- Last [last](last.md)" },
                row = 5,
            },
            {
                name = "nested unordered item continuation",
                lines = { "- Parent [parent](parent.md)", "  - Other [other](other.md)",
                    "  - Chosen item prose", "    continuation text", "    [answer](answer.md)",
                    "  - Last [last](last.md)", "- Outside [outside](outside.md)" },
                row = 4,
            },
            {
                name = "direct link label in a tight unordered list",
                lines = { "- Other [other](other.md)", "- [answer](answer.md)", "- Last [last](last.md)" },
                row = 2,
                col = 4,
            },
        }
        for _, case in ipairs(list_cases) do
            it("opens the sole link from " .. case.name .. " without a picker in " .. mode .. " mode", function()
                for _, name in ipairs({ "other", "last", "parent", "outside" }) do
                    vim.fn.writefile({ "# " .. name }, root .. "/" .. name .. ".md")
                end
                open_source(case.lines, case.row, false)
                exec([[local row, col = ...; vim.api.nvim_win_set_cursor(0, { row, col })]], case.row, case.col or 0)
                if insert then
                    keys("i")
                    wait_for([[return vim.api.nvim_get_mode().mode == "i"]])
                end
                exec([[vim.ui.select = function(items) _G.unexpected_picker = items end]])
                keys("<M-o>")
                wait_for([[return vim.api.nvim_buf_get_name(0) == target or _G.unexpected_picker ~= nil]])
                assert.is_false(exec([[return _G.unexpected_picker ~= nil]]), "enclosing item must exclude sibling links")
                wait_for(insert and [[return vim.api.nvim_get_mode().mode == "i"]]
                    or [[return vim.api.nvim_get_mode().mode == "n"]])
                assert.same({ source, target }, exec([[return require("parley.file_history").snapshot(0).paths]]))
                assert.same(case.lines, vim.fn.readfile(source))
            end)
        end

        it("keeps an enclosing item's same-file anchor jump in " .. mode .. " mode", function()
            open_source({"- Jump to the section", "  [here](source.md#target)", "", "# Target"}, 1, insert)
            exec([[
                local p = require("parley")
                local open = p.cmd.OpenFileUnderCursor
                p.cmd.OpenFileUnderCursor = function() open(); _G.jump_completed = true end
                p.setup_markdown_keymaps(vim.api.nvim_get_current_buf())
            ]])
            keys("<M-o>")
            wait_for([[return _G.jump_completed == true]])
            assert.equals(4, exec("return vim.api.nvim_win_get_cursor(0)[1]"))
        end)

        for _, fragment in ipairs({ "revised-plan-ready-10-21-0040", "unknown-section", "" }) do
            local description = fragment == "" and "plain file link"
                or (fragment == "unknown-section" and "unknown heading anchor" or "heading anchor")
            it("opens a " .. description .. " in " .. mode .. " mode through <M-o>", function()
                local heading = "## Revised plan ready (10-21: 0040)"
                vim.fn.writefile({ "# Answer", "", "```markdown", heading, "```", "", heading,
                    "The real section." }, target)
                local suffix = fragment == "" and "" or "#" .. fragment
                open_source({ "[answer](answer.md" .. suffix .. ")" }, 1, insert)
                keys("<M-o>")
                wait_for([[return vim.api.nvim_buf_get_name(0) == target]])
                wait_for(insert and [[return vim.api.nvim_get_mode().mode == "i"]]
                    or [[return vim.api.nvim_get_mode().mode == "n"]])
                local expected_row = fragment == "revised-plan-ready-10-21-0040" and 7 or 1
                assert.equals(expected_row, exec("return vim.api.nvim_win_get_cursor(0)[1]"))
                assert.same({ source, target }, exec([[return require("parley.file_history").snapshot(0).paths]]))
                if fragment == "unknown-section" then
                    wait_for([[
                        for _, message in ipairs(notifications) do
                            local text = tostring(message):lower()
                            if text:find("unknown-section", 1, true) and text:find("not found", 1, true) then
                                return true
                            end
                        end
                        return false
                    ]])
                else
                    assert.same({}, exec([[return notifications]]))
                end
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
            assert.same({ source }, exec([[return require("parley.file_history").snapshot(0).paths]]))
        end)
    end
end)
