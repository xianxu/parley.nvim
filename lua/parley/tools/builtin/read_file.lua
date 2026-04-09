-- `read_file` — read a file from the working directory.
--
-- Real implementation landed in M2 Task 2.2 of issue #81.
--
-- PURE: no filesystem I/O beyond the target file, no vim state, no
-- caching. Returns a partial ToolResult without `id` — the
-- dispatcher (landing in Task 2.3) stamps id and name before the
-- result is serialized or validated. See lua/parley/tools/types.lua
-- ToolResult contract note.
--
-- Safety concerns NOT handled here (dispatcher handles them):
--   - cwd-scope check on the resolved path
--   - symlink resolution via vim.loop.fs_realpath
--   - truncation at tool_result_max_bytes
--
-- Content format: each line prefixed with a right-aligned 5-column
-- line number and two spaces, e.g. "    1  first line". This mirrors
-- common tool-output conventions (ripgrep, Claude Code's Read tool)
-- and makes it easy for the LLM to reference specific lines.

return {
    name = "read_file",
    kind = "read",
    description = "Read a file from the working directory and return its contents with line numbers (1-indexed). Optional line_start and line_end select a subrange.",
    input_schema = {
        type = "object",
        properties = {
            path = {
                type = "string",
                description = "Relative or absolute path to the file. Must be inside the working directory.",
            },
            line_start = {
                type = "integer",
                description = "Optional starting line number (1-indexed, inclusive).",
            },
            line_end = {
                type = "integer",
                description = "Optional ending line number (inclusive).",
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
                name = "read_file",
            }
        end

        local f, err = io.open(path, "r")
        if not f then
            return {
                content = "cannot open: " .. (err or path),
                is_error = true,
                name = "read_file",
            }
        end

        local line_start = input.line_start -- may be nil (no lower bound)
        local line_end = input.line_end     -- may be nil (no upper bound)

        local out = {}
        local n = 0
        for line in f:lines() do
            n = n + 1
            -- Short-circuit past line_end to avoid walking the rest of
            -- a large file.
            if line_end and n > line_end then break end
            if not line_start or n >= line_start then
                table.insert(out, string.format("%5d  %s", n, line))
            end
        end
        f:close()

        return {
            content = table.concat(out, "\n"),
            is_error = false,
            name = "read_file",
        }
    end,
}
