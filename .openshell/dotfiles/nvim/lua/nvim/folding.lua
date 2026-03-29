local M = {}

local function fold_dialog()
  local line = vim.fn.getline(vim.v.lnum)
  if line:match('^💬:') then         -- Check if the line starts with 💬:
    return '>1'                     -- Start a fold here
  elseif line:match('^🤖:') then     -- Check if the line starts with 🤖:
    return '0'                      -- Close the previous fold by resetting fold level
  else
    return '='                      -- Inherit the fold level from the previous line
  end
end

function M.setup_folding()
  vim.o.foldmethod = 'expr'
  vim.o.foldexpr = 'v:lua.require("nvim.folding").fold_dialog()'
end

return M
