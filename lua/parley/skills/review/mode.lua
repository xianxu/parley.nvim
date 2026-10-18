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
--             Optional, with no default: the universal-review export v3
--             (ariadne#437) retires it, and a document's `presentation:` is
--             then the one proposal knob. A v2 mode file always carries it.
--   frontier  on | off                    — respect the settled region above the
--                                          topmost 🤖[] human marker, or not.

local M = {}

local VALID = {
    scope = { ["whole-doc"] = true, ["markers-only"] = true },
    deletions = { ["apply-with-gutter-why"] = true, ["propose-strike"] = true, ["apply"] = true },
    frontier = { ["on"] = true, ["off"] = true },
}
local DEFAULT = { scope = "markers-only", frontier = "on" }

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
    for key in pairs(VALID) do
        local val = flags[key] or DEFAULT[key]
        if val ~= nil and not VALID[key][val] then
            return nil, ("mode '%s': invalid %s=%s"):format(flags.name, key, tostring(val))
        end
        out[key] = val
    end
    return out
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

--- The packaged universal-review export's version, from <dir>/export.json,
--- or nil when it can't be read. IO seam.
--- @param dir string the skill directory
--- @return number|nil
function M.export_version(dir)
    local ok, manifest = pcall(vim.json.decode, read_file(dir .. "/export.json") or "")
    return ok and type(manifest) == "table" and type(manifest.version) == "number" and manifest.version or nil
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
