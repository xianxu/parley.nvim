-- #294: Neovim 0.12's markdown ftplugin starts treesitter on every markdown
-- buffer. Chats are drawn by parley's highlighter, and a second full-buffer
-- parse on every edit doubled the cost of chat edits, so chat buffers stop it.
-- Treesitter is started by hand here, so the cases hold on 0.11 too, whose
-- ftplugin never starts it.
local parley = require("parley")

local root = (os.getenv("TMPDIR") or "/tmp") .. "/parley-test-chat-treesitter-" .. vim.fn.getpid()

local function active(buf)
	return vim.treesitter.highlighter.active[buf] ~= nil
end

local function open_chat()
	parley.setup({ chat_dir = root .. "/chats", state_dir = root .. "/state", providers = {}, api_keys = {} })
	vim.fn.mkdir(parley.config.chat_dir, "p")
	local path = parley.config.chat_dir .. "/2026-10-01-treesitter.md"
	vim.fn.writefile({ "---", "topic: treesitter", "file: 2026-10-01-treesitter.md", "---", "", "💬: question" }, path)
	vim.cmd("noautocmd silent edit! " .. vim.fn.fnameescape(path))
	local buf = vim.api.nvim_get_current_buf()
	vim.bo[buf].filetype = "markdown"
	vim.treesitter.start(buf, "markdown")
	assert.is_true(active(buf), "precondition: treesitter could not start on the chat")
	return buf, path
end

describe("chat buffers and treesitter", function()
	after_each(function()
		local buf = vim.api.nvim_get_current_buf()
		if vim.api.nvim_buf_is_valid(buf) then vim.api.nvim_buf_delete(buf, { force = true }) end
		vim.fn.delete(root, "rf")
	end)

	it("stops the treesitter highlighter the markdown ftplugin started", function()
		local buf, path = open_chat()
		parley.prep_chat(buf, path)
		assert.is_false(active(buf))
	end)

	it("stops it again when the filetype is set again", function()
		local buf, path = open_chat()
		parley.prep_chat(buf, path)
		vim.treesitter.start(buf, "markdown")
		vim.bo[buf].filetype = "markdown"
		assert.is_false(active(buf))
	end)

	it("leaves markdown that is not a chat alone", function()
		local path = root .. "/notes.md"
		vim.fn.mkdir(root, "p")
		vim.fn.writefile({ "# notes" }, path)
		vim.cmd("silent edit! " .. vim.fn.fnameescape(path))
		local buf = vim.api.nvim_get_current_buf()
		vim.treesitter.start(buf, "markdown")
		parley.prep_chat(buf, path)
		assert.is_true(active(buf))
	end)
end)
