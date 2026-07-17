local M = {}
local root_dirs = require("parley.root_dirs")
local repo_artifacts = require("parley.repo_artifacts")

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
    local dirs = {}
    for _, rel in ipairs(repo_artifacts.relative_dirs(config)) do
        local dir = join(repo_root, rel)
        if dir then
            table.insert(dirs, dir)
        end
    end
    return dirs
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

function M.build_policy(write_root, ordered_roots)
    local seen, read_roots = {}, {}
    for _, root in ipairs(ordered_roots or {}) do
        if type(root) == "string" and root ~= "" and not seen[root] then
            seen[root] = true
            read_roots[#read_roots + 1] = root
        end
    end
    return { write_root = write_root, read_roots = read_roots }
end

function M.policy_from_roots(write_root, repo_root, configured_roots)
    local function canonical(path)
        path = clean(path)
        return path and (vim.loop.fs_realpath(path) or path) or nil
    end
    write_root = canonical(write_root)
    if not write_root then return nil, "buffer has no file" end
    local roots = { write_root }
    repo_root = canonical(repo_root)
    if repo_root then roots[#roots + 1] = repo_root end
    for _, root in ipairs(configured_roots or {}) do
        if type(root) == "string" and root ~= "" then
            if root:sub(1, 1) == "~" then root = vim.fn.expand(root) end
            local resolved = root:sub(1, 1) == "/" and root or join(write_root, root)
            roots[#roots + 1] = canonical(resolved)
        end
    end
    return M.build_policy(write_root, roots)
end

function M.policy_for_path(path, config, chat_roots)
    local write_root, err = M.derive_for_path(path, config, chat_roots)
    if not write_root then return nil, err end
    local configured_repo = clean(config and config.repo_root)
    local repo_root = configured_repo and path_within(path, configured_repo)
        and configured_repo or nil
    return M.policy_from_roots(write_root, repo_root,
        config and config.tool_read_roots)
end

function M.format_tool_context(policy)
    if not policy or not policy.write_root then return nil end
    local lines = { "Relative reads search these roots in order (first existing match wins):" }
    for _, root in ipairs(policy.read_roots or {}) do lines[#lines + 1] = "- " .. root end
    lines[#lines + 1] = "Relative writes resolve only from: " .. policy.write_root
    return table.concat(lines, "\n")
end

function M.for_buf(buf)
    local path = vim.api.nvim_buf_get_name(buf)
    local config = require("parley").config
    local ok, chat_dirs = pcall(require, "parley.chat_dirs")
    local roots = {}
    if ok and type(chat_dirs.get_chat_roots) == "function" then
        local roots_ok, derived_roots = pcall(chat_dirs.get_chat_roots)
        if roots_ok then
            roots = derived_roots
        end
    end
    return M.derive_for_path(path, config, roots)
end

function M.policy_for_buf(buf)
    local path = vim.api.nvim_buf_get_name(buf)
    local config = require("parley").config
    local ok, chat_dirs = pcall(require, "parley.chat_dirs")
    local roots = {}
    if ok and type(chat_dirs.get_chat_roots) == "function" then
        local roots_ok, derived_roots = pcall(chat_dirs.get_chat_roots)
        if roots_ok then roots = derived_roots end
    end
    return M.policy_for_path(path, config, roots)
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

local function policy_for_completion(buf)
    return vim.b[buf].parley_root_policy or M.policy_for_buf(buf)
end

function M.merge_completion_candidates(per_root)
    local seen, out = {}, {}
    for _, items in ipairs(per_root or {}) do
        local sorted = vim.deepcopy(items)
        table.sort(sorted)
        for _, item in ipairs(sorted) do
            if not seen[item] then seen[item] = true; out[#out + 1] = item end
        end
    end
    return out
end

function M.completion_candidates(policy, base)
    local groups = {}
    for _, root in ipairs(policy and policy.read_roots or {}) do
        local items = {}
        for _, match in ipairs(vim.fn.glob(root .. "/" .. (base or "") .. "*", false, true)) do
            local rel = relative_to_root(match, root)
            if rel and rel ~= "" then
                if vim.fn.isdirectory(match) == 1 then rel = rel .. "/" end
                items[#items + 1] = rel
            end
        end
        groups[#groups + 1] = items
    end
    local accepted = {}
    local resolver = require("parley.tools.dispatcher").resolve_read_path
    for _, label in ipairs(M.merge_completion_candidates(groups)) do
        if resolver(label:gsub("/$", ""), policy.write_root, policy.read_roots) then
            accepted[#accepted + 1] = label
        end
    end
    return accepted
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
    local policy = policy_for_completion(buf)
    if not policy then
        return {}
    end
    return M.completion_candidates(policy, base)
end

local cmp_registered = false
local function cmp_path_sources(cmp)
    local sources = {
        {
            name = "parley_path",
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

    local policy = policy_for_completion(buf)
    if not policy then
        return nil
    end

    local ok, cmp = pcall(require, "cmp")
    if not ok or type(cmp) ~= "table" or type(cmp.setup) ~= "table" or type(cmp.setup.buffer) ~= "function" then
        return nil
    end
    if not cmp_registered and type(cmp.register_source) == "function" then
        cmp.register_source("parley_path", {
            complete = function(_, params, callback)
                local target = params.context and params.context.bufnr or vim.api.nvim_get_current_buf()
                local before = params.context and params.context.cursor_before_line or ""
                local base = before:match("([^%s%(%[%{]+)$") or ""
                local words = M.completion_candidates(policy_for_completion(target), base)
                local items = {}
                for _, word in ipairs(words) do items[#items + 1] = { label = word, word = word } end
                callback(items)
            end,
        })
        cmp_registered = true
    end

    cmp.setup.buffer({
        completion = {
            keyword_pattern = [[\~\?\(\k\|[\/\.\-]\)\+]],
            keyword_length = 1,
        },
        sources = cmp_path_sources(cmp),
    })
    return policy.write_root
end

local function schedule_cmp_attach(buf)
    vim.schedule(function()
        M.attach_cmp_completion(buf)
    end)
end

function M.attach_completion(buf)
    local policy = M.policy_for_buf(buf)
    if not policy then
        return nil
    end
    if vim.b[buf].parley_completion_attached then return policy.write_root end
    vim.b[buf].parley_completion_attached = true
    vim.b[buf].parley_root_policy = policy
    vim.api.nvim_set_option_value("completefunc", "v:lua.require'parley.neighborhood'.completefunc", { buf = buf })
    schedule_cmp_attach(buf)
    vim.api.nvim_create_autocmd("InsertEnter", {
        buffer = buf,
        once = true,
        callback = function()
            schedule_cmp_attach(buf)
        end,
    })
    return policy.write_root
end

return M
