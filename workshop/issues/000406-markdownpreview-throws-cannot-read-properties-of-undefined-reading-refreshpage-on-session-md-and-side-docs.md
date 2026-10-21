---
id: 000406
status: working
deps: []
github_issue:
created: 2026-10-20
updated: 2026-10-20
estimate_hours:
collaboration-mode: collaboration
card_mirror: 'cd70d74c34cc984bdf3e9bb124004998de1f6998' # card fields mirrored from issue-cards; edit via sdlc
started: 2026-10-20T21:34:42-07:00
claimant:
    operator: Xian Xu
    machine: 4716879978a7b90f6b583da1716fd0e9
    machine_name: Xian’s MacBook Pro
    workspace: parley.nvim:1
    worktree: /Users/xianxu/workspace/worktree/parley.nvim-slot1/parley.nvim
    repository: github.com/xianxu/parley.nvim
flow: {kind: quick, provenance: inferred, spec: "099d29a7", done: "1db194ec"}
---

# MarkdownPreview throws 'Cannot read properties of undefined (reading refreshPage)' on session.md and side docs

## Problem

On 10-20 at 21:33 the operator's MarkdownPreview stopped working on the hub session file and side docs (in
`~/workspace/ops/session.md` and `session.side/*.md`), with the error in the nvim message line:
`TypeError: Cannot read properties of undefined (reading 'refreshPage')`. Screenshot:
`ops/assets/session/2026-10-20.21-33-40.545.png`. Those files are written frequently from outside nvim (Couch
session-sync writes by the TL), and they moved today from `teams/devinfra/tl-status-*.md` to the repo root
(`session.md`, `session.side/`, ariadne#504). parley.nvim also had several landings today.

## Spec

The initial missing-page/reload hypothesis is superseded by the confirmed bind
failure (Revision below). Pin the shipped starter's MarkdownPreview port to
18999 (confirmed free on this machine), with a comment naming the Syncthing
8384 collision. Document how to change it if occupied. The operator's separate
Neovim configuration remains theirs; the hub coordinates that update. No fork,
third-party plugin edits, or Parley/session-sync reload changes (ARCH-PURPOSE).

## Done when

- A starter startup regression fails without the fixed-port setting and passes
  after it; existing preview lazy/localhost settings stay intact.
- Preserve the Parley-free TypeError reproduction and verify that the real
  preview server on a free fixed port delivers external parent/side-doc edits.
- Suite, close review and landing complete; operator config work stays with the hub.

## Plan

- [x] Trace the installed preview server and reproduce the reported failure with Parley absent.
- [x] Resolve scope with the hub: configuration in the shipped starter, no fork.
- [x] Add a red startup port regression; set the fixed port and troubleshooting note; verify real preview external rewrites and architecture/docs guards.
- [ ] Queue the recorded suite on the pushed head.

Landing gates: recorded suite pass, close review, then merge and report to the
hub. Review may overlap a queued suite under the worker contract.

## Log

### 2026-10-20

### 2026-10-20 — initiating failure located

The operator's preview log at
/Volumes/TestScratch/tmp/ops-slot0/mkdp-nvim.log starts at 14:12:48 with
`listen EADDRINUSE: address already in use 127.0.0.1:8384` (PID 95851).
The same process then reports openBrowser/refreshPage TypeErrors through
the operator's report at 21:33. Installed MarkdownPreview's app/server.js
chooses 8080 plus the last three timestamp digits when mkdp_port is empty.
Only its successful listen callback initializes the application object;
app/nvim.js catches the bind exception without ending the RPC process.
Later cursor refreshes dereference an application that never initialized.
The error is not an absent page: refreshPage already tolerates no clients.

A disposable Neovim 0.11.7, loading only the installed MarkdownPreview
plugin (no Parley), reproduced both EADDRINUSE and the exact refreshPage
TypeError with a Python-owned occupied localhost port, an external rewrite,
checktime and preview_refresh. Evidence/script:
/Volumes/TestScratch/tmp/parley.nvim-slot1/parley-406-repro-yayoiu5j/.
No operator files, installed plugin files or processes were changed.

Asked the hub to revise scope to the preview dependency startup/port owner
(ARCH-PURPOSE), rather than hide refresh errors in Parley's reload. Proposed
kernel-assigned default port, bind-failure shutdown and startup-notification
readiness coverage; delivery path and operator plugin update await decision.
Restarting Neovim may pick a free port and restore service immediately, but
is not the durable fix.

## Revisions

### 2026-10-20 — confirmed collision; configuration-only disposition

The hub confirmed Syncthing owns 127.0.0.1:8384 and approved a configuration-only
fix in packaging/starter-config/init.lua (Couch delivery
6424c96b-68c3-4bd5-af4a-97691bfef023). editor_dependencies.lua is a pure payload
registry, not configuration. Replace the initial Spec/Done-when's page-registration
assumption with the confirmed cause and starter-config regression above. No
startup state machine or dependency fork. A fixed port can still be occupied;
explicitly document choosing a different free port and restarting Neovim.

### 2026-10-20 — red/green and real dependency check

The bootstrap regression failed before the config edit (expected 18999, got
nil), with the other 20 cases passing. After adding the fixed port, all 21
bootstrap cases pass. Existing lazy loading, localhost-only and auto-start-off
assertions remain exercised. Architecture/documentation/arch-helper guards
passed, lint reports zero warnings/errors across 818 files, and diff-check is
clean. The fixed port was verified free by a real bind before testing.

A disposable installed Neovim 0.11.7 loaded the actual pinned MarkdownPreview
plugin/server with port 18999 and a browser callback that captured the URL
instead of opening a window. A real HTTP Socket.IO polling client received
initial contents and then updated contents for both session.md and
session.side/discussion.md after external disk writes, native checktime and
CursorMoved. No TypeError/EADDRINUSE appeared. The check used only scratch
files, no live documents, provider credentials or operator config. Script and
evidence live beside the reproduction (live.py / live.log).

Review/landing are recorded as acceptance gates outside implementation checkboxes
so they can overlap the recorded suite queue without claiming a pending pass.
The operator's separate config remains with the hub as approved.
