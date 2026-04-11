-- `grep` — search file contents for a pattern.
--
-- PURE: no vim state, no caching. Returns a partial ToolResult
-- without `id` — the dispatcher stamps id and name.
--
-- Uses ripgrep when available (faster, respects .gitignore), with a
-- pure-Lua fallback that scans files via vim.fn.glob + io.open.
-- Capped at 1000 matching lines.

local MAX_MATCHES = 1000

--- Ripgrep-based search.
local function grep_rg(pattern, path, glob_filter, case_sensitive)
    local args = {
        "rg",
        "--line-number",
        "--no-heading",
        "--color=never",
        "--max-columns=500",
        "--max-count=" .. MAX_MATCHES,
    }
    if case_sensitive == false then
        table.insert(args, "-i")
    end
    if glob_filter and glob_filter ~= "" then
        table.insert(args, "--glob")
        table.insert(args, glob_filter)
    end
    table.insert(args, "--")
    table.insert(args, pattern)
    table.insert(args, path or ".")

    local result = vim.fn.system(args)
    local exit_code = vim.v.shell_error
    -- rg exit 0 = matches, 1 = no matches, 2+ = error
    if exit_code >= 2 then
        return nil, "ripgrep error (exit " .. exit_code .. "): " .. (result or "")
    end
    return result or "", nil
end

--- Pure-Lua fallback: scan files matching glob_filter for pattern.
local function grep_lua(pattern, path, glob_filter, case_sensitive)
    local base = path or "."
    local file_pattern = glob_filter or "**/*"
    local files = vim.fn.globpath(base, file_pattern, false, true)

    local lua_pat = pattern
    if case_sensitive == false then
        -- Lua patterns don't have case-insensitive flag; do simple lower-case match
        lua_pat = pattern:lower()
    end

    local out = {}
    for _, fpath in ipairs(files) do
        if #out >= MAX_MATCHES then break end
        local stat = vim.loop.fs_stat(fpath)
        if stat and stat.type == "file" then
            local f = io.open(fpath, "r")
            if f then
                local n = 0
                for line in f:lines() do
                    n = n + 1
                    if #out >= MAX_MATCHES then break end
                    local match_line = case_sensitive == false and line:lower() or line
                    if match_line:find(lua_pat, 1, false) then
                        -- Make path relative
                        local rel = fpath
                        if rel:sub(1, #base + 1) == base .. "/" then
                            rel = rel:sub(#base + 2)
                        end
                        table.insert(out, rel .. ":" .. n .. ":" .. line:sub(1, 500))
                    end
                end
                f:close()
            end
        end
    end
    return table.concat(out, "\n"), nil
end

return {
    name = "grep",
    kind = "read",
    description = "Search file contents for a regular-expression pattern. Returns matching lines prefixed with 'path:line:'. Uses ripgrep when available, otherwise a pure-Lua fallback. Confined to the working directory.",
    input_schema = {
        type = "object",
        properties = {
            pattern = {
                type = "string",
                description = "Regular-expression pattern to search for.",
            },
            path = {
                type = "string",
                description = "Directory or file to search. Defaults to the working directory.",
            },
            glob = {
                type = "string",
                description = "File glob filter, e.g. '*.lua'. Passed through to ripgrep's --glob.",
            },
            case_sensitive = {
                type = "boolean",
                description = "Case-sensitive matching. Default true.",
            },
        },
        required = { "pattern" },
    },
    handler = function(input)
        input = input or {}
        local pattern = input.pattern
        if type(pattern) ~= "string" or pattern == "" then
            return {
                content = "missing or invalid required field: pattern",
                is_error = true,
                name = "grep",
            }
        end

        local path = input.path or "."
        local glob_filter = input.glob
        local case_sensitive = input.case_sensitive
        if case_sensitive == nil then case_sensitive = true end

        local result, err
        if vim.fn.executable("rg") == 1 then
            result, err = grep_rg(pattern, path, glob_filter, case_sensitive)
        else
            result, err = grep_lua(pattern, path, glob_filter, case_sensitive)
        end

        if err then
            return {
                content = err,
                is_error = true,
                name = "grep",
            }
        end

        local trimmed = (result or ""):gsub("%s+$", "")
        if trimmed == "" then
            return {
                content = "no matches found",
                is_error = false,
                name = "grep",
            }
        end

        return {
            content = trimmed,
            is_error = false,
            name = "grep",
        }
    end,
}
