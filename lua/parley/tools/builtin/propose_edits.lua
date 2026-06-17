-- `propose_edits` — apply a batch of explained string-replacement edits to a
-- file. The P2 (artifact-workbench) edit tool: a real registered builtin, so
-- P2's edit-apply flows through the SAME dispatcher `execute_call` path
-- (cwd-scope guard via `file_path`; the M5 backup prelude via `needs_backup`)
-- as every chat tool — replacing skill_runner's special-cased `apply_edits`.
--
-- Edit logic is the single-source `parley.skill_edits.compute_edits` (pure).
-- The handler is the thin IO wrapper: read → compute → write → checktime. The
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
