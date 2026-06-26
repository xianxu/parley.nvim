-- Shared argv validation helpers for builtin read tools.
--
-- Pure mechanism only: no filesystem, config, or process execution here.

local M = {}

local function is_array(t)
    if type(t) ~= "table" then
        return false
    end
    local n = 0
    for k, _ in pairs(t) do
        if type(k) ~= "number" or k < 1 or k % 1 ~= 0 then
            return false
        end
        if k > n then
            n = k
        end
    end
    for i = 1, n do
        if t[i] == nil then
            return false
        end
    end
    return true
end

function M.validate_flags(flags, allowed)
    if flags == nil then
        return {}
    end
    if not is_array(flags) then
        return nil, "flags must be an array of strings"
    end
    local out = {}
    for _, flag in ipairs(flags) do
        if type(flag) ~= "string" or flag == "" then
            return nil, "flags must be an array of non-empty strings"
        end
        if not allowed[flag] then
            return nil, "unsupported flag"
        end
        out[#out + 1] = flag
    end
    return out
end

function M.validate_ls_flags(flags, allowed_chars)
    if flags == nil then
        return {}
    end
    if not is_array(flags) then
        return nil, "flags must be an array of strings"
    end
    local out = {}
    for _, flag in ipairs(flags) do
        if type(flag) ~= "string" or flag == "" then
            return nil, "flags must be an array of non-empty strings"
        end
        if flag:sub(1, 2) == "--" or flag:find("=", 1, true) then
            return nil, "unsupported flag"
        end
        if flag:sub(1, 1) ~= "-" or #flag < 2 then
            return nil, "unsupported flag"
        end
        for i = 2, #flag do
            local ch = flag:sub(i, i)
            if not allowed_chars[ch] then
                return nil, "unsupported flag"
            end
        end
        out[#out + 1] = flag
    end
    return out
end

function M.append_path_args(argv, path_or_paths)
    if type(path_or_paths) == "string" then
        argv[#argv + 1] = path_or_paths
        return true
    end
    if not is_array(path_or_paths) then
        return nil, "paths must be a string or array of strings"
    end
    for _, path in ipairs(path_or_paths) do
        if type(path) ~= "string" or path == "" then
            return nil, "paths must be a string or array of non-empty strings"
        end
        argv[#argv + 1] = path
    end
    return true
end

function M.nonnegative_int(value, name)
    if value == nil then
        return nil
    end
    if type(value) ~= "number" or value % 1 ~= 0 or value < 0 then
        return nil, name .. " must be a non-negative integer"
    end
    return value
end

function M.reject_unknown_fields(input, allowed)
    for key, _ in pairs(input or {}) do
        if not allowed[key] then
            return nil, "unsupported input field"
        end
    end
    return true
end

return M
