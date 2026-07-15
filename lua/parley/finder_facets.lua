local M = {}

local function copy_state(state)
	local copied = {}
	for key, enabled in pairs(state or {}) do
		copied[key] = enabled
	end
	return copied
end

M.discover = function(entries, facets_for_entry)
	local seen = {}
	for _, entry in ipairs(entries) do
		for _, key in ipairs(facets_for_entry(entry)) do
			seen[key] = true
		end
	end

	local discovered = {}
	local has_empty = seen[""] == true
	seen[""] = nil
	for key in pairs(seen) do
		table.insert(discovered, key)
	end
	table.sort(discovered)
	if has_empty then
		table.insert(discovered, "")
	end
	return discovered
end

M.merge_state = function(state, discovered)
	local merged = copy_state(state)
	for _, key in ipairs(discovered) do
		if merged[key] == nil then
			merged[key] = true
		end
	end
	return merged
end

M.toggle = function(state, key)
	local toggled = copy_state(state)
	toggled[key] = toggled[key] == false
	return toggled
end

M.set_all = function(state, enabled)
	local updated = copy_state(state)
	for key in pairs(updated) do
		updated[key] = enabled
	end
	return updated
end

M.filter = function(entries, state, facets_for_entry)
	local filtered = {}
	for _, entry in ipairs(entries) do
		local matches = false
		for _, key in ipairs(facets_for_entry(entry)) do
			if state[key] ~= false then
				matches = true
				break
			end
		end
		if matches then
			table.insert(filtered, entry)
		end
	end
	return filtered
end

M.project = function(discovered, state)
	if #discovered == 0 then
		return nil
	end

	local projected = {}
	for _, key in ipairs(discovered) do
		table.insert(projected, {
			label = key,
			enabled = state[key] ~= false,
		})
	end
	return projected
end

return M
