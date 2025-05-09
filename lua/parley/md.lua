local M = {}

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
  local cwd = vim.fn.expand("%:p:h")
  vim.fn.chansend(vim.b.terminal_job_id, "cd " .. cwd .. "\n")

  -- Send each command
  for _, cmd in ipairs(commands) do
    vim.fn.chansend(vim.b.terminal_job_id, cmd .. "\n")
  end

  -- Wait a moment then copy the terminal buffer to clipboard
  vim.defer_fn(function()
    vim.api.nvim_buf_set_option(term_buf, "modifiable", true)
    local term_lines = vim.api.nvim_buf_get_lines(term_buf, 0, -1, false)
    local output = table.concat(term_lines, "\n")
    vim.fn.setreg("+", output)
    print("✅ Command output copied")
  end, 1000)
end

return M

