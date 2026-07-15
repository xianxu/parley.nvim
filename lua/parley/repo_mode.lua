local M = {}

local function valid_mode(mode)
    return mode == "repo" or mode == "super_repo"
end

local function valid_root(root)
    return type(root) == "string" and root ~= ""
end

M.resolve = function(repo_modes, canonical_root)
    if type(repo_modes) ~= "table" or not valid_root(canonical_root) then
        return nil
    end
    local mode = repo_modes[canonical_root]
    if valid_mode(mode) then
        return mode
    end
    return nil
end

M.updated = function(repo_modes, canonical_root, mode)
    local result = {}
    if type(repo_modes) == "table" then
        for root, saved_mode in pairs(repo_modes) do
            if valid_root(root) and valid_mode(saved_mode) then
                result[root] = saved_mode
            end
        end
    end
    if valid_root(canonical_root) and valid_mode(mode) then
        result[canonical_root] = mode
    end
    return result
end

return M
