-- parley.note_dirs — note directory management
-- Thin wrapper around root_dirs for the note domain.

local M = {}
local root_dirs = require("parley.root_dirs")
local _parley

local _root_mgr = root_dirs.create({
    domain = "note",
    dir_key = "notes_dir",
    dirs_key = "note_dirs",
    roots_key = "note_roots",
})

M.setup = function(parley)
    _parley = parley
    _root_mgr.setup(parley)
end

--------------------------------------------------------------------------------
-- Delegate all root management to the generic instance
--------------------------------------------------------------------------------

M.get_note_roots = function() return _root_mgr.get_roots() end
M.get_note_dirs = function() return _root_mgr.get_dirs() end
M.find_note_root_record = function(file_name) return _root_mgr.find_root_record(file_name) end
M.find_note_root = function(file_name) return _root_mgr.find_root(file_name) end
M.registered_note_dir = function(dir) return _root_mgr.registered_dir(dir) end
M.note_root_display = function(root, include_dir) return _root_mgr.root_display(root, include_dir) end

M.apply_note_roots = function(roots) return _root_mgr.apply_roots(roots) end
M.apply_note_dirs = function(dirs) return _root_mgr.apply_dirs(dirs) end
M.normalize_note_roots = function(primary, extras, structured) return _root_mgr.normalize_roots(primary, extras, structured) end

M.set_note_dirs = function(dirs, persist) return _root_mgr.set_dirs(dirs, persist) end
M.set_note_roots = function(roots, persist) return _root_mgr.set_roots(roots, persist) end
M.add_note_dir = function(dir, persist, label) return _root_mgr.add_dir(dir, persist, label) end
M.remove_note_dir = function(dir, persist) return _root_mgr.remove_dir(dir, persist) end
M.rename_note_dir = function(dir, label, persist) return _root_mgr.rename_dir(dir, label, persist) end

--------------------------------------------------------------------------------
-- Commands
--------------------------------------------------------------------------------

M.cmd_note_dirs = function(_params)
    _parley.note_dir_picker.note_dir_picker(_parley)
end

M.cmd_note_dir_add = function(params)
    local dir = params and params.args or ""
    if dir == "" then
        dir = vim.fn.input({
            prompt = "Add note dir: ",
            default = vim.fn.getcwd() .. "/",
            completion = "dir",
        })
        vim.cmd("redraw")
    end

    if not dir or dir == "" then
        return
    end

    local normalized, err = M.add_note_dir(dir, true)
    if not normalized then
        vim.notify("Failed to add note dir: " .. err, vim.log.levels.WARN)
        return
    end

    local added_dir = normalized[#normalized]
    _parley.logger.info("Added note dir: " .. added_dir)
    vim.notify("Added note dir: " .. added_dir, vim.log.levels.INFO)
end

M.cmd_note_dir_remove = function(params)
    local dir = params and params.args or ""
    if dir == "" then
        vim.notify("Usage: :" .. _parley.config.cmd_prefix .. "NoteDirRemove <dir>", vim.log.levels.WARN)
        return
    end

    local normalized, err = M.remove_note_dir(dir, true)
    if not normalized then
        vim.notify("Failed to remove note dir: " .. err, vim.log.levels.WARN)
        return
    end

    _parley.logger.info("Removed note dir: " .. dir)
    vim.notify("Removed note dir: " .. dir, vim.log.levels.INFO)
end

return M
