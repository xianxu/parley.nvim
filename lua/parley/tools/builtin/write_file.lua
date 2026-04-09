-- `write_file` — create or overwrite a file.
--
-- M1 STUB: handler returns is_error=true. Real handler lands in M5
-- Task 5.5. `write_file` is write-type with `needs_backup=true`: the
-- dispatcher write-path prelude (M5 Task 5.6) captures the pre-image
-- to `<path>.parley-backup` on first write, enforces cwd-scope,
-- dirty-buffer protection, and appends a `pre-image:` metadata
-- footer to the result body so #84's replay has the data it needs.

return {
    name = "write_file",
    kind = "write",
    needs_backup = true,
    description = "Create or overwrite a file. Confined to the working directory. On first write to a path within a chat, the prior contents are captured to `<path>.parley-backup` for safety and future replay.",
    input_schema = {
        type = "object",
        properties = {
            path = {
                type = "string",
                description = "Path to the file, relative to or absolute within the working directory.",
            },
            content = {
                type = "string",
                description = "Full file content to write.",
            },
        },
        required = { "path", "content" },
    },
    handler = function(_input)
        return {
            content = "write_file: not yet implemented (M1 stub)",
            is_error = true,
            name = "write_file",
        }
    end,
}
