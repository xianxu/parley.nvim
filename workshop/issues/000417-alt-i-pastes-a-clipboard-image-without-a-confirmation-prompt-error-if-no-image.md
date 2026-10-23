---
id: 000417
status: codecomplete
deps: []
github_issue:
created: 2026-10-22
updated: 2026-10-22
estimate_hours:
collaboration-mode: collaboration
card_mirror: 'f9ebc23c7752cdf9eb755ecb8bb378ef7d59aa26' # card fields mirrored from issue-cards; edit via sdlc
started: 2026-10-22T18:01:39-07:00
claimant:
    operator: Xian Xu
    machine: 4716879978a7b90f6b583da1716fd0e9
    machine_name: Xian’s MacBook Pro
    workspace: parley.nvim:1
    worktree: /Users/xianxu/workspace/worktree/parley.nvim-slot1/parley.nvim
    repository: github.com/xianxu/parley.nvim
flow: {kind: quick, provenance: inferred, spec: "6c748c2d", done: "8119f216"}
actual_hours: 0.86
---

# Alt+i pastes a clipboard image without a confirmation prompt; error if no image

## Problem

## Spec

Operator request (10-22): **Alt+i** (paste the clipboard image as an attachment, #231/#377) currently asks for
confirmation in the Vim command line before inserting. Drop the confirmation: if the clipboard holds an image, insert
it immediately; if it doesn't, show a clear one-line error ("No image in the clipboard") and change nothing.

- Applies in Normal and Insert mode, as today.
- Any naming or placement the confirmation used to let the operator choose falls back to the existing default.
- README and atlas updated.

## Done when

- Alt+i with an image in the clipboard inserts it with no prompt (test with a fake clipboard).
- Alt+i with no image shows the error and leaves the buffer unchanged (test).

## Plan

- [x] Reproduce the prompt with a native UI and fake clipboard. The async save path currently has no explicit confirmation; guard against builtin notification hit-enter as well as input/confirm dialogs.
- [x] Keep existing default attachment naming, placement, writer/shrink and rollback (ARCH-DRY). Remove the paste completion's blocking feedback; emit one-line error `No image in the clipboard` for no-image, with buffer/disk unchanged.
- [x] Cover Normal/Insert mappings, image bytes, no prompt and absent-image no mutation through the existing fake and native UI on both supported Neovim versions. Update README/atlas.
Publication follows the recorded suite and the SDLC close/merge gates; it is not an implementation checkbox.


## Log

### 2026-10-22
- 2026-10-22: closed — BR-1 fixed by one fixed success notice with complete diagnostics in the Parley log. BR-2 adds real Alt+i text/no-image cases in Normal and Insert: exact builtin ERROR notice, unchanged buffer and assets, no hit-enter and ordinary next typing. Attachment mapping 504PASS/0FAIL/0ERROR on each nvim0.12.5 and0.11.7 with clean censuses; luacheck3files and diff check clean. Corrected-head recorded suite queued separately; no suite pass or landing claimed. Shutdown hold forbids a new merge. (done-when: contract moved since change-code; judged by the close review); review verdict: SHIP

### 2026-10-22 — quick-flow design

The existing clipboard-to-assets path does not call a confirmation dialog; its full-path success notice can trigger builtin hit-enter UI. First reproduce this through a real attached native UI instead of deleting an imaginary naming prompt. No new state, dependency or save protocol; existing terminal cleanup and shrink/error diagnostics remain authoritative (ARCH-PURPOSE/DRY). Posted the bounded plan to the hub, proceeding unless it objects.

## Revisions

### 2026-10-22 — observed prompt is builtin hit-enter

Native attached-UI reproduction and TL/operator confirmation identify the long success message as Neovim's hit-enter, not a naming/confirmation dialog. Keep the async save and default naming; shorten completion to `Image pasted` plus existing shrink diagnostics. No-image becomes the exact one-line error. No new state, save protocol or UI interception.

### 2026-10-22 — targeted verification

RED native UI tests on0.12.5 independently observed Normal/Insert become mode `r` after `Parley: pasted assets/...`; the no-image contract also failed as expected (3 intended failures total, /tmp/parley-417-native-mode-red.log). Fast nvim_get_mode observes the prompt; Enter is sent only after recording failure for inspection/teardown. GREEN native tests keep builtin notify, assert correct bytes/default link and prove subsequent ordinary typing reaches the buffer. Attachment mapping:492PASS/0FAIL/0ERROR on each nvim0.12.5 and0.11.7, clean censuses (/Volumes/TestScratch/parley-417-green-final.log and -green-0117.log). One stale PNG-extension notice assertion was corrected after the initial green attempt; no product fix was hidden by a retry. Lint0warnings/0errors3files; diff check clean. README/atlas and lesson updated. No recorded full-suite pass, close or landing claimed yet.

### 2026-10-22 — review-ready checkpoint

Implementation and targeted verification are complete at fdb9808f953b4fb35ef6945d39e500ccd114a9d7 (PR337). Publication remains conditional on the recorded suite, boundary review and merge gates; removed the self-referential close/land checkbox rather than ticking future work as done. The attached-UI matrix is the operator-confirmed reproduction surface; no live :0 stage performed.

### 2026-10-22 — BR-1 presentation revision approved

R1 is REWORK with Critical BR-1, family paste-completion-must-not-block-input: the shared success emission still appended shrink notes, so retained-original successes reproduced mode r on both n/i. The class enumeration is all3 note sources in image_shrink.shrink (conversion-limit admission, converter resolution/configuration, converter execution/output) plus ordinary successful conversion sizes. Reopened completion/coverage checkboxes until that matrix is green.

TL5a199558 approves one short one-line summary for every successful paste, with full shrink diagnostics and sizes silently retained in :messages and a short notice pointing there. Keep one policy at the existing success emission, no new UI, queue or state. Qualify native message-history capture semantics and quote/newline safety on both supported versions; :silent echomsg is not assumed to preserve history. Add native note-source/mode coverage red first, then implement. Update the atlas guarantee to match actual presentation.

Cancelled only superseded recorded suite lease-3257249525 on ff795ebb through sdlc (attempt1fed1f57ba59ba07475c9bffce1e6593); it is not passing evidence. The fixed code gets a new pushed-head recorded suite and another close review.

### 2026-10-22 — history-only API limitation; log policy approved

Native experiments found no tested supported core history-only path: verbose echo displays, capture suppresses history, unsilent restores history and hit-enter on both versions. No global option, UI interception or fake input was added. TLd1e1c466 chooses the existing Parley log instead of :messages: every success has one fixed short summary naming that log; full path/diagnostics/sizes use logger.debug, which writes without scheduling a notification. `:ParleyInspectLog` already opens the log. The native matrix and recording tests are updated to read explicit private per-spec log files. This supersedes the earlier :messages presentation only; all note producers remain in this round's coverage.

### 2026-10-22 — BR-1 correction verified

Claim BR-1 addressed: the one success emission now always uses fixed `Image pasted; details in the Parley log`. Existing logger.debug records the full relative asset path plus the unchanged outcome suffix without scheduling a notification; `:ParleyInspectLog` opens it. No history API, global option, UI interception or synthetic input in production. No-image remains the exact error with unchanged buffer and assets.

The12 real attached-UI scenarios (small, conversion-limit, missing converter, malformed recipe, bad converter output and successful JPEG conversion, each n/i) preserve builtin notifications, assert full path/reasons/exact before→after sizes from private per-test log files and verify subsequent ordinary typing. All note cases were RED mode r on both versions before the fix. GREEN attachment mapping502PASS/0FAIL/0ERROR on each nvim0.12.5 and0.11.7, clean censuses (parley-417-br1-green.log and -green-0117.log). Lint3files and diff check clean. Initial API probe sources were removed; only the permanent regressions ship. New recorded suite and R2 close remain pending; cancelled R1 suite is not passing evidence.

### 2026-10-22 — R2 coverage correction and shutdown checkpoint

R2 on 0761a9dc disposed BR-1 as addressed and returned FIX-THEN-SHIP, but close did not finalize because Important BR-2 (mode-specific-contract-coverage) remained open. Added the missing two native Alt+i text/no-image mapping cases, one Normal and one Insert, preserving builtin notify while observing completion. They assert the exact one-line error and ERROR severity, no prompt or mode departure, identical buffer bytes/modified state, no assets directory, and subsequent ordinary typing. No product behavior changed.

The resulting14 native cases and complete attachment mapping pass on nvim0.12.5 and0.11.7:504PASS/0FAIL/0ERROR each, clean censuses (parley-417-br2-green.log and -green-0117.log under /Volumes/TestScratch). The superseded recorded suite on0761a9dc was cancelled only by exact owned lease-235135071 (attempt ccfccda4caa69e51a32b9d17faeda2a6); terminal completion confirms cancellation, not passing evidence.

TL shutdown directive7c6fdbf9 forbids new merges/landings tonight. Next: push this coverage correction, queue its recorded suite, rerun plain close to dispose BR-2 (R2 was not finalized), and push review evidence. Do not start a merge. Before shutdown retain exact suite run/head and review outcome here; after the authenticated restart/lift inspect that run through sdlc, resume only missing work, and land only after the hold is lifted and every gate passes. #405 remains paused for pair#801's landed pin, with its two known architecture-test corrections still pending on its own branch.

### 2026-10-22 18:38 PDT — durable shutdown handoff

R3 close returned SHIP, high confidence: BR-1 and BR-2 addressed; zero new findings and zero open blocking findings. The reviewer independently passed the attachment mapping on both supported versions and mutation-tested the old no-image behavior (exactly two native failures per version). Close published codecomplete, evidence commit76ffa8a736bf26cdf6c098a8974a2dfcf528ee4f; mirror e2e203704f2e562598e97045ba51c70832d06bdb.

Recorded suite is still queued on tested code head f405d52460d1cf18c8699a9a98c951f2d0208e47: lease-579331086, attempt08b73ebebab2c324c06d3e92910a7040, detached checkout /Volumes/TestScratch/local-checks/sdlc-local-3238069172, log /Users/xianxu/workspace/parley.nvim/.git/sdlc/test-stats/inflight/08b73ebebab2c324c06d3e92910a7040/run.log. Live terminal93337; FIFO position9 last observed. No duplicate runner and no passing full-suite result claimed. Close and this handoff add documentation/evidence only.

Exact next action: inspect that lease/attempt and its final result through sdlc local-check/queue status after restart; retain it if live or completed, restart the same unchanged head only if gone. A real branch defect requires a fix and new suite; known-flake-only failure uses sdlc local-check resume. Do not start sdlc merge while TL7c6fdbf9's shutdown hold remains. Once explicitly lifted and the recorded suite is green, enter sdlc merge --yes for PR337, then report the Git-verified merge to the hub. No :0 stage or operator editor reload has been requested or performed.

### 2026-10-22 — restart recovery and lifted freeze

Recovered attempt08b73ebebab2c324c06d3e92910a7040 from the durable attempt record and GitHub exact-head status: suite PASSED on f405d52460d1cf18c8699a9a98c951f2d0208e47, exit0,295.789s (4m56s), log SHA2565b7efc2281365466c1f92e0a34e11681a63fc0b052a87bf1a5508e2453d9d67a. No suite rerun needed for recovery; SHIP close remains finalized, PR337 is open.

TL57e6ba32 explicitly lifted the freeze after the completed shutdown. Go reports1.27.3. Rebuilding this slot's ariadne tools before merge, while continuing to invoke ariadne:0's sdlc. Initial queue inspection reported helper inspect exit2; recheck after rebuild and report if it persists. Next: sdlc merge --yes after the rebuild/queue check; its integration owns current main and any required fresh suite. #405 follows this landing, pinned to pair#801 merge b5c1cb99260fa8131b48092e4601c2ac86abf5d7, with its two known architecture-test corrections before final acceptance.
