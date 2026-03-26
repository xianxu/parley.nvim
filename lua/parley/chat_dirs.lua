-- parley.chat_dirs — chat directory management
-- Extracted from init.lua. Holds all chat-root state logic, helpers, and commands.

local M = {}
local _parley -- reference to main module (for M.config, M.logger, M.refresh_state)

M.setup = function(parley)
    _parley = parley
end

--------------------------------------------------------------------------------
-- Local helpers
--------------------------------------------------------------------------------

local function path_within_dir(path, dir)
    local resolved_path = vim.fn.resolve(vim.fn.expand(path)):gsub("/+$", "")
    local resolved_dir = vim.fn.resolve(vim.fn.expand(dir)):gsub("/+$", "")
    return resolved_path == resolved_dir or _parley.helpers.starts_with(resolved_path, resolved_dir .. "/")
end

local function resolve_dir_key(dir)
    return vim.fn.resolve(vim.fn.expand(dir)):gsub("/+$", "")
end

local function default_chat_root_label(dir, is_primary)
    if is_primary then
        return "main"
    end

    local base = vim.fn.fnamemodify(resolve_dir_key(dir), ":t")
    if base == nil or base == "" then
        return "extra"
    end
    return base
end

local function normalize_chat_roots(chat_dir, chat_dirs, chat_roots)
    local roots = {}
    local seen = {}

    local function add_root(rootish, is_primary)
        local dir = nil
        local label = nil
        if type(rootish) == "string" then
            dir = rootish
        elseif type(rootish) == "table" then
            dir = rootish.dir or rootish.path
            label = rootish.label
        end

        if type(dir) ~= "string" or dir == "" then
            return
        end

        local prepared = _parley.helpers.prepare_dir(dir, "chat")
        local resolved = resolve_dir_key(prepared)
        local existing = seen[resolved]
        if existing then
            if (roots[existing].label == nil or roots[existing].label == "" or roots[existing].label == default_chat_root_label(roots[existing].dir, roots[existing].is_primary))
                and type(label) == "string" and label ~= "" then
                roots[existing].label = label
            end
            return
        end

        local root = {
            dir = prepared,
            label = (type(label) == "string" and label ~= "") and label or default_chat_root_label(prepared, is_primary),
            is_primary = is_primary,
            role = is_primary and "primary" or "extra",
        }
        table.insert(roots, root)
        seen[resolved] = #roots
    end

    if type(chat_roots) == "table" and #chat_roots > 0 then
        for index, root in ipairs(chat_roots) do
            add_root(root, index == 1)
        end
    else
        add_root(chat_dir, true)

        if type(chat_dirs) == "string" then
            add_root(chat_dirs, false)
        elseif type(chat_dirs) == "table" then
            for _, dir in ipairs(chat_dirs) do
                add_root(dir, false)
            end
        end
    end

    if #roots > 0 then
        roots[1].is_primary = true
        roots[1].role = "primary"
        if roots[1].label == nil or roots[1].label == "" then
            roots[1].label = default_chat_root_label(roots[1].dir, true)
        end
        for index = 2, #roots do
            roots[index].is_primary = false
            roots[index].role = "extra"
            if roots[index].label == nil or roots[index].label == "" then
                roots[index].label = default_chat_root_label(roots[index].dir, false)
            end
        end
    end

    return roots
end

local function apply_chat_roots(chat_roots)
    if type(chat_roots) ~= "table" or #chat_roots == 0 then
        return nil, "at least one chat directory is required"
    end

    local primary = nil
    local additional = {}
    for index, root in ipairs(chat_roots) do
        if index == 1 then
            primary = root
        else
            table.insert(additional, root)
        end
    end

    local normalized = normalize_chat_roots(primary, additional, nil)
    if #normalized == 0 then
        return nil, "at least one chat directory is required"
    end

    _parley.config.chat_roots = normalized
    _parley.config.chat_dir = normalized[1].dir
    _parley.config.chat_dirs = vim.tbl_map(function(root)
        return root.dir
    end, normalized)
    return normalized
end

local function apply_chat_dirs(chat_dirs)
    if type(chat_dirs) ~= "table" or #chat_dirs == 0 then
        return nil, "at least one chat directory is required"
    end

    local primary = chat_dirs[1]
    local additional = {}
    for i = 2, #chat_dirs do
        table.insert(additional, chat_dirs[i])
    end

    return apply_chat_roots(normalize_chat_roots(primary, additional, nil))
end

--------------------------------------------------------------------------------
-- Module functions exposed back to init.lua (and external callers)
--------------------------------------------------------------------------------

M.get_chat_roots = function()
    if type(_parley.config.chat_roots) == "table" and #_parley.config.chat_roots > 0 then
        return _parley.config.chat_roots
    end
    local roots = normalize_chat_roots(_parley.config.chat_dir, _parley.config.chat_dirs, nil)
    _parley.config.chat_roots = roots
    return roots
end

M.get_chat_dirs = function()
    local roots = M.get_chat_roots()
    if #roots > 0 then
        return vim.tbl_map(function(root)
            return root.dir
        end, roots)
    end
    if type(_parley.config.chat_dir) == "string" and _parley.config.chat_dir ~= "" then
        return { _parley.config.chat_dir }
    end
    return {}
end

M.find_chat_root_record = function(file_name)
    local resolved_file = resolve_dir_key(file_name)
    for _, root in ipairs(M.get_chat_roots()) do
        if path_within_dir(resolved_file, root.dir) then
            return root, resolved_file
        end
    end
    return nil, resolved_file
end

M.find_chat_root = function(file_name)
    local root, resolved_file = M.find_chat_root_record(file_name)
    return root and root.dir or nil, resolved_file
end

M.registered_chat_dir = function(dir)
    local resolved = resolve_dir_key(dir)
    for _, root in ipairs(M.get_chat_roots()) do
        if resolve_dir_key(root.dir) == resolved then
            return resolved
        end
    end
    return nil
end

M.chat_root_display = function(root, include_dir)
    local prefix = root.is_primary and "* primary" or "  extra  "
    local display = string.format("%s [%s]", prefix, root.label)
    if include_dir then
        display = string.format("%s %s", display, root.dir)
    end
    return display
end

-- apply_chat_roots / apply_chat_dirs: exposed so init.lua can call them directly
-- for setup() and refresh_state() paths that used to call local versions.
M.apply_chat_roots = apply_chat_roots
M.apply_chat_dirs = apply_chat_dirs
M.normalize_chat_roots = normalize_chat_roots

M.set_chat_dirs = function(chat_dirs, persist)
    local normalized, err = apply_chat_dirs(chat_dirs)
    if not normalized then
        return nil, err
    end

    if persist ~= false then
        _parley.refresh_state({
            chat_dirs = vim.deepcopy(M.get_chat_dirs()),
            chat_roots = vim.deepcopy(M.get_chat_roots()),
        })
    end

    return M.get_chat_dirs()
end

M.set_chat_roots = function(chat_roots, persist)
    local normalized, err = apply_chat_roots(chat_roots)
    if not normalized then
        return nil, err
    end

    if persist ~= false then
        _parley.refresh_state({
            chat_dirs = vim.deepcopy(M.get_chat_dirs()),
            chat_roots = vim.deepcopy(M.get_chat_roots()),
        })
    end

    return M.get_chat_roots()
end

M.add_chat_dir = function(chat_dir, persist, label)
    local roots = vim.deepcopy(M.get_chat_roots())
    table.insert(roots, {
        dir = chat_dir,
        label = label,
    })
    local normalized, err = M.set_chat_roots(roots, persist)
    if not normalized then
        return nil, err
    end
    return M.get_chat_dirs()
end

M.remove_chat_dir = function(chat_dir, persist)
    local target = resolve_dir_key(chat_dir)
    local current_roots = M.get_chat_roots()
    if #current_roots > 0 and resolve_dir_key(current_roots[1].dir) == target then
        return nil, "cannot remove the primary chat directory"
    end
    local remaining = {}
    local removed = false

    for _, root in ipairs(current_roots) do
        if resolve_dir_key(root.dir) == target then
            removed = true
        else
            table.insert(remaining, root)
        end
    end

    if not removed then
        return nil, "chat directory not found: " .. chat_dir
    end

    if #remaining == 0 then
        return nil, "at least one chat directory is required"
    end

    local normalized, err = M.set_chat_roots(remaining, persist)
    if not normalized then
        return nil, err
    end
    return M.get_chat_dirs()
end

M.rename_chat_dir = function(chat_dir, label, persist)
    local target = resolve_dir_key(chat_dir)
    local roots = vim.deepcopy(M.get_chat_roots())
    local updated = false

    for _, root in ipairs(roots) do
        if resolve_dir_key(root.dir) == target then
            root.label = (type(label) == "string" and label ~= "") and label or default_chat_root_label(root.dir, root.is_primary)
            updated = true
            break
        end
    end

    if not updated then
        return nil, "chat directory not found: " .. chat_dir
    end

    local normalized, err = M.set_chat_roots(roots, persist)
    if not normalized then
        return nil, err
    end
    return M.get_chat_roots()
end

--------------------------------------------------------------------------------
-- Commands
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
