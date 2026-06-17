-- review.lua — Backward-compatible shim.
--
-- The review feature has been refactored into the skill system:
--   - Marker parsing / quickfix: lua/parley/skills/review/init.lua
--   - Edit application: the propose_edits builtin (via the skill_invoke driver)
--   - Diagnostics / highlights: lua/parley/skill_render.lua
--   - System prompts: lua/parley/skills/review/SKILL.md
--
-- This file re-exports the live marker/quickfix/submit API so existing callers
-- (tests, highlighter.lua, init.lua) continue to work unchanged. (The v1
-- compute_edits/apply_edits/diagnostics re-exports were removed in M4 with
-- skill_runner — they had no non-test callers; the canonical paths are
-- skill_edits, the propose_edits builtin, and skill_render.)

local M = {}

local _review_skill

local function get_review()
    if not _review_skill then _review_skill = require("parley.skills.review") end
    return _review_skill
end

-- Marker parsing (delegated to review skill)
M.parse_markers = function(lines) return get_review().parse_markers(lines) end
M._parse_marker_sections = nil  -- set lazily below
M.populate_quickfix = function(buf, markers, filter) return get_review().populate_quickfix(buf, markers, filter) end
M.scan_pending = function(dir) return get_review().scan_pending(dir) end
M.cmd_review_finder = function() return get_review().cmd_review_finder() end

-- Submit review (delegated to the M3 skill_invoke path via review.run_via_invoke)
M.submit_review = function(buf, level)
    get_review().run_via_invoke(buf, { level = level or "edit" })
end

-- Keybindings (delegated to review skill)
M.setup_keymaps = function(buf) get_review().setup_keymaps(buf) end

-- Lazy property for _parse_marker_sections (used by highlighter.lua)
setmetatable(M, {
    __index = function(t, k)
        if k == "_parse_marker_sections" then
            local val = get_review()._parse_marker_sections
            rawset(t, k, val)
            return val
        end
    end,
})

return M
