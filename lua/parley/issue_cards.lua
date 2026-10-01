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

-- Finder record fields a card can own (the rest stay with the details).
local RECORD_FIELDS = { "status", "title", "created", "updated", "github_issue" }

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

local function blank(value)
    return value == nil or value == ""
end

local function same(left, right)
    if blank(left) and blank(right) then
        return true
    end
    return left == right
end

-- Card blob text → {id, title, fields} or nil. Only top-level `key: value`
-- lines are read; the indented `tracker:` envelope is internal to sdlc.
M.parse_card = function(text)
    if type(text) ~= "string" then
        return nil
    end
    local lines = vim.split(text, "\n", { plain = true })
    if lines[1] ~= "---" then
        return nil
    end
    local fields, close = {}, nil
    for i = 2, #lines do
        if lines[i] == "---" then
            close = i
            break
        end
        local key, value = lines[i]:match("^([%w_]+):(.*)$")
        if key then
            fields[key:lower()] = scalar(value)
        end
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
    local owned = {}
    for _, name in ipairs(names or {}) do
        owned[name] = true
    end
    out.tracked = true
    out.tracker_stale = {}
    for _, name in ipairs(RECORD_FIELDS) do
        local value = card_value(card, name)
        if name == "title" and blank(value) then
            value = nil -- a card always has a title; blank means no H1 was parsed
        end
        if owned[name] and value ~= nil then
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

-- Details buffer lines + card → { {row (0-based), field, text} } for every
-- card-owned frontmatter line (and the H1 title) the card disagrees with.
M.annotations = function(lines, card, names)
    local notes = {}
    if not card or lines[1] ~= "---" then
        return notes
    end
    local owned = {}
    for _, name in ipairs(names or {}) do
        owned[name] = true
    end
    local function note(row, field, value)
        notes[#notes + 1] = {
            row = row,
            field = field,
            text = "← tracker: " .. (blank(value) and "(empty)" or value),
        }
    end
    local close
    for i = 2, #lines do
        if lines[i] == "---" then
            close = i
            break
        end
        local key, value = lines[i]:match("^([%w_]+):(.*)$")
        key = key and key:lower()
        if key and key ~= "title" and owned[key] and card.fields[key] ~= nil
            and not same(card.fields[key], scalar(value)) then
            note(i - 1, key, card.fields[key])
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

local VIEW_FIELDS = { "status", "created", "updated", "github_issue", "estimate_hours" }

-- The read-only card view: provenance label, the card's top-level fields (the
-- `tracker:` envelope is sdlc's), then the card body as is. `card` nil means the
-- card left the tracker. Nothing is fabricated.
M.view_lines = function(card, id, status)
    local ref = status.ref or "issue-tracker"
    local lines = {
        "card only · read only — " .. ref .. (status.tip and (" @ " .. status.tip:sub(1, 7)) or "")
            .. " · " .. M.freshness(status),
        "Details for #" .. id .. " are not in this checkout (they may be on another branch).",
        "Card fields are sdlc's to change: `sdlc issue set-status`, `sdlc claim`.",
        "",
    }
    if not card then
        lines[#lines + 1] = "Card #" .. id .. " is no longer on " .. ref .. "."
        return { lines = lines, label_rows = { 0 } }
    end
    for _, key in ipairs(VIEW_FIELDS) do
        if card.fields[key] ~= nil then
            lines[#lines + 1] = key .. ": " .. card.fields[key]
        end
    end
    lines[#lines + 1] = ""
    vim.list_extend(lines, vim.split(card.body or "", "\n", { plain = true }))
    return { lines = lines, label_rows = { 0 } }
end

return M
