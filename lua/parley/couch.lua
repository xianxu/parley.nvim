-- parley.couch — the one seam to the `couch` binary (#316; extracted from
-- session_sync, #313). Every message leaves from this editor, so couch sees
-- the editor's own slot as the sender (pair#433 counts it as the operator's).
--
-- This editor's slot: pair launches every pane with COUCH_THREAD_SCOPE and
-- COUCH_THREAD_TAG; the actor whose binding carries both is the agent in the
-- same slot. Matching the thread, not an address string, avoids couch's alias
-- and prefix spellings of repo:N (its own LivenessForThread does the same).

local M = {}

-- A decoded JSON value as a list: anything but a table is empty.
M.list = function(value)
	return type(value) == "table" and value or {}
end

--- One message; on_exit(obj) gets the result, in the main loop.
M.send = function(to, message, on_exit)
	local argv = { "couch", "--send-to", to, "--message", message }
	local ok, err = pcall(vim.system, argv, { text = true }, vim.schedule_wrap(on_exit or function() end))
	if not ok and on_exit then
		on_exit({ code = -1, stderr = tostring(err) })
	end
end

--- Run a couch query; cb(decoded) with nil unless it exited 0 with Code "ok".
--- JSON null decodes to nil (never vim.NIL), so a missing field reads as absent.
M.query = function(argv, cb)
	local ok = pcall(vim.system, argv, { text = true }, vim.schedule_wrap(function(obj)
		local decoded, data = pcall(vim.json.decode, obj.stdout or "", { luanil = { object = true, array = true } })
		cb(obj.code == 0 and decoded and type(data) == "table" and data.Code == "ok" and data or nil)
	end))
	if not ok then
		cb(nil)
	end
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
