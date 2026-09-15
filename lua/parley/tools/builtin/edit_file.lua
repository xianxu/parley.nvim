-- `edit_file` — edit a file via string replacement or line insertion.
--
-- Two modes:
--   1. str_replace: old_string + new_string → literal find-and-replace
--   2. insert: insert_line + insert_text → insert text at a line number
--
-- After writing, triggers :checktime so Neovim reloads the buffer.

local definition = {
    name = "edit_file",
    kind = "write",
    needs_backup = false,
    description = "Edit a file. Two modes: "
        .. "(1) String replacement: provide old_string and new_string to find and replace text. "
        .. "Errors if old_string is not found or not unique (use replace_all=true for multiple). "
        .. "(2) Insert: provide insert_line (0=beginning, N=after line N) and insert_text to insert text at a specific line. "
        .. "The edit is reversible from the chat transcript.",
    input_schema = {
        type = "object",
        properties = {
            file_path = {
                type = "string",
                description = "Path to the file.",
            },
            old_string = {
                type = "string",
                description = "Literal string to find and replace (str_replace mode).",
            },
            new_string = {
                type = "string",
                description = "Literal replacement string (str_replace mode).",
            },
            replace_all = {
                type = "boolean",
                description = "Replace every occurrence. Default false.",
            },
            insert_line = {
                type = "integer",
                description = "Line number to insert after (insert mode). 0 = beginning of file.",
            },
            insert_text = {
                type = "string",
                description = "Text to insert (insert mode).",
            },
        },
        required = { "file_path" },
    },
    handler = function(input)
        input = input or {}
        local path = input.file_path or input.path

        if type(path) ~= "string" or path == "" then
            return { content = "missing or invalid required field: file_path", is_error = true, name = "edit_file" }
        end

        local invalid=require('parley.tools.file_transform').validate('edit_file',input)
        if invalid then return {content=invalid,is_error=true,name='edit_file'}end

        -- Read the file
        local f, err = io.open(path, "r")
        if not f then
            return { content = "cannot open: " .. (err or path), is_error = true, name = "edit_file" }
        end
        local content = f:read("*a")
        f:close()

        local new_content,msg=require('parley.tools.file_transform').transform('edit_file',input,content,path)
        if not new_content then return {content=msg,is_error=true,name='edit_file'}end

        -- Write back
        local refresh=require('parley.tools.file_refresh').capture(path)
        local wf, werr = io.open(path, "w")
        if not wf then
            require('parley.tools.file_refresh').release(refresh)
            return { content = "cannot write: " .. (werr or path), is_error = true, name = "edit_file" }
        end
        local written,write_error=wf:write(new_content)
        local closed,close_error=wf:close()
        if not written or not closed then
            require('parley.tools.file_refresh').release(refresh)
            return {content='write completion failed: '..tostring(write_error or close_error),is_error=true,name='edit_file'}
        end

        local completion=require('parley.tools.file_refresh').complete(refresh,new_content)
        if completion.reconciliation_required then
            vim.notify('[Disk updated; buffer reconciliation required]',vim.log.levels.WARN)
        end

        return { content = msg, is_error = false, name = "edit_file" }
    end,
}

return require("parley.tools.async_builtin").bind(definition)
