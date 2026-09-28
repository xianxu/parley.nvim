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

describe("private note Return continuation", function()
    local function chat(line, extra)
        local buf = prepped({ "# topic: notes", "- file: notes.md", "---", "", line }, extra)
        assert.is_true(parley._prepared_bufs[buf])
        vim.api.nvim_win_set_cursor(0, { 5, 0 })
        return buf
    end
    local function keys(value)
        vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes(value, true, false, true), "x", false)
    end
    local function body(buf)
        return vim.api.nvim_buf_get_lines(buf, 4, -1, false)
    end
    after_each(function()
        vim.cmd("stopinsert")
        vim.api.nvim_buf_delete(0, { force = true })
    end)
    it("continues successive private lines and preserves native undo", function()
        local buf = chat("🔒: first")
        keys("A<CR>second<CR><CR>third<Esc>")
        assert.same({ "🔒: first", "🔒: second", "🔒:", "🔒: third" }, body(buf))
        keys("u")
        assert.same({ "🔒: first" }, body(buf))
    end)
    it("keeps both parts private when splitting within note text", function()
        local buf = chat("🔒: first second")
        vim.api.nvim_win_set_cursor(0, { 5, #("🔒: first ") })
        keys("i<CR><Esc>")
        assert.same({ "🔒: first ", "🔒: second" }, body(buf))
    end)
    for _, prefix in ipairs({ "PRIVATE:", "NOTE,:", "NOTE\\:" }) do
        it("continues the literal configured prefix " .. prefix, function()
            local buf = chat(prefix .. "first", { chat_local_prefix = prefix })
            keys("A<CR>second<Esc>")
            assert.same({ prefix .. "first", prefix .. "second" }, body(buf))
        end)
    end
    it("keeps chat preparation usable when a prefix is not a native comment leader", function()
        local buf = chat("NOTE\\,: first", { chat_local_prefix = "NOTE\\,:" })
        assert.is_truthy(vim.fn.maparg(Registry.key_for("private_note", parley.config), "i", false, true).callback)
        assert.is_nil(vim.bo[buf].comments:find("NOTE", 1, true))
    end)
    it("leaves ordinary prose and Return mappings alone", function()
        local buf = chat("ordinary text")
        assert.same({}, vim.fn.maparg("<CR>", "i", false, true))
        keys("A<CR>next<Esc>")
        assert.same({ "ordinary text", "next" }, body(buf))
    end)
    it("preserves an existing Return mapping", function()
        vim.keymap.set("i", "<CR>", "<CR>mapped")
        local ok, err = pcall(function()
            local buf = chat("🔒: first")
            keys("A<CR><Esc>")
            assert.same({ "🔒: first", "🔒: mapped" }, body(buf))
        end)
        vim.keymap.del("i", "<CR>")
        assert.is_true(ok, tostring(err))
    end)
    it("leaves prompt-buffer Return ownership intact", function()
        local buf = chat("🔒: first", { chat_prompt_buf_type = true })
        assert.equals("prompt", vim.bo[buf].buftype)
        assert.is_nil(vim.bo[buf].comments:find("🔒:", 1, true))
    end)
    it("composes with spell typeahead Return", function()
        local buf = chat("🔒: first", { chat_spell = { typeahead = true } })
        assert.is_truthy(vim.fn.maparg("<CR>", "i", false, true).callback)
        keys("A<CR>second<Esc>")
        assert.same({ "🔒: first", "🔒: second" }, body(buf))
    end)
    it("does not enable continuation for non-chat markdown", function()
        local buf = prepped({ "🔒: first" })
        local comments, format = vim.bo[buf].comments, vim.bo[buf].formatoptions
        parley.prep_chat(buf, vim.api.nvim_buf_get_name(buf))
        assert.equals(comments, vim.bo[buf].comments)
        assert.equals(format, vim.bo[buf].formatoptions)
        keys("A<CR>second<Esc>")
        assert.same({ "🔒: first", "second" }, vim.api.nvim_buf_get_lines(buf, 0, -1, false))
    end)
end)
