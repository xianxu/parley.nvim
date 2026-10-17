---
id: 000373
status: working
deps: []
github_issue:
created: 2026-10-17
updated: 2026-10-17
estimate_hours: 5.53
collaboration-mode: collaboration
card_mirror: '708f77f1bf3631014542da823bc712872d66717a' # card fields mirrored from issue-cards; edit via sdlc
started: 2026-10-17T06:40:08-07:00
claimant:
    operator: Xian Xu
    machine: 4716879978a7b90f6b583da1716fd0e9
    machine_name: Xian’s MacBook Pro
    workspace: parley.nvim:1
    worktree: /Users/xianxu/workspace/worktree/parley.nvim-slot1/parley.nvim
    repository: github.com/xianxu/parley.nvim
flow: {kind: full, provenance: inferred}
---

# side docs S3: on a name change the mover rewrites the parent's links and discussions index, suffixes an orphan .side folder, and passes ariadne's shared move fixtures

## Problem

The S3 design for side docs (ops `teams/devinfra/projects/universal-agent-input-interface/design.side/07-s3-side-docs.md`, final at ops cf0f0ebf, section 6; decisions by the operator, 10-16) needs parley's document mover (parley.nvim#332, `document_move_plan.lua`) to finish what a rename does. Today the mover moves `<name>.side/` with the file, rewrites each side doc's `parent:` and backlinks, and renames Couch's registry entry. A name change (`design.md` → `spec.md`) leaves the parent's own links into `design.side/…` and its `discussions:` index entries pointing at the old folder.

## Spec

- **A name change rewrites the parent's own references.** When the file name changes, the folder becomes `spec.side/`, and the mover rewrites the parent's own links and its `discussions:` frontmatter entries from `design.side/…` to `spec.side/…`, in the same journal as the rest of the move.
- **A taken folder name suffixes the orphan.** When `spec.side/` already exists (an orphan: its document is gone, since a taken `spec.md` stops the move), the orphan is renamed `spec_1.side/` (then `_2`, …), and the moving document takes `spec.side/`, because every tool finds a document's side docs from its file name. The move names where the orphan went. (Operator decision, 07's thread 09.)
- **Shared fixtures.** One set of before/after move fixtures is shared with ariadne's `xx-universal-review` examples checker, carried in the skill's `export.json` (as #319 does), so the two writers can't drift. ariadne's side is ariadne#424.
- **Check:** a side doc opened with Alt+o from an agentic parent is registered with Couch too (design.md's S3 line); today's side docs usually aren't, which is why the agent writes them straight to disk (parley#367's finding).
- Links from other documents into the folder are not rewritten (operator: side docs are local references).

## Done when

- A parley rename that changes the file name keeps the parent's links and its `discussions:` index resolving, with a projection spec.
- A move into a taken `.side/` name suffixes the orphan and reports it, with a spec.
- The projection specs pass the shared fixtures from ariadne's `export.json`.
- Side docs opened with Alt+o from an agentic parent are registered, or the gap is filed with evidence.

## Estimate

*Produced via `brain/data/life/42shots/velocity/estimate-logic-v3.1.md` against `baseline-v3.1.md`. Method A only.* Calibration is marked stale by sdlc; values are provisional.

The producer contract and approved state table resolve design decisions (×0.2 design discount). Implementation values below already apply v3.1's ×0.40 scale to v2 table values. Familiarity 1.0: this extends the existing Lua mover, Python exporter and persistent fake. Library check: existing frontmatter/reference parsers, filesystem no-replace adapter and lease implementation are reused; no novel platform/library integration is assumed.

- Export v2 snapshot: smaller module extension, base design 0.2 → 0.04; base implementation 0.5 → 0.20.
- Parent-reference projection: focused Lua feature, base design 2 → 0.40; base implementation 1.5 → 0.60.
- Pure transition model: greenfield single-concern module, base design 1 → 0.20; base implementation 0.8 → 0.32.
- Journal/recovery integration: focused Lua feature, base design 3 → 0.60; base implementation 1.5 → 0.60.
- Editor synchronization/registration audit: focused Lua feature, base design 2 → 0.40; base implementation 1.5 → 0.60.
- Shared fixture executor: smaller module extension, base design 0.2 → 0.04; base implementation 0.5 → 0.20.
- Two milestone reviews plus final close: 3 × base implementation 0.5 × 0.40 = 0.60.
- Atlas/docs: base design 0.2 × 0.2 = 0.04; base implementation 0.2 × 0.40 = 0.08.
- Issue/design integration: base design 1 × 0.2 = 0.20; base implementation 0.3 × 0.40 = 0.12.

```estimate
model: estimate-logic-v3.1
familiarity: 1.0
item: smaller-go-module design=0.04 impl=0.20
item: lua-neovim design=0.40 impl=0.60
item: greenfield-go-module design=0.20 impl=0.32
item: lua-neovim design=0.60 impl=0.60
item: lua-neovim design=0.40 impl=0.60
item: smaller-go-module design=0.04 impl=0.20
item: milestone-review design=0.00 impl=0.20
item: milestone-review design=0.00 impl=0.20
item: milestone-review design=0.00 impl=0.20
item: atlas-docs design=0.04 impl=0.08
item: issue-spec design=0.20 impl=0.12
design-buffer: 0.15
total: 5.53
```

Design 1.92 × 1.15 + implementation 3.32 = 5.528, rounded 5.53 focused ship-hours. Module slugs are the closed-vocabulary analogues for Python/Lua single-concern modules, not a planned Go port.

## Plan

- [x] M1 — Export v2 fixture snapshot and pure move projection; review via milestone-close.
- [ ] M2 — Recoverable orphan/parent rewrite journal, editor handoff, shared integration fixtures and acceptance; review via milestone-close.

Durable plan: [000373-side-doc-moves-plan.md](../plans/000373-side-doc-moves-plan.md).

## Log

### 2026-10-17
- 2026-10-17: closed M1 — TL authorizes fourth M1 review solely to dispose BR-5 atlas text; no ledger waiver. Atlas fix 2d1c2a26 documents S3 pure observations, effect order, refusals and orphan_destination separately from M2 runtime. Round 3 passed all code findings; descendants of reusable green 714899bf suite (3m28s, log sha256 7283fecc279a) are docs-only. legacy suite attempt a97173e6 lacks exact queue endpoints; excluded from calibration per ariadne#420. Stop for new findings beyond atlas text.; review verdict: SHIP

Planning only, 2026-10-17: claimed and started from current main. Read S3 design section 6 and producer #424 at 5990bf04a5d7cebb58dcf279b19e142ae3f2fe5f; producer confirms unlanded/no PR, fixture role in export v2. Existing mover owns leases/no-replace renames, conservative byte rewrites and forward recovery; new parent rewrite must synchronize loaded buffer and NEW witness before later saves. Read-only explorer confirmed these seams. No implementation or generated snapshot changes; code waits for landed producer and approved full-flow plan.

TL approved the durable plan and policies (receipt 6d2d8e58-b402-4f59-af38-d945acb5c1af, submitted). Waiting for ariadne#424 landing; no code or tests changed.

Producer #424 landed as ariadne PR #284 at 5fa50f084f8062fafb493bec86b8207fc8f5617a, confirmed from Git and peer receipt 933d0b03-27a1-4866-9cc4-5ceec0f1d9a6. Relevant export/fixture/reference files match the planning pin. Proceeding to change-code on the approved plan.

Plan-quality round 1 raised PQ-1 (authoritative transition model) and PQ-2 (function-level strategies). Revised durable plan defines a pure v2 state reducer, one journal dispatcher, and compressed adversarial test contracts. TL approved revision and operator mapping: moving/done/interrupted, one reopen recovery, forward-only witness recovery or safe pre-effect abort; changed/unknown bytes never overwritten. Rerunning change-code, no implementation yet.

Plan-quality round 2 CLEAN: PQ-1/PQ-2 addressed, no new findings. Estimate derived after that approval; change-code will validate/admit it before code.

M1 in progress: exporter v2 snapshot passes 21 Python contracts and two pinned --check runs; projection tests first red (6 missing-feature failures) then green; state tests red on absent module then green. Shared fixtures match and a temporary old-projection negative control fails on occupied destination, restored code passes. Fixture-loader startup initially used package.searchpath (Nvim runtime modules are outside package.path); corrected to harness cwd, stopped that owned failed runner, then green. Scale test on 20KB unmatched brackets found a genuine scanner stall; fixing existing scanner semantics-preservingly before M1 close.

M1 candidate verification: 39 projection cases, 9 state cases (including generated event sequences), 19 reference cases (1208 legacy scanner differential inputs), shared manifest-driven cases byte-for-byte (2 fixture groups in one integration case), 21 Python contracts. Shared old-code negative control failed as expected before restoring current projection. Mapped session-sync: 19 files / 490 cases green. Mapped review: initial single stale lexical assertion failed because imported S3 prose now mentions Couch rename; corrected to test actual excluded adapter heading, then 18 files / 374 cases green. Latest generator --check matches producer merge pin. Lint 779 files clean; diff check clean. Logs /tmp/parley-373-{plan-green,state-green,reference-integrated,shared-green,session-sync,review-green,export-integrated,lint}.log. No full-suite flake/retry.

Estimate-quality was INFO, not blocking: journal/fixture implementation allowances may be tight and discounted design may overcount completed work. Active verification/live/landing work is included in feature/review allowances; machine-queue idle is not implementation effort. Retaining the derived estimate for honest calibration. M2 writer integration and registration audit remain undone.

Recorded M1 suite on bbe6022fb37ff24edbd5e77190ac8c59b1d37ae2 completed normally (run a97173e6d0fbc47a41529cb4bfd524cd, exit 2, 2m21s). Its sole failure was tests/arch/module_reachability_spec.lua: the planned pure document_move_state module had no runtime consumer until M2. This is a reproducible milestone-boundary defect, not restart loss or a flake; retained log is .git/sdlc/test-stats/failed/a97173e6d0fbc47a41529cb4bfd524cd.log in the common Git directory. TL approved shifting the reducer and its unit tests into M2 with the dispatcher (receipt 82d18b04-a8d1-44b8-9056-8a140b0351cc). Their implementation remains recoverable from bbe6022f; removed those two files and their traceability rows from the M1 candidate. No guard waiver or dummy require. Verify the corrected boundary before milestone-close.

Corrected M1 head 49bfc58005ac885e303c594ca4631827203d9246: targeted reachability 2/2 passed with the original guard unchanged. Recorded suite run 68d1790c514142ac8969fa925d97f4dc passed, exit 0 in 4m24s after 502s machine queue; log SHA256 prefix 641c5d30add8, common Git log sdlc/local-checks/49bfc58005ac885e303c594ca4631827203d9246/suite.log. Clean process census. This is verification after the boundary correction, not an unchanged flake retry. Requesting mandatory M1 review; M2 implementation still waits.

M1 milestone-close refused before dispatch: measured actual unavailable because legacy suite attempt a97173e6d0fbc47a41529cb4bfd524cd lacks exact queue endpoints (only queue_seconds present). Asked hub to restore the named measurement evidence, receipt c2aacd57-7736-4996-b987-8d1e5809f00d submitted. No waiver, guessed timestamps, or repeated boundary invocation. Corrected suite attempt has queued_at/acquired_at and remains green. Mandatory review and M2 are still pending.

M1 review round 1 REWORK: BR-1 markdown-code-preservation (Critical), BR-2 output-preflight-before-mutation (Important), BR-3 bounded-reference-scanning (Important). Verified each finding. Red projection run: 39 pass/3 failures for cross-line code preservation and malformed destination scale; fixed exact-width paragraph-wide backtick masking and disjoint malformed destination token scans shared by both rewrite APIs. Expanded green projection: 43 cases, including escaped delimiters, differing run widths, CRLF and paragraph boundaries. Exporter red: 23 Python methods with 21 expected-output type subtest failures, including stale SKILL mutation; green: 23 methods after snapshot-aware regular-file leaf/directory ancestor validation before writes. Logs /tmp/parley-373-review-links-{red,green}.log and /tmp/parley-373-preflight-{red,green}.log. Shared fixture tree and pinned --check still pass. TL authorizes --no-actual for this issue’s legacy queue sample, excluded under ariadne#420 (receipt f90bcd1b-4736-4a58-9c16-b1d3030cc1eb).

Review-fix verification: mapped session-sync 18 files / 486 cases passed; projection 43 cases, shared fixture integration green, pinned sync --check green, lint 777 files with zero warnings/errors, Python 23 contracts green. Recorded full-suite rerun will use the new pushed code head; the earlier pass does not cover these fixes.

Post-review-fix recorded suite 149dbe8d5111d0009477f6dbe32d98b5 on 163672d75f10c87fd1b8454be32948d0ab25ac93 passed: exit 0, 2m39s after 176s queue, log SHA256 prefix dec582f60909; clean process census. BR-1/2/3 fixes now have targeted red/green evidence and a fresh full pass. Re-requesting M1 boundary review with the approved legacy-sample --no-actual exclusion.

M1 review round 2 REWORK: reviewer verified negative controls for BR-1/2/3 and disposed all three as addressed; BR-4 (Critical, markdown-code-preservation) found cross-block backtick pairing that suppresses live rewrites. Red block regression reproduces it. Extracted existing reference_candidates Markdown segmentation into markdown_blocks; wrapped-link scanning and code masks now consume that single rule without changing the scanner dialect. Walls/headings isolate a row, list starts break before and retain their continuation, blank/fenced rows exclude inline syntax. Both rewrite APIs test every supported boundary and valid list/paragraph continuations. Green: 44 projection cases, 20 reference cases (legacy differential inputs retained), both shared trees, lint 777 clean. Logs /tmp/parley-373-blocks-{red,green,references,shared,lint}.log. No M2 code yet.

Shared-block correction recorded suite 60f4170eeb597b338c2d0976e829f3c7 on 714899bfd552645a4a3597e2c331e76ca0f027c9 passed: exit 0 in 3m28s after 1456s queue; log SHA256 prefix 7283fecc279a, clean process census. Re-request M1 review for BR-4 using the single shared block classifier and focused preservation/live-rewrite coverage.

M1 review round 3: FIX-THEN-SHIP; BR-1/2/3/4 all disposed addressed, reviewer independently verified BR-4 negative control. New BR-5 Important architecture-documentation: atlas mapped only fixture export, not pure move observations/results. Added S3 pure projection section to atlas/modes/session_sync.md with parent_bytes, bounded absent-NEW orphan observations, effect order, orphan_destination, preservation/refusal rules and explicit M1/M2 runtime distinction. This is docs-only since the recorded green 714899bf suite. The gate did not finalize because BR-5 remains open despite FIX-THEN-SHIP; asking hub for the finalization path at the three-round cap, not waiving a ledger or starting M2.

TL authorized docs-only milestone-close --fixed-then-ship after round 3, on reusable green 714899bf suite (receipt 8d1c464e-fbc1-49b2-97c8-4fd2342449f0). Installed binary refuses that exact flag before dispatch: unknown flag --fixed-then-ship; milestone help says it exists only on whole-issue close. Reported mismatch to hub (bd0c0fdc-9f47-4717-b107-1d6a61f6159a), requested supported path/binary update. No review or close finalized, no ledger/judge/integrate waiver, no M2 implementation.

M1 finalized SHIP in authorized round 4 at 1e5fcc6dec678dfcd8f798e500403fe043d61ad0. All BR-1..5 disposed addressed, no new findings. No gate ledger waiver. Starting M2: one reducer-driven v2 dispatcher plus parent_rewritten editor handshake; v1 compatibility retained. Read-only preparation confirms Alt+o currently opens a child path then lookup only (no parent-owner registration); M2 will reproduce through real opener/fake and file the allowed unclaimed gap if confirmed. Native saveas must syntax-preflight current buffer text separately from OLD disk; actual NEW raw bytes after write own rewrite hashes. Session move synchronization must not advance an unrelated acquisition baseline or clear an outstanding operator turn.

M2 targeted evidence so far: reducer 9 cases green; dispatcher 48 cases plus single-owner guard 2 and reachability 2 green; session native synchronization 69 cases green (five new cases failed before the API existed). Shared fixtures now exercise the real filesystem and persisted fake registry: 3 cases green, with old M1 mover negative control 1 pass/2 expected failures (missing orphan support and unchanged parent links/index). Direct mover negative control initially 33 pass/5 expected failures. Foreign-temp cleanup red 45 pass/3 preservation failures then green; complete unpublished next-checkpoint recovery passes. Logs /tmp/parley-373-m2-dispatcher-final.log, /tmp/parley-373-session-api-{red,green}.log, /tmp/parley-373-m2-shared-{red,green}.log. Further final-confirmation witness regressions and root editor/recovery integration verification are still in progress; no full M2 suite claimed.

Alt+o required audit completed through real OpenFileUnderCursor/open_buf: registered parent effective owner ops:0, pane actor parley.nvim:1; navigation emitted only child lookup, child stayed plain with null identity/absent registry entry, zero sends. Filed unclaimed #378 on origin with durable sanitized evidence and acceptance criteria, as Done-when permits. Local raw evidence /tmp/parley-373-side-open-gap.log, reproduction /tmp/parley-373-side-open-gap.lua; scratch removed/process census clean.

M2 final direct proofs: 53 mover cases green plus 2 sole-owner guards, after red 48 pass/5 failures covering lost changed effective owner, late unrecorded raw write, bounded initial reducer overflow, and same-byte inode replacement. The complete checkpoint retains the exact confirmed registration; final handoff rechecks raw/stat witness; bounded admission failures release the lease. Latest /tmp/parley-373-m2-final-proofs-{red,green}.log.

Editor integration expanded to 22 cases. New checkpoint-publication failure recovery passed immediately against persisted editor preimage and releases the mechanical synthetic turn. Real BufReadPost edit regression initially failed: move falsely succeeded because Neovim clears modified after the autocmd. Expected editor postimage now comes from the same pure rewrite over normalized buffer lines; a differing reread is marked modified and preserved, and metadata never starts. Intermediate test caught the missing modified flag; final 22/22 passed, clean process census, /tmp/parley-373-m2-owned-{final,reread-green,reread-final}.log. Offline existing recovery now checks the approved v2 interrupted/reopen label. Python exporter 23 tests, producer-pinned sync --check and lint 780 files (zero warnings/errors) passed before the final small editor guard; mapped verification underway.

Mapped session-sync rerun passed 19 files / 533 cases, zero failures, clean process census (/tmp/parley-373-m2-session-map-green.log). Earlier failed mapped attempt retained: two legacy v1 feedback assertions (overdue background and forget-command UI) updated to the approved v2 moving/wait and interrupted/reopen contract; traceability inline comments were interpreted as literal test filenames by the map reader, so removed them. Not a flake retry. Integrated origin/main cleanly before the full suite because the noon freshness gate requires #353's renderer changes; no conflict resolutions were needed. The recorded full suite will verify that integrated candidate.

Recorded full M2 suite queued on pushed eea1accf42a3e8bb2066abb9742ce90a3b5d2c0f, attempt 3bf6a047fb43e8b90f1e02c4d165d9e4 (exec session 11538). Inflight log: common Git sdlc/test-stats/inflight/3bf6a047fb43e8b90f1e02c4d165d9e4/run.log. Queue is advancing; prior holders had actual make test children behind their expected cat holders, so no interference or rerun.

TL authorized the bounded M2 live check once that suite is green (receipt ea719627-18ff-46c6-b636-f3a8d6045453, submitted): stage on parley.nvim:0 briefly, disposable scratch design.md with discussions/link and orphan spec.side, verify retained spec_1.side bytes and rewritten parent, save/reopen stable registry ID, remove scratch files and Couch entries, clear stage, log evidence. Stage dry-run passes; no actual staging yet. Prepared /tmp/parley-373-live-check.lua uses the real profile/runtime and Couch transport, no submission sends; luacheck clean.

First integrated M2 full suite passed on eea1accf42a3e8bb2066abb9742ce90a3b5d2c0f: attempt 3bf6a047fb43e8b90f1e02c4d165d9e4, exit 0 in 2m20s after 2140s queue, log SHA256 prefix b0d48b081b89, clean process census. Staged docs-only descendant cc7eecee60b66ef45b60b67ddebcbc53efdf4d60 on :0. Real profile /Users/xianxu/.config/parley loaded that runtime, then failed before file effects: E976 Blob as String at document_lease.lua:106. PATH nvim is 0.11.7; suite selects 0.12.5 for its newer LuaJIT. Existing NUL-delimited journal-budget namespace reaches a SHA API whose Blob support differs. Cleared :0 to main immediately, forgot the scratch design registration (lookup then confirmed null), removed scratch. No real documents, sends or credentials changed. Failed live evidence retained at /tmp/parley-373-live-evidence.json and /tmp/parley-373-live-check.log.

TL authorized the lease-boundary correction with byte-identical keys plus actual 0.11 coverage (4b20a07a-3975-44a4-8087-b941a0d31569, submitted). Filed unclaimed #379 for the separate operator-version gate gap. New fixed-vector binary namespace/key lease test passes on 0.12 and fails on 0.11 with the precise E976 (9 pass/1 failure, /tmp/parley-373-lease-011-red.log). The boundary now falls back to sha256sum/shasum over raw stdin only when native SHA refuses NUL; normal digest paths stay unchanged. Both digests are computed before allocating any lease resource, and missing utilities refuse cleanly. Actual 0.11 run now passes 11 lease cases plus 22 owned/native editor cases, clean census (/tmp/parley-373-lease-owned-011-green.log). First attempt to select 0.11 using a make command-line variable actually kept the preferred runtime; reran with PARLEY_TEST_NVIM in the environment and verified the real failure, rather than counting that false-negative run. Fresh full-suite verification is required for the code change before restaging.

Live acceptance completed on actual PATH Neovim 0.11.7, real profile /Users/xianxu/.config/parley, real Couch transport and staged 9dd4ca8e5e2d41c2a8e5c39e7a5dd8703c4011eb. TL approved doing this while the code-identical full suite waits (1f96f893-97a0-406c-9491-2448932c19a3, submitted). PASS: design.md → spec.md rewrites quoted/commented discussions scalar and body link in disk/loaded buffer; original spec.side bytes stay unchanged at spec_1.side; notice gives full retained path; child parent/backlink updated; nested child unchanged; actual Alt+o opener reaches spec.side/01-why.md; later native save and reopen plus real lookup keep stable ID 3ad7ab1c3bab18adf6510d162a4ddc71. Forgot registration, confirmed OLD/NEW/child lookups absent, removed scratch, and cleared :0 back to main. No sends, credential changes or real-document edits. Evidence /tmp/parley-373-live-evidence.json and /tmp/parley-373-live-check-final.log. An intermediate scratch-script error called parley.OpenFileUnderCursor instead of parley.cmd.OpenFileUnderCursor after all move assertions passed; cleared/cleaned that attempt, corrected only the script, then completed the full pass.

Fresh code-change suite on 9dd4ca8e5e2d41c2a8e5c39e7a5dd8703c4011eb is queued: attempt fc7be9493f18008e7fd6a593b09307c4, exec session 7683, common Git sdlc/test-stats/inflight/fc7be9493f18008e7fd6a593b09307c4/run.log. Earlier suite pass is retained but does not verify the lease correction. No flake retry or gate waiver. M2 review/whole close/landing remain pending that fresh suite.

Recovery reread preservation regression: a real once-only BufReadPost edit at the recovered name handoff was overwritten by the next reread (22 pass/1 failure). Require a postimage on every handoff: v2 accepts the captured editor preimage or its existing pure mechanical projection; v1 accepts only its captured preimage. Other text stays modified and interrupted before any later read. Negative control fails both v1/v2 cases (22 pass/2 failures); final owned suite passes 24 cases on both preferred 0.12 and operator 0.11. Logs /tmp/parley-373-v1-read-{negative,final-green,final-green-011}.log.

Recovered hook ordering regression: unknown raw NEW invoked document_moved before refusal, and a valid parent publication gap handed off before its existing proof (52 pass/3 failures). Dispatcher now proves raw NEW before recovered handoff; parent publication gaps reach editor through their existing before/after proof first. Fresh move timing and v1 dispatcher unchanged. Green 55 mover cases plus 2 single-owner checks, lint and whitespace clean; /tmp/parley-373-m2-recovery-order-{red,green}.log. These finish the approved witness/editor contract, adding no state or recovery action. Current queued 9dd4ca8e suite remains baseline evidence only; final code requires a new recorded run.

Final recovery-fix candidate f4552c63ff8d4284332708e420633e844cacec3d passed the same real-profile scratch acceptance on operator Neovim 0.11.7 at 13:35 PDT. Real Couch ID 41670d76cc323679ff4e23260ccdbad2 remained stable through rename, save and reopen; parent link/index, orphan preservation/notice, child backlink and actual Alt+o assertions passed. Scratch registry entries were forgotten and lookups confirmed absent; files removed; stage cleared back to main. Evidence /tmp/parley-373-live-evidence.json and /tmp/parley-373-live-check-final.log. Recorded final-code suite launched (exec session 18594); older queued run retained, not reused for these code changes. Hub report receipt ee718c23-1879-47e3-8052-c5dd2f6a7cfd pending delivery.

Final combined recovery verification on operator Neovim 0.11.7 passed 24 owned-editor and 55 mover cases, clean process census (/tmp/parley-373-recovery-combined-011.log). Recorded final-code suite attempt 0538b4445fd6c4c1c5d1707974d2d3b1 runs f4552c63 in detached sdlc-local-3488177334, queued at machine admission; exec session 18594. Hub live report ee718c23-1879-47e3-8052-c5dd2f6a7cfd is submitted.
