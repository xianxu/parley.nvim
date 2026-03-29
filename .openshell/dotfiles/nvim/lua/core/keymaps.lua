local map = require("helpers.keys").map

-- Stay in indent mode
map("v", "<", "<gv")
map("v", ">", ">gv")

-- Clear after search
map("n", "<leader>ur", "<cmd>nohl<cr>", "Clear highlights")

-- deal with soft lines (line wrap)
vim.api.nvim_set_keymap("n", "<Up>", "gk", { noremap = true, silent = true })
vim.api.nvim_set_keymap("n", "<Down>", "gj", { noremap = true, silent = true })
vim.api.nvim_set_keymap("v", "<Up>", "gk", { noremap = true, silent = true })
vim.api.nvim_set_keymap("v", "<Down>", "gj", { noremap = true, silent = true })
vim.api.nvim_set_keymap("i", "<Up>", "<C-o>gk", { noremap = true, silent = true })
vim.api.nvim_set_keymap("i", "<Down>", "<C-o>gj", { noremap = true, silent = true })

vim.keymap.set("n", "<leader>ll", function()
  vim.fn.setreg("+", vim.fn.expand("%") .. ":" .. vim.fn.line("."))
end, { desc = "Copy filename:line to clipboard" })

vim.keymap.set("n", "<leader>LL", function()
  local filename = vim.fn.expand("%")
  local line_num = vim.fn.line(".")
  local line_content = vim.fn.getline(".")
  local output = string.format("%s:%d\n%s", filename, line_num, line_content)
  vim.fn.setreg("+", output)
  print("Copied: " .. filename .. ":" .. line_num)
end, { desc = "Copy filename:line and line content to clipboard" })

vim.keymap.set("v", "<leader>ll", function()
  local filename = vim.fn.expand("%")
  local start_line = vim.fn.line("'<")
  local end_line = vim.fn.line("'>")
  local range_str = string.format("%s:%d-%d", filename, start_line, end_line)
  vim.fn.setreg("+", range_str)
  vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes("<Esc>", true, false, true), "n", false)
end, { noremap = true, silent = true })

vim.keymap.set("v", "<leader>LL", function()

  local filename = vim.fn.expand("%")
  local start_line = vim.fn.line("v")
  local end_line = vim.fn.line(".")

  -- Ensure correct ordering
  if start_line > end_line then
    start_line, end_line = end_line, start_line
  end

  local lines = vim.api.nvim_buf_get_lines(0, start_line - 1, end_line, false)
  local content = table.concat(lines, "\n")

  local output = string.format("%s:%d-%d\n%s", filename, start_line, end_line, content)

  vim.fn.setreg("+", output)

  vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes("<Esc>", true, false, true), "n", false)
end, { noremap = true, silent = true, desc = "Copy filename:range and content to clipboard" })

vim.keymap.set("n", "<leader>fd", function()
  require('telescope').extensions.frecency.frecency({ workspace = "CWD" })
end, { desc = "Frecency (Recent + Frequent Files)" })

vim.keymap.set("n", "<leader>fo", "<cmd>Oil<CR>", { desc = "Open parent directory in Oil" })

-- gitsigns, display hunk at current line and esc to dismiss
vim.keymap.set("n", "<leader>h", function()
  require("gitsigns").preview_hunk()
end, { desc = "Preview Git Hunk" })

vim.keymap.set("n", "<Esc>", function()
  for _, win in ipairs(vim.api.nvim_list_wins()) do
    if vim.api.nvim_win_get_config(win).relative ~= "" then
      vim.api.nvim_win_close(win, true)
    end
  end
end, { desc = "Close floating windows", silent = true })

vim.api.nvim_create_user_command("Retab2", function()
  -- Ensure 4-space indent settings are active
  vim.bo.expandtab = true
  vim.bo.tabstop = 4
  vim.bo.shiftwidth = 4
  vim.bo.softtabstop = 4

  -- Replace leading 2-space indents with 4-space indents proportionally
  vim.cmd([[
    %s#^\( \{2}\)\+#\=repeat('    ', len(submatch(0)) / 2)#g
    nohlsearch
  ]])
end, {
  desc = "Convert 2-space leading indents to 4-space indents",
})

vim.api.nvim_create_user_command("Retab4", function()
  -- Ensure 4-space indent settings are active
  vim.bo.expandtab = true
  vim.bo.tabstop = 2
  vim.bo.shiftwidth = 2
  vim.bo.softtabstop = 2

  -- Replace leading 4-space indents with 2-space indents proportionally
  vim.cmd([[
    %s#^\( \{4}\)\+#\=repeat('  ', len(submatch(0)) / 4)#g
    nohlsearch
  ]])
end, {
  desc = "Convert 4-space leading indents to 3-space indents",
})

local function CopyUrlUnderCursor()
  local word = vim.fn.expand("<cWORD>")
  local url_pattern = "[a-z]+://[^%s%]%)]+"  -- basic URL matcher
  local url = string.match(word, url_pattern)

  if url then
    vim.fn.setreg("+", url)
    vim.notify("Copied URL: " .. url)
  else
    vim.notify("No valid URL under cursor", vim.log.levels.WARN)
  end
end

vim.keymap.set("n", "gy", CopyUrlUnderCursor, { desc = "Copy URL under cursor" })
