-- Unit tests for lua/parley/tool_loop.lua
--
-- The tool loop is the driver that ties together:
--   - Task 2.4 providers.decode_anthropic_tool_calls_from_stream
--     (extracts ToolCalls from a captured SSE response)
--   - Task 2.3 dispatcher.execute_call (cwd-scope, pcall-guarded
--     handler invocation, truncation)
--   - Task 2.1 serialize.render_call / render_result (emits the
--     🔧: / 📎: buffer blocks)
--
-- After streaming finishes, chat_respond calls process_response
-- with the captured raw SSE stream. process_response:
--   1. Decodes tool_use blocks from the stream
--   2. If none → returns "done" and the normal chat_respond
--      finalization continues
--   3. If some → writes 🔧: blocks, executes tools, writes 📎:
--      blocks, and returns "recurse" to tell chat_respond to
--      re-submit the updated buffer
--
-- M2 ships with a hard single-recursion cap inside chat_respond;
-- M4 Task 4.1 lifts that cap using the per-buf iteration counter
-- this module exposes.

local tool_loop = require("parley.tool_loop")
local registry = require("parley.tools")
local serialize = require("parley.tools.serialize")

local tmp_base = (os.getenv("TMPDIR") or "/tmp") .. "/claude/parley-test-tool-loop-" .. os.time()
vim.fn.mkdir(tmp_base, "p")

-- Build a valid Anthropic SSE raw response that calls `read_file`
-- on the given path. Used to drive process_response without hitting
-- the real API.
local function mk_read_file_sse_response(toolu_id, path)
    local events = {
        { type = "message_start", message = { id = "msg_test", model = "claude-sonnet-4-6" } },
        { type = "content_block_start", index = 0,
          content_block = { type = "tool_use", id = toolu_id, name = "read_file", input = {} } },
        { type = "content_block_delta", index = 0,
          delta = { type = "input_json_delta", partial_json = '{"path":"' .. path .. '"}' } },
        { type = "content_block_stop", index = 0 },
        { type = "message_delta", delta = { stop_reason = "tool_use" } },
        { type = "message_stop" },
    }
    local lines = {}
    for _, ev in ipairs(events) do
        table.insert(lines, "event: " .. (ev.type or "unknown"))
        table.insert(lines, "data: " .. vim.json.encode(ev))
        table.insert(lines, "")
    end
    return table.concat(lines, "\n")
end

-- Build an SSE response that returns plain text (no tool_use) —
-- the "final answer" phase of a tool loop.
local function mk_plain_text_sse_response(text)
    local events = {
        { type = "message_start", message = { id = "msg_test" } },
        { type = "content_block_start", index = 0, content_block = { type = "text", text = "" } },
        { type = "content_block_delta", index = 0, delta = { type = "text_delta", text = text } },
        { type = "content_block_stop", index = 0 },
        { type = "message_stop" },
    }
    local lines = {}
    for _, ev in ipairs(events) do
        table.insert(lines, "event: " .. (ev.type or "unknown"))
        table.insert(lines, "data: " .. vim.json.encode(ev))
        table.insert(lines, "")
    end
    return table.concat(lines, "\n")
end

-- Create a scratch buffer with an initial state.
local function mk_buffer(initial_lines)
    local bufnr = vim.api.nvim_create_buf(false, true)
    vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, initial_lines or {})
    return bufnr
end

local function buf_text(bufnr)
    return table.concat(vim.api.nvim_buf_get_lines(bufnr, 0, -1, false), "\n")
end

describe("tool_loop: per-buffer state", function()
    before_each(function()
        tool_loop.reset(1)
        tool_loop.reset(2)
        registry.register_builtins()
    end)

    it("get_iter returns 0 for a fresh buffer", function()
        assert.equals(0, tool_loop.get_iter(1))
    end)

    it("increment_iter bumps the counter per buffer", function()
        tool_loop.increment_iter(1)
        assert.equals(1, tool_loop.get_iter(1))
        tool_loop.increment_iter(1)
        assert.equals(2, tool_loop.get_iter(1))
    end)

    it("state is independent across buffers", function()
        tool_loop.increment_iter(1)
        tool_loop.increment_iter(1)
        tool_loop.increment_iter(2)
        assert.equals(2, tool_loop.get_iter(1))
        assert.equals(1, tool_loop.get_iter(2))
    end)

    it("reset clears iteration state for a buffer", function()
        tool_loop.increment_iter(1)
        tool_loop.increment_iter(1)
        tool_loop.reset(1)
        assert.equals(0, tool_loop.get_iter(1))
    end)
end)

describe("tool_loop.process_response: no tool_use blocks", function()
    before_each(function()
        registry.register_builtins()
    end)

    it("returns 'done' when the stream has no tool_use", function()
        local bufnr = mk_buffer({ "💬: hi", "🤖: [Claude]", "Hello!" })
        local raw = mk_plain_text_sse_response("Hello!")
        local outcome = tool_loop.process_response(bufnr, raw, { max_tool_iterations = 20, tool_result_max_bytes = 102400 })
        assert.equals("done", outcome)
        -- Buffer should NOT have grown (no tool blocks added)
        local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
        assert.equals(3, #lines)
    end)

    it("returns 'done' on empty raw response", function()
        local bufnr = mk_buffer({ "💬: hi", "🤖: [Claude]" })
        local outcome = tool_loop.process_response(bufnr, "", {})
        assert.equals("done", outcome)
    end)

    it("resets iteration counter on 'done'", function()
        local bufnr = mk_buffer({ "💬: hi", "🤖: [Claude]" })
        tool_loop.increment_iter(bufnr)
        assert.equals(1, tool_loop.get_iter(bufnr))
        tool_loop.process_response(bufnr, "", {})
        assert.equals(0, tool_loop.get_iter(bufnr))
    end)
end)

describe("tool_loop.process_response: with tool_use", function()
    local scratch_file
    before_each(function()
        registry.register_builtins()
        scratch_file = tmp_base .. "/sample-" .. math.random(0, 0xFFFFFF) .. ".txt"
        vim.fn.writefile({ "line 1", "line 2" }, scratch_file)
    end)

    it("writes 🔧: and 📎: blocks to the buffer and returns 'recurse'", function()
        local bufnr = mk_buffer({ "💬: read this file", "🤖: [Claude]" })
        local raw = mk_read_file_sse_response("toolu_LOOP_1", scratch_file)

        local outcome = tool_loop.process_response(bufnr, raw, {
            max_tool_iterations = 20,
            tool_result_max_bytes = 102400,
            cwd = tmp_base, -- scratch_file lives under tmp_base
        })
        assert.equals("recurse", outcome)

        local text = buf_text(bufnr)
        -- Tool use block was written
        assert.matches("🔧: read_file id=toolu_LOOP_1", text)
        -- Tool result block was written
        assert.matches("📎: read_file id=toolu_LOOP_1", text)
        -- Tool result content includes the scratch file's content
        assert.matches("line 1", text)
        assert.matches("line 2", text)
    end)

    it("increments iter counter on recurse", function()
        local bufnr = mk_buffer({ "💬: q", "🤖: [Claude]" })
        local raw = mk_read_file_sse_response("toolu_ITER", scratch_file)
        tool_loop.process_response(bufnr, raw, { max_tool_iterations = 20, cwd = tmp_base })
        assert.equals(1, tool_loop.get_iter(bufnr))
    end)

    it("stops with 'done' when max_tool_iterations is hit (cap behavior)", function()
        local bufnr = mk_buffer({ "💬: q", "🤖: [Claude]" })
        -- Pre-set iter to the cap
        tool_loop.increment_iter(bufnr)
        tool_loop.increment_iter(bufnr)
        tool_loop.increment_iter(bufnr)
        assert.equals(3, tool_loop.get_iter(bufnr))

        local raw = mk_read_file_sse_response("toolu_CAP", scratch_file)
        local outcome = tool_loop.process_response(bufnr, raw, { max_tool_iterations = 3, cwd = tmp_base })
        -- At the cap, process_response returns "done" without recursing further.
        -- (M4 Task 4.1 will add a synthetic 📎: (iteration limit reached)
        -- result for better UX; M2 just stops.)
        assert.equals("done", outcome)
    end)

    it("handles tool execution errors gracefully (cwd-scope rejection)", function()
        -- A path OUTSIDE cwd should trigger dispatcher.execute_call's
        -- safety prelude which returns an error ToolResult. tool_loop
        -- still writes the 📎: error block and continues.
        local bufnr = mk_buffer({ "💬: q", "🤖: [Claude]" })
        -- Path that's not inside cwd — construct a sibling tmp file
        local outside = tmp_base .. "/outside-" .. math.random(0, 0xFFFFFF) .. ".txt"
        vim.fn.writefile({ "secret" }, outside)
        -- Set cwd to a narrow dir that doesn't contain `outside`
        local cwd = tmp_base .. "/narrow-" .. math.random(0, 0xFFFFFF)
        vim.fn.mkdir(cwd, "p")

        local raw = mk_read_file_sse_response("toolu_ERR", outside)
        local outcome = tool_loop.process_response(bufnr, raw, {
            max_tool_iterations = 20,
            cwd = cwd,
        })
        assert.equals("recurse", outcome)

        local text = buf_text(bufnr)
        assert.matches("🔧: read_file id=toolu_ERR", text)
        assert.matches("📎: read_file id=toolu_ERR", text)
        assert.matches("error=true", text)
        assert.matches("outside working directory", text)
    end)

    it("emits 📎: result in dynamic-fence form that survives backticks in file content", function()
        -- Put backticks in the scratch file content to verify the
        -- fence-length logic from serialize.render_result picks a
        -- fence longer than any backtick run in the body.
        local back_file = tmp_base .. "/back-" .. math.random(0, 0xFFFFFF) .. ".md"
        vim.fn.writefile({ "```lua", "local x = 1", "```" }, back_file)

        local bufnr = mk_buffer({ "💬: q", "🤖: [Claude]" })
        local raw = mk_read_file_sse_response("toolu_BACK", back_file)
        tool_loop.process_response(bufnr, raw, { max_tool_iterations = 20, cwd = tmp_base })

        local text = buf_text(bufnr)
        -- The rendered 📎: must use 4+ backticks to survive the
        -- 3-backtick run in the file content.
        assert.matches("````", text)
    end)
end)
