.PHONY: test test-spec test-changed lint fixtures model-check model-checker test-clean-env

PLENARY = ~/.local/share/nvim/lazy/plenary.nvim
REAL_HOME = $(HOME)
TEST_HOME = $(CURDIR)/.test-home
TEST_XDG = $(CURDIR)/.test-xdg
TEST_TMP = $(CURDIR)/.test-tmp
TEST_ENV = HOME="$(TEST_HOME)" XDG_DATA_HOME="$(TEST_XDG)/data" XDG_STATE_HOME="$(TEST_XDG)/state" XDG_CACHE_HOME="$(TEST_XDG)/cache" TMPDIR="$(TEST_TMP)" NVIM_TEST_PLENARY="$(REAL_HOME)/.local/share/nvim/lazy/plenary.nvim"

define PREP_TEST_ENV
mkdir -p "$(TEST_HOME)" "$(TEST_XDG)/data" "$(TEST_XDG)/state" "$(TEST_XDG)/cache" "$(TEST_TMP)"
endef

# Run all tests (unit + integration) via plenary in headless Neovim.
# Each spec file runs sequentially to avoid state bleed.
test:
	@$(PREP_TEST_ENV)
	@$(TEST_ENV) nvim --headless --noplugin -u tests/minimal_init.vim \
	  -c "PlenaryBustedDirectory tests/ {sequential = true}" \
	  -c "qa!"

# Run tests mapped to one spec key/path from specs/traceability.yaml.
# Example: make test-spec SPEC=chat/lifecycle
test-spec:
	@if [ -z "$(SPEC)" ]; then \
		echo "Usage: make test-spec SPEC=chat/lifecycle"; \
		exit 1; \
	fi
	@$(PREP_TEST_ENV); \
	tests="$$(scripts/spec_test_map.sh list-tests "$(SPEC)")"; \
	if [ -z "$$tests" ]; then \
		echo "No tests mapped for spec: $(SPEC)"; \
		echo "Update specs/traceability.yaml to add mappings."; \
		exit 1; \
	fi; \
	for test_file in $$tests; do \
		echo "Running $$test_file"; \
		$(TEST_ENV) nvim -n --headless --noplugin -u tests/minimal_init.vim \
		  -c "PlenaryBustedFile $$test_file" \
		  -c "qa!" || exit $$?; \
	done

# Run tests mapped to changed spec files under specs/*/*.md.
# Uses tracked and untracked file changes since feature-branch base
# (default base ref: remote/main, fallback origin/main, then main).
test-changed:
	@$(PREP_TEST_ENV); \
	changed_specs="$$(scripts/spec_test_map.sh list-changed-specs)"; \
	if [ -z "$$changed_specs" ]; then \
		echo "No changed spec files under specs/*/*.md"; \
		exit 0; \
	fi; \
	echo "Changed specs:"; \
	printf '%s\n' "$$changed_specs"; \
	missing=0; \
	for spec_path in $$changed_specs; do \
		spec_tests="$$(scripts/spec_test_map.sh list-tests "$$spec_path")"; \
		if [ -z "$$spec_tests" ]; then \
			echo "No tests mapped for $$spec_path"; \
			missing=1; \
		fi; \
	done; \
	if [ "$$missing" -ne 0 ]; then \
		echo "Please update specs/traceability.yaml for missing mappings."; \
		exit 1; \
	fi; \
	all_tests="$$(scripts/spec_test_map.sh list-tests-from-changed-specs)"; \
	if [ -z "$$all_tests" ]; then \
		echo "No mapped tests found for changed specs."; \
		exit 1; \
	fi; \
	for test_file in $$all_tests; do \
		echo "Running $$test_file"; \
		$(TEST_ENV) nvim -n --headless --noplugin -u tests/minimal_init.vim \
		  -c "PlenaryBustedFile $$test_file" \
		  -c "qa!" || exit $$?; \
	done

# Run static analysis for Lua code and tests.
lint:
	@command -v luacheck >/dev/null 2>&1 || { \
		echo "luacheck not found. Install with: luarocks install luacheck"; \
		exit 1; \
	}
	@luacheck lua tests

# Refresh SSE fixture files from real APIs.
# Requires ANTHROPIC_API_KEY, OPENAI_API_KEY, GOOGLEAI_API_KEY in environment.
fixtures:
	@$(PREP_TEST_ENV)
	@$(TEST_ENV) nvim --headless --noplugin -u tests/minimal_init.vim \
	  -c "luafile scripts/record_fixtures.lua" \
	  -c "qa!"

# Check latest model offerings from each provider and optionally update fixture models.
# Requires API keys in environment.
model-check:
	@bash scripts/model_check.sh

# Backward-compatible alias.
model-checker: model-check

test-clean-env:
	rm -rf "$(TEST_HOME)" "$(TEST_XDG)" "$(TEST_TMP)"
