-- Outline module for Parley.nvim
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

-- Function to determine if a line is inside a code block
-- Uses a smarter approach with a memo table to avoid recalculating
-- code block states for the same line numbers repeatedly
local function is_in_code_block(bufnr, line_number, memo)
  memo = memo or {}
  
  -- If we've already calculated this line, return the cached result
  if memo[line_number] ~= nil then
    return memo[line_number]
  end
  
  -- Code block delimiters
  local code_block_delimiters = {
    ["```"] = true,
    ["~~~"] = true,
  }
  
  -- For line 1, we know we're not in a code block
  if line_number <= 1 then
    memo[line_number] = false
    return false
  end
  
  -- Get the state from the previous line
  local prev_line_state = is_in_code_block(bufnr, line_number - 1, memo)
  
  -- Check if current line toggles the code block state
  local line_content = vim.api.nvim_buf_get_lines(bufnr, line_number - 1, line_number, false)[1] or ""
  local toggle_state = false
  
  for delimiter in pairs(code_block_delimiters) do
    if line_content:match("^%s*" .. vim.pesc(delimiter)) then
      toggle_state = true
      break
    end
  end
  
  -- Calculate current state based on previous line state and toggle
  local current_state = prev_line_state
  if toggle_state then
    current_state = not prev_line_state
  end
  
  -- Cache the result
  memo[line_number] = current_state
  return current_state
end

-- Function to check if a line should be included in the outline
-- Returns: boolean (should be included), string (type), string (formatted content)
local function is_outline_item(bufnr, line_number, config, code_block_memo)
  -- Get the line content
  local line = vim.api.nvim_buf_get_lines(bufnr, line_number - 1, line_number, false)[1] or ""
  
  -- Check for code block start - we want to include this in the outline
  if line:match("^%s*```%S+") then
    -- Construct a nice outline entry for code blocks
    -- Extract the language name after the backticks: ```python -> python
    local rest = line:match("^%s*```(.*)")
    local display = "📃 Code: " .. rest
    
    return true, "code_block", display
  end
  
  -- Skip lines in code blocks (but not the opening line)
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

  -- Get the current buffer and filename - important to track exactly which buffer we're working with
  local current_bufnr = vim.api.nvim_get_current_buf()
  local buf_name = vim.api.nvim_buf_get_name(current_bufnr)
  
  -- Store important buffer info for later use
  local buffer_info = {
    bufnr = current_bufnr,
    name = buf_name,
    filetype = vim.api.nvim_buf_get_option(current_bufnr, 'filetype'),
  }
  
  -- Log buffer information for debugging
  vim.schedule(function()
    vim.notify("Opening outline for buffer " .. buffer_info.bufnr .. " (" .. buffer_info.name .. ")", vim.log.levels.DEBUG)
  end)

  -- Ensure buffer is saved to disk to reflect latest changes
  local modified = vim.api.nvim_buf_get_option(current_bufnr, 'modified')
  if modified then
    vim.cmd('silent! write')
  end
  
  -- Create lines table with fresh buffer content
  local lines = {}
  
  -- Get configured user prefix
  local user_prefix = config.chat_user_prefix
  
  -- Create a memo table for code block state calculations
  local code_block_memo = {}
  
  -- Scan the buffer for headers and questions
  local line_count = vim.api.nvim_buf_line_count(current_bufnr)
  for i = 1, line_count do
    local is_item, item_type, formatted_line = is_outline_item(current_bufnr, i, config, code_block_memo)
    
    if is_item then
      table.insert(lines, { line = formatted_line, lnum = i, type = item_type })
    end
  end

  -- Create the picker
  pickers.new({}, {
    prompt_title = "💬 Q&A and Code Outline",
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
        -- Store current state before closing
        local entry = action_state.get_selected_entry()
        local lnum = entry.value and entry.value.lnum or 1
        
        -- Pass explicit buffer details rather than relying on implicit buffer references
        local target_buf = buffer_info.bufnr
        local target_name = buffer_info.name
        
        -- Verify buffer is valid before proceeding
        if not vim.api.nvim_buf_is_valid(target_buf) then
          vim.notify("Buffer " .. target_buf .. " is no longer valid - cannot navigate", vim.log.levels.ERROR)
          actions.close(prompt_bufnr)
          return
        end
        
        -- Store all buffer details to help with debugging
        local debug_info = {
          target_bufnr = target_buf,
          target_name = target_name,
          line_number = lnum,
        }
        
        -- Log navigation intent
        vim.schedule(function()
          vim.notify("Will navigate to line " .. lnum .. " in buffer " .. target_buf, vim.log.levels.DEBUG)
        end)
        
        -- Store the windows that have this buffer open
        local windows = {}
        for _, win in ipairs(vim.api.nvim_list_wins()) do
          if vim.api.nvim_win_get_buf(win) == target_buf then
            table.insert(windows, win)
          end
        end
        
        -- Close the prompt
        actions.close(prompt_bufnr)
        
        -- Schedule the cursor movement to ensure telescope cleanup is done
        vim.schedule(function()
          -- Double-check the buffer is still valid
          if not vim.api.nvim_buf_is_valid(target_buf) then
            vim.notify("Target buffer " .. target_buf .. " is no longer valid after Telescope closed", vim.log.levels.ERROR)
            return
          end

		  -- TODO: this looks overly complex.
          
          -- Verify the selected line number is valid
          local line_count = vim.api.nvim_buf_line_count(target_buf)
          local safe_lnum = math.min(lnum, line_count)
          
          -- Log current state
          vim.notify("Navigating to line " .. safe_lnum .. " in buffer " .. target_name, vim.log.levels.DEBUG)
          
          -- Create a memo table for code block state calculations
          local code_block_memo = {}
          
          -- Check if the line is a valid outline item
          local is_valid_line, _, _ = is_outline_item(target_buf, safe_lnum, config, code_block_memo)
          
          -- If the line doesn't match what we expect, try to find the closest match
          if not is_valid_line then
            -- Search for neighboring lines that might be headers or questions
            for offset = -5, 5 do
              if offset ~= 0 then
                local test_lnum = safe_lnum + offset
                if test_lnum > 0 and test_lnum <= line_count then
                  -- Check if this line is a valid outline item
                  local is_item, _, _ = is_outline_item(target_buf, test_lnum, config, code_block_memo)
                  if is_item then
                    safe_lnum = test_lnum
                    is_valid_line = true
                    break
                  end
                end
              end
            end
          end
          
          -- Create a safety check for the target buffer name using the buffer name
          local current_buf_name = vim.api.nvim_buf_get_name(target_buf)
          if current_buf_name ~= target_name then
            vim.notify("Warning: Buffer name mismatch. Expected: " .. target_name .. " Got: " .. current_buf_name, vim.log.levels.WARN)
          end
          
          -- Find a valid window containing our target buffer
          local target_win = nil
          for _, win in ipairs(windows) do
            if vim.api.nvim_win_is_valid(win) and 
               vim.api.nvim_win_get_buf(win) == target_buf then
              target_win = win
              break
            end
          end
          
          -- If we found a valid window, set the cursor there
          if target_win then
            vim.notify("Using existing window for navigation", vim.log.levels.DEBUG)
            vim.api.nvim_set_current_win(target_win)
            vim.api.nvim_win_set_cursor(target_win, { safe_lnum, 0 })
            
            -- Center the cursor in view
            vim.cmd("normal! zz")
          else
            -- Fall back to trying to find the buffer in any window
            local found = false
            for _, win in ipairs(vim.api.nvim_list_wins()) do
              if vim.api.nvim_win_is_valid(win) and 
                 vim.api.nvim_win_get_buf(win) == target_buf then
                vim.notify("Found buffer in different window", vim.log.levels.DEBUG)
                vim.api.nvim_set_current_win(win)
                vim.api.nvim_win_set_cursor(win, { safe_lnum, 0 })
                vim.cmd("normal! zz")
                found = true
                break
              end
            end
            
            -- If buffer isn't visible in any window, try to show it specifically by file path
            if not found then
              vim.notify("Buffer not visible in any window, opening by path: " .. target_name, vim.log.levels.DEBUG)
              
              -- Use the specific file path rather than buffer number
              if vim.fn.filereadable(target_name) == 1 then
                vim.cmd("split " .. vim.fn.fnameescape(target_name))
                vim.api.nvim_win_set_cursor(0, { safe_lnum, 0 })
                vim.cmd("normal! zz")
              else
                vim.notify("Warning: Could not open file - " .. target_name, vim.log.levels.WARN)
                
                -- Fall back to buffer number if file isn't readable
                if vim.api.nvim_buf_is_valid(target_buf) then
                  vim.cmd("sbuffer " .. target_buf)
                  vim.api.nvim_win_set_cursor(0, { safe_lnum, 0 })
                  vim.cmd("normal! zz")
                end
              end
            end
          end
          -- Visual highlight after jump (1 second)
          do
            local ns_id = vim.api.nvim_create_namespace("ParleyOutline")
            vim.api.nvim_buf_clear_namespace(target_buf, ns_id, 0, -1)
            vim.api.nvim_buf_add_highlight(target_buf, ns_id, "DiffAdd", safe_lnum - 1, 0, -1)
            vim.defer_fn(function()
              vim.api.nvim_buf_clear_namespace(target_buf, ns_id, 0, -1)
            end, 1000)
          end
        end)
      end)
    
      return true
    end,
  }):find()
end

return M
