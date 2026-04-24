-- parley.chat_dirs — chat directory management
-- Thin wrapper around root_dirs for the chat domain.

local M = {}
local root_dirs = require("parley.root_dirs")
local _parley

local _root_mgr = root_dirs.create({
    domain = "chat",
    dir_key = "chat_dir",
    dirs_key = "chat_dirs",
    roots_key = "chat_roots",
})

M.setup = function(parley)
    _parley = parley
    _root_mgr.setup(parley)
end

--------------------------------------------------------------------------------
-- Delegate all root management to the generic instance
--------------------------------------------------------------------------------

M.get_chat_roots = function() return _root_mgr.get_roots() end
M.get_chat_dirs = function() return _root_mgr.get_dirs() end
M.find_chat_root_record = function(file_name) return _root_mgr.find_root_record(file_name) end
M.find_chat_root = function(file_name) return _root_mgr.find_root(file_name) end
M.registered_chat_dir = function(dir) return _root_mgr.registered_dir(dir) end
M.chat_root_display = function(root, include_dir) return _root_mgr.root_display(root, include_dir) end

M.apply_chat_roots = function(roots) return _root_mgr.apply_roots(roots) end
M.apply_chat_dirs = function(dirs) return _root_mgr.apply_dirs(dirs) end
M.normalize_chat_roots = function(primary, extras, structured) return _root_mgr.normalize_roots(primary, extras, structured) end

M.set_chat_dirs = function(dirs, persist) return _root_mgr.set_dirs(dirs, persist) end
M.set_chat_roots = function(roots, persist) return _root_mgr.set_roots(roots, persist) end
M.add_chat_dir = function(dir, persist, label) return _root_mgr.add_dir(dir, persist, label) end
M.remove_chat_dir = function(dir, persist) return _root_mgr.remove_dir(dir, persist) end
M.rename_chat_dir = function(dir, label, persist) return _root_mgr.rename_dir(dir, label, persist) end

--------------------------------------------------------------------------------
-- Commands (chat-specific)
--------------------------------------------------------------------------------

M.cmd_chat_dirs = function(_params)
    _parley.chat_dir_picker.chat_dir_picker(_parley)
end

M.cmd_chat_move = function(params)
    local file_name = vim.api.nvim_buf_get_name(0)
    local target_dir = params and params.args or ""

    if target_dir ~= "" then
        local new_file, err = _parley.move_chat_tree(file_name, target_dir)
        if not new_file then
            vim.notify("Failed to move chat tree: " .. err, vim.log.levels.WARN)
            return
        end

        vim.notify("Moved chat tree to: " .. new_file, vim.log.levels.INFO)
        return
    end

    _parley.prompt_chat_move(file_name)
end

M.cmd_chat_dir_add = function(params)
    local dir = params and params.args or ""
    if dir == "" then
        dir = vim.fn.input({
            prompt = "Add chat dir: ",
            default = vim.fn.getcwd() .. "/",
            completion = "dir",
        })
        vim.cmd("redraw")
    end

    if not dir or dir == "" then
        return
    end

    local normalized, err = M.add_chat_dir(dir, true)
    if not normalized then
        vim.notify("Failed to add chat dir: " .. err, vim.log.levels.WARN)
        return
    end

    local added_dir = normalized[#normalized]
    _parley.logger.info("Added chat dir: " .. added_dir)
    vim.notify("Added chat dir: " .. added_dir, vim.log.levels.INFO)
end

M.cmd_chat_dir_remove = function(params)
    local dir = params and params.args or ""
    if dir == "" then
        vim.notify("Usage: :" .. _parley.config.cmd_prefix .. "ChatDirRemove <dir>", vim.log.levels.WARN)
        return
    end

    local normalized, err = M.remove_chat_dir(dir, true)
    if not normalized then
        vim.notify("Failed to remove chat dir: " .. err, vim.log.levels.WARN)
        return
    end

    _parley.logger.info("Removed chat dir: " .. dir)
    vim.notify("Removed chat dir: " .. dir, vim.log.levels.INFO)
end

return M
