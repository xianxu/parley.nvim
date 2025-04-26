--------------------------------------------------------------------------------
-- Render module for logic related to visualization
--------------------------------------------------------------------------------

local logger = require("parley.logger")
local helpers = require("parley.helper")
local tasker = require("parley.tasker")

local M = {}

---@param template string # template string
---@param key string # key to replace
---@param value string | table | nil # value to replace key with (nil => "")
---@return string # returns rendered template with specified key replaced by value
M.template_replace = function(template, key, value)
	value = value or ""

	if type(value) == "table" then
		value = table.concat(value, "\n")
	end

	value = value:gsub("%%", "%%%%")
	template = template:gsub(key, value)
	template = template:gsub("%%%%", "%%")
	return template
end

---@param template string # template string
---@param key_value_pairs table # table with key value pairs
---@return string # returns rendered template with keys replaced by values from key_value_pairs
M.template = function(template, key_value_pairs)
	for key, value in pairs(key_value_pairs) do
		template = M.template_replace(template, key, value)
	end

	return template
end

---@param template string # template string
---@param command string | nil # command
---@param selection string | nil # selection
---@param filetype string | nil # filetype
---@param filename string | nil # filename
M.prompt_template = function(template, command, selection, filetype, filename)
	local git_root = helpers.find_git_root(filename)
	if git_root ~= "" then
		local git_root_plus_one = vim.fn.fnamemodify(git_root, ":h")
		if git_root_plus_one ~= "" then
			filename = filename or ""
			filename = filename:sub(#git_root_plus_one + 2)
		end
	end

	local key_value_pairs = {
		["{{command}}"] = command,
		["{{selection}}"] = selection,
		["{{filetype}}"] = filetype,
		["{{filename}}"] = filename,
	}
	return M.template(template, key_value_pairs)
end

return M
