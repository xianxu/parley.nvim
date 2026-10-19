---
id: 000393
status: codecomplete
deps: []
github_issue:
created: 2026-10-18
updated: 2026-10-18
estimate_hours:
collaboration-mode: collaboration
card_mirror: '4ebd9c2ede66d483402428387c28bb53e93f3097' # card fields mirrored from issue-cards; edit via sdlc
started: 2026-10-18T21:11:16-07:00
claimant:
    operator: Xian Xu
    machine: 4716879978a7b90f6b583da1716fd0e9
    machine_name: Xian’s MacBook Pro
    workspace: parley.nvim:1
    worktree: /Users/xianxu/workspace/worktree/parley.nvim-slot1/parley.nvim
    repository: github.com/xianxu/parley.nvim
flow: {kind: quick, provenance: inferred, spec: "f5b376a7", done: "a66fdd31"}
actual_hours: 0.10
---

# spelling: the Blink corrections menu is off by default (underlines stay on)

## Problem

The operator does not use the spelling suggestion menu (chat_spell.blink, on by default: after a 180 ms pause on a misspelled word, Blink opens a corrections menu) and asked (2026-10-18) to disable it by default in parley. Underlines (chat_spell.enable) stay on.

## Spec

Change the default of `chat_spell.blink` from true to false. `enable` (underlines) stays true; `typeahead` stays false. Users who want the menu set `chat_spell = { blink = true }`. Update the config comment, atlas/ui/spell_typeahead.md (default and how to opt in), README if it mentions the default, and the tests that assume the default.

## Done when

- A fresh setup with no chat_spell options shows underlines and opens no corrections menu (test).
- Setting blink = true restores today's menu behavior (existing tests, now opt-in).

## Plan

- [x] Change only the shared Blink default/comment; document the default and explicit opt-in in the existing atlas (ARCH-DRY).
- [x] Red/green bare setup through prep_chat with a ready stateful Blink fake: underlines stay on, no menu; retain opt-in menu behavior coverage. Run mapped tests and architecture guards; schedule the recorded suite for the landing gate.

## Log

### 2026-10-18
- 2026-10-18: closed — 79 mapped spelling cases pass on each Neovim 0.12.5 and stock 0.11.7; 144 architecture/helper cases and lint 805 files clean. Bare setup/prep_chat with ready stateful Blink shows underlines and zero menu requests; explicit blink=true positive control opens corrections. Default and bare-setup assertions fail original config. Atlas default/opt-in updated, README has no default claim. Recorded suite cb7588a68bab3b4b10fa36c1e134718c queued on code-identical d6e05403, mandatory before landing. Hub approved suite/close and smoke in normal use, no :0 staging. (done-when: contract moved since change-code; judged by the close review); review verdict: SHIP

## Revisions

### 2026-10-18 — correct documentation path

The existing spelling atlas is atlas/chat/spell_typeahead.md, not atlas/ui/.
Update that source; README has no spelling-default claim. No new mechanism,
state, actions, resources or growth drivers: only the existing setup default
changes; blink=true opts back into the existing controller and ownership rules.

### 2026-10-18 — default and regression

The default assertion and bare-setup menu-count regression fail the original
config; the explicit blink=true positive control still opens a menu. After the
shared default changes to false, all mapped spelling cases pass. The regression
uses real setup/prep_chat and the existing ready stateful Blink fake through
the production readiness seam, with actual dictionary completions and underlines.
Existing controller and keyboard-conformance tests already explicitly opt in.
README contains no spelling-default claim. Atlas now also accurately notes that
a supplied chat_spell table replaces the defaults, so its opt-in example includes
enable=true. No setup merge behavior changed. Hub approved suite plus close
review, no :0 staging; normal use after the hub's fast-forward/restart is smoke.
Lint: zero warnings/errors across 805 files.

### 2026-10-18 — review overlaps queue

The recorded suite is mandatory before landing, not before review. Scheduled
cb7588a68bab3b4b10fa36c1e134718c on pushed d6e05403 (PR #314); code identical
to this docs-only checkpoint. Close review overlaps the machine queue per the
worker rules. Verification: 79 mapped cases on each of preferred 0.12.5 and
stock 0.11.7; 144 architecture/helper cases, lint 805 files zero warnings/errors,
and git diff --check. No :0 staging, per the hub's explicit approval.

### 2026-10-18 — issue-backed unchanged suite rerun

First recorded suite cb7588a68bab3b4b10fa36c1e134718c failed only
document_registry_spec's queue/deadline case: first Python fake request exceeded
its 1000 ms deadline (queued_ms=0, ran_ms=1000). Preferred-runtime remaining
specs passed; make stopped before compatibility. Log retained under test-stats/
failed, SHA-256 prefix 1fb5f695372b. Registry code/spec are unchanged from main.
The same spec passed 11/11 immediately alone (/tmp/parley-393-registry-alone.log).
Filed unclaimed #394 with the narrow 0.6 s sleep / 1 s deadline evidence. One
unchanged recorded rerun on d6e05403 is permitted by the worker flake rule; a
second unrelated failure will be reported to the hub, not retried again.
