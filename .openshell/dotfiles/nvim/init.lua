-- Handle plugins with lazy.nvim
require("core.lazy")

-- General Neovim keymaps
require("core.keymaps")

-- Other options
require("core.options")

-- Custom path for Lua modules (host-specific .so files, skip in sandbox)
-- package.cpath = package.cpath .. ";" .. vim.fn.expand("~") .. "/settings/?.so"

