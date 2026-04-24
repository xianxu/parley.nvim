-- Note directory picker module for Parley.nvim
-- Thin wrapper around root_dir_picker for the note domain.

local M = {}

local root_dir_picker = require("parley.root_dir_picker")

function M._build_items(plugin)
    return root_dir_picker.build_items(function() return plugin.get_note_roots() end)
end

function M.note_dir_picker(plugin, initial_dir)
    root_dir_picker.open({
        plugin = plugin,
        title = "Parley Note Roots  <C-n>: add  <C-r>: label  <C-d>: remove",
        domain = "note",
        get_roots = function() return plugin.get_note_roots() end,
        get_dirs = function() return plugin.get_note_dirs() end,
        add_dir = function(dir, persist, label) return plugin.add_note_dir(dir, persist, label) end,
        remove_dir = function(dir, persist) return plugin.remove_note_dir(dir, persist) end,
        rename_dir = function(dir, label, persist) return plugin.rename_note_dir(dir, label, persist) end,
        base_dir_key = "base_notes_dir",
        initial_dir = initial_dir,
        reopen = function(dir) M.note_dir_picker(plugin, dir) end,
    })
end

return M
