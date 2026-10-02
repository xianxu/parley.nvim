-- Pure model of ariadne#252 tracker cards (no IO).
--
-- A tracked repository keeps card-owned issue fields on the `issue-tracker`
-- branch (`workshop/issue-cards/*.md`); the details file in workshop/issues only
-- holds a `card_mirror` snapshot that goes stale when sdlc moves the card. This
-- module parses git output and card blobs, overlays card values onto finder
-- records, and computes the buffer annotations for fields the mirror has wrong.
-- The IO shell is parley.issue_tracker.

local M = {}

M.HIGHLIGHT = "ParleyIssueTracker"

local function trim(value)
    return (value:gsub("^%s+", ""):gsub("%s+$", ""))
end

local function scalar(raw)
    local value = trim(raw)
    local quoted = value:match("^'(.-)'") or value:match('^"(.-)"')
    if quoted then
        return quoted
    end
    return trim((value:gsub("%s+#.*$", "")))
end

-- A card value is a scalar string, or a block: the child lines of a nested
-- field (e.g. `claimant:`), dedented and in order.
local function blank(value)
    return value == nil or value == "" or (type(value) == "table" and #value == 0)
end

local function same(left, right)
    if blank(left) and blank(right) then
        return true
    end
    return vim.deep_equal(left, right)
end

-- One-line form of a card value, for an end-of-line note.
local function inline(value)
    return type(value) == "table" and table.concat(value, ", ") or value
end

-- `key: value` frontmatter lines for a card value; a block nests under `key:`.
local function field_lines(key, value)
    if type(value) ~= "table" then
        return { key .. ": " .. value }
    end
    local out = { key .. ":" }
    for _, child in ipairs(value) do
        out[#out + 1] = "    " .. child
    end
    return out
end

-- Frontmatter lines → the closing `---` index (nil when unterminated) and the
-- top-level entries { {row (0-based), key, value} }. A key with no value
-- followed by indented lines takes a block value (the child lines, dedented).
local function frontmatter(lines)
    local entries = {}
    if lines[1] ~= "---" then
        return nil, entries
    end
    for i = 2, #lines do
        if lines[i] == "---" then
            return i, entries
        end
        local key, value = lines[i]:match("^([%w_]+):(.*)$")
        if key then
            value = scalar(value)
            local indent = value == "" and lines[i + 1] and lines[i + 1]:match("^(%s+)%S")
            if indent then
                value = {}
                for j = i + 1, #lines do
                    if lines[j]:sub(1, #indent) ~= indent then
                        break
                    end
                    value[#value + 1] = lines[j]:sub(#indent + 1)
                end
            end
            entries[#entries + 1] = { row = i - 1, key = key:lower(), value = value }
        end
    end
    return nil, entries
end

-- Card blob text → {id, title, fields} or nil. Top-level `key: value` lines
-- give scalars; a key with no value followed by indented lines gives a block
-- (the `tracker:` envelope included — it is not a vocabulary field, so nothing
-- shows it).
M.parse_card = function(text)
    if type(text) ~= "string" then
        return nil
    end
    local lines = vim.split(text, "\n", { plain = true })
    local close, entries = frontmatter(lines)
    local fields = {}
    for _, entry in ipairs(entries) do
        fields[entry.key] = entry.value
    end
    if not close or type(fields.id) ~= "string" or not fields.id:match("^%d+$") then
        return nil
    end
    local title = ""
    for i = close + 1, #lines do
        local heading = lines[i]:match("^#%s+(.+)$")
        if heading then
            title = trim(heading)
            break
        end
    end
    local body = table.concat(vim.list_slice(lines, close + 1), "\n"):gsub("^\n+", "")
    return { id = fields.id, title = title, fields = fields, body = body }
end

-- `git ls-tree <tip> -- <cards>/` output → { {oid, path, id} }.
M.parse_tree = function(output)
    local entries = {}
    for line in (output or ""):gmatch("[^\n]+") do
        local oid, path = line:match("^%d+ blob (%x+)\t(.+)$")
        local id = path and path:match("([^/]+)$"):match("^(%d+)%-.*%.md$")
        if id then
            entries[#entries + 1] = { oid = oid, path = path, id = id }
        end
    end
    return entries
end

-- `git cat-file --batch` output → {oid = text}. Frames are size-delimited, so
-- blob bytes may contain anything; a truncated frame ends the parse.
M.parse_batch = function(output)
    local blobs, pos = {}, 1
    output = output or ""
    while pos <= #output do
        local eol = output:find("\n", pos, true)
        if not eol then
            break
        end
        local header = output:sub(pos, eol - 1)
        local oid, size = header:match("^(%x+) blob (%d+)$")
        if oid then
            size = tonumber(size)
            if eol + size > #output then
                break
            end
            blobs[oid] = output:sub(eol + 1, eol + size)
            pos = eol + size + 2
        else
            pos = eol + 1 -- `<oid> missing` and other non-blob headers
        end
    end
    return blobs
end

-- The remote to read the tracker from: the upstream's remote when it carries the
-- tracker ref, else the only remote that does. A reader's choice — sdlc owns
-- where card writes go.
M.select_remote = function(upstream_remote, tracker_remotes)
    tracker_remotes = tracker_remotes or {}
    if upstream_remote and vim.tbl_contains(tracker_remotes, upstream_remote) then
        return upstream_remote
    end
    if #tracker_remotes == 1 then
        return tracker_remotes[1]
    end
    return nil
end

-- Card-owned field names from the vocabulary JSON (`card.fields`), minus the
-- `id` join key. nil when the vocabulary carries no card model.
M.card_field_names = function(raw)
    local fields = type(raw) == "table" and type(raw.card) == "table" and raw.card.fields
    if type(fields) ~= "table" then
        return nil
    end
    local names = {}
    for _, field in ipairs(fields) do
        if type(field) == "table" and type(field.name) == "string" and field.name ~= "id" then
            names[#names + 1] = field.name
        end
    end
    return names
end

local function card_value(card, name)
    if name == "title" then
        return card.title
    end
    return card.fields[name]
end

-- A copy of `record` whose card-owned fields come from `card`; fields where the
-- card disagrees with the details are flagged in `tracker_stale`. Without a card
-- the record is returned as is (nothing fabricated).
M.overlay = function(record, card, names)
    local out = {}
    for key, value in pairs(record) do
        out[key] = value
    end
    if not card then
        return out
    end
    out.tracked = true
    out.tracker_stale = {}
    for _, name in ipairs(names or {}) do
        local value = card_value(card, name)
        if name == "title" and blank(value) then
            value = nil -- a card always has a title; blank means no H1 was parsed
        end
        if value ~= nil then
            if not same(value, record[name]) then
                out.tracker_stale[name] = true
            end
            if name == "github_issue" and blank(value) then
                value = nil
            end
            out[name] = value
        end
    end
    return out
end

local function set_of(names)
    local out = {}
    for _, name in ipairs(names or {}) do
        out[name] = true
    end
    return out
end

-- Details buffer lines + card → { {row (0-based), field, text} } for every
-- card-owned frontmatter line (and the H1 title) the card disagrees with.
M.annotations = function(lines, card, names)
    local notes = {}
    if not card then
        return notes
    end
    local owned = set_of(names)
    local function note(row, field, value)
        notes[#notes + 1] = {
            row = row,
            field = field,
            text = "← tracker: " .. (blank(value) and "(empty)" or inline(value)),
        }
    end
    local close, entries = frontmatter(lines)
    for _, entry in ipairs(entries) do
        local key = entry.key
        if key ~= "title" and owned[key] and card.fields[key] ~= nil and not same(card.fields[key], entry.value) then
            note(entry.row, key, card.fields[key])
        end
    end
    if close and owned.title then
        for i = close + 1, #lines do
            local heading = lines[i]:match("^#%s+(.+)$")
            if heading then
                if not same(card.title, trim(heading)) then
                    note(i - 1, "title", card.title)
                end
                break
            end
        end
    end
    return notes
end

-- Card-owned fields the details' frontmatter has no line for, as frontmatter
-- lines in vocabulary order, to show above the closing `---` (`row`, 0-based).
-- nil when there is no card, no closed frontmatter, or nothing to add. Blank card
-- values add nothing; the title lives in the H1, which annotations covers.
M.missing = function(lines, card, names)
    local close, entries = frontmatter(lines)
    if not card or not close then
        return nil
    end
    local present = {}
    for _, entry in ipairs(entries) do
        present[entry.key] = true
    end
    local out = {}
    for _, name in ipairs(names or {}) do
        local value = card.fields[name]
        if name ~= "title" and not present[name] and not blank(value) then
            vim.list_extend(out, field_lines(name, value))
        end
    end
    return #out > 0 and { row = close - 1, lines = out } or nil
end

-- #309: a card with no details file in this checkout (its details may be on
-- another branch) still gets a finder row and a read-only view.

-- One name for a card-only issue: finder row value, identity key, buffer name.
M.card_ref = function(root, id)
    return "parley-card://" .. root .. "#" .. id
end

local function epoch(date)
    local y, m, d = tostring(date or ""):match("^(%d%d%d%d)%-(%d%d)%-(%d%d)")
    return y and os.time({ year = tonumber(y), month = tonumber(m), day = tonumber(d), hour = 12 }) or 0
end

-- Finder records for the cards whose id is not in `local_ids` (details ids from
-- both the issues and the history dir of that repository). `opts = { root,
-- repo_name, is_terminal }`. The records carry an identity, so the finder's
-- dedupe/filter/sort run on them unchanged.
M.card_only_records = function(cards, local_ids, opts)
    local out = {}
    for id, card in pairs(cards or {}) do
        if not local_ids[id] then
            local ref = M.card_ref(opts.root, id)
            local f = card.fields
            out[#out + 1] = {
                id = id,
                title = card.title,
                slug = "",
                deps = {},
                status = f.status,
                created = f.created,
                updated = f.updated,
                github_issue = not blank(f.github_issue) and f.github_issue or nil,
                card_only = true,
                card_root = opts.root,
                repo_name = opts.repo_name,
                archived = opts.is_terminal(f.status) == true,
                mtime = epoch(f.updated),
                identity = { key = ref, source = { root_ordinal = 0, unresolved = ref } },
            }
        end
    end
    return out
end

local function clock(t)
    return os.date("%H:%M", t)
end

-- How current the shown cards are. A failure after the last success reports the
-- failure: cached content never reads as freshly fetched.
M.freshness = function(status)
    local text
    if status.fetch_failed_at and (not status.fetch_ok_at or status.fetch_failed_at >= status.fetch_ok_at) then
        text = "cached · last fetch failed " .. clock(status.fetch_failed_at)
            .. ": " .. ((status.fetch_error or ""):match("[^\n]+") or "unknown error")
    elseif status.fetch_ok_at then
        text = "fetched " .. clock(status.fetch_ok_at)
    else
        text = "local ref · not fetched yet"
    end
    return status.fetching and (text .. " · refreshing…") or text
end

-- The read-only card view: provenance label, the card's vocabulary fields
-- (`names`; the `tracker:` envelope is sdlc's), then the card body as is. Without a card,
-- `readable` tells a card that left the tracker (cards were read) from a
-- tracker that could not be read at all. Nothing is fabricated.
M.view_lines = function(card, id, status, readable, names)
    local ref = status.ref or "issue-tracker"
    local lines = {
        "card only · read only — " .. ref .. (status.tip and (" @ " .. status.tip:sub(1, 7)) or "")
            .. " · " .. M.freshness(status),
        "Details for #" .. id .. " are not in this checkout (they may be on another branch).",
        "Card fields are sdlc's to change: `sdlc issue set-status`, `sdlc claim`.",
        "",
    }
    if not card then
        lines[#lines + 1] = readable and ("Card #" .. id .. " is no longer on " .. ref .. ".")
            or "No tracker cards are readable in this checkout right now."
        return { lines = lines, label_rows = { 0 } }
    end
    for _, name in ipairs(names or {}) do
        if name ~= "title" and card.fields[name] ~= nil then
            vim.list_extend(lines, field_lines(name, card.fields[name]))
        end
    end
    lines[#lines + 1] = ""
    vim.list_extend(lines, vim.split(card.body or "", "\n", { plain = true }))
    return { lines = lines, label_rows = { 0 } }
end

return M
