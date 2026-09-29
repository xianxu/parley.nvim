-- Recording-only additions. The packaged app stays the source of app defaults.
local runtime = assert(vim.env.PARLEY_RUNTIME, "Launch with ./parley_app --demo")
local keys = {
    ["<TAB>"] = "Tab", ["<CR>"] = "Enter", ["<ESC>"] = "Esc",
    ["<SPACE>"] = "Space", ["<BS>"] = "Backspace", ["<LEFT>"] = "Left",
    ["<RIGHT>"] = "Right", ["<UP>"] = "Up", ["<DOWN>"] = "Down", ["SUPER"] = "Cmd",
}
for n = 1, 12 do keys["<F" .. n .. ">"] = "F" .. n end
local plugins = {
    { "NStefan002/screenkey.nvim",
        commit = "16390931d847b1d5d77098daccac4e55654ac9e2", -- v2.4.2
        lazy = false, opts = { keys = keys, show_leader = false } },
}
assert(loadfile(runtime .. "/packaging/starter-config/init.lua"))(plugins)
-- Show keys once Neovim has opened its initial file.
vim.api.nvim_create_autocmd("VimEnter", { once = true, callback = function() vim.cmd("Screenkey") end })
