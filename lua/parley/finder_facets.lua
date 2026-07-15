local M = {}

local function copy_state(state)
	local copied = {}
	for key, enabled in pairs(state or {}) do
		copied[key] = enabled
	end
	return copied
end

M.discover = function(entries, facets_for_entry, ordering)
	local seen = {}
	local discovered = {}
	local has_empty = false
	for _, entry in ipairs(entries) do
		for _, key in ipairs(facets_for_entry(entry)) do
			if key == "" then
				has_empty = true
			elseif not seen[key] then
				seen[key] = true
				table.insert(discovered, key)
			end
		end
	end

	if ordering ~= "source" then
		table.sort(discovered)
	end
	if has_empty then
		table.insert(discovered, "")
	end
	return discovered
end

M.eligible_labels = function(entries, active, label_for_entry)
	if not active then
		return nil
	end

	local labels = {}
	for _, entry in ipairs(entries) do
		local label = label_for_entry(entry)
		if type(label) ~= "string" or label == "" then
			return nil
		end
		table.insert(labels, label)
	end

	local discovered = M.discover(labels, function(label)
		return { label }
	end)
	if #discovered < 2 then
		return nil
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
