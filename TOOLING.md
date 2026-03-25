# Tooling

## Development Commands
- Manual testing: Start Neovim and use `:lua require('parley').setup()` followed by `:Parley`
- Run tests: `make test` (runs all unit + integration tests via plenary.nvim in headless Neovim)
- Lint: `make lint`
- Run tests for one spec: `make test-spec SPEC=chat/lifecycle` (uses `specs/traceability.yaml` mapping)
- Run tests for changed specs: `make test-changed` (runs mapped tests for changed `specs/*/*.md` files), this is faster than full test run
- Refresh SSE fixtures: `ANTHROPIC_API_KEY=... OPENAI_API_KEY=... make fixtures`
- Test files live in `tests/unit/` (pure logic, no Neovim APIs) and `tests/integration/` (full Neovim runtime)
