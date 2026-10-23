-- Keep the builtin notification surface: a recording notify hides hit-enter.
local arrival = require("tests.helpers.arrival")
local Embedded = require("tests.helpers.embedded_nvim")
local repo = vim.fn.getcwd()

describe("clipboard image native input", function()
    local child, root

    before_each(function()
        root = vim.fn.resolve(vim.fn.tempname()) .. "-paste-native"
        vim.fn.mkdir(root, "p")
        child = Embedded.start({ ui = { 80, 24 } })
        child:exec([[
            local root, repo = ...
            vim.env.PARLEY_REPO_MODE = "0"
            vim.env.PARLEY_FAKE_CLIPBOARD = "png:" .. repo .. "/tests/fixtures/one_pixel.png"
            vim.o.swapfile = false
            require("parley").setup({
                repo_root = false, chat_dir = root, state_dir = root .. "/state",
                providers = {}, api_keys = {},
                assets = { clipboard_cmd = { repo .. "/tests/fixtures/fake_clipboard", "{out}" } },
            })
            local path = root .. "/2026-10-22.12-30-00.123_clipboard-image.md"
            vim.fn.writefile({ "Look at this image" }, path)
            vim.cmd("silent edit " .. vim.fn.fnameescape(path))
            vim.bo.filetype = "markdown"
            require("parley").setup_markdown_keymaps(vim.api.nvim_get_current_buf())
        ]], root, repo)
    end)

    after_each(function()
        if child then child:stop(); child = nil end
        if root then vim.fn.delete(root, "rf") end
    end)

    for _, insert in ipairs({ false, true }) do
        it("Alt+i pastes immediately without hit-enter in " .. (insert and "Insert" or "Normal") .. " mode", function()
            if insert then
                child:input("i")
                assert.is_true(vim.wait(arrival.MS, function()
                    return child:exec([[return vim.api.nvim_get_mode().mode == "i"]])
                end))
            end
            child:input("<M-i>")
            local mode
            assert.is_true(vim.wait(arrival.MS, function()
                if #vim.fn.glob(root .. "/assets/**/*.png", false, true) == 0 then return false end
                mode = child:request("nvim_get_mode").mode
                return true
            end), "Alt+i inserts the link without any confirmation input")
            if mode == "r" then
                child:input("<CR>") -- Inspect only after recording the unwanted prompt.
            end
            local result = child:exec([[
                local line = vim.api.nvim_buf_get_lines(0, 1, 2, false)[1]
                local attachment = require("parley.assets").parse_attachment(line)
                local bytes = attachment and require("parley.assets").default_io.read(
                    vim.fs.dirname(vim.api.nvim_buf_get_name(0)) .. "/" .. attachment.path,
                    require("parley.assets").MAX_BYTES + 1)
                return { mode = vim.api.nvim_get_mode().mode, line = line,
                    bytes = bytes, messages = vim.fn.execute("messages") }
            ]])
            assert.equals(insert and "i" or "n", mode,
                "builtin paste notification must not wait for Enter: " .. result.messages)
            assert.matches("assets/2026%-10%-22%.12%-30%-00%.123/", result.line)
            local expected = require("parley.assets").default_io.read(repo .. "/tests/fixtures/one_pixel.png", 1024)
            assert.equals(expected, result.bytes)
            child:input(insert and "typed" or "Atyped<Esc>")
            assert.is_true(vim.wait(arrival.MS, function()
                return child:exec([[
                    return vim.api.nvim_buf_get_lines(0, 0, -1, false)[1]:find("typed", 1, true) ~= nil
                ]])
            end), "ordinary input after paste is not consumed by a prompt")
        end)
    end
end)
