-- `list_dir` — list directory contents.
--
-- PURE: no vim state, no caching. Returns a partial ToolResult
-- without `id` — the dispatcher stamps id and name.
--
-- Uses vim.loop.fs_scandir for directory traversal. Recurses up to
-- max_depth. Capped at 1000 entries to prevent unbounded output.

local MAX_ENTRIES = 1000

local function scandir(path, depth, max_depth, entries)
    if #entries >= MAX_ENTRIES then return end
    local handle = vim.loop.fs_scandir(path)
    if not handle then return end

    while #entries < MAX_ENTRIES do
        local name, typ = vim.loop.fs_scandir_next(handle)
        if not name then break end
        -- Skip hidden files/dirs (starting with .)
        if name:sub(1, 1) ~= "." then
            local rel = path == "." and name or (path .. "/" .. name)
            if typ == "directory" then
                table.insert(entries, rel .. "/")
                if depth < max_depth then
                    scandir(rel, depth + 1, max_depth, entries)
                end
            else
                table.insert(entries, rel)
            end
        end
    end
end

return {
    name = "list_dir",
    kind = "read",
    description = "List directory contents. Shallow by default (max_depth=1). Returns one entry per line with a trailing '/' for directories. Confined to the working directory. Capped at 1000 entries.",
    input_schema = {
        type = "object",
        properties = {
            path = {
                type = "string",
                description = "Directory path relative to the working directory.",
            },
            max_depth = {
                type = "integer",
                description = "Recursion depth. 1 = shallow listing (default). Larger values recurse into subdirectories.",
            },
        },
        required = { "path" },
    },
    handler = function(input)
        input = input or {}
        local path = input.path
        if type(path) ~= "string" or path == "" then
            return {
                content = "missing or invalid required field: path",
                is_error = true,
                name = "list_dir",
            }
        end

        local stat = vim.loop.fs_stat(path)
        if not stat then
            return {
                content = "path does not exist: " .. path,
                is_error = true,
                name = "list_dir",
            }
        end
        if stat.type ~= "directory" then
            return {
                content = "not a directory: " .. path,
                is_error = true,
                name = "list_dir",
            }
        end

        local max_depth = input.max_depth or 1
        local entries = {}
        scandir(path, 1, max_depth, entries)

        -- Convert to relative paths (strip cwd prefix)
        local cwd = vim.fn.getcwd()
        local prefix = cwd .. "/"
        for i, e in ipairs(entries) do
            if e:sub(1, #prefix) == prefix then
                entries[i] = e:sub(#prefix + 1)
            end
        end
        table.sort(entries)

        local suffix = ""
        if #entries >= MAX_ENTRIES then
            suffix = "\n... (truncated at " .. MAX_ENTRIES .. " entries)"
        end

        return {
            content = table.concat(entries, "\n") .. suffix,
            is_error = false,
            name = "list_dir",
        }
    end,
}
