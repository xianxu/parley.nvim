# Style Guidelines

## Code Style
- Use 4-space indentation consistently
- Follow Lua module pattern with `local M = {}` and `return M`
- Prefer local functions: `local function name()` or `M.name = function()`
- Use descriptive variable and function names (snake_case)
- Wrap Neovim API calls with pcall for error handling
- Prefer vim.api for Neovim API calls
- Use local variables to avoid polluting global namespace
- Use multi-line strings with `[[...]]` syntax for templates
- Document functions with inline comments explaining purpose and parameters
- Follow existing patterns for config handling and error messaging
