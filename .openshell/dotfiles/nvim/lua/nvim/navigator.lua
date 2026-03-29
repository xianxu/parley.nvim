local M = {}

function M.navigate_to_marker(marker)
  -- vim.cmd(string.format("normal! /%s<CR>", vim.fn.escape(marker, '/')))
  vim.cmd('normal! ?' .. marker .. '<CR>')
  vim.cmd('normal! ^')  -- Ensure the cursor is at the start of the line
end

return M

