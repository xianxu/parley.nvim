-- parley.session_sync — turn-based shared markdown (#313).
--
-- A markdown file whose frontmatter says `type: session-sync` is shared
-- between the operator and the agent named by `couch-owner:` (`owner:` is the legacy fallback).
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
-- Lifecycles: submit or an undo to the acquisition baseline removes the lock; an operator lock left
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
-- reconciliation token), content (last observed buffer hash), baseline (hash
-- before our first edit, retained through saves), edits_attached (native edit callback installed),
-- watch = timer|nil, idle = timer|nil, owed (epoch of the oldest owed event
-- couch last reported, or nil), minutes (rendered owed minutes), violated /
-- complained (this operator turn), unkept (the disk mtime of an agent copy
-- that could not be kept), probing / probed (vim.uv.now() of the last
-- probe), pinged (the LastWrite value last pinged; false when absent),
-- feedback (bounded submission receipt/error, cleared by operator edit or foreign reload) }
local state = {}
local buffer_reads, native_reads = {}, {}

--- Frontmatter lines → normalized { owner, operator } for session-sync.
--- This is the single owner accessor: couch-owner first, owner fallback.
---@param lines string[]
---@return table|nil
M.parse_header = function(lines)
	local fm = require("parley.frontmatter").parse(lines)
	if not fm or fm.fields.type ~= "session-sync" then
		return nil
	end
	return { owner = fm.fields["couch-owner"] or fm.fields.owner, operator = fm.fields.operator }
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

-- Submission receipts and errors share one literal, bounded label with the
-- pre-attachment coordinator. Escape percent signs only at each UI boundary.
M.feedback_view = function(message, is_error)
    local label = type(message) == "string" and message or tostring(message or "")
    label = label:gsub("[\r\n]+", " "):gsub("%c", " ")
    return { label = vim.fn.strcharpart(label, 0, 160), hl = is_error and "DiagnosticError" or "DiagnosticOk" }
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

local function buffer_id(buf)
    return buf == 0 and vim.api.nvim_get_current_buf() or buf
end

-- A synchronous native read emits BufUnload without ending the editor's
-- document incarnation. Keep that distinction available even inside autocmds.
M.is_buffer_read = function(buf)
    buf = buffer_id(buf)
    return buffer_reads[buf] ~= nil or native_reads[buf] ~= nil
end

M.with_buffer_read = function(buf, fn)
    buf = buffer_id(buf)
    local previous = buffer_reads[buf]
    buffer_reads[buf] = (previous or 0) + 1
    local function pack(...) return { n = select("#", ...), ... } end
    local result = pack(pcall(fn))
    buffer_reads[buf] = previous
    if not result[1] then error(result[2], 0) end
    return unpack(result, 2, result.n)
end

M.is_session_sync = function(buf)
    buf = buffer_id(buf)
    return state[buf] ~= nil or header(buf) ~= nil
end

M.identity = function(buf)
    local s = state[buffer_id(buf)]
    return s and vim.deepcopy(s.identity) or nil
end

local function file_of(buf)
    buf = buffer_id(buf)
    return state[buf] and state[buf].identity.File
        or vim.fn.fnamemodify(vim.api.nvim_buf_get_name(buf), ":p")
end

M.lock_path = function(buf)
	return file_of(buf) .. ".lock"
end

local function owner_of(buf)
	return state[buffer_id(buf)] and state[buffer_id(buf)].identity.Owner or (header(buf) or {}).owner
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
    local bytes = M.lock_body(holder, os.time())
    local written = f:write(bytes)
    local closed = f:close()
    if not written or not closed then return false end
    local s = state[buffer_id(buf)]
    if s then s.owned_lock = bytes end
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
        local s = state[buf]
        s.windows = s.windows or {}
        s.windows[win] = s.windows[win] or {
            winhighlight = vim.api.nvim_get_option_value("winhighlight", opts),
            winbar = vim.api.nvim_get_option_value("winbar", opts),
        }
        local owned = s.windows[win]
        owned.installed_highlight = "StatusLine:" .. view.hl
        owned.installed_bar = "%#" .. view.hl .. "# " .. view.label:gsub("%%", "%%%%") .. "%="
        vim.api.nvim_set_option_value("winhighlight", owned.installed_highlight, opts)
        vim.api.nvim_set_option_value("winbar", owned.installed_bar, opts)
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

-- on_lines sees the completed edit; the preceding hash is the acquisition
-- baseline, independent of saves. JSON keeps embedded NULs and lines distinct.
local function content_hash(buf)
	return vim.fn.sha256(vim.json.encode(vim.api.nvim_buf_get_lines(buf, 0, -1, false)))
end

local refresh, probe

-- A clean buffer follows the file on disk silently; the owed state is
-- re-read at once, since a write is usually the agent's answer.
local function reload(buf)
    M.with_buffer_read(buf, function()
        vim.api.nvim_buf_call(buf, function()
            vim.cmd("silent edit!")
        end)
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
	if not s or s.moving or not owner or s.probing or (s.probed and vim.uv.now() - s.probed < M.PING_CHECK_MS) then
		return
	end
	s.probing, s.probed = true, vim.uv.now()
	local path = file_of(buf)
	local mtime = disk_mtime(buf)
    local epoch = s.epoch
	query({ "couch", "--session-sync", "status", "--json", path }, function(status)
		if state[buf] ~= s or s.moving or s.epoch ~= epoch then
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
			if state[buf] ~= s or s.moving or s.epoch ~= epoch then
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
	if s.moving or s.watch then
		return
	end
	local timer = vim.uv.new_timer()
	s.watch = timer
	timer:start(M.POLL_MS, M.POLL_MS, vim.schedule_wrap(function()
		-- An unloaded buffer (:bdelete) has no copy to keep: stop until
		-- BufWinEnter shows it again.
		if state[buf] ~= s or s.moving or s.watch ~= timer or not vim.api.nvim_buf_is_loaded(buf) then
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
	if not s or s.moving or not vim.api.nvim_buf_is_valid(buf) then
		return
	end
	local turn = read_turn(buf)
	s.turn = turn
	if turn ~= "operator" then
		s.stale, s.violated, s.complained, s.baseline, s.owned_lock = false, false, false, nil, nil
	end
	s.minutes = owed_minutes(buf)
	start_watch(buf)
	render(buf, s.feedback or M.view(turn, s, owner_of(buf)))
end

-- Completion belongs to the coordinator; this engine retains its receipt
-- across normal saves/status refreshes until actual document activity follows.
M.set_submission_feedback = function(buf, message, is_error)
    buf = buffer_id(buf)
    local s = state[buf]
    if not s or not vim.api.nvim_buf_is_valid(buf) then return false end
    s.feedback = M.feedback_view(message, is_error)
    refresh(buf)
    return true
end

-- Restart the idle timer (one per buffer, reused across keystrokes); when it
-- fires with the operator still holding the turn, the turn is stale and
-- renders in the reminder colour.
local function restart_idle(buf)
	local s = state[buf]
    if not s or s.moving then return end
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
		if state[buf] == s and not s.moving and vim.api.nvim_buf_is_valid(buf) and read_turn(buf) == "operator" then
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
M.attach = function(buf, identity, observed)
    buf = buffer_id(buf)
    if state[buf] then
        local current = state[buf].identity
        if identity and identity.File == current.File and (not current.ID or current.ID == identity.ID) then
            state[buf].identity = vim.deepcopy(identity)
        end
        if observed then M.acquire_observed(buf, observed) end
        return
    end
    local h = header(buf)
    if not identity and not h then return end
    identity = identity or { File = file_of(buf), Owner = h.owner }
    if type(identity.File) ~= "string" or identity.File:sub(1, 1) ~= "/" then return end
    local s = { stale = false, identity = vim.deepcopy(identity), epoch = 0,
        previous_autoread = vim.bo[buf].autoread }
    state[buf] = s
	define_highlights()
	-- With autoread an unmodified buffer reloads on :checktime without
	-- FileChangedShell: an agent write under the lock right after an
	-- auto-save would replace the operator's text (#317).
	vim.bo[buf].autoread = false
	local group = vim.api.nvim_create_augroup(ns_group .. buf, { clear = true })
    s.group = group
	-- Acquire in the edit notification, before TextChanged/InsertLeave auto-save
	-- callbacks can clear 'modified' (#324). This buffer was identified at
	-- attach: an edit to its YAML must not remove its protection.
	local function attach_edits()
		if s.edits_attached then return end
		s.content = content_hash(buf)
		s.edits_attached = vim.api.nvim_buf_attach(buf, false, {
			on_lines = function()
				if state[buf] ~= s then
					return true
				end
                local previous = s.content
                s.content = content_hash(buf)
                if s.moving then return end
                if s.feedback and previous ~= s.content and vim.bo[buf].modified then
                    s.feedback = nil
                    refresh(buf) -- synchronous: an earlier TextChanged auto-save must see it cleared
                end
                local epoch = s.epoch
				if vim.bo[buf].modified and read_turn(buf) == "free" then
					local moved = mtime_moved(buf)
					if write_lock(buf, "operator") then
						s.baseline = previous
						refresh(buf)
						vim.schedule(function()
							if moved and state[buf] == s and not s.moving and s.epoch == epoch and vim.api.nvim_buf_is_loaded(buf)
								and read_turn(buf) == "operator" and disk_changed(buf) then
								violation(buf, true)
							end
						end)
					end
				end
				restart_idle(buf)
				-- Reconcile only the latest edit, after native undo and auto-save
				-- settle. Saves never advance the acquisition baseline (#330).
				local edit = {}
				s.edit = edit
				vim.schedule(function()
					if state[buf] ~= s or s.moving or s.epoch ~= epoch or s.edit ~= edit or not vim.api.nvim_buf_is_loaded(buf) then
						return
					end
                    if s.baseline and content_hash(buf) == s.baseline and read_turn(buf) == "operator" then
                        M.release_if_baseline(buf)
                    end
				end)
			end,
			-- An external reload is not an operator edit; keep the attachment for
			-- the next keystroke and invalidate any pending clean-edit check.
			on_reload = function()
				s.content = content_hash(buf)
				s.edit = nil
                s.feedback = nil
                refresh(buf)
			end,
			on_detach = function()
				s.edits_attached, s.edit = false, nil
			end,
		})
	end
	s.attach_edits = attach_edits
	attach_edits()
	-- No prompt about a file changed on disk: someone else wrote it. During
	-- disk_changed's own check, only record that; else under the operator's
	-- lock it is a violation (handled outside the autocmd, which may not
	-- write), and otherwise what autoread would do.
	vim.api.nvim_create_autocmd("FileChangedShell", {
		group = group,
		buffer = buf,
        callback = function()
            if s.moving then vim.v.fcs_choice = ""; return end
            local epoch = s.epoch
            s.foreign = disk_mtime(buf)
            if s.feedback then s.feedback = nil; refresh(buf) end
			if s.checking then
				vim.v.fcs_choice = ""
				return
			end
			if read_turn(buf) ~= "operator" then
				vim.v.fcs_choice = vim.bo[buf].modified and "ask" or "reload"
                if vim.v.fcs_choice == "reload" then
                    -- FileChangedShellPost ends the synchronous native check.
                    -- A scheduled callback can run inside that read's autocmds,
                    -- so scheduler progress cannot prove the read has ended.
                    native_reads[buf] = true
                end
				return
			end
			vim.v.fcs_choice = ""
			vim.schedule(function()
				if state[buf] == s and not s.moving and s.epoch == epoch and vim.api.nvim_buf_is_loaded(buf) and read_turn(buf) == "operator" then
					violation(buf)
				end
			end)
		end,
	})
	-- What the buffer last saw on disk: the base `disk_changed` compares to.
	vim.api.nvim_create_autocmd({ "BufReadPost", "BufWritePost", "FileChangedShellPost" }, {
		group = group,
		buffer = buf,
        callback = function(event)
            if event.event == "FileChangedShellPost" then native_reads[buf] = nil end
            if s.moving then return end
            s.loaded = disk_mtime(buf)
            if event.event ~= "BufWritePost" and s.feedback then s.feedback = nil; refresh(buf) end
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
            M.detach(buf)
		end,
	})
	s.loaded = disk_mtime(buf)
    refresh(buf)
    restart_idle(buf)
    if observed then M.acquire_observed(buf, observed) end
end

-- Restore only the values this attachment still owns; never release a turn.
M.detach = function(buf)
    buf = buffer_id(buf)
    native_reads[buf] = nil
    local s = state[buf]
    if not s then return end
    state[buf] = nil
    s.epoch, s.edit = s.epoch + 1, nil
    close_timer(s.watch)
    close_timer(s.idle)
    if vim.api.nvim_buf_is_valid(buf) and vim.bo[buf].autoread == false then
        vim.bo[buf].autoread = s.previous_autoread
    end
    for win, owned in pairs(s.windows or {}) do
        if vim.api.nvim_win_is_valid(win) then
            local opts = { win = win, scope = "local" }
            for _, option in ipairs({ "winbar", "winhighlight" }) do
                local installed = option == "winbar" and owned.installed_bar or owned.installed_highlight
                if vim.api.nvim_get_option_value(option, opts) == installed then
                    vim.api.nvim_set_option_value(option, owned[option], opts)
                end
            end
        end
    end
    pcall(vim.api.nvim_del_augroup_by_id, s.group)
end

-- Unknown-period edits can already have been auto-saved: modified is not
-- evidence that the operator has no outstanding edit turn.
M.acquire_observed = function(buf, observed)
    buf = buffer_id(buf)
    local s = state[buf]
    if not s or s.moving or not observed or not observed.outstanding then return false end
    if observed.loaded then s.loaded = observed.loaded end
    if read_turn(buf) == "free" and not write_lock(buf, "operator") then return false end
    s.baseline = s.baseline or observed.baseline
    s.content = content_hash(buf)
    refresh(buf)
    restart_idle(buf)
    if disk_changed(buf) then return violation(buf, true) end
    return true
end

local submit_now

--- <M-CR> in a session-sync file. `couch-owner:` is a check, not a route (#316):
--- inside a pair slot, the file is submitted only when its owner is this
--- slot's own agent. Outside pair there is no slot to compare, and the owner
--- is sent to as before.
M.submit = function(buf)
	buf = buffer_id(buf)
    local h = state[buf] and { owner = owner_of(buf) } or header(buf)
	if not h or not h.owner then
		notify("no `couch-owner:` (or legacy `owner:`) in the frontmatter", vim.log.levels.ERROR)
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

local function lock_bytes(path)
    local f = io.open(path, "rb")
    if not f then return nil end
    local bytes = f:read("*a")
    f:close()
    return bytes
end


-- Reconciliation and save are shared by legacy and registered submission.
M.prepare_submit = function(buf)
    buf = buffer_id(buf)
    if not state[buf] then M.attach(buf) end
    local s = state[buf]
    if not s or s.moving then return false, "document is not available for submission" end
    if disk_changed(buf) then
        if read_turn(buf) == "operator" then
            if not violation(buf) then return false, "the agent's copy could not be kept beside the file" end
        else
            return false, "the file changed on disk since this buffer read it; not overwriting it"
        end
    end
    if mtime_moved(buf) then return false, "disk change could not be reconciled" end
    vim.cmd("stopinsert")
    local ok, err = pcall(vim.api.nvim_buf_call, buf, function() vim.cmd("silent write") end)
    if not ok or vim.bo[buf].modified then return false, tostring(err or "save failed") end
    return true
end

-- The same acquisition-baseline release serves native undo and synthetic
-- migration protection. A matching content hash alone never owns a lock.
M.release_if_baseline = function(buf)
    buf = buffer_id(buf)
    local s = state[buf]
    if not s or s.moving or not s.baseline or content_hash(buf) ~= s.baseline then return false end
    if not s.owned_lock or lock_bytes(M.lock_path(buf)) ~= s.owned_lock then return false end
    if disk_changed(buf) then
        violation(buf)
        return false
    end
    if mtime_moved(buf) then return false end
    if vim.bo[buf].modified then
        local ok = pcall(vim.api.nvim_buf_call, buf, function() vim.cmd("silent write") end)
        if not ok or vim.bo[buf].modified or content_hash(buf) ~= s.baseline then return false end
    end
    if lock_bytes(M.lock_path(buf)) ~= s.owned_lock then return false end
    local ok = os.remove(M.lock_path(buf))
    if not ok then return false end
    refresh(buf)
    restart_idle(buf)
    return true
end

local function release_and_send(buf, owner, callback)
    local ok, err = M.prepare_submit(buf)
    if not ok then
        notify(err, vim.log.levels.ERROR)
        if callback then callback({ code = 1, stderr = err }) end
        return false, err
    end
    local lock = M.lock_path(buf)
    if vim.uv.fs_stat(lock) and not os.remove(lock) then
        err = "cannot remove " .. lock
        notify(err, vim.log.levels.ERROR)
        if callback then callback({ code = 1, stderr = err }) end
        return false, err
    end
    refresh(buf)
    restart_idle(buf)
    local s = state[buf]
    local epoch, path = s.epoch, file_of(buf)
    send(owner, "submitted: " .. path, function(obj)
        if state[buf] ~= s or s.moving or s.epoch ~= epoch then return end
        if obj.code ~= 0 then
            notify("send to " .. owner .. " failed, Alt+Return resends: " .. vim.trim(obj.stderr or ""), vim.log.levels.ERROR)
        else
            notify("submitted to " .. owner)
            s.probed = nil
            probe(buf)
        end
        if callback then callback(obj) end
    end)
    return true
end

-- Explicit registry routing uses Couch's confirmed effective owner.
M.send_registered = function(buf, identity, callback)
    buf = buffer_id(buf)
    local s = state[buf]
    if not s or not identity or identity.ID ~= s.identity.ID or identity.File ~= s.identity.File
        or identity.Owner ~= s.identity.Owner then
        local err = "registered identity changed"
        if callback then callback({ code = 1, stderr = err }) end
        return false, err
    end
    return release_and_send(buf, s.identity.Owner, callback)
end

submit_now = function(buf, h)
    M.attach(buf)
    return release_and_send(buf, h.owner)
end


-- Suspend the existing engine after preserving any foreign write. The token
-- is also the ownership proof for every later migration operation.
M.begin_move = function(buf)
    buf = buffer_id(buf)
    local s = state[buf]
    if not s or s.moving then return nil, "document already moving or detached" end
    if disk_changed(buf) then
        if read_turn(buf) ~= "operator" or not violation(buf) then return nil, "foreign change requires reconciliation" end
    end
    if mtime_moved(buf) then return nil, "disk change could not be reconciled" end
    local token = { old_path = file_of(buf), path = file_of(buf), lock = lock_bytes(M.lock_path(buf)), baseline = s.baseline }
    s.moving = { token = token, old_path = token.old_path, lock = token.lock, baseline = s.baseline }
    s.epoch, s.edit, s.probing = s.epoch + 1, nil, false
    close_timer(s.watch)
    close_timer(s.idle)
    s.watch, s.idle = nil, nil
    return token
end

-- Recovery runs only under the caller's validated journal and ID lease.
-- Matching persisted bytes prove the turn; neither path is overwritten here.
M.restore_move = function(buf, old_identity, new_path, protection)
    buf = buffer_id(buf)
    if not old_identity or type(old_identity.ID) ~= "string" or type(old_identity.File) ~= "string"
        or old_identity.File:sub(1, 1) ~= "/" or type(new_path) ~= "string" or new_path:sub(1, 1) ~= "/"
        or new_path == old_identity.File or type(protection) ~= "table" then
        return nil, "invalid migration recovery proof"
    end
    if protection.old_lock ~= nil and type(protection.old_lock) ~= "string"
        or protection.new_lock ~= nil and type(protection.new_lock) ~= "string"
        or protection.baseline ~= nil and type(protection.baseline) ~= "string" then
        return nil, "invalid migration protection bytes"
    end
    local old_lock = lock_bytes(old_identity.File .. ".lock")
    local new_lock = lock_bytes(new_path .. ".lock")
    if new_lock ~= protection.new_lock then return nil, "destination protection changed" end
    if old_lock ~= protection.old_lock then
        -- OLD cleanup can precede a crash after metadata confirmation. Only a
        -- matching held NEW proof permits resuming that forward-only handoff.
        if old_lock ~= nil or not protection.new_lock or new_lock ~= protection.new_lock then
            return nil, "source protection changed"
        end
    end
    if M.turn(protection.old_lock) == "operator" and M.turn(new_lock) ~= "operator" then
        return nil, "destination operator protection missing"
    end
    local s = state[buf]
    if s and (s.moving or s.identity.ID ~= old_identity.ID
        or (s.identity.File ~= old_identity.File and s.identity.File ~= new_path)) then
        return nil, "another document operation owns this buffer"
    end
    if not s then
        M.attach(buf, old_identity)
        s = state[buf]
        if not s then return nil, "document could not be attached" end
    end
    s.identity = vim.deepcopy(old_identity)
    s.baseline, s.owned_lock = protection.baseline, protection.baseline and protection.new_lock or nil
    local token = { old_path = old_identity.File, path = old_identity.File,
        lock = protection.old_lock, baseline = protection.baseline }
    s.moving = { token = token, old_path = old_identity.File, lock = protection.old_lock,
        baseline = protection.baseline, new_path = new_path, new_lock = protection.new_lock, effects = true }
    s.epoch, s.edit, s.probing = s.epoch + 1, nil, false
    close_timer(s.watch)
    close_timer(s.idle)
    s.watch, s.idle = nil, nil
    return token
end

M.install_move_lock = function(buf, token, new_path)
    buf = buffer_id(buf)
    local s = state[buf]
    local moving = s and s.moving
    if not moving or moving.token ~= token then return false, "stale move token" end
    if type(new_path) ~= "string" or new_path:sub(1, 1) ~= "/" or new_path == moving.old_path then
        return false, "invalid move destination"
    end
    if moving.new_path then return moving.new_path == new_path, "different move destination" end
    if M.turn(moving.lock) == "operator" then
        local fd, err = vim.uv.fs_open(new_path .. ".lock", "wx", 384)
        if not fd then return false, err end
        local written, write_err = vim.uv.fs_write(fd, moving.lock, 0)
        local closed, close_err = vim.uv.fs_close(fd)
        if written ~= #moving.lock or not closed then
            -- Preserve a partial destination lock: an effect occurred and must
            -- stay visible to recovery rather than enable unsafe cancellation.
            moving.new_path, moving.effects = new_path, true
            return false, write_err or close_err or "short lock write"
        end
        moving.effects = true
        moving.new_lock = moving.lock
    end
    moving.new_path = new_path
    return true
end

M.finish_move = function(buf, token, identity)
    buf = buffer_id(buf)
    local s = state[buf]
    local moving = s and s.moving
    if not moving or moving.token ~= token then return false, "stale move token" end
    if not identity or identity.ID ~= s.identity.ID or identity.File ~= moving.new_path then
        return false, "move identity mismatch"
    end
    if M.turn(moving.lock) == "operator" and lock_bytes(identity.File .. ".lock") ~= moving.new_lock then
        return false, "destination protection changed"
    end
    if lock_bytes(moving.old_path .. ".lock") == moving.lock and moving.lock then
        local ok, err = os.remove(moving.old_path .. ".lock")
        if not ok then return false, err end
    end
    s.identity = vim.deepcopy(identity)
    s.loaded = disk_mtime(buf)
    s.foreign, s.unkept, s.moving = nil, nil, nil
    s.probed, s.probing = nil, false
    s.content = content_hash(buf)
    s.attach_edits() -- owned native acknowledgement may reload while moving
    refresh(buf)
    restart_idle(buf)
    return true
end

M.abort_move = function(buf, token)
    buf = buffer_id(buf)
    local s = state[buf]
    local moving = s and s.moving
    if not moving or moving.token ~= token then return false, "stale move token" end
    local name = vim.fn.fnamemodify(vim.api.nvim_buf_get_name(buf), ":p")
    local current = vim.uv.fs_realpath(name) or name
    local original = vim.uv.fs_realpath(moving.old_path) or moving.old_path
    if moving.effects or current ~= original then
        return false, "move effects require forward recovery"
    end
    s.moving = nil
    refresh(buf)
    restart_idle(buf)
    return true
end

return M
