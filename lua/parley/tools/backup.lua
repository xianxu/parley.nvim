-- parley.tools.backup — numbered pre-write backups.
--
-- Single source for the `.parley-backup.<n>` pattern shared by the write tools
-- (write_file, propose_edits, …). Each write saves the prior content to the next
-- free numbered backup, preserving every prior state. (Until the dispatcher's
-- write-path prelude generalizes this, the tools call it inline — ARCH-DRY: one
-- implementation, N callers.)

local M = {}

--- Write `content` (a file's prior state) to the next free
--- `<path>.parley-backup.<n>`.
--- @param path string the file being overwritten
--- @param content string the prior content to preserve
--- @return string|nil backup_path  the backup written, or nil on failure
function M.numbered(path, content)
    local n = 1
    while true do
        local fc = io.open(path .. ".parley-backup." .. n, "r")
        if not fc then
            break
        end
        fc:close()
        n = n + 1
    end
    local bp = path .. ".parley-backup." .. n
    local bf = io.open(bp, "w")
    if not bf then
        return nil
    end
    bf:write(content)
    bf:close()
    return bp
end

return M
