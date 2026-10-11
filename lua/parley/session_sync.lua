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
-- lock (it never writes the lock); a watch notices, reloads and unlocks.
-- The turn is always read from disk, so a reopened buffer shows it too.
-- An agent write under the operator's lock never prompts (#314): the
-- operator's copy is written back, the agent's kept as `<file>.clobbered`,
-- and the owner told once. While the owner owes a response for
-- `session_sync_ping_minutes` and its turn has ended, it is pinged once.
--
-- Lifecycles: the lock is removed by the agent's reply; an operator lock left
-- idle turns stale and is shown in the reminder colour until submitted. The
-- watch timer lives while the buffer is loaded (closed on unload and
-- BufWipeout, restarted by BufWinEnter); the idle
-- timer is one per buffer, restarted on each edit and closed on BufWipeout.
-- `<file>.clobbered` is one per file, overwritten by the next violation and
-- removed by whoever reads it. Probes are one-shot couch processes, one at a
-- time per buffer.

local M = {}

M.POLL_MS = 1000
M.PING_CHECK_MS = 60000
-- An owner whose slot showed no activity for this long has ended its turn
-- (couch's own QuietInterval, the rule its routing uses).
M.QUIET_SECONDS = 30

local ns_group = "ParleySessionSync"

-- Per-buffer state: { turn, stale, gen (submit generation), loaded (disk
-- mtime last read/written), watch = timer|nil, idle = timer|nil, minutes
-- (the agent's turn so far), violated / complained (this operator turn),
-- probing / probed (vim.uv.now()
-- of the last probe), pinged (the owed-since time last pinged) }
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
	violated = { hl = "ParleySessionSyncOperator", label = "%s wrote under your lock: %s" },
	agent = { hl = "ParleySessionSyncAgent", label = "%s owes a response, %d min, read-only" },
}

--- (turn, { stale, violated (what became of it), minutes }, owner) →
--- { state, label, hl }: what every surface renders. A violation outranks staleness.
M.view = function(turn, flags, owner)
	flags = flags or {}
	local key = turn
	if turn == "operator" then
		key = flags.violated and "violated" or flags.stale and "stale" or "operator"
	end
	local v = VIEWS[key]
	local detail = key == "violated" and flags.violated or (flags.minutes or 0)
	return { state = key, label = v.label:format(owner or "agent", detail), hl = v.hl }
end

-- Days since 1970-01-01 for a proleptic Gregorian date (no timezone involved).
local function days_from_civil(y, m, d)
	y = m <= 2 and y - 1 or y
	local era = math.floor(y / 400)
	local yoe = y - era * 400
	local doy = math.floor((153 * (m > 2 and m - 3 or m + 9) + 2) / 5) + d - 1
	return era * 146097 + yoe * 365 + math.floor(yoe / 4) - math.floor(yoe / 100) + doy - 719468
end

--- RFC3339 text → epoch seconds, or nil.
M.parse_time = function(text)
	if type(text) ~= "string" then
		return nil
	end
	local y, mo, d, h, mi, sec, tz = text:match("^(%d%d%d%d)%-(%d%d)%-(%d%d)T(%d%d):(%d%d):(%d%d)%.?%d*(.*)$")
	if not y then
		return nil
	end
	local offset = 0
	if tz ~= "Z" then
		local sign, oh, om = tz:match("^([+-])(%d%d):(%d%d)$")
		if not sign then
			return nil
		end
		offset = (sign == "-" and -60 or 60) * (tonumber(oh) * 60 + tonumber(om))
	end
	return days_from_civil(tonumber(y), tonumber(mo), tonumber(d)) * 86400
		+ tonumber(h) * 3600 + tonumber(mi) * 60 + tonumber(sec) - offset
end

--- The actor (from `couch --actors --json`) a couch address names: the exact
--- slot, else the one slot whose repository starts with the address's (couch
--- resolves `parley:1` to `parley.nvim:1` the same way). nil when none or ambiguous.
M.find_actor = function(actors, owner)
	local repo, index = (owner or ""):match("^(.*):(%d+)$")
	local prefixed = {}
	for _, actor in ipairs(type(actors) == "table" and actors or {}) do
		local binding = type(actor) == "table" and actor.Binding
		local slot = type(binding) == "table" and type(binding.Slot) == "string" and binding.Slot or ""
		if slot == owner then
			return actor
		end
		local r, i = slot:match("^(.*):(%d+)$")
		if repo and r and i == index and r:sub(1, #repo) == repo then
			prefixed[#prefixed + 1] = actor
		end
	end
	return #prefixed == 1 and prefixed[1] or nil
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

local function owner_of(buf)
	return (header(buf) or {}).owner
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

-- One message to the owner; on_exit(obj) gets the result, in the main loop.
-- Every message leaves from this editor, so couch sees the operator's own
-- slot as the sender (pair#433 counts it as the operator's, not a peer's).
local function send(owner, message, on_exit)
	local argv = { "couch", "--send-to", owner, "--message", message }
	local ok, err = pcall(vim.system, argv, { text = true }, vim.schedule_wrap(on_exit or function() end))
	if not ok and on_exit then
		on_exit({ code = -1, stderr = tostring(err) })
	end
end

-- A decoded JSON value as a list: anything but a table is empty.
local function list(value)
	return type(value) == "table" and value or {}
end

-- Run a couch query; cb(decoded) with nil unless it exited 0 with Code "ok".
-- JSON null decodes to nil (never vim.NIL), so a missing field reads as absent.
local function query(argv, cb)
	local ok = pcall(vim.system, argv, { text = true }, vim.schedule_wrap(function(obj)
		local decoded, data = pcall(vim.json.decode, obj.stdout or "", { luanil = { object = true, array = true } })
		cb(obj.code == 0 and decoded and type(data) == "table" and data.Code == "ok" and data or nil)
	end))
	if not ok then
		cb(nil)
	end
end

local function close_timer(timer)
	if timer and not timer:is_closing() then
		timer:stop()
		timer:close()
	end
end

local function render(buf, view)
	for _, win in ipairs(vim.fn.win_findbuf(buf)) do
		local opts = { win = win, scope = "local" }
		vim.api.nvim_set_option_value("winhighlight", "StatusLine:" .. view.hl, opts)
		-- `%=` fills the rest of the bar in the same colour: a full-width band.
		vim.api.nvim_set_option_value("winbar", "%#" .. view.hl .. "# " .. view.label .. "%=", opts)
	end
end

-- The file's mtime on disk, comparable by equality ("" when missing).
local function disk_mtime(buf)
	local st = vim.uv.fs_stat(file_of(buf))
	return st and (st.mtime.sec .. "." .. st.mtime.nsec) or ""
end

-- Whether the file on disk changed since the buffer last read or wrote it.
local function disk_changed(buf)
	local s = state[buf]
	return s.loaded ~= nil and disk_mtime(buf) ~= s.loaded
end

local function reload(buf)
	vim.bo[buf].modifiable = true
	vim.api.nvim_buf_call(buf, function()
		vim.cmd("silent edit!")
	end)
end

local function lock_mtime(buf)
	local st = vim.uv.fs_stat(M.lock_path(buf))
	return st and st.mtime.sec
end

-- Whole minutes since the lock was written (the agent's turn so far).
local function lock_minutes(buf)
	return math.floor((os.time() - (lock_mtime(buf) or os.time())) / 60)
end

local refresh

-- The agent wrote (or deleted) the file while the operator held the lock.
-- Keep the agent's copy beside the file, write the operator's buffer back over
-- it (`write!`: no "changed since reading" prompt, now or on a later save),
-- flag the band and tell the owner once per operator turn. A copy that cannot
-- be kept is never overwritten: the buffer adopts the disk's mtime (no retry
-- each tick) and a later save meets Neovim's own overwrite prompt.
local function violation(buf)
	local s = state[buf]
	if not disk_changed(buf) then
		return
	end
	local path = file_of(buf)
	local clobbered = path .. ".clobbered"
	local band, told
	if not vim.uv.fs_stat(path) then
		band, told = "deleted it, yours restored", "was deleted while the operator held the lock;"
			.. " the operator's copy was restored"
	elseif vim.uv.fs_copyfile(path, clobbered) then
		band, told = "yours kept, theirs in .clobbered", "was written while the operator held the lock;"
			.. " the operator's copy was kept, yours is at " .. clobbered
	else
		band, told = "theirs could not be kept, file left as theirs", "was written while the operator held"
			.. " the lock; your copy could not be kept at " .. clobbered .. ", so it was not overwritten"
	end
	if band:find("not be kept", 1, true) then
		s.loaded = disk_mtime(buf)
	else
		vim.api.nvim_buf_call(buf, function()
			vim.cmd("silent write!")
		end)
	end
	s.violated = band
	refresh(buf)
	local owner = owner_of(buf)
	notify((owner or "the agent") .. " " .. path .. " " .. told, vim.log.levels.WARN)
	if owner and not s.complained then
		s.complained = true
		send(owner, "session-sync violation: " .. path .. " " .. told)
	end
end

-- Ping the owner once per episode of owed work: owed since the lock was
-- handed to it (the agent's turn), or since the oldest owed event couch's
-- `--session-sync status` reports (pair#437; any failure leaves the lock
-- alone as the condition). Only an owner that is live and quiet (its turn
-- ended: no activity for QUIET_SECONDS) is pinged: mid-turn the message would
-- only queue. (`Resting` names the slot's resting branch, not its turn.)
local function probe(buf)
	local s = state[buf]
	local owner = owner_of(buf)
	if not owner or s.probing or (s.probed and vim.uv.now() - s.probed < M.PING_CHECK_MS) then
		return
	end
	s.probing, s.probed = true, vim.uv.now()
	local path = file_of(buf)
	local function lock_owed()
		return read_turn(buf) == "agent" and lock_mtime(buf) or nil
	end
	query({ "couch", "--session-sync", "status", "--json", path }, function(status)
		if state[buf] ~= s then
			return
		end
		local since = lock_owed()
		local from_lock = since ~= nil
		for _, owed in ipairs(list(status and list(status.Status).Owed)) do
			local at = type(owed) == "table" and M.parse_time(owed.At)
			if at and (not since or at < since) then
				since, from_lock = at, false
			end
		end
		local after = (require("parley").config.session_sync_ping_minutes or 5) * 60
		if not since or os.time() - since < after or s.pinged == since then
			s.probing = false
			return
		end
		query({ "couch", "--actors", "--json" }, function(actors)
			if state[buf] ~= s then
				return
			end
			s.probing = false
			local actor = actors and M.find_actor(actors.Actors, owner)
			-- The reply may have landed while couch answered.
			local active = actor and actor.Known and M.parse_time(actor.LastActivity)
			if not active or os.time() - active < M.QUIET_SECONDS or (from_lock and lock_owed() ~= since) then
				return
			end
			s.pinged = since
			send(owner, "session-sync ping: " .. path .. " owes a response since "
				.. os.date("!%Y-%m-%dT%H:%M:%SZ", since))
		end)
	end)
end

-- Watch the file in every turn. During the agent's turn the lock's removal is
-- the reply; during a free turn an agent write reloads the (unmodified)
-- buffer, so the operator never edits a stale copy; during the operator's
-- turn an agent write is a violation.
local function start_watch(buf)
	local s = state[buf]
	if s.watch then
		return
	end
	local timer = vim.uv.new_timer()
	s.watch = timer
	timer:start(M.POLL_MS, M.POLL_MS, vim.schedule_wrap(function()
		-- An unloaded buffer (:bdelete) has no copy to keep: stop until
		-- BufWinEnter shows it again.
		if s.watch ~= timer or not vim.api.nvim_buf_is_loaded(buf) then
			close_timer(timer)
			if s.watch == timer then
				s.watch = nil
			end
			return
		end
		local turn = read_turn(buf)
		if turn == "operator" and s.turn == "operator" and disk_changed(buf) then
			violation(buf)
		elseif turn == "free" and s.turn == "agent" then
			reload(buf)
			notify((owner_of(buf) or "agent") .. " replied")
		elseif turn == "free" and not vim.bo[buf].modified and disk_changed(buf) then
			reload(buf)
		end
		if turn ~= s.turn or (turn == "agent" and s.minutes ~= lock_minutes(buf)) then
			refresh(buf)
		end
		probe(buf)
	end))
end

-- Apply the on-disk turn: read-only while the agent holds it.
refresh = function(buf)
	local s = state[buf]
	if not s or not vim.api.nvim_buf_is_valid(buf) then
		return
	end
	local turn = read_turn(buf)
	s.turn = turn
	if turn ~= "operator" then
		s.stale, s.violated, s.complained = false, false, false
	end
	s.minutes = turn == "agent" and lock_minutes(buf) or nil
	vim.bo[buf].modifiable = turn ~= "agent"
	start_watch(buf)
	render(buf, M.view(turn, s, owner_of(buf)))
end

-- Restart the idle timer (one per buffer, reused across keystrokes); when it
-- fires with the operator still holding the turn, the turn is stale and
-- renders in the reminder colour.
local function restart_idle(buf)
	local s = state[buf]
	if s.stale then
		s.stale = false
		refresh(buf)
	end
	if s.idle then
		s.idle:stop()
	end
	if s.turn ~= "operator" then
		return
	end
	s.idle = s.idle or vim.uv.new_timer()
	local minutes = require("parley").config.session_sync_stale_minutes or 5
	s.idle:start(math.floor(minutes * 60000), 0, vim.schedule_wrap(function()
		if state[buf] == s and vim.api.nvim_buf_is_valid(buf) and read_turn(buf) == "operator" then
			s.stale = true
			refresh(buf)
		end
	end))
end

-- The operator's turn is a dark red band, unmistakable without glare; stale is orange.
local function define_highlights()
	local groups = {
		ParleySessionSyncFree = { link = "StatusLine" },
		ParleySessionSyncOperator = { bg = "#870000", fg = "#ffffff", ctermbg = 88, ctermfg = 231, bold = true },
		ParleySessionSyncStale = { bg = "#ff8700", fg = "#000000", ctermbg = 208, ctermfg = 16, bold = true },
		ParleySessionSyncAgent = { link = "DiffChange" },
	}
	for name, spec in pairs(groups) do
		vim.api.nvim_set_hl(0, name, vim.tbl_extend("force", spec, { default = true }))
	end
end

--- Install the turn autocmds on a session-sync buffer and render its turn. Idempotent.
M.attach = function(buf)
	if state[buf] or not M.is_session_sync(buf) then
		return
	end
	local s = { stale = false, gen = 0 }
	state[buf] = s
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
			if s.turn == "free" and vim.bo[buf].modified and vim.bo[buf].modifiable
				and read_turn(buf) == "free" and M.is_session_sync(buf) then
				-- The operator's turn never starts on a copy older than the
				-- disk: then no writer (submit, auto-save, :w) can clobber it.
				if disk_changed(buf) then
					reload(buf)
					notify("the file changed on disk; reloaded the current copy, retype your edit",
						vim.log.levels.WARN)
					return
				end
				if write_lock(buf, "operator") then
					refresh(buf)
				end
			end
			restart_idle(buf)
		end,
	})
	-- No prompt about a file changed on disk: under the operator's lock it is
	-- a violation (handled outside the autocmd, which may not write); else
	-- what autoread would do.
	vim.api.nvim_create_autocmd("FileChangedShell", {
		group = group,
		buffer = buf,
		callback = function()
			if read_turn(buf) ~= "operator" then
				vim.v.fcs_choice = vim.bo[buf].modified and "ask" or "reload"
				return
			end
			vim.v.fcs_choice = ""
			vim.schedule(function()
				if state[buf] == s and vim.api.nvim_buf_is_loaded(buf) and read_turn(buf) == "operator" then
					violation(buf)
				end
			end)
		end,
	})
	-- What the buffer last saw on disk: the base `disk_changed` compares to.
	vim.api.nvim_create_autocmd({ "BufReadPost", "BufWritePost", "FileChangedShellPost" }, {
		group = group,
		buffer = buf,
		callback = function()
			s.loaded = disk_mtime(buf)
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
			close_timer(s.watch)
			close_timer(s.idle)
			state[buf] = nil
			pcall(vim.api.nvim_del_augroup_by_id, group)
		end,
	})
	s.loaded = disk_mtime(buf)
	refresh(buf)
	restart_idle(buf)
end

--- <M-CR>: save, hand the turn to the agent, tell the owner.
M.submit = function(buf)
	local h = header(buf)
	if not h or not h.owner then
		notify("no `owner:` in the frontmatter", vim.log.levels.ERROR)
		return
	end
	M.attach(buf)
	local s = state[buf]
	if read_turn(buf) == "agent" then
		notify("already submitted to " .. h.owner .. "; waiting for its reply", vim.log.levels.WARN)
		return
	end
	if disk_changed(buf) then
		-- Under the operator's lock the operator's copy wins.
		if read_turn(buf) == "operator" then
			violation(buf)
		else
			notify("the file changed on disk since this buffer read it; not overwriting it."
				.. " :e! reloads (dropping your edits)", vim.log.levels.ERROR)
			return
		end
	end
	vim.cmd("stopinsert")
	vim.api.nvim_buf_call(buf, function()
		vim.cmd("silent write")
	end)
	if not write_lock(buf, "agent") then
		return
	end
	refresh(buf)
	-- A completion belongs to its submit: once the turn has moved on (an
	-- unlock, a resubmit, the agent's reply), a late exit must not touch it.
	s.gen = s.gen + 1
	local gen = s.gen
	local function current()
		return state[buf] == s and s.gen == gen and read_turn(buf) == "agent"
	end
	local function fail(why)
		if not current() then
			return
		end
		write_lock(buf, "operator")
		refresh(buf)
		notify("send to " .. h.owner .. " failed, your turn again: " .. why, vim.log.levels.ERROR)
	end
	send(h.owner, "submitted: " .. file_of(buf), function(obj)
		if obj.code ~= 0 then
			fail(vim.trim(obj.stderr or ""))
		elseif current() then
			notify("submitted to " .. h.owner)
		end
	end)
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
	state[buf].gen = state[buf].gen + 1
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
