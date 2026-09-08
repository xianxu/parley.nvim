-- parley/annotation.lua — what counts as a single-line annotation (#214).
--
-- `🌿:` (branch reference) and `🔒:` (private note) at the start of a line are
-- one-line annotations: withheld from what is sent to the model, but ordinary
-- buffer content in every other respect, and NOT the model's output.
--
-- One owner, because three places need the same answer and had begun to grow
-- their own: `chat_parser`'s trailing-span trim, `buffer_edit.delete_answer`'s
-- resubmit survivors, and the arch guard that checks them. A predicate spelled
-- three times is the shape that lets a fourth caller get it subtly wrong.

local M = {}

--- Default prefixes, used when no config is supplied. The config values are the
--- source of truth wherever one is available.
M.DEFAULTS = { branch = "🌿:", local_note = "🔒:" }

--- Does `line` begin with a single-line annotation prefix?
--- @param line string|nil
--- @param cfg table|nil  parley config; falls back to the shipped prefixes
--- @return boolean
function M.is_annotation(line, cfg)
    if type(line) ~= "string" then return false end
    cfg = cfg or {}
    local branch = cfg.chat_branch_prefix or M.DEFAULTS.branch
    local note = cfg.chat_local_prefix or M.DEFAULTS.local_note
    return vim.startswith(line, branch) or vim.startswith(line, note)
end

return M
