# Canonical repo name from git remote (portable across worktrees and containers)
REPO_NAME := $(shell git remote get-url origin 2>/dev/null | sed 's|.*/||; s|\.git$$||')

# This project nests issues and history under workshop/
WF_ISSUES_DIR = workshop/issues
WF_HISTORY_DIR = workshop/history

# Assemble sub-Makefiles (Makefile.workflow already includes .openshell/Makefile)
include Makefile.workflow
-include Makefile.local

.PHONY: help

# help-sandbox and help-tart are defined by .openshell/Makefile and
# .tart/Makefile, both included via Makefile.workflow's -include lines.
# Every consumer that vendors the ariadne base layer ships both
# fragments (see construct/base.manifest), so these targets always
# resolve. If a consumer ever drops .openshell or .tart from its
# manifest, the corresponding help-X line would need to come out.
help: help-workflow help-sandbox help-tart
	@true
