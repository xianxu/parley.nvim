-- Outline module for gp.nvim
-- Provides navigation through chat messages and markdown headers

local M = {}

-- Reverse the order of elements in a table
local function reverse(tbl)
  local new_tbl = {}
  for i = #tbl, 1, -1 do
    table.insert(new_tbl, tbl[i])
  end
  return new_tbl
end

-- Create a Telescope picker to navigate questions and headings in the current buffer
function M.question_picker(config)
  -- Check if telescope is available
  local ok, _ = pcall(require, "telescope")
  if not ok then
    vim.notify("Telescope is required for this feature", vim.log.levels.ERROR)
    return
  end

  local pickers = require("telescope.pickers")
  local finders = require("telescope.finders")
  local conf = require("telescope.config").values

  local lines = {}
  local bufnr = vim.api.nvim_get_current_buf()
  
  -- Get configured user prefix
  local user_prefix = config.chat_user_prefix
  
  for i = 1, vim.api.nvim_buf_line_count(bufnr) do
    local line = vim.api.nvim_buf_get_lines(bufnr, i - 1, i, false)[1]
    
    -- Match questions (using configured user prefix)
    if line:match("^" .. vim.pesc(user_prefix)) then
      table.insert(lines, { line = "  " .. line, lnum = i })
    -- Match top-level headers
    elseif line:match("^# ") then
      table.insert(lines, { line = "🧭 " .. string.sub(line, 3), lnum = i })
    -- Match second-level headers
    elseif line:match("^## ") then
      table.insert(lines, { line = "• " .. string.sub(line, 4), lnum = i })
    -- Match annotations
    elseif line:match("^@.+@$") then
      table.insert(lines, { line = "→ " .. string.sub(line, 2, -2), lnum = i })
    end
  end

  -- Create the picker
  pickers.new({}, {
    prompt_title = "💬 Q&A Outline",
    finder = finders.new_table {
      results = reverse(lines),
      entry_maker = function(entry)
        return {
          value = entry,
          display = entry.line,
          ordinal = entry.line,
          lnum = entry.lnum,
        }
      end,
    },
    sorter = require("telescope.sorters").get_fuzzy_file(),
    attach_mappings = function(_, map)
      local actions = require("telescope.actions")
      local action_state = require("telescope.actions.state")
    
      map("i", "<CR>", function(prompt_bufnr)
        local entry = action_state.get_selected_entry()
        actions.close(prompt_bufnr)
        local lnum = entry.value and entry.value.lnum or 1
        vim.api.nvim_win_set_cursor(0, { lnum, 0 })
      end)
    
      return true
    end,
  }):find()
end

return M