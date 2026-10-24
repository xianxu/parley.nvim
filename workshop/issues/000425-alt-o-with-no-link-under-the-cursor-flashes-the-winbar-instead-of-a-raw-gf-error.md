---
id: 000425
status: codecomplete
deps: []
github_issue:
created: 2026-10-23
updated: 2026-10-23
estimate_hours:
collaboration-mode: collaboration
card_mirror: 'ae96c452de8fc5acbbd27a0ac954a5dfcce199d1' # card fields mirrored from issue-cards; edit via sdlc
started: 2026-10-23T12:32:20-07:00
claimant:
    operator: Xian Xu
    machine: 4716879978a7b90f6b583da1716fd0e9
    machine_name: Xian’s MacBook Pro
    workspace: parley.nvim:2
    worktree: /Users/xianxu/workspace/worktree/parley.nvim-slot2/parley.nvim
    repository: github.com/xianxu/parley.nvim
flow: {kind: quick, provenance: inferred, spec: "d464156b", done: "0b48457d"}
actual_hours: 0.29
---

# Alt+o with no link under the cursor flashes the winbar instead of a raw gf error

## Problem

## Spec

**Alt+o on text with no link shows a raw Lua error (operator, 10-23).** Alt+o's fallback (lua/parley/init.lua:5151,
called from :5196) runs `normal gf` on the word under the cursor; when that word isn't a file (e.g. "error"), Vim
raises E447 "Can't find file in path", and it surfaces as an E5108 stack trace with "Press ENTER". Screenshot:
ops `assets/session/2026-10-23.11-27-34.920.jpg`.

Fix: when there's nothing to open under the cursor (no link, no resolvable path), do nothing except a brief visual
cue: **flash the winbar**. If the buffer has no winbar (not Alt+Returned, so not tracked by Couch), show a transient
winbar just for the flash and remove it. No error, no message prompt. A real failure to open an existing link still
reports clearly.

## Done when

- Alt+o on plain text produces no error or prompt and flashes the winbar, with or without an existing winbar (test).
- Alt+o on a valid link or path still opens it (existing tests pass).

## Plan

- [x] Catch only native gf no-target E446/E447 at its owning fallback, with an Alt+o callback; keep direct gf and explicit target errors intact.
- [x] Reuse the shared document_band pulse/layer owner for a quiet same-window cue, temporary bar restoration and Insert-mode restoration (ARCH-DRY, ARCH-ORDER).
- [x] Add red-first native Normal/Insert no-target cases with/without bars, valid path and missing-link controls; verify shared pulse cleanup and override behavior. Recorded suite and close are the remaining workflow gates.

## Log

### 2026-10-23
- 2026-10-23: closed — Round1 REWORK fixes: BR-1 native insertion regressions failed 12/12 before fix (nonzero/EOL/UTF-8 across absent/custom bars); captured cursor restored inside scheduled insertion, startinsert! only at original EOL. BR-2 six pulse interactions failed before fix (queued/active notice x buffer/WinLeave plus reverse arrival); purpose-aware coalescing and leave priority retain single owner. BR-3 README now documents quiet no-target feedback/bar restoration. Final review-green.log: 82/0/0 (renderer32, leave24, native26), clean census; review-lint.log:854 files zero warnings/errors; diff-check clean. Logs /Volumes/TestScratch/parley425.YDVqCr. Prior full suite passed 4a0a48cf; new local-check --pre-close correctly selects suite because trains off/no affected declaration, PENDING on pushed 3f9321f80a8aff88078f4d30f69c04637b8586ed. Pass required before landing; live check awaits hub sequencing, no stage touched. (done-when: contract moved since change-code; judged by the close review); review verdict: SHIP

Root cause: ResolveRefOrGotoFile calls normal! gf without handling native E446/E447. OpenFileUnderCursor catches and rethrows that error, so a normal no-target gesture becomes E5108 and a prompt. Existing document_band owns pulse timers, window layers, restoration proofs and navigation cancellation; reuse that owner instead of an independent notification timer. Alt+o supplies the no-target callback; direct gf retains its native failure behavior. Hub plan posted, proceeding under the quick-flow rule unless objected.

Actions: Alt+o, edit, navigate.

| Internal state | Visible state | Recovery action | Possible loss |
| --- | --- | --- | --- |
| No resolvable target | Brief No file to open bar cue, then original bar | Edit or navigate to a target and retry Alt+o | None |
| Window navigates/closes or bar overridden during pulse | Current window/bar survives; pulse retires | Continue editing/navigation | None |
| Existing explicit reference fails | Existing clear diagnostic | Correct the reference and retry Alt+o | None |

Creates nothing durable: a pulse owns one finite timer and window layer, removed by completion/navigation/window-close. Navigation remains one existing scan; no added per-byte work. The fixed six pulse frames are independent of document length. No storage, registration, fold, or editing behavior changes. ARCH-PURE: no new business model; this is the existing thin UI/command boundary.

### Implementation checkpoint

Native red run /tmp/parley425-red.log reproduced the actual hit-enter mode through the Normal/Insert Alt+o mappings on both missing words and empty text, with builtin notifications intact. A bare-path control initially overasserted that navigation paints nothing; corrected it to forbid only the no-target cue, since a successful navigation legitimately paints breadcrumbs.

The native fallback now handles only E446/E447 when Alt+o supplies its callback. Other native failures still propagate; explicit link errors retain their existing diagnostic. The shared document_band pulse is factored into one owner used by the existing lock-leave reminder and a quiet same-buffer notice. It preserves the lock cell and its exact option-restoration proofs. No notification or independent timer family was introduced.

A first shared run passed32 renderer and18 lock-leave tests, then the new fixture failed to complete: it replaced a live breadcrumb-owned bar and waited for that artificial override to restore. Set breadcrumb.enable=false explicitly for genuine no-bar/custom-bar cases, matching the documented option. The next focused run passed13/0/0; no product timeout change or flake claim. Added a separate state-owned lock-cell control.

Queued-navigation control red: /Volumes/TestScratch/parley425.YDVqCr/navigation-race-red.log,13/1/0 with the buffer identity guard removed, specifically catching a notice painting after enew. Restored the guard; final context and shared targeted runs are in progress. Logs under /Volumes/TestScratch/parley425.YDVqCr. Initial lint found a shadowed pulse name; renamed the shared function start_pulse, final lint pending. Required recorded suite and boundary review remain pending. #428 remains queued; no styling change included here.

### Final targeted verification

The complete context/file_references run found one genuine compatibility failure:669 passed/1 failed in navigation-green.log. Existing open_reference_spec asserts that a selected explicit non-Markdown link's failed native gf still reports the error and restores the source cursor. Limited the no-target callback to fallback without a selected reference; this preserves the existing explicit-link contract rather than weakening that regression.

Final verification after that fix: final-green.log exits0,77/0/0 (open_reference_spec, native no-target14 cases, arrival architecture guards). Other context tests had passed in navigation-green.log; shared-green.log exits0,64/0/0 (renderer32, lock-leave18, native no-target14). Clean process censuses. Final lint-final2.log exits0,854 files/0warnings/errors; git diff-check clean. All logs in /Volumes/TestScratch/parley425.YDVqCr. Native controls retain builtin notifications for no-target gestures and verify subsequent typing, source text/cursor, Normal/Insert mode, temporary/custom bar restoration, retained operator cell, real E37 open failure and direct smart-gf E447 behavior. The queued-navigation control fails without its identity guard and passes with it.

Required recorded suite and close review remain pending. Operator smoke should press Alt+o on a plain word and blank line (Normal and Insert), with a normal state-owned bar and in an untracked/breadcrumb-disabled buffer: brief cue, no prompt, bar returns; then open a real path. Ask the hub to sequence the live check before touching :0.


## Revisions

### 2026-10-23 — Close round 1, preserve no-op position and leave feedback

The recorded suite on4a0a48cf passed (attempt b55f8e0de7d3b4b2ffd06a83b4efba87,7m27s), but close returned REWORK. BR-1 exposes stopinsert moving the insertion position left; cover nonzero positions, EOL and UTF-8 byte boundaries with absent/custom bars, restoring the captured position only on no-target return. BR-2 exposes source-only coalescing between two distinct pulse purposes; cover queued/active notice crossed with buffer/WinLeave departure, and let leave feedback supersede a quiet notice while retaining duplicate-event coalescing. BR-3 requires the README no-target explanation, alongside the atlas. These preserve the existing gesture and reminder contracts, with no additional owner/timer or durable state. New binary pre-close selection will run on the pushed fixes before re-close.

### Close round 1 fixes

Red controls in review-red2.log confirm12/12 nonzero/EOL/UTF-8 insertion cases fail before BR-1's fix, across absent/custom bars. Review fixture syntax was corrected before interpreting this red run; the earlier module-load errors are not defect evidence. Restore the captured cursor inside the scheduled Insert restoration and use startinsert! only for an original EOL insertion. Successful navigation retains its existing restoration path.

BR-2 red controls: priority-red.log exits2,18 passed/6 failed. All four queued/active notice × buffer/window departure cases lose their warning, and both reverse-order cases show quiet feedback cancelling leave feedback. The existing pulse owner now carries purpose; only same-source/same-purpose events coalesce, and a quiet notice cannot displace a leave reminder. No parallel timer or owner added. README now explains the quiet cue and original-bar restoration (BR-3). Final shared/native controls and lint are running; no stage or landing yet.

Final review-fix verification: review-green.log exits0,82/0/0 (renderer32, leave24, native no-target26), clean census. All16 initial review controls and both reverse-priority controls now pass. review-lint.log exits0,854 files/0warnings/errors; git diff-check clean. Next: push, run sdlc local-check run --pre-close on that head, full re-close (REWORK had not finalized), then the hub-sequenced live check before landing.


### 2026-10-24 — SHIP; recorded suite blocked by registered #427

Close round2 returned SHIP, all BR-1/2/3 addressed, evidence commit7e43bea490d4b9387f4ae8d3823d32890b5b11bc. The hub waived an operator stage for #425 (delivery35811c71-0a17-4aad-b19b-946d355210c8); :0 remains untouched and landing waits for passing tests.

Pre-close selector correctly chose suite because trains are off and main has no affected declaration. The full run on3f9321f80a8aff88078f4d30f69c04637b8586ed completed7m25s, only session_sync_native_spec.lua failed: case session-sync native edits undo releases acquisition baseline, redo retakes: watch autosave=true, expected no notices but received Remote view unavailable; reopen the file to retry. Native summary143/1/0, clean census. Exact identity is already registered on open #427. Raw log /Users/xianxu/workspace/parley.nvim/.git/sdlc/test-stats/failed/e4d0be42c9dc1b5f590f98b2f136b726.log SHA2563eb01c540943996bf01c881cdde8119c31b7da1d573b155110a46aa73271e1ac. Recorded outcome is unattributable-failure, not a resumable typed-case failure.

Tried the supported exact-attempt resume. Refusal: resume proof for parent e4d0be42c9dc1b5f590f98b2f136b726 is unavailable: parent is not an ordinary completed resumable suite failure; fix/advance the code and run a suite on a new head. No blind rerun, dummy code advance or waiver attempted. Report this exact refusal to the hub and wait for its guidance on the registered-flake/legacy-attempt gate. #428 remains queued after landing.
