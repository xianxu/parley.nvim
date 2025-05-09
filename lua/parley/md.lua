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

--	Function to check if a line is a code block
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

return M