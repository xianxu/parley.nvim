-- `edit_file` — perform a literal string replacement in a file.
--
-- M1 STUB: handler returns is_error=true. Real handler lands in M5
-- Task 5.4. `edit_file` is write-type but needs NO `.parley-backup`:
-- the tool call itself already contains `old_string` AND `new_string`,
-- making it locally reversible from the transcript alone. The
-- dispatcher write-path prelude still enforces cwd-scope and
-- dirty-buffer protection (M5 Task 5.6).

return {
    name = "edit_file",
    kind = "write",
    needs_backup = false,
    description = "Perform a literal string replacement in a file. Errors if old_string is not unique in the file unless replace_all is true. The call itself preserves enough information (old_string + new_string) for the edit to be reversible from the chat transcript.",
    input_schema = {
        type = "object",
        properties = {
            path = {
                type = "string",
                description = "Path to the file, relative to or absolute within the working directory.",
            },
            old_string = {
                type = "string",
                description = "Literal string to replace. Must be unique in the file unless replace_all is true.",
            },
            new_string = {
                type = "string",
                description = "Literal replacement string.",
            },
            replace_all = {
                type = "boolean",
                description = "Replace every occurrence of old_string. Default false.",
            },
        },
        required = { "path", "old_string", "new_string" },
    },
    handler = function(_input)
        return {
            content = "edit_file: not yet implemented (M1 stub)",
            is_error = true,
            name = "edit_file",
        }
    end,
}
