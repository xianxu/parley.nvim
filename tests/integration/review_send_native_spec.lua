-- Preserve builtin notifications: replacing them hides hit-enter regressions.
local arrival = require("tests.helpers.arrival")
local Embedded = require("tests.helpers.embedded_nvim")

describe("local review native input", function()
    local child, root

    before_each(function()
        root = vim.fn.resolve(vim.fn.tempname()) .. "-review-native"
        vim.fn.mkdir(root, "p")
        child = Embedded.start({ ui = { 80, 24 } })
        child:exec([[
            local root = ...
            vim.env.COUCH_THREAD_SCOPE, vim.env.COUCH_THREAD_TAG = nil, nil
            vim.env.PARLEY_REPO_MODE = "0"
            vim.o.swapfile = false
            require("parley").setup({
                repo_root = false, chat_dir = root .. "/chats", state_dir = root .. "/state",
                log_file = root .. "/parley.log", providers = {}, api_keys = {},
            })
            local builtin_notify = vim.notify
            vim.notify = function(message, level, ...)
                vim.fn.writefile({ vim.json.encode({ message = message, level = level }) }, root .. "/notice.jsonl", "a")
                return builtin_notify(message, level, ...)
            end
            -- Keep the real review owner, stopping only at the provider seam.
            require("parley.skill_invoke").invoke = function(buf, manifest, args, opts)
                vim.fn.writefile({ vim.json.encode({ buf = buf, name = manifest.name, args = args, manual = opts.manual }) },
                    root .. "/invocation.json")
            end
        ]], root)
    end)

    after_each(function()
        if child then child:stop(); child = nil end
        if root then vim.fn.delete(root, "rf") end
    end)

    local cases = {
        { name = "no-marker Markdown", document = { "# Notes", "plain prose" }, note = "no markers found" },
        { name = "ready-marker Markdown", document = { "# Notes", "prose 🤖[fix this]" }, ready = true },
        { name = "protected chat", document = { "---", "collaboration-mode: chat", "---", "🤖[answer this]" },
            note = "the hub agent answers chat", chat = true },
        { name = "unnamed Markdown", document = { "# Notes", "🤖[fix this]" },
            note = "save the file first", unnamed = true },
    }

    for _, insert in ipairs({ false, true }) do
        for _, case in ipairs(cases) do
            it("Alt+Return handles " .. case.name .. " in " .. (insert and "Insert" or "Normal") .. " mode", function()
                local before = child:exec([[
                    local root, case = ...
                    if case.unnamed then
                        vim.cmd("enew")
                    else
                        vim.fn.writefile(case.document, root .. "/notes.md")
                        vim.cmd("silent edit " .. vim.fn.fnameescape(root .. "/notes.md"))
                    end
                    vim.bo.filetype = "markdown"
                    vim.api.nvim_buf_set_lines(0, 0, -1, false, case.document)
                    require("parley").setup_markdown_keymaps(vim.api.nvim_get_current_buf())
                    return { lines = vim.api.nvim_buf_get_lines(0, 0, -1, false), modified = vim.bo.modified,
                        tick = vim.api.nvim_buf_get_changedtick(0), buf = vim.api.nvim_get_current_buf() }
                ]], root, case)
                local disk_before = not case.unnamed and vim.fn.readfile(root .. "/notes.md", "b") or nil
                if insert then
                    child:input("i")
                    assert.is_true(vim.wait(arrival.MS, function()
                        return child:request("nvim_get_mode").mode == "i"
                    end))
                end
                child:input("<M-CR>")
                local mode
                assert.is_true(vim.wait(arrival.MS, function()
                    -- Fast RPC is safe even when the real mapping opens input().
                    mode = child:request("nvim_get_mode").mode
                    return mode == "c" or mode == "r"
                        or vim.fn.filereadable(root .. "/invocation.json") == 1
                        or vim.fn.filereadable(root .. "/notice.jsonl") == 1
                end), "the native mapping must report an outcome")
                if mode == "c" then child:input("<Esc>") end
                if mode == "r" then child:input("<CR>") end
                local after = child:exec([[
                    return { lines = vim.api.nvim_buf_get_lines(0, 0, -1, false), modified = vim.bo.modified,
                        tick = vim.api.nvim_buf_get_changedtick(0), messages = vim.fn.execute("messages") }
                ]])
                assert.equals(insert and "i" or "n", mode, "no instruction prompt or hit-enter: " .. after.messages)
                assert.same(before.lines, after.lines)
                assert.equals(before.modified, after.modified)
                assert.equals(before.tick, after.tick, "submit does not rewrite the live document")
                if disk_before then assert.same(disk_before, vim.fn.readfile(root .. "/notes.md", "b")) end
                if not case.unnamed then
                    assert.matches("review: local review requested", after.messages, 1, true)
                end
                if case.note then assert.matches(case.note, after.messages, 1, true) end
                if case.ready then
                    local invocation = vim.json.decode(table.concat(vim.fn.readfile(root .. "/invocation.json"), "\n"))
                    assert.equals(before.buf, invocation.buf)
                    assert.equals("review", invocation.name)
                    assert.same({}, invocation.args)
                    assert.is_true(invocation.manual)
                else
                    assert.equals(0, vim.fn.filereadable(root .. "/invocation.json"), "real marker admission prevents provider work")
                end
                child:input(insert and "typed" or "Atyped<Esc>")
                assert.is_true(vim.wait(arrival.MS, function()
                    if child:request("nvim_get_mode").mode == "r" then return false end
                    return child:exec([[
                        return vim.api.nvim_buf_get_lines(0, 0, 1, false)[1]:find("typed", 1, true) ~= nil
                    ]])
                end), "subsequent typing reaches the buffer")
            end)
        end
    end
end)
