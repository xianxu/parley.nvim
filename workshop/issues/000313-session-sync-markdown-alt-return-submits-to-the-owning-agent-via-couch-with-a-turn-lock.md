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

## Done when

- In a `session-sync` file, the first keystroke creates `<file>.lock`, and `<M-CR>` saves, sets the buffer read-only and sends one couch message to `owner` (a test with a fake couch on PATH asserts the exact argv).
- When the file changes on disk and the lock is gone, the buffer reloads and is editable again (test).
- A markdown file without `type: session-sync` still gets the review action on `<M-CR>` (test).
- The stale-lock reminder appears after the idle threshold (test with a short threshold).
- A live check with the ops TL: comment on `tl-status-xian-xu.md`, `<M-CR>`, and the TL's reply unlocks it.
- The atlas documents the `session-sync` type and its keys.

## Plan

Durable plan: `workshop/plans/000313-session-sync-submit-plan.md` (single pass, no milestones).

- [ ] Pure header parser + lock body (unit spec)
- [ ] Controller: attach/lock/submit/poll/unlock/reminder + `<M-CR>` dispatch + `<C-g>u` (integration spec, fake couch)
- [ ] Atlas + traceability; full `make test`; live check with ops TL

## Log

### 2026-10-10
