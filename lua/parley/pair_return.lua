-- parley/pair_return.lua — Return remap gated on positive composer detection.
--
-- Ported concern from pair's wrapcmd/codex_composer.go (#142) for the
-- parley side of the pair integration: plain Return rewrites to a newline
-- only when the agent's live composer is positively detected via visible
-- cursor + nearby composer surface. Unknown/hidden/inactive composer and
-- active overlay both force bare CR so pickers/menus confirm.
--
-- Pure core (no vim deps) → unit-tested directly.

local M = {}

M.COMPOSER_MIN_ROWS = 2

-- Is the composer positively active? Pure.
-- state = { rows, cols, cursorRow, cursorCol, cursorVisible, paintedRows }
-- paintedRows is map[row]=true where the agent painted its composer BG.
function M.is_composer_active(state)
	if not state then
		return false
	end
	if not state.cursorVisible then
		return false
	end
	if not state.rows or state.rows <= 0 or not state.cols or state.cols <= 0 then
		return false
	end
	if not state.cursorRow or state.cursorRow <= 0 then
		return false
	end
	local painted = state.paintedRows or {}
	local count = 0
	for row, _ in pairs(painted) do
		if row >= state.cursorRow - 1 and row <= state.cursorRow + 1 then
			count = count + 1
		end
	end
	return count >= M.COMPOSER_MIN_ROWS
end

-- Should plain Return rewrite to the agent's newline? Pure.
-- opts = { cursorVisible, composerActive, overlayActive }
function M.should_rewrite(opts)
	opts = opts or {}
	if opts.overlayActive then
		return false
	end
	if not opts.cursorVisible then
		return false
	end
	if not opts.composerActive then
		return false
	end
	return true
end

-- What <CR> should feed given popup + composer/overlay/cursor gate. Pure.
-- Extends parley.spell.cr_keys with the pair composer gate.
-- When the gate is closed, Return is bare CR (base) regardless of popup;
-- when open, delegate to the spell popup logic.
---@param visible boolean # is popup visible
---@param has_selection boolean # is popup item selected
---@param base string|nil # no-popup base (default "<CR>")
---@param gate table|nil # { cursorVisible, composerActive, overlayActive }
---@return string
function M.cr_keys(visible, has_selection, base, gate)
	base = base or "<CR>"
	gate = gate or {}
	-- Overlay and cursor/composer bypass → bare CR
	if gate.overlayActive then
		return base
	end
	if gate.cursorVisible == false then
		return base
	end
	if gate.composerActive == false then
		return base
	end
	if not visible then
		return base
	end
	if has_selection then
		return "<C-y>"
	end
	return "<C-e>" .. base
end

return M
