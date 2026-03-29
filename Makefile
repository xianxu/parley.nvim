# Canonical repo name from git remote (portable across worktrees and containers)
REPO_NAME := $(shell git remote get-url origin 2>/dev/null | sed 's|.*/||; s|\.git$$||')

# Assemble sub-Makefiles
include Makefile.parley
include Makefile.workflow
-include .openshell/Makefile

.PHONY: help

help: help-parley help-workflow help-sandbox
	@true
