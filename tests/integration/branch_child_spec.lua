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
        parley.create_child_chat(child, "widget", parent_buf,
            require("parley.branch_submit").seed_question("define", "widget"))
        assert.are.equal("widget", header_of(child).topic)
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
        -- A CHAT buffer: only there does parley create a child, because only
        -- there can it commit the reference (BR-28).
        parley._parley_bufs[buf] = "chat"
    end)

    after_each(function()
        parley._parley_bufs[buf] = nil
        parley.config.chat_dir = saved_dir
        vim.fn.delete(tmpdir, "rf")
    end)

    it("the no-selection path hands create_child_chat the ? sentinel", function()
        parley._branch_inserters(buf, false, true).n()
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
        local inserters = parley._branch_inserters(chat_buf(), false, true)
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
            parley._branch_inserters(b, false, true)[mode]()
            assert.is_false(vim.bo[b].modified,
                ("mode %q created a child but left the reference unsaved — a :q! "
                    .. "orphans a file discoverable only through that link"):format(mode))
        end
    end)

    it("on a foreign markdown buffer: inserts the ref, no child, no write", function()
        -- BR-27/BR-28: parley cannot make the reference durable in a file it does
        -- not own, so it must not create a child there either — an orphan on disk
        -- reachable only through an unsaved line. And it must still do the LOCAL
        -- work (cursor + insert mode) an early return once skipped, which made
        -- the key look inert.
        local path = tmpdir .. "/plain-notes.md"
        vim.fn.writefile({ "# Notes", "body" }, path)
        vim.cmd("edit! " .. vim.fn.fnameescape(path))
        local b = vim.api.nvim_get_current_buf()
        vim.api.nvim_win_set_cursor(0, { 1, 0 })
        local before = #vim.fn.readdir(tmpdir)

        parley._branch_inserters(b, true, false).n()

        assert.are.equal(before, #vim.fn.readdir(tmpdir),
            "no child may be created in a buffer parley cannot commit")
        -- The reference is inserted as its own BLOCK (#214 BR-68), so it may be
        -- preceded by a margin blank; what matters is that it exists and that
        -- the cursor is on IT, not on the blank.
        local body = vim.api.nvim_buf_get_lines(b, 0, -1, false)
        local ref_row
        for i, line in ipairs(body) do if line:find("🌿:", 1, true) then ref_row = i end end
        assert.is_truthy(ref_row, "the reference line must still be inserted")
        assert.are.equal(ref_row, vim.api.nvim_win_get_cursor(0)[1],
            "cursor must land on the new reference line so the topic can be typed")
    end)

    it("does NOT write a foreign markdown buffer", function()
        local path = tmpdir .. "/notes.md"
        vim.fn.writefile({ "# Notes" }, path)
        vim.cmd("edit! " .. vim.fn.fnameescape(path))
        local b = vim.api.nvim_get_current_buf()
        vim.api.nvim_buf_set_lines(b, -1, -1, false, { "UNSAVED USER EDIT" })
        assert.is_true(vim.bo[b].modified)

        parley._branch_inserters(b, true, false).n()

        assert.is_true(vim.bo[b].modified,
            "branching from an arbitrary document must not :write it — that "
            .. "persists unrelated pending edits the user never asked to save")
        local on_disk = table.concat(vim.fn.readfile(path), "\n")
        assert.is_falsy(on_disk:find("UNSAVED USER EDIT", 1, true))
    end)
end)

-- #214 BR-28, third occurrence. The ownership rule was applied to insert_plain
-- twice while insert_inline kept creating children on foreign markdown. The
-- enumeration is modes x buffer types — six cells — so this iterates BOTH axes
-- instead of naming a path.
describe("no child is created in a buffer parley cannot commit (#214)", function()
    local tmpdir, saved_dir

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

    it("every mode on a FOREIGN buffer creates no file and writes nothing", function()
        for _, mode in ipairs({ "n", "i", "v" }) do
            local path = tmpdir .. "/doc-" .. mode .. ".md"
            vim.fn.writefile({ "# Doc", "some prose here" }, path)
            vim.cmd("edit! " .. vim.fn.fnameescape(path))
            local b = vim.api.nvim_get_current_buf()
            local before = #vim.fn.readdir(tmpdir)
            if mode == "v" then
                vim.api.nvim_win_set_cursor(0, { 2, 0 })
                vim.cmd("normal! v$")
            end
            parley._branch_inserters(b, true, false)[mode]()
            assert.are.equal(before, #vim.fn.readdir(tmpdir),
                ("mode %q created a child in a buffer parley cannot commit — an "
                    .. "orphan reachable only through an unsaved line"):format(mode))
        end
    end)
end)

-- #214 BR-21. The first attempt at this ran the fixed gsub inside the test body,
-- so it proved Lua's semantics rather than parley's code — reverting the fix
-- left it green. This drives create_child_chat, the function that owns the
-- substitution.
describe("a selection with pattern metacharacters (#214 BR-21)", function()
    local tmpdir, parent_buf

    before_each(function()
        parley.setup({})
        tmpdir = vim.fn.tempname(); vim.fn.mkdir(tmpdir, "p")
        local parent = tmpdir .. "/2026-09-06.13-00-00.000_p.md"
        vim.fn.writefile({ "---", "topic: p", "file: f", "---", "", "💬: q" }, parent)
        vim.cmd("edit! " .. vim.fn.fnameescape(parent))
        parent_buf = vim.api.nvim_get_current_buf()
    end)
    after_each(function() vim.fn.delete(tmpdir, "rf") end)

    local function topic_of(path)
        for _, l in ipairs(vim.fn.readfile(path)) do
            local t = l:match("^topic:%s*(.*)$")
            if t then return t end
        end
    end

    it("a topic containing % does not raise, and lands verbatim", function()
        local child = tmpdir .. "/2026-09-06.13-01-00.000.md"
        local topic = 'what is "50% off"'
        assert.has_no.errors(function()
            parley.create_child_chat(child, topic, parent_buf, topic .. "?")
        end)
        assert.are.equal(topic, topic_of(child))
    end)

    it("a topic containing %1 is not treated as a capture reference", function()
        local child = tmpdir .. "/2026-09-06.13-02-00.000.md"
        local topic = 'what is "%1 placeholder"'
        parley.create_child_chat(child, topic, parent_buf, topic .. "?")
        assert.are.equal(topic, topic_of(child))
    end)
end)

-- #214 BR-10 / BR-17, measured as unpinned across three rounds.
describe("residual M1 fixes, pinned (#214)", function()
    before_each(function() parley.setup({}) end)

    it("BR-10: a NON-chat parent gets an absolute back-link, not a bare basename", function()
        local tmpdir = vim.fn.tempname(); vim.fn.mkdir(tmpdir, "p")
        local parent = tmpdir .. "/plain-notes.md"     -- no parseable timestamp
        vim.fn.writefile({ "# Notes" }, parent)
        vim.cmd("edit! " .. vim.fn.fnameescape(parent))
        local pb = vim.api.nvim_get_current_buf()
        local child = tmpdir .. "/2026-09-06.14-00-00.000.md"
        parley.create_child_chat(child, "?", pb, nil)
        local body = table.concat(vim.fn.readfile(child), "\n")
        assert.is_truthy(body:find(tmpdir, 1, true),
            "a basename back-link is unresolvable for a parent that is not a "
            .. "timestamped chat file; got: " .. body:sub(1, 200))
        vim.fn.delete(tmpdir, "rf")
    end)

    it("BR-17: ToggleToolFolds refuses outside a parley buffer", function()
        local b = vim.api.nvim_create_buf(false, true)
        vim.api.nvim_set_current_buf(b)
        parley._parley_bufs[b] = nil
        local before = vim.wo.foldenable
        parley.cmd.ToggleToolFolds()
        assert.are.equal(before, vim.wo.foldenable,
            "the command flipped folds in a window that is not a parley buffer")
        vim.api.nvim_buf_delete(b, { force = true })
    end)
end)

-- #214 M3. `<M-S-CR>` performs the submission `<M-CR>` would perform, into a new
-- child chat, and leaves a 🌿: reference where `<M-CR>`'s output would have
-- appeared. Driven through the real keymap callback on a real chat buffer — the
-- transition, not the sub-step (round-11 lesson).
describe("branched submission (#214 M3)", function()
    local tmpdir, parent_path, parent_buf

    -- The transcript every case plans against. `answer.line_end` is the 📝: line.
    --  5 💬: first question   7..11 🤖: … 📝: sum      13 💬: second question
    local TRANSCRIPT = {
        "---", "topic: parent topic", "file: f", "---", "",
        "💬: first question", "",
        "🤖:[A]", "",
        "answer text here", "",
        "📝: the summary", "",
        "💬: second question",
    }

    local function open(lines)
        tmpdir = vim.fn.tempname()
        vim.fn.mkdir(tmpdir, "p")
        parent_path = tmpdir .. "/2026-09-06.10-00-00.000_parent.md"
        vim.fn.writefile(lines, parent_path)
        vim.cmd("edit " .. vim.fn.fnameescape(parent_path))
        parent_buf = vim.api.nvim_get_current_buf()
        parley.prep_chat(parent_buf, parent_path)
        return parent_buf
    end

    before_each(function()
        parley.setup({})
        open(TRANSCRIPT)
        parley.config.chat_dir = tmpdir
    end)

    after_each(function()
        parley._prepared_bufs[parent_buf] = nil
        vim.fn.delete(tmpdir, "rf")
    end)

    local function lines_now()
        return vim.api.nvim_buf_get_lines(parent_buf, 0, -1, false)
    end

    local function ref_line_index(lines)
        for i, l in ipairs(lines) do if l:match("^🌿:") then return i end end
    end

    local function child_path_from(ref)
        return tmpdir .. "/" .. ref:match("^🌿:%s*([^:]+):")
    end

    local function branch_here(line)
        vim.api.nvim_win_set_cursor(0, { line, 0 })
        parley._branch_inserters(parent_buf, false, true).n()
    end

    -- 1.2 — no markers: a PLACEHOLDER at the cursor. `<M-i>` reads as an
    -- insertion, so it must not delete an answer or move the line elsewhere.
    it("with no markers it inserts a placeholder at the cursor", function()
        branch_here(10)   -- inside the answer of exchange 1
        local l = lines_now()
        -- Its own block right under the cursor: a margin blank, then the
        -- reference (#214 BR-68 — this used to be a bare line with no margin).
        assert.are.equal("", l[11], "no blank line between the prose and the reference")
        assert.is_truthy(l[12] and l[12]:match("^🌿:"),
            "the reference did not land at the cursor: " .. vim.inspect(l))
    end)

    it("and the placeholder destroys nothing", function()
        branch_here(10)
        local after = table.concat(lines_now(), "\n")
        for _, keep in ipairs({ "💬: first question", "answer text here",
                               "📝: the summary", "💬: second question" }) do
            assert.is_truthy(after:find(keep, 1, true), "lost from the parent: " .. keep)
        end
    end)

    it("and its child is empty, ready to be typed into", function()
        branch_here(10)
        local l = lines_now()
        local child = child_path_from(l[ref_line_index(l)])
        local body = table.concat(vim.fn.readfile(child), "\n")
        assert.is_nil(body:find("first question", 1, true),
            "a bare <M-i> must not copy the question into the child")
    end)

    it("an answered question is never destroyed by a bare <M-i>", function()
        branch_here(6)    -- on 💬: first question, which HAS an answer
        local joined = table.concat(lines_now(), "\n")
        assert.is_truthy(joined:find("answer text here", 1, true),
            "a bare <M-i> deleted the answer — that is <M-CR>'s job, not this one")
    end)

    -- 1.3 — with markers: rearrange, and the reference still lands at the cursor.
    -- This REVISES the earlier end-of-answer rule. The cost is real and measured:
    -- `🌿:` sets the parser's `line_before_local` (the mechanism `🔒:` uses), so
    -- answer text after a mid-answer reference leaves the LLM context and the
    -- exchange model truncates that exchange. Recorded in ## Revisions; the
    -- operator's call is that a key named "insert" must insert where you are.
    it("the quotes case also lands at the cursor", function()
        open({
            "---", "topic: parent topic", "file: f", "---", "",
            "💬: first question", "",
            "🤖:[A]", "",
            "answer text here 🤖[what about this?]", "",
            "more answer text", "",
            "📝: the summary",
        })
        parley.config.chat_dir = tmpdir
        branch_here(12)   -- on "more answer text", below the marker

        local l = lines_now()
        -- cursor line, then the MARGIN blank, then the reference
        assert.are.equal("more answer text", l[12])
        assert.are.equal("", l[13], "no blank line between the text and the reference")
        assert.is_truthy(l[14] and l[14]:match("^🌿:"),
            "the reference was relocated instead of landing at the cursor: " .. vim.inspect(l))
        assert.are.equal("", l[15], "no blank line after the reference")
    end)


    -- #214 BR-58 (Critical). `plan.ref_after` is the PRE-strip cursor line, and
    -- `apply_text_edits` runs before the insert — so any marker whose removal
    -- changes the line count moves the reference. The only test for this path
    -- used an INLINE marker, whose delta is zero: one interleaving, reported as
    -- coverage. A STANDALONE `🤖[…]` is the ordinary form (`<M-q>` on a blank
    -- line produces it) and gather_edit_plan deletes its newline too.
    it("a standalone marker above the cursor does not move the reference", function()
        open({
            "---", "topic: parent topic", "file: f", "---", "",
            "💬: first question", "",
            "🤖:[A]", "",
            "answer text here", "",
            "🤖[what about this?]", "",
            "the cursor line", "",
            "📝: the summary",
        })
        parley.config.chat_dir = tmpdir
        branch_here(14)   -- "the cursor line"

        local l = lines_now()
        local i = ref_line_index(l)
        assert.is_truthy(i, "no reference was inserted")
        local anchor
        -- the line may be [bracketed] in place by mark_reference_span
        for n = 1, #l do if l[n]:find("the cursor line", 1, true) then anchor = n end end
        assert.is_truthy(anchor, "the cursor line vanished")
        assert.are.equal(anchor + 2, i,
            ("reference at %d, cursor line at %d — the strip moved it"):format(i, anchor))
        assert.are.equal("", l[i - 1], "no blank line before the reference")
        assert.are.equal("", l[i + 1], "no blank line after the reference")
    end)

    it("a multi-line marker above the cursor does not move it either", function()
        open({
            "---", "topic: parent topic", "file: f", "---", "",
            "💬: first question", "",
            "🤖:[A]", "",
            "answer text here", "",
            "🤖[line one", "line two]", "",
            "the cursor line", "",
            "📝: the summary",
        })
        parley.config.chat_dir = tmpdir
        branch_here(15)   -- "the cursor line"

        local l = lines_now()
        local i = ref_line_index(l)
        local anchor
        -- the line may be [bracketed] in place by mark_reference_span
        for n = 1, #l do if l[n]:find("the cursor line", 1, true) then anchor = n end end
        assert.are.equal(anchor + 2, i,
            ("reference at %d, cursor line at %d — a multi-line strip moved it"):format(
                i, anchor))
    end)

    -- BR-58 round 2: my fixtures all put the marker ABOVE the cursor, which
    -- samples one side of the delta axis. A marker BELOW the cursor moves no
    -- line above it, so an off-by-one in the anchor shows up only here.
    it("a standalone marker BELOW the cursor does not move the reference", function()
        open({
            "---", "topic: parent topic", "file: f", "---", "",
            "💬: first question", "",
            "🤖:[A]", "",
            "the cursor line", "",
            "🤖[what about this?]", "",
            "trailing answer text", "",
            "📝: the summary",
        })
        parley.config.chat_dir = tmpdir
        branch_here(10)   -- "the cursor line"

        local l = lines_now()
        local i = ref_line_index(l)
        assert.is_truthy(i, "no reference was inserted")
        local anchor
        -- the line may be [bracketed] in place by mark_reference_span
        for n = 1, #l do if l[n]:find("the cursor line", 1, true) then anchor = n end end
        assert.is_truthy(anchor, "the cursor line vanished")
        assert.is_true(i > anchor,
            ("reference at %d is ABOVE the cursor line at %d"):format(i, anchor))
        assert.are.equal(anchor + 2, i,
            ("reference at %d, cursor line at %d"):format(i, anchor))
    end)

    it("a marker above AND below the cursor still anchors correctly", function()
        open({
            "---", "topic: parent topic", "file: f", "---", "",
            "💬: first question", "",
            "🤖:[A]", "",
            "text 🤖[first] more", "",
            "the cursor line", "",
            "🤖[second]", "",
            "📝: the summary",
        })
        parley.config.chat_dir = tmpdir
        branch_here(12)   -- "the cursor line"

        local l = lines_now()
        local i = ref_line_index(l)
        local anchor
        -- the line may be [bracketed] in place by mark_reference_span
        for n = 1, #l do if l[n]:find("the cursor line", 1, true) then anchor = n end end
        assert.are.equal(anchor + 2, i,
            ("reference at %d, cursor line at %d"):format(i, anchor))
    end)

    -- BR-68: the margin claim was in three artifacts and held by neither path.
    -- The tests that "covered" it had a blank line already sitting where the
    -- margin would go, so they passed either way. Prose on BOTH sides is the
    -- fixture that can tell the difference.
    it("the reference gets a blank line on each side, with prose both sides", function()
        open({
            "---", "topic: parent topic", "file: f", "---", "",
            "💬: first question", "",
            "🤖:[A]", "",
            "line above 🤖[what about this?]",
            "line below with no blank between",
            "", "📝: the summary",
        })
        parley.config.chat_dir = tmpdir
        branch_here(10)

        local l = lines_now()
        local i = ref_line_index(l)
        assert.is_truthy(i, "no reference inserted")
        assert.are.equal("", l[i - 1], "no blank line before the reference")
        assert.are.equal("", l[i + 1], "no blank line after the reference")
    end)

    it("but does not double a blank that is already there", function()
        open({
            "---", "topic: parent topic", "file: f", "---", "",
            "💬: first question", "",
            "🤖:[A]", "",
            "line above 🤖[what about this?]", "",
            "line below", "", "📝: the summary",
        })
        parley.config.chat_dir = tmpdir
        branch_here(10)

        local l = lines_now()
        local i = ref_line_index(l)
        assert.are.equal("", l[i - 1])
        assert.is_truthy(l[i - 2] and l[i - 2]:match("%S"),
            "two blank lines stacked before the reference: " .. vim.inspect(l))
    end)

    it("pending <M-q> quotes go to the child and are stripped from the parent", function()
        open({
            "---", "topic: parent topic", "file: f", "---", "",
            "💬: first question", "",
            "🤖:[A]", "",
            "answer text here 🤖[what about this?]", "",
            "📝: the summary",
        })
        parley.config.chat_dir = tmpdir
        branch_here(10)

        local l = lines_now()
        local joined = table.concat(l, "\n")
        assert.is_nil(joined:find("🤖[", 1, true), "the marker was not stripped from the parent")
        assert.is_truthy(joined:find("answer text here", 1, true), "the answer must be preserved")

        local child = child_path_from(l[ref_line_index(l)])
        local body = table.concat(vim.fn.readfile(child), "\n")
        assert.is_truthy(body:find("what about this?", 1, true),
            "the gathered quote did not reach the child")
    end)

    it("the parent is saved, so the only pointer to the child is durable", function()
        branch_here(14)
        assert.is_false(vim.api.nvim_get_option_value("modified", { buf = parent_buf }),
            "parent left unsaved: a :q! here orphans the child (#214 BR-19)")
    end)
end)

-- #214 M3: generalising the chord must not delete the affordance M1 shipped.
-- With nothing to submit, <M-S-CR> still makes a side chat — it is never a no-op.
describe("branched submission falls back, never no-ops (#214 M3)", function()
    local tmpdir, parent_path, parent_buf

    after_each(function()
        parley._prepared_bufs[parent_buf] = nil
        vim.fn.delete(tmpdir, "rf")
    end)

    local function open(lines)
        parley.setup({})
        tmpdir = vim.fn.tempname()
        vim.fn.mkdir(tmpdir, "p")
        parent_path = tmpdir .. "/2026-09-06.10-00-00.000_parent.md"
        vim.fn.writefile(lines, parent_path)
        vim.cmd("edit " .. vim.fn.fnameescape(parent_path))
        parent_buf = vim.api.nvim_get_current_buf()
        parley.config.chat_dir = tmpdir
        parley.prep_chat(parent_buf, parent_path)
    end

    local function child_of()
        for _, f in ipairs(vim.fn.readdir(tmpdir)) do
            if f ~= vim.fn.fnamemodify(parent_path, ":t") then return tmpdir .. "/" .. f end
        end
    end

    it("a transcript with no exchanges still branches", function()
        open({ "---", "topic: t", "file: f", "---", "" })
        vim.api.nvim_win_set_cursor(0, { 5, 0 })
        parley._branch_inserters(parent_buf, false, true).n()
        assert.is_truthy(child_of(), "the chord did nothing at all")
    end)

    it("a cursor in the frontmatter still branches, and keeps the ? sentinel", function()
        open({ "---", "topic: t", "file: f", "---", "", "💬: q", "", "🤖:[A]", "", "a" })
        vim.api.nvim_win_set_cursor(0, { 1, 0 })
        parley._branch_inserters(parent_buf, false, true).n()

        local created = child_of()
        assert.is_truthy(created, "the chord did nothing at all")
        local topic
        for _, line in ipairs(vim.fn.readfile(created)) do
            topic = topic or line:match("^topic:%s*(.*)$")
        end
        assert.are.equal("?", topic, "the fallback must keep BR-1's sentinel")
    end)

    it("the fallback does not delete the answer it did not point at", function()
        open({ "---", "topic: t", "file: f", "---", "", "💬: q", "", "🤖:[A]", "", "answer body" })
        vim.api.nvim_win_set_cursor(0, { 1, 0 })
        parley._branch_inserters(parent_buf, false, true).n()

        local joined = table.concat(vim.api.nvim_buf_get_lines(parent_buf, 0, -1, false), "\n")
        assert.is_truthy(joined:find("answer body", 1, true),
            "a cursor outside every exchange must not destroy an answer")
    end)
end)

-- #214 M3 case 1: a visual selection anchors in place and the child is told what
-- to do with it. The topic names the subject (it becomes the slug); the
-- instruction is the seeded question. Before M3 both were `what is "X"`, and the
-- same phrase was rebuilt inline on the follow-a-dead-link path.
describe("visual branch seeds the child with an instruction (#214 M3)", function()
    local tmpdir, parent_path, parent_buf

    before_each(function()
        parley.setup({})
        tmpdir = vim.fn.tempname()
        vim.fn.mkdir(tmpdir, "p")
        parent_path = tmpdir .. "/2026-09-06.10-00-00.000_parent.md"
        vim.fn.writefile({ "---", "topic: t", "file: f", "---", "",
                           "💬: q", "", "🤖:[A]", "", "monad transformers are useful" }, parent_path)
        vim.cmd("edit " .. vim.fn.fnameescape(parent_path))
        parent_buf = vim.api.nvim_get_current_buf()
        parley.config.chat_dir = tmpdir
        parley.prep_chat(parent_buf, parent_path)
    end)

    after_each(function()
        parley._prepared_bufs[parent_buf] = nil
        vim.fn.delete(tmpdir, "rf")
    end)

    it("the child's topic is the selection and its question is the instruction", function()
        vim.api.nvim_win_set_cursor(0, { 10, 0 })
        vim.cmd("normal! v" .. string.rep("l", 17))   -- "monad transformers"
        parley._branch_inserters(parent_buf, false, true).v()

        local created
        for _, f in ipairs(vim.fn.readdir(tmpdir)) do
            if f ~= vim.fn.fnamemodify(parent_path, ":t") then created = tmpdir .. "/" .. f end
        end
        assert.is_truthy(created, "no child was created")
        local body = table.concat(vim.fn.readfile(created), "\n")
        assert.is_truthy(body:find("topic: monad transformers", 1, true),
            "the topic should name the subject, not a question about it")
        assert.is_truthy(body:find('tell me more about "monad transformers"', 1, true),
            "the child was not seeded with the instruction")
    end)

    it("the anchor stays in the parent, linking the child", function()
        vim.api.nvim_win_set_cursor(0, { 10, 0 })
        vim.cmd("normal! v" .. string.rep("l", 17))
        parley._branch_inserters(parent_buf, false, true).v()

        local joined = table.concat(vim.api.nvim_buf_get_lines(parent_buf, 0, -1, false), "\n")
        assert.is_truthy(joined:find("[🌿:monad transformers]", 1, true),
            "the selection was not wrapped as an inline anchor")
    end)
end)

-- #214 M3, ARCH-ORDER. A streaming response owns the parent's exchange model and
-- holds a chat lease anchored on the 🤖: line. Deleting the answer under it
-- (case 3b) or splicing a line into the exchange it is writing would fight that
-- lease, and the failure mode is a corrupted transcript rather than an error. The
-- transition is synchronous on the keypress, so declining is enough — there is
-- no queue to build.
describe("branched submission refuses under a pending response (#214 M3)", function()
    local tmpdir, parent_path, parent_buf
    local pending = require("parley.chat_pending")

    before_each(function()
        parley.setup({})
        tmpdir = vim.fn.tempname()
        vim.fn.mkdir(tmpdir, "p")
        parent_path = tmpdir .. "/2026-09-06.10-00-00.000_parent.md"
        vim.fn.writefile({ "---", "topic: t", "file: f", "---", "",
                           "💬: first question", "", "🤖:[A]", "", "answer body", "",
                           "📝: sum" }, parent_path)
        vim.cmd("edit " .. vim.fn.fnameescape(parent_path))
        parent_buf = vim.api.nvim_get_current_buf()
        parley.config.chat_dir = tmpdir
        parley.prep_chat(parent_buf, parent_path)
    end)

    after_each(function()
        parley._prepared_bufs[parent_buf] = nil
        vim.fn.delete(tmpdir, "rf")
    end)

    it("changes nothing while the buffer owns a pending response", function()
        local before = table.concat(vim.api.nvim_buf_get_lines(parent_buf, 0, -1, false), "\n")
        local orig = pending.identity
        pending.identity = function(b) return b == parent_buf and { agent = "A" } or nil end

        vim.api.nvim_win_set_cursor(0, { 6, 0 })
        parley._branch_inserters(parent_buf, false, true).n()

        pending.identity = orig
        local after = table.concat(vim.api.nvim_buf_get_lines(parent_buf, 0, -1, false), "\n")
        assert.are.equal(before, after,
            "the transcript was edited while a response was streaming into it")
        for _, f in ipairs(vim.fn.readdir(tmpdir)) do
            assert.are.equal(vim.fn.fnamemodify(parent_path, ":t"), f,
                "a child was created for a submission that was refused")
        end
    end)

    -- BR-69: the guard sat inside insert_planned, which only n/i reach — so
    -- VISUAL mode created a child and wrote the parent mid-stream while the
    -- README and the atlas said the chord declines. The enumeration is the
    -- dispatch table (n, i, v), which this file already says out loud.
    it("every dispatch mode refuses, not just the one that had the guard", function()
        local orig = pending.identity
        for _, mode in ipairs({ "n", "i", "v" }) do
            vim.fn.writefile({ "---", "topic: t", "file: f", "---", "",
                               "💬: first question", "", "🤖:[A]", "", "answer body", "",
                               "📝: sum" }, parent_path)
            vim.cmd("edit! " .. vim.fn.fnameescape(parent_path))
            parent_buf = vim.api.nvim_get_current_buf()
            parley.prep_chat(parent_buf, parent_path)
            local before = table.concat(vim.api.nvim_buf_get_lines(parent_buf, 0, -1, false), "\n")

            pending.identity = function(b) return b == parent_buf and { agent = "A" } or nil end
            vim.api.nvim_win_set_cursor(0, { 10, 0 })
            if mode == "v" then vim.cmd("normal! v$") end
            parley._branch_inserters(parent_buf, false, true)[mode]()
            pending.identity = orig

            local after = table.concat(vim.api.nvim_buf_get_lines(parent_buf, 0, -1, false), "\n")
            assert.are.equal(before, after, mode .. " edited the transcript mid-stream")
            for _, f in ipairs(vim.fn.readdir(tmpdir)) do
                assert.are.equal(vim.fn.fnamemodify(parent_path, ":t"), f,
                    mode .. " created a child for a refused branch")
            end
        end
    end)

    it("works again once the response is done", function()
        vim.api.nvim_win_set_cursor(0, { 6, 0 })
        parley._branch_inserters(parent_buf, false, true).n()
        local joined = table.concat(vim.api.nvim_buf_get_lines(parent_buf, 0, -1, false), "\n")
        assert.is_truthy(joined:find("🌿:", 1, true), "no branch after the response finished")
    end)
end)

-- #214 M3, found by the operator on first real use. `vim.fn.writefile` encodes a
-- `\n` INSIDE a list element as a NUL byte instead of rejecting it, so a
-- multi-line question — and the gathered <M-q> quote blocks are inherently
-- multi-line — wrote `> [abstractions]^@^@what's this` to disk.
--
-- The trap that let it ship: `readfile` turns those NULs back into newlines, so
-- every Lua-side round-trip looks perfect. The damage is only visible OUTSIDE
-- Vim, which is where the operator saw it. These tests read the raw bytes.
describe("a branched child is not NUL-corrupted (#214 M3)", function()
    local tmpdir, parent_buf, parent_path

    before_each(function()
        parley.setup({})
        tmpdir = vim.fn.tempname()
        vim.fn.mkdir(tmpdir, "p")
        parent_path = tmpdir .. "/2026-09-06.10-00-00.000_parent.md"
        vim.fn.writefile({ "---", "topic: t", "file: f", "---", "", "💬: q" }, parent_path)
        vim.cmd("edit " .. vim.fn.fnameescape(parent_path))
        parent_buf = vim.api.nvim_get_current_buf()
        parley.config.chat_dir = tmpdir
    end)

    after_each(function()
        parley._prepared_bufs[parent_buf] = nil
        vim.fn.delete(tmpdir, "rf")
    end)

    -- Raw bytes, not readfile: readfile cannot see this bug.
    local function raw(path)
        local fd = assert(io.open(path, "rb"))
        local body = fd:read("*a")
        fd:close()
        return body
    end

    it("a multi-line question writes real lines, not NUL bytes", function()
        local child = tmpdir .. "/child.md"
        parley.create_child_chat(child, "?", parent_buf,
            "> [abstractions]\n\nwhat's this\n\n> [rungs]\n\nwhat's that")

        local body = raw(child)
        assert.are.equal(0, select(2, body:gsub("%z", "")),
            "NUL bytes on disk — writefile was handed an element containing \\n")
        assert.is_truthy(body:find("\n> [rungs]\n", 1, true),
            "the second quote block is not on its own line")
    end)

    it("a multi-line question is shaped the way <M-CR> shapes a gathered turn", function()
        -- chat_respond inserts { "", user_prefix } then the block lines, so the
        -- prefix sits on its own line. The chord's promise is that the two agree.
        local child = tmpdir .. "/child.md"
        parley.create_child_chat(child, "?", parent_buf, "> [q]\n\nwhat's this")
        local lines = vim.fn.readfile(child)

        -- the FIRST bare prefix: the template ends with a trailing `💬:` prompt
        -- for the user to type into, and taking the last one finds that instead.
        local at
        for i, l in ipairs(lines) do
            if l == "💬:" and not at then at = i end
        end
        assert.is_truthy(at, "the user prefix is not on its own line for a multi-line turn")
        assert.are.equal("> [q]", lines[at + 1])
    end)

    it("does not leave a double blank above the template's own prompt", function()
        local child = tmpdir .. "/child4.md"
        parley.create_child_chat(child, "?", parent_buf, "> [q]\n\nwhat's this")
        local lines = vim.fn.readfile(child)
        for i = 1, #lines - 1 do
            assert.is_false(lines[i] == "" and lines[i + 1] == "",
                ("blank lines stacked at %d-%d: %s"):format(i, i + 1, vim.inspect(lines)))
        end
    end)

    it("a single-line question still sits inline after the prefix", function()
        local child = tmpdir .. "/child2.md"
        parley.create_child_chat(child, "?", parent_buf, "how does X work?")
        local joined = table.concat(vim.fn.readfile(child), "\n")
        assert.is_truthy(joined:find("💬: how does X work?", 1, true))
    end)

    -- A newline in the TOPIC must not corrupt either. Note this passes with the
    -- writer-side guard REMOVED — the template is split after the gsub, so this
    -- path never had the defect. Kept as a property worth holding, labelled so
    -- nobody reads it as coverage of `flatten_lines` (M2's lesson: a green test
    -- can be green for a reason that does not generalise).
    it("a newline in the topic does not corrupt the file either", function()
        local child = tmpdir .. "/child3.md"
        parley.create_child_chat(child, "line one\nline two", parent_buf, "q")
        local body = raw(child)
        assert.are.equal(0, select(2, body:gsub("%z", "")))
    end)

    it("the end-to-end quotes branch produces a clean child on disk", function()
        vim.fn.writefile({ "---", "topic: t", "file: f", "---", "",
                           "💬: first question", "", "🤖:[A]", "",
                           "some talk 🤖[what's this] and more 🤖[what's that]", "",
                           "📝: sum" }, parent_path)
        vim.cmd("edit! " .. vim.fn.fnameescape(parent_path))
        parent_buf = vim.api.nvim_get_current_buf()
        parley.prep_chat(parent_buf, parent_path)

        vim.api.nvim_win_set_cursor(0, { 10, 0 })
        parley._branch_inserters(parent_buf, false, true).n()

        local created
        for _, f in ipairs(vim.fn.readdir(tmpdir)) do
            if f ~= vim.fn.fnamemodify(parent_path, ":t") then created = tmpdir .. "/" .. f end
        end
        assert.is_truthy(created, "no child was created")
        local body = raw(created)
        assert.are.equal(0, select(2, body:gsub("%z", "")), "the branched child has NUL bytes")
        assert.is_truthy(body:find("what's this", 1, true), "the quote did not reach the child")
    end)
end)

-- The writer-side guard: no caller can reintroduce this, whatever it hands over.
describe("helper.flatten_lines (#214 M3)", function()
    local helper = require("parley.helper")

    it("splits an element containing newlines", function()
        assert.same({ "a", "b", "c" }, helper.flatten_lines({ "a\nb", "c" }))
    end)

    it("leaves clean input untouched", function()
        assert.same({ "a", "b" }, helper.flatten_lines({ "a", "b" }))
    end)

    it("preserves the blank lines a split produces", function()
        assert.same({ "a", "", "b" }, helper.flatten_lines({ "a\n\nb" }))
    end)
end)

-- #214 BR-63: the parent must not be mutated until the child exists. The write
-- was pcall-guarded and the create was not, so an unwritable chat_dir raised out
-- of the keymap callback with the markers already stripped and the reference
-- already inserted — a parent pointing at nothing, and the annotations gone.
describe("a failed child creation leaves the parent untouched (#214 BR-63)", function()
    local tmpdir, parent_path, parent_buf

    before_each(function()
        parley.setup({})
        tmpdir = vim.fn.tempname()
        vim.fn.mkdir(tmpdir, "p")
        parent_path = tmpdir .. "/2026-09-06.10-00-00.000_parent.md"
        vim.fn.writefile({ "---", "topic: t", "file: f", "---", "",
                           "💬: q", "", "🤖:[A]", "",
                           "answer 🤖[what about this?]", "", "📝: sum" }, parent_path)
        vim.cmd("edit " .. vim.fn.fnameescape(parent_path))
        parent_buf = vim.api.nvim_get_current_buf()
        parley.config.chat_dir = tmpdir
        parley.prep_chat(parent_buf, parent_path)
    end)

    after_each(function()
        parley._prepared_bufs[parent_buf] = nil
        vim.fn.delete(tmpdir, "rf")
    end)

    it("the markers survive and no reference is inserted", function()
        local before = table.concat(vim.api.nvim_buf_get_lines(parent_buf, 0, -1, false), "\n")

        local orig = parley.create_child_chat
        parley.create_child_chat = function() error("simulated: chat_dir unwritable") end
        local ok = pcall(function()
            vim.api.nvim_win_set_cursor(0, { 10, 0 })
            parley._branch_inserters(parent_buf, false, true).n()
        end)
        parley.create_child_chat = orig

        assert.is_true(ok, "the failure escaped the keymap callback")
        local after = table.concat(vim.api.nvim_buf_get_lines(parent_buf, 0, -1, false), "\n")
        assert.are.equal(before, after,
            "the parent was mutated for a child that was never created")
        assert.is_truthy(after:find("🤖[what about this?]", 1, true),
            "the user's annotation was stripped and then lost")
    end)
end)

-- #214 M3 review (Minor): one key, one landing. The placeholder path opened the
-- child in insert mode and the quotes path did not.
describe("both branch paths land the same way (#214 M3)", function()
    it("the child is opened in insert mode from either path", function()
        local src = table.concat(vim.fn.readfile("lua/parley/init.lua"), "\n")
        local planned = src:match("Branched submission into.-end%)")
        local plain = src:match("Created branch to new chat.-end%)")
        assert.is_truthy(planned and plain, "could not locate both branch landings")
        for name, body in pairs({ ["quotes path"] = planned, ["placeholder path"] = plain }) do
            assert.is_truthy(body:find("startinsert", 1, true),
                name .. " does not put the cursor in insert mode in the child")
        end
    end)
end)

-- #214 BR-75 end-to-end: the sequence the finding describes. <M-i> inserts a
-- reference mid-answer (where the chord puts one, by design), then <M-CR> on
-- that exchange resubmits — which deletes question..answer.line_end. Before the
-- fix that deleted the reference, orphaning a child that exists on disk.
describe("a resubmit does not orphan the child <M-i> just made (#214 BR-75)", function()
    local tmpdir, parent_path, parent_buf

    after_each(function()
        parley._prepared_bufs[parent_buf] = nil
        vim.fn.delete(tmpdir, "rf")
    end)

    it("the reference survives the delete_answer a resubmit performs", function()
        parley.setup({})
        tmpdir = vim.fn.tempname()
        vim.fn.mkdir(tmpdir, "p")
        parent_path = tmpdir .. "/2026-09-06.10-00-00.000_parent.md"
        vim.fn.writefile({ "---", "topic: t", "file: f", "---", "",
                           "💬: first question", "", "🤖:[A]", "",
                           "answer one 🤖[what about this?]", "",
                           "answer two", "", "📝: sum" }, parent_path)
        vim.cmd("edit " .. vim.fn.fnameescape(parent_path))
        parent_buf = vim.api.nvim_get_current_buf()
        parley.config.chat_dir = tmpdir
        parley.prep_chat(parent_buf, parent_path)

        vim.api.nvim_win_set_cursor(0, { 10, 0 })
        parley._branch_inserters(parent_buf, false, true).n()

        local l = vim.api.nvim_buf_get_lines(parent_buf, 0, -1, false)
        local ref
        for _, line in ipairs(l) do if line:match("^🌿:") then ref = line end end
        assert.is_truthy(ref, "no reference was inserted")
        local child = tmpdir .. "/" .. ref:match("^🌿:%s*([^:]+):")
        assert.are.equal(1, vim.fn.filereadable(child), "the child is not on disk")

        -- now the resubmit's own deletion, over that exchange
        local parsed = parley.parse_chat(l, parley.chat_parser.find_header_end(l))
        local ex = parsed.exchanges[1]
        require("parley.buffer_edit").delete_answer(
            parent_buf, ex.question.line_end, ex.answer.line_end - 1)

        local after = table.concat(vim.api.nvim_buf_get_lines(parent_buf, 0, -1, false), "\n")
        assert.is_truthy(after:find(ref, 1, true),
            "the resubmit deleted the only pointer to " .. vim.fn.fnamemodify(child, ":t"))
        assert.is_nil(after:find("answer two", 1, true), "the answer was not replaced")
    end)
end)
