-- `write_file` — create or overwrite a file.
--
-- PURE: writes content to disk. The dispatcher handles cwd-scope.
-- On first write to a path, captures the prior contents to
-- <path>.parley-backup for safety.
--
-- After writing, triggers :checktime so Neovim reloads the buffer.

return {
    name = "write_file",
    kind = "write",
    needs_backup = true,
    description = "Create or overwrite a file with the given content. On first write, the prior contents (if any) are saved to <path>.parley-backup. Confined to the working directory.",
    input_schema = {
        type = "object",
        properties = {
            file_path = {
                type = "string",
                description = "Path to the file.",
            },
            content = {
                type = "string",
                description = "Full file content to write.",
            },
        },
        required = { "file_path", "content" },
    },
    handler = function(input)
        input = input or {}
        local path = input.file_path or input.path
        local content = input.content

        if type(path) ~= "string" or path == "" then
            return { content = "missing or invalid required field: file_path", is_error = true, name = "write_file" }
        end
        if type(content) ~= "string" then
            return { content = "missing or invalid required field: content", is_error = true, name = "write_file" }
        end

        -- Backup: save prior contents before every write.
        -- Numbered backups: .parley-backup.1, .parley-backup.2, etc.
        local existing = io.open(path, "r")
        if existing then
            local prior = existing:read("*a")
            existing:close()
            -- Find next available backup number
            local n = 1
            while true do
                local bp = path .. ".parley-backup." .. n
                local f_check = io.open(bp, "r")
                if f_check then
                    f_check:close()
                    n = n + 1
                else
                    break
                end
            end
            local bf = io.open(path .. ".parley-backup." .. n, "w")
            if bf then
                bf:write(prior)
                bf:close()
            end
        end

        -- Ensure parent directory exists
        local dir = path:match("(.+)/[^/]+$")
        if dir then
            vim.fn.mkdir(dir, "p")
        end

        -- Write the file
        local f, err = io.open(path, "w")
        if not f then
            return { content = "cannot write: " .. (err or path), is_error = true, name = "write_file" }
        end
        f:write(content)
        f:close()

        -- Trigger Neovim to reload if buffer was open
        vim.schedule(function()
            pcall(vim.cmd, "checktime")
        end)

        local msg = "Written " .. #content .. " bytes to " .. path
        if existing then
            msg = msg .. " (backup at " .. backup_path .. ")"
        end

        return {
            content = msg,
            is_error = false,
            name = "write_file",
        }
    end,
}
