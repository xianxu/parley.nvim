-- Generated issue vocabulary loader and pure helpers.

local M = {}

local VOCAB_PATH = "construct/generated/vocabulary/issue.json"
local CATEGORY_ORDER = { "open", "active", "terminal" }

local default_model = nil

local function copy_list(values)
    local out = {}
    for _, value in ipairs(values or {}) do
        table.insert(out, value)
    end
    return out
end

local function index_set(values)
    local set = {}
    for _, value in ipairs(values or {}) do
        set[value] = true
    end
    return set
end

local function find_git_root(start)
    local dir = start
    while dir and dir ~= "" do
        local git_dir = dir .. "/.git"
        if vim.loop.fs_stat(git_dir) then
            return dir
        end
        local parent = vim.fn.fnamemodify(dir, ":h")
        if parent == dir then
            break
        end
        dir = parent
    end
    return start
end

local function resolve_vocab_path()
    local runtime_matches = vim.api.nvim_get_runtime_file(VOCAB_PATH, false)
    if runtime_matches and runtime_matches[1] then
        return runtime_matches[1]
    end

    local root = find_git_root(vim.fn.getcwd())
    return root .. "/" .. VOCAB_PATH
end

local IssueVocabulary = {}
IssueVocabulary.__index = IssueVocabulary

function IssueVocabulary:status_values()
    return copy_list(self._status_values)
end

function IssueVocabulary:category(name)
    return copy_list(self._categories[name])
end

function IssueVocabulary:is_open(status)
    return self._sets.open[status] == true
end

function IssueVocabulary:is_active(status)
    return self._sets.active[status] == true
end

function IssueVocabulary:is_terminal(status)
    return self._sets.terminal[status] == true
end

function IssueVocabulary:next_status(current)
    return self._next_status[current] or self._default_status
end

function IssueVocabulary:sort_rank(status)
    return self._sort_rank[status] or (#self._status_values + 1)
end

function IssueVocabulary:enumerable_values(field)
    if field == "status" then
        return self:status_values()
    end
    return {}
end

M.from_table = function(raw)
    if type(raw) ~= "table" then
        error("issue vocabulary must be a table")
    end
    if type(raw.categories) ~= "table" then
        error("issue vocabulary missing categories")
    end
    if type(raw.lifecycle) ~= "table" then
        error("issue vocabulary missing lifecycle")
    end

    local categories = {}
    local sets = {}
    local status_values = {}
    local sort_rank = {}

    for _, name in ipairs(CATEGORY_ORDER) do
        if type(raw.categories[name]) ~= "table" then
            error("issue vocabulary missing category: " .. name)
        end
        categories[name] = copy_list(raw.categories[name])
        sets[name] = index_set(categories[name])
        for _, status in ipairs(categories[name]) do
            if not sort_rank[status] then
                table.insert(status_values, status)
                sort_rank[status] = #status_values
            end
        end
    end

    local next_status = {}
    for _, transition in ipairs(raw.lifecycle) do
        if type(transition) == "table" and type(transition.from) == "string" and type(transition.to) == "string" then
            next_status[transition.from] = next_status[transition.from] or transition.to
        end
    end

    return setmetatable({
        raw = raw,
        _categories = categories,
        _sets = sets,
        _status_values = status_values,
        _sort_rank = sort_rank,
        _next_status = next_status,
        _default_status = categories.open[1] or "open",
    }, IssueVocabulary)
end

M.load = function(opts)
    opts = opts or {}
    if opts.table then
        return M.from_table(opts.table)
    end

    local path = opts.path or resolve_vocab_path()
    local ok, lines = pcall(vim.fn.readfile, path)
    if not ok then
        error("failed to read issue vocabulary: " .. path)
    end

    local json = table.concat(lines, "\n")
    local decode_ok, decoded = pcall(vim.json.decode, json)
    if not decode_ok then
        error("failed to decode issue vocabulary: " .. path)
    end

    return M.from_table(decoded)
end

M.default = function()
    if not default_model then
        default_model = M.load()
    end
    return default_model
end

M.set_default_for_tests = function(model)
    default_model = model
end

M.reset_for_tests = function()
    default_model = nil
end

-- #116 M2: the repo-RELATIVE home folder for issue instances, sourced from the
-- cue `discovery` block (construct/vocabulary/issue.cue → exported issue.json).
-- PURE over `model` when given; with no arg it pcall-loads the default and
-- returns nil when the generated vocabulary is missing/unreadable (fresh clone /
-- pre-weave) — callers fall back to their own config default. Config-decoupled by
-- design (the default fallback lives at the seed site, init.lua). Never absolute:
-- consumers join to their repo root.
M.home = function(model)
    if model == nil then
        local ok, m = pcall(M.default)
        if not ok then
            return nil
        end
        model = m
    end
    local discovery = type(model) == "table" and model.raw and model.raw.discovery
    if type(discovery) == "table" and type(discovery.home) == "string" and discovery.home ~= "" then
        return discovery.home
    end
    return nil
end

return M
