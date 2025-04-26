--------------------------------------------------------------------------------
-- :checkhealth parley
--------------------------------------------------------------------------------

local M = {}

function M.check()
	vim.health.start("Parley.nvim checks")

	local ok, parley = pcall(require, "parley")
	if not ok then
		vim.health.error("require('parley') failed")
	else
		vim.health.ok("require('parley') succeeded")

		if parley._setup_called then
			vim.health.ok("require('parley').setup() has been called")
		else
			vim.health.error("require('parley').setup() has not been called")
		end
	end

	if vim.fn.executable("curl") == 1 then
		vim.health.ok("curl is installed")
	else
		vim.health.error("curl is not installed")
	end

	if vim.fn.executable("grep") == 1 then
		vim.health.ok("grep is installed")
	else
		vim.health.error("grep is not installed")
	end

	-- Whisper module removed in simplified version
	require("parley.deprecator").check_health()
end

return M
