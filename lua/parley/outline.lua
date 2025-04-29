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
  
  -- Scan the buffer for headers and questions
  local line_count = vim.api.nvim_buf_line_count(current_bufnr)
  for i = 1, line_count do
    local line = vim.api.nvim_buf_get_lines(current_bufnr, i - 1, i, false)[1]
    
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
          
          -- Verify the selected line number is valid
          local line_count = vim.api.nvim_buf_line_count(target_buf)
          local safe_lnum = math.min(lnum, line_count)
          
          -- Log current state
          vim.notify("Navigating to line " .. safe_lnum .. " in buffer " .. target_name, vim.log.levels.DEBUG)
          
          -- Verify the line actually contains what we expect (heading or user prompt)
          local line_content = vim.api.nvim_buf_get_lines(target_buf, safe_lnum - 1, safe_lnum, false)[1] or ""
          local is_valid_line = line_content:match("^#") or 
                               line_content:match("^" .. vim.pesc(config.chat_user_prefix)) or
                               line_content:match("^@.+@$")
          
          -- If the line doesn't match what we expect, try to find the closest match
          if not is_valid_line then
            -- Search for neighboring lines that might be headers or questions
            for offset = -5, 5 do
              if offset ~= 0 then
                local test_lnum = safe_lnum + offset
                if test_lnum > 0 and test_lnum <= line_count then
                  local test_content = vim.api.nvim_buf_get_lines(target_buf, test_lnum - 1, test_lnum, false)[1] or ""
                  if test_content:match("^#") or 
                     test_content:match("^" .. vim.pesc(config.chat_user_prefix)) or
                     test_content:match("^@.+@$") then
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
        end)
      end)
    
      return true
    end,
  }):find()
end

return M
