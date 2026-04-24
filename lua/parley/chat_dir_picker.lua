-- Chat directory picker module for Parley.nvim
-- Thin wrapper around root_dir_picker for the chat domain.

local M = {}

local root_dir_picker = require("parley.root_dir_picker")

function M._build_items(plugin)
    return root_dir_picker.build_items(function() return plugin.get_chat_roots() end)
end

function M.chat_dir_picker(plugin, initial_dir)
    root_dir_picker.open({
        plugin = plugin,
        title = "Parley Chat Roots  <C-n>: add  <C-r>: label  <C-d>: remove",
        domain = "chat",
        get_roots = function() return plugin.get_chat_roots() end,
        get_dirs = function() return plugin.get_chat_dirs() end,
        add_dir = function(dir, persist, label) return plugin.add_chat_dir(dir, persist, label) end,
        remove_dir = function(dir, persist) return plugin.remove_chat_dir(dir, persist) end,
        rename_dir = function(dir, label, persist) return plugin.rename_chat_dir(dir, label, persist) end,
        base_dir_key = "base_chat_dir",
        initial_dir = initial_dir,
        reopen = function(dir) M.chat_dir_picker(plugin, dir) end,
    })
end

return M
