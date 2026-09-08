-- parley/annotation.lua — what counts as an annotation (#214).
--
-- `🌿:` (branch reference) and `🔒:` (private note) are withheld from what is
-- sent to the model but are ordinary buffer content otherwise, and — this is the
-- part that keeps being missed — they are NOT the model's output. A resubmit
-- regenerates an answer; it must not take the user's annotations with it.
--
-- Two FORMS, not one. Enumerating line positions (leading / middle / trailing)
-- and fixing them is not enumerating forms: an inline `[🌿:anchor](file)` sits
-- inside prose, so a line-start predicate does not see it, and the visual
-- branch — the case that exists to produce one — kept losing its child on the
-- next resubmit (BR-75 fixed the line form, BR-79 the inline one).
--
-- One owner, because four places need these answers: the parser's trailing-span
-- trim, the resubmit's survivor filter, the arch guard, and the tests.

local M = {}

--- The annotation prefixes for `cfg`.
---
--- Derived through `highlight_structure.patterns`, which is already the one
--- place that resolves a prefix from config or falls back — rather than a second
--- default table here (#214 BR-80: fabricating them silently answers for a
--- caller that forgot to thread config through, which is the shape #215's
--- `is_partition` exists to forbid, and the wrong answer here deletes user
--- data). One source for the defaults, one owner for the question.
--- @param cfg table  parley config
--- @return string branch, string local_note
local function prefixes(cfg)
    assert(type(cfg) == "table", "annotation: config is required, not optional")
    local p = require("parley.highlight_structure").patterns(cfg)
    return p.branch_prefix, p.local_prefix
end

--- Does `line` BEGIN with a single-line annotation prefix?
--- @param line string|nil
--- @param cfg table
--- @return boolean
function M.is_annotation(line, cfg)
    if type(line) ~= "string" then return false end
    local branch, note = prefixes(cfg)
    return vim.startswith(line, branch) or vim.startswith(line, note)
end

--- Every inline `[🌿:anchor](path)` in `line`, as `{ anchor, path }` pairs.
--- @param line string|nil
--- @param cfg table
--- @return table[]
function M.inline_links(line, cfg)
    if type(line) ~= "string" then return {} end
    local branch = (prefixes(cfg))
    local out = {}
    for _, link in ipairs(require("parley.chat_parser")
        .extract_inline_branch_links(line, branch)) do
        out[#out + 1] = { anchor = link.topic, path = link.path }
    end
    return out
end

--- What must survive when `lines` are deleted as a regenerated answer.
---
--- A line-start annotation survives verbatim. An inline link survives as a
--- STANDALONE reference: the prose around it belonged to the answer being
--- replaced, and keeping it would leave a stale sentence inside the new answer —
--- but the link itself is the only pointer to a child chat on disk, so it is
--- reformatted rather than dropped.
--- @param lines string[]
--- @param cfg table
--- @return string[]
function M.survivors(lines, cfg)
    local branch = (prefixes(cfg))
    local branch_ref = require("parley.branch_ref")
    local out = {}
    for _, line in ipairs(lines) do
        if M.is_annotation(line, cfg) then
            out[#out + 1] = line
        else
            for _, link in ipairs(M.inline_links(line, cfg)) do
                out[#out + 1] = branch_ref.format_ref_line(branch, link.path, link.anchor)
            end
        end
    end
    return out
end

return M
