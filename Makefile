.PHONY: test fixtures

PLENARY = ~/.local/share/nvim/lazy/plenary.nvim

# Run all tests (unit + integration) via plenary in headless Neovim.
# Each spec file runs sequentially to avoid state bleed.
test:
	nvim --headless --noplugin -u tests/minimal_init.vim \
	  -c "PlenaryBustedDirectory tests/ {sequential = true}" \
	  -c "qa!"

# Refresh SSE fixture files from real APIs.
# Requires ANTHROPIC_API_KEY, OPENAI_API_KEY, GOOGLEAI_API_KEY in environment.
fixtures:
	nvim --headless --noplugin -u tests/minimal_init.vim \
	  -c "luafile scripts/record_fixtures.lua" \
	  -c "qa!"
