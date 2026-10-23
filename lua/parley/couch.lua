-- parley.couch — the one seam to the `couch` binary (#316; extracted from
-- session_sync, #313). Every message leaves from this editor, so couch sees
-- the editor's own slot as the sender (pair#433 counts it as the operator's).
--
-- This editor's slot: pair launches every pane with COUCH_THREAD_SCOPE and
-- COUCH_THREAD_TAG; the actor whose binding carries both is the agent in the
-- same slot. Matching the thread, not an address string, avoids couch's alias
-- and prefix spellings of repo:N (its own LivenessForThread does the same).

local M = {}

--- No couch child lives forever (#400): a hung couch would hold its pipes and
--- stall the caller's state. A query gets the budget a submit already gets,
--- the user's setting first, read per call through the one owner of agentic
--- deadlines; a send gets longer (M.send_deadline_ms).
--- @return number
M.deadline_ms = function()
	return require("parley.document_registry").config_ms("agentic_submit_timeout_ms")
end

--- The one scheduled process seam. Returns the child for bounded cancellation.
--- `options.timeout` defaults to M.deadline_ms(); expiry kills the child and cb
--- gets code 124 (see M.timed_out). `timeout = false` is for a caller that
--- bounds the child itself (document_registry's own deadline timer).
M.run = function(argv, cb, options)
	local delivered = false
	local function finish(result)
		if delivered then return end
		delivered = true
		vim.schedule(function() cb(result) end)
	end
	local opts = vim.tbl_extend("force", { text = true, timeout = M.deadline_ms() }, options or {})
	if opts.timeout == false then opts.timeout = nil end
	local ok, child = pcall(vim.system, argv, opts, finish)
	if not ok then finish({ code = -1, stderr = tostring(child) }); return nil end
	return child
end

-- Input admission is a registry transaction, not a scheduled query. Both the
-- child deadline and synchronous wait are bounded by this operator-facing budget.
M.OPERATOR_LOCK_TIMEOUT_MS = 500

--- Pure residual budget; callers pass monotonic millisecond readings.
M.remaining_ms = function(deadline_ms, now_ms)
	return math.max(0, math.floor(deadline_ms - now_ms))
end

local function valid_turn(token)
	return type(token) == "string" and #token == 32 and token:match("^[0-9a-f]+$") ~= nil
end

--- The sidecar's unambiguous ownership evidence; unknown fields (e.g. time)
--- do not affect ownership. Recognized fields must each occur exactly once.
M.operator_proof = function(text)
	if type(text) ~= "string" then return nil end
	local fields = {}
	for line in (text .. "\n"):gmatch("([^\n]*)\n") do
		local key = line:match("^%s*([%w_-]+)%s*:")
		if key == "holder" or key == "document" or key == "turn" then
			local value = line:match("^" .. key .. ": ([^%s]+)$")
			if not value or fields[key] then return nil end
			fields[key] = value
		end
	end
	if fields.holder ~= "operator" or not fields.document or not valid_turn(fields.turn) then return nil end
	return { ID = fields.document, Turn = fields.turn }
end

local function operator_request_valid(verb, identity, token)
	return (verb == "acquire" or verb == "release") and type(identity) == "table"
		and type(identity.ID) == "string" and identity.ID ~= ""
		and type(identity.File) == "string" and identity.File:sub(1, 1) == "/" and valid_turn(token)
end

--- Classify only the producer's explicit unavailable code as degraded. A
--- malformed reply or uncertain publication never grants editing permission.
M.operator_result = function(obj, verb, identity, token)
	local function refused(reason) return { kind = "refused", error = reason } end
	if not operator_request_valid(verb, identity, token) then return refused("invalid operator lock request") end
	if type(obj) ~= "table" then return refused("missing operator lock reply") end
	if M.timed_out(obj) then return { kind = "unavailable", error = "Couch operator lock timed out after 500 ms" } end
	local ok, data = pcall(vim.json.decode, obj.stdout or "", { luanil = { object = true, array = true } })
	if not ok or type(data) ~= "table" then return refused(obj.stderr or "malformed operator lock reply") end
	if obj.code == 7 and data.Code == "session-sync-unavailable" then
		return { kind = "unavailable", error = "session-sync-unavailable" }
	end
	if obj.code ~= 0 or data.Code ~= "ok" then
		return refused(type(data.Code) == "string" and data.Code or "operator lock refused")
	end
	local lock = data.OperatorLock
	if type(lock) ~= "table" or lock.ID ~= identity.ID or lock.File ~= identity.File or lock.Turn ~= token then
		return refused("operator lock acknowledgment does not match document and turn")
	end
	if verb == "acquire" then
		local proof = M.operator_proof(lock.LockText)
		if (lock.State ~= "acquired" and lock.State ~= "already-held") or lock.Holder ~= "operator"
			or lock.LockPath ~= identity.File .. ".lock" or not proof or proof.ID ~= identity.ID or proof.Turn ~= token then
			return refused("operator lock acknowledgment has invalid ownership evidence")
		end
	elseif lock.State ~= "released" and lock.State ~= "already-released" then
		return refused("operator release acknowledgment has invalid state")
	end
	return { kind = "confirmed", lock = lock }
end

--- Acquire/release before input can apply. Spawn exceptions are explicit
--- failures, not evidence that Couch's registry transaction is unavailable.
--- Optional deadline_ms is an absolute monotonic input-admission deadline.
M.operator_lock = function(verb, identity, token, deadline_ms)
	if not operator_request_valid(verb, identity, token) then
		return { kind = "refused", error = "invalid operator lock request" }
	end
	local function budget()
		return deadline_ms and M.remaining_ms(deadline_ms, vim.uv.hrtime() / 1e6) or M.OPERATOR_LOCK_TIMEOUT_MS
	end
	local timeout = budget()
	if timeout <= 0 then return M.operator_result({ code = 124 }, verb, identity, token) end
	local argv = { "couch", "--session-sync", "operator-" .. verb, identity.File,
		"--id", identity.ID, "--turn", token, "--json" }
	local ok, result = pcall(function()
		-- Spawning may consume the last of an enclosing admission's budget.
		-- Native wait(0) kills the child but may precede its exit delivery.
		local waited = vim.system(argv, { text = true, timeout = timeout }):wait(budget())
		return waited or (deadline_ms and { code = 124 } or nil)
	end)
	if not ok then return { kind = "refused", error = tostring(result) } end
	return M.operator_result(result, verb, identity, token)
end

--- Whether a run result is its deadline's kill: vim.system reports code 124
--- once its timer fired, whatever signal ended the child. The outcome is
--- unknown; a send may already have been queued.
M.timed_out = function(obj)
	return obj.code == 124
end

-- A decoded JSON value as a list: anything but a table is empty.
M.list = function(value)
	return type(value) == "table" and value or {}
end

--- How long a send's child lives (#400): a send may already be delivered, so
--- it outlives the submit deadline, where #357 lets a press join it, until its
--- reply counts as lost (document_registry.lost_ms).
--- @return number
M.send_deadline_ms = function()
	return require("parley.document_registry").lost_ms()
end

--- One message; on_exit(obj) gets the result, in the main loop. A send killed
--- at its deadline logs one line naming the delivery, so a later duplicate can
--- be explained, and its stderr says it may have arrived.
M.send = function(to, message, on_exit)
	local argv = { "couch", "--send-to", to, "--message", message }
	local deadline_ms = M.send_deadline_ms()
	return M.run(argv, function(obj)
		if M.timed_out(obj) then
			obj.stderr = ("not confirmed within %g s; it may have arrived"):format(deadline_ms / 1000)
			require("parley.logger").warning(("couch send killed at its deadline: to=%s message=%q %s")
				:format(to, (message:match("[^\n]*")), obj.stderr))
		end
		if on_exit then on_exit(obj) end
	end, { timeout = deadline_ms })
end

--- Run a couch query; cb(decoded) with nil unless it exited 0 with Code "ok".
--- JSON null decodes to nil (never vim.NIL), so a missing field reads as absent.
--- `options` reaches vim.system (e.g. { timeout = ms }; expiry is a nonzero exit).
M.query = function(argv, cb, options)
	return M.run(argv, function(obj)
		local decoded, data = pcall(vim.json.decode, obj.stdout or "", { luanil = { object = true, array = true } })
		cb(obj.code == 0 and decoded and type(data) == "table" and data.Code == "ok" and data or nil)
	end, options)
end

local function binding(actor)
	local b = type(actor) == "table" and actor.Binding
	return type(b) == "table" and b or {}
end

--- The actor (from `couch --actors --json`) a couch address names: the exact
--- slot, else the one slot whose repository starts with the address's (couch
--- resolves `parley:1` to `parley.nvim:1` the same way). nil when none or ambiguous.
M.find_actor = function(actors, owner)
	local repo, index = (owner or ""):match("^(.*):(%d+)$")
	local prefixed = {}
	for _, actor in ipairs(M.list(actors)) do
		local slot = type(binding(actor).Slot) == "string" and binding(actor).Slot or ""
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

--- This editor's thread, from the environment pair launched it with; nil
--- outside pair.
M.thread = function()
	local scope, tag = vim.env.COUCH_THREAD_SCOPE or "", vim.env.COUCH_THREAD_TAG or ""
	if scope == "" or tag == "" then
		return nil
	end
	return { scope = scope, tag = tag }
end

--- The actor bound to `thread` ({ scope, tag }), or nil.
M.own_actor = function(actors, thread)
	if not thread then
		return nil
	end
	for _, actor in ipairs(M.list(actors)) do
		local b = binding(actor)
		if b.Scope == thread.scope and b.Tag == thread.tag then
			return actor
		end
	end
	return nil
end

--- Whether two actors are the same slot's agent.
M.same = function(a, b)
	return a ~= nil and b ~= nil and binding(a).Scope == binding(b).Scope and binding(a).Tag == binding(b).Tag
end

--- Resolve this editor's slot. cb(nil) outside pair; else cb(actors, own)
--- where `own` is nil when couch did not answer or no actor is bound to this
--- thread (actors is then the decoded list, possibly empty).
M.own_slot = function(cb)
	local thread = M.thread()
	if not thread then
		cb(nil)
		return
	end
	M.query({ "couch", "--actors", "--json" }, function(data)
		local actors = data and M.list(data.Actors) or {}
		cb(actors, M.own_actor(actors, thread))
	end)
end

--- An actor's slot address (repo:N).
M.slot = function(actor)
	return binding(actor).Slot
end

return M
