local markdown_finder = require("parley.markdown_finder")
local float_picker = require("parley.float_picker")

local fixture = vim.fn.getcwd() .. "/tests/fixtures/fake_git_file_list"

local function close_floats()
	for _, win in ipairs(vim.api.nvim_list_wins()) do
		local ok, config = pcall(vim.api.nvim_win_get_config, win)
		if ok and config.relative ~= "" then
			pcall(vim.api.nvim_win_close, win, true)
		end
	end
	vim.wait(50, function() return false end, 10)
end

local function picker_lines()
	local lines = {}
	for _, win in ipairs(vim.api.nvim_list_wins()) do
		local ok, config = pcall(vim.api.nvim_win_get_config, win)
		if ok and config.relative ~= "" then
			local buf = vim.api.nvim_win_get_buf(win)
			if vim.bo[buf].buftype == "nofile" then
				for _, line in ipairs(vim.api.nvim_buf_get_lines(buf, 0, -1, false)) do
					lines[#lines + 1] = line
				end
			end
		end
	end
	return lines
end

local function line_containing(needle)
	for _, line in ipairs(picker_lines()) do
		if line:find(needle, 1, true) then
			return line
		end
	end
end

local function git(root, ...)
	local command = { vim.fn.exepath("git"), "-C", root, ... }
	vim.fn.system(command)
	assert.equals(0, vim.v.shell_error, table.concat(command, " "))
end

local function parley_for(root, warnings, dependencies)
	return {
		_markdown_finder = {},
		config = { repo_root = root, markdown_finder_max_depth = 4 },
		super_repo = { get_state = function() return { active = false, members = {} } end },
		helpers = { find_git_root = function() return root end },
		logger = { warning = function(message) warnings[#warnings + 1] = message end },
		_finder_dependencies = dependencies,
		float_picker = float_picker,
		open_buf = function() end,
	}
end

describe("real asynchronous Markdown finder", function()
	local root
	local warnings

	before_each(function()
		root = vim.fn.tempname() .. "-delayed-markdown"
		warnings = {}
		vim.fn.mkdir(root, "p")
		assert((vim.uv or vim.loop).fs_chmod(fixture, 493))
	end)

	after_each(function()
		close_floats()
		markdown_finder.setup(require("parley"))
		vim.fn.delete(root, "rf")
	end)

	it("runs a scheduled sentinel and spinner tick before delayed Git settles", function()
		vim.fn.writefile({ "# late" }, root .. "/late.md")
		markdown_finder.setup(parley_for(root, warnings, { git_executable = fixture }))
		local sentinel = false
		vim.schedule(function() sentinel = true end)

		markdown_finder.open()
		local initial = line_containing("scanning…")
		assert.is_not_nil(initial)
		assert(vim.wait(1000, function()
			local current = line_containing("scanning…")
			return sentinel and current ~= nil and current ~= initial
		end, 10), "spinner did not tick while Git remained pending")
		assert(vim.wait(3000, function() return line_containing("late.md") ~= nil end, 10),
			"delayed Markdown result did not settle; lines=" .. table.concat(picker_lines(), " | ")
				.. "; warnings=" .. table.concat(warnings, " | "))
		assert.same({}, warnings)
	end)

	it("excludes a tracked Markdown symlink whose target is a directory", function()
		git(root, "init", "-q")
		vim.fn.mkdir(root .. "/target", "p")
		vim.fn.writefile({ "# hidden" }, root .. "/target/hidden.md")
		vim.fn.writefile({ "# regular" }, root .. "/regular.md")
		assert((vim.uv or vim.loop).fs_symlink(root .. "/target", root .. "/directory.md"))
		git(root, "add", "regular.md", "directory.md")
		markdown_finder.setup(parley_for(root, warnings))

		markdown_finder.open()
		assert(vim.wait(3000, function() return line_containing("regular.md") ~= nil end, 10),
			"real Git Markdown result did not settle; lines=" .. table.concat(picker_lines(), " | ")
				.. "; warnings=" .. table.concat(warnings, " | "))

		assert.is_nil(line_containing("directory.md"))
		assert.equals(1, #warnings)
		assert.truthy(warnings[1]:find("1 files", 1, true))
	end)
end)
