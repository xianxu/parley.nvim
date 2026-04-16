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

local function parse_marker_sections(text, pos)
    local sections = {}
    local cursor = pos + 3  -- skip ㊷ (3-byte UTF-8: E3 8A B7)

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

M.parse_markers = function(lines)
    local fence_ranges = compute_fence_ranges(lines)
    local markers = {}
    local marker_char = "㊷"

    for i, line in ipairs(lines) do
        if not in_code_fence(fence_ranges, i - 1) then
            local search_start = 1
            while true do
                local pos = line:find(marker_char, search_start, true)
                if not pos then break end

                local sections, end_pos = parse_marker_sections(line, pos)
                if #sections > 0 then
                    local ready = (#sections % 2) == 1
                    table.insert(markers, {
                        line = i - 1,
                        col = pos - 1,
                        sections = sections,
                        ready = ready,
                        raw = line:sub(pos, end_pos - 1),
                    })
                end
                search_start = end_pos
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

M.populate_quickfix = function(buf, markers, filter)
    local file_name = vim.api.nvim_buf_get_name(buf)
    local items = {}
    for _, marker in ipairs(markers) do
        local include = (filter ~= "pending") or (not marker.ready)
        if include then
            local last_section = marker.sections[#marker.sections]
            local text = last_section and (last_section.type == "agent"
                and "Agent asks: " .. last_section.text
                or "User: " .. last_section.text) or marker.raw
            table.insert(items, {
                filename = file_name,
                lnum = marker.line + 1,
                col = marker.col + 1,
                text = text,
            })
        end
    end
    vim.fn.setqflist(items, "r")
    if #items > 0 then
        vim.cmd("copen")
    end
end

--------------------------------------------------------------------------------
-- Skill definition
--------------------------------------------------------------------------------

M.skill = {
    name = "review",
    description = "Edit document based on review markers",
    args = {
        { name = "level", description = "Edit intensity",
          complete = function() return { "edit", "revise" } end },
    },

    system_prompt = function(args, file_path, content, skill_md)
        local level = args.level or "edit"
        local section_header = level == "edit" and "## LIGHT_EDIT" or "## HEAVY_REVISION"
        -- Extract base (everything before first section header)
        local base = skill_md:match("^(.-)## LIGHT_EDIT") or skill_md
        -- Extract the chosen section
        local section = skill_md:match(section_header .. "\n(.-)\n##")
            or skill_md:match(section_header .. "\n(.+)$")
            or ""
        return base .. "\n" .. section
    end,

    pre_submit = function(buf, args)
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

    post_apply = function(buf, args, result, new_content, resubmit_count)
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
-- Keybindings (buffer-local, for markdown files)
--------------------------------------------------------------------------------

M.setup_keymaps = function(buf)
    local parley = get_parley()
    local cfg = parley.config
    local set_keymap = parley.helpers.set_keymap

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

    -- <C-g>ve: light edit (fast path, bypasses picker)
    local edit_cfg = cfg.review_shortcut_edit
    if edit_cfg then
        for _, mode in ipairs(edit_cfg.modes or {}) do
            set_keymap({ buf }, mode, edit_cfg.shortcut, function()
                get_runner().run(buf, M.skill, { level = "edit" })
            end, "Parley review: light edit")
        end
    end

    -- <C-g>vr: heavy revision (fast path, bypasses picker)
    local revise_cfg = cfg.review_shortcut_revise
    if revise_cfg then
        for _, mode in ipairs(revise_cfg.modes or {}) do
            set_keymap({ buf }, mode, revise_cfg.shortcut, function()
                get_runner().run(buf, M.skill, { level = "revise" })
            end, "Parley review: heavy revision")
        end
    end
end

return M
