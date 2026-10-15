-- #332: pane Alt+Return saves, registers and submits unchanged Markdown.
-- Outside a pane the existing instruction-driven review stays local.
local rs = require("parley.review_send")
local review = require("parley.skills.review")
local uv = vim.uv or vim.loop

describe("review_send", function()
    local root, file, argv_file, log_file, saved, buf, invoked
    local p = require("parley")

    -- ariadne:2 is bound to the thread s2/t2, this editor's (set per spec).
    local function slots(list)
        return vim.json.encode({ Code = "ok", Actors = list or {
            { Binding = { Slot = "ops:0", Scope = "s0", Tag = "t0" } },
            { Binding = { Slot = "ariadne:2", Scope = "s2", Tag = "t2" } },
        } })
    end

    local function open(lines)
        vim.fn.writefile(lines, file)
        vim.cmd("edit " .. vim.fn.fnameescape(file))
        buf = vim.api.nvim_get_current_buf()
        p.setup_markdown_keymaps(buf)
    end

    local function alt_return()
        local km = vim.api.nvim_buf_call(buf, function() return vim.fn.maparg("<M-CR>", "n", false, true) end)
        assert.equals(1, km.buffer)
        km.callback()
    end

    local function exists(path) return uv.fs_stat(path) ~= nil end
    local function sent() return exists(log_file) and vim.fn.readfile(log_file) or {} end
    local function last() return table.concat(vim.fn.readfile(log_file .. ".last"), "\n") end
    local function lines() return vim.api.nvim_buf_get_lines(buf, 0, -1, false) end
    local function has(text, needle) return text:find(needle, 1, true) ~= nil end

    local function set_line(n, text)
        vim.api.nvim_buf_set_lines(buf, n - 1, n, false, { text })
    end

    before_each(function()
        root = vim.fn.resolve(vim.fn.tempname())
        vim.fn.mkdir(root, "p")
        file = root .. "/notes.md"
        argv_file = root .. "/argv"
        log_file = root .. "/sent"
        require("tests.helpers.fake_couch").write(root, log_file, argv_file)
        saved = {
            path = vim.env.PATH, scope = vim.env.COUCH_THREAD_SCOPE, tag = vim.env.COUCH_THREAD_TAG,
            input = vim.ui.input, invoke = review.run_via_invoke, notify = vim.notify,
            registry = vim.env.FAKE_COUCH_REGISTRY, registry_mode = vim.env.FAKE_COUCH_REGISTRY_MODE,
            actors = vim.env.FAKE_COUCH_ACTORS, exit = vim.env.FAKE_COUCH_EXIT,
            isolated = vim.env.COUCH_ISOLATED_ROOT, state_dir = p.config.state_dir,
        }
        vim.env.PATH = root .. "/bin:" .. vim.env.PATH
        vim.env.COUCH_THREAD_SCOPE, vim.env.COUCH_THREAD_TAG = "s2", "t2"
        vim.env.FAKE_COUCH_ACTORS = slots()
        vim.env.FAKE_COUCH_EXIT = "0"
        vim.env.FAKE_COUCH_REGISTRY = root .. "/registry.json"
        vim.env.FAKE_COUCH_REGISTRY_MODE = nil
        vim.env.COUCH_ISOLATED_ROOT = root
        p.config.state_dir = root .. "/state"
        p.config.review_shortcut_next = { modes = { "n", "i" }, shortcut = "<M-CR>" }
        invoked = nil
        review.run_via_invoke = function(b, args) invoked = { buf = b, args = args } end
    end)

    after_each(function()
        if buf and vim.api.nvim_buf_is_valid(buf) then
            vim.api.nvim_buf_delete(buf, { force = true })
        end
        require("parley.agentic_document").detach(buf)
        vim.env.FAKE_COUCH_REGISTRY, vim.env.FAKE_COUCH_REGISTRY_MODE = saved.registry, saved.registry_mode
        vim.env.FAKE_COUCH_ACTORS, vim.env.FAKE_COUCH_EXIT = saved.actors, saved.exit
        vim.env.COUCH_ISOLATED_ROOT, p.config.state_dir = saved.isolated, saved.state_dir
        vim.env.PATH = saved.path
        vim.env.COUCH_THREAD_SCOPE, vim.env.COUCH_THREAD_TAG = saved.scope, saved.tag
        vim.ui.input, review.run_via_invoke, vim.notify = saved.input, saved.invoke, saved.notify
        vim.fn.delete(root, "rf")
    end)

    local doc = { "---", 'process-instruction: "[copy-edit] keep the voice"', "---", "", "- a" }

    local function delivered(count)
        assert.is_true(vim.wait(5000, function()
            local status = require("parley.agentic_document").status(buf)
            return #sent() == count and status and status.phase == "registered" and not status.operation
        end))
    end

    it("saves then registers before one submitted notification without injecting instructions", function()
        open(doc)
        set_line(5, "- a, edited")
        alt_return()
        delivered(1)
        assert.equals("ariadne:2|submitted: " .. file, sent()[1])
        assert.equals("submitted: " .. file, last())
        assert.same(lines(), vim.fn.readfile(file))
        assert.equals("- a, edited", vim.fn.readfile(file)[5])
        assert.is_false(vim.bo[buf].modified)
        local registered = vim.json.decode(table.concat(vim.fn.readfile(root .. "/registry.json"), "\n"))
        assert.equals("ariadne:2", registered.paths[file].Owner)
        assert.is_nil(invoked)
    end)

    it("failed delivery retains registration and requires explicit resubmit", function()
        open(doc)
        alt_return()
        delivered(1)
        local original = require("parley.agentic_document").identity(buf).ID
        set_line(5, "- b")
        vim.env.FAKE_COUCH_EXIT = "1"
        alt_return()
        delivered(2)
        assert.equals(original, require("parley.agentic_document").identity(buf).ID)
        vim.env.FAKE_COUCH_EXIT = "0"
        set_line(5, "- c")
        alt_return()
        delivered(3)
        assert.equals("submitted: " .. file, last())
        assert.equals(original, require("parley.agentic_document").identity(buf).ID)
    end)

    it("an explicit couch-owner overrides the pane while business owner does not route", function()
        open({ "---", "owner: accounting", "couch-owner: ops:0", "---", "body" })
        alt_return()
        delivered(1)
        assert.equals("ops:0|submitted: " .. file, sent()[1])
        assert.equals("ops:0", require("parley.agentic_document").identity(buf).Owner)
    end)

    it("ordinary owner metadata leaves routing to the current pane", function()
        open({ "---", "owner: accounting", "---", "body" })
        alt_return()
        delivered(1)
        assert.equals("ariadne:2|submitted: " .. file, sent()[1])
    end)

    it("first Alt+Return during pending lookup submits once after admission", function()
        vim.env.FAKE_COUCH_REGISTRY_MODE = "delay"
        open({ "# notes" })
        alt_return()
        alt_return()
        delivered(1)
        assert.equals("ariadne:2|submitted: " .. file, sent()[1])
        assert.same({ "# notes" }, lines())
    end)

    it("journal Markdown uses the pane mapping without inserting review instructions", function()
        file = root .. "/journal.md"
        open({ "---", "type: journal", "---", "# private notes" })
        alt_return()
        delivered(1)
        assert.equals("ariadne:2|submitted: " .. file, sent()[1])
        assert.same({ "---", "type: journal", "---", "# private notes" }, lines())
    end)

    it("outside pair: no couch call; the review round runs here with the instruction", function()
        vim.env.COUCH_THREAD_SCOPE, vim.env.COUCH_THREAD_TAG = nil, nil
        open(doc)
        alt_return()
        assert.is_true(vim.wait(1000, function() return invoked ~= nil end))
        assert.equals(buf, invoked.buf)
        assert.same({ modes = { "copy-editing" }, instruction = "keep the voice" }, invoked.args)
        assert.same({}, sent())
    end)

    it("a slot couch cannot resolve: nothing sent, no review round", function()
        vim.env.FAKE_COUCH_ACTORS = slots({})
        local errors = {}
        vim.notify = function(msg) errors[#errors + 1] = msg end
        open(doc)
        alt_return()
        local function told()
            for _, e in ipairs(errors) do
                if has(e, "cannot resolve this pane's agent") then return true end
            end
            return false
        end
        assert.is_true(vim.wait(2000, told))
        assert.same({}, sent())
        assert.is_nil(invoked)
    end)

    it("an unknown stock prompt is refused outside a pane, naming the known ones", function()
        vim.env.COUCH_THREAD_SCOPE, vim.env.COUCH_THREAD_TAG = nil, nil
        local errors = {}
        vim.notify = function(msg) errors[#errors + 1] = msg end
        open({ "---", "process-instruction: [nope] x", "---" })
        alt_return()
        assert.is_true(has(table.concat(errors, "\n"), "[nope] is not a stock prompt"))
        vim.wait(100)
        assert.same({}, sent())
    end)

    it("no process-instruction submits unchanged Markdown without prompting", function()
        vim.ui.input = function() error("pane submission must not prompt") end
        open({ "# notes", "- a" })
        alt_return()
        delivered(1)
        assert.same({ "# notes", "- a" }, lines())
        assert.equals("submitted: " .. file, last())
    end)

    it("existing frontmatter remains unchanged on pane submission", function()
        vim.ui.input = function() error("pane submission must not prompt") end
        open({ "---", "title: t", "---", "body" })
        alt_return()
        delivered(1)
        assert.same({ "---", "title: t", "---", "body" }, lines())
    end)

    it("a cancelled outside-pane prompt changes nothing and sends nothing", function()
        vim.env.COUCH_THREAD_SCOPE, vim.env.COUCH_THREAD_TAG = nil, nil
        vim.ui.input = function(_, cb) cb(nil) end
        open({ "# notes" })
        alt_return()
        vim.wait(100)
        assert.same({ "# notes" }, lines())
        assert.same({}, sent())
    end)

    it("[ in the value completes the stock prompt names; the value ends up quoted", function()
        vim.env.COUCH_THREAD_SCOPE, vim.env.COUCH_THREAD_TAG = nil, nil
        open({ "---", "process-instruction: ", "---", "body" })
        vim.api.nvim_win_set_cursor(0, { 2, 0 })
        -- Typed keys fire TextChangedI from the main loop once typeahead is
        -- empty, which a feedkeys run never reaches mid-sequence: <F3> runs
        -- the installed handler in real insert mode instead.
        assert.equals(1, #vim.api.nvim_get_autocmds({ event = "TextChangedI", buffer = buf, group = "ParleyReviewSend" .. buf }))
        local offered
        vim.keymap.set("i", "<F3>", function() rs.on_text_changed(buf) end, { buffer = buf })
        vim.keymap.set("i", "<F2>", function()
            offered = vim.fn.complete_info({ "items" }).items
            return ""
        end, { buffer = buf, expr = true })
        vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes("A[<F3><F2><C-y> keep<Esc>", true, false, true), "tx", false)
        assert.is_not_nil(offered)
        local words = vim.tbl_map(function(i) return i.word end, offered)
        assert.truthy(vim.tbl_contains(words, "copy-editing]"))
        assert.truthy(vim.tbl_contains(words, "free-form]"))
        assert.is_true(vim.wait(1000, function() return lines()[2]:sub(1, 23) == 'process-instruction: "[' end))
        assert.equals('process-instruction: "[' .. words[1] .. ' keep"', lines()[2])
    end)
end)

describe("review_send pure helpers", function()
    it("completion starts only inside the value's [name] run", function()
        assert.equals(23, rs.completion_start("process-instruction: ["))
        assert.equals(24, rs.completion_start('process-instruction: "['))
        assert.equals(29, rs.completion_start("process-instruction: [a][b]["))
        assert.is_nil(rs.completion_start("process-instruction: x ["))
        assert.is_nil(rs.completion_start("title: ["))
    end)

    it("a quoted instruction may carry a trailing comment; a plain one keeps its #", function()
        assert.equals("[copy-edit] y", rs.instruction_value({ "---", 'process-instruction: "[copy-edit] y" # note', "---" }))
        assert.equals("fix #3 please", rs.instruction_value({ "---", "process-instruction: fix #3 please", "---" }))
        assert.is_nil(rs.instruction_value({ "---", "title: t", "---" }))
    end)

    it("requote closes a quote the operator opened", function()
        local line, col = rs.requote('process-instruction: "[copy-editing] k', 37)
        assert.equals('process-instruction: "[copy-editing] k"', line)
        assert.equals(37, col)
    end)

    it("requote keeps the cursor on the same text", function()
        local line, col = rs.requote("process-instruction: [copy-editing] k", 36)
        assert.equals('process-instruction: "[copy-editing] k"', line)
        assert.equals(37, col)
        assert.is_nil(rs.requote('process-instruction: "[a] b"', 5))
        assert.is_nil(rs.requote("process-instruction: plain", 5))
    end)

    it("the diff is capped", function()
        local old, new = {}, {}
        for i = 1, 300 do old[i], new[i] = "a" .. i, "b" .. i end
        local d = rs.diff(table.concat(old, "\n"), table.concat(new, "\n"))
        local n = #vim.split(d, "\n")
        assert.equals(rs.DIFF_MAX_LINES + 1, n)
        assert.truthy(d:find("more diff lines; read the file", 1, true))
        assert.is_nil(rs.diff(nil, "x"))
    end)
end)
