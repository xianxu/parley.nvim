# CLAUDE.md

## Workflow Orchestration

### 1. Plan Mode Default
- Enter plan mode for ANY non-trivial task (3+ steps or architectural decisions)
- If something goes sideways, STOP and re-plan immediately — don’t keep pushing
- Use plan mode for verification steps, not just building
- Write detailed specs in specs/ upfront to reduce ambiguity
- Read specs/index.md to get a sense of the features

### 2. Subagent Strategy
- Use subagents liberally to keep main context window clean
- Offload research, exploration, and parallel analysis to subagents
- For complex problems, throw more compute at it via subagents
- One task per subagent for focused execution

### 3. Self-Improvement Loop
- After ANY correction from the user, update `tasks/lessons.md` with the pattern
- Write rules for yourself that prevent the same mistake
- Ruthlessly iterate on these lessons until mistake rate drops
- Review lessons at session start for relevant project

### 4. Verification Before Done
- Never mark a task complete without proving it works
- Diff behavior between main and your changes when relevant
- Ask yourself: “Would a staff engineer approve this?”
- Run tests, check logs, demonstrate correctness

### 5. Demand Elegance (Balanced)
- For non-trivial changes: pause and ask “is there a more elegant way?”
- If a fix feels hacky: “Knowing everything I know now, implement the elegant solution”
- Skip this for simple, obvious fixes — don’t over-engineer
- Challenge your own work before presenting it

### 6. Autonomous Bug Fixing
- When given a bug report: just fix it. Don’t ask for hand-holding
- Point at logs, errors, failing tests — then resolve them
- Zero context switching required from the user
- Go fix failing CI tests without being told how

### 7. Maintenance of Specs and Documentation
- After changes, update corresponding specs in specs/ folder
- Specs should be organized into subfolders by feature or component for easy navigation.
- Maintain a specs/index.md that links to all spec files with brief descriptions of their contents.
- When unsure, ask user which spec file to update.

## Task Management
1. **Plan First**: Write plan to `tasks/todo.md` with checkable items
2. **Verify Plan**: Check in before starting implementation
3. **Track Progress**: Mark items complete as you go
4. **Explain Changes**: High-level summary at each step
5. **Document Results**: Add review section to `tasks/todo.md`
6. **Capture Lessons**: Update `tasks/lessons.md` after corrections

## Core Principles
- **Simplicity First**: Make every change as simple as possible. Minimal impact.
- **No Laziness**: Find root causes. No temporary fixes. Senior developer standards.
- **Minimal Impact**: Changes should only touch what’s necessary. Avoid introducing bugs.
- **Keep It DRY**: Don’t Repeat Yourself. Refactor to reuse existing code when possible.
- **Design for Testability**: Write code that’s easy to unit test. Add tests for new functionality. Organize tests in a clear hierarchical structure to test corresponding components or features. 

## Project Overview
Parley.nvim is a Neovim plugin that provides a streamlined LLM chat interface with highlighting and navigation features. It supports multiple AI providers (OpenAI, Anthropic, Google AI, Ollama).

## Development Commands
- Manual testing: Start Neovim and use `:lua require('parley').setup()` followed by `:Parley`
- Run tests: `make test` (runs all unit + integration tests via plenary.nvim in headless Neovim)
- Refresh SSE fixtures: `ANTHROPIC_API_KEY=... OPENAI_API_KEY=... make fixtures`
- Test files live in `tests/unit/` (pure logic, no Neovim APIs) and `tests/integration/` (full Neovim runtime)
- Lint: None specified (consider using luacheck or lua-formatter if needed)

## Code Style Guidelines
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

## Architecture Notes
- Config is handled through `/lua/parley/config.lua`
- Logging through `/lua/parley/logger.lua`
- UI rendering in `/lua/parley/render.lua`
- LLM connections managed in dispatcher and provider-specific modules
