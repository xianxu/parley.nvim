-- parley.skills.review.journal — the self-contained per-round review journal.
--
-- Pure serialize/parse/diff/drift over a markdown sidecar
-- (<doc>.parley-journal.md); the thin IO seam (sidecar_path/read/append) is at
-- the bottom. Replaces docflow's git-branch journaling with a pure-Lua, in-repo
-- record that travels in git WITH the doc — docflow's value (attributed
-- per-round diffs + rationale) without its branch mechanism. See issue #133.

local M = {}

-- 4-backtick fences for the journal's OWN blocks, so an ordinary 3-backtick code
-- fence inside the document (or its diff) cannot close them (markdown's
-- longer-fence nesting rule). A doc using 4-backtick fences is the rare exception.
local FENCE = "````"

--------------------------------------------------------------------------------
-- Pure: diff + hash + drift
--------------------------------------------------------------------------------

--- Unified diff old→new. Deterministic (vim.diff); no IO/state.
--- @param old string
--- @param new string
--- @return string
function M.diff(old, new)
    return vim.diff(old, new, { result_type = "unified" }) or ""
end

--- sha256 of content (thin vim builtin; the one non-pure line, deterministic).
--- @param content string
--- @return string
function M.hash(content)
    return vim.fn.sha256(content)
end

--- Has the doc drifted from the last recorded state? Compares the recorded
--- hash to the current content's hash (e.g. an external edit by Claude Code).
--- @param recorded_hash string
--- @param current_content string
--- @return boolean
function M.is_drift(recorded_hash, current_content)
    return recorded_hash ~= M.hash(current_content)
end

--------------------------------------------------------------------------------
-- Pure: serialize
--------------------------------------------------------------------------------

--- The journal file header. PURE.
function M.header(doc_name)
    return table.concat({
        "# Review journal: " .. tostring(doc_name),
        "",
        "<!-- parley-journal v1 — per-round review history (#133); travels in git with the doc. -->",
        "",
        "",
    }, "\n")
end

--- Serialize the base snapshot (round 0). PURE.
--- @param base_content string
--- @param base_hash string
--- @return string
function M.serialize_base(base_content, base_hash)
    return table.concat({
        "## Base — round 0",
        "",
        ("<!-- parley-base: hash=%s -->"):format(base_hash),
        "",
        FENCE .. "text",
        base_content,
        FENCE,
        "",
        "",
    }, "\n")
end

--- Serialize one round entry to its markdown section. PURE.
--- @param entry table { round, mode?, side, ts, hash, explains?, diff }
--- @return string
function M.serialize_entry(entry)
    local mode = entry.mode
    if mode == nil or mode == "" then
        mode = "none"
    end
    local lines = {
        ("## Round %d — %s · %s · %s"):format(entry.round, mode, entry.side, entry.ts),
        "",
        ("<!-- parley-round: n=%d mode=%s side=%s ts=%s hash=%s -->"):format(
            entry.round, mode, entry.side, entry.ts, entry.hash),
        "",
    }
    if entry.explains and #entry.explains > 0 then
        table.insert(lines, "### Rationale")
        for _, e in ipairs(entry.explains) do
            table.insert(lines, "- " .. (tostring(e):gsub("%s+", " ")))
        end
        table.insert(lines, "")
    end
    table.insert(lines, FENCE .. "diff")
    table.insert(lines, entry.diff or "")
    table.insert(lines, FENCE)
    table.insert(lines, "")
    table.insert(lines, "")
    return table.concat(lines, "\n")
end

--------------------------------------------------------------------------------
-- Pure: parse
--------------------------------------------------------------------------------

--- Parse a journal's text into its machine fields. PURE.
--- @param text string
--- @return table { base = string|nil, base_hash = string|nil, entries = {…} }
function M.parse(text)
    local out = { entries = {} }
    out.base_hash = text:match("parley%-base: hash=(%S+)")
    -- base content = the FENCEtext block immediately after the parley-base comment
    out.base = text:match("parley%-base:.-\n" .. FENCE .. "text\n(.-)\n" .. FENCE)
    -- each round = its comment's fields + the FENCEdiff block that follows it
    local pat = "parley%-round: n=(%S+) mode=(%S+) side=(%S+) ts=(%S+) hash=(%S+) %-%->"
        .. ".-\n" .. FENCE .. "diff\n(.-)\n" .. FENCE
    for n, mode, side, ts, hash, diff in text:gmatch(pat) do
        table.insert(out.entries, {
            round = tonumber(n),
            mode = mode,
            side = side,
            ts = ts,
            hash = hash,
            diff = diff,
        })
    end
    return out
end

--------------------------------------------------------------------------------
-- IO seam (thin) over the pure layer.
--------------------------------------------------------------------------------

--- Sidecar path for a document: <doc>.parley-journal.md (beside the doc, so the
--- review history travels in git WITH the document).
--- @param doc_path string
--- @return string
function M.sidecar_path(doc_path)
    return doc_path .. ".parley-journal.md"
end

local function read_file(path)
    local f = io.open(path, "r")
    if not f then
        return nil
    end
    local c = f:read("*a")
    f:close()
    return c
end

--- Read + parse a doc's journal sidecar. Returns the parsed table
--- ({base, base_hash, entries}); entries is {} when no sidecar exists yet.
--- @param doc_path string
--- @return table
function M.read(doc_path)
    local content = read_file(M.sidecar_path(doc_path))
    if not content then
        return { entries = {} }
    end
    return M.parse(content)
end

--- Append one round to the doc's journal sidecar. Creates it (header + base
--- snapshot, round 0) on the first call. The round number is DERIVED from the
--- existing entry count (so the caller need not track it) and written into
--- `entry.round`.
--- @param doc_path string  the reviewed document's path
--- @param entry table  { mode?, side, ts, hash, explains?, diff } — round filled in
--- @param base_content string  doc content before round 1 (used only on create)
--- @return boolean ok, string|nil err
function M.append(doc_path, entry, base_content)
    local path = M.sidecar_path(doc_path)
    local existing = read_file(path)
    if not existing or existing == "" then
        entry.round = 1
        local doc_name = vim.fn.fnamemodify(doc_path, ":t")
        local body = M.header(doc_name)
            .. M.serialize_base(base_content or "", M.hash(base_content or ""))
            .. M.serialize_entry(entry)
        local f = io.open(path, "w")
        if not f then
            return false, "journal: cannot write " .. path
        end
        f:write(body)
        f:close()
        return true
    end
    entry.round = #M.parse(existing).entries + 1
    local f = io.open(path, "a")
    if not f then
        return false, "journal: cannot append " .. path
    end
    f:write(M.serialize_entry(entry))
    f:close()
    return true
end

return M
