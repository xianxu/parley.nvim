---
id: 000313
status: working
deps: []
github_issue:
created: 2026-10-10
updated: 2026-10-10
estimate_hours:
card_mirror: '76b4d4a05fb7c9623bdfbf1cb6322de837bcef75' # card fields mirrored from issue-cards; edit via sdlc
started: 2026-10-10T12:19:59-07:00
claimant:
    operator: Xian Xu
    machine: 4716879978a7b90f6b583da1716fd0e9
    machine_name: MacBook Pro
    workspace: parley.nvim:2
    worktree: /Users/xianxu/workspace/worktree/parley.nvim-slot2/parley.nvim
    repository: github.com/xianxu/parley.nvim
flow: {kind: quick, provenance: inferred, spec: "2343b3eb", done: "fa54cbda"}
---

# session-sync markdown: Alt+Return submits to the owning agent via couch, with a turn lock

## Problem

The ops TL keeps a live status file for the operator's right pane (`ops/teams/devinfra/tl-status-<operator>.md`): "Needs you" first, one section per thread. The operator comments on it with inline `🤖[…]` markers, which the TL resolves (the `xx-fix` convention). This works (first used 10-10), but two things are missing:
- **No submit gesture.** The operator has to switch to the TL's chat to say "ready". Watching the file instead would act on half-written comments.
- **No turn-taking.** The TL rewrites the file as threads change. If it writes while the operator is mid-comment, one side's edits get clobbered or confused.

Today `<M-CR>` in a markdown buffer is the document-review action (`lua/parley/init.lua:3056`, `parley.skills.review`). Parley already auto-saves markdown 1s after `TextChanged` / `InsertLeave` (`init.lua:1796`), but not during insert mode.

## Spec

A markdown file whose frontmatter has `type: session-sync` is a turn-based shared file between the operator and an agent:

```yaml
type: session-sync
owner: ops:0        # couch address of the agent that keeps it
operator: xian-xu
```

1. **Dispatch on type.** In a `session-sync` buffer, `<M-CR>` submits to the owner instead of running the review action. Other markdown keeps today's behavior.
2. **The lock.** The agent holds the file by default. On the operator's **first modification** (`TextChangedI` / `BufModifiedSet`, not on save), parley writes a sidecar `<file>.lock` (holder, time), so the lock is taken at the first keystroke. While it exists, the agent never writes the file.
3. **Submit** (`<M-CR>`): save, make the buffer read-only (`nomodifiable`), and run `couch --send-to <owner> --message "submitted: <absolute path>"`. Show the outcome briefly (queued, or the couch error); on a send failure, keep the buffer editable and say so.
4. **Unlock on reply.** The agent replies by rewriting the file and deleting the lock. Parley notices the change on disk (file watch or `checktime`), reloads the buffer, and makes it editable again. A manual unlock key exists for when the agent never replies.
5. **Stale-lock reminder.** If the lock exists and the buffer has been idle for N minutes (default 5) without a submit, show virtual text: "unsent edits: Alt+Return to submit".
6. **The agent side** isn't parley's: the owner diffs the file against its own shadow copy, resolves the markers, writes, and deletes the lock (documented in ops' `xx-tl` draft).

## Revisions

### 2026-10-10 — ownership must be obvious (ops TL, from the operator)
- **Lock names the turn holder:** absent = free; `holder: operator` = the operator's turn; `holder: agent` = the agent's turn (buffer read-only). The first edit writes `holder: operator`; submit rewrites it to `holder: agent`; the agent deletes the lock when done and never writes it. A failed send rewrites it back to `operator`; the manual unlock (`<C-g>u`) does the same. The turn is read from disk, so a buffer reopened during the agent's turn is read-only too.
- **Render the turn:** a window-local `winhighlight` StatusLine colour per state, a lualine component (text + colour), and a winbar label (`free: editing takes your turn` / `your turn, Alt+Return to submit` / `<owner> working, read-only`).
- **Stale reminder** (spec §5) is now the `stale` state: the winbar reads `unsent edits, Alt+Return to submit` in the reminder colour. It replaces the end-of-line virtual text, which would have said the same thing twice.
- Done-when additions: the lock body names the holder at each transition, and each state's winbar/StatusLine/lualine rendering is tested.

### 2026-10-10 — live-check rendering changes (ops TL, from the operator)
- The core flow passed the live check. Rendering: the winbar label spans the full width; the lualine component is removed; the operator's turn is a bright red band (the default-linked DiffAdd green was too subtle), stale is orange.
- Re-check passed; the operator asked for a more subtle red: `#870000` (cterm 88), still white bold text.

## Done when

- In a `session-sync` file, the first keystroke creates `<file>.lock` with `holder: operator`, and `<M-CR>` saves, rewrites the holder to `agent`, sets the buffer read-only and sends one couch message to `owner` (a test with a fake couch on PATH asserts the exact argv). A failed send gives the turn back (`holder: operator`, editable).
- When the lock is deleted after the agent rewrites the file, the buffer reloads and is editable again (test); a file reopened during the agent's turn is read-only (test); `<C-g>u` takes the turn back (test).
- A markdown file without `type: session-sync` still gets the review action on `<M-CR>` (test).
- Each turn renders as a full-width winbar band and a window-local StatusLine colour (free / operator in dark red / stale in orange after the idle threshold / agent), tested with a short threshold; no lualine component.
- A live check with the ops TL: comment on `tl-status-xian-xu.md`, `<M-CR>`, and the TL's reply unlocks it.
- The atlas documents the `session-sync` type, its keys, the lock protocol and the rendering.

## Plan

Durable plan: `workshop/plans/000313-session-sync-submit-plan.md` (single pass, no milestones).

- [x] Pure header parser + lock body (unit spec)
- [x] Controller: attach/lock/submit/poll/unlock/reminder + `<M-CR>` dispatch + `<C-g>u` (integration spec, fake couch)
- [ ] Atlas + traceability; full `make test`; live check with ops TL

## Log

### 2026-10-10
- Implemented `lua/parley/session_sync.lua` + `<M-CR>` dispatch / `<C-g>u` in `setup_markdown_keymaps`; specs `tests/unit/session_sync_spec.lua`, `tests/integration/session_sync_spec.lua` (fake `couch` on PATH asserts the exact argv).
- Discovery: `BufModifiedSet` fires from the main loop on a keystroke (verified mid-insert in headless nvim with real input), never synchronously from `nvim_buf_set_lines`; the spec fires it after an API edit.
- `<C-g>u` is bound in every markdown buffer (registry no-ghost contract, `keybinding_agreement_spec`); it no-ops outside session-sync files.
- Scope fold from ops (see Revisions): holder-named lock, winbar/StatusLine/lualine rendering, stale state replaces the eol virt text.
- Full `make test` green (424 files). One earlier run lost three specs to load-induced 50s deadlines (pass standalone) and exposed a fake-couch argv race, fixed by writing argv atomically.
- Couch sends need the unsandboxed socket; the first, sandboxed send was never delivered (status: not retained) and was resent.
- Live check handed to ops TL (message e2266ec8).
- Live check: core flow confirmed by ops; rendering changes (full-width winbar, no lualine, bright red operator band) made for the re-check.
- Re-check passed (full-width band, red operator turn, round trip). Red darkened to `#870000` per the operator.
