return {
  "folke/todo-comments.nvim",
  dependencies = { "nvim-lua/plenary.nvim" },
  opts = {
    signs = true,
    sign_priority = 20, -- higher priority to ensure visibility
    highlight = {
      keyword = "fg",   -- or "fg", or "wide" depending on what you like
    },
  },
}

