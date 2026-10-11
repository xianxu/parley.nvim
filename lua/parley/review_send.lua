-- parley.review_send — <M-CR> in a markdown file (#316).
--
-- The document goes to the agent in this editor's own Couch slot, steered by
-- the `process-instruction:` frontmatter line (`[mode]` stock prompts plus
-- free text, see skills/review/instruction.lua), with what changed since the
-- last send. Outside pair there is no slot: the same instruction runs today's
-- in-editor review. A `type: session-sync` file keeps its turn semantics
-- (session_sync.submit). A file without the line is asked for it once, and
-- the answer is written into the frontmatter.
--
-- Lifecycle: the per-file send baseline lives in memory (one string per file
-- sent this session) and dies with the editor; the first send after a restart
-- says so instead of diffing. Nothing is written beside the file.

local couch = require("parley.couch")
local frontmatter = require("parley.frontmatter")
local instruction = require("parley.skills.review.instruction")

local M = {}

M.KEY = "process-instruction"
M.DIFF_MAX_LINES = 200

-- Absolute path → the content at its last successful send.
local baseline = {}

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

--- Unified diff of the document since the last send; nil without a baseline. PURE.
M.diff = function(old, new)
	if old == nil then
		return nil
	end
	local diff_fn = (vim.text and vim.text.diff) or vim.diff
	local text = diff_fn(old .. "\n", new .. "\n", { result_type = "unified", ctxlen = 2 })
	local lines = vim.split(text, "\n", { trimempty = true })
	if #lines > M.DIFF_MAX_LINES then
		local cut = #lines - M.DIFF_MAX_LINES
		lines = vim.list_slice(lines, 1, M.DIFF_MAX_LINES)
		lines[#lines + 1] = ("… %d more diff lines; read the file"):format(cut)
	end
	return table.concat(lines, "\n")
end

--- The message to the slot's agent. PURE.
---@param m table { path, instruction (raw line value), brief, diff (nil = first send) }
M.message = function(m)
	local change
	if m.diff == nil then
		change = "First send this session: read the whole file."
	elseif m.diff == "" then
		change = "No change since the last send."
	else
		change = "```diff\n" .. m.diff .. "\n```"
	end
	return table.concat({
		"review request: " .. m.path,
		"process-instruction: " .. m.instruction,
		"Respond by editing the file in place (review convention: 🤖 markers).",
		"",
		m.brief,
		"",
		"## Changes since the last send (by anyone: your own edits to the file included)",
		change,
	}, "\n")
end

-- Save, then send to the slot; the baseline moves only on a delivered send.
local function send_to_slot(buf, slot, value, expanded)
	local path = vim.fn.fnamemodify(vim.api.nvim_buf_get_name(buf), ":p")
	if vim.bo[buf].modified then
		local ok, err = pcall(vim.api.nvim_buf_call, buf, function()
			vim.cmd("silent write")
		end)
		if not ok then
			notify("cannot save " .. path .. ": " .. tostring(err), vim.log.levels.ERROR)
			return
		end
	end
	local content = table.concat(vim.api.nvim_buf_get_lines(buf, 0, -1, false), "\n")
	local msg = M.message({
		path = path,
		instruction = value,
		brief = instruction.brief(expanded.modes, expanded.text),
		diff = M.diff(baseline[path], content),
	})
	couch.send(slot, msg, function(obj)
		if obj.code ~= 0 then
			notify("send to " .. slot .. " failed, Alt+Return resends: " .. vim.trim(obj.stderr or ""),
				vim.log.levels.ERROR)
			return
		end
		baseline[path] = content
		notify("sent to " .. slot)
	end)
end

--- <M-CR> in a markdown buffer.
M.submit = function(buf)
	if require("parley.session_sync").is_session_sync(buf) then
		require("parley.session_sync").submit(buf)
		return
	end
	if vim.api.nvim_buf_get_name(buf) == "" then
		notify("save the file first: the agent reads it from disk", vim.log.levels.ERROR)
		return
	end
	local lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
	local value = M.instruction_value(lines)
	if value == nil then
		vim.ui.input({ prompt = M.KEY .. ": " }, function(answer)
			if not answer or vim.trim(answer) == "" or not vim.api.nvim_buf_is_valid(buf) then
				return
			end
			local p = M.placement(vim.api.nvim_buf_get_lines(buf, 0, -1, false), vim.trim(answer))
			require("parley.buffer_edit").replace_user_lines(buf, p.first, p.last, false, p.lines)
			M.submit(buf)
		end)
		return
	end
	local expanded, err = instruction.expand(value, modes())
	if not expanded then
		notify(err, vim.log.levels.ERROR)
		return
	end
	couch.own_slot(function(actors, own)
		if not vim.api.nvim_buf_is_valid(buf) then
			return
		end
		if actors == nil then
			local names = {}
			for _, m in ipairs(expanded.modes) do
				names[#names + 1] = m.name
			end
			require("parley.skills.review").run_via_invoke(buf, { modes = names, instruction = expanded.text })
		elseif not own then
			notify("cannot resolve this slot's agent (couch --actors); nothing sent", vim.log.levels.ERROR)
		else
			send_to_slot(buf, couch.slot(own), value, expanded)
		end
	end)
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
			require("parley.buffer_edit").replace_user_lines(buf, row - 1, row, false, { line })
			vim.api.nvim_win_set_cursor(0, { row, new_col })
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
