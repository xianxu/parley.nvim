-- Alt+Return retains the existing Couch/session and local invocation owners.
local M = {}
local function notify(msg, level)
    require('parley.review_notice').show({msg},
        msg == 'local review requested' and 'review: local review requested' or 'review: save file first',
        level or vim.log.levels.INFO)
end

M.submit = function(buf)
	if require("parley.agentic_document").submit(buf) then return end
	if require("parley.session_sync").is_session_sync(buf) then
		require("parley.session_sync").submit(buf)
		return
	end
	if vim.api.nvim_buf_get_name(buf) == "" then
		notify("save the file first: the agent reads it from disk", vim.log.levels.ERROR)
		return
	end
	notify("local review requested")
	require("parley.skills.review").run_via_invoke(buf, {})
end

return M
