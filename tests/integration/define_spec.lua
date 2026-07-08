-- Integration tests for the inline term-definition feature (#161).
-- See workshop/issues/000161-inline-term-definition.md and its plan.

-- Bootstrap parley so M.config is populated (parse_chat reads it).
require("parley").setup({
    chat_dir = vim.fn.tempname() .. "-define-chat",
    providers = {},
    api_keys = {},
})

-- SSE builder + an emit_definition tool-call response (mirrors skill_invoke_spec).
local function sse(events)
    local out = {}
    for _, ev in ipairs(events) do
        table.insert(out, "event: " .. (ev.type or "unknown"))
        table.insert(out, "data: " .. vim.json.encode(ev))
        table.insert(out, "")
    end
    return table.concat(out, "\n")
end

local function emit_definition_sse(term, definition)
    return sse({
        { type = "content_block_start", index = 0,
          content_block = { type = "tool_use", id = "d1", name = "emit_definition", input = {} } },
        { type = "content_block_delta", index = 0,
          delta = { type = "input_json_delta", partial_json = vim.json.encode({ term = term, definition = definition }) } },
        { type = "content_block_stop", index = 0 },
        { type = "message_stop" },
    })
end

describe("emit_definition tool", function()
    before_each(function()
        require("parley.tools").register_builtins()
    end)

    it("is registered and selectable without raising", function()
        local reg = require("parley.tools")
        local ok, sel = pcall(function()
            return reg.select({ "emit_definition" })
        end)
        assert.is_true(ok)
        assert.is_not_nil(sel)
    end)

    it("does not advertise pager offset/limit params", function()
        local def = require("parley.tools.builtin.emit_definition")
        local props = def.input_schema.properties
        assert.is_nil(props.offset)
        assert.is_nil(props.limit)
        assert.is_not_nil(props.term)
        assert.is_not_nil(props.definition)
    end)
end)

describe("define skill", function()
    it("is auto-discovered by the registry", function()
        -- current() returns a registry object { get, names, all }, not a list.
        local reg = require("parley.skill_registry").current()
        local names = {}
        for _, n in ipairs(reg.names()) do
            names[n] = true
        end
        assert.is_true(names["define"] == true)
    end)

    it("folds the phrase into the system prompt and forces no tool", function()
        local skill = require("parley.skills.define")
        local body = skill.source({ args = { phrase = "ASIN" }, repo_root = "." })
        assert.is_true(body:find("ASIN", 1, true) ~= nil)
        assert.is_nil(skill.force_tool)
        assert.same({ "emit_definition" }, skill.tools)
    end)
end)

describe("define: skill_invoke read-only seams (#161)", function()
    local skill_invoke = require("parley.skill_invoke")
    local parley = require("parley")
    local tasker = require("parley.tasker")
    local assembly = require("parley.skill_assembly")

    local tmpdir, path, buf, orig_query, orig_resolve, captured_payload, done_result

    before_each(function()
        require("parley.tools").register_builtins()
        tmpdir = vim.fn.tempname() .. "-def"
        vim.fn.mkdir(tmpdir, "p")
        path = tmpdir .. "/chat.md"
        vim.fn.writefile({ "on disk line 1", "on disk line 2" }, path)
        vim.cmd("edit " .. vim.fn.fnameescape(path))
        buf = vim.api.nvim_get_current_buf()
        captured_payload, done_result = nil, nil

        orig_resolve = assembly.resolve_agent
        assembly.resolve_agent = function()
            return { model = "m", provider = "anthropic" }
        end
        orig_query = parley.dispatcher.query
        parley.dispatcher.query = function(_b, _p, payload, _h, on_exit)
            captured_payload = payload
            tasker.set_query("qid_def", {
                raw_response = emit_definition_sse("ASIN", "Amazon Standard Identification Number."),
            })
            vim.schedule(function() on_exit("qid_def") end)
        end
    end)

    after_each(function()
        parley.dispatcher.query = orig_query
        assembly.resolve_agent = orig_resolve
        pcall(function() require("parley.progress").stop() end)
        vim.fn.delete(tmpdir, "rf")
    end)

    local function define_manifest()
        return {
            name = "define", description = "d", scope = "global",
            activation = { manual = true }, tools = { "emit_definition" },
            source = function() return "SYSTEM BODY" end,
        }
    end

    it("does not write or reload the buffer under opts.no_reload", function()
        -- Make the buffer dirty (an in-progress prompt the user is typing).
        vim.api.nvim_buf_set_lines(buf, -1, -1, false, { "DRAFT the user is typing" })
        assert.is_true(vim.bo[buf].modified)

        skill_invoke.invoke(buf, define_manifest(), { phrase = "ASIN" }, {
            document = "SENTINEL CONTEXT",
            no_reload = true,
            on_done = function(r) done_result = r end,
        })
        vim.wait(2000, function() return done_result ~= nil end)

        assert.is_not_nil(done_result, "on_done never ran")
        -- File on disk is unchanged (the draft was NOT persisted).
        assert.are.same({ "on disk line 1", "on disk line 2" }, vim.fn.readfile(path))
        -- Buffer was NOT reloaded (still dirty, draft intact).
        assert.is_true(vim.bo[buf].modified)
        assert.are.equal("DRAFT the user is typing",
            vim.api.nvim_buf_get_lines(buf, -2, -1, false)[1])
    end)

    it("sends opts.document as the user message, not the whole buffer", function()
        skill_invoke.invoke(buf, define_manifest(), { phrase = "ASIN" }, {
            document = "SENTINEL CONTEXT",
            no_reload = true,
            on_done = function(r) done_result = r end,
        })
        vim.wait(2000, function() return done_result ~= nil end)
        assert.is_not_nil(captured_payload, "query never ran")
        local dump = vim.inspect(captured_payload.messages)
        assert.is_true(dump:find("SENTINEL CONTEXT", 1, true) ~= nil,
            "document should be in the payload")
        assert.is_nil(dump:find("DRAFT the user is typing", 1, true),
            "the buffer content must not leak when opts.document is set")
    end)
end)

describe("define: web-toggle payload (#161)", function()
    local parley = require("parley")
    local dispatcher = require("parley.dispatcher")

    before_each(function()
        require("parley.tools").register_builtins()
        parley._state = parley._state or {}
    end)

    local function tool_names(payload)
        local n = {}
        for _, t in ipairs(payload.tools or {}) do n[t.name] = true end
        return n
    end

    it("includes web_search in the anthropic payload iff the global toggle is on", function()
        local saved = parley._state.web_search
        local MODEL = { model = "claude-sonnet-4-5" }
        local msgs = { { role = "user", content = "x" } }

        parley._state.web_search = true
        local on = dispatcher.prepare_payload(msgs, MODEL, "anthropic", { "emit_definition" })
        assert.is_true(tool_names(on).web_search == true)

        parley._state.web_search = false
        local off = dispatcher.prepare_payload(msgs, MODEL, "anthropic", { "emit_definition" })
        assert.is_nil(tool_names(off).web_search)

        parley._state.web_search = saved
    end)
end)

describe("define_visual + render_definition (#161)", function()
    local parley = require("parley")
    local tasker = require("parley.tasker")
    local assembly = require("parley.skill_assembly")
    local ns = require("parley.skill_render").diag_namespace()

    local tmpdir, path, buf, orig_query, orig_resolve, query_called

    before_each(function()
        require("parley.tools").register_builtins()
        tmpdir = vim.fn.tempname() .. "-dv"
        vim.fn.mkdir(tmpdir, "p")
        path = tmpdir .. "/chat.md"
        vim.fn.writefile({ "line one", "line two", "here is ASIN in context", "line four", "       " }, path)
        vim.cmd("edit " .. vim.fn.fnameescape(path))
        buf = vim.api.nvim_get_current_buf()
        query_called = false

        orig_resolve = assembly.resolve_agent
        assembly.resolve_agent = function()
            return { model = "m", provider = "anthropic" }
        end
        orig_query = parley.dispatcher.query
        parley.dispatcher.query = function(_b, _p, _payload, _h, on_exit)
            query_called = true
            tasker.set_query("qid_dv", {
                raw_response = emit_definition_sse("ASIN", "Amazon Standard Identification Number."),
            })
            vim.schedule(function() on_exit("qid_dv") end)
        end
        vim.diagnostic.reset(ns, buf)
    end)

    after_each(function()
        parley.dispatcher.query = orig_query
        assembly.resolve_agent = orig_resolve
        pcall(function() require("parley.progress").stop() end)
        vim.fn.delete(tmpdir, "rf")
    end)

    local hl_ns = vim.api.nvim_create_namespace("parley_skill_hl")
    local function hl_on_line(b, line0)
        for _, m in ipairs(vim.api.nvim_buf_get_extmarks(b, hl_ns, 0, -1, {})) do
            if m[2] == line0 then return true end
        end
        return false
    end

    it("stores the definition as a durable footnote, highlights the line, and shows the diagnostic", function()
        -- select "ASIN" on line 3 (cols 9..12, 1-based)
        vim.fn.setpos("'<", { buf, 3, 9, 0 })
        vim.fn.setpos("'>", { buf, 3, 12, 0 })
        require("parley").define_visual(buf)
        vim.wait(2000, function()
            return #vim.diagnostic.get(buf, { namespace = ns }) > 0
        end)
        -- Footnote reference written into the line (the undo anchor)
        assert.are.equal("here is ASIN[^asin] in context",
            vim.api.nvim_buf_get_lines(buf, 2, 3, false)[1])
        assert.are.same({
            "---",
            "",
            "[^asin]: Amazon Standard Identification Number.",
        }, vim.api.nvim_buf_get_lines(buf, 5, 8, false))
        -- diagnostic on the term's line
        local diags = vim.diagnostic.get(buf, { namespace = ns })
        assert.are.equal(2, diags[1].lnum) -- 0-based line 3
        assert.are.equal(8, diags[1].col)
        assert.are.equal(2, diags[1].end_lnum)
        assert.are.equal(19, diags[1].end_col) -- ASIN plus [^asin]
        assert.is_true(diags[1].message:find("ASIN", 1, true) ~= nil)
        -- whole-line DiffChange highlight on the hl namespace, on line 3
        assert.is_true(hl_on_line(buf, 2), "term line not highlighted")
    end)

    it("u undoes the footnote edit + clears decorations; C-r restores them (R1)", function()
        vim.fn.setpos("'<", { buf, 3, 9, 0 })
        vim.fn.setpos("'>", { buf, 3, 12, 0 })
        require("parley").define_visual(buf)
        vim.wait(2000, function()
            return #vim.diagnostic.get(buf, { namespace = ns }) > 0
        end)
        assert.are.equal("here is ASIN[^asin] in context",
            vim.api.nvim_buf_get_lines(buf, 2, 3, false)[1])

        -- undo: the footnote edit reverts; the projection watcher (TextChanged) clears
        -- both decorations. Fire the autocmd Vim fires interactively — headless
        -- :undo doesn't trigger TextChanged on its own (the watcher itself is
        -- covered by projection's own specs; here we verify define's records).
        vim.cmd("silent undo")
        vim.api.nvim_exec_autocmds("TextChanged", { buffer = buf })
        assert.are.equal("here is ASIN in context",
            vim.api.nvim_buf_get_lines(buf, 2, 3, false)[1])
        assert.is_nil(table.concat(vim.api.nvim_buf_get_lines(buf, 0, -1, false), "\n")
            :find("%[%^asin%]:", 1, false), "footnote not removed on undo")
        assert.are.equal(0, #vim.diagnostic.get(buf, { namespace = ns }),
            "diagnostic not cleared on undo")
        assert.is_false(hl_on_line(buf, 2), "highlight not cleared on undo")

        -- redo: footnote edit + decorations return
        vim.cmd("silent redo")
        vim.api.nvim_exec_autocmds("TextChanged", { buffer = buf })
        assert.are.equal("here is ASIN[^asin] in context",
            vim.api.nvim_buf_get_lines(buf, 2, 3, false)[1])
        assert.is_true(#vim.diagnostic.get(buf, { namespace = ns }) >= 1,
            "diagnostic not restored on redo")
        assert.is_true(hl_on_line(buf, 2), "highlight not restored on redo")
    end)

    it("no-ops on a whitespace-only selection (no query, no diagnostic)", function()
        -- line 5 is all spaces; selecting it yields a whitespace-only phrase.
        vim.fn.setpos("'<", { buf, 5, 1, 0 })
        vim.fn.setpos("'>", { buf, 5, 5, 0 })
        require("parley").define_visual(buf)
        vim.wait(200)
        assert.is_false(query_called, "empty selection must not query")
        assert.are.equal(0, #vim.diagnostic.get(buf, { namespace = ns }))
    end)

    it("no-ops on a no-tool-call response", function()
        parley.dispatcher.query = function(_b, _p, _payload, _h, on_exit)
            query_called = true
            tasker.set_query("qid_none", {
                raw_response = "event: message_stop\ndata: {\"type\":\"message_stop\"}\n",
            })
            vim.schedule(function() on_exit("qid_none") end)
        end
        vim.fn.setpos("'<", { buf, 3, 9, 0 })
        vim.fn.setpos("'>", { buf, 3, 12, 0 })
        require("parley").define_visual(buf)
        vim.wait(1000, function() return false end) -- let on_done run
        assert.is_true(query_called)
        assert.are.equal(0, #vim.diagnostic.get(buf, { namespace = ns }),
            "a no-tool response must not set a diagnostic")
        assert.are.equal("here is ASIN in context",
            vim.api.nvim_buf_get_lines(buf, 2, 3, false)[1],
            "a no-tool response must not footnote the term")
    end)
end)

describe("define keybinding split (#161)", function()
    local kb = require("parley.keybinding_registry")
    local parley = require("parley")

    it("routes visual <M-CR> to define, keeps visual <C-g><C-g> as respond, n/i respond", function()
        local buf = vim.api.nvim_create_buf(false, true)
        local who
        -- Mirror the production chat_define callback: n/i = respond, v/x = define.
        local callbacks = {
            chat_respond = {
                n = function() who = "respond" end,
                i = function() who = "respond" end,
                v = function() who = "respond" end,
                x = function() who = "respond" end,
            },
            chat_define = {
                n = function() who = "respond" end,
                i = function() who = "respond" end,
                v = function() who = "define" end,
                x = function() who = "define" end,
            },
        }

        local records = {}
        local function set_keymap(_scopes, mode, key, cb, _desc)
            records[#records + 1] = { mode = mode, key = key, cb = cb }
        end
        kb.register_buffer({ "chat" }, buf, parley.config, callbacks, set_keymap)

        local function invoke(mode, key)
            for _, r in ipairs(records) do
                if r.mode == mode and r.key == key then
                    who = nil
                    r.cb()
                    return who
                end
            end
            return "<unbound>"
        end

        -- visual <M-CR> → define; visual <C-g><C-g> → respond (resubmit preserved)
        assert.are.equal("define", invoke("x", "<M-CR>"))
        assert.are.equal("respond", invoke("x", "<C-g><C-g>"))
        -- normal/insert <M-CR> → respond (unchanged)
        assert.are.equal("respond", invoke("n", "<M-CR>"))
        assert.are.equal("respond", invoke("i", "<M-CR>"))
        -- chat_respond no longer binds <M-CR> (no double-bind): exactly one per mode
        local mcr_x_count = 0
        for _, r in ipairs(records) do
            if r.mode == "x" and r.key == "<M-CR>" then
                mcr_x_count = mcr_x_count + 1
            end
        end
        assert.are.equal(1, mcr_x_count, "<M-CR> must be bound exactly once in visual mode")
    end)

    it("real prep_chat wiring: <M-CR>/<C-g><C-g> buffer-mapped in visual mode", function()
        -- Exercises the production callback table + registry (not a hand-mirror):
        -- catches a chat_define id/key mismatch that would silently no-op.
        local dir = parley.config.chat_dir
        vim.fn.mkdir(dir, "p")
        local path = dir .. "/2026-03-01-kbwire.md"
        -- must pass not_chat: >=5 lines + topic/file headers + separator
        vim.fn.writefile({ "# topic: kbwire", "- file: kbwire.md", "---", "", "💬: hi" }, path)
        vim.cmd("edit " .. vim.fn.fnameescape(path))
        local buf = vim.api.nvim_get_current_buf()
        parley.prep_chat(buf, path)

        local mcr = vim.fn.maparg("<M-CR>", "x", false, true)
        assert.is_true(mcr and mcr.buffer == 1 and next(mcr) ~= nil,
            "<M-CR> not buffer-mapped in visual mode after prep_chat")
        local cgg = vim.fn.maparg("<C-g><C-g>", "x", false, true)
        assert.is_true(cgg and cgg.buffer == 1 and next(cgg) ~= nil,
            "<C-g><C-g> not buffer-mapped in visual mode after prep_chat")

        vim.fn.delete(path)
    end)
end)

describe("define: context_for_selection vs real parse_chat (#161)", function()
    it("slices the enclosing exchange from real parse_chat output (field contract)", function()
        local parley = require("parley")
        local define = require("parley.define")
        -- A real 2-exchange chat; selecting inside exchange 2 must yield ONLY
        -- exchange 2's lines (guards context_for_selection's field access against
        -- the real parse_chat output shape, not just a synthetic table).
        local lines = {
            "# topic: ctx",
            "- file: ctx.md",
            "---",
            "",
            "💬: what is FIRSTONLY",
            "🤖: first answer about FIRSTONLY",
            "",
            "💬: define ASIN",
            "🤖: ASIN is a product id",
        }
        local header_end = parley.chat_parser.find_header_end(lines) or 0
        local parsed = parley.parse_chat(lines, header_end)
        assert.is_true(#parsed.exchanges >= 2, "fixture must parse into >=2 exchanges")
        -- the "define ASIN" question is line 8 (1-based)
        local ctx = define.context_for_selection(parsed, 8, lines, parley.find_exchange_at_line)
        assert.is_true(ctx:find("ASIN", 1, true) ~= nil, "enclosing exchange must be present")
        assert.is_nil(ctx:find("FIRSTONLY", 1, true), "other exchange must not be in context")
    end)
end)
