-- Parley - A Neovim LLM Chat Plugin
-- File tracking module for access time tracking

--------------------------------------------------------------------------------
-- Track file access times
--------------------------------------------------------------------------------

local M = {}

-- Structure to store file access information
-- Keys are file paths, values are tables with:
-- { 
--   last_accessed = timestamp,  -- Last time the file was accessed
--   access_count = number       -- How many times the file was accessed
-- }
M._file_access = {}

-- Path for storing file access data
local access_data_file = vim.fn.stdpath("data"):gsub("/$", "") .. "/parley/file_access.json"

-- Ensure directory exists
local function ensure_dir_exists(filepath)
    local dir = vim.fn.fnamemodify(filepath, ":h")
    if vim.fn.isdirectory(dir) == 0 then
        vim.fn.mkdir(dir, "p")
    end
end

-- Load file access data from disk
function M.load_data()
    ensure_dir_exists(access_data_file)
    
    -- Check if the file exists
    if vim.fn.filereadable(access_data_file) == 1 then
        local content = vim.fn.readfile(access_data_file)
        if #content > 0 then
            local json_str = table.concat(content, "\n")
            local ok, data = pcall(vim.fn.json_decode, json_str)
            if ok and type(data) == "table" then
                M._file_access = data
                return true
            end
        end
    end
    
    -- Default to empty table if file doesn't exist or can't be parsed
    M._file_access = {}
    return false
end

-- Save file access data to disk
function M.save_data()
    ensure_dir_exists(access_data_file)
    
    local ok, json_str = pcall(vim.fn.json_encode, M._file_access)
    if ok then
        vim.fn.writefile({json_str}, access_data_file)
        return true
    end
    
    return false
end

-- Track file access
function M.track_file_access(file_path)
    -- Load data if it's the first time
    if next(M._file_access) == nil then
        M.load_data()
    end
    
    -- Create entry if it doesn't exist
    if not M._file_access[file_path] then
        M._file_access[file_path] = {
            last_accessed = os.time(),
            access_count = 1
        }
    else
        -- Update existing entry
        M._file_access[file_path].last_accessed = os.time()
        M._file_access[file_path].access_count = (M._file_access[file_path].access_count or 0) + 1
    end
    
    -- Save data to disk
    M.save_data()
end

-- Get last access time for a file
function M.get_last_access_time(file_path)
    -- Load data if it's the first time
    if next(M._file_access) == nil then
        M.load_data()
    end
    
    if M._file_access[file_path] then
        return M._file_access[file_path].last_accessed
    end
    
    -- If no data, return mtime from filesystem as fallback
    local stat = vim.loop.fs_stat(file_path)
    if stat then
        return stat.mtime.sec
    end
    
    -- If all else fails, return current time (least priority in sorting)
    return 0
end

-- Get access count for a file
function M.get_access_count(file_path)
    -- Load data if it's the first time
    if next(M._file_access) == nil then
        M.load_data()
    end
    
    if M._file_access[file_path] then
        return M._file_access[file_path].access_count or 0
    end
    
    return 0
end

-- Clean up old entries (files that no longer exist)
function M.cleanup()
    local entries_before = 0
    for _ in pairs(M._file_access) do
        entries_before = entries_before + 1
    end
    
    local to_remove = {}
    for file_path, _ in pairs(M._file_access) do
        if vim.fn.filereadable(file_path) == 0 then
            table.insert(to_remove, file_path)
        end
    end
    
    for _, file_path in ipairs(to_remove) do
        M._file_access[file_path] = nil
    end
    
    local entries_after = 0
    for _ in pairs(M._file_access) do
        entries_after = entries_after + 1
    end
    
    if #to_remove > 0 then
        M.save_data()
    end
    
    return {
        before = entries_before,
        after = entries_after,
        removed = #to_remove
    }
end

-- Initialize the tracker
function M.init()
    M.load_data()
    
    -- Run cleanup on startup to remove stale entries
    M.cleanup()
    
    return M
end

return M