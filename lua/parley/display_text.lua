-- Editor display units shared by layout adapters. Neovim keeps each base
-- character together with its composing characters when skipcc is true.
local M = { width = vim.fn.strdisplaywidth }

function M.units(text)
    local units = {}
    for index = 0, vim.fn.strchars(text, true) - 1 do
        units[#units + 1] = vim.fn.strcharpart(text, index, 1, true)
    end
    return units
end

return M
