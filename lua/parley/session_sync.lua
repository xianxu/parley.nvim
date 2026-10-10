-- parley.session_sync — turn-based shared markdown (#313).
--
-- A markdown file whose frontmatter says `type: session-sync` is shared
-- between the operator and the agent named by `owner:` (a couch address).
-- The agent holds the file by default. The operator's first edit writes the
-- sidecar `<file>.lock`; while it exists the agent never writes the file.
-- <M-CR> saves, makes the buffer read-only and tells the owner via
-- `couch --send-to`. The owner replies by rewriting the file and deleting the
-- lock; a poll notices, reloads the buffer and makes it editable again.
--
-- Lifecycles: the lock is removed by the owner's reply (the stale reminder
-- nags the operator to submit until then); the poll timer lives from a
-- successful send to the reply, a manual unlock, or BufWipeout; the reminder
-- timer is one per buffer, replaced on each edit.

local M = {}

M.POLL_MS = 1000
M.REMINDER = "unsent edits: Alt+Return to submit"

local ns = vim.api.nvim_create_namespace("parley_session_sync")

-- Per-buffer state: { poll = timer|nil, idle = timer|nil, submitted = bool }
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

--- The lock sidecar's text.
---@param holder string
---@param epoch number
---@return string
M.lock_body = function(holder, epoch)
	return "holder: " .. holder .. "\ntime: " .. os.date("!%Y-%m-%dT%H:%M:%SZ", epoch) .. "\n"
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

local function close_timer(timer)
	if timer and not timer:is_closing() then
		timer:stop()
		timer:close()
	end
end

local function notify(msg, level)
	vim.notify("session-sync: " .. msg, level or vim.log.levels.INFO)
end

local function take_lock(buf)
	local path = M.lock_path(buf)
	if vim.uv.fs_stat(path) then
		return
	end
	local h = header(buf) or {}
	local f = io.open(path, "w")
	if not f then
		notify("cannot write " .. path, vim.log.levels.ERROR)
		return
	end
	f:write(M.lock_body(h.operator or vim.env.USER or "operator", os.time()))
	f:close()
end

local function clear_reminder(buf)
	if vim.api.nvim_buf_is_valid(buf) then
		vim.api.nvim_buf_clear_namespace(buf, ns, 0, -1)
	end
end

-- Restart the idle timer: when it fires with the lock held and nothing sent,
-- remind the operator their edits are unsent.
local function restart_idle(buf)
	local s = state[buf]
	close_timer(s.idle)
	s.idle = nil
	clear_reminder(buf)
	if s.submitted or not vim.uv.fs_stat(M.lock_path(buf)) then
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
		if vim.api.nvim_buf_is_valid(buf) and not s.submitted and vim.uv.fs_stat(M.lock_path(buf)) then
			vim.api.nvim_buf_set_extmark(buf, ns, 0, 0, {
				virt_text = { { M.REMINDER, "WarningMsg" } },
				virt_text_pos = "eol",
			})
		end
	end))
end

local function stop_waiting(buf)
	local s = state[buf]
	if s then
		close_timer(s.poll)
		s.poll = nil
		s.submitted = false
	end
	if vim.api.nvim_buf_is_valid(buf) then
		vim.bo[buf].modifiable = true
	end
end

-- Poll the lock while a submit is outstanding; its removal is the reply.
local function start_poll(buf, owner)
	local s = state[buf]
	local timer = vim.uv.new_timer()
	s.poll = timer
	timer:start(M.POLL_MS, M.POLL_MS, vim.schedule_wrap(function()
		if s.poll ~= timer or not vim.api.nvim_buf_is_valid(buf) then
			close_timer(timer)
			return
		end
		if vim.uv.fs_stat(M.lock_path(buf)) then
			return
		end
		stop_waiting(buf)
		vim.api.nvim_buf_call(buf, function()
			vim.cmd("silent edit!")
		end)
		vim.bo[buf].modifiable = true
		notify(owner .. " replied")
	end))
end

--- Install the lock / reminder autocmds on a session-sync buffer. Idempotent.
M.attach = function(buf)
	if state[buf] or not M.is_session_sync(buf) then
		return
	end
	state[buf] = { submitted = false }
	vim.bo[buf].autoread = true
	local group = vim.api.nvim_create_augroup("ParleySessionSync" .. buf, { clear = true })
	-- The first edit takes the lock; every edit restarts the idle reminder.
	-- BufModifiedSet catches the first keystroke in either mode (it fires from
	-- the main loop, not from API edits); TextChanged[I] the later ones.
	vim.api.nvim_create_autocmd({ "BufModifiedSet", "TextChanged", "TextChangedI" }, {
		group = group,
		buffer = buf,
		callback = function()
			if vim.bo[buf].modified and vim.bo[buf].modifiable and M.is_session_sync(buf) then
				take_lock(buf)
			end
			restart_idle(buf)
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
end

--- <M-CR>: save, go read-only, tell the owner.
M.submit = function(buf)
	local h = header(buf)
	if not h or not h.owner then
		notify("no `owner:` in the frontmatter", vim.log.levels.ERROR)
		return
	end
	M.attach(buf)
	local s = state[buf]
	if s.submitted then
		notify("already submitted to " .. h.owner .. "; waiting for its reply", vim.log.levels.WARN)
		return
	end
	vim.cmd("stopinsert")
	vim.api.nvim_buf_call(buf, function()
		vim.cmd("silent write")
	end)
	take_lock(buf)
	s.submitted = true
	close_timer(s.idle)
	s.idle = nil
	clear_reminder(buf)
	vim.bo[buf].modifiable = false
	local argv = { "couch", "--send-to", h.owner, "--message", "submitted: " .. file_of(buf) }
	local ok, err = pcall(vim.system, argv, { text = true }, vim.schedule_wrap(function(obj)
		if not state[buf] then
			return
		end
		if obj.code ~= 0 then
			stop_waiting(buf)
			notify("send to " .. h.owner .. " failed, buffer stays editable: "
				.. vim.trim(obj.stderr or ""), vim.log.levels.ERROR)
			return
		end
		notify("submitted to " .. h.owner)
		start_poll(buf, h.owner)
	end))
	if not ok then
		stop_waiting(buf)
		notify("cannot run couch, buffer stays editable: " .. tostring(err), vim.log.levels.ERROR)
	end
end

--- Manual escape when the owner never replies: editable again, lock kept —
--- the operator holds the turn and resubmits with <M-CR>.
M.unlock = function(buf)
	-- Bound in every markdown buffer (the registry's no-ghost contract).
	if not state[buf] then
		notify("not a session-sync file", vim.log.levels.WARN)
		return
	end
	stop_waiting(buf)
	restart_idle(buf)
	notify("unlocked; Alt+Return resubmits")
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
