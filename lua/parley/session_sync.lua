-- parley.session_sync — turn-based shared markdown (#313).
--
-- A markdown file whose frontmatter says `type: session-sync` is shared
-- between the operator and the agent named by `owner:` (a couch address).
-- Pessimistic locking for the human, optimistic for the agent (#315): the
-- operator's lock is the only lock. The sidecar `<file>.lock`:
--   absent           free — the agent may write; a clean buffer follows its
--                    writes silently; the operator's first edit takes the
--                    turn (holder: operator)
--   holder: operator the operator's turn — the agent never writes the file
-- A legacy `holder: agent` lock reads as free. <M-CR> saves, deletes the lock
-- and tells the owner via `couch --send-to`; the buffer stays editable.
-- The turn is always read from disk, so a reopened buffer shows it too.
-- An agent write under the operator's lock (or racing the first keystroke)
-- never prompts (#314): the operator's copy is written back, the agent's
-- kept as `<file>.clobbered`, and the owner told once. Whether the owner owes
-- a response comes from couch's owed events alone: they drive the band, and
-- while owed for `session_sync_ping_minutes` with its turn ended, the owner
-- is pinged once.
--
-- Lifecycles: the lock is removed by submit; an operator lock left
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

-- Per-buffer state: { turn, stale, loaded (disk mtime last read/written),
-- foreign (the disk mtime of the last write Neovim saw as someone else's),
-- checking (inside disk_changed's :checktime),
-- watch = timer|nil, idle = timer|nil, owed (epoch of the oldest owed event
-- couch last reported, or nil), minutes (rendered owed minutes), violated /
-- complained (this operator turn), unkept (the disk mtime of an agent copy
-- that could not be kept), probing / probed (vim.uv.now() of the last
-- probe), pinged (the owed-since time last pinged) }
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

--- The lock sidecar's text for a holder (parley only writes "operator").
M.lock_body = function(holder, epoch)
	return "holder: " .. holder .. "\ntime: " .. os.date("!%Y-%m-%dT%H:%M:%SZ", epoch) .. "\n"
end

--- Lock text (nil = no lock) → "free" | "operator". A legacy agent lock is
--- no lock (#315); one without a recognisable holder still blocks the agent,
--- so it counts as the operator's.
M.turn = function(lock_text)
	if not lock_text or lock_text:match("^holder:%s*agent%s*\n") then
		return "free"
	end
	return "operator"
end

local VIEWS = {
	free = { hl = "ParleySessionSyncFree", label = "free: editing takes your turn" },
	operator = { hl = "ParleySessionSyncOperator", label = "your turn, Alt+Return to submit" },
	stale = { hl = "ParleySessionSyncStale", label = "unsent edits, Alt+Return to submit" },
	violated = { hl = "ParleySessionSyncOperator", label = "%s %s" },
	owed = { hl = "ParleySessionSyncOwed", label = "%s owes a response, %d min" },
}

--- (turn, { stale, violated (what became of it), minutes (owed, or nil) },
--- owner) → { state, label, hl }: what every surface renders. The operator's
--- turn outranks owed work; a violation outranks staleness.
M.view = function(turn, flags, owner)
	flags = flags or {}
	local key = flags.minutes and "owed" or "free"
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
-- `s.loaded` is only a cache: a write from a non-nested autocmd (an auto-save
-- on TextChanged) fires no BufWritePost, so when the mtime moved, Neovim, which
-- records every write the buffer makes, decides: `:checktime` raises
-- FileChangedShell (which records `s.foreign`) only for someone else's write
-- (#317). Never call it from inside an autocmd, where `:checktime` prompts.
local function disk_changed(buf)
	local s = state[buf]
	local now = disk_mtime(buf)
	if s.loaded == nil or now == s.loaded then
		return false
	end
	if now ~= s.foreign then
		s.checking = true
		pcall(vim.cmd, "checktime " .. buf)
		s.checking = false
		if now ~= s.foreign then
			s.loaded = now
			return false
		end
	end
	return true
end

local refresh, probe

-- A clean buffer follows the file on disk silently; the owed state is
-- re-read at once, since a write is usually the agent's answer.
local function reload(buf)
	vim.api.nvim_buf_call(buf, function()
		vim.cmd("silent edit!")
	end)
	state[buf].probed = nil
	probe(buf)
end

-- Whole minutes the owner has owed a response, or nil when nothing is owed.
local function owed_minutes(buf)
	local since = state[buf].owed
	return since and math.max(0, math.floor((os.time() - since) / 60)) or nil
end

-- The agent wrote (or deleted) the file while the operator held the lock, or
-- (`race`) just before the operator's first keystroke took it. Keep the agent's copy beside the file, write the operator's buffer back over
-- it (`write!`: no "changed since reading" prompt, now or on a later save),
-- flag the band and tell the owner once per operator turn. A copy that cannot
-- be kept is never overwritten: it is remembered by mtime (no retry each
-- tick), submit refuses, and a plain save meets Neovim's own overwrite prompt.
-- Returns whether the file on disk is the operator's copy; every caller that
-- writes next must act on it.
local function violation(buf, race)
	local s = state[buf]
	if not disk_changed(buf) then
		return true
	end
	if s.unkept == disk_mtime(buf) then
		return false
	end
	local path = file_of(buf)
	local clobbered = path .. ".clobbered"
	local verb = race and "changed as you started typing:" or "wrote under your lock:"
	local when = race and " as the operator started editing" or " while the operator held the lock"
	local band, told
	if not vim.uv.fs_stat(path) then
		band, told = "deleted it, yours restored", "was deleted" .. when .. ";"
			.. " the operator's copy was restored"
	elseif vim.uv.fs_copyfile(path, clobbered) then
		band, told = "yours kept, theirs in .clobbered", "was written" .. when .. ";"
			.. " the operator's copy was kept, yours is at " .. clobbered
	else
		band, told = "theirs could not be kept, file left as theirs", "was written" .. when
			.. "; your copy could not be kept at " .. clobbered .. ", so it was not overwritten"
	end
	local kept = not band:find("not be kept", 1, true)
	if not kept then
		s.unkept = disk_mtime(buf)
	else
		vim.api.nvim_buf_call(buf, function()
			vim.cmd("silent write!")
		end)
	end
	s.violated = verb .. " " .. band
	refresh(buf)
	local owner = owner_of(buf)
	notify((owner or "the agent") .. " " .. path .. " " .. told, vim.log.levels.WARN)
	if owner and not s.complained then
		s.complained = true
		send(owner, "session-sync violation: " .. path .. " " .. told)
	end
	return kept
end

-- Read the owed state: since the oldest owed event couch's `--session-sync
-- status` reports (pair#437; any failure reads as nothing owed). It drives
-- the band, and pings the owner once per episode of owed work. Only an owner
-- that is live and quiet (its turn ended: no activity for QUIET_SECONDS) is
-- pinged: mid-turn the message would only queue. (`Resting` names the slot's
-- resting branch, not its turn.)
probe = function(buf)
	local s = state[buf]
	local owner = owner_of(buf)
	if not owner or s.probing or (s.probed and vim.uv.now() - s.probed < M.PING_CHECK_MS) then
		return
	end
	s.probing, s.probed = true, vim.uv.now()
	local path = file_of(buf)
	query({ "couch", "--session-sync", "status", "--json", path }, function(status)
		if state[buf] ~= s then
			return
		end
		local since
		for _, owed in ipairs(list(status and list(status.Status).Owed)) do
			local at = type(owed) == "table" and M.parse_time(owed.At)
			if at and (not since or at < since) then
				since = at
			end
		end
		if s.owed ~= since then
			s.owed = since
			refresh(buf)
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
			if not active or os.time() - active < M.QUIET_SECONDS or s.owed ~= since then
				return
			end
			s.pinged = since
			send(owner, "session-sync ping: " .. path .. " owes a response since "
				.. os.date("!%Y-%m-%dT%H:%M:%SZ", since))
		end)
	end)
end

-- Watch the file in every turn. During a free turn an agent write reloads the
-- (unmodified) buffer, so the operator never edits a stale copy; during the
-- operator's turn an agent write is a violation.
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
		elseif turn == "free" and not vim.bo[buf].modified and disk_changed(buf) then
			reload(buf)
		end
		if turn ~= s.turn or s.minutes ~= owed_minutes(buf) then
			refresh(buf)
		end
		probe(buf)
	end))
end

-- Apply the on-disk turn and the owed state to the band.
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
	s.minutes = owed_minutes(buf)
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
		ParleySessionSyncOwed = { link = "DiffChange" },
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
	local s = { stale = false }
	state[buf] = s
	define_highlights()
	-- With autoread an unmodified buffer reloads on :checktime without
	-- FileChangedShell: an agent write under the lock right after an
	-- auto-save would replace the operator's text (#317).
	vim.bo[buf].autoread = false
	local group = vim.api.nvim_create_augroup(ns_group .. buf, { clear = true })
	-- The first edit takes the turn; every edit restarts the idle timer.
	-- BufModifiedSet catches the first keystroke in either mode (it fires from
	-- the main loop, not from API edits); TextChanged[I] the later ones.
	vim.api.nvim_create_autocmd({ "BufModifiedSet", "TextChanged", "TextChangedI" }, {
		group = group,
		buffer = buf,
		callback = function()
			if s.turn == "free" and vim.bo[buf].modified
				and read_turn(buf) == "free" and M.is_session_sync(buf) then
				-- Take the lock first; an agent write that landed since the
				-- buffer last read the disk lost the race: the operator's
				-- text is kept and the agent's set aside (#315).
				-- The mtime moved before this edit; whose write it was is
				-- asked outside the autocmd (disk_changed may :checktime).
				local moved = s.loaded ~= nil and disk_mtime(buf) ~= s.loaded
				if write_lock(buf, "operator") then
					refresh(buf)
					vim.schedule(function()
						if moved and state[buf] == s and vim.api.nvim_buf_is_loaded(buf)
							and read_turn(buf) == "operator" and disk_changed(buf) then
							violation(buf, true)
						end
					end)
				end
			end
			restart_idle(buf)
		end,
	})
	-- No prompt about a file changed on disk: someone else wrote it. During
	-- disk_changed's own check, only record that; else under the operator's
	-- lock it is a violation (handled outside the autocmd, which may not
	-- write), and otherwise what autoread would do.
	vim.api.nvim_create_autocmd("FileChangedShell", {
		group = group,
		buffer = buf,
		callback = function()
			s.foreign = disk_mtime(buf)
			if s.checking then
				vim.v.fcs_choice = ""
				return
			end
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

--- <M-CR>: save, delete the lock, tell the owner. The buffer stays editable;
--- the next edit takes the lock again (#315).
M.submit = function(buf)
	local h = header(buf)
	if not h or not h.owner then
		notify("no `owner:` in the frontmatter", vim.log.levels.ERROR)
		return
	end
	M.attach(buf)
	if disk_changed(buf) then
		-- Under the operator's lock the operator's copy wins, unless the
		-- agent's could not be kept.
		if read_turn(buf) == "operator" then
			if not violation(buf) then
				notify("the agent's copy could not be kept beside the file; not overwriting it", vim.log.levels.ERROR)
				return
			end
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
	local lock = M.lock_path(buf)
	if vim.uv.fs_stat(lock) and not os.remove(lock) then
		notify("cannot remove " .. lock, vim.log.levels.ERROR)
		return
	end
	refresh(buf)
	restart_idle(buf)
	local s = state[buf]
	send(h.owner, "submitted: " .. file_of(buf), function(obj)
		if obj.code ~= 0 then
			notify("send to " .. h.owner .. " failed, Alt+Return resends: " .. vim.trim(obj.stderr or ""),
				vim.log.levels.ERROR)
		elseif state[buf] == s then
			notify("submitted to " .. h.owner)
			-- The submit is now owed: show it without waiting a probe interval.
			s.probed = nil
			probe(buf)
		end
	end)
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
