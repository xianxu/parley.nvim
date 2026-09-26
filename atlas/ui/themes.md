# Packaged Themes

The macOS starter ships Moonfly as its startup colorscheme and includes four
optional themes in the dependency lock: Catppuccin Mocha, Tokyo Night Storm,
Catppuccin Latte, and Solarized Light. `:ParleyTheme` opens the shared floating
picker. Moving the cursor applies a live preview across Neovim, including
Parley's semantic highlight groups, without writing preference state.

Enter commits the highlighted choice to the Parley profile and restores it on
the next launch. Escape cancels the preview and restores the colorscheme that
was active when the picker opened. The final row restores Moonfly. A missing or
invalid preference falls back to the startup theme.

Implementation: `lua/parley/theme.lua`, `lua/parley/theme_picker.lua`, and
`lua/parley/float_picker.lua`; starter dependencies live in
`packaging/starter-config/init.lua`.
