-- parley.root_dirs — generic multi-root directory manager
-- Shared logic for chat roots and note roots. Domain modules (chat_dirs, note_dirs)
-- call root_dirs.create() with their config key names to get a specialized instance.

local M = {}

--------------------------------------------------------------------------------
-- Shared helpers (stateless, used by all instances)
--------------------------------------------------------------------------------

function M.resolve_dir_key(dir)
    return vim.fn.resolve(vim.fn.expand(dir)):gsub("/+$", "")
end

function M.path_within_dir(path, dir, helpers)
    local resolved_path = M.resolve_dir_key(path)
    local resolved_dir = M.resolve_dir_key(dir)
    return resolved_path == resolved_dir or helpers.starts_with(resolved_path, resolved_dir .. "/")
end

function M.default_root_label(dir, is_primary)
    if is_primary then
        return "main"
    end
    local base = vim.fn.fnamemodify(M.resolve_dir_key(dir), ":t")
    if base == nil or base == "" then
        return "extra"
    end
    return base
end

--------------------------------------------------------------------------------
-- Factory: create a domain-specific root manager
--------------------------------------------------------------------------------

--- Create a root manager for a specific domain (chat, note, etc.)
--- @param spec table { domain: string, dir_key: string, dirs_key: string, roots_key: string }
---   domain   — human-readable name for error messages (e.g. "chat", "note")
---   dir_key  — config key for the primary directory (e.g. "chat_dir", "notes_dir")
---   dirs_key — config key for extra directories (e.g. "chat_dirs", "note_dirs")
---   roots_key — config key for structured roots (e.g. "chat_roots", "note_roots")
function M.create(spec)
    local inst = {}
    local _parley

    local domain = spec.domain
    local dir_key = spec.dir_key
    local dirs_key = spec.dirs_key
    local roots_key = spec.roots_key

    inst.setup = function(parley)
        _parley = parley
    end

    -- Normalize a primary dir + extras + structured roots into a canonical roots array
    local function normalize_roots(primary_dir, extra_dirs, structured_roots)
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

            local prepared = _parley.helpers.prepare_dir(dir, domain)
            local resolved = M.resolve_dir_key(prepared)
            local existing = seen[resolved]
            if existing then
                if (roots[existing].label == nil or roots[existing].label == ""
                    or roots[existing].label == M.default_root_label(roots[existing].dir, roots[existing].is_primary))
                    and type(label) == "string" and label ~= "" then
                    roots[existing].label = label
                end
                return
            end

            local root = {
                dir = prepared,
                label = (type(label) == "string" and label ~= "") and label or M.default_root_label(prepared, is_primary),
                is_primary = is_primary,
                role = is_primary and "primary" or "extra",
            }
            table.insert(roots, root)
            seen[resolved] = #roots
        end

        if type(structured_roots) == "table" and #structured_roots > 0 then
            for index, root in ipairs(structured_roots) do
                add_root(root, index == 1)
            end
        else
            add_root(primary_dir, true)

            if type(extra_dirs) == "string" then
                add_root(extra_dirs, false)
            elseif type(extra_dirs) == "table" then
                for _, dir in ipairs(extra_dirs) do
                    add_root(dir, false)
                end
            end
        end

        if #roots > 0 then
            roots[1].is_primary = true
            roots[1].role = "primary"
            if roots[1].label == nil or roots[1].label == "" then
                roots[1].label = M.default_root_label(roots[1].dir, true)
            end
            for index = 2, #roots do
                roots[index].is_primary = false
                roots[index].role = "extra"
                if roots[index].label == nil or roots[index].label == "" then
                    roots[index].label = M.default_root_label(roots[index].dir, false)
                end
            end
        end

        return roots
    end

    -- Apply structured roots to config
    local function apply_roots(roots_list)
        if type(roots_list) ~= "table" or #roots_list == 0 then
            return nil, "at least one " .. domain .. " directory is required"
        end

        local primary = nil
        local additional = {}
        for index, root in ipairs(roots_list) do
            if index == 1 then
                primary = root
            else
                table.insert(additional, root)
            end
        end

        local normalized = normalize_roots(primary, additional, nil)
        if #normalized == 0 then
            return nil, "at least one " .. domain .. " directory is required"
        end

        _parley.config[roots_key] = normalized
        _parley.config[dir_key] = normalized[1].dir
        _parley.config[dirs_key] = vim.tbl_map(function(root)
            return root.dir
        end, normalized)
        return normalized
    end

    -- Apply flat dirs list to config
    local function apply_dirs(dirs_list)
        if type(dirs_list) ~= "table" or #dirs_list == 0 then
            return nil, "at least one " .. domain .. " directory is required"
        end

        local primary = dirs_list[1]
        local additional = {}
        for i = 2, #dirs_list do
            table.insert(additional, dirs_list[i])
        end

        return apply_roots(normalize_roots(primary, additional, nil))
    end

    -- Public API

    inst.get_roots = function()
        if type(_parley.config[roots_key]) == "table" and #_parley.config[roots_key] > 0 then
            return _parley.config[roots_key]
        end
        local roots = normalize_roots(_parley.config[dir_key], _parley.config[dirs_key], nil)
        _parley.config[roots_key] = roots
        return roots
    end

    inst.get_dirs = function()
        local roots = inst.get_roots()
        if #roots > 0 then
            return vim.tbl_map(function(root) return root.dir end, roots)
        end
        if type(_parley.config[dir_key]) == "string" and _parley.config[dir_key] ~= "" then
            return { _parley.config[dir_key] }
        end
        return {}
    end

    inst.find_root_record = function(file_name)
        local resolved_file = M.resolve_dir_key(file_name)
        for _, root in ipairs(inst.get_roots()) do
            if M.path_within_dir(resolved_file, root.dir, _parley.helpers) then
                return root, resolved_file
            end
        end
        return nil, resolved_file
    end

    inst.find_root = function(file_name)
        local root, resolved_file = inst.find_root_record(file_name)
        return root and root.dir or nil, resolved_file
    end

    inst.registered_dir = function(dir)
        local resolved = M.resolve_dir_key(dir)
        for _, root in ipairs(inst.get_roots()) do
            if M.resolve_dir_key(root.dir) == resolved then
                return resolved
            end
        end
        return nil
    end

    inst.root_display = function(root, include_dir)
        local prefix = root.is_primary and "* primary" or "  extra  "
        local display = string.format("%s [%s]", prefix, root.label)
        if include_dir then
            display = string.format("%s %s", display, root.dir)
        end
        return display
    end

    inst.apply_roots = apply_roots
    inst.apply_dirs = apply_dirs
    inst.normalize_roots = normalize_roots

    inst.set_dirs = function(dirs_list, persist)
        local normalized, err = apply_dirs(dirs_list)
        if not normalized then
            return nil, err
        end

        if persist ~= false then
            _parley.refresh_state({
                [dirs_key] = vim.deepcopy(inst.get_dirs()),
                [roots_key] = vim.deepcopy(inst.get_roots()),
            })
        end

        return inst.get_dirs()
    end

    inst.set_roots = function(roots_list, persist)
        local normalized, err = apply_roots(roots_list)
        if not normalized then
            return nil, err
        end

        if persist ~= false then
            _parley.refresh_state({
                [dirs_key] = vim.deepcopy(inst.get_dirs()),
                [roots_key] = vim.deepcopy(inst.get_roots()),
            })
        end

        return inst.get_roots()
    end

    inst.add_dir = function(dir, persist, label)
        local roots = vim.deepcopy(inst.get_roots())
        table.insert(roots, {
            dir = dir,
            label = label,
        })
        local normalized, err = inst.set_roots(roots, persist)
        if not normalized then
            return nil, err
        end
        return inst.get_dirs()
    end

    inst.remove_dir = function(dir, persist)
        local target = M.resolve_dir_key(dir)
        local current_roots = inst.get_roots()
        if #current_roots > 0 and M.resolve_dir_key(current_roots[1].dir) == target then
            return nil, "cannot remove the primary " .. domain .. " directory"
        end
        local remaining = {}
        local removed = false

        for _, root in ipairs(current_roots) do
            if M.resolve_dir_key(root.dir) == target then
                removed = true
            else
                table.insert(remaining, root)
            end
        end

        if not removed then
            return nil, domain .. " directory not found: " .. dir
        end

        if #remaining == 0 then
            return nil, "at least one " .. domain .. " directory is required"
        end

        local normalized, err = inst.set_roots(remaining, persist)
        if not normalized then
            return nil, err
        end
        return inst.get_dirs()
    end

    inst.rename_dir = function(dir, label, persist)
        local target = M.resolve_dir_key(dir)
        local roots = vim.deepcopy(inst.get_roots())
        local updated = false

        for _, root in ipairs(roots) do
            if M.resolve_dir_key(root.dir) == target then
                root.label = (type(label) == "string" and label ~= "") and label or M.default_root_label(root.dir, root.is_primary)
                updated = true
                break
            end
        end

        if not updated then
            return nil, domain .. " directory not found: " .. dir
        end

        local normalized, err = inst.set_roots(roots, persist)
        if not normalized then
            return nil, err
        end
        return inst.get_roots()
    end

    return inst
end

return M
