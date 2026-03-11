.PHONY: test test-spec test-changed lint fixtures model-check model-checker test-clean-env worktree issue fetch push pull-request merge

# Worktree management targets
# Capture extra argument after worktree (e.g. make worktree feature-x)
ifeq (worktree,$(firstword $(MAKECMDGOALS)))
  WT_NAME := $(wordlist 2,$(words $(MAKECMDGOALS)),$(MAKECMDGOALS))
  ifneq ($(WT_NAME),)
    $(eval $(WT_NAME):;@:)
  endif
endif

# Capture issue number after issue (e.g. make issue 42)
ifeq (issue,$(firstword $(MAKECMDGOALS)))
  ISSUE_NUM := $(wordlist 2,$(words $(MAKECMDGOALS)),$(MAKECMDGOALS))
  ifneq ($(ISSUE_NUM),)
    $(eval $(ISSUE_NUM):;@:)
  endif
endif

# Capture issue number after fetch (e.g. make fetch 42)
ifeq (fetch,$(firstword $(MAKECMDGOALS)))
  FETCH_NUM := $(wordlist 2,$(words $(MAKECMDGOALS)),$(MAKECMDGOALS))
  ifneq ($(FETCH_NUM),)
    $(eval $(FETCH_NUM):;@:)
  endif
endif

# Create a new git worktree in the parent directory.
# Usage: make worktree <name>
worktree:
	@if [ -z "$(WT_NAME)" ]; then \
		echo "Usage: make worktree <name>"; \
		exit 1; \
	fi
	@name="$(WT_NAME)"; \
	git worktree add -b "$$name" "../$$name" HEAD
	@echo "Worktree created at ../$(WT_NAME) on branch $(WT_NAME)"

# Create a new git worktree for a GitHub issue, fetch the issue into tasks/issue.md.
# Usage: make issue <number>
issue:
	@if [ -z "$(ISSUE_NUM)" ]; then \
		echo "Usage: make issue <number>"; \
		exit 1; \
	fi
	@repo_name=$$(basename "$$(git rev-parse --show-toplevel)"); \
	branch="$$repo_name-$(ISSUE_NUM)"; \
	wt_path="../$$branch"; \
	if git show-ref --verify --quiet "refs/heads/$$branch"; then \
		if [ -d "$$wt_path" ]; then \
			echo "Worktree already exists at $$wt_path, refreshing issue file..."; \
		else \
			echo "Cleaning up stale worktree for branch $$branch..."; \
			git worktree prune; \
			git branch -d "$$branch"; \
			git worktree add -b "$$branch" "$$wt_path" HEAD || exit 1; \
		fi; \
	else \
		git worktree add -b "$$branch" "$$wt_path" HEAD || exit 1; \
	fi; \
	repo=$$(git remote get-url origin | sed 's|.*github.com[:/]\(.*\)\.git|\1|;s|.*github.com[:/]\(.*\)$$|\1|'); \
	mkdir -p "$$wt_path/tasks" && \
	gh issue view "$(ISSUE_NUM)" --repo "$$repo" --json number,title,body,labels,assignees,state \
		| jq -r '"# Issue #\(.number): \(.title)\n\n**State:** \(.state)\n**Labels:** \([.labels[].name] | join(", "))\n**Assignees:** \([.assignees[].login] | join(", "))\n\n## Description\n\n\(.body)"' \
		> "$$wt_path/tasks/issue.md" || { git worktree remove "$$wt_path"; exit 1; }; \
	echo "Worktree created at $$wt_path on branch $$branch"; \
	echo "Issue #$(ISSUE_NUM) saved to $$wt_path/tasks/issue.md"; \
	echo "Run: cd $$wt_path"

# Fetch a GitHub issue and append it to tasks/issue.md in the current directory.
# Usage: make fetch <number>
fetch:
	@if [ -z "$(FETCH_NUM)" ]; then \
		echo "Usage: make fetch <number>"; \
		exit 1; \
	fi
	@repo=$$(git remote get-url origin | sed 's|.*github.com[:/]\(.*\)\.git|\1|;s|.*github.com[:/]\(.*\)$$|\1|'); \
	mkdir -p tasks && \
	echo "" >> tasks/issue.md && \
	gh issue view "$(FETCH_NUM)" --repo "$$repo" --json number,title,body,labels,assignees,state \
		| jq -r '"# Issue #\(.number): \(.title)\n\n**State:** \(.state)\n**Labels:** \([.labels[].name] | join(", "))\n**Assignees:** \([.assignees[].login] | join(", "))\n\n## Description\n\n\(.body)"' \
		>> tasks/issue.md && \
	echo "Issue #$(FETCH_NUM) appended to tasks/issue.md"

# Push to remote and close any issues listed in tasks/issue.md.
# Works from main — the direct-on-main workflow counterpart to merge.
# Usage: make push
push:
	@uncommitted=$$(git status --porcelain); \
	if [ -n "$$uncommitted" ]; then \
		echo "  [x] Uncommitted changes found — commit first"; \
		git status --short; \
		exit 1; \
	fi; \
	git push || exit 1; \
	repo=$$(git remote get-url origin | sed 's|.*github.com[:/]\(.*\)\.git|\1|;s|.*github.com[:/]\(.*\)$$|\1|'); \
	if [ -f tasks/issue.md ]; then \
		nums=$$(grep -oE '^# Issue #[0-9]+' tasks/issue.md | grep -oE '[0-9]+'); \
		if [ -n "$$nums" ]; then \
			for num in $$nums; do \
				echo "==> Closing issue #$$num..."; \
				gh issue close "$$num" --repo "$$repo" --comment "Fixed on main."; \
			done; \
			echo "==> Clearing tasks/issue.md..."; \
			: > tasks/issue.md; \
		fi; \
	fi; \
	echo "Done."

# Create a GitHub pull request from the current worktree branch to main.
# Reads tasks/issue.md for "# Issue #NN" lines and adds "Fixes #NN, ..." to the PR body.
# Must be run from inside a worktree (not from main).
pull-request:
	@branch=$$(git branch --show-current); \
	if [ -z "$$branch" ] || [ "$$branch" = "main" ]; then \
		echo "Error: run this from a worktree branch, not main"; \
		exit 1; \
	fi; \
	git push -u origin "$$branch"; \
	repo=$$(git remote get-url origin | sed 's|.*github.com[:/]\(.*\)\.git|\1|;s|.*github.com[:/]\(.*\)$$|\1|'); \
	fixes=""; \
	if [ -f tasks/issue.md ]; then \
		nums=$$(grep -oE '^# Issue #[0-9]+' tasks/issue.md | grep -oE '[0-9]+'); \
		if [ -n "$$nums" ]; then \
			fixes=$$(echo "$$nums" | sed 's/^/#/' | paste -sd ', ' -); \
			fixes="Fixes $$fixes"; \
		fi; \
	fi; \
	if [ -n "$$fixes" ]; then \
		echo "Including in PR body: $$fixes"; \
		gh pr create --repo "$$repo" --base main --head "$$branch" --fill --body "$$fixes"; \
	else \
		gh pr create --repo "$$repo" --base main --head "$$branch" --fill; \
	fi

# Merge the current worktree branch into main (if a PR exists), close any linked issue,
# then clean up the worktree. Must be run from inside a worktree (not from main).
merge:
	@branch=$$(git branch --show-current); \
	if [ -z "$$branch" ] || [ "$$branch" = "main" ]; then \
		echo "Error: run this from a worktree branch, not main"; \
		exit 1; \
	fi; \
	echo "==> Branch: $$branch"; \
	uncommitted=$$(git status --porcelain); \
	if [ -n "$$uncommitted" ]; then \
		echo "  [x] Uncommitted changes found — cannot merge"; \
		git status --short; \
		echo "Commit or stash them before merging."; \
		exit 1; \
	fi; \
	echo "  [ok] No uncommitted changes"; \
	upstream=$$(git rev-parse --abbrev-ref --symbolic-full-name @{u} 2>/dev/null || true); \
	if [ -z "$$upstream" ]; then \
		echo "  [x] No upstream configured for $$branch"; \
		echo "Push the branch first (e.g. make pull-request or git push -u origin $$branch)."; \
		exit 1; \
	fi; \
	ahead=$$(git rev-list --count "$$upstream..HEAD" 2>/dev/null || echo 0); \
	if [ "$$ahead" -gt 0 ]; then \
		echo "  [x] Unpushed local commits detected: $$ahead commit(s) ahead of $$upstream"; \
		echo "Push your branch before merging."; \
		exit 1; \
	fi; \
	echo "  [ok] No unpushed local commits (HEAD synced with $$upstream)"; \
	wt_path=$$(git rev-parse --show-toplevel); \
	main_path=$$(git worktree list | grep '\[main\]' | awk '{print $$1}'); \
	repo=$$(git remote get-url origin | sed 's|.*github.com[:/]\(.*\)\.git|\1|;s|.*github.com[:/]\(.*\)$$|\1|'); \
	unmerged=$$(git log "main..HEAD" --oneline 2>/dev/null); \
	if [ -n "$$unmerged" ]; then \
		echo "  [ok] Unmerged local commits found:"; \
		echo "$$unmerged" | sed 's/^/       /'; \
	else \
		echo "  [ok] No unmerged local commits (branch is clean)"; \
	fi; \
	printf "Final confirmation: proceed with irreversible merge/cleanup actions? [y/N] "; \
	read final_answer; \
	if [ "$$final_answer" != "y" ] && [ "$$final_answer" != "Y" ]; then \
		echo "Aborted."; \
		exit 1; \
	fi; \
	pr_number=$$(gh pr list --repo "$$repo" --head "$$branch" --json number --jq '.[0].number' 2>/dev/null); \
	if [ -n "$$pr_number" ]; then \
		echo "  [ok] Open PR found: #$$pr_number"; \
		echo "==> Merging PR #$$pr_number ($$branch) into main via GitHub..."; \
		gh pr merge --repo "$$repo" --merge --delete-branch "$$branch"; \
		echo "==> Pulling main..."; \
		git -C "$$main_path" pull; \
	else \
		echo "  [--] No open PR for branch $$branch"; \
		if [ -n "$$unmerged" ]; then \
			printf "Would you like to create a pull request first? [Y/n] "; \
			read answer; \
			if [ "$$answer" != "n" ] && [ "$$answer" != "N" ]; then \
				echo "Run 'make pull-request' to create a PR."; \
				exit 1; \
			fi; \
			printf "Remove worktree without merging? [y/N] "; \
			read answer2; \
			if [ "$$answer2" != "y" ] && [ "$$answer2" != "Y" ]; then \
				echo "Aborted."; \
				exit 1; \
			fi; \
		fi; \
	fi; \
	echo "==> Cleaning up tasks/todo.md..."; \
	rm -f "$$main_path/tasks/todo.md" && touch "$$main_path/tasks/todo.md"; \
	echo "==> Removing worktree at $$wt_path..."; \
	git -C "$$main_path" worktree remove "$$wt_path" 2>/dev/null || true; \
	git -C "$$main_path" branch -D "$$branch" 2>/dev/null || true; \
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
