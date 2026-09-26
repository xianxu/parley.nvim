local parley = require("parley")
local Registry = require("parley.keybinding_registry")

local root = (os.getenv("TMPDIR") or "/tmp") .. "/parley-test-private-prefix-" .. os.time()

local function prepped(lines)
	parley.setup({
		chat_dir = root .. "/chats",
		state_dir = root .. "/state",
		providers = {},
		api_keys = {},
	})
	vim.fn.mkdir(parley.config.chat_dir, "p")
	local path = parley.config.chat_dir .. "/2026-03-01-private.md"
	vim.fn.writefile(lines, path)
	vim.cmd("silent edit! " .. vim.fn.fnameescape(path))
	local buf = vim.api.nvim_get_current_buf()
	parley.prep_chat(buf, path)
	return buf
end

describe("private note prefix shortcut", function()
	it("inserts the configured prefix on a new line below the cursor", function()
		local buf = prepped({ "💬: question", "answer" })
		vim.api.nvim_win_set_cursor(0, { 2, 3 })

		local key = Registry.key_for("private_note", parley.config)
		assert.equals("<M-p>", key)
		local mapping = vim.fn.maparg(key, "n", false, true)
		assert.equals("function", type(mapping.callback))
		assert.equals("function", type(vim.fn.maparg(key, "i", false, true).callback))
		mapping.callback()

		assert.same({ "💬: question", "answer", "🔒:" },
			vim.api.nvim_buf_get_lines(buf, 0, -1, false))
		assert.same({ 3, #("🔒:") }, vim.api.nvim_win_get_cursor(0))
	end)
end)
