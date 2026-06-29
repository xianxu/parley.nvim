local M = {}
local root_dirs = require("parley.root_dirs")

local root_dir_helpers = {
    starts_with = function(text, prefix)
        return text:sub(1, #prefix) == prefix
    end,
}

local function clean(path)
    if type(path) ~= "string" or path == "" then
        return nil
    end
    return root_dirs.resolve_dir_key(path)
end

local function dirname(path)
    return vim.fs.dirname(path)
end

local function path_within(path, dir)
    if not clean(path) or not clean(dir) then
        return false
    end
    return root_dirs.path_within_dir(path, dir, root_dir_helpers)
end

local function join(root, rel)
    if type(root) ~= "string" or root == "" or type(rel) ~= "string" or rel == "" then
        return nil
    end
    if rel:sub(1, 1) == "/" then
        return clean(rel)
    end
    return clean(root .. "/" .. rel)
end

local function repo_artifact_dirs(config)
    config = config or {}
    local repo_root = clean(config.repo_root)
    if not repo_root then
        return {}
    end
    return {
        join(repo_root, config.repo_chat_dir or "workshop/parley"),
        join(repo_root, config.repo_note_dir or "workshop/notes"),
        join(repo_root, config.issues_dir or "workshop/issues"),
        join(repo_root, config.vision_dir or "workshop/vision"),
        join(repo_root, config.history_dir or "workshop/history"),
    }
end

local function repo_root_from_chat_root(root_dir, config)
    local rel = config and config.repo_chat_dir
    if type(rel) ~= "string" or rel == "" or rel:sub(1, 1) == "/" then
        return nil
    end
    local dir = clean(root_dir)
    local suffix = "/" .. rel:gsub("/+$", "")
    if dir and dir:sub(-#suffix) == suffix then
        return dir:sub(1, #dir - #suffix)
    end
    return nil
end

function M.derive_for_path(path, config, chat_roots)
    local artifact_path = clean(path)
    if not artifact_path then
        return nil, "buffer has no file"
    end

    local repo_root = clean(config and config.repo_root)
    if repo_root then
        for _, dir in ipairs(repo_artifact_dirs(config)) do
            if dir and path_within(artifact_path, dir) then
                return repo_root
            end
        end
    end

    for _, root in ipairs(chat_roots or {}) do
        local dir = type(root) == "table" and (root.dir or root.path) or root
        if dir and path_within(artifact_path, dir) then
            local owner = repo_root_from_chat_root(dir, config)
            if owner then
                return owner
            end
        end
    end

    return dirname(artifact_path)
end

function M.for_buf(buf)
    local path = vim.api.nvim_buf_get_name(buf)
    local config = require("parley").config
    local ok, chat_dirs = pcall(require, "parley.chat_dirs")
    local roots = {}
    if ok and type(chat_dirs.get_chat_roots) == "function" then
        roots = chat_dirs.get_chat_roots()
    end
    return M.derive_for_path(path, config, roots)
end

local function relative_to_root(path, root)
    path = clean(path)
    root = clean(root)
    if not path or not root then
        return nil
    end
    if path == root then
        return ""
    end
    if path:sub(1, #root + 1) == root .. "/" then
        return path:sub(#root + 2)
    end
    return nil
end

function M.completefunc(findstart, base)
    if tonumber(findstart) == 1 then
        local line = vim.api.nvim_get_current_line()
        local col = vim.fn.col(".") - 1
        local start = col
        while start > 0 do
            local ch = line:sub(start, start)
            if ch:match("[%s%(%[%{]") then
                break
            end
            start = start - 1
        end
        return start
    end

    local buf = vim.api.nvim_get_current_buf()
    local root = vim.b[buf].parley_neighborhood_root
    if type(root) ~= "string" or root == "" then
        root = M.for_buf(buf)
    end
    if type(root) ~= "string" or root == "" then
        return {}
    end

    base = base or ""
    local pattern = root .. "/" .. base .. "*"
    local matches = vim.fn.glob(pattern, false, true)
    local items = {}
    for _, match in ipairs(matches) do
        local rel = relative_to_root(match, root)
        if rel and rel ~= "" then
            if vim.fn.isdirectory(match) == 1 then
                rel = rel .. "/"
            end
            table.insert(items, rel)
        end
    end
    table.sort(items)
    return items
end

local function cmp_path_sources(cmp, root)
    local sources = {
        {
            name = "path",
            option = {
                get_cwd = function()
                    return root
                end,
            },
        },
        { name = "buffer" },
    }

    if cmp.config and type(cmp.config.sources) == "function" then
        return cmp.config.sources(sources)
    end
    return sources
end

function M.attach_cmp_completion(buf)
    if not vim.api.nvim_buf_is_valid(buf) then
        return nil
    end

    local root = vim.b[buf].parley_neighborhood_root
    if type(root) ~= "string" or root == "" then
        root = M.for_buf(buf)
    end
    if type(root) ~= "string" or root == "" then
        return nil
    end

    local ok, cmp = pcall(require, "cmp")
    if not ok or type(cmp) ~= "table" or type(cmp.setup) ~= "table" or type(cmp.setup.buffer) ~= "function" then
        return nil
    end

    cmp.setup.buffer({
        completion = {
            keyword_pattern = [[\~\?\(\k\|[\/\.\-]\)\+]],
            keyword_length = 1,
        },
        sources = cmp_path_sources(cmp, root),
    })
    return root
end

local function schedule_cmp_attach(buf)
    vim.schedule(function()
        M.attach_cmp_completion(buf)
    end)
end

function M.attach_completion(buf)
    local root = M.for_buf(buf)
    if type(root) ~= "string" or root == "" then
        return nil
    end
    vim.b[buf].parley_neighborhood_root = root
    vim.api.nvim_set_option_value("completefunc", "v:lua.require'parley.neighborhood'.completefunc", { buf = buf })
    schedule_cmp_attach(buf)
    vim.api.nvim_create_autocmd("InsertEnter", {
        buffer = buf,
        once = true,
        callback = function()
            schedule_cmp_attach(buf)
        end,
    })
    return root
end

return M
