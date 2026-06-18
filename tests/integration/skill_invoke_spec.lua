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
end)
