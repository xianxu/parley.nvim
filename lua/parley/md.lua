local M = {}

-- Utility function to copy terminal buffer with whitespace trimming
local function copy_terminal_content(term_buf)
  -- Get all terminal lines
  local term_lines = vim.api.nvim_buf_get_lines(term_buf, 0, -1, false)
  
  -- Trim empty lines at the beginning and end
  local start_idx, end_idx = 1, #term_lines
  
  -- Find first non-empty line that's not a terminal protocol line
  while start_idx <= end_idx do
    local line = term_lines[start_idx]
    -- Skip empty lines or terminal protocol lines
    if line ~= "" and not line:match("^%s*$") and 
       not line:match("^cd term://") and 
       not line:match("^cd: no such file or directory") then
      break
    end
    start_idx = start_idx + 1
  end
  
  -- Find last non-empty line
  while end_idx >= start_idx do
    local line = term_lines[end_idx]
    -- Skip empty lines or terminal protocol lines
    if line ~= "" and not line:match("^%s*$") and 
       not line:match("^cd term://") and 
       not line:match("^cd: no such file or directory") then
      break
    end
    end_idx = end_idx - 1
  end
  
  -- Extract relevant lines
  local filtered_lines = {}
  for i = start_idx, end_idx do
    local line = term_lines[i]
    -- Skip terminal protocol lines in the middle too
    if not line:match("^cd term://") and 
       not line:match("^cd: no such file or directory") then
      table.insert(filtered_lines, line)
    end
  end
  
  -- Copy filtered terminal content
  local output = #filtered_lines > 0 and table.concat(filtered_lines, "\n") or ""
  vim.fn.setreg("+", output)
  print("✅ Terminal output copied to clipboard")
end

-- Store the last executed commands
M._last_commands = nil
M._last_cwd = nil
-- Store the last terminal buffer and window
M._last_term_buf = nil
M._last_term_win = nil

-- Helper function to extract code block content
local function extract_code_block(bufnr, start_line, end_line)
  if not start_line or not end_line or end_line <= start_line then
    return nil
  end
  
  -- Extract code block contents (excluding ``` lines)
  local code_lines = {}
  for i = start_line + 1, end_line - 1 do
    local line = vim.api.nvim_buf_get_lines(bufnr, i - 1, i, false)[1]
    table.insert(code_lines, line)
  end
  
  return code_lines
end

-- Helper function to find a code block header and its closing marker
local function find_code_block_bounds(bufnr, line_number, direction)
  local lines = vim.api.nvim_buf_line_count(bufnr)
  local start_line, end_line
  
  -- Find the opening marker (```language)
  local start_pattern = "^%s*```%S+"
  local current_line = vim.api.nvim_buf_get_lines(bufnr, line_number - 1, line_number, false)[1]
  if current_line:match(start_pattern) then
    start_line = line_number
  else
    -- Search upward for the start marker
    for i = line_number - 1, 1, -1 do
      local line = vim.api.nvim_buf_get_lines(bufnr, i - 1, i, false)[1]
      if line:match(start_pattern) then
        start_line = i
        break
      end
    end
  end
  
  if not start_line then
    return nil, nil, "No code block start found"
  end
  
  -- Find the closing marker (```)
  for i = start_line + 1, lines do
    local line = vim.api.nvim_buf_get_lines(bufnr, i - 1, i, false)[1]
    if line:match("^%s*```%s*$") then
      end_line = i
      break
    end
  end
  
  if not end_line then
    return start_line, nil, "No code block end found"
  end
  
  return start_line, end_line, nil
end

-- Function to find a previous code block with the same filename
local function find_previous_code_block(bufnr, current_start_line, filename)
  -- Start from the line before the current code block
  for i = current_start_line - 1, 1, -1 do
    local line = vim.api.nvim_buf_get_lines(bufnr, i - 1, i, false)[1]
    
    -- Check if line is a code block start with a file attribute
    if line:match("^%s*```%S+") and line:match('file="([^"]+)"') then
      local block_filename = line:match('file="([^"]+)"')
      
      -- If the filename matches what we're looking for
      if block_filename == filename then
        -- Find the end of this code block
        local prev_start_line = i
        local prev_end_line
        
        for j = prev_start_line + 1, current_start_line - 1 do
          local end_line = vim.api.nvim_buf_get_lines(bufnr, j - 1, j, false)[1]
          if end_line:match("^%s*```%s*$") then
            prev_end_line = j
            break
          end
        end
        
        if prev_end_line then
          return prev_start_line, prev_end_line
        end
      end
    end
  end
  
  return nil, nil
end

-- Function to check if a line is a code block
function M.save_markdown_code_block()
  local bufnr = vim.api.nvim_get_current_buf()
  local cursor_line = vim.api.nvim_win_get_cursor(0)[1]
  local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)

  local start_line, end_line, file_name

  -- Search upward for ```
  for i = cursor_line, 1, -1 do
    local line = lines[i]
    if line:match("^%s*```") then
      start_line = i
      -- Extract file="..." if present
      file_name = line:match('file="([^"]+)"')
      break
    end
  end

  -- Search downward for closing ```
  for i = cursor_line + 1, #lines do
    local line = lines[i]
    if line:match("^%s*```") then
      end_line = i
      break
    end
  end

  -- Validate and prompt if needed
  if not file_name then
    file_name = vim.fn.input("Filename to save code block: ", "", "file")
    if file_name == "" then
      print("Aborted: No file name provided.")
      return
    end
  end

  if not (start_line and end_line and end_line > start_line) then
    print("No valid code block found.")
    return
  end

  -- Extract code block contents (excluding ``` lines)
  local code_lines = {}
  for i = start_line + 1, end_line - 1 do
    table.insert(code_lines, lines[i])
  end

  -- Write to file
  local path = vim.fn.getcwd() .. "/" .. file_name
  local ok, err = pcall(function()
    local f = io.open(path, "w")
    f:write(table.concat(code_lines, "\n"))
    f:close()
  end)

  if ok then
    print("✅ Saved code block to: " .. file_name)
  else
    print("❌ Failed to write file: " .. err)
  end
end

-- Function to copy a code block to the clipboard
function M.copy_markdown_code_block()
  local start_line, end_line
  local bufnr = vim.api.nvim_get_current_buf()
  local cursor_line = vim.api.nvim_win_get_cursor(0)[1]

  -- Search upward for ```
  for l = cursor_line, 1, -1 do
    local line = vim.api.nvim_buf_get_lines(bufnr, l - 1, l, false)[1]
    if line:match("^%s*```") then
      start_line = l
      break
    end
  end

  -- Search downward for ```
  local last_line = vim.api.nvim_buf_line_count(bufnr)
  for l = cursor_line + 1, last_line do
    local line = vim.api.nvim_buf_get_lines(bufnr, l - 1, l, false)[1]
    if line:match("^%s*```") then
      end_line = l
      break
    end
  end

  if start_line and end_line and start_line < end_line then
    local lines = vim.api.nvim_buf_get_lines(bufnr, start_line, end_line - 1, false)
    local joined = table.concat(lines, "\n")
    vim.fn.setreg("+", joined)  -- system clipboard
    print("Code block copied to clipboard.")
  else
    print("No valid code block found.")
  end
end

-- Function to run a code block in a terminal
function M.run_code_block_in_terminal()
  local bufnr = vim.api.nvim_get_current_buf()
  local cursor_line = vim.api.nvim_win_get_cursor(0)[1]
  local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)

  local start_line, end_line
  for i = cursor_line, 1, -1 do
    if lines[i]:match("^%s*```") then
      start_line = i
      break
    end
  end
  for i = cursor_line + 1, #lines do
    if lines[i]:match("^%s*```") then
      end_line = i
      break
    end
  end
  if not start_line or not end_line or end_line <= start_line then
    print("No valid code block found.")
    return
  end

  -- Extract and combine command lines (handle line continuation)
  local commands = {}
  local current_cmd = ""
  for i = start_line + 1, end_line - 1 do
    local line = lines[i]
    if line:match("\\%s*$") then
      current_cmd = current_cmd .. line:gsub("\\%s*$", "") .. " "
    else
      current_cmd = current_cmd .. line
      table.insert(commands, current_cmd)
      current_cmd = ""
    end
  end

  -- Open terminal in a vsplit on the right
  vim.cmd("vsplit")
  vim.cmd("terminal")
  local term_buf = vim.api.nvim_get_current_buf()
  local term_win = vim.api.nvim_get_current_win()
  local job_id = vim.b.terminal_job_id
  -- Get the real current working directory, not the file path
  local cwd = vim.fn.getcwd()
  
  -- Store the terminal buffer and window for later access
  M._last_term_buf = term_buf
  M._last_term_win = term_win
  
  -- Change to the correct directory
  vim.fn.chansend(job_id, "cd " .. cwd .. "\n")

  -- Store commands for reuse
  M._last_commands = commands
  M._last_cwd = cwd
  
  -- Send each command
  for _, cmd in ipairs(commands) do
    vim.fn.chansend(job_id, cmd .. "\n")
  end
  
  -- Set up the keybinding based on config if available, or use default '<leader>gc'
  local copy_key = '<leader>gc'
  if require("parley").config and require("parley").config.chat_shortcut_copy_terminal then
    local config = require("parley").config.chat_shortcut_copy_terminal
    if config.modes and vim.tbl_contains(config.modes, 'n') and config.shortcut then
      copy_key = config.shortcut
    end
  end
  
  -- Add a keybinding to capture output when ready
  vim.keymap.set('n', copy_key, function()
    copy_terminal_content(term_buf)
  end, { buffer = term_buf, noremap = true, silent = true, desc = "Copy terminal output to clipboard" })
  
  -- Tell the user how to capture output
  print("Commands sent to terminal. Press " .. copy_key .. " when execution is complete to copy output.")
  
  -- Return focus to the terminal window
  vim.api.nvim_set_current_win(term_win)
end

-- Function to repeat the last executed commands
function M.repeat_last_command()
  if not M._last_commands or #M._last_commands == 0 then
    print("No previous commands to repeat")
    return
  end
  
  -- Open terminal in a vsplit on the right
  vim.cmd("vsplit")
  vim.cmd("terminal")
  local term_buf = vim.api.nvim_get_current_buf()
  local term_win = vim.api.nvim_get_current_win()
  local job_id = vim.b.terminal_job_id
  
  -- Store the terminal buffer and window for later access
  M._last_term_buf = term_buf
  M._last_term_win = term_win
  
  -- Change to the correct directory
  if M._last_cwd then
    vim.fn.chansend(job_id, "cd " .. M._last_cwd .. "\n")
  end
  
  -- Send each command
  for _, cmd in ipairs(M._last_commands) do
    vim.fn.chansend(job_id, cmd .. "\n")
  end
  
  -- Set up the keybinding based on config if available, or use default '<leader>gc'
  local copy_key = '<leader>gc'
  if require("parley").config and require("parley").config.chat_shortcut_copy_terminal then
    local config = require("parley").config.chat_shortcut_copy_terminal
    if config.modes and vim.tbl_contains(config.modes, 'n') and config.shortcut then
      copy_key = config.shortcut
    end
  end
  
  -- Add a keybinding to capture output when ready
  vim.keymap.set('n', copy_key, function()
    copy_terminal_content(term_buf)
  end, { buffer = term_buf, noremap = true, silent = true, desc = "Copy terminal output to clipboard" })
  
  -- Tell the user how to capture output
  print("Repeating " .. #M._last_commands .. " command(s). Press " .. copy_key .. " when execution is complete to copy output.")
  
  -- Return focus to the terminal window
  vim.api.nvim_set_current_win(term_win)
end

-- Function to copy terminal output from the chat buffer
function M.copy_terminal_output()
  if not M._last_term_buf or not vim.api.nvim_buf_is_valid(M._last_term_buf) then
    print("No terminal buffer found. Run a code block first with <leader>gx.")
    return
  end
  
  -- Use the shared utility function to copy terminal content
  copy_terminal_content(M._last_term_buf)
  
  -- Optionally, flash the terminal window to show which one we copied from
  if M._last_term_win and vim.api.nvim_win_is_valid(M._last_term_win) then
    local current_win = vim.api.nvim_get_current_win()
    vim.api.nvim_set_current_win(M._last_term_win)
    vim.defer_fn(function()
      if vim.api.nvim_win_is_valid(current_win) then
        vim.api.nvim_set_current_win(current_win)
      end
    end, 200)
  end
end

-- Function to display diff between code blocks with same filename
function M.display_diff()
  local bufnr = vim.api.nvim_get_current_buf()
  local cursor_line = vim.api.nvim_win_get_cursor(0)[1]
  
  -- 1. Find code block under cursor and check if it has a filename
  local current_start_line, current_end_line, error_msg = find_code_block_bounds(bufnr, cursor_line, "up")
  
  if error_msg then
    print("❌ " .. error_msg)
    return
  end
  
  -- Get the first line of the code block to extract filename
  local header_line = vim.api.nvim_buf_get_lines(bufnr, current_start_line - 1, current_start_line, false)[1]
  local filename = header_line:match('file="([^"]+)"')
  
  if not filename then
    print("❌ Current code block doesn't have a filename. Add file=\"filename\" to the code fence.")
    return
  end
  
  -- 2. Search for a previous code block with the same filename
  local prev_start_line, prev_end_line = find_previous_code_block(bufnr, current_start_line, filename)
  
  if not prev_start_line or not prev_end_line then
    print("❌ No previous code block found with filename: " .. filename)
    return
  end
  
  -- 3. Extract content from both code blocks
  local current_content = extract_code_block(bufnr, current_start_line, current_end_line)
  local previous_content = extract_code_block(bufnr, prev_start_line, prev_end_line)
  
  if not current_content or not previous_content then
    print("❌ Failed to extract code block content")
    return
  end
  
  -- 4. Create temp files for diffing
  local temp_dir = vim.fn.tempname()
  vim.fn.mkdir(temp_dir, "p")
  
  local file_a = temp_dir .. "/previous_" .. filename
  local file_b = temp_dir .. "/current_" .. filename
  
  -- Write content to temp files
  local ok_a = pcall(function()
    local f = io.open(file_a, "w")
    f:write(table.concat(previous_content, "\n"))
    f:close()
  end)
  
  local ok_b = pcall(function()
    local f = io.open(file_b, "w")
    f:write(table.concat(current_content, "\n"))
    f:close()
  end)
  
  if not (ok_a and ok_b) then
    print("❌ Failed to create temporary files for diff")
    return
  end
  
  -- 5. Open diff view
  vim.cmd("tabnew")
  local win1 = vim.api.nvim_get_current_win()
  local buf1 = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_win_set_buf(win1, buf1)
  
  -- Read first file content
  local prev_content_lines = vim.fn.readfile(file_a)
  vim.api.nvim_buf_set_lines(buf1, 0, -1, false, prev_content_lines)
  vim.api.nvim_buf_set_name(buf1, "Previous: " .. filename)
  
  -- Try to detect filetype from extension
  local extension = filename:match("%.([^%.]+)$")
  if extension then
    vim.api.nvim_buf_set_option(buf1, "filetype", extension)
  end
  
  vim.cmd("diffthis")
  
  -- Create second split and buffer
  vim.cmd("vsplit")
  local win2 = vim.api.nvim_get_current_win() 
  local buf2 = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_win_set_buf(win2, buf2)
  
  -- Read second file content
  local curr_content_lines = vim.fn.readfile(file_b)
  vim.api.nvim_buf_set_lines(buf2, 0, -1, false, curr_content_lines)
  vim.api.nvim_buf_set_name(buf2, "Current: " .. filename)
  
  -- Apply same filetype to second buffer
  if extension then
    vim.api.nvim_buf_set_option(buf2, "filetype", extension)
  end
  
  vim.cmd("diffthis")
  
  -- Make these buffers read-only and temporary
  for _, bufnr in ipairs({buf1, buf2}) do
    vim.api.nvim_buf_set_option(bufnr, "readonly", true)
    vim.api.nvim_buf_set_option(bufnr, "buftype", "nofile")
    vim.api.nvim_buf_set_option(bufnr, "swapfile", false)
    vim.api.nvim_buf_set_option(bufnr, "modifiable", false)
    
    -- Auto-delete the buffer when it's hidden
    vim.api.nvim_create_autocmd("BufHidden", {
      buffer = bufnr,
      callback = function()
        if vim.api.nvim_buf_is_valid(bufnr) then
          vim.api.nvim_buf_delete(bufnr, { force = true })
        end
      end,
    })
  end
  
  -- Clean up temp files when the tab is closed
  local cleanup_group = vim.api.nvim_create_augroup("ParleyDiffCleanup", { clear = true })
  vim.api.nvim_create_autocmd("TabClosed", {
    group = cleanup_group,
    pattern = "*",
    callback = function()
      vim.fn.delete(file_a)
      vim.fn.delete(file_b)
      vim.fn.delete(temp_dir, "rf")
    end,
  })
  
  print("✅ Showing diff for file: " .. filename)
end

return M