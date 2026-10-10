-- parley.session_sync — turn-based shared markdown (#313).
--
-- A markdown file whose frontmatter says `type: session-sync` is shared
-- between the operator and the agent named by `owner:` (a couch address).
-- The sidecar `<file>.lock` names whose turn it is:
--   absent           free      — the agent may write; the operator's first
--                                 edit takes the turn (holder: operator)
--   holder: operator the operator's turn — the agent never writes the file
--   holder: agent    the agent's turn — the buffer is read-only
-- <M-CR> saves, rewrites the holder to agent and tells the owner via
-- `couch --send-to`. The agent replies by rewriting the file and deleting the
-- lock (it never writes the lock); a poll notices, reloads and unlocks.
-- The turn is always read from disk, so a reopened buffer shows it too.
--
-- Lifecycles: the lock is removed by the agent's reply; an operator lock left
-- idle turns stale and is shown in the reminder colour until submitted. The
-- poll timer lives only while the agent holds the turn (closed on any other
-- turn or BufWipeout); the idle timer is one per buffer, replaced on each edit.

local M = {}

M.POLL_MS = 1000

local ns_group = "ParleySessionSync"

-- Per-buffer state: { poll = timer|nil, idle = timer|nil, stale = bool }
local state = {}

--- Frontmatter lines → { owner, operator } when `type: session-sync`, else nil.
---@param lines string[]
---@return table|nil
M.parse_header = function(lines)
	if lines[1] ~= "---" then
		return nil
	end
	local fm = {}
	for i = 2, #lines do
		if lines[i] == "---" then
			if fm.type ~= "session-sync" then
				return nil
			end
			return { owner = fm.owner, operator = fm.operator }
		end
		local key, value = lines[i]:match("^([%w_]+):%s*(.-)%s*$")
		if key then
			value = value:gsub("%s+#.*$", "")
			fm[key:lower()] = value ~= "" and value or nil
		end
	end
	return nil
end

--- The lock sidecar's text for a turn holder ("operator" | "agent").
M.lock_body = function(holder, epoch)
	return "holder: " .. holder .. "\ntime: " .. os.date("!%Y-%m-%dT%H:%M:%SZ", epoch) .. "\n"
end

--- Lock text (nil = no lock) → "free" | "operator" | "agent". A lock without
--- a recognisable holder still blocks the agent, so it counts as the operator's.
M.turn = function(lock_text)
	if not lock_text then
		return "free"
	end
	return lock_text:match("^holder:%s*agent%s*\n") and "agent" or "operator"
end

local VIEWS = {
	free = { hl = "ParleySessionSyncFree", label = "free: editing takes your turn" },
	operator = { hl = "ParleySessionSyncOperator", label = "your turn, Alt+Return to submit" },
	stale = { hl = "ParleySessionSyncStale", label = "unsent edits, Alt+Return to submit" },
	agent = { hl = "ParleySessionSyncAgent", label = "%s working, read-only" },
}

--- (turn, stale, owner) → { state, label, hl }: what every surface renders.
M.view = function(turn, stale, owner)
	local key = (turn == "operator" and stale) and "stale" or turn
	local v = VIEWS[key]
	return { state = key, label = v.label:format(owner or "agent"), hl = v.hl }
end

local function header(buf)
	return M.parse_header(vim.api.nvim_buf_get_lines(buf, 0, 40, false))
end

M.is_session_sync = function(buf)
	return header(buf) ~= nil
end

local function file_of(buf)
	return vim.fn.fnamemodify(vim.api.nvim_buf_get_name(buf), ":p")
end

M.lock_path = function(buf)
	return file_of(buf) .. ".lock"
end

local function read_turn(buf)
	local f = io.open(M.lock_path(buf), "r")
	if not f then
		return "free"
	end
	local text = f:read("*a")
	f:close()
	return M.turn(text)
end

local function notify(msg, level)
	vim.notify("session-sync: " .. msg, level or vim.log.levels.INFO)
end

local function write_lock(buf, holder)
	local path = M.lock_path(buf)
	local f = io.open(path, "w")
	if not f then
		notify("cannot write " .. path, vim.log.levels.ERROR)
		return false
	end
	f:write(M.lock_body(holder, os.time()))
	f:close()
	return true
end

local function close_timer(timer)
	if timer and not timer:is_closing() then
		timer:stop()
		timer:close()
	end
end

--- The buffer's current view, or nil when it is not an attached session-sync buffer.
M.status = function(buf)
	local s = state[buf]
	if not s or not vim.api.nvim_buf_is_valid(buf) then
		return nil
	end
	local h = header(buf) or {}
	return M.view(read_turn(buf), s.stale, h.owner)
end

local function render(buf, view)
	for _, win in ipairs(vim.fn.win_findbuf(buf)) do
		local opts = { win = win, scope = "local" }
		vim.api.nvim_set_option_value("winhighlight", "StatusLine:" .. view.hl, opts)
		vim.api.nvim_set_option_value("winbar", "%#" .. view.hl .. "# " .. view.label .. " %*", opts)
	end
	if package.loaded["lualine"] then
		pcall(require("lualine").refresh)
	end
end

local refresh

-- Poll the lock while the agent holds the turn; its removal is the reply.
local function start_poll(buf, owner)
	local s = state[buf]
	if s.poll then
		return
	end
	local timer = vim.uv.new_timer()
	s.poll = timer
	timer:start(M.POLL_MS, M.POLL_MS, vim.schedule_wrap(function()
		if s.poll ~= timer or not vim.api.nvim_buf_is_valid(buf) then
			close_timer(timer)
			return
		end
		local turn = read_turn(buf)
		if turn == "agent" then
			return
		end
		if turn == "free" then
			vim.bo[buf].modifiable = true
			vim.api.nvim_buf_call(buf, function()
				vim.cmd("silent edit!")
			end)
			notify((owner or "agent") .. " replied")
		end
		refresh(buf)
	end))
end

-- Apply the on-disk turn: read-only while the agent holds it, poll only then.
refresh = function(buf)
	local s = state[buf]
	if not s or not vim.api.nvim_buf_is_valid(buf) then
		return
	end
	local h = header(buf) or {}
	local turn = read_turn(buf)
	if turn ~= "operator" then
		s.stale = false
	end
	vim.bo[buf].modifiable = turn ~= "agent"
	if turn == "agent" then
		start_poll(buf, h.owner)
	else
		close_timer(s.poll)
		s.poll = nil
	end
	render(buf, M.view(turn, s.stale, h.owner))
end

-- Restart the idle timer; when it fires with the operator still holding the
-- turn, the lock is stale and renders in the reminder colour.
local function restart_idle(buf)
	local s = state[buf]
	close_timer(s.idle)
	s.idle = nil
	if s.stale then
		s.stale = false
		refresh(buf)
	end
	if read_turn(buf) ~= "operator" then
		return
	end
	local minutes = require("parley").config.session_sync_stale_minutes or 5
	local timer = vim.uv.new_timer()
	s.idle = timer
	timer:start(math.floor(minutes * 60000), 0, vim.schedule_wrap(function()
		close_timer(timer)
		if s.idle ~= timer then
			return
		end
		s.idle = nil
		if vim.api.nvim_buf_is_valid(buf) and read_turn(buf) == "operator" then
			s.stale = true
			refresh(buf)
		end
	end))
end

local function define_highlights()
	local links = {
		ParleySessionSyncFree = "StatusLine",
		ParleySessionSyncOperator = "DiffAdd",
		ParleySessionSyncStale = "DiffDelete",
		ParleySessionSyncAgent = "DiffChange",
	}
	for name, target in pairs(links) do
		vim.api.nvim_set_hl(0, name, { link = target, default = true })
	end
end

--- Install the turn autocmds on a session-sync buffer and render its turn. Idempotent.
M.attach = function(buf)
	if state[buf] or not M.is_session_sync(buf) then
		return
	end
	state[buf] = { stale = false }
	define_highlights()
	vim.bo[buf].autoread = true
	local group = vim.api.nvim_create_augroup(ns_group .. buf, { clear = true })
	-- The first edit takes the turn; every edit restarts the idle timer.
	-- BufModifiedSet catches the first keystroke in either mode (it fires from
	-- the main loop, not from API edits); TextChanged[I] the later ones.
	vim.api.nvim_create_autocmd({ "BufModifiedSet", "TextChanged", "TextChangedI" }, {
		group = group,
		buffer = buf,
		callback = function()
			if vim.bo[buf].modified and vim.bo[buf].modifiable and read_turn(buf) == "free"
				and M.is_session_sync(buf) and write_lock(buf, "operator") then
				refresh(buf)
			end
			restart_idle(buf)
		end,
	})
	vim.api.nvim_create_autocmd("BufWinEnter", {
		group = group,
		buffer = buf,
		callback = function()
			refresh(buf)
		end,
	})
	vim.api.nvim_create_autocmd("BufWipeout", {
		group = group,
		buffer = buf,
		callback = function()
			local s = state[buf]
			if s then
				close_timer(s.poll)
				close_timer(s.idle)
			end
			state[buf] = nil
			pcall(vim.api.nvim_del_augroup_by_id, group)
		end,
	})
	refresh(buf)
end

--- <M-CR>: save, hand the turn to the agent, tell the owner.
M.submit = function(buf)
	local h = header(buf)
	if not h or not h.owner then
		notify("no `owner:` in the frontmatter", vim.log.levels.ERROR)
		return
	end
	M.attach(buf)
	if read_turn(buf) == "agent" then
		notify("already submitted to " .. h.owner .. "; waiting for its reply", vim.log.levels.WARN)
		return
	end
	vim.cmd("stopinsert")
	vim.api.nvim_buf_call(buf, function()
		vim.cmd("silent write")
	end)
	if not write_lock(buf, "agent") then
		return
	end
	refresh(buf)
	local function fail(why)
		write_lock(buf, "operator")
		refresh(buf)
		notify("send to " .. h.owner .. " failed, your turn again: " .. why, vim.log.levels.ERROR)
	end
	local argv = { "couch", "--send-to", h.owner, "--message", "submitted: " .. file_of(buf) }
	local ok, err = pcall(vim.system, argv, { text = true }, vim.schedule_wrap(function(obj)
		if not state[buf] then
			return
		end
		if obj.code ~= 0 then
			fail(vim.trim(obj.stderr or ""))
			return
		end
		notify("submitted to " .. h.owner)
	end))
	if not ok then
		fail(tostring(err))
	end
end

--- Manual escape when the owner never replies: the operator takes the turn
--- back (holder: operator); <M-CR> resubmits.
M.unlock = function(buf)
	-- Bound in every markdown buffer (the registry's no-ghost contract).
	if not state[buf] then
		notify("not a session-sync file", vim.log.levels.WARN)
		return
	end
	if read_turn(buf) ~= "agent" then
		notify("not waiting on the agent")
		return
	end
	write_lock(buf, "operator")
	refresh(buf)
	restart_idle(buf)
	notify("your turn again; Alt+Return resubmits")
end

--- The <M-CR> callback: submit in a session-sync buffer, else `fallback`.
--- Decided at call time, so editing the frontmatter takes effect at once.
M.dispatch = function(buf, fallback)
	return function()
		if M.is_session_sync(buf) then
			M.submit(buf)
		else
			fallback()
		end
	end
end

return M
