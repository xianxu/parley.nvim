.PHONY: test test-spec test-changed lint fixtures model-check model-checker test-clean-env new-worktree new-issue pull-request merge

# Worktree management targets
# Capture extra argument after new-worktree (e.g. make new-worktree feature-x)
ifeq (new-worktree,$(firstword $(MAKECMDGOALS)))
  WT_NAME := $(wordlist 2,$(words $(MAKECMDGOALS)),$(MAKECMDGOALS))
  ifneq ($(WT_NAME),)
    $(eval $(WT_NAME):;@:)
  endif
endif

# Capture issue number after new-issue (e.g. make new-issue 42)
ifeq (new-issue,$(firstword $(MAKECMDGOALS)))
  ISSUE_NUM := $(wordlist 2,$(words $(MAKECMDGOALS)),$(MAKECMDGOALS))
  ifneq ($(ISSUE_NUM),)
    $(eval $(ISSUE_NUM):;@:)
  endif
endif

# Create a new git worktree in the parent directory.
# Usage: make new-worktree <name>
new-worktree:
	@if [ -z "$(WT_NAME)" ]; then \
		echo "Usage: make new-worktree <name>"; \
		exit 1; \
	fi
	@name="$(WT_NAME)"; \
	git worktree add -b "$$name" "../$$name" HEAD
	@echo "Worktree created at ../$(WT_NAME) on branch $(WT_NAME)"

# Create a new git worktree for a GitHub issue, fetch the issue into tasks/issue.md.
# Usage: make new-issue <number>
new-issue:
	@if [ -z "$(ISSUE_NUM)" ]; then \
		echo "Usage: make new-issue <number>"; \
		exit 1; \
	fi
	@repo_name=$$(basename "$$(git rev-parse --show-toplevel)"); \
	branch="$$repo_name-issue-$(ISSUE_NUM)"; \
	wt_path="../$$branch"; \
	git worktree add -b "$$branch" "$$wt_path" HEAD; \
	repo=$$(git remote get-url origin | sed 's|.*github.com[:/]\(.*\)\.git|\1|;s|.*github.com[:/]\(.*\)$$|\1|'); \
	mkdir -p "$$wt_path/tasks"; \
	gh issue view "$(ISSUE_NUM)" --repo "$$repo" --json number,title,body,labels,assignees,state \
		| jq -r '"# Issue #\(.number): \(.title)\n\n**State:** \(.state)\n**Labels:** \([.labels[].name] | join(", "))\n**Assignees:** \([.assignees[].login] | join(", "))\n\n## Description\n\n\(.body)"' \
		> "$$wt_path/tasks/issue.md"; \
	echo "Worktree created at $$wt_path on branch $$branch"; \
	echo "Issue #$(ISSUE_NUM) saved to $$wt_path/tasks/issue.md"; \
	echo "Run: cd $$wt_path"

# Create a GitHub pull request from the current worktree branch to main.
# Must be run from inside a worktree (not from main).
pull-request:
	@branch=$$(git branch --show-current); \
	if [ -z "$$branch" ] || [ "$$branch" = "main" ]; then \
		echo "Error: run this from a worktree branch, not main"; \
		exit 1; \
	fi; \
	git push -u origin "$$branch"; \
	repo=$$(git remote get-url origin | sed 's|.*github.com[:/]\(.*\)\.git|\1|;s|.*github.com[:/]\(.*\)$$|\1|'); \
	gh pr create --repo "$$repo" --base main --head "$$branch" --fill

# Merge the current worktree branch into main (if a PR exists), close any linked issue,
# then clean up the worktree. Must be run from inside a worktree (not from main).
merge:
	@branch=$$(git branch --show-current); \
	if [ -z "$$branch" ] || [ "$$branch" = "main" ]; then \
		echo "Error: run this from a worktree branch, not main"; \
		exit 1; \
	fi; \
	wt_path=$$(git rev-parse --show-toplevel); \
	main_path=$$(git worktree list | grep '\[main\]' | awk '{print $$1}'); \
	repo=$$(git remote get-url origin | sed 's|.*github.com[:/]\(.*\)\.git|\1|;s|.*github.com[:/]\(.*\)$$|\1|'); \
	pr_number=$$(gh pr list --repo "$$repo" --head "$$branch" --json number --jq '.[0].number' 2>/dev/null); \
	if [ -n "$$pr_number" ]; then \
		echo "Merging PR #$$pr_number ($$branch) into main via GitHub..."; \
		gh pr merge --repo "$$repo" --merge --delete-branch "$$branch"; \
		echo "Pulling main..."; \
		git -C "$$main_path" pull; \
	else \
		echo "No open PR for $$branch, skipping merge."; \
		unmerged=$$(git log "$$main_path/main..HEAD" --oneline 2>/dev/null); \
		if [ -n "$$unmerged" ]; then \
			echo "Warning: branch has committed changes not in main:"; \
			echo "$$unmerged"; \
			printf "Remove worktree without merging? [y/N] "; \
			read answer; \
			if [ "$$answer" != "y" ] && [ "$$answer" != "Y" ]; then \
				echo "Aborted."; \
				exit 1; \
			fi; \
		fi; \
	fi; \
	issue_num=$$(echo "$$branch" | grep -oE 'issue-[0-9]+$$' | grep -oE '[0-9]+$$'); \
	if [ -n "$$issue_num" ]; then \
		echo "Closing issue #$$issue_num..."; \
		gh issue close "$$issue_num" --repo "$$repo"; \
	fi; \
	echo "Cleaning up tasks/todo.md..."; \
	rm -f "$$main_path/tasks/todo.md" && touch "$$main_path/tasks/todo.md"; \
	echo "Removing worktree at $$wt_path..."; \
	git -C "$$main_path" worktree remove "$$wt_path"; \
	if [ -z "$$pr_number" ]; then \
		git -C "$$main_path" branch -D "$$branch"; \
	fi; \
	echo "Done. Run: cd $$main_path"

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
