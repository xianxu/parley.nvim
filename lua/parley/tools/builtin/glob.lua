-- `glob` — find files matching a glob pattern.
--
-- M1 STUB: handler returns is_error=true. Real handler lands in M3
-- Task 3.3 with `vim.fn.globpath` for any `**` pattern (handles both
-- leading and middle recursion uniformly) and plain `vim.fn.glob`
-- otherwise.

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
    handler = function(_input)
        return {
            content = "glob: not yet implemented (M1 stub)",
            is_error = true,
            name = "glob",
        }
    end,
}
