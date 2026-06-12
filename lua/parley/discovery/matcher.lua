-- parley.discovery.matcher — a tagged-union predicate deciding whether a
-- file is an instance of a discovery type.
--
-- PURE: no IO, no state. `match(matcher, path, fm)` is a deterministic
-- function of the matcher spec, the file path, and a caller-produced
-- frontmatter table. The `fm` table is produced per-candidate by the
-- caller (datatype docs → YAML frontmatter; chat → parley's chat-header
-- parse); the matcher only consumes it, so this module stays agnostic to
-- how `fm` was parsed.
--
-- Discriminator kinds (from the #116 source-map audit):
--   frontmatter          fm[field] == value      — the datatype `type:` docs
--   frontmatter_present  fm[field] ~= nil          — chat (header `file:`, no type:)
--   filename             basename matches pattern  — issue (NNNNNN-*.md)
--   any                  always true; the descriptor's `locate` glob alone
--                        discriminates (note, plan, vision)

local M = {}

--- Set of known matcher kinds. Exposed for validation reuse (descriptor.lua).
M.KINDS = {
    frontmatter = true,
    frontmatter_present = true,
    filename = true,
    any = true,
}

--- Decide whether (path, fm) is an instance per `matcher`.
--- @param matcher table tagged-union spec: { kind = ..., ... }
--- @param path string repo-relative or absolute file path
--- @param fm table caller-produced frontmatter table (may be empty)
--- @return boolean
function M.match(matcher, path, fm)
    local kind = matcher.kind
    if kind == "frontmatter" then
        return fm[matcher.field] == matcher.value
    elseif kind == "frontmatter_present" then
        return fm[matcher.field] ~= nil
    elseif kind == "filename" then
        local basename = path:match("([^/]+)$") or path
        return basename:match(matcher.pattern) ~= nil
    elseif kind == "any" then
        return true
    end
    -- Fail-loud: a malformed matcher is a programming bug, never valid input.
    error("matcher: unknown kind '" .. tostring(kind) .. "'")
end

return M
