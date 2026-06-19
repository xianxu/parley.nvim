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
    -- Optional editorial-sequence position (developmental → … → free-form), used
    -- to order the menu by the document-construction workflow, not alphabetically.
    out.order = tonumber(flags.order)
    for key, default in pairs(DEFAULT) do
        local val = flags[key] or default
        if not VALID[key][val] then
            return nil, ("mode '%s': invalid %s=%s"):format(flags.name, key, tostring(val))
        end
        out[key] = val
    end
    return out
end

--- Render a Mode's flags into prose directives the model obeys this round. PURE.
--- The base SKILL.md owns the marker grammar/tool contract; this only states
--- which *behavior* the selected mode wants — it does not restate the grammar.
--- @param m table  a parsed Mode
--- @return string  directive block
function M.directives(m)
    local lines = { "## How to apply this round" }
    if m.scope == "whole-doc" then
        table.insert(lines, "- Scope: edit the whole document as the mode brief directs; markers are optional.")
    else
        table.insert(lines, "- Scope: confine edits to text referenced by 🤖 markers; leave the rest untouched.")
    end
    if m.frontier == "on" then
        table.insert(lines, "- Reading frontier: treat everything above the topmost 🤖[] human marker as settled — confine edits and findings to that marker and below.")
    end
    if m.deletions == "apply-with-gutter-why" then
        table.insert(lines, "- Deletions: apply removals directly, and state the reason so the operator sees why it went.")
    elseif m.deletions == "apply" then
        table.insert(lines, "- Deletions: apply mechanical removals directly and silently.")
    else -- propose-strike
        table.insert(lines, "- Deletions/replacements: do NOT apply them — propose each as a 🤖~old~{new} strike marker for the operator to accept or reject.")
    end
    return table.concat(lines, "\n")
end

--------------------------------------------------------------------------------
-- IO seam (thin) over the pure M.parse — reads modes/<name>.md files.
--------------------------------------------------------------------------------

local function read_file(path)
    local f = io.open(path, "r")
    if not f then
        return nil
    end
    local c = f:read("*a")
    f:close()
    return c
end

--- Load one mode by name from <dir>/<name>.md. IO seam over M.parse.
--- @param dir string   directory holding the mode files
--- @param name string  mode name (file basename without .md)
--- @return table|nil mode, string|nil err
function M.load(dir, name)
    local content = read_file(dir .. "/" .. name .. ".md")
    if not content then
        return nil, "mode: no file for '" .. tostring(name) .. "'"
    end
    return M.parse(content)
end

--- List all valid modes under dir, sorted by `order:` then name (editorial
--- sequence). Files that fail to parse are skipped (dropped, not fatal). IO seam.
--- @param dir string
--- @return table list of Mode
function M.list(dir)
    local out = {}
    local handle = vim.loop.fs_scandir(dir)
    if not handle then
        return out
    end
    while true do
        local fname, typ = vim.loop.fs_scandir_next(handle)
        if not fname then
            break
        end
        local base = fname:match("^(.+)%.md$")
        if base and typ ~= "directory" then
            local m = M.parse(read_file(dir .. "/" .. fname) or "")
            -- The canonical identity is the file basename: M.load resolves by it,
            -- and the menu/`complete` offer m.name, so the two MUST agree or the
            -- menu could offer a name load() can't find (silent no-op). Enforce
            -- it here — drop a misconfigured file whose frontmatter name ≠ basename.
            if m and m.name == base then
                table.insert(out, m)
            end
        end
    end
    -- Editorial sequence (by `order:`), then name as a stable tiebreak.
    table.sort(out, function(a, b)
        local ao, bo = a.order or math.huge, b.order or math.huge
        if ao ~= bo then
            return ao < bo
        end
        return a.name < b.name
    end)
    return out
end

return M
