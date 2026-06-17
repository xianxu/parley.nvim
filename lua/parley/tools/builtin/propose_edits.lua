-- `propose_edits` — apply a batch of explained string-replacement edits to a
-- file. The P2 (artifact-workbench) edit tool: a real registered builtin, so
-- P2's edit-apply flows through the SAME dispatcher `execute_call` path
-- (cwd-scope guard via `file_path`) as every chat tool — replacing
-- skill_runner's special-cased `apply_edits`.
--
-- Edit logic is the single-source `parley.skill_edits.compute_edits` (pure).
-- The handler is the thin IO wrapper: read → compute → back up → write →
-- checktime. Backup: before a successful write the prior content is saved to the
-- next free `<path>.parley-backup.<n>` (the `write_file.lua` pattern; #128 M3).
-- `needs_backup=true` remains the right classification, but backup is performed
-- inline here today (the dispatcher's write-path prelude is deferred). The
-- diagnostics/highlights rendering stays driver-side (M3), not here.

local skill_edits = require("parley.skill_edits")

return {
    name = "propose_edits",
    kind = "write",
    needs_backup = true,
    description = "Apply a batch of edits to a document. Each edit replaces an exact, unique old_string with new_string and includes a short explanation. Confined to the working directory.",
    input_schema = {
        type = "object",
        properties = {
            file_path = { type = "string", description = "Absolute path to the file to edit." },
            edits = {
                type = "array",
                description = "The edits to apply.",
                items = {
                    type = "object",
                    properties = {
                        old_string = { type = "string", description = "Exact, unique text to replace." },
                        new_string = { type = "string", description = "Replacement text." },
                        explain = { type = "string", description = "Brief reason for the change." },
                    },
                    required = { "old_string", "new_string", "explain" },
                },
            },
        },
        required = { "file_path", "edits" },
    },
    handler = function(input)
        input = input or {}
        local path = input.file_path or input.path
        local edits = input.edits

        if type(path) ~= "string" or path == "" then
            return { content = "missing or invalid required field: file_path", is_error = true, name = "propose_edits" }
        end
        if type(edits) ~= "table" then
            return { content = "missing or invalid required field: edits", is_error = true, name = "propose_edits" }
        end

        local f, err = io.open(path, "r")
        if not f then
            return { content = "cannot open: " .. (err or path), is_error = true, name = "propose_edits" }
        end
        local content = f:read("*a")
        f:close()

        local result = skill_edits.compute_edits(content, edits)
        if not result.ok then
            return { content = result.msg, is_error = true, name = "propose_edits" }
        end

        -- Back up the prior content before the (now-known-valid) write. Numbered
        -- backups (.parley-backup.1, .2, …) preserve every prior state — the
        -- write_file.lua pattern. Only runs once compute_edits succeeds, so an
        -- invalid batch leaves no backup (no destructive write happened).
        local n = 1
        while true do
            local fc = io.open(path .. ".parley-backup." .. n, "r")
            if not fc then
                break
            end
            fc:close()
            n = n + 1
        end
        local bf = io.open(path .. ".parley-backup." .. n, "w")
        if bf then
            bf:write(content)
            bf:close()
        end

        local wf, werr = io.open(path, "w")
        if not wf then
            return { content = "cannot write: " .. (werr or path), is_error = true, name = "propose_edits" }
        end
        wf:write(result.content)
        wf:close()

        -- Trigger Neovim to reload if the file's buffer is open.
        vim.schedule(function()
            pcall(vim.cmd, "checktime")
        end)

        return {
            content = result.msg .. " to " .. path,
            is_error = false,
            name = "propose_edits",
        }
    end,
}
