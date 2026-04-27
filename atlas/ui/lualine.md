# Spec: Lualine Integration

## Config
- `lualine.enable`: boolean on/off
- `lualine.section`: target section (e.g. `lualine_x`)
- `lualine.replace_filetype`: when true (default), auto-replaces the user's filetype component with a parley mode glyph (`○` global / `⊚` repo / `⦿` super-repo). See [Super-Repo Mode](../modes/super_repo.md).

## Component Content
- `[AgentName]`: current agent
- `[w]` / `[w?]`: web search active / enabled but unsupported
- `05min`: interview elapsed timer
- Optional cache/token metrics
- Mode glyph (`○` / `⊚` / `⦿`) when filetype auto-replace is on; refreshes on `User ParleySuperRepoChanged`

## Manual Integration
- `require('parley.lualine').create_component()` for custom positioning
- `require('parley.lualine').create_mode_component()` for the mode glyph (use with `replace_filetype = false`)
