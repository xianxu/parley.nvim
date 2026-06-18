-- Mode — a review mode parsed from a modes/<name>.md sub-file: YAML frontmatter
-- (behavior flags) + a markdown prompt body. PURE parser; the disk reads
-- (load/list) are the thin IO seam below. See issue #133.
--
-- A mode's flags drive how parley treats the LLM's result:
--   scope     whole-doc | markers-only   — edit the whole document, or only
--                                          text referenced by 🤖 markers.
--   deletions apply-with-gutter-why       — apply removals, explain in the gutter
--             | propose-strike            — propose removals as 🤖~old~{new}
--             | apply                      — apply silently (mechanical modes)
--   frontier  on | off                    — respect the settled region above the
--                                          topmost 🤖[] human marker, or not.

local M = {}

local VALID = {
    scope = { ["whole-doc"] = true, ["markers-only"] = true },
    deletions = { ["apply-with-gutter-why"] = true, ["propose-strike"] = true, ["apply"] = true },
    frontier = { ["on"] = true, ["off"] = true },
}
local DEFAULT = { scope = "markers-only", deletions = "propose-strike", frontier = "on" }

--- Parse a mode file's content into a Mode. PURE — no IO.
--- @param content string  the file's text
--- @return table|nil mode  { name, scope, deletions, frontier, body }
--- @return string|nil err  set (with mode nil) on any parse/validation failure
function M.parse(content)
    if type(content) ~= "string" then
        return nil, "mode: content must be a string"
    end
    -- Frontmatter is keyed off the LEADING `---\n` only, so a `---` inside the
    -- body (e.g. a horizontal rule) can't be mistaken for the fence.
    local _, fm_end = content:find("^%-%-%-\n")
    if not fm_end then
        return nil, "mode: missing frontmatter (--- … ---)"
    end
    local close = content:find("\n%-%-%-\n?", fm_end)
    if not close then
        return nil, "mode: unterminated frontmatter"
    end
    local fm = content:sub(fm_end + 1, close)
    -- A modes file has only flat scalar keys (no nesting, no lists), so a
    -- minimal `k: v` scan is enough — we deliberately do NOT pull in a YAML lib.
    local flags = {}
    for line in fm:gmatch("[^\n]+") do
        local k, v = line:match("^(%w[%w_-]*):%s*(.-)%s*$")
        if k then
            flags[k] = v
        end
    end
    if not flags.name or flags.name == "" then
        return nil, "mode: frontmatter needs a name"
    end

    -- Body = everything past the closing fence line.
    local nl_after_fence = content:find("\n", close + 1)
    local body = content:sub((nl_after_fence or #content) + 1)

    local out = { name = flags.name, body = (body:gsub("%s+$", "")) }
    for key, default in pairs(DEFAULT) do
        local val = flags[key] or default
        if not VALID[key][val] then
            return nil, ("mode '%s': invalid %s=%s"):format(flags.name, key, tostring(val))
        end
        out[key] = val
    end
    return out
end

return M
