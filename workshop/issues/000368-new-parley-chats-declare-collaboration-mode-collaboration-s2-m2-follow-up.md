---
id: 000368
status: working
deps: []
github_issue:
created: 2026-10-16
updated: 2026-10-17
estimate_hours:
card_mirror: '51d403034f180463887f4ae4ba738691218059f4' # card fields mirrored from issue-cards; edit via sdlc
started: 2026-10-17T01:10:38-07:00
claimant:
    operator: Xian Xu
    machine: 4716879978a7b90f6b583da1716fd0e9
    machine_name: Xian’s MacBook Pro
    workspace: parley.nvim:1
    worktree: /Users/xianxu/workspace/worktree/parley.nvim-slot1/parley.nvim
    repository: github.com/xianxu/parley.nvim
flow: {kind: quick, provenance: inferred, spec: "d50d682c", done: "d1ee8c53"}
---

# New parley chats declare collaboration-mode: collaboration (S2 M2 follow-up)

## Problem

## Spec

From ariadne#415 (S2 M2, the per-type collaboration-mode audit): every ariadne-managed document type now declares a default `collaboration-mode:` in its frontmatter. Parley's chat writer (`workshop/parley` chats) is parley's own document type and is outside ariadne's audit.

New parley chats should carry `collaboration-mode: collaboration` in their frontmatter: answers in place. That is ariadne:2's proposed default; the TL agreed.

Past chats are not migrated (operator decision for S2).

## Done when

- A newly created parley chat has `collaboration-mode: collaboration` in its frontmatter; a test covers the writer.
- Existing chats without the key still open and work unchanged.

## Plan

- [x] Add the declaration to both built-in templates shared by root and child writers (ARCH-DRY).
- [x] Test both writers and template variants; reopen a legacy chat and prove unchanged bytes.
- [x] Run targeted and recorded full-suite checks; close review and landing are the remaining gates.

## Log

### 2026-10-16

### 2026-10-17

Claimed and started from main. Quick scope: template-only declaration, with no reader, migration, custom-template rewrite or new IO mechanism. The existing writers own file creation (ARCH-PURE/DRY); one constant frontmatter line adds bounded bytes per new chat (ARCH-CONSTRAINTS/RETENTION). No external dependency, concurrency, authority or ownership change (ARCH-MOCK/ORDER/SECURE). Root and child writers plus both built-in templates are the consumer enumeration (ARCH-PURPOSE). Plan posted to hub, proceeding under quick-flow authorization.

Focused writer suite: red before implementation (two expected missing-key failures; legacy case passed), then 11/11 green after adding exactly two template lines. Both built-in template variants write the declaration in root and child files. Legacy open preserves buffer and disk lines. Logs: /tmp/parley-368-red.log and /tmp/parley-368-green.log. Diff whitespace check clean. Atlas creation map now records the default.

Lint passed: 0 warnings/errors in 773 files (/tmp/parley-368-lint.log). Recorded full suite started on pushed ba48a3d6, waiting behind healthy holders. TL accepted fix-forward smoke through normal use for this two-line frontmatter change with writer coverage (receipt fc89f179-5e08-4867-8eb2-e1d3071e3738); no staging or separate live check.

Recorded full suite passed on ba48a3d674263710562cbcc5e990aa3a9e5afe84, first attempt: exit 0 in 3m33s, log SHA256 prefix 9e64beea81dc, clean process census. Log: .git/sdlc/local-checks/ba48a3d674263710562cbcc5e990aa3a9e5afe84/suite.log. No code changed since that head.
