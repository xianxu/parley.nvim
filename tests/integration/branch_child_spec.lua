-- #214 BR-1 (Critical). The n/i branch path created its child with an EMPTY
-- topic, which silently disabled two lifecycle steps: auto-titling fires only
-- on `headers.topic == "?"` (chat_respond.lua) and the slug rename bails on ""
-- (init.lua). Every <M-i> branch was therefore a permanently anonymous
-- <timestamp>.md whose parent ref line stayed `🌿: ….md: ` forever.
--
-- The plan claimed the slug "fills in afterwards". The mechanism did exist —
-- what was never checked is whether it FIRES for the value being passed.

local parley = require("parley")

describe("branched child lifecycle (#214)", function()
    local tmpdir, parent_path, parent_buf

    before_each(function()
        parley.setup({})
        tmpdir = vim.fn.tempname()
        vim.fn.mkdir(tmpdir, "p")
        parent_path = tmpdir .. "/2026-09-06.10-00-00.000_parent.md"
        vim.fn.writefile({ "---", "topic: parent topic", "file: f", "---", "", "💬: q" }, parent_path)
        vim.cmd("edit " .. vim.fn.fnameescape(parent_path))
        parent_buf = vim.api.nvim_get_current_buf()
    end)

    after_each(function() vim.fn.delete(tmpdir, "rf") end)

    local function header_of(path)
        local h = {}
        for _, line in ipairs(vim.fn.readfile(path)) do
            local k, v = line:match("^(%w+):%s*(.*)$")
            if k then h[k] = v end
            if line == "---" and h.topic then break end
        end
        return h
    end

    it("a topic-less branch writes the ? sentinel, not an empty topic", function()
        local child = tmpdir .. "/2026-09-06.10-01-00.000.md"
        parley.create_child_chat(child, "?", parent_buf, nil)
        assert.are.equal("?", header_of(child).topic,
            "an empty topic disables auto-titling AND slug rename; the child "
            .. "would stay anonymous forever")
    end)

    it("a selection-derived branch keeps its real topic", function()
        local child = tmpdir .. "/2026-09-06.10-02-00.000.md"
        parley.create_child_chat(child, 'what is "widget"', parent_buf, 'what is "widget"?')
        assert.are.equal('what is "widget"', header_of(child).topic)
    end)

    it("the child carries a resolvable parent back-link", function()
        local child = tmpdir .. "/2026-09-06.10-03-00.000.md"
        parley.create_child_chat(child, "?", parent_buf, nil)
        local body = table.concat(vim.fn.readfile(child), "\n")
        assert.is_truthy(body:find("2026-09-06.10-00-00.000_parent.md", 1, true),
            "parent back-link missing or not by basename")
    end)
end)

-- The tests above pin create_child_chat's BEHAVIOUR. BR-1 lived in the CALL
-- SITE — what topic insert_plain hands it — so mutating that call left them
-- green. Same class as BR-3. This drives the inserter itself.
describe("branch inserter call site (#214 BR-1)", function()
    local tmpdir, parent_path, buf, saved_dir

    before_each(function()
        parley.setup({})
        tmpdir = vim.fn.tempname()
        vim.fn.mkdir(tmpdir, "p")
        saved_dir = parley.config.chat_dir
        parley.config.chat_dir = tmpdir
        parent_path = tmpdir .. "/2026-09-06.11-00-00.000_parent.md"
        vim.fn.writefile({ "---", "topic: parent", "file: f", "---", "", "💬: q" }, parent_path)
        vim.cmd("edit " .. vim.fn.fnameescape(parent_path))
        buf = vim.api.nvim_get_current_buf()
    end)

    after_each(function()
        parley.config.chat_dir = saved_dir
        vim.fn.delete(tmpdir, "rf")
    end)

    it("the no-selection path hands create_child_chat the ? sentinel", function()
        parley._branch_inserters(buf, false).n()
        local created
        for _, f in ipairs(vim.fn.readdir(tmpdir)) do
            if f ~= vim.fn.fnamemodify(parent_path, ":t") then created = tmpdir .. "/" .. f end
        end
        assert.is_truthy(created, "no child file was created")
        local topic
        for _, line in ipairs(vim.fn.readfile(created)) do
            topic = topic or line:match("^topic:%s*(.*)$")
        end
        assert.are.equal("?", topic,
            "the call site passed an empty topic: the child would never be "
            .. "auto-titled and never slugged")
    end)
end)

-- #214 I3-2 / I3-3. Two rules, both stated by the reviewer as classes:
--   1. Every mode that creates a child commits the reference in the SAME action.
--      The enumeration is the dispatch table's keys, so this iterates it rather
--      than naming a mode — BR-19 was fixed on insert_plain and left insert_inline
--      leaking precisely because the fix named a path.
--   2. The commit is scoped to parley CHAT buffers. `:write` commits the whole
--      buffer, so writing an arbitrary markdown document would persist the
--      user's unrelated pending edits.
describe("branch commits its reference, in every mode (#214)", function()
    local tmpdir, saved_dir

    local function chat_buf()
        local path = tmpdir .. "/2026-09-06.12-00-00.000_parent.md"
        vim.fn.writefile({ "---", "topic: parent", "file: f", "---", "", "💬: q", "some prose" }, path)
        vim.cmd("edit! " .. vim.fn.fnameescape(path))
        local b = vim.api.nvim_get_current_buf()
        parley._parley_bufs[b] = "chat"
        return b
    end

    before_each(function()
        parley.setup({})
        tmpdir = vim.fn.tempname(); vim.fn.mkdir(tmpdir, "p")
        saved_dir = parley.config.chat_dir
        parley.config.chat_dir = tmpdir
    end)

    after_each(function()
        parley.config.chat_dir = saved_dir
        vim.fn.delete(tmpdir, "rf")
    end)

    it("leaves the parent saved after EVERY dispatch mode", function()
        local inserters = parley._branch_inserters(chat_buf(), false)
        local modes = {}
        for mode in pairs(inserters) do modes[#modes + 1] = mode end
        table.sort(modes)
        assert.are.same({ "i", "n", "v" }, modes,
            "the dispatch table changed; this test must cover every mode")

        for _, mode in ipairs(modes) do
            local b = chat_buf()
            if mode == "v" then
                vim.api.nvim_win_set_cursor(0, { 7, 0 })
                vim.cmd("normal! v$")
            end
            parley._branch_inserters(b, false)[mode]()
            assert.is_false(vim.bo[b].modified,
                ("mode %q created a child but left the reference unsaved — a :q! "
                    .. "orphans a file discoverable only through that link"):format(mode))
        end
    end)

    it("does NOT write a foreign markdown buffer", function()
        local path = tmpdir .. "/notes.md"
        vim.fn.writefile({ "# Notes" }, path)
        vim.cmd("edit! " .. vim.fn.fnameescape(path))
        local b = vim.api.nvim_get_current_buf()
        vim.api.nvim_buf_set_lines(b, -1, -1, false, { "UNSAVED USER EDIT" })
        assert.is_true(vim.bo[b].modified)

        parley._branch_inserters(b, true).n()

        assert.is_true(vim.bo[b].modified,
            "branching from an arbitrary document must not :write it — that "
            .. "persists unrelated pending edits the user never asked to save")
        local on_disk = table.concat(vim.fn.readfile(path), "\n")
        assert.is_falsy(on_disk:find("UNSAVED USER EDIT", 1, true))
    end)
end)
