# Spec: Lualine Integration

## Config
- `lualine.enable`: boolean on/off
- `lualine.section`: target section (e.g. `lualine_x`)

## Component Content
- `[AgentName]`: current agent
- `[w]` / `[w?]`: web search active / enabled but unsupported
- `05min`: interview elapsed timer
- Optional cache/token metrics

## Manual Integration
- `require('parley.lualine').create_component()` for custom positioning
