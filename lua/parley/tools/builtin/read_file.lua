-- `read_file` — read a file from the working directory.
--
-- PURE: no filesystem I/O beyond the target file, no vim state, no
-- caching. Returns a partial ToolResult without `id` — the
-- dispatcher stamps id and name before the result is serialized.
--
-- Parameter names match Claude Code conventions (file_path, offset,
-- limit) so Claude uses them naturally.

return {
    name = "read_file",
    kind = "read",
    description = "Read a file and return its contents with line numbers. Use offset to start from a specific line, limit to cap the number of lines returned (default: all lines).",
    input_schema = {
        type = "object",
        properties = {
            file_path = {
                type = "string",
                description = "Path to the file. Relative to the working directory or absolute.",
            },
            offset = {
                type = "integer",
                description = "Line number to start reading from (1-indexed). Default: 1.",
            },
            limit = {
                type = "integer",
                description = "Maximum number of lines to return. Default: no limit.",
            },
        },
        required = { "file_path" },
    },
    handler = function(input)
        input = input or {}
        -- Accept both file_path (Claude Code convention) and path (legacy)
        local path = input.file_path or input.path
        if type(path) ~= "string" or path == "" then
            return {
                content = "missing or invalid required field: file_path",
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

        -- Accept both offset/limit (Claude Code) and line_start/line_end (legacy)
        local start_line = input.offset or input.line_start or 1
        local max_lines = input.limit  -- nil = no limit
        if not max_lines and input.line_end then
            max_lines = input.line_end - start_line + 1
        end

        local out = {}
        local n = 0
        for line in f:lines() do
            n = n + 1
            if max_lines and #out >= max_lines then break end
            if n >= start_line then
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
