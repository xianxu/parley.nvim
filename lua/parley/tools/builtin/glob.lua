-- `glob` — find files matching a glob pattern.
--
-- PURE: no vim state, no caching. Returns a partial ToolResult
-- without `id` — the dispatcher stamps id and name.
--
-- Uses vim.fn.globpath for `**` patterns and vim.fn.glob otherwise.
-- Capped at 1000 results.

local MAX_RESULTS = 1000

return {
    name = "glob",
    kind = "read",
    description = "Find files matching a glob pattern. Use `**` for recursive matching at any position (e.g. '**/*.lua' or 'lua/**/*.lua'). Returns one path per line. Confined to the working directory.",
    input_schema = {
        type = "object",
        properties = {
            pattern = {
                type = "string",
                description = "Glob pattern, e.g. '*.md' or 'lua/**/*.lua'.",
            },
            path = {
                type = "string",
                description = "Base path to search from. Defaults to the working directory.",
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
                name = "glob",
            }
        end

        local base = input.path or "."
        local raw
        if pattern:find("**", 1, true) then
            -- globpath handles ** recursion
            raw = vim.fn.globpath(base, pattern, false, true)
        else
            local full = base == "." and pattern or (base .. "/" .. pattern)
            raw = vim.fn.glob(full, false, true)
        end

        -- Convert to relative paths, skip hidden files/dirs
        local results = {}
        local cwd = vim.fn.getcwd() .. "/"
        for _, p in ipairs(raw or {}) do
            local rel = p
            if p:sub(1, #cwd) == cwd then
                rel = p:sub(#cwd + 1)
            end
            -- Strip leading ./ from globpath output
            if rel:sub(1, 2) == "./" then
                rel = rel:sub(3)
            end
            -- Skip hidden files/dirs (contain /. or start with .)
            if rel ~= "" and not rel:match("/%." ) and rel:sub(1, 1) ~= "." then
                table.insert(results, rel)
                if #results >= MAX_RESULTS then break end
            end
        end

        table.sort(results)

        local suffix = ""
        if #results >= MAX_RESULTS then
            suffix = "\n... (truncated at " .. MAX_RESULTS .. " results)"
        end

        return {
            content = table.concat(results, "\n") .. suffix,
            is_error = false,
            name = "glob",
        }
    end,
}
