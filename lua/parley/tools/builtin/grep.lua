-- `grep` — search file contents for a pattern.
--
-- M1 STUB: handler returns is_error=true. Real handler lands in M3
-- Task 3.2 wrapping ripgrep when available (`vim.fn.executable("rg")`)
-- with a pure-Lua fallback using `vim.fs.find` + line scanning.
-- rg flags: --line-number --no-heading --color=never --max-columns=500
-- --max-count=1000

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
    handler = function(_input)
        return {
            content = "grep: not yet implemented (M1 stub)",
            is_error = true,
            name = "grep",
        }
    end,
}
