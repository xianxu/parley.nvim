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

- Reproduce: open `session.md` with MarkdownPreview running, write the file from outside (session-sync style), and
  check whether the preview server's refresh hits a buffer or page it doesn't know (the error comes from the
  markdown-preview server's `refreshPage` on an undefined client or page).
- Find whether parley (or its session-sync reload path) triggers the preview refresh for a buffer whose preview page
  isn't registered (for example after an external reload or the path change), and fix it so the preview keeps
  updating, or at least never throws.

## Done when

- A regression reproduces the TypeError before the fix and passes after; the operator's preview of session.md and a
  side doc updates live after an external write.

## Plan

- [x] Trace the installed preview server and reproduce the reported failure with Parley absent.
- [ ] Resolve the upstream startup/port-allocation scope with the hub before implementation.
- [ ] Add the red regression, fix the owning boundary, verify external rewrites for parent/side docs, then review and land.

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
