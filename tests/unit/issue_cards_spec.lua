local cards = require("parley.issue_cards")

local CARD_296 = table.concat({
    "---",
    "id: 000296",
    "status: wontfix",
    "created: 2026-09-28",
    "updated: 2026-09-29",
    "estimate_hours:",
    "github_issue:",
    "tracker:",
    "    version: 1",
    "    handoff:",
    "        token: move-e3d2ea715de8",
    "        source_branch: refs/heads/main",
    "started: 2026-09-28T17:32:50-07:00",
    "---",
    "",
    "# Package Screenkey for app recordings",
    "",
    "## Problem",
}, "\n")

local DETAILS_296 = {
    "---",
    "id: 000296",
    "status: open",
    "deps: []",
    "github_issue:",
    "created: 2026-09-28",
    "updated: 2026-09-28",
    "estimate_hours:",
    "card_mirror: '4761b1d7' # card fields mirrored from issue-cards; edit via sdlc",
    "---",
    "",
    "# Package Screenkey for app recordings",
}

local NAMES = { "status", "started", "created", "updated", "estimate_hours", "actual_hours", "github_issue", "title" }

describe("issue_cards.parse_card", function()
    it("reads top-level card fields and the H1, ignoring the tracker envelope", function()
        local card = cards.parse_card(CARD_296)
        assert.are.equal("000296", card.id)
        assert.are.equal("wontfix", card.fields.status)
        assert.are.equal("2026-09-28T17:32:50-07:00", card.fields.started)
        assert.are.equal("", card.fields.github_issue)
        assert.is_nil(card.fields.token)
        assert.is_nil(card.fields.handoff)
        assert.are.equal("Package Screenkey for app recordings", card.title)
    end)

    it("strips quotes and trailing comments", function()
        local card = cards.parse_card("---\nid: '000007'\nstatus: \"done\" # note\n---\n# T\n")
        assert.are.equal("000007", card.id)
        assert.are.equal("done", card.fields.status)
    end)

    it("refuses blobs without frontmatter or a numeric id", function()
        assert.is_nil(cards.parse_card("# no frontmatter\n"))
        assert.is_nil(cards.parse_card("---\nid: ../etc\n---\n"))
        assert.is_nil(cards.parse_card("---\nid: 000001\n"))
    end)
end)

describe("issue_cards.parse_tree", function()
    it("lists card blobs with their ids", function()
        local entries = cards.parse_tree(table.concat({
            "100644 blob abc\tworkshop/issue-cards/000296-app-screenkey.md",
            "100644 blob def\tworkshop/issue-cards/README.txt",
            "100644 blob 123\tworkshop/issue-cards/notes.md",
            "",
        }, "\n"))
        assert.are.same({
            { oid = "abc", path = "workshop/issue-cards/000296-app-screenkey.md", id = "000296" },
        }, entries)
    end)
end)

describe("issue_cards.parse_batch", function()
    it("decodes size-framed blobs and skips missing objects", function()
        local a = "line one\n\nline three"
        local b = "x"
        local payload = "aaa blob " .. #a .. "\n" .. a .. "\n"
            .. "zzz missing\n"
            .. "bbb blob " .. #b .. "\n" .. b .. "\n"
        assert.are.same({ aaa = a, bbb = b }, cards.parse_batch(payload))
    end)

    it("stops at a truncated frame", function()
        assert.are.same({ aaa = "ok" }, cards.parse_batch("aaa blob 2\nok\nbbb blob 99\nshort"))
    end)
end)

describe("issue_cards.select_remote", function()
    it("prefers the upstream remote, else a unique tracker remote", function()
        assert.are.equal("origin", cards.select_remote("origin", { "fork", "origin" }))
        assert.are.equal("fork", cards.select_remote(nil, { "fork" }))
        assert.are.equal("fork", cards.select_remote("origin", { "fork" }))
        assert.is_nil(cards.select_remote(nil, { "a", "b" }))
        assert.is_nil(cards.select_remote("x", {}))
    end)
end)

describe("issue_cards.card_field_names", function()
    it("derives card-owned fields from the shipped vocabulary", function()
        local raw = vim.json.decode(table.concat(vim.fn.readfile("construct/generated/vocabulary/issue.json"), "\n"))
        local names = cards.card_field_names(raw)
        assert.is_true(vim.tbl_contains(names, "status"))
        assert.is_true(vim.tbl_contains(names, "title"))
        assert.is_true(vim.tbl_contains(names, "github_issue"))
        assert.is_false(vim.tbl_contains(names, "id"))
        assert.is_nil(cards.card_field_names({}))
        assert.is_nil(cards.card_field_names(nil))
    end)
end)

describe("issue_cards.overlay", function()
    local record = {
        id = "000296", title = "Package Screenkey for app recordings", status = "open",
        created = "2026-09-28", updated = "2026-09-28", github_issue = nil, deps = {},
    }

    it("lets card values win and flags fields that differ", function()
        local out = cards.overlay(record, cards.parse_card(CARD_296), NAMES)
        assert.are.equal("wontfix", out.status)
        assert.are.equal("2026-09-29", out.updated)
        assert.is_true(out.tracked)
        assert.are.same({ status = true, updated = true }, out.tracker_stale)
        assert.are.equal("open", record.status) -- input untouched
    end)

    it("treats nil and empty as equal and flags a different title", function()
        local card = cards.parse_card(CARD_296)
        card.title = "Renamed"
        local out = cards.overlay(record, card, NAMES)
        assert.is_nil(out.tracker_stale.github_issue)
        assert.is_nil(out.github_issue)
        assert.are.equal("Renamed", out.title)
        assert.is_true(out.tracker_stale.title)
    end)

    it("keeps the details title when the card has no H1, and flags a dropped GitHub link", function()
        local card = cards.parse_card(CARD_296)
        card.title = ""
        local linked = vim.tbl_extend("force", record, { github_issue = "12" })
        local out = cards.overlay(linked, card, NAMES)
        assert.are.equal("Package Screenkey for app recordings", out.title)
        assert.is_nil(out.tracker_stale.title)
        assert.is_nil(out.github_issue)
        assert.is_true(out.tracker_stale.github_issue)
    end)

    it("returns the record unchanged without a card", function()
        local out = cards.overlay(record, nil, NAMES)
        assert.are.equal("open", out.status)
        assert.is_nil(out.tracked)
        assert.is_nil(out.tracker_stale)
    end)
end)

describe("issue_cards.annotations", function()
    it("annotates differing card-owned frontmatter lines only", function()
        local notes = cards.annotations(DETAILS_296, cards.parse_card(CARD_296), NAMES)
        assert.are.same({
            { row = 2, field = "status", text = "← tracker: wontfix" },
            { row = 6, field = "updated", text = "← tracker: 2026-09-29" },
        }, notes)
    end)

    it("annotates the H1 when the title differs, and blank values as (empty)", function()
        local card = cards.parse_card(CARD_296)
        card.title = "Renamed"
        card.fields.created = ""
        local notes = cards.annotations(DETAILS_296, card, NAMES)
        local by_field = {}
        for _, n in ipairs(notes) do by_field[n.field] = n end
        assert.are.equal(11, by_field.title.row)
        assert.are.equal("← tracker: Renamed", by_field.title.text)
        assert.are.equal("← tracker: (empty)", by_field.created.text)
    end)
end)

-- #309: card-only issues (a card with no details file in this checkout).
local CARD_305 = CARD_296:gsub("000296", "000305"):gsub("wontfix", "open")
    .. "\n\nThe Problem text.\n"

describe("issue_cards.parse_card body", function()
    it("keeps the card text after the frontmatter, Problem included", function()
        local card = cards.parse_card(CARD_305)
        assert.truthy(card.body:find("^# Package Screenkey for app recordings"))
        assert.truthy(card.body:find("## Problem\n\nThe Problem text.", 1, true))
        assert.falsy(card.body:find("tracker:", 1, true))
    end)
end)

describe("issue_cards.card_only_records", function()
    local parsed = {
        ["000305"] = cards.parse_card(CARD_305),
        ["000296"] = cards.parse_card(CARD_296),
        ["000001"] = cards.parse_card((CARD_296:gsub("000296", "000001"))),
    }
    local function terminal(status) return status == "wontfix" or status == "done" end

    it("synthesizes one record per card without local details", function()
        local records = cards.card_only_records(parsed, { ["000001"] = true },
            { root = "/r", repo_name = "repo", is_terminal = terminal })
        table.sort(records, function(a, b) return a.id < b.id end)
        assert.are.equal(2, #records)
        local open, closed = records[2], records[1]
        assert.are.equal("000305", open.id)
        assert.is_true(open.card_only)
        assert.are.equal("/r", open.card_root)
        assert.are.equal("repo", open.repo_name)
        assert.are.equal("open", open.status)
        assert.is_false(open.archived)
        assert.is_true(closed.archived)
        assert.are.equal("parley-card:///r#000305", open.identity.key)
        assert.are.equal(cards.card_ref("/r", "000305"), open.identity.source.unresolved)
        assert.are.equal(os.time({ year = 2026, month = 9, day = 29, hour = 12 }), open.mtime)
        assert.is_nil(open.github_issue)
        assert.is_nil(open.path)
    end)

    it("returns nothing when every card has details", function()
        assert.same({}, cards.card_only_records(parsed,
            { ["000305"] = true, ["000296"] = true, ["000001"] = true },
            { root = "/r", is_terminal = terminal }))
    end)
end)

describe("issue_cards.freshness", function()
    local t1 = os.time({ year = 2026, month = 9, day = 30, hour = 10, min = 0 })
    local t2 = os.time({ year = 2026, month = 9, day = 30, hour = 10, min = 5 })

    it("reports a successful fetch", function()
        assert.are.equal("fetched 10:00", cards.freshness({ fetch_ok_at = t1 }))
    end)
    it("never claims freshness after a failure", function()
        assert.are.equal("cached · last fetch failed 10:05: fatal: x",
            cards.freshness({ fetch_ok_at = t1, fetch_failed_at = t2, fetch_error = "fatal: x\nmore" }))
        assert.are.equal("cached · last fetch failed 10:05: unknown error",
            cards.freshness({ fetch_failed_at = t2 }))
    end)
    it("says when nothing was fetched yet", function()
        assert.are.equal("local ref · not fetched yet", cards.freshness({}))
    end)
    it("marks a running fetch", function()
        assert.are.equal("fetched 10:00 · refreshing…", cards.freshness({ fetch_ok_at = t1, fetching = true }))
    end)
end)

describe("issue_cards.view_lines", function()
    local status = { ref = "origin/issue-tracker", tip = "abc1234def5678", fetch_ok_at = os.time() }

    it("labels provenance and shows the card without its envelope", function()
        local view = cards.view_lines(cards.parse_card(CARD_305), "000305", status)
        assert.truthy(view.lines[1]:find("card only · read only", 1, true))
        assert.truthy(view.lines[1]:find("origin/issue-tracker @ abc1234 ", 1, true))
        assert.truthy(view.lines[2]:find("not in this checkout", 1, true))
        assert.same({ 0 }, view.label_rows)
        local text = table.concat(view.lines, "\n")
        assert.truthy(text:find("\nstatus: open\n", 1, true))
        assert.truthy(text:find("## Problem\n\nThe Problem text.", 1, true))
        assert.falsy(text:find("tracker:", 1, true))
        assert.falsy(text:find("version:", 1, true))
        assert.falsy(text:find("## Spec", 1, true))
        assert.falsy(text:find("## Plan", 1, true))
    end)

    it("says when the card left the tracker", function()
        local view = cards.view_lines(nil, "000005", status)
        assert.are.equal("Card #000005 is no longer on origin/issue-tracker.", view.lines[#view.lines])
    end)
end)
