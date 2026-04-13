# AI issue-based workflow — include from your project Makefile:
#   include Makefile.workflow
# Override WF_ISSUES_DIR / WF_HISTORY_DIR before the include if your
# issues and history live somewhere other than issues/ and history/.

WF_ISSUES_DIR ?= issues
WF_HISTORY_DIR ?= history
export WF_ISSUES_DIR WF_HISTORY_DIR

.PHONY: help-workflow worktree issue fetch push pull-request merge check pre-merge test-agents

help-workflow:
	@printf '%s\n' \
	"AI Workflow (issue-based):" \
	"" \
	"  Work on main:" \
	"    make fetch 42       Fetch GitHub issue, create $(WF_ISSUES_DIR)/NNNN-slug.md" \
	"    make push           Auto-commit, push, close done issues, archive to $(WF_HISTORY_DIR)/" \
	"" \
	"  Work on a larger issue:" \
	"    make issue 42       Fetch issue into $(WF_ISSUES_DIR)/, create worktree in ../worktree/" \
	"    make pull-request   Push branch, open PR referencing GitHub issues" \
	"    make merge          Merge PR, archive done issues, clean up worktree" \
	"" \
	"  Pre-merge checks (agent-driven, run first in push/merge):" \
	"    make check          Run all checks with interactive selection" \
	"    make check-dry      Check DRY principle" \
	"    make check-pure     Check PURE principle" \
	"    make check-plan     Check issue plan completeness" \
	"    make check-test     Run tests + test-agents + lint, inspect results" \
	"    make check-specs    Check atlas/README sync" \
	"    make check-lessons  Check for lessons to capture" \
	"    PRE_MERGE_CHECKS=yynnyn make pre-merge   Preset selection" \
	"" \
	"  Other:" \
	"    make worktree NAME  Create a worktree in ../worktree/<name>" \
	"    make test-agents    Run agent workflow tests" \
	""

# ── Pre-merge checks ─────────────────────────────────────────────────────────
check: pre-merge

c:
	@scripts/parallel-checks.sh --audit

pre-merge:
	@scripts/parallel-checks.sh

check-%:
	@scripts/pre-merge-checks.sh $*

test-agents:
	@tests/test_agents.sh

test-checks:
	@tests/test_parallel_checks.sh

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
	@mkdir -p ../worktree
	@name="$(WT_NAME)"; \
	git worktree add -b "$$name" "../worktree/$$name" HEAD
	@echo "Worktree created at ../worktree/$(WT_NAME) on branch $(WT_NAME)"

# Create a new git worktree for a GitHub issue, create issue file in issues/.
# Usage: make issue <number>
issue:
	@if [ -z "$(ISSUE_NUM)" ]; then \
		echo "Usage: make issue <number>"; \
		exit 1; \
	fi
	@mkdir -p ../worktree
	@set -o pipefail; \
	branch="$(REPO_NAME)-$(ISSUE_NUM)"; \
	wt_path="../worktree/$$branch"; \
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
	gh_json=$$(gh issue view "$(ISSUE_NUM)" --repo "$$repo" --json number,title,body) || { git worktree remove "$$wt_path" 2>/dev/null; exit 1; }; \
	gh_title=$$(echo "$$gh_json" | jq -r '.title'); \
	gh_body=$$(echo "$$gh_json" | jq -r '.body // ""'); \
	slug=$$(echo "$$gh_title" | tr '[:upper:]' '[:lower:]' | sed 's/[^a-z0-9]/-/g; s/--*/-/g; s/^-//; s/-$$//'); \
	mkdir -p "$$wt_path/$(WF_ISSUES_DIR)"; \
	max_id=$$(ls "$$wt_path/$(WF_ISSUES_DIR)/" "$$wt_path/$(WF_HISTORY_DIR)/" 2>/dev/null | grep -oE '^[0-9]{6}-' | sed 's/-//' | sort -n | tail -1); \
	next_id=$$(printf '%06d' $$(( $${max_id:-0} + 1 )) ); \
	issue_file="$$wt_path/$(WF_ISSUES_DIR)/$${next_id}-$${slug}.md"; \
	today=$$(date +%Y-%m-%d); \
	printf '%s\n' \
		"---" \
		"id: $$next_id" \
		"status: open" \
		"deps: []" \
		"github_issue: $(ISSUE_NUM)" \
		"created: $$today" \
		"updated: $$today" \
		"---" \
		"" \
		"# $$gh_title" \
		"" \
		"$$gh_body" \
		"" \
		"## Done when" \
		"" \
		"-" \
		"" \
		"## Plan" \
		"" \
		"- [ ]" \
		"" \
		"## Log" \
		"" \
		"### $$today" \
		"" \
		> "$$issue_file"; \
	echo "Worktree created at $$wt_path on branch $$branch"; \
	echo "Issue file: $$issue_file"; \
	echo "Run: cd $$wt_path"

# Fetch a GitHub issue and create a local issue file in issues/.
# Usage: make fetch <number>
fetch:
	@if [ -z "$(FETCH_NUM)" ]; then \
		echo "Usage: make fetch <number>"; \
		exit 1; \
	fi
	@set -o pipefail; \
	repo=$$(git remote get-url origin | sed 's|.*github.com[:/]\(.*\)\.git|\1|;s|.*github.com[:/]\(.*\)$$|\1|'); \
	gh_json=$$(gh issue view "$(FETCH_NUM)" --repo "$$repo" --json number,title,body) || exit 1; \
	gh_title=$$(echo "$$gh_json" | jq -r '.title'); \
	gh_body=$$(echo "$$gh_json" | jq -r '.body // ""'); \
	slug=$$(echo "$$gh_title" | tr '[:upper:]' '[:lower:]' | sed 's/[^a-z0-9]/-/g; s/--*/-/g; s/^-//; s/-$$//'); \
	mkdir -p $(WF_ISSUES_DIR); \
	max_id=$$(ls $(WF_ISSUES_DIR)/ $(WF_HISTORY_DIR)/ 2>/dev/null | grep -oE '^[0-9]{6}-' | sed 's/-//' | sort -n | tail -1); \
	next_id=$$(printf '%06d' $$(( $${max_id:-0} + 1 )) ); \
	issue_file="$(WF_ISSUES_DIR)/$${next_id}-$${slug}.md"; \
	today=$$(date +%Y-%m-%d); \
	printf '%s\n' \
		"---" \
		"id: $$next_id" \
		"status: open" \
		"deps: []" \
		"github_issue: $(FETCH_NUM)" \
		"created: $$today" \
		"updated: $$today" \
		"---" \
		"" \
		"# $$gh_title" \
		"" \
		"$$gh_body" \
		"" \
		"## Done when" \
		"" \
		"-" \
		"" \
		"## Plan" \
		"" \
		"- [ ]" \
		"" \
		"## Log" \
		"" \
		"### $$today" \
		"" \
		> "$$issue_file"; \
	echo "Created $$issue_file (GitHub #$(FETCH_NUM))"

# Push to remote, close GitHub issues for done issues, move done issues to history/.
# Works from main — the direct-on-main workflow counterpart to merge.
# Usage: make push
push:
	@branch=$$(git branch --show-current); \
	if [ "$$branch" != "main" ]; then \
		echo "Error: make push must be run from main (current branch: $$branch)"; \
		exit 1; \
	fi
	@untracked=$$(git ls-files --others --exclude-standard); \
	if [ -n "$$untracked" ]; then \
		echo "  [x] Untracked files found — add or .gitignore them first"; \
		echo "$$untracked" | sed 's/^/       /'; \
		exit 1; \
	fi; \
	dirty=$$(git status --porcelain); \
	if [ -n "$$dirty" ]; then \
		echo "==> Auto-committing tracked changes..."; \
		commit_msg=""; \
		for f in $(WF_ISSUES_DIR)/[0-9][0-9][0-9][0-9][0-9][0-9]-*.md; do \
			[ -f "$$f" ] || continue; \
			if ! git diff --quiet -- "$$f" 2>/dev/null || ! git diff --cached --quiet -- "$$f" 2>/dev/null; then \
				topic=$$(grep -m1 '^# ' "$$f" | sed 's/^# *//'); \
				if [ -n "$$topic" ]; then \
					if [ -n "$$commit_msg" ]; then \
						commit_msg="$$commit_msg"$$'\n'"$$topic"; \
					else \
						commit_msg="$$topic"; \
					fi; \
				fi; \
			fi; \
		done; \
		if [ -z "$$commit_msg" ]; then \
			commit_msg="auto-commit before push"; \
		fi; \
		git commit -a -m "$$commit_msg" || exit 1; \
	fi
	@$(MAKE) pre-merge
	@$(call check_undone_issues,origin/main,$(WF_ISSUES_DIR)) \
	git push || exit 1; \
	repo=$$(git remote get-url origin | sed 's|.*github.com[:/]\(.*\)\.git|\1|;s|.*github.com[:/]\(.*\)$$|\1|'); \
	moved=0; \
	if [ -d $(WF_ISSUES_DIR) ]; then \
		for f in $(WF_ISSUES_DIR)/[0-9][0-9][0-9][0-9][0-9][0-9]-*.md; do \
			[ -f "$$f" ] || continue; \
			status=$$(grep -m1 '^status:' "$$f" | sed 's/^status:[[:space:]]*//'); \
			if [ "$$status" = "done" ] || [ "$$status" = "wontfix" ] || [ "$$status" = "punt" ]; then \
				if [ "$$status" = "done" ]; then \
					gh_num=$$(grep -m1 '^github_issue:' "$$f" | sed 's/^github_issue:[[:space:]]*//'); \
					if [ -n "$$gh_num" ] && [ "$$gh_num" != "" ]; then \
						echo "==> Closing GitHub issue #$$gh_num..."; \
						gh issue close "$$gh_num" --repo "$$repo" --comment "Fixed on main." || true; \
					fi; \
				fi; \
				mkdir -p $(WF_HISTORY_DIR); \
				echo "==> Archiving $$f to $(WF_HISTORY_DIR)/..."; \
				mv "$$f" "$(WF_HISTORY_DIR)/$$(basename $$f)"; \
				moved=1; \
			fi; \
		done; \
	fi; \
	if [ "$$moved" -eq 1 ]; then \
		echo "==> Committing archived history..."; \
		git add $(WF_ISSUES_DIR)/ $(WF_HISTORY_DIR)/ && \
		git commit -m "archive completed issues to history" && \
		git push; \
	fi; \
	echo "Done."

# Create a GitHub pull request from the current worktree branch to main.
# Scans issues/ files touched since branch point for github_issue frontmatter.
# Must be run from inside a worktree (not from main).
pull-request:
	@branch=$$(git branch --show-current); \
	if [ -z "$$branch" ] || [ "$$branch" = "main" ]; then \
		echo "Error: run this from a worktree branch, not main"; \
		exit 1; \
	fi; \
	git push -u origin "$$branch" || exit 1; \
	repo=$$(git remote get-url origin | sed 's|.*github.com[:/]\(.*\)\.git|\1|;s|.*github.com[:/]\(.*\)$$|\1|'); \
	base=$$(git merge-base main HEAD 2>/dev/null || echo main); \
	touched_issues=$$(git diff --name-only "$$base"..HEAD -- '$(WF_ISSUES_DIR)/*.md' 2>/dev/null); \
	gh_nums=""; \
	for f in $$touched_issues; do \
		[ -f "$$f" ] || continue; \
		num=$$(grep -m1 '^github_issue:' "$$f" | sed 's/^github_issue:[[:space:]]*//'); \
		if [ -n "$$num" ] && [ "$$num" != "" ]; then \
			gh_nums="$$gh_nums $$num"; \
		fi; \
	done; \
	fixes=""; \
	if [ -n "$$gh_nums" ]; then \
		fixes=$$(echo $$gh_nums | tr ' ' '\n' | sort -u | sed 's/^/#/' | paste -sd ', ' -); \
		fixes="Fixes $$fixes"; \
	fi; \
	commits=$$(git log main..HEAD --pretty=format:'- %s' 2>/dev/null); \
	if [ -n "$$fixes" ]; then \
		echo "Including in PR body: $$fixes"; \
		body="$$commits"; \
		if [ -n "$$body" ]; then \
			body="$$body"$$'\n\n'"$$fixes"; \
		else \
			body="$$fixes"; \
		fi; \
		gh pr create --repo "$$repo" --base main --head "$$branch" --fill-first --body "$$body"; \
	else \
		gh pr create --repo "$$repo" --base main --head "$$branch" --fill; \
	fi

# Merge the current worktree branch into main (if a PR exists),
# move done issues to history/, clean up the worktree.
# Must be run from inside a worktree (not from main).
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
	echo "  [ok] No unpushed local commits (HEAD synced with $$upstream)"
	@$(MAKE) pre-merge \
	wt_path=$$(git rev-parse --show-toplevel); \
	main_path=$$(git worktree list | grep '\[main\]' | awk '{print $$1}'); \
	if [ -z "$$main_path" ]; then \
		echo "  [x] Could not find main worktree — is main checked out?"; \
		exit 1; \
	fi; \
	repo=$$(git remote get-url origin | sed 's|.*github.com[:/]\(.*\)\.git|\1|;s|.*github.com[:/]\(.*\)$$|\1|'); \
	unmerged=$$(git log "main..HEAD" --oneline 2>/dev/null); \
	if [ -n "$$unmerged" ]; then \
		echo "  [ok] Unmerged local commits found:"; \
		echo "$$unmerged" | sed 's/^/       /'; \
	else \
		echo "  [ok] No unmerged local commits (branch is clean)"; \
	fi; \
	$(call check_undone_issues,main,$(WF_ISSUES_DIR)) \
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
		gh pr merge --repo "$$repo" --merge --delete-branch "$$branch" || exit 1; \
		echo "==> Pulling main..."; \
		git -C "$$main_path" pull || exit 1; \
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
	echo "==> Archiving completed issues to $(WF_HISTORY_DIR)/..."; \
	moved=0; \
	if [ -d "$$main_path/$(WF_ISSUES_DIR)" ]; then \
		for f in "$$main_path"/$(WF_ISSUES_DIR)/[0-9][0-9][0-9][0-9][0-9][0-9]-*.md; do \
			[ -f "$$f" ] || continue; \
			status=$$(grep -m1 '^status:' "$$f" | sed 's/^status:[[:space:]]*//'); \
			if [ "$$status" = "done" ] || [ "$$status" = "wontfix" ] || [ "$$status" = "punt" ]; then \
				mkdir -p "$$main_path/$(WF_HISTORY_DIR)"; \
				echo "  Moving $$(basename $$f) to $(WF_HISTORY_DIR)/"; \
				mv "$$f" "$$main_path/$(WF_HISTORY_DIR)/$$(basename $$f)"; \
				moved=1; \
			fi; \
		done; \
	fi; \
	if [ "$$moved" -eq 1 ]; then \
		echo "==> Committing archived history in main..."; \
		git -C "$$main_path" add $(WF_ISSUES_DIR)/ $(WF_HISTORY_DIR)/ && \
		git -C "$$main_path" commit -m "archive completed issues to history" && \
		git -C "$$main_path" push; \
	fi; \
	echo "==> Removing worktree at $$wt_path..."; \
	git -C "$$main_path" worktree remove "$$wt_path" 2>/dev/null || true; \
	git -C "$$main_path" branch -D "$$branch" 2>/dev/null || true; \
	echo "Done. Run: cd $$main_path"

# Warn if any touched issue files are not marked as resolved (done/wontfix/punt).
# Usage: $(call check_undone_issues,<base-ref>,<issues-dir>)
#   base-ref:   git ref to diff against (e.g. origin/main, main)
#   issues-dir: path to issues directory (e.g. $(WF_ISSUES_DIR), $$main_path/$(WF_ISSUES_DIR))
define check_undone_issues
	not_done=""; \
	touched=$$(git diff --name-only $(1)..HEAD -- '$(WF_ISSUES_DIR)/*.md' 2>/dev/null); \
	for f in $$touched; do \
		target="$(2)/$$(basename $$f)"; \
		[ -f "$$target" ] || continue; \
		status=$$(grep -m1 '^status:' "$$target" | sed 's/^status:[[:space:]]*//'); \
		if [ "$$status" != "done" ] && [ "$$status" != "wontfix" ] && [ "$$status" != "punt" ]; then \
			not_done="$$not_done\n  $$f (status: $${status:-unset})"; \
		fi; \
	done; \
	if [ -n "$$not_done" ]; then \
		printf "⚠️  Touched issue files that are NOT done:$$not_done\n"; \
		printf "Continue anyway? [y/N] "; \
		read undone_answer; \
		if [ "$$undone_answer" != "y" ] && [ "$$undone_answer" != "Y" ]; then \
			echo "Aborted."; \
			exit 1; \
		fi; \
	fi;
endef
