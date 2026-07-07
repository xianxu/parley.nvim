-- Integration tests for the inline term-definition feature (#161).
-- See workshop/issues/000161-inline-term-definition.md and its plan.

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
