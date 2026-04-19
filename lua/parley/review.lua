-- review.lua — Backward-compatible shim.
--
-- The review feature has been refactored into the skill system:
--   - Marker parsing / quickfix: lua/parley/skills/review/init.lua
--   - Edit pipeline / diagnostics: lua/parley/skill_runner.lua
--   - System prompts: lua/parley/skills/review/SKILL.md
--
-- This file re-exports the public API so existing callers (tests,
-- highlighter.lua, init.lua) continue to work unchanged.

local M = {}

local _review_skill
local _skill_runner

local function get_review()
    if not _review_skill then _review_skill = require("parley.skills.review") end
    return _review_skill
end

local function get_runner()
    if not _skill_runner then _skill_runner = require("parley.skill_runner") end
    return _skill_runner
end

-- Marker parsing (delegated to review skill)
M.parse_markers = function(lines) return get_review().parse_markers(lines) end
M._parse_marker_sections = nil  -- set lazily below
M.populate_quickfix = function(buf, markers, filter) return get_review().populate_quickfix(buf, markers, filter) end
M.scan_pending = function(dir) return get_review().scan_pending(dir) end
M.cmd_review_finder = function() return get_review().cmd_review_finder() end

-- Edit computation (delegated to skill_runner)
M.compute_edits = function(content, edits) return get_runner().compute_edits(content, edits) end
M.apply_edits = function(file_path, edits) return get_runner().apply_edits(file_path, edits) end

-- Diagnostics (delegated to skill_runner)
M.attach_diagnostics = function(buf, edits, original_content) return get_runner().attach_diagnostics(buf, edits, original_content) end
M.highlight_edits = function(buf, edits, new_content) return get_runner().highlight_edits(buf, edits, new_content) end

-- Submit review (delegated to skill_runner.run with review skill)
M.submit_review = function(buf, level)
    get_runner().run(buf, get_review().skill, { level = level or "edit" })
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
