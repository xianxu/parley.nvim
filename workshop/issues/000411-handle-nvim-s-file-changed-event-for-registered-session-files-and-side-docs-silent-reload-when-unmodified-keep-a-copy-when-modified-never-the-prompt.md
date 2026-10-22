---
id: 000411
status: working
deps: []
github_issue:
created: 2026-10-21
updated: 2026-10-22
estimate_hours:
collaboration-mode: collaboration
card_mirror: 'a21d1c8e7b6066f565d930077b34f44a2c5c5d05' # card fields mirrored from issue-cards; edit via sdlc
started: 2026-10-22T03:59:29-07:00
claimant:
    operator: Xian Xu
    machine: 4716879978a7b90f6b583da1716fd0e9
    machine_name: Xian’s MacBook Pro
    workspace: parley.nvim:2
    worktree: /Users/xianxu/workspace/worktree/parley.nvim-slot2/parley.nvim
    repository: github.com/xianxu/parley.nvim
---

# Handle nvim's file-changed event for registered session files and side docs: silent reload when unmodified, keep-a-copy when modified, never the prompt

## Problem

## Spec

Operator (10-21, item 14): "can't we disable nvim's warning of disk file changed and handle it, as part of the
locking mechanism on session and side docs?" (answer: ops `session.side/2026-10-21-27-nvim-file-changed.md`).

#404 takes the operator lock on entering insert mode and #408 closes the insert-entry race. What remains is a Couch
or TL write while the operator is only *viewing* a registered session file or side doc: nvim shows its
file-changed prompt. For registered documents, parley handles `FileChangedShell` itself:
- buffer unmodified: reload silently (`v:fcs_choice = "reload"`), cursor and view kept;
- buffer modified (only possible without a confirmed lock, e.g. Couch unreachable): take the existing keep-a-copy
  (clobber-copy) path with its notice, never nvim's prompt;
- unregistered files keep nvim's default behaviour.

## Done when

- A native test: an external write to a registered, unmodified, open document reloads it with no prompt, keeping the
  cursor.
- A modified registered buffer plus an external write keeps the operator's text via the copy path, with no prompt.
- An unregistered file still gets nvim's default handling.

## Plan

- [ ] Integrate main after #408 (PR329) lands; reuse its operator_admission snapshot and existing session_sync attachment. Do not stack on the unlanded branch.
- [ ] Add real embedded-editor FileChangedShell regressions for registered session and registered .side documents: clean reload keeps cursor/view in every showing window; dirty/unavailable-lock writes keep operator text and preserve foreign bytes in the existing .clobbered path with a notice, without the native prompt. Include unregistered Markdown native-default control, late/detached callback, copy-failure safety, and existing autosaved-outstanding protection.
- [ ] Repair only the existing session_sync buffer-local handler if RED demonstrates a gap. Reuse attached s.identity.ID and operator_admission; no new registry lookup/frontmatter parser/global handler. Suppress ask for registered dirty buffers and defer the existing violation/copy path behind attachment/epoch/move/loaded guards, without requiring a confirmed lock. Retain internal s.checking and insert-freshness s.admitting ownership, native read guards and window_views restoration (ARCH-DRY, ARCH-ORDER).
- [ ] Run targeted native/session/admission/lifetime tests serially through make -k, then required recorded suite and close. Update the existing atlas map. Coordinate the operator live check/staging with the hub before landing.

Actions: view, edit, retry preservation, save/submit. Existing admission history remains the sole authority; no new lifecycle state or durable file family is introduced.

| Existing state / failure mode | Visible state | Recovery action | Possible loss |
|---|---|---|---|
| Registered, clean, no outstanding operator delta | Silent disk reload, cursor/view retained | Continue viewing/editing | No operator edits to lose |
| Registered, modified, lock unavailable/unconfirmed | Existing preservation notice; operator text retained, foreign text in .clobbered | Continue editing or save/submit | Existing single-copy retention policy unchanged |
| Held/outstanding operator delta, including autosaved modified=false | Existing copy-first violation behavior | Continue editing or save/submit | Prevents discarding saved-but-unsubmitted operator work |
| Preservation copy fails | Existing could-not-be-kept notice; disk and operator buffer retained separately | Fix copy destination and retry preservation | Unsaved buffer remains vulnerable to editor exit, as today; foreign disk bytes are not overwritten |
| Attachment replaced, moved or unloaded before deferred work | Ignore stale callback | View/edit current attachment | No stale write to another document |
| Unregistered file | Native Neovim behavior | Use native prompt | Native choice remains operator-owned |

Prefer the existing attachment/event owner to a global handler with a second membership probe; global autoread cannot preserve dirty operator text or scope itself to registered files. On clean native reads retain FileChangedShellPost ownership until read completion, and update admission baseline only through #408's existing observe_reload/dispatch path. Preserve #317's outstanding-autosaved exception: modified=false alone is not permission to discard an operator delta.

Cost: one existing handler per attached buffer/event, constant-time policy from attached identity/admission. No new Couch query or background task. Existing copy/write work is linear in document bytes and view capture in showing windows; native-event tests at2/4 writes will count effects to reject duplicate handlers or repeated preservation of one foreign generation. Existing .clobbered creation/overwrite policy and lifetime remain unchanged.

## Log

### 2026-10-21

- 2026-10-22 planning: claimed and start-plan completed from main. First start-plan caught up the sibling Ariadne; its weave refresh regenerated an unrelated workflow SIGPIPE correction, which was inspected and restored to HEAD before the successful retry. No workflow payload is part of #411. Read the exact issue Spec and inspected #408 PR329 read-only while it remains unlanded. Existing gap candidate is the handler's modified-buffer ask branch when no lock/admission history confirms ownership; real native tests must establish reachability before changing it. #407 verified landed/archived separately at7bf23a5523fbbc1076a28bcceaf74b0a05cdca71.
