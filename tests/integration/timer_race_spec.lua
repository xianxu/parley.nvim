-- Integration regression tests for timer replacement races in parley.init.
--
-- These tests mock vim.uv.new_timer to deterministically exercise stale callbacks
-- from replaced timers. The goal is to catch "handle ... is already closing"
-- schedule callback errors early.

local tmp_dir = vim.fn.tempname() .. "-parley-timer-race"
vim.fn.mkdir(tmp_dir, "p")

local parley = require("parley")
parley.setup({
	chat_dir = tmp_dir,
	state_dir = tmp_dir .. "/state",
	providers = {},
	api_keys = {},
})

local function write_markdown_file(name, lines)
	local path = tmp_dir .. "/" .. name
	vim.fn.writefile(lines, path)
	return path
end

local function cleanup_buffers()
	for _, buf in ipairs(vim.api.nvim_list_bufs()) do
		if vim.api.nvim_buf_is_valid(buf) and vim.api.nvim_buf_get_option(buf, "buftype") == "" then
			pcall(vim.api.nvim_buf_delete, buf, { force = true })
		end
	end
end

local function install_fake_timers()
	local original_new_timer = vim.uv.new_timer
	local timers = {}

	vim.uv.new_timer = function()
		local timer = {
			closed = false,
			callback = nil,
			close_count = 0,
			stop_count = 0,
		}

		function timer:start(_, _, cb)
			self.callback = cb
		end

		function timer:stop()
			self.stop_count = self.stop_count + 1
		end

		function timer:is_closing()
			return self.closed
		end

		function timer:close()
			if self.closed then
				error("handle is already closing")
			end
			self.closed = true
			self.close_count = self.close_count + 1
		end

		table.insert(timers, timer)
		return timer
	end

	return timers, function()
		vim.uv.new_timer = original_new_timer
	end
end

local function clear_errmsg()
	vim.v.errmsg = ""
end

local function assert_no_async_errors(context)
	vim.wait(50)
	local errmsg = tostring(vim.v.errmsg or "")
	assert.are.same("", errmsg, context .. ": unexpected async error: " .. errmsg)
end

describe("timer replacement race safety", function()
	local restore_new_timer = nil

	after_each(function()
		if restore_new_timer then
			restore_new_timer()
			restore_new_timer = nil
		end
		cleanup_buffers()
		clear_errmsg()
	end)

	it("stale highlight debounce callback does not double-close timer", function()
		local timers
		timers, restore_new_timer = install_fake_timers()

		local file = write_markdown_file("notes-cursor-race.md", {
			"# Notes",
			"line 1",
			"line 2",
		})
		vim.cmd("edit " .. vim.fn.fnameescape(file))
		local buf = vim.api.nvim_get_current_buf()

		-- CursorMoved triggers highlight debounce without also triggering save debounce.
		vim.api.nvim_exec_autocmds("CursorMoved", { buffer = buf, modeline = false })
		vim.wait(20)
		vim.api.nvim_exec_autocmds("CursorMoved", { buffer = buf, modeline = false })
		vim.wait(20)

		assert.are.same(2, #timers)
		assert.is_true(timers[1].closed, "first timer should be closed when replaced")
		assert.is_not_nil(timers[1].callback)
		assert.is_not_nil(timers[2].callback)

		clear_errmsg()
		timers[1].callback()
		assert_no_async_errors("stale highlight callback")
		assert.are.same(1, timers[1].close_count, "stale callback must not re-close old timer")

		clear_errmsg()
		timers[2].callback()
		assert_no_async_errors("active highlight callback")
	end)

	it("stale markdown topic callback does not double-close timer", function()
		local timers
		timers, restore_new_timer = install_fake_timers()

		local missing_chat_path = tmp_dir .. "/missing-chat-" .. tostring(math.random(100000)) .. ".md"
		local file = write_markdown_file("notes-topic-race.md", {
			"@@"
				.. missing_chat_path,
			"plain line",
		})
		vim.cmd("edit " .. vim.fn.fnameescape(file))
		local buf = vim.api.nvim_get_current_buf()

		parley.highlight_markdown_chat_refs(buf)
		parley.highlight_markdown_chat_refs(buf)

		assert.are.same(2, #timers)
		assert.is_true(timers[1].closed, "first timer should be closed when replaced")
		assert.is_not_nil(timers[1].callback)
		assert.is_not_nil(timers[2].callback)

		clear_errmsg()
		timers[1].callback()
		assert_no_async_errors("stale markdown topic callback")
		assert.are.same(1, timers[1].close_count, "stale callback must not re-close old timer")

		clear_errmsg()
		timers[2].callback()
		assert_no_async_errors("active markdown topic callback")
	end)
end)
