return {
  "rmagatti/auto-session",
  config = function()
    require("auto-session").setup {
      log_level = "error",
      auto_session_suppress_dirs = {"~/", "~/Downloads", "~/Documents"},
      auto_save_enabled = true,
      auto_restore_enabled = true,
    }
  end,
}
