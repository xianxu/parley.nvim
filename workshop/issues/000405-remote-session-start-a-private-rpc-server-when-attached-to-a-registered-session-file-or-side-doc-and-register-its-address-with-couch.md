---
id: 000405
status: working
deps: []
github_issue:
created: 2026-10-20
updated: 2026-10-22
estimate_hours:
collaboration-mode: collaboration
card_mirror: 'cbb34347f1a9a6077b08104739914f9e687593cf' # card fields mirrored from issue-cards; edit via sdlc
started: 2026-10-22T04:55:52-07:00
claimant:
    operator: Xian Xu
    machine: 4716879978a7b90f6b583da1716fd0e9
    machine_name: Xian’s MacBook Pro
    workspace: parley.nvim:1
    worktree: /Users/xianxu/workspace/worktree/parley.nvim-slot1/parley.nvim
    repository: github.com/xianxu/parley.nvim
---

# remote-session: start a private RPC server when attached to a registered session file or side doc, and register its address with Couch

## Problem

Project remote-session (ops `teams/devinfra/projects/remote-session/`, operator-approved 10-20) makes the phone a
remote view of the live nvim buffer for each hub's session file and side docs. Couch needs to reach the nvim that has
the file open, without the operator starting nvim with special flags.

## Spec

- When parley attaches to a registered session file or side doc, it starts a private RPC server for that nvim
  (`serverstart()` on a per-file socket under a private runtime folder) and registers the address with Couch, the same
  way it reports submits; it unregisters on buffer wipe or nvim exit.
- Plain `nvim session.md` keeps working; no flag.
- If two nvims open the same file, the most recent registration wins and the other is told (parley already warns
  about a second editor on a locked file).
- Related: parley.nvim#404 (take the lock on entering insert mode) is the desktop half of "keyboard shown = locked".

## Done when

- Tests: attach registers an address, wipe and exit unregister, a second nvim supersedes the first; the socket is
  private (0700 folder).

## Plan

- [ ] M1 — endpoint model, private listeners and producer conformance (see [durable plan](../plans/000405-remote-session-endpoint-plan.md)).
- [ ] M2 — attachment lifecycle, outside-pane discovery, native takeover/teardown and real-profile acceptance.

## Log

### 2026-10-20

### 2026-10-22 — claimed and planned against producer prerequisite

Ran tl-worker/help and start-plan. The startup weave refresh changed only a generated CI workflow; restored that refresh delta under the TL's standing instruction, so no workflow/local-gates change is part of #405.

Inspected current admission/move/exit seams and remote-session design. Couch has no existing editor-endpoint API. TL approved pair:6's independently landed pair#758 M1 producer prerequisite, then #405, then the proxy; producer contract is being pinned before any code. TL also confirmed one read-only Markdown-open lookup outside Couch panes, with outside-pane submit unchanged.

The durable plan identifies the pure sole owner, private per-file sockets, exact generation cleanup, notice-before-ack and detach-before-ack races, bounded shutdown, executable fake and real native conformance. No estimate before the full-flow change-code plan-quality gate.

## Revisions

### 2026-10-22 — producer prerequisite and outside-pane discovery

Reason: existing Couch document membership is not an editor endpoint registry, and in-pane admission does not cover a plain terminal nvim open. Delta: pair#758 M1 supplies the shared endpoint contract first; #405 consumes it. Add one read-only lookup on Markdown open outside a Couch pane for RPC discovery; preserve all outside-pane submit behavior. Endpoint authority stays with Couch, listener ownership with Parley.
