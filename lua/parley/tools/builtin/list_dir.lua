-- `list_dir` — list directory contents.
--
-- M1 STUB: handler returns is_error=true. Real handler lands in M3
-- Task 3.1 with `vim.loop.fs_scandir` recursion up to max_depth and
-- a 1000-entry cap.

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
    handler = function(_input)
        return {
            content = "list_dir: not yet implemented (M1 stub)",
            is_error = true,
            name = "list_dir",
        }
    end,
}
