return {
  {
    "bluz71/vim-moonfly-colors",
    name = "moonfly",         -- optional but helps in `colorscheme` calls
    lazy = false,             -- make sure it's loaded at startup
    priority = 1000,          -- load before other plugins/themes
    config = function()
      vim.cmd.colorscheme("moonfly")
    end,
  },
}
