-- review skill — Edit document based on ㊷ review markers.
--
-- Marker syntax:  ㊷[user]{agent}[user]{agent}...
--   [] = user turns, {} = agent turns, strictly alternating
--   Odd section count = ready for agent, even = awaiting user response

local M = {}

local _parley
local _skill_runner

local function get_parley()
    if not _parley then _parley = require("parley") end
    return _parley
end

local function get_runner()
    if not _skill_runner then _skill_runner = require("parley.skill_runner") end
    return _skill_runner
end

--------------------------------------------------------------------------------
-- Marker parsing (extracted from review.lua)
--------------------------------------------------------------------------------

local function find_matching_bracket(text, start, open, close)
    local depth = 0
    for i = start, #text do
        local ch = text:sub(i, i)
        if ch == open then
            depth = depth + 1
        elseif ch == close then
            depth = depth - 1
            if depth == 0 then
                return i
            end
        end
    end
    return nil
end

local function parse_marker_sections(text, pos, byte_len)
    local sections = {}
    local cursor = pos + (byte_len or 3)  -- ㊷=3 bytes, 🤖=4 bytes

    while cursor <= #text do
        local ch = text:sub(cursor, cursor)
        if ch == "[" then
            local close = find_matching_bracket(text, cursor, "[", "]")
            if not close then break end
            table.insert(sections, {
                type = "user",
                text = text:sub(cursor + 1, close - 1),
                byte_start = cursor,
                byte_end = close,
            })
            cursor = close + 1
        elseif ch == "{" then
            local close = find_matching_bracket(text, cursor, "{", "}")
            if not close then break end
            table.insert(sections, {
                type = "agent",
                text = text:sub(cursor + 1, close - 1),
                byte_start = cursor,
                byte_end = close,
            })
            cursor = close + 1
        else
            break
        end
    end

    return sections, cursor
end

local function in_code_fence(fence_ranges, line_idx)
    for _, range in ipairs(fence_ranges) do
        if line_idx >= range[1] and line_idx <= range[2] then
            return true
        end
    end
    return false
end

local function compute_fence_ranges(lines)
    local ranges = {}
    local fence_start = nil
    for i, line in ipairs(lines) do
        if line:match("^```") then
            if fence_start then
                table.insert(ranges, { fence_start, i - 1 })
                fence_start = nil
            else
                fence_start = i - 1
            end
        end
    end
    if fence_start then
        table.insert(ranges, { fence_start, #lines - 1 })
    end
    return ranges
end

-- marker_defs: { char, byte_len, marker_type }
-- human (㊷): [] = user turns, {} = agent turns. odd section count = ready.
-- machine (🤖): [] = agent turns, {} = user turns. even section count = ready.
local MARKER_DEFS = {
    { char = "㊷", byte_len = 3, marker_type = "human" },
    { char = "🤖", byte_len = 4, marker_type = "machine" },
}

M.parse_markers = function(lines)
    local fence_ranges = compute_fence_ranges(lines)
    local markers = {}

    for i, line in ipairs(lines) do
        if not in_code_fence(fence_ranges, i - 1) then
            for _, md in ipairs(MARKER_DEFS) do
                local search_start = 1
                while true do
                    local pos = line:find(md.char, search_start, true)
                    if not pos then break end

                    local sections, end_pos = parse_marker_sections(line, pos, md.byte_len)
                    if #sections > 0 then
                        local ready
                        if md.marker_type == "human" then
                            ready = (#sections % 2) == 1
                        else
                            ready = (#sections % 2) == 0
                        end
                        table.insert(markers, {
                            line = i - 1,
                            col = pos - 1,
                            sections = sections,
                            ready = ready,
                            raw = line:sub(pos, end_pos - 1),
                            marker_type = md.marker_type,
                        })
                    end
                    search_start = end_pos
                end
            end
        end
    end

    return markers
end

-- Expose for highlighter.lua backward compatibility
M._parse_marker_sections = parse_marker_sections

--------------------------------------------------------------------------------
-- Quickfix helpers
--------------------------------------------------------------------------------

local function marker_summary(marker)
    local last = marker.sections[#marker.sections]
    if not last then return marker.raw end
    if marker.marker_type == "machine" then
        return last.type == "user"
            and "🤖 " .. last.text
            or "🤖 You: " .. last.text
    else
        return last.type == "agent"
            and "㊷ Agent asks: " .. last.text
            or "㊷ " .. last.text
    end
end

M.populate_quickfix = function(buf, markers, filter)
    local file_name = vim.api.nvim_buf_get_name(buf)
    local items = {}
    for _, marker in ipairs(markers) do
        local include = (filter ~= "pending") or (not marker.ready)
        if include then
            table.insert(items, {
                filename = file_name,
                lnum = marker.line + 1,
                col = marker.col + 1,
                text = marker_summary(marker),
            })
        end
    end
    vim.fn.setqflist(items, "r")
    if #items > 0 then
        vim.cmd("copen")
    end
end

-- Scan all .md files under dir for pending (non-ready) markers.
-- Returns list of { filepath, marker } sorted by filepath then line.
M.scan_pending = function(dir)
    local results = {}
    local files = vim.fn.glob(dir .. "/**/*.md", false, true)
    -- also catch top-level .md files (** may not match depth-0 on all systems)
    for _, f in ipairs(vim.fn.glob(dir .. "/*.md", false, true)) do
        table.insert(files, f)
    end
    local seen = {}
    for _, filepath in ipairs(files) do
        filepath = vim.fn.resolve(filepath)
        if not seen[filepath] then
            seen[filepath] = true
            local ok, lines = pcall(vim.fn.readfile, filepath)
            if ok and lines then
                local markers = M.parse_markers(lines)
                for _, marker in ipairs(markers) do
                    if not marker.ready then
                        table.insert(results, { filepath = filepath, marker = marker })
                    end
                end
            end
        end
    end
    return results
end

-- Open a float picker listing all pending review markers under cwd.
-- Only runs inside a parley-enabled repo (.parley marker file present at git root).
M.cmd_review_finder = function()
    local parley = get_parley()
    if not parley.config.repo_root then
        parley.logger.warning("Review finder: not in a parley-enabled repo")
        return
    end

    local cwd = vim.fn.getcwd()
    local pending = M.scan_pending(cwd)

    if #pending == 0 then
        parley.logger.info("Review finder: no pending markers found")
        return
    end

    -- Group by file, preserving first-occurrence order
    local file_order = {}
    local counts = {}
    for _, entry in ipairs(pending) do
        local fp = entry.filepath
        if not counts[fp] then
            counts[fp] = 0
            table.insert(file_order, fp)
        end
        counts[fp] = counts[fp] + 1
    end

    local items = {}
    for _, fp in ipairs(file_order) do
        local rel = vim.fn.fnamemodify(fp, ":~:.")
        local n = counts[fp]
        table.insert(items, {
            display = rel .. "  (" .. n .. ")",
            search_text = rel,
            value = fp,
        })
    end

    require("parley.float_picker").open({
        title = "Pending Review (" .. #items .. " files)",
        items = items,
        anchor = "top",
        on_select = function(item)
            vim.cmd("edit " .. vim.fn.fnameescape(item.value))
        end,
    })
end

--------------------------------------------------------------------------------
-- Skill definition
--------------------------------------------------------------------------------

M.skill = {
    name = "review",
    description = "Edit document based on review markers",
    args = {},

    system_prompt = function(_args, _file_path, _content, skill_md)
        return skill_md
    end,

    pre_submit = function(buf, _args)
        local lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
        local markers = M.parse_markers(lines)

        if #markers == 0 then
            get_runner().clear_decorations(buf)
            vim.fn.setqflist({}, "r")
            pcall(vim.cmd, "cclose")
            get_parley().logger.info("Review: complete — no markers found")
            return false
        end

        local pending = {}
        for _, marker in ipairs(markers) do
            if not marker.ready then table.insert(pending, marker) end
        end

        if #pending > 0 then
            M.populate_quickfix(buf, pending, "pending")
            get_parley().logger.warning("Review: " .. #pending .. " marker(s) need your response")
            return false, #pending .. " marker(s) need your response"
        end

        vim.fn.setqflist({}, "r")
        pcall(vim.cmd, "cclose")
        return true
    end,

    post_apply = function(buf, args, _result, _new_content, resubmit_count)
        local new_lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
        local remaining = M.parse_markers(new_lines)
        if #remaining == 0 then
            get_parley().logger.info("Review: all comments addressed")
            return
        end

        local has_questions = false
        for _, marker in ipairs(remaining) do
            if not marker.ready then
                has_questions = true
                break
            end
        end

        if has_questions then
            M.populate_quickfix(buf, remaining, "pending")
            get_parley().logger.info("Review: agent has follow-up questions")
        elseif (resubmit_count or 0) < 3 then
            get_parley().logger.info("Review: " .. #remaining .. " marker(s) remain, resubmitting...")
            get_runner().run(buf, M.skill, args, (resubmit_count or 0) + 1)
        end
    end,
}

--------------------------------------------------------------------------------
-- On-enter quickfix scan
--------------------------------------------------------------------------------

local _qf_scanned_bufs = {}

-- Called once per buffer on first BufEnter. Populates quickfix if there are
-- pending markers (waiting for human response) so the human sees them immediately.
local function scan_on_enter(buf)
    if _qf_scanned_bufs[buf] then return end
    _qf_scanned_bufs[buf] = true
    vim.api.nvim_buf_attach(buf, false, {
        on_detach = function() _qf_scanned_bufs[buf] = nil end,
    })

    local lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
    local markers = M.parse_markers(lines)
    local pending = {}
    for _, marker in ipairs(markers) do
        if not marker.ready then table.insert(pending, marker) end
    end
    if #pending > 0 then
        M.populate_quickfix(buf, pending, "pending")
    end
end

--------------------------------------------------------------------------------
-- Keybindings (buffer-local, for markdown files)
--------------------------------------------------------------------------------

M.setup_keymaps = function(buf)
    local parley = get_parley()
    local cfg = parley.config
    local set_keymap = parley.helpers.set_keymap

    scan_on_enter(buf)

    -- <C-g>vi: insert ㊷[] marker
    local insert_cfg = cfg.review_shortcut_insert
    if insert_cfg then
        for _, mode in ipairs(insert_cfg.modes or {}) do
            if mode == "v" or mode == "x" then
                set_keymap({ buf }, mode, insert_cfg.shortcut, function()
                    local start_pos = vim.fn.getpos("'<")
                    local end_pos = vim.fn.getpos("'>")
                    local start_line = start_pos[2]
                    local start_col = start_pos[3]
                    local end_line = end_pos[2]
                    local end_col = end_pos[3]

                    if start_line == end_line then
                        local line = vim.api.nvim_buf_get_lines(buf, start_line - 1, start_line, false)[1]
                        local before = line:sub(1, start_col - 1)
                        local selected = line:sub(start_col, end_col)
                        local after = line:sub(end_col + 1)
                        vim.api.nvim_buf_set_lines(buf, start_line - 1, start_line, false, {
                            before .. "㊷[" .. selected .. "]" .. after,
                        })
                    end
                end, "Parley review: wrap selection with marker")
            else
                set_keymap({ buf }, mode, insert_cfg.shortcut, function()
                    local cursor = vim.api.nvim_win_get_cursor(0)
                    local row = cursor[1] - 1
                    local col = cursor[2]
                    local line = vim.api.nvim_buf_get_lines(buf, row, row + 1, false)[1] or ""
                    local before = line:sub(1, col)
                    local after = line:sub(col + 1)
                    vim.api.nvim_buf_set_lines(buf, row, row + 1, false, {
                        before .. "㊷[]" .. after,
                    })
                    vim.api.nvim_win_set_cursor(0, { row + 1, col + 4 })
                    vim.cmd("startinsert")
                end, "Parley review: insert marker")
            end
        end
    end

    -- <C-g>vR: insert 🤖[] machine-initiated marker (for testing/debugging)
    local insert_machine_cfg = cfg.review_shortcut_insert_machine
    if insert_machine_cfg then
        for _, mode in ipairs(insert_machine_cfg.modes or {}) do
            set_keymap({ buf }, mode, insert_machine_cfg.shortcut, function()
                local cursor = vim.api.nvim_win_get_cursor(0)
                local row = cursor[1] - 1
                local col = cursor[2]
                local line = vim.api.nvim_buf_get_lines(buf, row, row + 1, false)[1] or ""
                local before = line:sub(1, col)
                local after = line:sub(col + 1)
                vim.api.nvim_buf_set_lines(buf, row, row + 1, false, {
                    before .. "🤖[]" .. after,
                })
                vim.api.nvim_win_set_cursor(0, { row + 1, col + 5 })
                vim.cmd("startinsert")
            end, "Parley review: insert machine marker")
        end
    end

    -- <C-g>ve: run review
    local edit_cfg = cfg.review_shortcut_edit
    if edit_cfg then
        for _, mode in ipairs(edit_cfg.modes or {}) do
            set_keymap({ buf }, mode, edit_cfg.shortcut, function()
                get_runner().run(buf, M.skill, {})
            end, "Parley review: process markers")
        end
    end
end

return M
