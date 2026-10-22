---
id: 000411
status: done
deps: []
github_issue:
created: 2026-10-21
updated: 2026-10-22
estimate_hours:
collaboration-mode: collaboration
card_mirror: 'b737664473e2c7cc90c43542bb4aab92a1b7ec1e' # card fields mirrored from issue-cards; edit via sdlc
started: 2026-10-22T03:59:29-07:00
claimant:
    operator: Xian Xu
    machine: 4716879978a7b90f6b583da1716fd0e9
    machine_name: Xian’s MacBook Pro
    workspace: parley.nvim:2
    worktree: /Users/xianxu/workspace/worktree/parley.nvim-slot2/parley.nvim
    repository: github.com/xianxu/parley.nvim
flow: {kind: quick, provenance: inferred, spec: "f33d115e", done: "54cccc96"}
actual_hours: 0.68
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

- [x] Integrate main after #408 (PR329) lands; reuse its operator_admission snapshot and existing session_sync attachment. Do not stack on the unlanded branch.
- [x] Add real embedded-editor FileChangedShell regressions for registered session and registered .side documents: clean reload keeps cursor/view in every showing window; dirty/unavailable-lock writes keep operator text and preserve foreign bytes in the existing .clobbered path with a notice, without the native prompt. Include unregistered Markdown native-default control, late/detached callback, copy-failure safety, and existing autosaved-outstanding protection.
- [x] Repair only the existing session_sync buffer-local handler if RED demonstrates a gap. Reuse attached s.identity.ID and operator_admission; no new registry lookup/frontmatter parser/global handler. Suppress ask for registered dirty buffers and defer the existing violation/copy path behind attachment/epoch/move/loaded guards, without requiring a confirmed lock. Retain internal s.checking and insert-freshness s.admitting ownership, native read guards and window_views restoration (ARCH-DRY, ARCH-ORDER).
- [x] Run targeted native/session/admission/lifetime tests serially through make -k and update the existing README/atlas map.

Required recorded suite and close are the next workflow gates. Per tl-worker, review may overlap a queued suite; a recorded pass on the final code still precedes staging/landing. The hub stages #411 together with #408 after the operator's Couch includes pair#777; do not stage independently.

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

- 2026-10-22 live check: hub relayed operator PASS (delivery535c1b96-a6a3-4e2d-9284-0a81fae6cc11) on staged588c7cee88d7f2a7b36be295c5fe054be4f2760a. Unmodified buffer reloaded silently, no prompt, cursor kept. With an unsaved operator edit holding the lock, the TL write was refused and nvim showed no prompt; this live check exercised lock refusal, while dirty unconfirmed-lock copy preservation remains covered by native tests. Hub authorized landing. Cleared parley.nvim:0 stage successfully before merge.

- 2026-10-22 final gates: required recorded suite PASSED on cfe4c2049db2f720ac7e9b34242208ac8a37fec4, attempt df937bebcb2b8bc55faf03874170bea4 (lease-970358608), exit0 in298.26s. Log: /Users/xianxu/workspace/parley.nvim/.git/sdlc/local-checks/cfe4c2049db2f720ac7e9b34242208ac8a37fec4/suite.log; SHA256 cc75bff8f43d54f35d76765971b861c86b3d922399ed8858b609bfac881ae5e4. This supersedes the pending-suite note in the close verification. Close round1 SHIP, no findings, evidence commit c1d26e080d49c26bc07d9f5f5a660c799c063e25; PR331 remains open. Holding for hub-owned combined live staging with #408 after pair#777; no independent stage, landing or live acceptance.


- 2026-10-22: closed — Native RED /tmp/parley411-file-change-red.log proves4 ask-branch failures; /tmp/parley411-file-change-history-red.log proves second-generation operator-text replacement at2/4 writes without admission history. Targeted GREEN /tmp/parley411-targeted-green.log passes new native9, existing native142/session72/admission18/lifetime10/owner2. Final native/docs9+4 and lint823 pass; diff-check clean. Existing attached identity, handler, copy effect and operator_admission observed event reused; no new registry query/state owner. Registered dirty pre-attachment history has unknown preimage before preservation clears modified; clean view/unregistered and copy-failure safeguards tested. Required recorded suite explicitly PENDING on cfe4c2049db2f720ac7e9b34242208ac8a37fec4, running in parallel under tl-worker allowance; no waiver, suite pass on final code precedes staging/landing. Hub owns combined live check with #408 after pair#777; no independent stage or live acceptance. (done-when: contract moved since change-code; judged by the close review); review verdict: SHIP
### 2026-10-21

- 2026-10-22 planning: claimed and start-plan completed from main. First start-plan caught up the sibling Ariadne; its weave refresh regenerated an unrelated workflow SIGPIPE correction, which was inspected and restored to HEAD before the successful retry. No workflow payload is part of #411. Read the exact issue Spec and inspected #408 PR329 read-only while it remains unlanded. Existing gap candidate is the handler's modified-buffer ask branch when no lock/admission history confirms ownership; real native tests must establish reachability before changing it. #407 verified landed/archived separately at7bf23a5523fbbc1076a28bcceaf74b0a05cdca71.

- 2026-10-22 approval: hub delivery0c6a859d-4a07-4ced-a583-a543d1993964 approves this quick-flow plan and the autosaved-outstanding exception. Code waits for #408 on main. Hub owns combined staging/live check with #408 after the operator's Couch contains pair#777; this slot will report green without touching :0 independently.

- 2026-10-22 root cause verified after integrating #408 merge84c816668c260b1c3c94d18c73633ffe3b3d2cce and entering quick change-code: a registered buffer already dirty at attachment has no pre-edit admission history, so real checktime selected ask. /tmp/parley411-file-change-red.log fails4 native checks at that exact choice; clean multiwindow and unregistered native-autoread controls pass.
- Removing ask alone was insufficient: preserving the first foreign generation writes the operator buffer and clears modified; without remembered history the second foreign generation reloads over the operator text. /tmp/parley411-file-change-history-red.log reproduces generation2 replacement for both file kinds at2/4 writes. Record the existing dirty fact with unknown preimage through the sole owner's observed event before preservation, retaining history across the save. No direct history-field mutation, lookup or new phase.
- Native evidence also establishes that suppressed handling emits no FileChangedShellPost (dirty post count0); only actual clean reload completes that path. Corrected the test's post-count assumption; no production baseline workaround was added. Notice RED /tmp/parley411-file-change-notice-red.log pins that unconfirmed-lock preservation must not claim the operator held a lock. Existing lock/race wording stays for those actual conditions.
- Targeted GREEN is running for new native file-change cases plus existing operator_admission, sole-owner architecture, session_sync native/integration and agentic lifetime specs. Combined live staging remains hub-owned after pair#777.

## Revisions

### 2026-10-22 — Native evidence pins pre-attachment history

Native RED shows a dirty buffer can reach registration attachment without a pre-edit history witness. The approved copy path itself clears modified, so its dirty fact must reach operator_admission's existing observed event with an unknown preimage before that write. This implements the approved single-owner/copy-first invariant across subsequent generations; no new history state, membership mechanism or durable artifact is introduced. Existing clean, internal-check and move/read ownership remain intact. The notice distinguishes local changes without a lock from an actual held-lock violation.

- Final targeted GREEN: /tmp/parley411-targeted-green.log, make -k temporary map, exit0: new native9/9, existing native142/142, session integration72/72, lifetime10/10, admission18/18 and sole-owner arch2/2. /tmp/parley411-final-native-docs.log rechecks native9/9 (including the unregistered public attach control) and docs4/4. /tmp/parley411-final-lint.log passes823 files,0warnings/errors; diff-check clean. README/atlas and traceability reflect the registered-file event policy. No model change, membership query, watcher or new artifact family. Fresh recorded suite and close will overlap under the explicit tl-worker allowance, with suite pending named in verification; no stage or live acceptance is claimed.
