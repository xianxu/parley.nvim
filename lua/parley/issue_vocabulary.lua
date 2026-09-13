-- Generated issue vocabulary loader and pure helpers.

local M = {}

local VOCAB_PATH = "construct/generated/vocabulary/issue.json"
local CATEGORY_ORDER = { "open", "active", "terminal" }

local MAX_BYTES = 1024 * 1024
local module_source = debug.getinfo(1, "S").source
local module_root = module_source:sub(1, 1) == "@"
    and vim.fn.fnamemodify(module_source:sub(2), ":p:h:h:h") or nil
local cache = { state = "unprobed" }

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

local function resolve_vocab_path()
    if not module_root then
        error("cannot locate the loaded parley issue vocabulary module")
    end
    return module_root .. "/" .. VOCAB_PATH
end

local function dense_array(values, label)
    if type(values) ~= "table" then
        error("issue vocabulary missing " .. label)
    end
    local count = 0
    for key in pairs(values) do
        if type(key) ~= "number" or key < 1 or key % 1 ~= 0 then
            error("issue vocabulary " .. label .. " must be a dense array")
        end
        count = count + 1
    end
    for i = 1, count do
        if values[i] == nil then
            error("issue vocabulary " .. label .. " must be a dense array")
        end
    end
    return count
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
        local count = dense_array(raw.categories[name], "category: " .. name)
        if name == "open" and count == 0 then
            error("issue vocabulary open category must not be empty")
        end
        categories[name] = copy_list(raw.categories[name])
        sets[name] = index_set(categories[name])
        for _, status in ipairs(categories[name]) do
            if type(status) ~= "string" or status == "" then
                error("issue vocabulary statuses must be nonempty strings")
            end
            if sort_rank[status] then
                error("issue vocabulary duplicate status: " .. status)
            end
            table.insert(status_values, status)
            sort_rank[status] = #status_values
        end
    end

    dense_array(raw.lifecycle, "lifecycle")
    local next_status = {}
    for _, transition in ipairs(raw.lifecycle) do
        if type(transition) ~= "table" or type(transition.from) ~= "string"
            or type(transition.to) ~= "string" or not sort_rank[transition.from] or not sort_rank[transition.to] then
            error("issue vocabulary lifecycle endpoints must be known statuses")
        end
        next_status[transition.from] = next_status[transition.from] or transition.to
    end

    return setmetatable({
        raw = raw,
        _categories = categories,
        _sets = sets,
        _status_values = status_values,
        _sort_rank = sort_rank,
        _next_status = next_status,
        _default_status = categories.open[1],
    }, IssueVocabulary)
end

M.load = function(opts)
    opts = opts or {}
    if opts.table then
        return M.from_table(opts.table)
    end

    local path = opts.path or resolve_vocab_path()
    local stat = vim.loop.fs_stat(path)
    if not stat or stat.type ~= "file" then
        error("issue vocabulary must be a regular file: " .. path)
    end
    if stat.size > MAX_BYTES then
        error("issue vocabulary exceeds 1 MiB: " .. path)
    end
    local fd, open_error = vim.loop.fs_open(path, "r", 0)
    if not fd then
        error("failed to read issue vocabulary: " .. path .. ": " .. tostring(open_error))
    end
    local opened_stat = vim.loop.fs_fstat(fd)
    if not opened_stat or opened_stat.type ~= "file" or opened_stat.size > MAX_BYTES then
        vim.loop.fs_close(fd)
        error("issue vocabulary must be a regular file no larger than 1 MiB: " .. path)
    end
    local json, read_error = vim.loop.fs_read(fd, MAX_BYTES + 1, 0)
    vim.loop.fs_close(fd)
    if not json then
        error("failed to read issue vocabulary: " .. path .. ": " .. tostring(read_error))
    end
    if #json > MAX_BYTES then
        error("issue vocabulary exceeds 1 MiB: " .. path)
    end
    local decode_ok, decoded = pcall(vim.json.decode, json)
    if not decode_ok then
        error("failed to decode issue vocabulary: " .. path)
    end
    return M.from_table(decoded)
end

-- Refresh explicitly on setup, including failed lookups. Hot consumers never
-- repeatedly probe an unavailable file; repairing it takes effect at reload.
M.reload = function(opts)
    local ok, result = pcall(M.load, opts)
    if ok then
        cache = { state = "ready", model = result }
    else
        cache = { state = "unavailable", reason = tostring(result) }
    end
    return cache.model, cache.reason
end

M.default = function()
    if cache.state == "unprobed" then
        return M.reload()
    end
    return cache.model, cache.reason
end

M.set_default_for_tests = function(model)
    cache = model and { state = "ready", model = model } or { state = "unprobed" }
end

M.reset_for_tests = function()
    cache = { state = "unprobed" }
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
