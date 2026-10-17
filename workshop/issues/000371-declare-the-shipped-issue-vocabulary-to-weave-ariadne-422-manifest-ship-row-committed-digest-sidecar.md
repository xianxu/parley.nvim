---
id: 000371
status: open
deps: [ariadne#422]
github_issue:
created: 2026-10-17
updated: 2026-10-17
estimate_hours:
collaboration-mode: collaboration
card_mirror: 'bf2eece3a278182c90588a6e42fd60dce2d66691' # card fields mirrored from issue-cards; edit via sdlc
---

# Declare the shipped issue vocabulary to weave (ariadne#422): manifest ship row, committed digest sidecar

## Problem

parley ships `construct/generated/vocabulary/issue.json` in git on purpose (#208): users install the plugin from GitHub through a plugin manager and never run weave, so the plugin reads its issue vocabulary from the installed tree. A fresh CI checkout has no weave ownership inventory (`construct/generated/weave/` is gitignored), so after any ariadne vocabulary change weave refuses the committed copy as "something weave did not write" and parley's main merge-check goes red (#321, #326, PR 285 after ariadne#415).

## Spec

Adopt ariadne#422's declared shipped outputs, once it lands:
1. Add `internal ship construct/generated/vocabulary/issue.json` to `construct/base.manifest`, with a comment giving the reason (the plugin reads its vocabulary from the installed tree; #208).
2. Un-ignore the digest sidecar weave writes next to it (`!/construct/generated/vocabulary/issue.json.weave-sha256`, beside the existing `!/construct/generated/vocabulary/issue.json`), and commit it together with a freshly regenerated issue.json.
3. Record the reason in the atlas entry for the issue vocabulary.

## Done when

- A cold checkout's merge-check regenerates issue.json after an ariadne vocabulary change instead of refusing it (green CI), and prints the refresh line.
- A hand edit to issue.json is still refused.
- The manifest row, the sidecar and the reason are committed.

## Plan

- [ ]

## Log

### 2026-10-17
