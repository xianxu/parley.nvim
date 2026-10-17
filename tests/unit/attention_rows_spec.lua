-- #354 M2: the attention finder's rows. Pure: entries in, float_picker items out.
local Rows = require("parley.attention_rows")
local Model = require("parley.attention_model")

local function at(t) return ("%02d:%02d"):format(math.floor(t / 60), t % 60) end
local options = { home = "/home/me", clock = at }

local function entry(path, fields)
    return vim.tbl_extend("force", { path = path, pending = {}, submitted_at = 600 }, fields or {})
end

describe("attention_rows.items", function()
    -- Strategy: one row per state, checked whole (text, highlight span, value,
    -- search text); then the order and the unknown marker.
    local cases = {
        { "waiting", entry("/home/me/w/tl.md", { pending = { m1 = 600 } }), "waiting    tl.md  ~/w  10:00", "ParleyAttentionWaiting" },
        { "answered", entry("/srv/a.md", { answered_at = 700 }), "answered   a.md  /srv  10:00", "ParleyAttentionAnswered" },
        { "seen", entry("/srv/s.md", { answered_at = 700, seen_at = 800 }), "seen       s.md  /srv  10:00", "ParleyAttentionSeen" },
        { "unknown", entry("/srv/u.md", { pending = { m1 = 600 }, unknown = "unsupported" }), "waiting  ? u.md  /srv  10:00", "ParleyAttentionWaiting" },
        { "side", entry("/srv/a.side/s.md", { answered_at = 600, kind = "side", parent = "/srv/a.md" }), "answered ↳ s.md  /srv/a.side  10:00", "ParleyAttentionAnswered" },
    }
    for _, case in ipairs(cases) do
        it("renders a " .. case[1] .. " entry", function()
            local item = Rows.items({ case[2] }, options)[1]
            assert.equals(case[3], item.display)
            assert.same({ { 0, #case[3], case[4] } }, item.highlights)
            assert.equals(case[2].path, item.value)
            local parent = case[2].parent and (" " .. vim.fn.fnamemodify(case[2].parent, ":t")) or ""
            assert.equals(vim.fn.fnamemodify(case[2].path, ":t") .. " " .. vim.fn.fnamemodify(case[2].path, ":h") .. parent, item.search_text)
        end)
    end

    it("keeps the model's order: newest submit first", function()
        local state = Model.empty()
        for i, path in ipairs({ "/x/old.md", "/x/new.md" }) do
            state = Model.transition(state, { type = "submitted", path = path, id = "m" .. i }, i * 60)
        end
        local items = Rows.items(Model.list(state), options)
        assert.same({ "/x/new.md", "/x/old.md" }, vim.tbl_map(function(item) return item.value end, items))
    end)
end)
