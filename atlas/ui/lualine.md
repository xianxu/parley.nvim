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
- Existing lualine `branch` components are kept as lualine branch components,
  but Parley wraps their `fmt` callback to shorten long display labels: first
  word plus its space/`-`/`_` separator when present, capped at 10 characters,
  plus `...` when shortened. The underlying git branch name is not changed.
- In repo mode, Parley suppresses cwd/directory display and lualine `filename`
  components to save statusline width; interview mode remains visible because it
  carries active timer state rather than location context.

## Manual Integration
- `require('parley.lualine').create_component()` for custom positioning
- `require('parley.lualine').create_mode_component()` for the mode glyph (use with `replace_filetype = false`)
- `require('parley.lualine').format_branch_label()` for the branch display rule
