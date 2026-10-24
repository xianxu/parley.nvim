-- Integration test for review ported onto skill_invoke (#128 M3).
--
-- Tests review.run_via_invoke's marker pre-check + resubmit logic by stubbing
-- skill_invoke.invoke (the driver itself is covered by skill_invoke_spec). The
-- marker grammar: a `[]` (human) last section = ready; a `{}` (agent) last
-- section = pending (awaiting the human).

local review = require("parley.skills.review")
local skill_invoke = require("parley.skill_invoke")

describe("review.run_via_invoke", function()
    local buf, orig_invoke, invoke_calls

    before_each(function()
        require("parley.tools").register_builtins()
        invoke_calls = {}
        vim.cmd("messages clear")
        orig_invoke = skill_invoke.invoke
        skill_invoke.invoke = function(b, manifest, args, opts)
            table.insert(invoke_calls, { buf = b, manifest = manifest, args = args, opts = opts })
        end
        buf = vim.api.nvim_create_buf(false, true)
    end)

    after_each(function()
        skill_invoke.invoke = orig_invoke
        if vim.api.nvim_buf_is_valid(buf) then
            vim.api.nvim_buf_delete(buf, { force = true })
        end
    end)

    it("invokes skill_invoke with the review manifest when a ready marker exists", function()
        vim.api.nvim_buf_set_lines(buf, 0, -1, false, { "prose 🤖[please fix this]" })
        review.run_via_invoke(buf, {})
        assert.are.equal(1, #invoke_calls)
        assert.are.equal("review", invoke_calls[1].manifest.name)
        assert.is_true(invoke_calls[1].opts.manual)
        assert.is_function(invoke_calls[1].opts.on_done)
    end)

    for _, reason in ipairs({'no edit proposed', 'HTTP 400: tool_choice: unsupported for this model'}) do
        it('shows the failure reason in the bounded caption and history: '..reason, function()
            local old_notify, notices=vim.notify,{}
            vim.notify=function(msg)notices[#notices+1]=msg end
            vim.api.nvim_buf_set_lines(buf,0,-1,false,{'prose 🤖[fix]'})
            review.run_via_invoke(buf,{})
            local failure=reason:find('HTTP',1,true) and {http_status=400,
                body=vim.json.encode({error={message='tool_choice: unsupported for this model'}})} or nil
            invoke_calls[1].opts.on_done({ok=false,msg=reason,error=failure})
            vim.notify=old_notify
            assert.truthy(vim.fn.execute('messages'):find(reason,1,true))
            assert.truthy(notices[#notices]:find(reason:sub(1,18),1,true))
            assert.is_true(vim.fn.strdisplaywidth(notices[#notices])<=48)
        end)
    end

    it("ignores retired mode/instruction args instead of bypassing ready-marker admission", function()
        vim.api.nvim_buf_set_lines(buf, 0, -1, false, { "plain text, no markers" })
        review.run_via_invoke(buf, { modes = { "proofreading", "copy-editing" }, instruction = "x" })
        assert.equals(0, #invoke_calls)
    end)

    it("does NOT invoke when there are no markers", function()
        vim.api.nvim_buf_set_lines(buf, 0, -1, false, { "plain text, no markers" })
        review.run_via_invoke(buf, {})
        assert.are.equal(0, #invoke_calls)
    end)

    it("leaves pure chat items for Couch side answers without provider work", function()
        local old_notify, notices = vim.notify, {}
        vim.notify = function(msg) notices[#notices + 1] = msg end
        vim.api.nvim_buf_set_lines(buf, 0, -1, false, { "@@chat@@", "# Inbox", "1. Why retry?" })
        review.run_via_invoke(buf, { mode = "copy-editing" })
        vim.notify = old_notify
        assert.equals(0, #invoke_calls)
        assert.truthy(vim.fn.execute("messages"):find("chat items are answered in a side doc by Couch review; left unchanged", 1, true))
        assert.equals(1, #notices)
        assert.truthy(notices[1]:find(":messages", 1, true))
    end)

    it("allows ordinary robot asks in chat and supplies exact source identities", function()
        vim.api.nvim_buf_set_lines(buf, 0, -1, false, { "@@chat@@", "# Inbox", "1. prose 🤖[tighten this]" })
        review.run_via_invoke(buf, { mode = "copy-editing", instruction = "retired" })
        assert.equals(1, #invoke_calls)
        assert.same({ { line = 2, col = #"1. prose ", raw = "🤖[tighten this]" } }, invoke_calls[1].args.review_asks)
        assert.is_nil(invoke_calls[1].args.mode)
        assert.is_nil(invoke_calls[1].args.modes)
        assert.is_nil(invoke_calls[1].args.instruction)
    end)

    for _, case in ipairs(require("tests.helpers.collaboration_declarations")) do
        it("keeps ready asks eligible across legacy/header forms in " .. case.name, function()
            local document = { "---" }
            for _, line in ipairs(case.header) do document[#document + 1] = line end
            if case.closed ~= false then document[#document + 1] = "---" end
            document[#document + 1] = "secret 🤖[tighten this]"
            vim.api.nvim_buf_set_lines(buf, 0, -1, false, document)
            local old_notify, notices = vim.notify, {}
            vim.notify = function(msg) notices[#notices + 1] = msg end
            review.run_via_invoke(buf, {})
            vim.notify = old_notify
            assert.equals(1, #invoke_calls)
            if case.closed ~= false then
                assert.is_true(#notices > 0, "closed legacy metadata must be reported")
            else
                -- Without a closing fence there is no frontmatter block.
                assert.same({}, notices)
            end
            assert.same(document, vim.api.nvim_buf_get_lines(buf, 0, -1, false))
            assert.same("🤖[tighten this]", invoke_calls[1].args.review_asks[1].raw)
        end)
    end

    it("reports unknown retired routing and keeps the robot ask eligible", function()
        local old_notify, notices = vim.notify, {}
        vim.notify = function(msg) notices[#notices + 1] = msg end
        vim.api.nvim_buf_set_lines(buf, 0, -1, false, { "---", "collaboration-mode: unknown", "---", "🤖[tighten this]" })
        review.run_via_invoke(buf, {})
        vim.notify = old_notify
        assert.equals(1, #invoke_calls)
        assert.truthy(vim.fn.execute("messages"):find("retired and ignored", 1, true))
    end)

    it("a deferred question is a no-op without journal/projection writes or resubmission", function()
        local journal = require("parley.skills.review.journal")
        local projection = require("parley.skills.review.projection")
        local old_notify, old_append, old_record = vim.notify, journal.append, projection.record
        local old_empty, old_watch = projection.record_empty_for, projection.ensure_watch
        local notices, journals, records = {}, 0, 0
        vim.notify = function(msg) notices[#notices + 1] = msg end
        journal.append = function() journals = journals + 1; return true end
        projection.record = function() records = records + 1 end
        projection.record_empty_for = function() records = records + 1 end
        projection.ensure_watch = function() records = records + 1 end
        local ok, err = pcall(function()
            vim.api.nvim_buf_set_name(buf, vim.fn.tempname() .. ".md")
            vim.api.nvim_buf_set_lines(buf, 0, -1, false, { "🤖[why?]" })
            review.run_via_invoke(buf, {})
            invoke_calls[1].opts.on_done({ ok = true, review = { deferred = 1, noop = true },
                original = "🤖[why?]", new_content = "invented" })
            assert.equals(1, #invoke_calls)
            assert.equals(0, journals)
            assert.equals(0, records)
            assert.same({ "🤖[why?]" }, vim.api.nvim_buf_get_lines(buf, 0, -1, false))
            assert.equals(1, #notices)
            assert.truthy(notices[1]:find(":messages", 1, true))
            local history = vim.fn.execute("messages")
            local full = "questions are answered in a side doc by Couch review; left unchanged"
            local first, last = history:find(full, 1, true)
            assert.is_truthy(first)
            assert.is_nil(history:find(full, last + 1, true), "exact question notice is stored once")
        end)
        vim.notify, journal.append, projection.record = old_notify, old_append, old_record
        projection.record_empty_for, projection.ensure_watch = old_empty, old_watch
        assert.is_true(ok, tostring(err))
    end)

    it("does not resubmit a preserved question after a mixed command made progress", function()
        vim.api.nvim_buf_set_lines(buf, 0, -1, false, { "🤖[tighten]", "🤖[why?]" })
        review.run_via_invoke(buf, {})
        vim.api.nvim_buf_set_lines(buf, 0, -1, false, { "tightened", "🤖[why?]" })
        local notify, notices = vim.notify, {}
        vim.notify = function(msg) notices[#notices + 1] = msg end
        invoke_calls[1].opts.on_done({ ok = true, review = { deferred = 1, noop = false } })
        vim.notify = notify
        assert.equals(1, #invoke_calls)
        assert.same({ "tightened", "🤖[why?]" }, vim.api.nvim_buf_get_lines(buf, 0, -1, false))
        assert.equals(1, #notices)
        assert.truthy(notices[1]:find(":messages", 1, true))
        local history = vim.fn.execute("messages")
        local full = "questions are answered in a side doc by Couch review; left unchanged"
        local first, last = history:find(full, 1, true)
        assert.is_truthy(first)
        assert.is_nil(history:find(full, last + 1, true), "exact question notice is stored once")
    end)

    it("does NOT invoke when the last marker is a pending agent question", function()
        vim.api.nvim_buf_set_lines(buf, 0, -1, false, { "prose 🤖{agent asks a question}" })
        review.run_via_invoke(buf, {})
        assert.are.equal(0, #invoke_calls)
    end)

    it("resubmits when the marker set shrank and a ready marker remains (bounded at 3)", function()
        vim.api.nvim_buf_set_lines(buf, 0, -1, false, { "🤖[a]", "🤖[b]" }) -- 2 ready markers
        review.run_via_invoke(buf, {})
        assert.are.equal(1, #invoke_calls)
        -- the apply removed one marker; one ready marker remains → progress → re-invoke
        vim.api.nvim_buf_set_lines(buf, 0, -1, false, { "🤖[b]" })
        invoke_calls[1].opts.on_done({ ok = true })
        assert.are.equal(2, #invoke_calls)
    end)

    it("does NOT resubmit when the marker set did not shrink (no-progress storm guard)", function()
        vim.api.nvim_buf_set_lines(buf, 0, -1, false, { "🤖[fix]" })
        review.run_via_invoke(buf, {})
        -- buffer unchanged (model made no/empty/wrong edit) → no progress → stop
        invoke_calls[1].opts.on_done({ ok = true })
        assert.are.equal(1, #invoke_calls)
    end)

    it("does NOT resubmit when the remaining marker is a pending question", function()
        vim.api.nvim_buf_set_lines(buf, 0, -1, false, { "🤖[a]", "🤖[b]" })
        review.run_via_invoke(buf, {})
        -- shrank to one marker, but it's now a pending agent question
        vim.api.nvim_buf_set_lines(buf, 0, -1, false, { "🤖[b]{a question}" })
        invoke_calls[1].opts.on_done({ ok = true })
        assert.are.equal(1, #invoke_calls)
    end)

    it("does NOT resubmit on a failed exchange", function()
        vim.api.nvim_buf_set_lines(buf, 0, -1, false, { "🤖[fix]" })
        review.run_via_invoke(buf, {})
        invoke_calls[1].opts.on_done({ ok = false, msg = "tool error" })
        assert.are.equal(1, #invoke_calls)
    end)

    it("retired single-mode args do not create markerless provider work", function()
        vim.api.nvim_buf_set_lines(buf, 0, -1, false, { "plain prose, no markers" })
        review.run_via_invoke(buf, { mode = "developmental" })
        assert.equals(0, #invoke_calls)
    end)

    it("invokes (processes ready) even when an unaddressed pending {} marker is present", function()
        -- Was blocked pre-#133 (#pending > 0 → return); now the ready [] is processed.
        vim.api.nvim_buf_set_lines(buf, 0, -1, false, { "🤖[fix me]", "prose 🤖{agent asked earlier}" })
        review.run_via_invoke(buf, {})
        assert.are.equal(1, #invoke_calls)
    end)

    it("leaves proposal-only text without provider work (no ready asks)", function()
        -- A bare strike (🤖~del~) is a proposal, not agent-actionable: no mode +
        -- no ready marker → nothing to do, no LLM call (M2 review-finding pin).
        vim.api.nvim_buf_set_lines(buf, 0, -1, false, { "prose 🤖~delete this~" })
        review.run_via_invoke(buf, {})
        assert.are.equal(0, #invoke_calls)
    end)

    it("records projection states (base empty + post) so undo/redo re-render style (#133 M5)", function()
        local projection = require("parley.skills.review.projection")
        local doc = vim.fn.tempname() .. ".md"
        vim.fn.writefile({ "original line 🤖[tighten this]" }, doc)
        vim.cmd("edit " .. vim.fn.fnameescape(doc))
        local b = vim.api.nvim_get_current_buf()
        projection.reset(b)
        review.run_via_invoke(b, { mode = "developmental" })
        -- simulate the round: apply text + draw a decoration, then fire on_done
        vim.api.nvim_buf_set_lines(b, 0, -1, false, { "edited line" })
        require("parley.skill_render").attach_diagnostics(b, { { pos = 1, explain = "why" } }, "edited line")
        invoke_calls[#invoke_calls].opts.on_done({
            ok = true, original = "original line 🤖[tighten this]", new_content = "edited line",
            decorations = { { kind = "change", explain = "why" } },
        })
        -- undo to base → style cleared (base recorded empty)
        vim.api.nvim_buf_set_lines(b, 0, -1, false, { "original line 🤖[tighten this]" })
        projection.project(b)
        assert.are.equal(0, #vim.diagnostic.get(b))
        -- redo to the round state → style restored
        vim.api.nvim_buf_set_lines(b, 0, -1, false, { "edited line" })
        projection.project(b)
        assert.is_true(#vim.diagnostic.get(b) >= 1)
        projection.reset(b)
        vim.fn.delete(doc)
        vim.fn.delete(require("parley.skills.review.journal").sidecar_path(doc))
        vim.api.nvim_buf_delete(b, { force = true })
    end)

    it("journals the round to a sidecar beside the doc (#133 M3)", function()
        local doc = vim.fn.tempname() .. ".md"
        vim.fn.writefile({ "original line 🤖[tighten this]" }, doc)
        vim.cmd("edit " .. vim.fn.fnameescape(doc))
        local b = vim.api.nvim_get_current_buf()
        review.run_via_invoke(b, { mode = "developmental" }) -- retired args do not override the marker ask
        assert.are.equal(1, #invoke_calls)
        invoke_calls[#invoke_calls].opts.on_done({
            ok = true,
            original = "original line 🤖[tighten this]",
            new_content = "edited line",
            decorations = { { kind = "change", explain = "tightened the wording" } },
        })
        local J = require("parley.skills.review.journal")
        local p = J.read(doc)
        assert.are.equal("original line 🤖[tighten this]", p.base)
        assert.are.equal(1, #p.entries)
        assert.are.equal("none", p.entries[1].mode)
        assert.is_truthy(p.entries[1].diff:find("edited", 1, true))
        vim.fn.delete(doc)
        vim.fn.delete(J.sidecar_path(doc))
        vim.api.nvim_buf_delete(b, { force = true })
    end)
end)

describe("review journal sidecar exclusion (#133 M3)", function()
    local function named(name)
        local b = vim.api.nvim_create_buf(false, true)
        vim.api.nvim_buf_set_name(b, name)
        return b
    end
    it("is_journal_sidecar matches only *.parley-journal.md", function()
        assert.is_true(require("parley.skills.review").is_journal_sidecar(named("/tmp/doc.md.parley-journal.md")))
        assert.is_false(require("parley.skills.review").is_journal_sidecar(named("/tmp/doc.md")))
        assert.is_false(require("parley.skills.review").is_journal_sidecar(named("/tmp/parley-journal.txt")))
    end)
    it("setup_keymaps no-ops on a sidecar buffer (no review map bound)", function()
        local b = named("/tmp/x.parley-journal.md")
        require("parley").setup_markdown_keymaps(b)  -- #214 C1: the registry installs review keys now
        for _, m in ipairs(vim.api.nvim_buf_get_keymap(b, "n")) do
            assert.is_nil(m.desc and m.desc:find("Parley review", 1, true))
        end
    end)
end)

describe("review.should_resubmit (pure)", function()
    it("resubmits while ready work remains, shrank, and under the bound", function()
        assert.is_true(review.should_resubmit(2, 1, 0)) -- 2→1 ready, round 0
    end)
    it("stops when no ready asks remain (only pending findings)", function()
        assert.is_false(review.should_resubmit(0, 0, 0))
        assert.is_false(review.should_resubmit(2, 0, 0))
    end)
    it("stops when the ready count did not shrink (no progress)", function()
        assert.is_false(review.should_resubmit(1, 1, 0))
        assert.is_false(review.should_resubmit(1, 2, 0)) -- grew (e.g. inserted ready) → stop
    end)
    it("stops at the resubmit bound (3)", function()
        assert.is_true(review.should_resubmit(3, 2, 2))
        assert.is_false(review.should_resubmit(3, 2, 3))
    end)
end)
