-- `edit_file` — edit a file via string replacement or line insertion.
--
-- Two modes:
--   1. str_replace: old_string + new_string → literal find-and-replace
--   2. insert: insert_line + insert_text → insert text at a line number
--
-- After writing, triggers :checktime so Neovim reloads the buffer.

return {
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

        -- Determine mode
        local is_insert = input.insert_line ~= nil and input.insert_text ~= nil
        local is_replace = input.old_string ~= nil

        if not is_insert and not is_replace then
            return {
                content = "provide either (old_string + new_string) for replacement or (insert_line + insert_text) for insertion",
                is_error = true,
                name = "edit_file",
            }
        end

        -- Read the file
        local f, err = io.open(path, "r")
        if not f then
            return { content = "cannot open: " .. (err or path), is_error = true, name = "edit_file" }
        end
        local content = f:read("*a")
        f:close()

        local new_content
        local msg

        if is_insert then
            -- INSERT MODE: insert text at a specific line
            local line_num = input.insert_line
            local text = input.insert_text

            local lines = {}
            for line in (content .. "\n"):gmatch("([^\n]*)\n") do
                table.insert(lines, line)
            end
            -- Remove the extra empty line added by the trailing \n trick
            if #lines > 0 and lines[#lines] == "" and content:sub(-1) == "\n" then
                table.remove(lines)
            end

            -- Clamp line_num
            if line_num < 0 then line_num = 0 end
            if line_num > #lines then line_num = #lines end

            -- Insert the text lines
            local insert_lines = {}
            for line in (text .. "\n"):gmatch("([^\n]*)\n") do
                table.insert(insert_lines, line)
            end
            if #insert_lines > 0 and insert_lines[#insert_lines] == "" and text:sub(-1) == "\n" then
                table.remove(insert_lines)
            end

            -- Build new content
            local result = {}
            for i = 1, line_num do
                table.insert(result, lines[i])
            end
            for _, l in ipairs(insert_lines) do
                table.insert(result, l)
            end
            for i = line_num + 1, #lines do
                table.insert(result, lines[i])
            end

            new_content = table.concat(result, "\n")
            if content:sub(-1) == "\n" then
                new_content = new_content .. "\n"
            end
            msg = "Inserted " .. #insert_lines .. " line(s) after line " .. line_num .. " in " .. path

        else
            -- STR_REPLACE MODE
            local old_str = input.old_string
            local new_str = input.new_string
            local replace_all = input.replace_all or false

            if type(old_str) ~= "string" then
                return { content = "missing or invalid required field: old_string", is_error = true, name = "edit_file" }
            end
            if type(new_str) ~= "string" then
                return { content = "missing or invalid required field: new_string", is_error = true, name = "edit_file" }
            end

            local first_pos = content:find(old_str, 1, true)
            if not first_pos then
                return { content = "old_string not found in " .. path, is_error = true, name = "edit_file" }
            end

            if not replace_all then
                local second_pos = content:find(old_str, first_pos + 1, true)
                if second_pos then
                    return {
                        content = "old_string is not unique in " .. path .. ". Use replace_all=true to replace all occurrences.",
                        is_error = true,
                        name = "edit_file",
                    }
                end
            end

            local count = 0
            if replace_all then
                local escaped = old_str:gsub("([%(%)%.%%%+%-%*%?%[%]%^%$])", "%%%1")
                new_content = content:gsub(escaped, function()
                    count = count + 1
                    return new_str
                end)
            else
                new_content = content:sub(1, first_pos - 1) .. new_str .. content:sub(first_pos + #old_str)
                count = 1
            end
            msg = "Replaced " .. count .. " occurrence(s) in " .. path
        end

        -- Write back
        local wf, werr = io.open(path, "w")
        if not wf then
            return { content = "cannot write: " .. (werr or path), is_error = true, name = "edit_file" }
        end
        wf:write(new_content)
        wf:close()

        -- Trigger Neovim to reload
        vim.schedule(function()
            pcall(vim.cmd, "checktime")
        end)

        return { content = msg, is_error = false, name = "edit_file" }
    end,
}
