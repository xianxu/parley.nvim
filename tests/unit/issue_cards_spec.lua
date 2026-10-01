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
