-- Run with actual pinned theme repositories installed under PARLEY_THEME_ROOT:
-- PARLEY_THEME_ROOT=/path/to/lazy nvim --headless -u NONE -l tests/packaging/theme_compatibility.lua
local ok, err = pcall(function()
    vim.opt.runtimepath:prepend(vim.fn.getcwd())
    local theme = require("parley.theme")
    local root = assert(vim.env.PARLEY_THEME_ROOT, "set PARLEY_THEME_ROOT to the installed lazy plugin root")
    for _, plugin in ipairs(theme.packaged_plugins()) do
        local path = root .. "/" .. plugin.name
        assert(vim.fn.isdirectory(path) == 1, "missing theme dependency: " .. path)
        vim.opt.runtimepath:append(path)
    end
    vim.o.termguicolors = true
    vim.cmd.colorscheme("moonfly")
    local parley = require("parley")
    local scratch = vim.fn.tempname()
    parley.setup({ chat_dir = scratch .. "/chats", state_dir = scratch .. "/state",
        providers = {}, api_keys = {}, cliproxy = { manage = false } })
    local groups = { "Normal", "Comment", "String", "Identifier", "Title", "NormalFloat",
        "FloatBorder", "StatusLine", "ParleyQuestion", "ParleyThinking", "ParleyAnnotation",
        "ParleyFileReference", "ParleyToolError" }
    for _, spec in ipairs(theme.items()) do
        local applied, why = theme.apply(spec.id, { on_applied = parley.setup_highlight })
        assert(applied, spec.id .. ": " .. tostring(why))
        assert(vim.o.background == spec.mode, spec.id .. ": incorrect background")
        for _, group in ipairs(groups) do
            local hl = vim.api.nvim_get_hl(0, { name = group, link = false })
            assert(next(hl), spec.id .. ": missing " .. group)
            if hl.fg and hl.bg then
                assert(hl.fg ~= hl.bg, spec.id .. ": invisible " .. group)
            end
        end
        print("PASS " .. spec.id)
    end
    vim.fn.delete(scratch, "rf")
end)
if not ok then
    io.stderr:write(tostring(err) .. "\n")
    vim.cmd("cquit 1")
end
vim.cmd("qa!")
