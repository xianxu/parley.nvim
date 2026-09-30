-- Recording-only additions. The packaged app stays the source of app defaults.
local runtime = assert(vim.env.PARLEY_RUNTIME, "Launch with ./parley_app --demo")
local keys = {
    ["<TAB>"] = "Tab", ["<CR>"] = "Enter", ["<ESC>"] = "Esc",
    ["<SPACE>"] = "Space", ["<BS>"] = "Backspace", ["<LEFT>"] = "Left",
    ["<RIGHT>"] = "Right", ["<UP>"] = "Up", ["<DOWN>"] = "Down", ["SUPER"] = "Cmd",
}
for n = 1, 12 do keys["<F" .. n .. ">"] = "F" .. n end
local screenkey = dofile(runtime .. '/lua/parley/editor_dependencies.lua').plugin('screenkey.nvim')
screenkey.lazy = false
screenkey.opts = { keys = keys, show_leader = false }
local plugins = { screenkey }
assert(loadfile(runtime .. "/packaging/starter-config/init.lua"))(plugins)
-- Show keys once Neovim has opened its initial file.
vim.api.nvim_create_autocmd("VimEnter", { once = true, callback = function() vim.cmd("Screenkey") end })
