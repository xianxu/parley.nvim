-- parley.session_sync — turn-based shared markdown (#313).
--
-- A markdown file whose frontmatter says `type: session-sync` is shared
-- between the operator and the agent named by `couch-owner:` (`owner:` is the legacy fallback).
-- Pessimistic locking for the human, optimistic for the agent (#315): the
-- operator's lock is the only lock. The sidecar `<file>.lock`:
--   absent           free — the agent may write; a clean buffer follows its
--                    writes silently; insert entry or a normal-mode edit takes
--                    the turn (holder: operator)
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
-- Lifecycles: submit, unchanged insert exit, or a normal-mode undo to the
-- acquisition baseline removes the lock; an operator lock left
-- idle turns stale and is shown in the reminder colour until submitted. The
-- watch timer lives while the buffer is loaded (closed on unload and
-- BufWipeout, restarted by BufWinEnter); the idle
-- timer is one per buffer, restarted on each edit and closed on BufWipeout.
-- `<file>.clobbered` is one per file, overwritten by the next violation and
-- removed by whoever reads it. Probes are one-shot couch processes, one at a
-- time per buffer.

local M = {}
local couch = require("parley.couch")
local window_views = require("parley.window_views")
local operator_admission = require("parley.operator_admission")

M.POLL_MS = 1000
M.PING_CHECK_MS = 60000
-- An owner whose slot showed no activity for this long has ended its turn
-- (couch's own QuietInterval, the rule its routing uses).
M.QUIET_SECONDS = 30

local ns_group = "ParleySessionSync"

-- Per-buffer state: { turn, stale, loaded (disk mtime last read/written),
-- foreign (the disk mtime of the last write Neovim saw as someone else's),
-- checking (inside disk_changed's :checktime), edit (latest pending clean-edit
-- reconciliation token), inserting (current insert intent), operator_admission
-- (private history owner), gated_modifiable/retry_maps (owned refusal UI),
-- retry_entry (one queued native entry sharing a completed retry), content
-- (last observed buffer hash), edits_attached (native edit callback installed),
-- watch = timer|nil, idle = timer|nil, owed (epoch of the oldest owed event
-- couch last reported, or nil), minutes (rendered owed minutes), violated /
-- complained (this operator turn), unkept (the disk mtime of an agent copy
-- that could not be kept), probing / probed (vim.uv.now() of the last
-- probe), pinged (the LastWrite value last pinged; false when absent),
-- feedback (bounded submission receipt/error, cleared by operator edit or foreign reload) }
local state = {}
local buffer_reads, native_reads = {}, {}
local dispatch_admission

local function admission(s)
    return s.operator_admission.snapshot()
end

local function observe_content(buf, s, content)
    s.content = content
    dispatch_admission(buf, { type = "observe", content = content })
end

local function observe_reload(buf, s, after, clean)
    if s.moving then return observe_content(buf, s, after) end
    local before = s.content
    s.content = after
    dispatch_admission(buf, { type = "reload", before = before, after = after, clean = clean })
end

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
	free = { hl = "ParleySessionSyncFree", label = "free: insert mode or an edit takes your turn" },
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
    if flags.admission then
        return { state = "unknown", label = flags.admission_message, hl = "ParleySessionSyncStale" }
    end
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
-- An existing lock with no local baseline remains an outstanding turn.
M.has_unsubmitted = function(turn, baseline, current)
    return turn == "operator" and (not baseline or baseline ~= current)
end

M.feedback_view = require("parley.document_band").feedback_view

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

local function lock_bytes(path)
    local f = io.open(path, "rb")
    if not f then return nil end
    local bytes = f:read("*a")
    f:close()
    return bytes
end

local function write_lock(buf, holder, baseline)
	local s = state[buffer_id(buf)]
    if s and admission(s).acquire_token then return false end
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
    if s then dispatch_admission(buf, { type = "legacy_adopt", baseline = baseline, content = s.content, proof = bytes }) end
    return true
end

-- Restore only the option value owned by this attachment's edit gate.
local function restore_edit_gate(buf, s)
    if s.gated_modifiable ~= nil then
        if vim.bo[buf].modifiable == false then vim.bo[buf].modifiable = s.gated_modifiable end
        s.gated_modifiable = nil
    end
end

-- Only refusal owns these local maps. Preserve local overrides and uncover
-- global mappings again, without deleting a mapping changed by the operator.
local function retry_maps(buf, s, refused)
    if refused and not s.retry_maps then
        s.retry_maps = {}
        for _, key in ipairs({ "i", "a", "o", "I", "A", "O" }) do
            local saved = vim.api.nvim_buf_call(buf, function() return vim.fn.maparg(key, "n", false, true) end)
            local callback = function()
                if M.retry(buf) and vim.bo[buf].modifiable then
                    -- The immediately queued native command shares this retry's
                    -- admission, including its single bounded unavailable call.
                    local entry = { epoch = s.epoch, token = admission(s).acquire_token }
                    s.retry_entry = entry
                    vim.api.nvim_feedkeys(key, "ni", false)
                end
            end
            s.retry_maps[key] = { saved = saved.buffer == 1 and saved or nil, callback = callback }
            vim.keymap.set("n", key, callback, { buffer = buf, silent = true, desc = "Retry session lock" })
        end
    elseif not refused and s.retry_maps then
        for key, mapping in pairs(s.retry_maps) do
            local current = vim.api.nvim_buf_call(buf, function() return vim.fn.maparg(key, "n", false, true) end)
            if current.buffer == 1 and current.callback == mapping.callback then
                vim.keymap.del("n", key, { buffer = buf })
                if mapping.saved then
                    vim.api.nvim_buf_call(buf, function() vim.fn.mapset("n", false, mapping.saved) end)
                end
            end
        end
        s.retry_maps = nil
    end
end

local function release_owned(buf, path, expected)
    local s = state[buf]
    local owned = admission(s)
    local proof = couch.operator_proof(expected)
    if proof then
        if proof.ID ~= s.identity.ID or expected ~= owned.owned_lock and proof.Turn ~= owned.acquire_token then
            return false, "operator protection belongs to another turn"
        end
    elseif expected and (expected:find("\ndocument:", 1, true) or expected:find("\nturn:", 1, true)) then
        return false, "operator ownership evidence is invalid"
    elseif s.identity.ID and (not expected or expected ~= owned.owned_lock) then
        return false, "registered operator protection has no confirmed ownership"
    end
    if not owned.owned_lock and not s.identity.ID then
        local adopted, reason = dispatch_admission(buf, { type = "legacy_adopt", proof = expected, content = s.content })
        if not adopted then return false, reason end
    end
    return dispatch_admission(buf, { type = "release" }, path)
end

local send, query, list = couch.send, couch.query, couch.list

local function close_timer(timer)
	if timer and not timer:is_closing() then
		timer:stop()
		timer:close()
	end
end

local function render(buf, view)
    local s = state[buf]
    s.renderer = s.renderer or require("parley.document_band").new(buf)
    s.renderer.render(view)
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
    local views = window_views.capture(buf)
    M.with_buffer_read(buf, function()
        vim.api.nvim_buf_call(buf, function()
            vim.cmd("silent edit!")
        end)
    end)
    window_views.restore(buf, views)
	state[buf].probed = nil
	probe(buf)
	require("parley.edit_round").refresh(buf) -- the write is usually the agent's round (#383)
end

local function refusal_message(reason)
    local label = reason == "operator-lock" and "held by operator" or "not locked: " .. tostring(reason)
    return label .. "; press i to retry (:ParleySessionRetry); keys not applied"
end

-- The shell runs effects; only the private owner advances admission history.
-- Every completion carries its operation witness back, including release.
dispatch_admission = function(buf, event, release_path)
    local s = state[buf]
    if not s then return false, "document is detached" end
    local effect, error_message = s.operator_admission.dispatch(event)
    if error_message then return false, error_message end
    if event.type ~= "acquire" and event.type ~= "release" then return true end
    local releasing = event.type == "release"
    if releasing and not effect then return false, error_message or "no owned operator turn" end
    while effect do
        local outcome = { witness = effect.witness }
        if effect.kind == "acquire" then
            local result = couch.operator_lock("acquire", s.identity, effect.token)
            if result.kind == "confirmed" and lock_bytes(M.lock_path(buf)) ~= result.lock.LockText then
                result = { kind = "refused", error = "operator protection changed after acknowledgment" }
            end
            if result.kind == "confirmed" then
                outcome.type, outcome.proof = "acquired", result.lock.LockText
            else
                outcome.type = result.kind
                outcome.message = result.kind == "unavailable"
                    and "not locked: Couch unreachable; edits may conflict" or refusal_message(result.error)
            end
        elseif effect.kind == "freshen" then
            restore_edit_gate(buf, s)
            s.admitting = true
            local checked, reason = pcall(vim.api.nvim_buf_call, buf, function() vim.cmd("silent checktime " .. buf) end)
            if checked and mtime_moved(buf) then checked, reason = pcall(reload, buf) end
            s.admitting = nil
            if checked and not vim.bo[buf].modified then
                outcome.type, outcome.content, outcome.clean = "freshened", content_hash(buf), true
                s.foreign = nil
            else
                outcome.type, outcome.message = "refused", refusal_message("freshness check failed: " .. tostring(reason or "buffer changed"))
            end
        elseif effect.kind == "release" then
            local parsed = couch.operator_proof(effect.proof)
            local token = effect.token or parsed and parsed.Turn
            local path = release_path or file_of(buf)
            local ok, reason
            if token then
                local result = couch.operator_lock("release", { ID = s.identity.ID, File = path }, token)
                ok, reason = result.kind == "confirmed", result.error
            else
                -- Legacy exact-byte protection has no Couch turn identity.
                if effect.proof and lock_bytes(path .. ".lock") == effect.proof then
                    ok, reason = os.remove(path .. ".lock")
                else reason = "operator protection changed" end
            end
            outcome.type = ok and "released" or "release_failed"
            error_message = not ok and reason or nil
        else
            error("unknown operator admission effect: " .. tostring(effect.kind))
        end
        if state[buf] ~= s then return false, "document is detached" end
        local next_effect, _, accepted = s.operator_admission.dispatch(outcome)
        effect = next_effect
        if accepted == false then return false, "operator admission changed while awaiting reply" end
    end
    local view = admission(s)
    if view.phase == "refused" then
        if s.gated_modifiable == nil then s.gated_modifiable = vim.bo[buf].modifiable end
        vim.bo[buf].modifiable = false
        retry_maps(buf, s, true)
        if not releasing then notify(view.admission_message, vim.log.levels.ERROR) end
    else
        restore_edit_gate(buf, s)
        retry_maps(buf, s, false)
    end
    if releasing then return error_message == nil, error_message end
    refresh(buf)
    return view.phase == "held" or view.phase == "unconfirmed"
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
    local protected = read_turn(buf) == "operator"
	local verb = race and "changed as you started typing:" or protected and "wrote under your lock:" or "changed on disk:"
	local when = race and " as the operator started editing" or protected and " while the operator held the lock"
        or " while the operator had local changes"
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
		if (turn == "operator" and s.turn == "operator" or admission(s).unconfirmed_edit) and disk_changed(buf) then
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
	if turn ~= "operator" and admission(s).admission ~= "unavailable" then
		s.stale, s.violated, s.complained = false, false, false
	end
	s.minutes = owed_minutes(buf)
	start_watch(buf)
	local view = M.view(turn, vim.tbl_extend("force", s, admission(s)), owner_of(buf))
    view.unsent = admission(s).baseline ~= nil and content_hash(buf) ~= admission(s).baseline
    view.feedback = not admission(s).admission and s.feedback or nil
    render(buf, view)
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
		ParleySessionSyncLeave = { bg = "#ff0000", fg = "#ffffff", ctermbg = 196, ctermfg = 231, bold = true },
		ParleySessionSyncOperator = { bg = "#870000", fg = "#ffffff", ctermbg = 88, ctermfg = 231, bold = true },
		ParleySessionSyncStale = { bg = "#ff8700", fg = "#000000", ctermbg = 208, ctermfg = 16, bold = true },
		ParleySessionSyncOwed = { link = "DiffChange" },
	}
	for name, spec in pairs(groups) do
		vim.api.nvim_set_hl(0, name, vim.tbl_extend("force", spec, { default = true }))
	end
end

--- Install the turn autocmds on a session-sync buffer and render its turn. Idempotent.
M.attach = function(buf, identity, observed, restoring_move)
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
        previous_autoread = vim.bo[buf].autoread, operator_admission = operator_admission.new() }
    state[buf] = s
	require("parley.highlight_groups").keep("session_sync", define_highlights)
	define_highlights()
	-- With autoread an unmodified buffer reloads on :checktime without
	-- FileChangedShell: an agent write under the lock right after an
	-- auto-save would replace the operator's text (#317).
	vim.bo[buf].autoread = false
	local group = vim.api.nvim_create_augroup(ns_group .. buf, { clear = true })
    s.group = group
    local function outstanding()
        return state[buf] == s and not s.moving and vim.api.nvim_buf_is_valid(buf)
            and M.has_unsubmitted(read_turn(buf), admission(s).baseline, s.content)
    end
    vim.api.nvim_create_autocmd({ "BufLeave", "WinLeave" }, { group = group, buffer = buf, callback = function()
        if outstanding() then
            require("parley.document_band").flash(vim.api.nvim_get_current_win(), buf, outstanding)
        end
    end })

    -- One admission policy serves insert intent and normal-mode first edits.
    -- Only a clean insert entry is allowed to establish a fresh native baseline.
    local function acquire_registered(baseline, entering)
        local owned = admission(s)
        if owned.phase == "held" and owned.owned_lock and couch.operator_proof(owned.owned_lock)
            and lock_bytes(M.lock_path(buf)) == owned.owned_lock then return true end
        local token = owned.acquire_token
        if not token then
            local ok, random = pcall(vim.uv.random, 16)
            if ok and type(random) == "string" and #random == 16 then
                token = (random:gsub(".", function(byte) return ("%02x"):format(byte:byte()) end))
            end
        end
        return dispatch_admission(buf, { type = "acquire", baseline = baseline,
            content = content_hash(buf), token = token, clean = entering and not vim.bo[buf].modified })
    end

    s.acquire_turn = acquire_registered

    -- Dirty edit races reconcile outside input autocmds. Clean insert freshness
    -- uses the nested, narrowly permitted native reread above.
    local function take_turn(baseline)
        if state[buf] ~= s or s.moving or read_turn(buf) ~= "free" then return end
        local moved, epoch = mtime_moved(buf), s.epoch
        if s.identity.ID then
            if not acquire_registered(baseline, false) then return end
        else
            if not write_lock(buf, "operator", baseline) then return end
            refresh(buf)
        end
        vim.schedule(function()
            if moved and state[buf] == s and not s.moving and s.epoch == epoch and vim.api.nvim_buf_is_loaded(buf)
                and read_turn(buf) == "operator" and disk_changed(buf) then
                violation(buf, true)
            end
        end)
    end
    local function insert_enter()
        if state[buf] ~= s then return end
        s.inserting = true
        if s.moving then return end
        local baseline = not vim.bo[buf].modified and content_hash(buf) or admission(s).baseline
        local retried = s.retry_entry
        s.retry_entry = nil
        -- A refused-state key already completed this exact admission.
        if not (retried and retried.epoch == s.epoch and retried.token == admission(s).acquire_token) then
            if s.identity.ID then acquire_registered(baseline, true)
            else take_turn(baseline) end
        end
        restart_idle(buf)
    end
    vim.api.nvim_create_autocmd("InsertEnter", {group=group, buffer=buf, nested=true, callback=insert_enter})
    vim.api.nvim_buf_create_user_command(buf, "ParleySessionRetry", function() M.retry(buf) end,
        { desc = "Retry this document's operator lock" })
    vim.api.nvim_create_autocmd({"InsertLeave", "ModeChanged"}, {group=group, buffer=buf, callback=function(event)
        if not s.inserting then return end
        if event.event == "ModeChanged" and vim.v.event.new_mode:match("^[iR]") then return end
        s.inserting = nil
        local epoch = s.epoch
        -- Release may classify a foreign disk write with checktime. Like edit
        -- reconciliation, it must run after the input autocmd/auto-save settles.
        vim.schedule(function()
            if state[buf] == s and not s.moving and s.epoch == epoch and vim.api.nvim_buf_is_loaded(buf) then
                M.release_if_baseline(buf)
            end
        end)
    end})

	-- Acquire in the edit notification, before TextChanged/InsertLeave auto-save
	-- callbacks can clear 'modified' (#324). This buffer was identified at
	-- attach: an edit to its YAML must not remove its protection.
	local function attach_edits()
		if s.edits_attached then return end
		observe_content(buf, s, content_hash(buf))
		s.edits_attached = vim.api.nvim_buf_attach(buf, false, {
			on_lines = function()
				if state[buf] ~= s then
					return true
				end
                local previous = s.content
                observe_content(buf, s, content_hash(buf))
                if s.moving then return end
                if s.feedback and previous ~= s.content and vim.bo[buf].modified then
                    s.feedback = nil
                    refresh(buf) -- synchronous: an earlier TextChanged auto-save must see it cleared
                end
                local epoch = s.epoch
				-- The pure owner derives outstanding work from the observed hash.
                if vim.bo[buf].modified and not admission(s).admission then take_turn(previous) end
				restart_idle(buf)
				-- Reconcile only the latest edit, after native undo and auto-save
				-- settle. Saves never advance the acquisition baseline (#330).
				local edit = {}
				s.edit = edit
				vim.schedule(function()
					if state[buf] ~= s or s.moving or s.epoch ~= epoch or s.edit ~= edit or not vim.api.nvim_buf_is_loaded(buf) then
						return
					end
                    if admission(s).baseline and content_hash(buf) == admission(s).baseline and read_turn(buf) == "operator" then
                        M.release_if_baseline(buf)
                    end
				end)
			end,
			-- An external reload is not an operator edit; keep the attachment for
			-- the next keystroke and invalidate any pending clean-edit check.
			on_reload = function()
                observe_reload(buf, s, content_hash(buf), not vim.bo[buf].modified)
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
	-- lock or with registered local edits it needs preservation outside the
    -- autocmd (which may not write); otherwise follow the clean disk read.
	vim.api.nvim_create_autocmd("FileChangedShell", {
		group = group,
		buffer = buf,
        callback = function()
            if s.moving then vim.v.fcs_choice = ""; return end
            local epoch = s.epoch
            s.foreign = disk_mtime(buf)
            if s.feedback then s.feedback = nil; refresh(buf) end
            if s.admitting and not vim.bo[buf].modified then vim.v.fcs_choice = "reload"; return end
			if s.checking then
				vim.v.fcs_choice = ""
				return
			end
            local registered_dirty = s.identity.ID and vim.bo[buf].modified
            if registered_dirty and not admission(s).history then
                -- Attachment may follow an edit. Remember that work through
                -- the sole owner, with unknown preimage, before preservation's
                -- write clears modified and a later disk read could discard it.
                dispatch_admission(buf, { type = "observed", content = content_hash(buf) })
            end
			if read_turn(buf) ~= "operator" and not admission(s).unconfirmed_edit and not registered_dirty then
				vim.v.fcs_choice = vim.bo[buf].modified and "ask" or "reload"
                if vim.v.fcs_choice == "reload" then
                    -- FileChangedShellPost ends the synchronous native check.
                    -- A scheduled callback can run inside that read's autocmds,
                    -- so scheduler progress cannot prove the read has ended.
                    native_reads[buf] = true
                    s.views = window_views.capture(buf) -- restored at FileChangedShellPost
                end
				return
			end
			vim.v.fcs_choice = ""
            local id, path = s.identity.ID, s.identity.File
			vim.schedule(function()
				if state[buf] == s and not s.moving and s.epoch == epoch
                    and s.identity.ID == id and s.identity.File == path and vim.api.nvim_buf_is_loaded(buf)
                    and (read_turn(buf) == "operator" or admission(s).unconfirmed_edit or (id and vim.bo[buf].modified)) then
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
            if event.event == "FileChangedShellPost" then
                native_reads[buf] = nil
                if s.views then window_views.restore(buf, s.views); s.views = nil end
                require("parley.edit_round").refresh(buf)
            end
            if s.moving then return end
            s.loaded = disk_mtime(buf)
            -- :edit! detaches native observers before BufReadPost, whereas a
            -- checktime reload retains on_reload. Both publish the same fact
            -- before attach_edits can replace the cached preimage.
            if event.event ~= "BufWritePost" then
                observe_reload(buf, s, content_hash(buf), not vim.bo[buf].modified)
            end
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
    require("parley.edit_round").refresh(buf)
    if observed then M.acquire_observed(buf, observed) end
    if vim.api.nvim_get_current_buf() == buf and vim.fn.mode():match("^[iR]") then
        if restoring_move then s.inserting = true else insert_enter() end
    end
end

-- Restore only the values this attachment still owns; never release a turn.
M.detach = function(buf)
    buf = buffer_id(buf)
    native_reads[buf] = nil
    local s = state[buf]
    if not s then return end
    if vim.api.nvim_buf_is_valid(buf) then
        restore_edit_gate(buf, s)
        retry_maps(buf, s, false)
        pcall(vim.api.nvim_buf_del_user_command, buf, "ParleySessionRetry")
    end
    state[buf] = nil
    s.epoch, s.edit = s.epoch + 1, nil
    close_timer(s.watch)
    close_timer(s.idle)
    if vim.api.nvim_buf_is_valid(buf) and vim.bo[buf].autoread == false then
        vim.bo[buf].autoread = s.previous_autoread
    end
    if s.renderer then s.renderer.clear() end
    pcall(vim.api.nvim_del_augroup_by_id, s.group)
end

M.retry = function(buf)
    buf = buffer_id(buf)
    local s = state[buf]
    if not s or s.moving or not s.identity.ID then return false end
    local baseline = not vim.bo[buf].modified and content_hash(buf) or admission(s).baseline
    return s.acquire_turn(baseline, true)
end

-- Unknown-period edits can already have been auto-saved: modified is not
-- evidence that the operator has no outstanding edit turn.
M.acquire_observed = function(buf, observed)
    buf = buffer_id(buf)
    local s = state[buf]
    if not s or s.moving or not observed or not observed.outstanding then return false end
    if observed.loaded then s.loaded = observed.loaded end
    if read_turn(buf) == "free" then
        if s.identity.ID then
            if not s.acquire_turn(observed.baseline, false) then return false end
        elseif not write_lock(buf, "operator", observed.baseline) then return false end
    end
    dispatch_admission(buf, { type = "observed", baseline = observed.baseline, content = content_hash(buf) })
    observe_content(buf, s, content_hash(buf))
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




-- Reconciliation and save are shared by legacy and registered submission.
M.prepare_submit = function(buf)
    buf = buffer_id(buf)
    if not state[buf] then M.attach(buf) end
    local s = state[buf]
    if not s or s.moving then return false, "document is not available for submission" end
    if disk_changed(buf) then
        if read_turn(buf) == "operator" or admission(s).unconfirmed_edit then
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

local function insert_intent(buf)
    local s = state[buf]
    return s and s.inserting
        or vim.api.nvim_get_current_buf() == buf and vim.fn.mode():match("^[iR]") ~= nil
end

local function automatic_release_eligible(buf, s)
    return not insert_intent(buf) and admission(s).baseline ~= nil
end

-- The same acquisition-baseline release serves native undo and synthetic
-- migration protection. A matching content hash alone never owns a lock.
M.release_if_baseline = function(buf)
    buf = buffer_id(buf)
    local s = state[buf]
    if not s or s.moving or not automatic_release_eligible(buf, s) or content_hash(buf) ~= admission(s).baseline then return false end
    if not admission(s).owned_lock or lock_bytes(M.lock_path(buf)) ~= admission(s).owned_lock then return false end
    if disk_changed(buf) then
        violation(buf)
        return false
    end
    if mtime_moved(buf) then return false end
    if vim.bo[buf].modified then
        local ok = pcall(vim.api.nvim_buf_call, buf, function() vim.cmd("silent write") end)
        if not ok or vim.bo[buf].modified or content_hash(buf) ~= admission(s).baseline then return false end
    end
    if lock_bytes(M.lock_path(buf)) ~= admission(s).owned_lock then return false end
    local ok = release_owned(buf, file_of(buf), admission(s).owned_lock)
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
    if vim.uv.fs_stat(lock) then
        ok, err = release_owned(buf, file_of(buf), lock_bytes(lock))
    elseif admission(state[buf]).acquire_token then
        ok, err = dispatch_admission(buf, { type = "release" })
    end
    if not ok then
        err = "cannot release " .. lock .. ": " .. tostring(err)
        notify(err, vim.log.levels.ERROR)
        if callback then callback({ code = 1, stderr = err }) end
        return false, err
    end
    refresh(buf)
    restart_idle(buf)
    local s = state[buf]
    local epoch, path = s.epoch, file_of(buf)
    -- The attention finder (#354) records every submit Couch accepted, with the
    -- breadcrumb taken now: the operator may move on while the send runs.
    local attention = require("parley.attention")
    local taken, breadcrumb = pcall(attention.breadcrumb, vim.fn.bufwinid(buf))
    breadcrumb = taken and breadcrumb or nil
    send(owner, "submitted: " .. path, function(obj)
        -- Sent is sent, whatever the engine did meanwhile: record before the
        -- guard. The record is optional work on this path, so it can't throw.
        if obj.code == 0 then
            -- The operator answered the agent's round (#383).
            require("parley.edit_round").clear(buf)
            local recorded, why = pcall(attention.record, path, breadcrumb, obj)
            if not recorded then notify("attention: the submit was not tracked: " .. tostring(why), vim.log.levels.WARN) end
        end
        if state[buf] ~= s or s.moving or s.epoch ~= epoch then return end
        if couch.timed_out(obj) then
            notify("send to " .. owner .. " " .. obj.stderr .. ". Alt+Return resends", vim.log.levels.WARN)
        elseif obj.code ~= 0 then
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
    local token = { old_path = file_of(buf), path = file_of(buf), lock = lock_bytes(M.lock_path(buf)), baseline = admission(s).baseline }
    s.moving = { token = token, old_path = token.old_path, lock = token.lock, baseline = admission(s).baseline }
    s.epoch, s.edit, s.probing = s.epoch + 1, nil, false
    close_timer(s.watch)
    close_timer(s.idle)
    s.watch, s.idle = nil, nil
    return token
end

-- Finalization can authorize an absent lock as an after-state. Only ENOENT
-- proves absence: unreadable files, directories and symlinks remain unknown.
local function finalization_lock(path)
    local st, stat_error, code = vim.uv.fs_lstat(path)
    if not st then
        if code == "ENOENT" then return true, nil end
        return false, stat_error or "lock state is unknown"
    end
    if st.type ~= "file" then return false, "lock is not a regular file" end
    local stream, open_error = io.open(path, "rb")
    if not stream then return false, open_error end
    local bytes, read_error = stream:read("*a")
    local closed, close_error = stream:close()
    if not bytes or not closed then return false, read_error or close_error or "lock could not be read" end
    return true, bytes
end

-- Recovery runs only under the caller's validated journal and ID lease.
-- Matching persisted bytes prove the turn; neither path is overwritten here.
M.restore_move = function(buf, old_identity, new_path, protection, finalization)
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
    -- A persisted release is permission for the old turn, never a new insert
    -- intent. Refuse before attach can acquire obsolete protection at OLD.
    if finalization and protection.new_lock and finalization.new_lock_after == false and insert_intent(buf) then
        return nil, "leave insert mode and reopen " .. new_path .. " to finish this move"
    end
    local old_lock = lock_bytes(old_identity.File .. ".lock")
    local new_lock = lock_bytes(new_path .. ".lock")
    if finalization then
        local old_ok, new_ok
        old_ok, old_lock = finalization_lock(old_identity.File .. ".lock")
        new_ok, new_lock = finalization_lock(new_path .. ".lock")
        if not old_ok then return nil, old_lock end
        if not new_ok then return nil, new_lock end
        local after = finalization.stage == "protection" or finalization.stage == "retire"
        if finalization.stage ~= "handoff" and not after
            or finalization.old_lock_before ~= (protection.old_lock or false)
            or finalization.new_lock_before ~= (protection.new_lock or false)
            or finalization.new_lock_after ~= false and finalization.new_lock_after ~= finalization.new_lock_before
            or type(finalization.editor_hash) ~= "string" or content_hash(buf) ~= finalization.editor_hash
            or protection.new_lock and finalization.new_lock_after == false
                and (vim.bo[buf].modified or protection.baseline ~= finalization.editor_hash) then
            return nil, "invalid finalization recovery proof"
        end
        local held_new = protection.new_lock ~= nil and new_lock == protection.new_lock
        if finalization.stage == "retire" and old_lock ~= nil
            or old_lock ~= protection.old_lock and not (old_lock == nil and (after or held_new)) then
            return nil, "source protection changed"
        end
        local expected_after = finalization.new_lock_after ~= false and finalization.new_lock_after or nil
        if finalization.stage == "retire" and new_lock ~= expected_after
            or new_lock ~= protection.new_lock and not (after and new_lock == expected_after) then
            return nil, "destination protection changed"
        end
    else
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
    end
    local s = state[buf]
    if s and (s.moving or s.identity.ID ~= old_identity.ID
        or (s.identity.File ~= old_identity.File and s.identity.File ~= new_path)) then
        return nil, "another document operation owns this buffer"
    end
    if not s then
        -- The journal proof above already owns this turn. Late attachment must
        -- preserve insert intent without attempting a new acquisition at OLD.
        M.attach(buf, old_identity, nil, true)
        s = state[buf]
        if not s then return nil, "document could not be attached" end
    end
    s.identity = vim.deepcopy(old_identity)
    local restored_proof = protection.baseline and protection.new_lock or nil
    local parsed_proof = couch.operator_proof(restored_proof)
    local restored, restore_error = dispatch_admission(buf, { type = "restore", baseline = protection.baseline,
        proof = restored_proof, token = parsed_proof and parsed_proof.Turn })
    if not restored then return nil, restore_error end
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

-- A guarded native reread has acknowledged the journal's parent rewrite.
-- Keep migration suspended until metadata confirms, while translating only a
-- baseline equal to the pre-rewrite editor content (never an outstanding edit).
M.synchronize_move = function(buf, token, expected_before_content_hash)
    buf = buffer_id(buf)
    local s = state[buf]
    local moving = s and s.moving
    if not moving or moving.token ~= token then return false, "stale move token" end
    if type(expected_before_content_hash) ~= "string" or expected_before_content_hash == "" then
        return false, "invalid move content proof"
    end
    if not vim.api.nvim_buf_is_loaded(buf) or vim.bo[buf].modified then
        return false, "move buffer is unloaded or modified"
    end
    local path = vim.fn.fnamemodify(vim.api.nvim_buf_get_name(buf), ":p")
    path = vim.uv.fs_realpath(path) or path
    if not moving.new_path or path ~= moving.new_path then return false, "move buffer path changed" end
    if lock_bytes(moving.new_path .. ".lock") ~= moving.new_lock then
        return false, "destination protection changed"
    end
    local observed = vim.uv.fs_stat(moving.new_path)
    if not observed or observed.type ~= "file" then return false, "move destination is unavailable" end
    local content = content_hash(buf)
    dispatch_admission(buf, { type = "rebase", before = expected_before_content_hash, after = content })
    local baseline = admission(s).baseline
    moving.baseline, token.baseline = baseline, baseline
    s.loaded = observed.mtime.sec .. "." .. observed.mtime.nsec
    observe_content(buf, s, content)
    s.attach_edits()
    return true, { old_lock = moving.lock, new_lock = moving.new_lock, baseline = baseline }
end

-- Persist the returned intent in the move journal before invoking cleanup.
-- A synthetic turn can be released only at its current acquisition baseline.
M.move_finalization_snapshot = function(buf, token)
    buf = buffer_id(buf)
    local s = state[buf]
    local moving = s and s.moving
    if not moving or moving.token ~= token then return false, "stale move token" end
    if not vim.api.nvim_buf_is_loaded(buf) then return false, "move buffer is unloaded" end
    local path = vim.fn.fnamemodify(vim.api.nvim_buf_get_name(buf), ":p")
    if (vim.uv.fs_realpath(path) or path) ~= moving.new_path then return false, "reopen " .. tostring(moving.new_path) .. " to finish this move" end
    local old_ok, old = finalization_lock(moving.old_path .. ".lock")
    local new_ok, new = finalization_lock(moving.new_path .. ".lock")
    if not old_ok then return false, old end
    if not new_ok then return false, new end
    if new ~= moving.new_lock or old ~= moving.lock and not (old == nil and moving.new_lock ~= nil) then
        return false, "move protection changed before finalization intent"
    end
    local content = content_hash(buf)
    local release = not vim.bo[buf].modified and automatic_release_eligible(buf, s)
        and admission(s).baseline == content and admission(s).owned_lock == moving.new_lock
    return true, { old_lock_before = moving.lock or false, new_lock_before = moving.new_lock or false,
        new_lock_after = not release and moving.new_lock or false, editor_hash = content }
end

-- The journal has published its protection stage. Absence is an after-witness,
-- never permission to remove different bytes. Keep watchers suspended throughout.
M.prepare_move_finalization = function(buf, token, intent)
    buf = buffer_id(buf)
    local s = state[buf]
    local moving = s and s.moving
    if not moving or moving.token ~= token then return false, "stale move token" end
    if type(intent) ~= "table" or intent.stage ~= "protection" and intent.stage ~= "retire"
        or intent.old_lock_before ~= (moving.lock or false) or intent.new_lock_before ~= (moving.new_lock or false)
        or intent.new_lock_after ~= false and intent.new_lock_after ~= intent.new_lock_before
        or not vim.api.nvim_buf_is_loaded(buf) or content_hash(buf) ~= intent.editor_hash then
        return false, "invalid finalization proof or changed editor content"
    end
    local path = vim.fn.fnamemodify(vim.api.nvim_buf_get_name(buf), ":p")
    if (vim.uv.fs_realpath(path) or path) ~= moving.new_path then return false, "reopen " .. tostring(moving.new_path) .. " to finish this move" end
    -- Revalidate at the effect boundary, including protection/retire replay.
    if moving.new_lock and intent.new_lock_after == false and insert_intent(buf) then
        return false, "leave insert mode and reopen " .. moving.new_path .. " to finish this move"
    end
    if moving.new_lock and intent.new_lock_after == false
        and (vim.bo[buf].modified or admission(s).history and (not automatic_release_eligible(buf, s)
            or admission(s).baseline ~= intent.editor_hash or admission(s).owned_lock ~= moving.new_lock)) then
        return false, "operator turn changed before finalization"
    end
    local old_ok, old = finalization_lock(moving.old_path .. ".lock")
    local new_ok, new = finalization_lock(moving.new_path .. ".lock")
    if not old_ok then return false, old end
    if not new_ok then return false, new end
    local after = intent.new_lock_after ~= false and intent.new_lock_after or nil
    if intent.stage == "retire" and (old ~= nil or new ~= after)
        or old ~= nil and old ~= moving.lock or new ~= moving.new_lock and new ~= after then
        return false, "move protection changed during finalization"
    end
    if old then
        local ok, err = os.remove(moving.old_path .. ".lock")
        if not ok then return false, err end
    end
    if new and after == nil then
        if not admission(s).history then
            -- A retained, validated journal can replay its exact before-state
            -- after a confirmed release. Restore that witness through the same
            -- owner; never adopt different bytes or a current insert intent.
            local proof = couch.operator_proof(new)
            local restored, reason = dispatch_admission(buf, { type = "restore", baseline = moving.baseline,
                proof = new, token = proof and proof.Turn })
            if not restored then return false, reason end
        end
        local ok, err = release_owned(buf, moving.new_path, moving.new_lock)
        if not ok then return false, err end
    end
    moving.finalized = true
    local st = vim.uv.fs_stat(moving.new_path)
    moving.finalized_loaded = st and (st.mtime.sec .. "." .. st.mtime.nsec) or ""
    return true
end

-- Journal retirement already owns every filesystem effect. This acknowledgment
-- only resumes the editor; it never removes a lock or rewrites a document.
M.retire_move = function(buf, token, identity)
    buf = buffer_id(buf)
    local s = state[buf]
    local moving = s and s.moving
    if not moving or moving.token ~= token or not moving.finalized then return false, "move finalization incomplete" end
    if not identity or identity.ID ~= s.identity.ID or identity.File ~= moving.new_path then
        return false, "move identity mismatch"
    end
    s.identity = vim.deepcopy(identity)
    s.loaded = moving.finalized_loaded
    observe_content(buf, s, content_hash(buf))
    s.foreign, s.unkept, s.moving = nil, nil, nil
    s.probed, s.probing = nil, false
    s.attach_edits()
    refresh(buf)
    restart_idle(buf)
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
    observe_content(buf, s, content_hash(buf))
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
