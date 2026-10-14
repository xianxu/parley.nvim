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
-- after `session_sync_ping_minutes` without a write and with its turn ended,
-- the owner is pinged once per write generation (outside the operator lock).
--
-- Lifecycles: submit or a clean undo removes the lock; an operator lock left
-- idle turns stale and is shown in the reminder colour until submitted. The
-- watch timer lives while the buffer is loaded (closed on unload and
-- BufWipeout, restarted by BufWinEnter); the idle
-- timer is one per buffer, restarted on each edit and closed on BufWipeout.
-- `<file>.clobbered` is one per file, overwritten by the next violation and
-- removed by whoever reads it. Probes are one-shot couch processes, one at a
-- time per buffer.

local M = {}
local couch = require("parley.couch")

M.POLL_MS = 1000
M.PING_CHECK_MS = 60000
-- An owner whose slot showed no activity for this long has ended its turn
-- (couch's own QuietInterval, the rule its routing uses).
M.QUIET_SECONDS = 30

local ns_group = "ParleySessionSync"

-- Per-buffer state: { turn, stale, loaded (disk mtime last read/written),
-- foreign (the disk mtime of the last write Neovim saw as someone else's),
-- checking (inside disk_changed's :checktime), edit (latest pending clean-edit
-- reconciliation token), edits_attached (native edit callback installed),
-- watch = timer|nil, idle = timer|nil, owed (epoch of the oldest owed event
-- couch last reported, or nil), minutes (rendered owed minutes), violated /
-- complained (this operator turn), unkept (the disk mtime of an agent copy
-- that could not be kept), probing / probed (vim.uv.now() of the last
-- probe), pinged (the LastWrite value last pinged; false when absent) }
local state = {}

--- Frontmatter lines → { owner, operator } when `type: session-sync`, else nil.
---@param lines string[]
---@return table|nil
M.parse_header = function(lines)
	local fm = require("parley.frontmatter").parse(lines)
	if not fm or fm.fields.type ~= "session-sync" then
		return nil
	end
	return { owner = fm.fields.owner, operator = fm.fields.operator }
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
	local y, mo, d, h, mi, sec, tz = text:match("^(%d%d%d%d)%-(%d%d)%-(%d%d)T(%d%d):(%d%d):(%d%d)(.*)$")
	if not y then
		return nil
	end
	y, mo, d, h, mi, sec = tonumber(y), tonumber(mo), tonumber(d), tonumber(h), tonumber(mi), tonumber(sec)
	local leap = y % 4 == 0 and (y % 100 ~= 0 or y % 400 == 0)
	local days = ({ 31, leap and 29 or 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31 })[mo]
	if not days or d < 1 or d > days or h > 23 or mi > 59 or sec > 59 then
		return nil
	end
	tz = tz:match("^%.%d+(.+)$") or tz
	local offset = 0
	if tz ~= "Z" then
		local sign, oh, om = tz:match("^([+-])(%d%d):(%d%d)$")
		if not sign or tonumber(oh) > 23 or tonumber(om) > 59 then
			return nil
		end
		offset = (sign == "-" and -60 or 60) * (tonumber(oh) * 60 + tonumber(om))
	end
	return days_from_civil(y, mo, d) * 86400 + h * 3600 + mi * 60 + sec - offset
end

--- Eligible write generation, false for no recorded write, or nil to postpone.
--- `since` is the oldest valid obligation time; nil means no known obligation.
M.ping_generation = function(written, since, now, minutes, pinged)
	local baseline = written == nil and since or M.parse_time(written)
	local generation = written or false
	if not since or not baseline or now - baseline < (minutes or 15) * 60 or pinged == generation then
		return nil
	end
	return generation
end

--- Whether a known owner's observed turn has been quiet long enough.
M.owner_quiet = function(actor, now)
	local active = actor and actor.Known and M.parse_time(actor.LastActivity)
	return not not (active and now - active >= M.QUIET_SECONDS)
end

M.find_actor = couch.find_actor

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

local send, query, list = couch.send, couch.query, couch.list

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
-- (#317). Only Neovim's verdict moves the baseline: when it gives none (the
-- check errored, or `eventignore` hides the event) the write stays undecided,
-- asked again next time, and Neovim's own overwrite warning still guards
-- a save. Never call it from inside an autocmd, where `:checktime` prompts.
local function mtime_moved(buf)
	local s = state[buf]
	return s.loaded ~= nil and disk_mtime(buf) ~= s.loaded
end

local function disk_changed(buf)
	local s = state[buf]
	if not mtime_moved(buf) then
		return false
	end
	local now = disk_mtime(buf)
	if now == s.foreign then
		return true
	end
	local ignored = vim.o.eventignore:lower()
	if ignored:find("all", 1, true) or ignored:find("filechangedshell", 1, true) then
		return false
	end
	s.checking = true
	local ok = pcall(vim.cmd, "checktime " .. buf)
	s.checking = false
	if now == s.foreign then
		return true
	end
	if ok then
		s.loaded = now
	end
	return false
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
-- the band. Pings use LastWrite (oldest owed time only when absent), once
-- per write generation; changing deliveries never rearms them. Only an owner
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
	local mtime = disk_mtime(buf)
	query({ "couch", "--session-sync", "status", "--json", path }, function(status)
		if state[buf] ~= s then
			return
		end
		local observed = list(status and status.Status)
		local obligations = list(observed.Owed)
		local since
		for _, owed in ipairs(obligations) do
			local at = type(owed) == "table" and M.parse_time(owed.At)
			if at and (not since or at < since) then
				since = at
			end
		end
		if s.owed ~= since then
			s.owed = since
			refresh(buf)
		end
		local generation = M.ping_generation(observed.LastWrite, since, os.time(),
			require("parley").config.session_sync_ping_minutes, s.pinged)
		if generation == nil or read_turn(buf) == "operator" then
			s.probing = false
			return
		end
		query({ "couch", "--actors", "--json" }, function(actors)
			if state[buf] ~= s then
				return
			end
			s.probing = false
			local actor = actors and M.find_actor(actors.Actors, owner)
			-- A write or operator edit while either query ran postpones the ping.
			if not M.owner_quiet(actor, os.time()) or read_turn(buf) == "operator"
				or disk_mtime(buf) ~= mtime then
				return
			end
			s.pinged = generation
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
	-- Acquire in the edit notification, before TextChanged/InsertLeave auto-save
	-- callbacks can clear 'modified' (#324). This buffer was identified at
	-- attach: an edit to its YAML must not remove its protection.
	local function attach_edits()
		if s.edits_attached then return end
		s.edits_attached = vim.api.nvim_buf_attach(buf, false, {
			on_lines = function()
				if state[buf] ~= s then
					return true
				end
				local before = disk_mtime(buf)
				if vim.bo[buf].modified and read_turn(buf) == "free" then
					local moved = mtime_moved(buf)
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
				-- Undo updates 'modified' after on_lines. Reconcile when it settles,
				-- but a save (including a non-nested auto-save with no BufWritePost)
				-- keeps the turn until submit. Only the latest edit may release it.
				local edit = {}
				s.edit = edit
				vim.schedule(function()
					if state[buf] ~= s or s.edit ~= edit or not vim.api.nvim_buf_is_loaded(buf) then
						return
					end
					if not vim.bo[buf].modified and disk_mtime(buf) == before
						and read_turn(buf) == "operator" then
						if vim.fn.delete(M.lock_path(buf)) == 0 then
							refresh(buf)
							restart_idle(buf)
						end
					end
				end)
			end,
			-- An external reload is not an operator edit; keep the attachment for
			-- the next keystroke and invalidate any pending clean-edit check.
			on_reload = function()
				s.edit = nil
			end,
			on_detach = function()
				s.edits_attached, s.edit = false, nil
			end,
		})
	end
	attach_edits()
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
			attach_edits() -- :edit! detaches buffer callbacks before BufReadPost.
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

local submit_now

--- <M-CR> in a session-sync file. `owner:` is a check, not a route (#316):
--- inside a pair slot, the file is submitted only when its owner is this
--- slot's own agent. Outside pair there is no slot to compare, and the owner
--- is sent to as before.
M.submit = function(buf)
	local h = header(buf)
	if not h or not h.owner then
		notify("no `owner:` in the frontmatter", vim.log.levels.ERROR)
		return
	end
	couch.own_slot(function(actors, own)
		if not vim.api.nvim_buf_is_valid(buf) then
			return
		end
		if actors and not own then
			notify("cannot resolve this slot's agent (couch --actors); not submitting", vim.log.levels.ERROR)
		elseif own and not couch.same(own, couch.find_actor(actors, h.owner)) then
			notify("owner " .. h.owner .. " is not this slot's agent (" .. tostring(couch.slot(own))
				.. "); not submitting", vim.log.levels.WARN)
		else
			submit_now(buf, h)
		end
	end)
end

-- Save, delete the lock, tell the owner. The buffer stays editable; the
-- next edit takes the lock again (#315).
submit_now = function(buf, h)
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

return M
