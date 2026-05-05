# AI issue-based workflow — include from your project Makefile:
#   include Makefile.workflow

# Include openshell targets if available
-include .openshell/Makefile
# Override WF_ISSUES_DIR / WF_HISTORY_DIR before the include if your
# issues and history live somewhere other than issues/ and history/.

WF_ISSUES_DIR ?= issues
WF_HISTORY_DIR ?= history
export WF_ISSUES_DIR WF_HISTORY_DIR

# ── Upstream config ──────────────────────────────────────────────────────────
# Defaults assume ariadne is upstream. Descendants of nous (or other re-export
# hosts) override these in their root Makefile before `include Makefile.workflow`:
#   UPSTREAM_NAME    := nous
#   UPSTREAM_REFRESH := ../nous/nous/setup.sh
UPSTREAM_NAME      ?= ariadne
UPSTREAM_DIR       ?= ../$(UPSTREAM_NAME)
UPSTREAM_MODE_FILE ?= .$(UPSTREAM_NAME)-mode
UPSTREAM_REFRESH   ?= $(UPSTREAM_DIR)/construct/setup.sh

.PHONY: help-workflow worktree fetch push pull-request merge check pre-merge refresh issue-sync

help-workflow:
	@printf '%s\n' \
	"AI Workflow (issue-based):" \
	"" \
	"  Work on main:" \
	"    make fetch 42       Fetch GitHub issue, create $(WF_ISSUES_DIR)/NNNN-slug.md" \
	"    make push           Auto-commit, push, close done issues, archive to $(WF_HISTORY_DIR)/" \
	"" \
	"  Work on a larger issue:" \
	"    make worktree       Auto-detect issue file, commit, create worktree" \
	"    make worktree NAME  Create a worktree with explicit name" \
	"    make pull-request   Push branch, open PR referencing GitHub issues" \
	"    make merge          Merge PR, archive done issues, clean up worktree" \
	"" \
	"  Pre-merge checks (agent-driven, run first in push/merge):" \
	"    make check          Run all checks with interactive selection" \
	"    make check-dry      Check DRY principle" \
	"    make check-pure     Check PURE principle" \
	"    make check-plan     Check issue plan completeness" \
	"    make check-specs    Check atlas/README sync" \
	"    make check-lessons  Check for lessons to capture" \
	"    PRE_MERGE_CHECKS=yynnyn make pre-merge   Preset selection" \
	"" \
	"  Sync issues:" \
	"    make issue-sync     Sync $(WF_ISSUES_DIR)/ changes to main and push" \
	"" \
	"  Close (mechanical §5 checklist):" \
	"    make close-issue ISSUE=N [MILESTONE=Mx] ACTUAL=h VERIFIED='...'" \
	"                        Tick checkboxes, set status/actual_hours, update project file" \
	"" \
	"  Setup:" \
	"    make refresh        Re-run $(UPSTREAM_NAME) setup (link + merge settings)" \
	""

# ── Issue sync ────────────────────────────────────────────────────────────────
# Sync issue file changes to main and push, even when on a feature branch.
issue-sync:
	@scripts/issue-sync.sh

# ── Close (issue or milestone) ────────────────────────────────────────────────
# Mechanical part of AGENTS.md §5: tick checkboxes, flip status, write
# actual_hours, update the project file's task row + detail block.
# Does NOT commit — the agent commits, usually bundling other content.
#
# Usage:
#   make close-issue ISSUE=15 MILESTONE=M4 ACTUAL=2.5 VERIFIED="ran ./test, saw X"
#   make close-issue ISSUE=15 ACTUAL=7 VERIFIED="end-to-end run, captured in Log"
# Required for issue close: ACTUAL + VERIFIED.
# Flags:
#   FORCE=1   skip "already done" / "Plan unchecked" / "atlas untouched" guards
#   DRY=1     print what would change, write nothing
#   BRAIN_DIR=../brain   override project-file lookup root
.PHONY: close-issue
close-issue: export ISSUE       := $(ISSUE)
close-issue: export MILESTONE   := $(MILESTONE)
close-issue: export ACTUAL      := $(ACTUAL)
close-issue: export VERIFIED    := $(VERIFIED)
close-issue: export FORCE       := $(FORCE)
close-issue: export DRY         := $(DRY)
close-issue: export BRAIN_DIR   := $(BRAIN_DIR)
close-issue:
	@scripts/close-issue.py

# ── Refresh (setup + merge) ───────────────────────────────────────────────────
# Detection (all keyed off UPSTREAM_* vars; defaults target ariadne):
#   $(UPSTREAM_MODE_FILE) present → adopted target. Run $(UPSTREAM_REFRESH) so
#     vendored copies are refreshed from the source of truth. If upstream is
#     missing, fall back to merging settings with the local vendored merge
#     script (skips the re-vendor — local construct/ may be stale).
#   $(UPSTREAM_MODE_FILE) absent + construct/setup.sh present → upstream itself
#     (e.g. running inside ariadne); just merge.
#   $(UPSTREAM_MODE_FILE) absent + upstream present → uninitialized target; first-time adopt.
refresh:
	@if [ -f $(UPSTREAM_MODE_FILE) ]; then \
		if [ -f $(UPSTREAM_REFRESH) ]; then \
			$(UPSTREAM_REFRESH); \
		else \
			echo "$(UPSTREAM_DIR) not found — merging settings only (skipping re-vendor)."; \
			construct/scripts/merge-settings.sh .claude/settings.ariadne.json .claude; \
			echo "Done. .claude/settings.json updated."; \
		fi; \
	elif [ -f construct/setup.sh ]; then \
		echo "$(UPSTREAM_NAME) repo detected — merging settings only."; \
		construct/scripts/merge-settings.sh .claude/settings.ariadne.json .claude; \
		echo "Done. .claude/settings.json updated."; \
	elif [ -f $(UPSTREAM_REFRESH) ]; then \
		$(UPSTREAM_REFRESH); \
	else \
		echo "Error: $(UPSTREAM_NAME) not found at $(UPSTREAM_DIR)."; \
		echo "  Clone it as a sibling directory."; \
		exit 1; \
	fi

# ── Pre-merge checks ─────────────────────────────────────────────────────────
check: pre-merge

c:
	@scripts/parallel-checks.sh --audit

pre-merge:
	@scripts/parallel-checks.sh

check-%:
	@scripts/pre-merge-checks.sh $*

# Worktree management targets
# Capture extra argument after worktree (e.g. make worktree feature-x)
ifeq (worktree,$(firstword $(MAKECMDGOALS)))
  WT_NAME := $(wordlist 2,$(words $(MAKECMDGOALS)),$(MAKECMDGOALS))
  ifneq ($(WT_NAME),)
    $(eval $(WT_NAME):;@:)
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
# Usage: make worktree <name>    — explicit name
#        make worktree            — auto-detect from single untracked issue file
worktree:
	@name="$(WT_NAME)"; \
	if [ -z "$$name" ]; then \
		issues=$$(git ls-files --others --exclude-standard -- '$(WF_ISSUES_DIR)/' 2>/dev/null | grep -E '/[0-9]{6}-.*\.md$$'); \
		count=$$(echo "$$issues" | grep -c . 2>/dev/null || echo 0); \
		if [ "$$count" -eq 1 ]; then \
			name=$$(basename "$$issues" .md); \
			echo "Auto-detected issue: $$name"; \
		else \
			echo "Usage: make worktree <name>"; \
			if [ "$$count" -gt 1 ]; then \
				echo "Multiple untracked issue files found:"; \
				echo "$$issues" | sed 's/^/  /'; \
			fi; \
			exit 1; \
		fi; \
	fi; \
	if [ -n "$$issues" ] && [ -f "$$issues" ]; then \
		echo "==> Committing $$issues before creating worktree..."; \
		git add "$$issues" && \
		git commit -m "committing issue file before creating worktree" && \
		git push || echo "  Warning: push failed, continuing with worktree creation"; \
	fi; \
	repo_dir=$$(basename "$$(pwd)"); \
	mkdir -p "../worktree/$$repo_dir"; \
	git worktree add -b "$$name" "../worktree/$$repo_dir/$$name" HEAD; \
	echo "Worktree created at ../worktree/$$repo_dir/$$name on branch $$name"; \
	printf '%s' "../worktree/$$repo_dir/$$name" > .goto; \
	echo "Run: g (to cd into worktree)"

# Fetch a GitHub issue and create a local issue file in issues/.
# Usage: make fetch <number>
fetch:
	@if [ -z "$(FETCH_NUM)" ]; then \
		echo "Usage: make fetch <number>"; \
		exit 1; \
	fi
	@set -o pipefail; \
	repo=$$(git remote get-url origin | sed 's|.*github.com[:/]\(.*\)\.git|\1|;s|.*github.com[:/]\(.*\)$$|\1|'); \
	gh_title=$$(gh issue view "$(FETCH_NUM)" --repo "$$repo" --json title --jq '.title') || exit 1; \
	gh_body=$$(gh issue view "$(FETCH_NUM)" --repo "$$repo" --json body --jq '.body // ""'); \
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
	printf '%s' "$$main_path" > "$$wt_path/.goto"; \
	echo "Done. Run: g (to cd back to main)"

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
