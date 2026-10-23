-- Alt+Return submits Couch documents through S1's registered coordinator.
-- Outside Couch, effective editorial settings select the local inline review.
-- This module owns no peer transport, payload builder or diff baseline.

local frontmatter = require("parley.frontmatter")
local instruction = require("parley.skills.review.instruction")

local M = {}

M.KEY = "process-instruction"

local function notify(msg, level)
	vim.notify("review: " .. msg, level or vim.log.levels.INFO)
end

local function modes()
	local dir = (vim.api.nvim_get_runtime_file("lua/parley/skills/review/modes", false) or {})[1]
	return dir and require("parley.skills.review.mode").list(dir) or {}
end

--- The instruction text from frontmatter lines; nil when the key is absent.
--- A quoted value is its quoted scalar (a comment may follow it); a plain one
--- is the whole line after the colon, `#` included.
---@param lines string[]
---@return string|nil
M.instruction_value = function(lines)
	local fm = frontmatter.parse(lines)
	local raw = fm and fm.raw[M.KEY]
	if raw and frontmatter.quoted_span(raw) then
		return fm.fields[M.KEY] or ""
	end
	return raw
end

--- The frontmatter line for a value, quoted when a strict YAML reader needs it.
M.format_line = function(value)
	return M.KEY .. ": " .. (frontmatter.needs_quote(value) and frontmatter.quote(value) or value)
end

--- Where the line for `value` goes: { first, last, lines } in nvim_buf_set_lines
--- terms (0-based, end exclusive). Replaces an existing line, else inserts
--- before the closing fence, else adds a frontmatter. PURE.
M.placement = function(lines, value)
	local line = M.format_line(value)
	local fm = frontmatter.parse(lines)
	if fm and fm.lnum[M.KEY] then
		return { first = fm.lnum[M.KEY] - 1, last = fm.lnum[M.KEY], lines = { line } }
	elseif fm then
		return { first = fm.close - 1, last = fm.close - 1, lines = { line } }
	end
	return { first = 0, last = 0, lines = { "---", line, "---" } }
end

--- <M-CR> in a markdown buffer.
M.submit = function(buf)
    if require("parley.agentic_document").submit(buf) then return end
    if vim.api.nvim_buf_get_name(buf) == "" then
        notify("save the file first: the agent reads it from disk", vim.log.levels.ERROR)
        return
    end
    local projection, err = require("parley.editorial_prepare").prepare(buf, "ReviewSend")
    if not projection then notify(err, vim.log.levels.ERROR); return end
    for _, warning in ipairs(projection.settings.warnings) do notify(warning, vim.log.levels.WARN) end
    if require("parley.session_sync").is_session_sync(buf) then
        require("parley.session_sync").submit(buf)
        return
    end
    if projection.skip_reason then
        local settings, problem = require("parley.editorial_frontmatter").resolve(
            vim.api.nvim_buf_get_lines(buf, 0, -1, false), modes())
        if not settings then notify(problem, vim.log.levels.ERROR); return end
        projection.settings = settings
    end
    local saved, save_error = pcall(vim.api.nvim_buf_call, buf, function() vim.cmd("silent write") end)
    if not saved or not vim.api.nvim_buf_is_valid(buf) or vim.bo[buf].modified then
        notify("save failed: " .. tostring(save_error or "document remains modified"), vim.log.levels.ERROR)
        return
    end
    local path = vim.api.nvim_buf_get_name(buf)
    path = (vim.uv or vim.loop).fs_realpath(path) or path
    if path ~= projection.path
        or vim.fn.sha256(vim.json.encode(vim.api.nvim_buf_get_lines(buf, 0, -1, false))) ~= projection.after_hash then
        notify("submit cancelled: document changed while saving", vim.log.levels.WARN)
        return
    end
    local names = {}
    for _, mode in ipairs(projection.settings.modes) do names[#names + 1] = mode.name end
    notify("local review: using " .. table.concat(names, ", ") .. " (outside Couch)")
    require("parley.skills.review").run_via_invoke(buf, {
        modes = names, instruction = projection.settings.instruction,
    })
end

--------------------------------------------------------------------------------
-- `[` completion in the process-instruction value
--------------------------------------------------------------------------------

local LINE = "^[Pp]rocess%-instruction:%s*"

--- The 1-based column where a mode name starts, when the text before the
--- cursor is the value's run of `[name]`s ending in an open `[`; else nil. PURE.
M.completion_start = function(before)
	local head = before:match(LINE .. '"?')
	if not head then
		return nil
	end
	local run = before:sub(#head + 1)
	if run:sub(-1) ~= "[" or run:sub(1, -2):gsub("%[[^%]]*%]", "") ~= "" then
		return nil
	end
	return #before + 1
end

--- The line once completion ended: the value quoted when it needs it (an
--- opened, unclosed quote gets its closing one), and the cursor column
--- (0-based) on the same text. PURE.
M.requote = function(line, col)
	local head = line:match(LINE)
	if not head then
		return nil
	end
	local opened = line:sub(#head + 1, #head + 1)
	if opened:match("[\"']") then
		if frontmatter.quoted_span(line:sub(#head + 1)) then
			return nil
		end
		return line .. opened, col
	end
	local value = line:sub(#head + 1)
	if not frontmatter.needs_quote(value) then
		return nil
	end
	local before = line:sub(#head + 1, col)
	local escaped = before:gsub("\\", "\\\\"):gsub('"', '\\"')
	return M.KEY .. ": " .. frontmatter.quote(value), #(M.KEY .. ": ") + 1 + #escaped
end

local function in_frontmatter(buf, row)
	local fm = frontmatter.parse(vim.api.nvim_buf_get_lines(buf, 0, 60, false))
	return fm ~= nil and row > 1 and row < fm.close
end

--- TextChangedI: offer the mode names after an `[` in the value.
M.on_text_changed = function(buf)
	local row, col = unpack(vim.api.nvim_win_get_cursor(0))
	local line = vim.api.nvim_get_current_line()
	local start = M.completion_start(line:sub(1, col))
	if not start or not in_frontmatter(buf, row) then
		return
	end
	vim.b[buf].parley_instruction_completing = true
	vim.fn.complete(start, instruction.complete(modes()))
end

--- CompleteDone: quote the value a strict YAML reader would reject.
M.on_complete_done = function(buf)
	if not vim.b[buf].parley_instruction_completing then
		return
	end
	vim.b[buf].parley_instruction_completing = false
	vim.schedule(function()
		if not vim.api.nvim_buf_is_valid(buf) or vim.api.nvim_get_current_buf() ~= buf then
			return
		end
		local row, col = unpack(vim.api.nvim_win_get_cursor(0))
		local line, new_col = M.requote(vim.api.nvim_get_current_line(), col)
		if line then
			-- Cosmetic requoting; a refusal is quiet and leaves the line as typed (#265).
			if require("parley.buffer_edit").edit_user_lines("ReviewSend", buf, row - 1, row, { line },
				{ quiet = true }) then
				vim.api.nvim_win_set_cursor(0, { row, new_col })
			end
		end
	end)
end

--- Install the completion autocmds on a markdown buffer. Idempotent.
M.attach = function(buf)
	local group = vim.api.nvim_create_augroup("ParleyReviewSend" .. buf, { clear = true })
	vim.api.nvim_create_autocmd("TextChangedI", {
		group = group,
		buffer = buf,
		callback = function()
			M.on_text_changed(buf)
		end,
	})
	vim.api.nvim_create_autocmd("CompleteDone", {
		group = group,
		buffer = buf,
		callback = function()
			M.on_complete_done(buf)
		end,
	})
	vim.api.nvim_create_autocmd("BufWipeout", {
		group = group,
		buffer = buf,
		callback = function()
			pcall(vim.api.nvim_del_augroup_by_id, group)
		end,
	})
end

return M
