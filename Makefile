# Canonical repo name from git remote (portable across worktrees and containers)
REPO_NAME := $(shell git remote get-url origin 2>/dev/null | sed 's|.*/||; s|\.git$$||')

# This project nests issues and history under workshop/
WF_ISSUES_DIR = workshop/issues
WF_HISTORY_DIR = workshop/history

# Public checkouts use product targets without the maintainer overlay. After
# bootstrap clones peers, the sibling fallback supplies the first weave.
.DEFAULT_GOAL := help
WF_WORKFLOW := $(firstword $(wildcard Makefile.workflow ../ariadne/Makefile.workflow))
-include $(WF_WORKFLOW)
-include Makefile.local

.PHONY: help
help: $(WF_HELP_TARGETS)
	@true
