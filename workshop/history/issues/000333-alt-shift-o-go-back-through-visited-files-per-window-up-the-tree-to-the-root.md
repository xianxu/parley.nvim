---
id: 000333
status: done
deps: []
github_issue:
created: 2026-10-15
updated: 2026-10-15
estimate_hours:
card_mirror: '85becc067d78c612736ef964e54debd4c2ec1c58' # card fields mirrored from issue-cards; edit via sdlc
started: 2026-10-15T11:08:10-07:00
claimant:
    operator: Xian Xu
    machine: 4716879978a7b90f6b583da1716fd0e9
    machine_name: Xian’s MacBook Pro
    workspace: parley.nvim:1
    worktree: /Users/xianxu/workspace/worktree/parley.nvim-slot1/parley.nvim
    repository: github.com/xianxu/parley.nvim
flow: {kind: full, provenance: inferred}
actual_hours: N/A
---

# Alt+Shift+O: go back through visited files (per window), up the tree to the root

## Problem

The universal-agent-input-interface project (ops `teams/devinfra/projects/universal-agent-input-interface/`) turns
markdown files into a connected tree: the session file → an answer or side doc → a link inside it → … The operator
navigates down with Alt+o (parley#327) and needs to come back **up the tree, file by file, to the root** (e.g. the
session file). `Ctrl-o` walks every cursor position, so it takes many presses per file; `Ctrl-^` toggles only between
two files; `:bp` follows buffer-list order, not visit order.

## Spec

- **Alt+Shift+O** (`<M-O>`): go back to the previous **file** in this window's visit history, skipping same-file jumps,
  restoring that file's last cursor position. Repeated presses walk further back, up to the root.
- The history is per window, ordered by visit, collapsing consecutive visits to the same file; it records files
  entered by any means (Alt+o, `gf`, `:e`, a picker).
- Going back then visiting a new file truncates the forward part (like a browser).
- Optional and cheap: a forward counterpart, if one is free (otherwise none).

## Done when

- Headless tests: session file → answer (Alt+o) → side doc (Alt+o), moving around inside each; two Alt+Shift+O presses
  land back on the session file at its previous cursor; same-file jumps don't count; history is per window.
- README documents the key.
- A new split inherits its parent history independently; Back reaches the session file from the split.

## Plan

- [x] Implement and unit-test the pure bounded history transition model.
- [x] Wire the per-window event adapter, FileBack command, registry/config mapping and real-key integration tests.
- [x] Update README, runtime-generated help and atlas; run targeted and full tests.

## Log

### 2026-10-15
- 2026-10-15: closed — actuals unmeasurable: shared sdlc rejects a Qoder subagent transcript, ariadne#391; correct after it lands. Precise no-actual waiver authorized by ops:0 delivery c1416143-8aea-4cef-b7c2-d63ee8f6bcf3; no other waivers. Integrated main 6121476a (#327) in 8ecf9864; conflict resolution retains main reference_generation/OpenFileUnderCursor implementation plus independent FileBack command. All 433 test files pass including Alt+o and file-history navigation; vocabulary and range whitespace pass. No behavior change to reviewed #333 core. (fixed-then-ship; full suite: make test exit 0: 433 passing files, lint 0 warnings/errors in 732 files, clean unit/integration process censuses; /tmp/parley-333-integrated-full-retry.log. Unchanged code retry after one starter lock-test failure; isolated 19 cases also pass.); review verdict: SHIP
- 2026-10-15: closed — BR-2 correction: make test exit 0, 430 passing files, lint 0 warnings/errors in 728 files, clean unit/integration censuses (/tmp/parley-333-sync-full.log). ui/keybindings and focused 28-case adapter plus lookup guard pass. Serial old-adapter run fails no-yield API-to-two-Lua-edits traversal; restored synchronous adapter passes (/tmp/parley-333-order-red-valid.log, /tmp/parley-333-order-restored.log). Removed all deferred initialization and suppression. API creation starts EMPTY; synchronous BufEnter or Back begins history, documented in README/atlas. Native focused splits/tabs remain strict. Vocabulary and range whitespace pass.; review verdict: SHIP
- 2026-10-15: flow upgraded quick → full — 201 added lines in code files (limit 100); an earlier round of this close already ran the full review

## Revisions

### 2026-10-15 — proposed implementation design

Use an explicit per-window file-visit history, not a filtered jumplist (which
cannot guarantee picker/API buffer switches). Detailed plan:
[000333-file-history-plan.md](../plans/000333-file-history-plan.md).
Proposed clarifications for TL approval: normal editing windows only; all named
normal file buffers, regardless of filetype; scratch/help/terminal/floating
buffers are not visits. Keep at most 200 visits per window, evicting the oldest
when full; no disk persistence. Each new split starts its own history.
Back at the first retained file is a quiet no-op. Missing, unloaded files are
skipped; a loaded buffer remains navigable even if its file was deleted.
A refused switch (e.g. unsaved text with hidden off) keeps the current file and
history position so the operator can save and retry. A successful Back never
appends itself as a new visit. No forward key in this slice.

Acceptance additions: verify all four entry paths (Alt+o, gf, edit, picker-like
buffer switch), n/i mappings, independent split histories, transient buffers,
forward-tail truncation, missing targets, safe switch refusal, cursor clamping,
window cleanup, repeated setup, configured keys, help and disabled mappings.

### 2026-10-15 — planning log

- Verified the ops:0 dispatch receipt, claimed #333 in parley.nvim:1, and
  started the issue branch through SDLC after its dependency catch-up.
- Read the owning ops project and design. This navigation slice has no
  dependency on the agentic-document registry or side-document protocol.

## Revisions

### 2026-10-15 — TL approval and split inheritance

Approved by ops:0 delivery 499f2cb2-4d7a-42df-80e9-06b6c25d9175,
including the 200-visit limit. Supersedes fresh split histories: a new split
inherits a copy of its parent window's history, then evolves independently,
so Back can still reach the session file. Capture the source on WinLeave and
copy its immutable model state when WinNew creates the child; cover a split
showing the same file and a split opening a new file. A tab opened from a
window follows the same inheritance when Neovim creates its window.

Insert-mode Back bypasses the global registry's stopinsert wrapper using an
entry-specific preserve_insert flag; other entries keep the current behavior.
Native probes confirm buffer switching itself preserves Insert mode. The help
surface is generated at runtime from the registry; no static help file or
help-generator script exists, so assert the generated help lines directly.

### 2026-10-15 — initial implementation evidence

- Model delegation: 7 pure cases pass, including independent branches from a
  shared immutable split snapshot. Integration baseline: 11 expected failures
  before the adapter/command/key; after wiring, 10 pass and Insert typing fails.
- Tracing proved prep_md exits Insert and drains typeahead during Back's native
  BufEnter. It now honors the adapter's synchronous restoration scope. All 11
  integration cases pass, including linked session/answer/side-doc traversal,
  split inheritance, source/gf/picker entries, native refusal and deleted targets.
- Added queued repeated Back, root Insert typing, new-tab inheritance and
  split-close coverage. Running the complete keybinding mapping next.

### 2026-10-15 — split-source and mode regression evidence

- Full ui/keybindings mapping passed. Added an inactive API split case and saw
  it inherit the wrong previous window. Native tracing shows WinNew runs in
  the child even without WinLeave in the source; track the focused source via
  WinEnter and snapshot it at creation. All 15 integration cases then pass.
- Reverting only preserve_insert makes both actual typed-key regressions fail
  (successful Back and root no-op); restored it before final verification.
- Checklist bookkeeping now ends at test verification; close, merge and staging
  are subsequent SDLC operations recorded by their actual outcomes, rather than
  marking them complete before the close gate runs. Approved scope is unchanged.

### 2026-10-15 — full-suite architecture finding

The first full suite exited 2 with one failing file: buffer_lookup_spec rejected
bufnr(path). All file-history integration cases passed; no test processes survived.
Reused helper.buffer_for(path, true) for both loaded eligibility and switching
(ARCH-DRY), retaining an added deleted-file/loaded-backup case as coverage.
That case also passes before the change on this Neovim; the architecture guard
is the demonstrated red/green regression. The full keybinding mapping and focused
16-case adapter plus architecture-guard run pass after the correction. Rerunning
the full suite before close; scope and approved behavior are unchanged.

### 2026-10-15 — final verification

make test exited 0 after admission, with 430 passing test files, zero lint
warnings/errors across 728 files, and clean unit/integration process censuses.
Both file-history specs and buffer_lookup_spec pass in that full run. Evidence:
/tmp/parley-333-full-final.log. make check-vocabulary and the committed-range
git diff --check pass. The complete ui/keybindings mapping also passes after
the exact-name lookup correction. Implementation checklist is complete;
entering the mandatory SDLC close review, then merge and stage on SHIP.

### 2026-10-15 — boundary review BR-1 and parent-identification revision

Round 1 returned REWORK: the focused-source assumption fails an explicit API
split of an unfocused parent. Eight new real-editor regressions (four directions,
active/inactive child) reproduce it. No landing has occurred. Native probes by
an independent agent show that equalalways can make different parents produce
identical WinNew layout/geometry/clone state; get_config.split describes position,
not requested direction. Native-state inference cannot guarantee actual parentage.
Asked the hub to choose explicit Lua API argument capture with documented RPC
limitations versus a narrowed split contract; implementation waits on that choice.
The previously passing full-suite result applies to the reviewed head, not a BR-1
fix. Preserve the red regressions and review sidecars as the recovery checkpoint.

### 2026-10-15 — approved focused-command inheritance

TL delivery 0071ffce-140a-4b7b-a704-4752bce09148 narrows split inheritance and
rejects core API wrapping. Supersedes the universal parent-copy acceptance above:
focused native split/tab commands (including Parley's openers) inherit the source
history; other creations start fresh. Use the immediate WinLeave→WinNew event
sequence, consumed once and cleared on WinEnter. API calls create the child
before leaving the source and therefore start fresh, even with a focused parent;
this observable boundary was reported back to the hub. The first displayed file
is the new root. Keep native focused-source inheritance strict and adjust the
eight unfocused API regressions to assert no inherited Back target.

### 2026-10-15 — narrowed BR-1 correction evidence

The narrowed contract first produced nine expected failures against the old
adapter. Replaced focus reuse with a consumed native departure token; API births
start fresh. Suppress API creation-time observations until one guarded scheduled
seed sees the final buffer; WinClosed or immediate Back cancels that token.
The expanded ui/keybindings mapping passes, as do 27 focused adapter cases and
the exact-name architecture guard. Tests retain strict native split/tab inheritance,
cover eight unfocused API directions/activation cases, focused API creation,
identical-file parent ambiguity, temporary clones and close-before-seed.
Removing only creation suppression makes the final-buffer case fail; restored
and confirmed 27/27 green. README/atlas describe the narrowed contract. Full
verification and boundary re-review remain pending on this correction.

### 2026-10-15 — narrowed implementation full verification

make test exited 0 on d2ad0a00: all 430 test files pass, lint has zero
warnings/errors in 728 files, and both process censuses are clean. Evidence:
/tmp/parley-333-narrow-full.log. The expanded adapter's 27 cases and buffer lookup
guard pass in that run. make check-vocabulary and range whitespace checks pass.
Re-entering the SDLC boundary review for BR-1 against the TL-approved narrowing.

### 2026-10-15 — BR-2 initialization ordering correction

Round 2 disposes BR-1 but finds deferred suppression drops legitimate visits
before the scheduled callback. Removed pending state and scheduling entirely.
Fresh API WinEnter clones do not seed history; BufEnter records synchronously,
and Back can establish the current file as root. An API creation reusing its
buffer remains EMPTY until BufEnter or Back; README/atlas now state this precise
boundary instead of the implementation's stronger creation-root promise.
Native focused-source inheritance remains unchanged. No real file-entry event
after creation is suppressed (ARCH-ORDER).

Expanded sequence coverage includes API creation then two Lua edits and Back
without yielding, immediate Back, native splitting, and closure. The old adapter
fails exactly the no-yield sequence; restoring the synchronous adapter yields
28 passing cases plus the lookup guard. ui/keybindings passes. One initial red
attempt was invalidated by overlapping test runs and is excluded as evidence;
the serial red/green rerun is /tmp/parley-333-order-{red-valid,restored}.log.
Full verification and boundary re-review are pending on this correction.

### 2026-10-15 — synchronous correction full verification

make test exited 0 on 1fd0e752: 430 passing test files, zero lint warnings/errors
in 728 files, and clean unit/integration process censuses. Evidence:
/tmp/parley-333-sync-full.log. The file-history adapter including the no-yield
sequence passes within that run. Vocabulary freshness and committed-range
whitespace checks pass. Re-entering SDLC review for BR-2 with no deferred state.

### 2026-10-15 — SHIP and main integration checkpoint

Round 3 returns SHIP with BR-1/BR-2 addressed and no new findings. The reviewer
independently verified the no-yield red/green regression. Merge then encountered
newly landed #327 at main 6121476a. Resolved the init.lua conflict by keeping
main's reference_generation/OpenFileUnderCursor implementation and adding the
independent FileBack command immediately before it. Integration commit 8ecf9864.

Integrated full test run exited 2: 432 files pass, only starter_config_spec fails
its competing welcome-creator case with the lock-owner repair error. Starter
production/test files are unchanged in the integration; isolated rerun passes
all 19 cases (/tmp/parley-333-starter-isolated.log). Clean process census; all
navigation tests pass. Retrying full suite on the unchanged integrated code
(/tmp/parley-333-integrated-full-retry.log). After a pass, run the required narrow
conflict review with --fixed-then-ship and --full-suite evidence, then merge/stage.

### 2026-10-15 — integrated full retry passes

Unchanged integrated code passes make test on retry: exit 0, 433 passing files,
zero lint warnings/errors across 732 files, and clean unit/integration censuses.
starter_config_spec passes in the complete run as well as its isolated 19-case
rerun. Evidence: /tmp/parley-333-integrated-full-retry.log. Vocabulary freshness
and range whitespace checks pass. Entering the required narrow conflict review.

### 2026-10-15 — narrow-review measurement blocker

The required --fixed-then-ship close cannot dispatch its review: actual measurement
reports incomplete Qoder session metadata at
/Users/xianxu/.qoder/projects/-Users-xianxu-workspace-pair/6d3388c7-e99a-4311-96b6-5d90f35d4067/subagents/agent-aExplore-2bcc142b6679e6be.jsonl.
The gate directs the hub to restore this evidence. Reported it to ops:0; a
subsequent sdlc actual --issue 333 confirms the same blocker. No actuals bypass.
Integrated full suite remains green (433 files); branch/code is checkpointed.
After repair: rerun actual, the narrow conflict close with the recorded full-suite
evidence, sdlc pr/merge, refresh this resting slot by fast-forward, then stage :0.
