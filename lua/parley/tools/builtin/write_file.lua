-- `write_file` — create or overwrite a file.
--
-- PURE: writes content to disk. The dispatcher handles cwd-scope.
-- On first write to a path, captures the prior contents to
-- <path>.parley-backup for safety.
--
-- After writing, triggers :checktime so Neovim reloads the buffer.

local definition = {
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
        local content

        if type(path) ~= "string" or path == "" then
            return { content = "missing or invalid required field: file_path", is_error = true, name = "write_file" }
        end
        local message
        content,message=require('parley.tools.file_transform').transform('write_file',input,'',path)
        if not content then return {content=message,is_error=true,name='write_file'}end

        -- Backup: save prior contents before every write (shared numbered-backup
        -- helper — .parley-backup.1, .2, …; ARCH-DRY with propose_edits).
        local existing = io.open(path, "r")
        if existing then
            local prior = existing:read("*a")
            existing:close()
            require("parley.tools.backup").numbered(path, prior)
        end

        -- Ensure parent directory exists
        local dir = path:match("(.+)/[^/]+$")
        if dir then
            require("parley.fs").ensure_dir(dir)
        end

        -- Write the file
        local refresh=require('parley.tools.file_refresh').capture(path)
        local f, err = io.open(path, "w")
        if not f then
            require('parley.tools.file_refresh').release(refresh)
            return { content = "cannot write: " .. (err or path), is_error = true, name = "write_file" }
        end
        local written,write_error=f:write(content)
        local closed,close_error=f:close()
        if not written or not closed then
            require('parley.tools.file_refresh').release(refresh)
            return {content='write completion failed: '..tostring(write_error or close_error),is_error=true,name='write_file'}
        end

        local completion=require('parley.tools.file_refresh').complete(refresh,content)
        if completion.reconciliation_required then
            vim.notify('[Disk updated; buffer reconciliation required]',vim.log.levels.WARN)
        end

        local msg = message

        return {
            content = msg,
            is_error = false,
            name = "write_file",
        }
    end,
}

return require("parley.tools.async_builtin").bind(definition)
