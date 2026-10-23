---
id: 000418
status: working
deps: []
github_issue:
created: 2026-10-22
updated: 2026-10-23
estimate_hours: 3.61
collaboration-mode: collaboration
card_mirror: '78b88a0c157cc7d0b58450995de6c6218b76b600' # card fields mirrored from issue-cards; edit via sdlc
started: 2026-10-23T00:21:40-07:00
claimant:
    operator: Xian Xu
    machine: 4716879978a7b90f6b583da1716fd0e9
    machine_name: Xian’s MacBook Pro
    workspace: parley.nvim:3
    worktree: /Users/xianxu/workspace/worktree/parley.nvim-slot3/parley.nvim
    repository: github.com/xianxu/parley.nvim
flow: {kind: full, provenance: operator}
---

# First Alt+Return on a file adds or merges the required front matter

## Problem

## Spec

Operator request (10-22): the **first time** the operator presses **Alt+Return** on a file (submitting it to the agent
in the same pair session), parley checks that the file has the front matter a submitted/registered document needs; if
it has none, parley adds it; if it already has front matter, parley **merges** the required fields into it (adding
missing keys, never overwriting or dropping the operator's existing keys or values).

- "Required" is whatever Couch's session-sync registration and the submit path need (today a plain side doc can be
  refused with "is not a session-sync file (frontmatter `type: session-sync`)"); derive the set from that contract,
  don't invent one. Where a value can't be inferred, leave the file unsubmitted and say which key is missing.
- Idempotent: later Alt+Returns on the same file change nothing if the fields are present.
- The front-matter edit is a normal buffer edit (undoable), done before the submit, and saved with the submit.
- Related: parley.nvim#410 (unregistered typed files show "not protected" until the first submit registers them).


**Operator addition (10-22, night):** whenever front matter is filled in for a document (a new session file or side doc, or the first Alt+Return adding missing front matter), it lists **all three mode keys with their default values written out** (`collaboration-mode: discussion`, `presentation-mode: highlight`, `processing-mode: free-form`), as a visible reminder that they can be changed. Merging into existing front matter adds any missing ones the same way and never changes values already set.

## Done when
- New or filled front matter lists all three mode keys with their defaults; existing values are untouched (test).

- Alt+Return on a file with no front matter adds the required fields and submits (test).
- Alt+Return on a file with partial front matter merges the missing fields, keeping existing keys and values exactly
  (test).
- A second Alt+Return makes no front-matter change (test).

## Plan

- [ ] Implement the approved shared [first-submit plan](../plans/000418-first-submit-frontmatter-plan.md), including canonical/legacy readers and additive undoable preparation before save/register/send.
- [ ] Prove this issue's Done-when and #322's separate visible-outcome acceptance on both runtimes, record the required check, obtain the binary-owned close review and complete live acceptance/landing after ariadne#562.

## Log

### 2026-10-22

### 2026-10-23 — claimed and planned with #322

TL dispatch 24886cea-c7ae-4329-a81f-ec5c69c35332 assigns #418 and #322 together, one plan with separate acceptance. Claimed #418 and started this main-based issue branch; #322 was a wontfix duplicate of #332 and is reopened through the status verb under this new assignment. Current `agentic_document` already saves/registers/submits plain named Markdown without front matter; it needs neither `type: session-sync` nor guessed owner metadata. Existing `review_send` outside-Couch path still requires legacy process-instruction, and `presentation.value` still reads only presentation. No implementation has started.

Coordinated with ariadne:5: #562 defines three canonical scalar defaults, optional processing-instruction, component-wise legacy fallback and whole-document multi-selector fill refusal. TL delivery da9d9e00 approves including existing-reader migration here and reserves section comments/typeahead for #419. #562 reference examples are source fixtures, not manifest exports; pinned-provenance copies are approved. Delivery 7106eb75 confirms TL's presentation policy: canonical presence wins; missing/empty/unknown means highlight, unknown warns without refusing. The [shared plan](../plans/000418-first-submit-frontmatter-plan.md) records the visible-state table, ownership, pure/IO split, alternatives, failure/retry tests and proposed interactive header envelope. Plan goes to TL before change-code; landing waits for #562's landed contract and fixtures, never an unlanded stack. ARCH-DRY and ARCH-EVOLVE require shared effective resolution and additive byte-preserving insertion rather than three literal defaults or YAML reserialization.

### 2026-10-23 — design approved; producer landing prerequisite

Authenticated TL approval 7acabe36-c3b8-4c2a-b70f-33d8f62d5788 accepts the shared resolver/insertion design, current save/submit owner, canonical reader migration, preserved legacy intent, atomic multi-mode refusal, warned highlight fallback and 8192-line/1-MiB header bounds. No new cache/watchers. Exact next step: wait for ariadne#562 to land; verify its landed revision, pin the reference fill fixtures/provenance from main, then run change-code before implementation. The hub will schedule live acceptance with the operator on a session document. No runtime/test implementation has begun.

### 2026-10-23 — producer landed; reference fixtures pinned

Authenticated TL delivery a5452e45-2afd-4b84-a9a1-a397a1f26214 confirms ariadne#562 landed and directs fixture pin/change-code. Git resolves its merge as `4f10a45d038acb2324c5a19e74a78f4a593571e6`, proven ancestor of freshly fetched producer main. Copied all 24 source files across eight editorial-fill cases into `tests/fixtures/editorial_fill/`; `provenance.json` records repository, exact commit, source path, byte length and SHA256 for each immutable oracle. Every copied byte digest verified against that pinned Git blob. These are source reference fixtures, not export-manifest members or an executable producer resolver. Next: full-flow change-code plan-quality gate, then its estimate gate before runtime implementation. No test/runtime code has changed.

### 2026-10-23 — plan-quality round 1 refinement

The gate recorded PQ-1 (owned-edit-operation-validity) and PQ-2 (function-test-strategy). Verified PQ-1 against production: on_lines dispatches changed while busy, and document_session cancels save, so the original inside-save insertion would strand its own submit. The plan now specifies one witnessed preparation stage before ordinary save on the same model operation, recognizing only its exact before/after edit and retaining invalidation for unrelated edits/reload/detach. No observer mute flag or second owner. Added named function strategies with generated malformed metadata and deterministic real-observer interruption coverage, replacing test inventories. This design delta is pending TL approval before rerunning change-code; no runtime code has started. TL b47c8af9 confirms mixed per-span presentation is #419, and pair:9 has been told.


### 2026-10-23 — implementation checkpoint after accepted revised plan

Authenticated TL delivery 464b8701-86f6-4d63-92fe-4a8d7893b928 approved the exact before/after preparation witness and instructed rerunning change-code. Full-flow change-code passed: plan-quality CLEAN, derived estimate 3.61 hours accepted with nonblocking INFO about optimistic native/live verification allocation. Accepted design is committed. The pure resolver/filler now passes its first four cases after the expected missing-module RED: pinned eight producer cases, generated presentation precedence, unknown metadata preservation and atomic invalid-header refusal. This is partial implementation, not completion evidence. The helper's pure lifecycle run passed 55 cases on both supported runtimes; it is extending the compact projection payload and running native observer integration. Its active files are intentionally excluded from this checkpoint.

Recovery gap: previous TTY capture is unavailable. Git branch, this Log, gate ledger and the current diff establish the resumed state. Next: finish native exact-edit preparation, migrate whole-document presentation/local-review readers, extend malformed/limit/growth and interruption coverage, then run the required recorded check and close review. Live acceptance still needs the hub-scheduled operator session-document check. Authenticated pair:9 schema notice 7f759ac0-0451-4860-82a6-e2589d0103fc is reserved for #419: optional per-span presentation direct/highlight/propose, absent falls back to round presentation then highlight; #418 remains whole-document.


### 2026-10-23 — witnessed native preparation and reader migration

Native preparation now executes through the existing operation and real on_lines observer: compact projection, exact path/changedtick/preimage/postimage proof, one authorized insertion, then ordinary save. The helper's combined check passed 9 native and 57 model cases on Neovim 0.12.5 and 0.11.7 with clean terminal process censuses. Parent review verified the model keeps only the compact insertion/settings, not full document/header/routing snapshots. Presentation canonical precedence passed 13 unit cases; local/default/canonical review and route protections passed 23 integration cases; edit-round warned highlight fallback passed 10 cases. These targeted passes precede remaining generated-property/compatibility work and are not final suite evidence.

A complete-header budget test exposed that the opening fence's four bytes were omitted. Input and projected output now both honor 8192 lines / 1 MiB, including fences, while large bodies remain accepted. Six pure settings cases including N/2N counted VM work are green. The source export snapshot was refreshed through the normal generator from landed producer main (no fixture/API invention). Next: finish adversarial and legacy fixture adaptations, verify both runtimes and protocol/lint, checkpoint/push and run the required recorded suite; then binary-owned close review and hub-scheduled live acceptance. No PR/landing has been requested yet.


### 2026-10-23 — generated properties and compatibility checkpoint

Generated settings coverage is now 13 cases: component-wise precedence, selector exact/prefix/ambiguity, quoting/comments, duplicate relevant keys, malformed roots, multi-mode readability/atomic refusal, case consistency, complete-header bounds and counted linear work. The case matrix exposed a real inconsistency: header presence normalized key case but collaboration reading matched exact case; matching now uses the same normalized identity. Property RED was 12 pass/1 fail, then all 13 passed. Export refresh is exactly generator-reproducible; its standalone test now expects the landed schema v3, and all 25 Python export tests pass. Shipped-mode assertions were updated for v3's retired deletions flag, preserving v2 synthetic compatibility tests. make lint passed all 834 files with zero warnings/errors.

Preferred mapped review now exits 0. Preferred mapped session-sync found only four stale owned-move fixture row assumptions; all four were corrected to locate body headings without weakening race/lock/journal/tree assertions, and the complete owned-move target passed 43 cases. Earlier admission/lifetime adaptation passed 48 + 10 cases. Alternate-runtime mapped review/session-sync and architecture guards remain queued/running, as do two disposable in-memory mutation-control runs (no product source edits). Exact next step: collect those results, resolve any genuine failure, commit/push final verified code and run the required recorded suite, then close review/live acceptance. This checkpoint contains implementation plus its tested focused evidence; it does not claim final acceptance.


### 2026-10-23 — live acceptance scheduled; preflight findings classified

Authenticated TL cf318a62-ca13-4e62-b37f-b2d03c2b918b schedules the operator's morning check (plain file, partial header, second press; submissions to ops:0) and says to keep the runner. PR 338 is pushed; sdlc stage --build staged code head 9a5967f4768a181522ba89fa2ddfaf5d746750a7 on parley.nvim:0, with no Go build required. Recorded suite lease-3834505791 is retained, initially FIFO position 9, on that code head. No live submission was sent by the worker. Receipt 76e808d0-3824-4f72-9dcd-d4b4156df640 for the waiting/live report is submitted.

The final mapped session-sync run additionally exposed typed session fixture disk reads at fixed body indices; the earlier checkpoint's four owned-move failures were only the initial observed subset, not the final mapped result. These test-only corrections are underway with body-heading lookup and retained admission/lock/disk invariants; runtime code is unchanged. Architecture preflight requires exact exported API names in the Core-concepts tables: added the eight implemented functions to their existing plan ownership inventory. Both findings mean the eventual required record must cover the corrected test/plan head; keep the existing queued runner until the hub decides the transition.

Disposable in-memory mutations used the same 13-case pure test suite without editing product source: removing the multi-mode refusal yielded 11 pass/2 fail/0 errors, and ignoring canonical presentation yielded 11 pass/2 fail/0 errors. These are expected mutation-control failures. The ordinary baseline was 13 pass/0 fail. Next: finish the typed fixture check on both runtimes, collect architecture green, checkpoint/push the concrete test-only correction and coordinate replacing the obsolete queued check with the hub, then await live acceptance and complete close/landing.


### 2026-10-23 — final preflight correction ready

Typed session fixture corrections passed the entire 72-case session_sync_spec on both supported runtimes (0 failures/errors, clean censuses). Architecture guards passed after the API inventory documentation fix: arrival budget, buffer mutation boundary and single-source sweep all green. No runtime code changed after staged/pushed 9a5967f4; these are test expectations plus plan/docs only. The earlier queued suite still targets the obsolete test/plan snapshot and will require replacement with a corrected-head record; the TL explicitly asked to retain it, so cancellation waits for coordinated instruction rather than silently losing its FIFO place.

Authenticated TL c11c266d and peer 4b48ceb7 request future #419 fixture agreement. Confirmed directly to pair:9: optional Span.presentation direct/highlight/propose, missing → Round.presentation → highlight; explicit per-span values survive review-records/resume. Requested mixed/top-level-only/no-level source-document fixtures and mixed record/resume round-trip, with hash/expected-value evidence. No #419 implementation or claim starts here, and #418 scope remains whole-document.


### 2026-10-23 — corrected-head recorded suite retained

Authenticated TL 41f07631-c60d-4d03-bc58-134d69f74711 approved cancelling the obsolete queued lease and one replacement on dbb3cd1e. Supported cancel completed for lease-3834505791 without running a suite or recording a result. New recorded suite lease-2976986650 targets pushed dbb3cd1ecd768872f18f1644a91c40ee171d534e; terminal session 28887 is retained. It initialized in /Volumes/TestScratch/local-checks/sdlc-local-1286120678 with raw log /Users/xianxu/workspace/parley.nvim/.git/sdlc/test-stats/inflight/781b67e502e28036977da46605addba4/run.log, initially FIFO position 7. Do not cancel/requeue for a wait or restart while it is live. Later Log-only commits do not change the tested code/tests.

Current targeted evidence: modes/review completes 19 files with no failures on each runtime; architecture preflight completes all three files; typed session_sync_spec completes 72 cases on each runtime after the final correction. Ordinary settings baseline is 13/0, each of two deliberate mutants is 11/2/0. Native/model exact-observer preparation is 9 + 57 passing on each runtime. Admission/lifetime 48 + 10 and owned-move 43 passed preferred; alternate mapped session-sync passed those files, with only the now-corrected typed fixture assertions failing. Full recorded-suite proof remains pending, not green.

Exact next step: collect session 28887's completed result on dbb3cd1e (or confirm that exact live lease after recovery), classify every failure before any retry, and receive the hub's morning live acceptance for plain/partial/second press. Then finish plan/issue acceptance ticks and run the binary-owned closes for #418 and #322, PR/merge gates and final report. Do not claim SHIP or land before those remaining requirements. Stage remains held on parley.nvim:0 at unchanged runtime code 9a5967f4 for the scheduled operator check; clear through sdlc after acceptance unless landing handles it.


### 2026-10-23 — future #419 fixture handoff recorded

Authenticated peer delivery 1045ba73-849b-47ca-9c76-b190bcaf4722 reports the agreed #823 fixture at cmd/internal/sessionsync/testdata/editorial-rounds/presentation.json, with mixed explicit/absent span policies, both legacy fallbacks, document/result hashes and positions, expected effective values, opaque metadata and review-record/resume consistency. Git resolves the reported producer commit to 4619aee1f0aaad327101110fb401c09b61e8c27d. This is an unlanded handoff reference only: future #419 must wait for pair:9's landed revision before pinning, with no stack/runtime dependency here. #418 scope and staged code remain unchanged. The retained recorded suite is still live on dbb3cd1e and has advanced to FIFO position 4; no suite result or operator live acceptance has arrived. Keep session 28887/lease-2976986650 and the existing next-step instructions above.


### 2026-10-23 — recorded suite completed red; attention fixture diagnosis

Retained session 28887 finished: recorded suite on dbb3cd1e failed exit 2 after 2m36s execution. Immutable attempt 781b67e502e28036977da46605addba4 retains /Users/xianxu/workspace/parley.nvim/.git/sdlc/test-stats/failed/781b67e502e28036977da46605addba4.log, SHA256 prefix e59c2fb8c3aa. The runner classified its unstructured summary as unattributable-failure; the complete log identifies exactly one failed file, attention_record_spec.lua, with two cases: records two pending IDs with the real breadcrumb seam, and with the unavailable breadcrumb seam. Both first submits succeed; second edit overwrites the new closing fence at old fixed row 8, then fill visibly refuses unclosed frontmatter. This is a deterministic test-fixture defect, not flake evidence. All remaining unit/integration files in that execution passed and both censuses were clean; the test command stopped before its later compatibility pass.

Next: reproduce the two cases in a focused run, target the fixture body heading instead of row 8 while preserving pending-ID/breadcrumb assertions, prove the full spec on both runtimes, then commit/push and run one new recorded suite on that corrected head. Do not resume/register a flake or blindly rerun the failed old head. Live acceptance remains pending; staged runtime is unchanged.

Authenticated peer delivery 76f8ce1c-b33f-4994-b60b-e50ce62b53a0 supersedes the future #419 fixture handoff revision with Git-verified dcef993baf17ff93db5b6b2410661cc45f87cb51 (PR557), same presentation.json path. Peer reports actual minimal proposals, narrowed valid spans/digests and resume occurrences, no schema change. Pin only after its landing; no runtime dependency on that branch.


### 2026-10-23 — attention fixture correction verified

Focused reproduction confirmed the same two deterministic failures (11 pass, 2 fail, 0 errors). The fixture edit helper now finds its ## Needs you body heading before editing the following row, retaining both pending message-ID and breadcrumb assertions. The complete attention_record_spec then passed 13/13 on Neovim 0.12.5 and 0.11.7, with zero failures/errors and clean censuses. Its luacheck and diff whitespace checks pass. No runtime code changed. Commit/push this test correction and one fresh recorded suite; the earlier failed attempt stays immutable and is not mislabeled a flake. Live acceptance and close/landing remain outstanding.

## Revisions

### 2026-10-23 — canonical fill and current registration contract

Required submission metadata is the current registry contract, which does not require a type/owner header. The explicit new settings are collaboration-mode: discussion, presentation-mode: highlight and processing-mode: free-form when no current or legacy choice exists. Missing components materialize effective legacy choices instead of shadowing them; preserve existing canonical/alias lines, unknown metadata and body. Optional processing-instruction is filled only from legacy free text. Existing-reader migration is included so these keys work. Section comments, typeahead and external side-doc/session writers remain with #419/#562 as coordinated. Each issue keeps its own Done-when; one plan/branch is the TL's explicit combined-work exception.

## Estimate

Produced via `brain/data/life/42shots/velocity/estimate-logic-v3.1.md` against `baseline-v3.1.md`. Method A only. The calibration is marked stale by sdlc, so this is provisional. Three focused Lua primitives cover pure header/settings projection, the witnessed native preparation lifecycle, and migration of existing local-review/presentation consumers; each includes its pure/native tests and both-runtime verification. Pick the Lua table's midpoint design 2h, discounted x0.2 by the approved concrete plan to 0.4h, and upper implementation 1.5h scaled x0.40 to 0.6h. Existing LuaJIT/Neovim, selectors, provenance editor and persistent fake registry are the library substrate; no novel stack or general YAML dependency is introduced. Docs use 0.1h design x0.2 and 0.15h implementation x0.4; one atomic review uses 0.1h design x0.2 and 0.4h implementation x0.4. A 0.4h real-API discovery allocation x0.4 covers the hub-scheduled operator session-document conformance. Familiarity is 1.0 and the thorough-plan design buffer is 15%. This combined implementation is budgeted here; do not duplicate its implementation hours on #322's separate acceptance record.

```estimate
model: estimate-logic-v3.1
familiarity: 1.0
item: lua-neovim design=0.4 impl=0.6
item: lua-neovim design=0.4 impl=0.6
item: lua-neovim design=0.4 impl=0.6
item: atlas-docs design=0.02 impl=0.06
item: milestone-review design=0.02 impl=0.16
item: real-api-discovery design=0 impl=0.16
design-buffer: 0.15
total: 3.61
```
