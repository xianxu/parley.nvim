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
        assert.is_truthy(vim.api.nvim_buf_get_lines(b, 1, 2, false)[1]:find("🌿:", 1, true),
            "the reference line must still be inserted")
        assert.are.equal(2, vim.api.nvim_win_get_cursor(0)[1],
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

    it("an unanswered question is COPIED; the ref follows it", function()
        branch_here(14)   -- 💬: second question
        local l = lines_now()
        local i = ref_line_index(l)
        assert.is_truthy(i, "no branch reference was inserted")
        assert.are.equal("💬: second question", l[14], "the question must stay in the parent")
        assert.are.equal("", l[15], "one blank line between the question and the ref")
        assert.are.equal(16, i)
    end)

    it("and the child is seeded with that question", function()
        branch_here(14)
        local l = lines_now()
        local child = child_path_from(l[ref_line_index(l)])
        local body = table.concat(vim.fn.readfile(child), "\n")
        assert.is_truthy(body:find("second question", 1, true),
            "the child was not seeded with the question it branched from")
    end)

    it("an answered question loses its answer, and the ref takes its place", function()
        branch_here(6)    -- 💬: first question, which has an answer at 8..12
        local l = lines_now()
        assert.are.equal("💬: first question", l[6], "the question must stay")
        assert.is_nil(vim.tbl_filter(function(x) return x == "answer text here" end, l)[1],
            "the answer <M-CR> would have replaced is still there")
        assert.is_truthy(l[8]:match("^🌿:"), "the ref did not take the answer's place")
    end)

    -- This is the QUOTES case: the answer is preserved, so the exchange still
    -- ends with its 📝: and the ref must follow it. (The question case deletes
    -- the answer, so its ref follows the question — a different line, same rule:
    -- the ref goes where <M-CR>'s output would have gone.)
    it("the ref lands AFTER the summary, so the summary keeps its model block", function()
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
        local i = ref_line_index(l)
        local summary_at
        for n = 1, #l do if l[n]:match("^📝:") then summary_at = n end end
        assert.is_truthy(summary_at, "the summary vanished")
        assert.is_true(i > summary_at,
            "the ref was placed BEFORE the summary; measured, that drops the "
            .. "summary block out of the exchange model entirely")
    end)

    -- The model-level consequence, asserted directly rather than by proxy.
    it("and the exchange model still carries the summary block afterwards", function()
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
        local parsed = parley.parse_chat(l, parley.chat_parser.find_header_end(l))
        local model = require("parley.exchange_model").from_parsed_chat(parsed)
        local kinds = {}
        for _, blk in ipairs(model.exchanges[1].blocks) do kinds[#kinds + 1] = blk.kind end
        assert.is_truthy(vim.tbl_contains(kinds, "summary"),
            "summary block lost from the model: " .. table.concat(kinds, ", "))
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

    it("works again once the response is done", function()
        vim.api.nvim_win_set_cursor(0, { 6, 0 })
        parley._branch_inserters(parent_buf, false, true).n()
        local joined = table.concat(vim.api.nvim_buf_get_lines(parent_buf, 0, -1, false), "\n")
        assert.is_truthy(joined:find("🌿:", 1, true), "no branch after the response finished")
    end)
end)

-- #214 M3, Task 7. `branch_submit` re-derives the exchange-at-line rule that
-- `init.lua`'s `find_exchange_at_line` already implements — deliberately, so the
-- planner stays pure and loadable without the plugin. A duplicated rule is a
-- drift risk, so pin the two against each other BEHAVIOURALLY, line by line,
-- rather than against prose. (Deviation from the plan, which proposed grepping
-- the case names out of atlas/chat/drill_in.md: a prose grep would pass while
-- the two implementations disagreed, which is the only thing that matters here.)
describe("the planner agrees with <M-CR>'s exchange resolution (#214 M3)", function()
    local bs = require("parley.branch_submit")

    local TRANSCRIPTS = {
        {
            name = "answered, then an unanswered trailing question",
            lines = { "---", "topic: t", "file: f", "---", "",
                      "💬: first question", "", "🤖:[A]", "", "answer", "", "📝: sum", "",
                      "💬: second question", "", "" },
        },
        {
            name = "two answered exchanges",
            lines = { "---", "topic: t", "file: f", "---", "",
                      "💬: one", "", "🤖:[A]", "", "a1", "", "📝: s1", "",
                      "💬: two", "", "🤖:[A]", "", "a2", "", "📝: s2", "" },
        },
        {
            name = "a single unanswered question with trailing blanks",
            lines = { "---", "topic: t", "file: f", "---", "", "💬: only", "", "", "" },
        },
    }

    for _, t in ipairs(TRANSCRIPTS) do
        it("agrees on every line — " .. t.name, function()
            parley.setup({})
            local header_end = parley.chat_parser.find_header_end(t.lines)
            local parsed = parley.parse_chat(t.lines, header_end)

            local disagreements = {}
            for line = 1, #t.lines do
                local theirs = parley.find_exchange_at_line(parsed, line)
                local mine = bs._exchange_at(parsed, line)
                if theirs ~= mine then
                    disagreements[#disagreements + 1] = string.format(
                        "line %d (%q): <M-CR> says %s, planner says %s",
                        line, t.lines[line], tostring(theirs), tostring(mine))
                end
            end
            assert.same({}, disagreements)
        end)
    end
end)
