-- `read_file` — read a file from the working directory.
--
-- M1 STUB: handler returns is_error=true. Real handler lands in M2
-- Task 2.2 with pure file I/O, optional line range, cwd-scope
-- enforcement in the dispatcher, and truncation applied by the
-- dispatcher at 100KB default.

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
    handler = function(_input)
        return {
            content = "read_file: not yet implemented (M1 stub)",
            is_error = true,
            name = "read_file",
        }
    end,
}
