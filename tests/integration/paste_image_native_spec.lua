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
                log_file = root .. "/parley.log",
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

    local cases = {
        { name = "small PNG" },
        { name = "conversion limit", width = 16385, note = "image exceeds conversion limits" },
        { name = "missing tool", width = 1800, missing = true, note = "no image shrink tool found" },
        { name = "malformed tool recipe", width = 1800, malformed = true, note = "{out}" },
        { name = "invalid tool output", width = 1800, tool = "garbage", note = "not a JPEG" },
        { name = "converted JPEG", width = 1800, tool = "ok:", converted = true },
    }
    for _, insert in ipairs({ false, true }) do
        for _, case in ipairs(cases) do
            it("Alt+i pastes " .. case.name .. " without hit-enter in " .. (insert and "Insert" or "Normal") .. " mode", function()
                if case.width then
                    child:exec([[
                        local root, repo, case = ...
                        local assets = require("parley.assets")
                        local bytes = require("tests.helpers.png_gen").png_bytes(case.width, 1)
                        assert(assets.default_io.write(root .. "/source.png", bytes))
                        vim.env.PARLEY_FAKE_CLIPBOARD = "png:" .. root .. "/source.png"
                        local cfg = require("parley").config.assets
                        cfg.shrink_cmd = case.malformed and { "missing-output-token", "{in}" }
                            or { repo .. "/tests/fixtures/fake_sips", "{in}", "--out", "{out}", "{max}" }
                        if case.missing then
                            cfg.shrink_cmd = nil
                            require("parley.image_shrink").configure(cfg, {
                                sysname = "Darwin", manager = "brew", executable = function() return false end,
                            })
                        else
                            require("parley.image_shrink").configure(cfg)
                        end
                        if case.tool then
                            vim.env.PARLEY_FAKE_SIPS = case.tool == "ok:" and case.tool .. repo .. "/tests/fixtures/one_pixel.jpg"
                                or case.tool
                        end
                    ]], root, repo, case)
                end
                if insert then
                    child:input("i")
                    assert.is_true(vim.wait(arrival.MS, function()
                        return child:exec([[return vim.api.nvim_get_mode().mode == "i"]])
                    end))
                end
                child:input("<M-i>")
                local mode
                assert.is_true(vim.wait(arrival.MS, function()
                    if #vim.fn.glob(root .. "/assets/**/*.*", false, true) == 0 then return false end
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
                local expected_path = case.converted and repo .. "/tests/fixtures/one_pixel.jpg"
                    or case.width and root .. "/source.png" or repo .. "/tests/fixtures/one_pixel.png"
                local expected = require("parley.assets").default_io.read(expected_path, 1024 * 1024)
                assert.equals(expected, result.bytes)
                local details = table.concat(vim.fn.readfile(root .. "/parley.log"), "\n")
                local attachment = require("parley.assets").parse_attachment(result.line)
                assert.matches("Image pasted: " .. attachment.path, details, 1, true)
                if case.note then assert.matches(case.note, details, 1, true) end
                if case.converted then
                    local assets = require("parley.assets")
                    local source = assets.default_io.read(root .. "/source.png", 1024 * 1024)
                    assert.matches(assets.human_size(#source) .. " → " .. assets.human_size(#expected), details, 1, true)
                    assert.matches(".jpg", result.line, 1, true)
                end
                child:input(insert and "typed" or "Atyped<Esc>")
                assert.is_true(vim.wait(arrival.MS, function()
                    return child:exec([[
                        return vim.api.nvim_buf_get_lines(0, 0, -1, false)[1]:find("typed", 1, true) ~= nil
                    ]])
                end), "ordinary input after paste is not consumed by a prompt")
            end)
        end
    end
end)
