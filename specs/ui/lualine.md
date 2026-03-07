# Spec: Lualine Integration

## Overview
Parley integrates with `lualine.nvim` to provide statusline indicators for the current agent, search state, and interview timer.

## Configuration
- `lualine.enable`: Boolean to enable/disable integration.
- `lualine.section`: Default lualine section for the component (e.g., `lualine_x`).

## Component Content
- **Current Agent**: `[AgentName]`.
- **Web Search State**: `[w]` (active), `[w?]` (enabled but unsupported).
- **Interview Timer**: Displays the elapsed time (e.g., `05min`) during active interviews.
- **Cache Metrics**: Optionally displays token usage/cache hits for the session.

## Manual Integration
- `require('parley.lualine').create_component()`: Provides a lualine-compatible component for custom positioning.
