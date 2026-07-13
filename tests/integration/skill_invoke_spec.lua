-- Integration test for lua/parley/skill_invoke.lua — the thin P2 driver.
--
-- Reuses the chat_respond_spec fake pattern: monkeypatch parley.dispatcher.query
-- (the LLM dispatcher), inject a tool-use raw_response into tasker, fire on_exit;
-- vim.wait for the (vim.scheduled) on_done. The propose_edits call applies through
-- the REAL tools dispatcher (execute_call) onto the artifact file.

local skill_invoke = require("parley.skill_invoke")
local parley = require("parley")
local tasker = require("parley.tasker")
local assembly = require("parley.skill_assembly")

-- SSE builder (same shape as tests/unit/anthropic_tool_decode_spec.lua).
local function sse(events)
    local out = {}
    for _, ev in ipairs(events) do
        table.insert(out, "event: " .. (ev.type or "unknown"))
        table.insert(out, "data: " .. vim.json.encode(ev))
        table.insert(out, "")
    end
    return table.concat(out, "\n")
end

-- A raw_response decoding to one propose_edits tool call with the given edits.
local function propose_edits_sse(edits)
    return sse({
        { type = "content_block_start", index = 0,
          content_block = { type = "tool_use", id = "t1", name = "propose_edits", input = {} } },
        { type = "content_block_delta", index = 0,
          delta = { type = "input_json_delta", partial_json = vim.json.encode({ edits = edits }) } },
        { type = "content_block_stop", index = 0 },
        { type = "message_stop" },
    })
end

local function read_file_sse(path)
    return sse({
        { type = "content_block_start", index = 0,
          content_block = { type = "tool_use", id = "t_read", name = "read_file", input = {} } },
        { type = "content_block_delta", index = 0,
          delta = { type = "input_json_delta", partial_json = vim.json.encode({ file_path = path }) } },
        { type = "content_block_stop", index = 0 },
        { type = "message_stop" },
    })
end

local function manifest(over)
    return vim.tbl_extend("force", {
        name = "t", description = "d", scope = "global", activation = { manual = true },
        source = function() return "SYSTEM BODY" end,
        tools = {}, elevated = { "propose_edits" }, force_tool = "propose_edits",
    }, over or {})
end

describe("skill_invoke.invoke", function()
    local tmpdir, path, buf
    local orig_query, orig_resolve
    local captured_payload, done_result

    before_each(function()
        require("parley.tools").register_builtins() -- propose_edits must be registered
        tmpdir = vim.fn.tempname() .. "-si"
        vim.fn.mkdir(tmpdir, "p")
        path = tmpdir .. "/doc.md"
        vim.fn.writefile({ "alpha beta" }, path)
        vim.cmd("edit " .. vim.fn.fnameescape(path))
        buf = vim.api.nvim_get_current_buf()

        captured_payload, done_result = nil, nil

        -- isolate from real agent resolution (tested separately in M2)
        orig_resolve = assembly.resolve_agent
        assembly.resolve_agent = function()
            return { model = "m", provider = "anthropic" }
        end

        orig_query = parley.dispatcher.query
        parley.dispatcher.query = function(_buf, _provider, payload, _handler, on_exit)
            captured_payload = payload
            tasker.set_query("qid_test", {
                raw_response = propose_edits_sse({
                    { old_string = "alpha", new_string = "ALPHA", explain = "uppercase" },
                }),
            })
            vim.schedule(function()
                on_exit("qid_test")
            end)
        end
    end)

    after_each(function()
        parley.dispatcher.query = orig_query
        assembly.resolve_agent = orig_resolve
        pcall(function() require("parley.progress").stop() end)
        vim.fn.delete(tmpdir, "rf")
    end)

    it("drives one exchange: payload + force_tool, applies propose_edits, reloads, on_done", function()
        skill_invoke.invoke(buf, manifest(), {}, {
            manual = true,
            on_done = function(r) done_result = r end,
        })
        vim.wait(2000, function() return done_result ~= nil end)

        assert.is_not_nil(done_result, "on_done never ran")
        assert.is_true(done_result.ok)
        -- payload: force_tool → tool_choice; the system body is messages[1]
        assert.are.same({ type = "tool", name = "propose_edits" }, captured_payload.tool_choice)
        -- large-document headroom: max_tokens bumped well past the 4096 default
        assert.is_true((captured_payload.max_tokens or 0) >= 100000)
        -- propose_edits applied to the artifact FILE via the real execute_call path
        assert.are.equal("ALPHA beta", table.concat(vim.fn.readfile(path), "\n"))
        -- the artifact BUFFER was reloaded to match
        assert.are.equal("ALPHA beta", table.concat(vim.api.nvim_buf_get_lines(buf, 0, -1, false), "\n"))
        -- a numbered backup was made (M3 Task 1)
        assert.are.equal(1, vim.fn.filereadable(path .. ".parley-backup.1"))
        -- #133 M3: on_done payload carries the journal-feeding fields
        assert.are.equal("alpha beta", done_result.original)
        assert.are.equal("ALPHA beta", done_result.new_content)
        assert.is_true(#done_result.decorations >= 1)
        assert.are.equal("edit", done_result.decorations[1].kind)
        assert.are.equal("uppercase", done_result.decorations[1].explain)
    end)

    it("coerces a stringified edits array and applies it (model quirk, #133)", function()
        -- Some models emit the propose_edits `edits` arg as a JSON STRING, not an
        -- array. The driver must coerce it (so it applies) and not crash the renderer.
        parley.dispatcher.query = function(_b, _p, _payload, _h, on_exit)
            local edits_str = vim.json.encode({ { old_string = "alpha", new_string = "ALPHA", explain = "up" } })
            tasker.set_query("qid_str", {
                raw_response = sse({
                    { type = "content_block_start", index = 0,
                      content_block = { type = "tool_use", id = "t1", name = "propose_edits", input = {} } },
                    { type = "content_block_delta", index = 0,
                      delta = { type = "input_json_delta", partial_json = vim.json.encode({ edits = edits_str }) } },
                    { type = "content_block_stop", index = 0 },
                    { type = "message_stop" },
                }),
            })
            vim.schedule(function() on_exit("qid_str") end)
        end
        skill_invoke.invoke(buf, manifest(), {}, { on_done = function(r) done_result = r end })
        vim.wait(2000, function() return done_result ~= nil end)
        assert.is_not_nil(done_result, "on_done never ran (renderer likely crashed)")
        assert.is_true(done_result.ok)
        assert.are.equal("ALPHA beta", table.concat(vim.fn.readfile(path), "\n"))
    end)

    it("surfaces a failed edit: on_done ok=false, applied=0, file untouched", function()
        -- non-unique old_string → compute_edits fails → propose_edits is_error
        vim.fn.writefile({ "ab ab" }, path)
        vim.cmd("edit! " .. vim.fn.fnameescape(path))
        buf = vim.api.nvim_get_current_buf()
        parley.dispatcher.query = function(_b, _p, _payload, _h, on_exit)
            tasker.set_query("qid_err", {
                raw_response = propose_edits_sse({
                    { old_string = "ab", new_string = "X", explain = "non-unique" },
                }),
            })
            vim.schedule(function() on_exit("qid_err") end)
        end
        skill_invoke.invoke(buf, manifest(), {}, { on_done = function(r) done_result = r end })
        vim.wait(2000, function() return done_result ~= nil end)
        assert.is_not_nil(done_result)
        assert.is_false(done_result.ok)
        assert.are.equal(0, done_result.applied)
        assert.are.equal("ab ab", table.concat(vim.fn.readfile(path), "\n")) -- untouched
    end)

    it("is_in_flight true during a query; cancel clears it + supersedes the exchange (#133)", function()
        local held_exit
        parley.dispatcher.query = function(_b, _p, _payload, _h, on_exit)
            held_exit = on_exit -- hold it open; don't complete the query
        end
        skill_invoke.invoke(buf, manifest(), {}, { on_done = function(r) done_result = r end })
        assert.is_true(skill_invoke.is_in_flight(buf))
        skill_invoke.cancel(buf)
        assert.is_false(skill_invoke.is_in_flight(buf))
        -- The now-superseded query completes late → its on_exit must no-op.
        tasker.set_query("qid_stale", { raw_response = "" })
        held_exit("qid_stale")
        vim.wait(200, function() return done_result ~= nil end)
        assert.is_nil(done_result, "a cancelled query's late on_exit must not run on_done")
    end)

    it("shows the progress bar during the query and stops it on completion (#133 M7)", function()
        local progress = require("parley.progress")
        local held_exit
        parley.dispatcher.query = function(_b, _p, _payload, _h, on_exit)
            held_exit = on_exit
            tasker.set_query("qid_p", {
                raw_response = propose_edits_sse({
                    { old_string = "alpha", new_string = "ALPHA", explain = "up" },
                }),
            })
        end
        progress.stop()
        skill_invoke.invoke(buf, manifest(), {}, { on_done = function(r) done_result = r end })
        assert.is_true(progress.is_active(), "bar shows while the query runs")
        held_exit("qid_p")
        vim.wait(2000, function() return done_result ~= nil end)
        assert.is_false(progress.is_active(), "bar stops when the query completes")
    end)

    it("aborts (on_done ok=false) when no agent resolves", function()
        assembly.resolve_agent = function() return nil end
        local query_called = false
        parley.dispatcher.query = function() query_called = true end
        skill_invoke.invoke(buf, manifest(), {}, { on_done = function(r) done_result = r end })
        vim.wait(500, function() return done_result ~= nil end)
        assert.is_not_nil(done_result)
        assert.is_false(done_result.ok)
        assert.is_false(query_called, "must not query without an agent")
    end)

    it("aborts gracefully (on_done ok=false) when source() throws", function()
        -- a fallible source (e.g. voice_apply with a missing style file) must route
        -- through on_done, not throw a raw Lua error past the caller.
        local query_called = false
        parley.dispatcher.query = function() query_called = true end
        local m = manifest({ source = function() error("style file not found") end })
        skill_invoke.invoke(buf, m, {}, { on_done = function(r) done_result = r end })
        vim.wait(500, function() return done_result ~= nil end)
        assert.is_not_nil(done_result, "on_done must run even when source throws")
        assert.is_false(done_result.ok)
        assert.is_truthy((done_result.msg or ""):find("source", 1, true))
        assert.is_false(query_called, "must not query when source failed")
    end)

    it("widens relative reads from ordinary nested repo Markdown", function()
        local repo = tmpdir .. "/repo"
        local nested = repo .. "/data/nested"
        vim.fn.mkdir(nested, "p")
        vim.fn.writefile({ "repo root file" }, repo .. "/README.md")
        path = nested .. "/doc.md"
        vim.fn.writefile({ "alpha beta" }, path)
        vim.cmd("edit! " .. vim.fn.fnameescape(path))
        buf = vim.api.nvim_get_current_buf()

        parley.config.repo_root = repo

        parley.dispatcher.query = function(_b, _p, _payload, _h, on_exit)
            tasker.set_query("qid_read", {
                raw_response = read_file_sse("README.md"),
            })
            vim.schedule(function() on_exit("qid_read") end)
        end

        skill_invoke.invoke(buf, manifest({
            tools = { "read_file" },
            elevated = {},
            force_tool = "read_file",
        }), {}, { on_done = function(r) done_result = r end })
        vim.wait(2000, function() return done_result ~= nil end)

        assert.is_not_nil(done_result)
        assert.is_true(done_result.ok)
        assert.equals("repo root file", done_result.results[1].content:match("repo root file"))
    end)

    it("executes relative tool paths from a super-repo sibling chat neighborhood", function()
        local current_repo = tmpdir .. "/current"
        local sibling_repo = tmpdir .. "/sibling"
        local current_chat = current_repo .. "/workshop/parley"
        local sibling_chat = sibling_repo .. "/workshop/parley"
        vim.fn.mkdir(current_chat, "p")
        vim.fn.mkdir(sibling_chat, "p")
        vim.fn.writefile({ "sibling repo root file" }, sibling_repo .. "/README.md")
        path = sibling_chat .. "/2026-06-29.topic.md"
        vim.fn.writefile({ "alpha beta" }, path)
        vim.cmd("edit! " .. vim.fn.fnameescape(path))
        buf = vim.api.nvim_get_current_buf()

        parley.config.repo_root = current_repo
        parley.config.repo_chat_dir = "workshop/parley"
        parley.config.chat_roots = {
            { dir = current_chat, label = "repo" },
            { dir = sibling_chat, label = "sibling" },
        }

        parley.dispatcher.query = function(_b, _p, _payload, _h, on_exit)
            tasker.set_query("qid_sibling_read", {
                raw_response = read_file_sse("README.md"),
            })
            vim.schedule(function() on_exit("qid_sibling_read") end)
        end

        skill_invoke.invoke(buf, manifest({
            tools = { "read_file" },
            elevated = {},
            force_tool = "read_file",
        }), {}, { on_done = function(r) done_result = r end })
        vim.wait(2000, function() return done_result ~= nil end)

        assert.is_not_nil(done_result)
        assert.is_true(done_result.ok)
        assert.equals("sibling repo root file", done_result.results[1].content:match("sibling repo root file"))
    end)
end)

describe("skill_invoke terminal ownership (#182)", function()
    local parley = require("parley")
    local skill_invoke = require("parley.skill_invoke")
    local assembly = require("parley.skill_assembly")
    local tasker = require("parley.tasker")
    local tmpdir, path, buf, original_query, original_resolve

    local function terminal_manifest(overrides)
        return vim.tbl_extend("force", {
            name = "terminal-test",
            description = "d",
            scope = "global",
            activation = { manual = true },
            source = function() return "SYSTEM" end,
            tools = {},
        }, overrides or {})
    end

    before_each(function()
        tmpdir = vim.fn.tempname() .. "-skill-terminal"
        vim.fn.mkdir(tmpdir, "p")
        path = tmpdir .. "/doc.md"
        vim.fn.writefile({ "alpha" }, path)
        vim.cmd("edit! " .. vim.fn.fnameescape(path))
        buf = vim.api.nvim_get_current_buf()
        original_query = parley.dispatcher.query
        original_resolve = assembly.resolve_agent
        assembly.resolve_agent = function()
            return { model = "m", provider = "anthropic" }
        end
        require("parley.progress").stop()
    end)

    after_each(function()
        parley.dispatcher.query = original_query
        assembly.resolve_agent = original_resolve
        pcall(skill_invoke.cancel, buf)
        pcall(function() require("parley.progress").stop() end)
        pcall(vim.cmd, "enew!")
        vim.fn.delete(tmpdir, "rf")
    end)

    it("suppresses detached progress only when explicitly requested", function()
        local held_exit
        parley.dispatcher.query = function(_b, _p, _pl, _h, on_exit)
            held_exit = on_exit
        end
        skill_invoke.invoke(buf, terminal_manifest(), {}, { detached_progress = false })
        assert.is_false(require("parley.progress").is_active())
        skill_invoke.cancel(buf)

        skill_invoke.invoke(buf, terminal_manifest(), {}, {})
        assert.is_true(require("parley.progress").is_active())
        skill_invoke.cancel(buf)
        tasker.set_query("late", { raw_response = "" })
        held_exit("late")
    end)

    it("owns each async terminal once and orders terminal before done", function()
        local terminals = {
            {
                name = "success",
                fire = function(c) tasker.set_query("q", { raw_response = "" }); c.on_exit("q") end,
            },
            { name = "pre-query abort", fire = function(c) c.on_abort("abort") end },
            { name = "transport error", fire = function(c) c.on_error("q", { code = 7 }) end },
        }
        for _, case in ipairs(terminals) do
            local callbacks, events = {}, {}
            parley.dispatcher.query = function(_b, _p, _pl, _h, on_exit, _cb, _prog, on_abort, _activity, on_error)
                callbacks = { on_exit = on_exit, on_abort = on_abort, on_error = on_error }
            end
            skill_invoke.invoke(buf, terminal_manifest(), {}, {
                detached_progress = false,
                on_terminal = function() table.insert(events, "terminal") end,
                on_done = function() table.insert(events, "done") end,
            })
            case.fire(callbacks)
            assert.is_true(vim.wait(1000, function() return #events == 2 end, 10), case.name)
            callbacks.on_abort("late")
            callbacks.on_error("q", { code = 8 })
            assert.are.same({ "terminal", "done" }, events, case.name)
            assert.is_false(skill_invoke.is_in_flight(buf), case.name)
        end
    end)

    it("cancel delivers terminal cleanup once, skips done, and ignores late callbacks", function()
        local held_exit, held_error, events = nil, nil, {}
        parley.dispatcher.query = function(_b, _p, _pl, _h, on_exit, _cb, _prog, _abort, _activity, on_error)
            held_exit, held_error = on_exit, on_error
        end
        skill_invoke.invoke(buf, terminal_manifest(), {}, {
            detached_progress = false,
            on_terminal = function() table.insert(events, "terminal") end,
            on_done = function() table.insert(events, "done") end,
        })
        skill_invoke.cancel(buf)
        skill_invoke.cancel(buf)
        tasker.set_query("late", { raw_response = "" })
        held_exit("late")
        held_error("late", { code = 7 })
        vim.wait(100, function() return false end)
        assert.are.same({ "terminal" }, events)
    end)

    it("finishes invalid scheduled completion without reading or delivering done", function()
        local held_exit, events = nil, {}
        parley.dispatcher.query = function(_b, _p, _pl, _h, on_exit)
            held_exit = on_exit
        end
        skill_invoke.invoke(buf, terminal_manifest(), {}, {
            detached_progress = false,
            on_terminal = function(result) table.insert(events, result.msg) end,
            on_done = function() table.insert(events, "done") end,
        })
        vim.api.nvim_buf_delete(buf, { force = true })
        tasker.set_query("deleted", { raw_response = "" })
        held_exit("deleted")
        assert.is_true(vim.wait(1000, function() return #events > 0 end, 10))
        assert.are.same({ "buffer invalid" }, events)
    end)

    it("delivers synchronous terminal failures once before done", function()
        local cases = {
            {
                name = "no file",
                setup = function()
                    vim.cmd("enew!")
                    buf = vim.api.nvim_get_current_buf()
                end,
                manifest = terminal_manifest(),
                message = "buffer has no file",
            },
            {
                name = "source failure",
                setup = function() end,
                manifest = terminal_manifest({ source = function() error("boom") end }),
                message = "source failed",
            },
            {
                name = "no agent",
                setup = function() assembly.resolve_agent = function() return nil end end,
                manifest = terminal_manifest(),
                message = "no agent",
            },
        }
        for _, case in ipairs(cases) do
            if case.name ~= "no file" then
                vim.cmd("edit! " .. vim.fn.fnameescape(path))
                buf = vim.api.nvim_get_current_buf()
            end
            case.setup()
            local events = {}
            skill_invoke.invoke(buf, case.manifest, {}, {
                detached_progress = false,
                on_terminal = function(result) table.insert(events, "terminal:" .. result.msg) end,
                on_done = function() table.insert(events, "done") end,
            })
            assert.are.equal(2, #events, case.name)
            assert.is_truthy(events[1]:find(case.message, 1, true), case.name)
            assert.are.equal("done", events[2], case.name)
            assert.is_false(skill_invoke.is_in_flight(buf), case.name)
        end
    end)

    it("rejects a second invocation through its own ordered terminal", function()
        parley.dispatcher.query = function() end
        skill_invoke.invoke(buf, terminal_manifest(), {}, { detached_progress = false })
        local events = {}
        skill_invoke.invoke(buf, terminal_manifest(), {}, {
            detached_progress = false,
            on_terminal = function(result) table.insert(events, "terminal:" .. result.msg) end,
            on_done = function() table.insert(events, "done") end,
        })
        assert.are.same({ "terminal:already running", "done" }, events)
        assert.is_true(skill_invoke.is_in_flight(buf), "the first invocation must remain owned")
        skill_invoke.cancel(buf)
    end)
end)
