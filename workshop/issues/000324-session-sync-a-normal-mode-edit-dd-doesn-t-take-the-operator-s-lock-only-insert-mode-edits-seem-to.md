---
id: 000324
status: codecomplete
deps: []
github_issue:
created: 2026-10-14
updated: 2026-10-14
estimate_hours:
card_mirror: '11cb4ffb5ac893ac64583a7f970746a18331edcc' # card fields mirrored from issue-cards; edit via sdlc
started: 2026-10-14T16:45:23-07:00
claimant:
    operator: Xian Xu
    machine: 4716879978a7b90f6b583da1716fd0e9
    machine_name: Xian’s MacBook Pro
    workspace: parley.nvim:2
    worktree: /Users/xianxu/workspace/worktree/parley.nvim-slot2/parley.nvim
    repository: github.com/xianxu/parley.nvim
flow: {kind: quick, provenance: inferred, spec: "1dff2098", done: "cb6b284b"}
actual_hours: 0.83
---

# session-sync: a normal-mode edit (dd) doesn't take the operator's lock; only insert-mode edits seem to

## Problem

2026-10-14, the operator on ops' TL status file: deleting a line with `dd` in normal mode didn't take the operator's turn (no `<file>.lock`), so the agent could still write; edits after entering insert mode do take it. The code intends both: `lua/parley/session_sync.lua` ~488–516 takes the lock on `BufModifiedSet` / `TextChanged` / `TextChangedI` when `s.turn == "free"`, the buffer is modified, the disk turn reads free, and the buffer is a session-sync file. So one of those conditions fails for a normal-mode first edit, e.g. `s.turn` stale after an agent write reloaded the buffer, `TextChanged` not firing until the cursor moves, or `BufModifiedSet` already spent because the buffer was modified earlier.

## Spec

Find which condition fails on a first normal-mode change (`dd`, `x`, `p`, `u`) and fix it so any first edit, in any mode, takes the operator's lock before an agent write can land. Add a headless test per edit kind, including right after an agent write reloaded the buffer.

## Done when

- `dd`, `x`, `p`, `u`, `.`, and Insert edits acquire before the operator's pre-existing immediate auto-save; actual Couch writes refuse with exit 3 under that lock.
- The same first-edit protection works on open, immediately after watcher or checktime reload, and after submit → agent write → reload; temporary YAML damage does not revoke attached identity.
- Clean undo and multi-step undo release silently without submit or owner notification; redo away from disk takes the turn again. Explicit and automatic saves retain the turn until submit.
- Clean release reconciles pending foreign overwrite/deletion through the existing violation protocol: preserve foreign bytes in .clobbered, restore deletion, keep the operator copy/turn, and never overwrite an unkeepable foreign copy.
- Native input tests await complete cross-process payloads (locks, notifications, preserved/restored files); targeted tests, declared full suite, boundary review and operator live-editor confirmation pass before landing.

## Core concepts

| Concept | Kind | Location | Status / invariant |
|---|---|---|---|
| Attached session file / edit callback | INTEGRATION | lua/parley/session_sync.lua M.attach | Modified; YAML edits retain identity, callbacks reacquire before auto-save. |
| Operator turn / native sidecar | INTEGRATION | lua/parley/session_sync.lua write_lock/read_turn | Existing helpers reused; acquire on edit, clean undo releases, submit saves/releases/notifies. |
| Disk reconciliation / violation | INTEGRATION | lua/parley/session_sync.lua disk_changed/violation | Existing helpers reused before every new release; save alone keeps the turn. |

## Plan

- [x] Reproduce with real child-Neovim UI input; cover dd/x/p/u/dot and insert initially and after an agent reload, including edits damaging frontmatter. Record events and guard values; clarify the operator's original edit location with the hub.
- [x] Repair attached-buffer turn reconciliation in the existing callback; add failing regression tests for clean undo, multi-step undo, redo, silent release, and saved-buffer/violation compatibility. Keep race handling and timer cleanup intact (ARCH-DRY, ARCH-STATE, ARCH-FUNERAL).
- [x] Run targeted session-sync tests and the declared full suite, update atlas, obtain the required real-editor check through the hub, then close/review/land on SHIP.

## Log

### 2026-10-14
- 2026-10-14: closed — 97 targeted cases pass: 31 native real-input, 52 integration, 14 unit. Delayed empty-log fixture reproduced three BR-4 failures before the shared complete-payload helper; all positive cross-process waits now use that helper. BR-5 README interaction docs added. Foreign-change guard unchanged from full-suite-passing bce3f188 (2m23s, recorded success); full suite rerunning for final tests/docs head. Precise no-plan-check: TL requested parallel review; final Plan checkbox remains open for suite and mandatory operator live confirmation before merge. No other gates waived.; review verdict: SHIP

- Claimed and started on a fresh main-based branch. Start-plan refreshed the private Ariadne substrate and required a rerun with its rebuilt binary; no product source changed.
- Root-cause probes use a child Neovim with attached headless UI and real nvim_input, not synthetic autocmd dispatch. Body dd acquires, including after agent write/checktime reload. Header ggdd fires TextChanged and BufModifiedSet with modified=true, but M.is_session_sync=false because the edit removed the opening delimiter, so acquisition is skipped. dd then u fires both events with modified=false while the lock remains: callback has acquisition only, no clean-edit release.
- Sent the measured findings and proposed brief plan to the hub; original reported edit location remains unconfirmed. Preserve the distinction rather than claiming the body-only symptom reproduced. Temporary probe scripts: /tmp/parley324-probe.lua, /tmp/parley324-header-probe.lua, /tmp/parley324-reload-probe.lua.

- Real-input red run: 16/19 new cases failed as expected (Normal edits with pre-existing auto-save, damaged YAML, and undo release); Insert acquisition and save retention passed. First implementation exposed :edit! detaching callbacks; measured on_detach in a probe, then made BufReadPost idempotently reattach. No unrelated changes.
- Final targeted verification: make -k test-spec SPEC=modes/session_sync passed 26 native-input cases + 52 existing integration cases + 14 unit cases, with clean process census. Covers initial open, watcher reload, :checktime reload, submit/reload/first dd, undo/redo and multi-step undo, header edits, save retention, existing race/violation scenarios. Lint passed for source and new spec; git diff --check clean.
- Real Couch conformance on an isolated temporary file: headless UI body dd with the operator's immediate auto-save produced holder: operator while modified=false; couch --session-sync write --section 'Operator instructions' then refused with exit 3 ('operator holds the lock'). No operator file changed. Fixture/probe under /tmp/parley324-live-contract/.

- Staged verified implementation on parley.nvim:0 via sdlc stage --build after explicit TL authorization (receipt 85d69085-8a71-4081-b19e-36e22500488e). Pure Lua plugin, no Go build targets/binaries. Restart Neovim to replace existing timers/attachments; reopening a buffer alone does not load the new module.
- TL explicitly requested close review in parallel with full suite/live smoke, while prohibiting landing before operator confirmation. Final Plan checkbox remains open honestly: suite is queued and live-editor confirmation pending. Close uses the precise --no-plan-check acknowledgment for that scheduling; no other gate bypass. Merge remains blocked until both pass.

- Review round 1 fixes: BR-1 reproduced red for pending foreign overwrite/deletion/unkeepable-copy before clean undo (three new failures). The sole release site now calls disk_changed/violation and returns with the lock held; failed/ignored checks retain protection until classification succeeds. Added both undecided-check cases. BR-2's shared readiness helper now waits for complete holder bytes. BR-3's Done when enumerates the full revised contract.
- Revised targeted run: 31 native-input + 52 existing integration + 14 unit cases passed; lint clean. Foreign-violation native tests capture vim.notify so its default long-warning hit-enter UI cannot block the RPC test driver; owner messages/preserved bytes/turn are asserted independently. Added a scheduler sentinel to the undecided-check assertions for final full-suite verification.
- The earlier full suite ran every file and failed only two existing auto-save submit waits (session_sync_spec.lua:329 and :368). Targeted reruns have passed those cases; no cause claimed. Preserved the original recorded failure log at .git/sdlc/local-checks/5e88129b3b1156fd61063567e308a814b7ae37a9/suite.log and added shared failure diagnostics (sent lines, argv, lock, modified) without increasing the timeout, so any recurrence is inspectable.

- Full suite on bce3f188 passed in 2m23s with clean process census and recorded sdlc-local/suite success. Earlier async-submit failures did not recur; their diagnostics remain in the shared helper. Round 2 verified all BR-1/2/3 fixes and raised only BR-4 payload readiness and BR-5 README interaction coverage.
- BR-4 red/green: fake sender now can create an empty log, delay 100 ms, then append. With the old notification waits, all three foreign-change notification cases failed; one shared newline-terminated expected-payload helper now serves lock, submit/violation notification, preserved foreign-file and restored-file waits. Absence checks and synchronous fixture reads are the explicit exclusions. Final mapped run passes 31 native + 52 integration + 14 unit cases; changed test Lua lint clean.
- BR-5: README's existing session-sync paragraph documents first-edit protection, clean undo, redo, and save retention, with the atlas link. No new product command or setting.

- Final automated acceptance: full declared suite on 1297e8d4 passed all 428 spec files in 3m8s, with clean process census; success recorded as sdlc-local/suite (log SHA256 prefix fc4cdc85dff0). Final PR CI green. An earlier run failed unchanged packaging VM state timing (line 131); an isolated run failed the previously observed guest-profile assertion (line 167). No packaging source changed; isolated main-baseline probe at dc5ac559 passed all 17 cases, and the complete suite retry passed. Do not describe the packaging intermittency as fixed.
- Close round 3: SHIP, high confidence; all five findings addressed, zero new findings. Reviewer independently ran 97 mapped cases, mutation-tested payload readiness, checked real Couch exit 3, and passed a full suite with external test scratch. Final review anchor remains unchanged in production code. Fetched main and merged origin/main: already up to date.
- Remaining pre-landing condition: restage the reviewed candidate and obtain explicit operator live-editor confirmation through the TL. Final Plan checkbox deliberately remains open until that confirmation; do not merge before it arrives.

- Operator live acceptance confirmed through TL receipt 7b338471-8790-4661-b7c7-c9fd63fb79f9: "yes, this worked" for the reviewed staged candidate. All pre-landing verification is now complete; TL explicitly instructed landing PR #236, then clearing :0's stage.

## Revisions

- 2026-10-14 — add (operator): **undo back to the lock releases it.** If the operator undoes back to the point where their edit took the lock, the buffer equals the file on disk again (not modified), so release the operator lock without a submit and without telling the owner. Criterion: on TextChanged/BufModifiedSet, `&modified` is false (content matches disk), not an undo-sequence comparison, so redo, retyping the same text, or an undo through several changes all behave. Same autocmd as the first-edit fix, so it belongs in this issue. Test: dd → u releases; dd → x → u → u releases; dd → u → Ctrl-r takes it again.

- 2026-10-14 — root-cause refinement: normal body edits fail with the operator's pre-existing TextChanged auto-save registered before session attachment. Real input ordering is on_lines (modified=true), TextChanged (auto-save first, then lock handler sees modified=false), BufModifiedSet (modified=false). Insert TextChangedI can run before that auto-save. Existing tests manually fire BufModifiedSet before TextChanged and hide the defect. /tmp/parley324-autosave-probe.lua and /tmp/parley324-lines-probe.lua record it.
- 2026-10-14 — proposed delta pending hub approval: acquire in the buffer edit notification before auto-save, keep attached identity through header edits, and reconcile a clean edit only when no save intervened. An unconditional modified=false release after a save would negate the Normal-mode fix and violate #317's existing saved-turn tests; asked the hub to confirm this interpretation.

- Confirmed the live operator configuration read-only at ~/.config/nvim/lua/core/options.lua:48–56: global InsertLeave/TextChanged for *.md immediately writes when modified. Parley's own prep_md is debounced; the regression fixture must reproduce the operator's immediate global callback installed before session attachment. This closes the body-only reproduction gap.

- 2026-10-14 — TL confirmed the original edit was in the body. The operator's exact immediate auto-save configuration reproduces that failure. Live hub peek shows approval of the edit-before-save design and retaining save semantics; implementation is within the dispatch's explicit build/land authorization.
- 2026-10-14 — revised design: attach on_lines to acquire synchronously before TextChanged/auto-save; defer clean-edit reconciliation until modified settles, guarded by the edit's disk-mtime snapshot so saves do not release. Ignore reload notifications as operator edits; retain/reinstall the attachment across reloads and wipeout with the existing lifecycle. Real UI tests install the operator-style global InsertLeave/TextChanged auto-save before attachment. First edit still schedules the existing foreign-write race check.

- 2026-10-14 — TL requested verification ordering change: run the close review while suite/smoke are pending; retain both as mandatory pre-landing conditions. Scope and Done when unchanged.

- 2026-10-14 — review round 1 (BR-1/2/3): enumerate the single clean-release site against foreign overwrite, deletion, and copy-preservation failure; reconcile through disk_changed/violation before release. Await complete lock bytes in the one shared test helper. Expand Done when for all revised behaviors and describe Core concepts with kind/path/status. Stale :0 stage cleared pending fixes. Full suite failed only session_sync_spec.lua in two auto-save submission assertions; keep the failure evidence and investigate independently.

- 2026-10-14 — review round 2: BR-1/2/3 verified addressed (review mutation-tested all five foreign-change cases). BR-4 repeats the complete-payload readiness family: enumerate every positive filesystem wait in the native spec — lock helper; submit notification; overwrite/deletion/unkeepable violation notification; .clobbered preservation; restored original file; resumed undecided-check preservation. Replace all with one payload helper; absence checks remain absence checks. Add a fake-writer delay after empty log creation to keep the reproduced race covered. BR-5: document changed undo/redo/save interaction in README's existing session-sync paragraph.
