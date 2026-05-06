-- Chat buffer folding for parley.
--
-- Uses the exchange_model to compute fold regions. Each answer block
-- (🧠:, text, 🔧:, 📎:, 📝:) gets its own fold. Questions and
-- agent headers are never folded.
--
-- foldmethod=manual — folds are created explicitly from model positions.
-- No foldexpr evaluation, no backward scanning.

local M = {}

-- Block kinds that should be folded
local FOLDABLE = {
    tool_use = true,
    tool_result = true,
}

-- Structural prefixes that terminate a marker region (the terminator line
-- itself is NOT part of the fold). All marker prefixes mutually terminate
-- each other so consecutive blocks fold individually.
local STRUCTURAL_TERMINATORS = {
    "💬:", "🤖:", "🔧:", "📎:", "📝:", "🌿:", "🔒:", "🧠:", "---",
}

local function line_starts_with_terminator(line)
    for _, prefix in ipairs(STRUCTURAL_TERMINATORS) do
        if line:sub(1, #prefix) == prefix then return true end
    end
    return false
end

-- Compute fold ranges (1-indexed inclusive) for lines whose first content is
-- the given marker prefix. A region opens at the marker line and extends to
-- the line immediately before the next structural marker (or end of buffer).
-- For `🧠:`, an explicit `🧠:[END]` line closes the region (inclusive).
-- min_size = 1 produces folds even for single-line regions (suitable for the
-- typically one-line `📝:` summary). min_size = 2 skips lone-marker lines.
local function compute_marker_ranges(lines, prefix, min_size)
    local ranges = {}
    local end_marker = (prefix == "🧠:") and "🧠:[END]" or nil
    local i = 1
    while i <= #lines do
        if lines[i]:sub(1, #prefix) == prefix then
            local start_1 = i
            local end_1 = #lines
            local cursor = i + 1
            while cursor <= #lines do
                local line = lines[cursor]
                if end_marker and line:sub(1, #end_marker) == end_marker then
                    end_1 = cursor
                    break
                end
                if line_starts_with_terminator(line) then
                    end_1 = cursor - 1
                    break
                end
                cursor = cursor + 1
            end
            -- Trim trailing blank lines from the fold so we don't pull the
            -- inter-block separator into the marker's region.
            while end_1 > start_1 and not lines[end_1]:match("%S") do
                end_1 = end_1 - 1
            end
            if end_1 - start_1 + 1 >= min_size then
                table.insert(ranges, { start_1, end_1 })
            end
            i = end_1 + 1
        else
            i = i + 1
        end
    end
    return ranges
end
M._compute_marker_ranges = compute_marker_ranges
-- Backward-compat alias for the original reasoning-only spec.
M._compute_reasoning_ranges = function(lines)
    return compute_marker_ranges(lines, "🧠:", 2)
end

--- Compute and apply folds from the exchange model.
--- @param buf integer
function M.apply_folds(buf)
    if not vim.api.nvim_buf_is_valid(buf) then return end

    local chat_parser = require("parley.chat_parser")
    local exchange_model = require("parley.exchange_model")
    local cfg = require("parley.config")
    local lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
    local header_end = chat_parser.find_header_end(lines)
    if not header_end then return end
    local parsed = chat_parser.parse_chat(lines, header_end, cfg)
    local model = exchange_model.from_parsed_chat(parsed)

    -- Clear existing folds
    vim.cmd("normal! zE")

    -- Create a fold for each foldable block
    for k, ex in ipairs(model.exchanges) do
        for b, blk in ipairs(ex.blocks) do
            if FOLDABLE[blk.kind] and blk.size > 0 then
                local start_0 = model:block_start(k, b)
                local end_0 = model:block_end(k, b)
                -- Convert 0-indexed to 1-indexed for vim commands
                local start_1 = start_0 + 1
                local end_1 = end_0 + 1
                if start_1 <= #lines and end_1 <= #lines and start_1 <= end_1 then
                    pcall(vim.cmd, start_1 .. "," .. end_1 .. "fold")
                end
            end
        end
    end

    -- Reasoning (🧠:) and summary (📝:) regions aren't their own model
    -- blocks — the parser folds them into the answer's text. Compute their
    -- ranges from buffer lines. 🧠: requires multi-line bodies; 📝: lines
    -- are typically single and still benefit from being collapsed.
    local marker_ranges = {}
    for _, r in ipairs(compute_marker_ranges(lines, "🧠:", 2)) do
        table.insert(marker_ranges, r)
    end
    for _, r in ipairs(compute_marker_ranges(lines, "📝:", 1)) do
        table.insert(marker_ranges, r)
    end
    for _, range in ipairs(marker_ranges) do
        local start_1, end_1 = range[1], range[2]
        if start_1 <= #lines and end_1 <= #lines and start_1 <= end_1 then
            pcall(vim.cmd, start_1 .. "," .. end_1 .. "fold")
        end
    end

    -- Close all folds
    pcall(vim.cmd, "normal! zM")
    -- Keep cursor visible
    pcall(vim.cmd, "normal! zv")
end

--- Custom fold text.
function M.foldtext()
    local start_line = vim.fn.getline(vim.v.foldstart)
    local line_count = vim.v.foldend - vim.v.foldstart + 1

    if start_line:match("^🔧:") then
        local name = start_line:match("^🔧:%s*(%S+)") or "tool"
        return string.format("🔧 %s (%d lines) ", name, line_count)
    elseif start_line:match("^📎:") then
        local name = start_line:match("^📎:%s*(%S+)") or "result"
        local is_error = start_line:match("error=true") and " error" or ""
        return string.format("📎 %s%s (%d lines) ", name, is_error, line_count)
    elseif start_line:match("^🧠:") then
        return "🧠 thinking (" .. line_count .. " lines) "
    elseif start_line:match("^📝:") then
        return "📝 summary (" .. line_count .. " lines) "
    else
        local preview = start_line:sub(1, 60)
        if #start_line > 60 then preview = preview .. "..." end
        return preview .. " (" .. line_count .. " lines) "
    end
end

--- Set up folding on a chat buffer.
function M.setup(buf)
    vim.api.nvim_set_option_value("foldmethod", "manual", { win = 0 })
    vim.api.nvim_set_option_value("foldtext", "v:lua.require('parley.tool_folds').foldtext()", { win = 0 })
    vim.api.nvim_set_option_value("foldcolumn", "1", { win = 0 })
    -- Apply folds from the model
    vim.schedule(function()
        M.apply_folds(buf)
    end)
end

--- Reapply folds after tool_loop writes blocks.
function M.close_tool_folds(buf)
    vim.schedule(function()
        M.apply_folds(buf)
    end)
end

return M
