local opts = {
  shiftwidth = 4,
  tabstop = 4,
  softtabstop = 4,
  expandtab = true,
  wrap = true,
  termguicolors = true,
  number = true,
  relativenumber = true,
  clipboard = "unnamedplus",
  ignorecase = true,
  smartcase = true,
  linebreak = true,
  breakindent = true,
  showbreak = ↳,
  list = false,
  -- cmdheight = 0,
}

-- Set options from table
for opt, val in pairs(opts) do
  vim.o[opt] = val
end

-- OSC 52 clipboard for sandbox/SSH environments (terminal handles copy to host)
if vim.fn.has("mac") == 0 and vim.fn.executable("pbcopy") == 0 then
  vim.g.clipboard = {
    name = "OSC 52",
    copy = {
      ["+"] = require("vim.ui.clipboard.osc52").copy("+"),
      ["*"] = require("vim.ui.clipboard.osc52").copy("*"),
    },
    paste = {
      ["+"] = require("vim.ui.clipboard.osc52").paste("+"),
      ["*"] = require("vim.ui.clipboard.osc52").paste("*"),
    },
  }
end

-- Set other options
-- disable other themes, use default moonfly
-- local colorscheme = require("helpers.colorscheme")
-- vim.cmd.colorscheme(colorscheme)

vim.api.nvim_create_autocmd("FileType", {
  pattern = { "markdown", "text", "gitcommit" }, -- Add more types if needed
  callback = function()
    vim.opt_local.spell = true
    vim.opt_local.spelllang = "en_us"
  end,
})

vim.api.nvim_create_autocmd({ "InsertLeave", "TextChanged" }, {
  pattern = "*.md",
  callback = function()
    if vim.bo.modified and vim.fn.expand("%") ~= "" and vim.bo.buftype == "" then
      vim.cmd("silent! write")
    end
  end,
})

