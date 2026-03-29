return {
  "xianxu/telescope-frecency.nvim",
  branch = "feature",
  --dir = "~/workspace/telescope-frecency.nvim",
  name = "telescope-frecency.nvim", -- optional, but can be helpful
  -- dev = true,         -- optional, disables some caching features
  dependencies = { "tami5/sqlite.lua" }, -- needs sqlite for storing usage
  config = function()
    require("telescope").load_extension("frecency")
  end,
}
