-- Outline module for Parley.nvim
-- Provides navigation through chat messages and markdown headers

local M = {}

-- Build a code block state table for all lines in the buffer with a single bulk read.
-- Returns a table mapping 1-based line numbers to boolean (true = inside code block).
local function build_code_block_memo(bufnr)
  local all_lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
  local memo = {}
  local in_block = false

  for i, line_content in ipairs(all_lines) do
    if line_content:match("^%s*```") or line_content:match("^%s*~~~") then
      in_block = not in_block
    end
    memo[i] = in_block
  end

  return memo
end

-- Compatibility wrapper used by is_outline_item and exposed for testing.
local function is_in_code_block(bufnr, line_number, memo)
  if memo[line_number] ~= nil then
    return memo[line_number]
  end
  -- Fallback: compute lazily (should rarely happen when memo is pre-built)
  local all_lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
  local in_block = false
  for i = 1, line_number do
    local lc = all_lines[i] or ""
    if lc:match("^%s*```") or lc:match("^%s*~~~") then
      in_block = not in_block
    end
    memo[i] = in_block
  end
  return memo[line_number] or false
end

-- Function to check if a line should be included in the outline
-- Returns: boolean (should be included), string (type), string (formatted content)
-- Optional all_lines parameter avoids per-line buffer reads when bulk lines are available.
local function is_outline_item(bufnr, line_number, config, code_block_memo, all_lines)
  -- Get the line content (use pre-fetched lines if available)
  local line = all_lines and all_lines[line_number]
    or vim.api.nvim_buf_get_lines(bufnr, line_number - 1, line_number, false)[1] or ""

  -- Skip lines in code blocks
  if is_in_code_block(bufnr, line_number, code_block_memo) then
    return false, nil, nil
  end

  -- Check different types of outline items
  local user_prefix = config.chat_user_prefix

  -- Match questions (using configured user prefix)
  if line:match("^" .. vim.pesc(user_prefix)) then
    return true, "question", "  " .. line
  -- Match top-level headers
  elseif line:match("^# ") then
    return true, "header1", "🧭 " .. string.sub(line, 3)
  -- Match second-level headers
  elseif line:match("^## ") then
    return true, "header2", "• " .. string.sub(line, 4)
  -- Match annotations
  elseif line:match("^@@.+@@$") then
    return true, "annotation", "→ " .. string.sub(line, 2, -2)
  end

  -- Not an outline item
  return false, nil, nil
end

-- Expose helpers for testing (follows dispatcher._extract_sse_content convention)
M._is_in_code_block = is_in_code_block
M._is_outline_item = is_outline_item

local function find_nearest_outline_line(target_buf, lnum, config)
  local line_count = vim.api.nvim_buf_line_count(target_buf)
  local safe_lnum = math.min(lnum, line_count)
  local all_lines = vim.api.nvim_buf_get_lines(target_buf, 0, -1, false)
  local code_block_memo = build_code_block_memo(target_buf)
  local is_valid_line = is_outline_item(target_buf, safe_lnum, config, code_block_memo, all_lines)

  if is_valid_line then
    return safe_lnum
  end

  for offset = 1, 5 do
    local previous_lnum = safe_lnum - offset
    if previous_lnum > 0 then
      local previous_is_item = is_outline_item(target_buf, previous_lnum, config, code_block_memo, all_lines)
      if previous_is_item then
        return previous_lnum
      end
    end

    local next_lnum = safe_lnum + offset
    if next_lnum <= line_count then
      local next_is_item = is_outline_item(target_buf, next_lnum, config, code_block_memo, all_lines)
      if next_is_item then
        return next_lnum
      end
    end
  end

  return safe_lnum
end

local function focus_buffer_line(target_buf, target_name, preferred_windows, lnum)
  for _, win in ipairs(preferred_windows or {}) do
    if vim.api.nvim_win_is_valid(win) and vim.api.nvim_win_get_buf(win) == target_buf then
      vim.api.nvim_set_current_win(win)
      vim.api.nvim_win_set_cursor(win, { lnum, 0 })
      vim.cmd("normal! zz")
      return true
    end
  end

  for _, win in ipairs(vim.api.nvim_list_wins()) do
    if vim.api.nvim_win_is_valid(win) and vim.api.nvim_win_get_buf(win) == target_buf then
      vim.api.nvim_set_current_win(win)
      vim.api.nvim_win_set_cursor(win, { lnum, 0 })
      vim.cmd("normal! zz")
      return true
    end
  end

  if vim.fn.filereadable(target_name) == 1 then
    vim.cmd("split " .. vim.fn.fnameescape(target_name))
    vim.api.nvim_win_set_cursor(0, { lnum, 0 })
    vim.cmd("normal! zz")
    return true
  end

  if vim.api.nvim_buf_is_valid(target_buf) then
    vim.cmd("sbuffer " .. target_buf)
    vim.api.nvim_win_set_cursor(0, { lnum, 0 })
    vim.cmd("normal! zz")
    return true
  end

  return false
end

local function jump_to_outline_location(selection, config)
  local target_buf = selection.bufnr
  local target_name = selection.name

  if not vim.api.nvim_buf_is_valid(target_buf) then
    vim.notify("Buffer " .. target_buf .. " is no longer valid - cannot navigate", vim.log.levels.ERROR)
    return false
  end

  local safe_lnum = find_nearest_outline_line(target_buf, selection.lnum or 1, config)
  local focused = focus_buffer_line(target_buf, target_name, selection.windows, safe_lnum)
  if not focused then
    vim.notify("Could not navigate to outline selection", vim.log.levels.WARN)
    return false
  end

  local ns_id = vim.api.nvim_create_namespace("ParleyOutline")
  vim.api.nvim_buf_clear_namespace(target_buf, ns_id, 0, -1)
  vim.api.nvim_buf_add_highlight(target_buf, ns_id, "DiffAdd", safe_lnum - 1, 0, -1)
  vim.defer_fn(function()
    if vim.api.nvim_buf_is_valid(target_buf) then
      vim.api.nvim_buf_clear_namespace(target_buf, ns_id, 0, -1)
    end
  end, 1000)

  return true, safe_lnum
end

M._jump_to_outline_location = jump_to_outline_location

-- Build the list of picker items from a buffer. Exposed for testing.
-- Returns items in document order: { display: string, value: { lnum: number } }
function M._build_picker_items(bufnr, config)
  local all_lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
  local code_block_memo = build_code_block_memo(bufnr)
  local items = {}
  for i = 1, #all_lines do
    local is_item, _, formatted_line = is_outline_item(bufnr, i, config, code_block_memo, all_lines)
    if is_item then
      table.insert(items, { display = formatted_line, value = { lnum = i } })
    end
  end
  return items
end

-- Create a floating picker to navigate questions and headings in the current buffer
function M.question_picker(config)
  local float_picker = require("parley.float_picker")

  -- Get the current buffer and filename
  local current_bufnr = vim.api.nvim_get_current_buf()
  local buf_name = vim.api.nvim_buf_get_name(current_bufnr)

  -- Ensure buffer is saved to disk to reflect latest changes
  local modified = vim.api.nvim_buf_get_option(current_bufnr, 'modified')
  if modified then
    vim.cmd('silent! write')
  end

  -- Capture windows showing the target buffer before the picker opens
  local target_windows = {}
  for _, win in ipairs(vim.api.nvim_list_wins()) do
    if vim.api.nvim_win_get_buf(win) == current_bufnr then
      table.insert(target_windows, win)
    end
  end

  local items = M._build_picker_items(current_bufnr, config)

  float_picker.open({
    title = "💬 Q&A Outline",
    items = items,
    anchor = "top",
    on_select = function(item)
      local entry = item.value
      if not vim.api.nvim_buf_is_valid(current_bufnr) then
        vim.notify("Buffer is no longer valid - cannot navigate", vim.log.levels.ERROR)
        return
      end
      jump_to_outline_location({
        bufnr = current_bufnr,
        name = buf_name,
        windows = target_windows,
        lnum = entry.lnum,
      }, config)
    end,
  })
end

return M
