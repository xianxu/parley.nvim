local parley = require("parley")
local Registry = require("parley.keybinding_registry")

local root = (os.getenv("TMPDIR") or "/tmp") .. "/parley-test-private-prefix-" .. os.time()

local function prepped(lines, extra)
	parley.setup(vim.tbl_extend("force", {
		chat_dir = root .. "/chats",
		state_dir = root .. "/state",
		providers = {},
		api_keys = {},
	}, extra or {}))
	vim.fn.mkdir(parley.config.chat_dir, "p")
	local path = parley.config.chat_dir .. "/2026-03-01-private.md"
	vim.fn.writefile(lines, path)
	vim.cmd("silent edit! " .. vim.fn.fnameescape(path))
	local buf = vim.api.nvim_get_current_buf()
	parley.prep_chat(buf, path)
	return buf
end

describe("private note prefix shortcut", function()
	after_each(function()
		vim.cmd("stopinsert")
		local buf = vim.api.nvim_get_current_buf()
		if vim.api.nvim_buf_is_valid(buf) then vim.api.nvim_buf_delete(buf, { force = true }) end
	end)
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
	for _, mode in ipairs({ "normal", "insert" }) do
		it("types after a custom prefix from real " .. mode .. " mode", function()
			local prefix = "PRIVATE:"
			local buf = prepped({ "💬: question", "answer", "following line" }, {
				chat_local_prefix = prefix,
			})
			vim.api.nvim_win_set_cursor(0, { 2, 2 })
			local key = Registry.key_for("private_note", parley.config)
			local lead = mode == "insert" and "A typed first" or ""
			local keys = vim.api.nvim_replace_termcodes(lead .. key .. " my note<Esc>", true, false, true)
			vim.api.nvim_feedkeys(keys, "x", false)
			assert.same({ "💬: question", mode == "insert" and "answer typed first" or "answer",
				"PRIVATE: my note", "following line" }, vim.api.nvim_buf_get_lines(buf, 0, -1, false))
			assert.same({ 3, #("PRIVATE: my note") - 1 }, vim.api.nvim_win_get_cursor(0))
		end)
	end
end)
