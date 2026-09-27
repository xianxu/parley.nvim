---
id: '000014'
status: done
created: 2026-03-29
updated: 2026-03-29
actual_hours: N/A
---

# make worktree workflow work in openshell

## Problem

we want to make worktree based workflow work well in openshell. we need to do the following.

1/ verify the portability aspects of Makefiles, make sure the repo name is used for customization, not the directory name of the repo root in local system.

2/ mount the directory openshell is started in as /{repo-name}, currently it's /sandbox.

3/ mount the ../worktree in openshell as /worktree. make ../worktree/ directory if it is not there.

4/ update worktree related commands, such as `make issue 42`, `make worktree NAME`, to use ../worktree convention, so that it works in both local and in openshell. 

5/ the goal is to achieve portability of all make targets between local mac environment and openshell environment. propose what additional things we need to do
