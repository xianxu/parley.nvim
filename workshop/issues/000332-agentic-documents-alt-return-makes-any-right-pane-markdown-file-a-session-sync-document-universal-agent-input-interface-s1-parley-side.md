---
id: 000332
status: working
deps: []
github_issue:
created: 2026-10-15
updated: 2026-10-15
estimate_hours: 5.9075
card_mirror: 'b189f5b9f50fdc780dec47c23145916f7413ce35' # card fields mirrored from issue-cards; edit via sdlc
started: 2026-10-15T13:07:57-07:00
claimant:
    operator: Xian Xu
    machine: 4716879978a7b90f6b583da1716fd0e9
    machine_name: Xian’s MacBook Pro
    workspace: parley.nvim:2
    worktree: /Users/xianxu/workspace/worktree/parley.nvim-slot2/parley.nvim
    repository: github.com/xianxu/parley.nvim
flow: {kind: full, provenance: operator}
---

# Agentic documents: Alt+Return makes any right-pane markdown file a session-sync document (universal-agent-input-interface S1, parley side)

## Problem

Project universal-agent-input-interface (ops `teams/devinfra/projects/universal-agent-input-interface/`, design in
`design.md`, slice S1): today only files with `type: session-sync` get the operator lock, Alt+Return submit and the
red winbar. The operator wants any markdown file opened in Couch's right-pane nvim to become an **agentic document**
at its first Alt+Return.

## Spec

- Any markdown buffer in the right-pane nvim (detected from the pane's pair environment) can be submitted with
  Alt+Return. The first submit registers the file as agentic with Couch (Couch-side registry keyed by canonical path;
  nothing is written into the file) and sends it to **the pane's own slot** ("the agent on the left"). An explicit
  `couch-owner:` in the frontmatter, if present, still wins.
- From then on the existing session-sync behaviour applies unchanged: operator lock on the first edit (parley#324),
  undo-to-baseline release (#330), the red winbar while the operator holds the lock, the band, owed pings.
- A file that was never submitted stays plain nvim: no lock, no band.
- Renaming or moving an agentic file keeps it agentic (registry follows the path) and renames its `<name>.side/`
  folder (S3 relies on this).

## Done when

- A plain note in the right pane, after one Alt+Return, is locked on the next edit (red winbar), an agent write is
  refused while it's held, and the submit reaches the pane's slot.
- A proven-plain, never-submitted file shows no lock or band. Unknown/unavailable membership stays editable with the prescribed uncertainty band, as approved in Revisions.
- Headless tests with the real auto-save setup (as in #324) cover first submit, lock, rename, and an explicit
  `couch-owner:` override. Depends on the pair (Couch) S1 issue for the registry verbs.
- A successful explicit submit keeps a winbar receipt with effective owner and local time through own saves and status refresh, until the next operator edit or agent write. Save, owner, lookup, register and send failures remain visible, including before attachment; feedback is bounded and rendered literally.

- Unchanged content since the last confirmed successful submit is skipped with a visible timestamped notice; a second explicit idle press within two seconds resends with visible confirmation. Changed content sends normally, failures never create success receipts, and busy presses never cause a delayed duplicate.

## Core concepts

| Entity | Kind | Location | Status |
|---|---|---|---|
| `document_session` — lifecycle and registry reply model | PURE | `lua/parley/document_session.lua` | new |
| `document_move_plan` — migration and backlink projection | PURE | `lua/parley/document_move_plan.lua` | new |
| `couch` — shared process transport | INTEGRATION | `lua/parley/couch.lua` | modified |
| `document_registry` — typed registry client | INTEGRATION | `lua/parley/document_registry.lua` | new |
| `agentic_document` — buffer admission and known-path cache | INTEGRATION | `lua/parley/agentic_document.lua` | new |
| `document_move` — leased migration and recovery | INTEGRATION | `lua/parley/document_move.lua` | new |
| `document_lease` — kernel ownership | INTEGRATION | `lua/parley/document_lease.lua` | new |
| `session_sync` — shared edit-turn engine | INTEGRATION | `lua/parley/session_sync.lua` | modified |
| `helper` — checked byte and JSON writers | INTEGRATION | `lua/parley/helper.lua` | modified |
| `fake_couch` — stateful executable fake | INTEGRATION | `tests/helpers/fake_couch.lua` | modified |

## Plan

Durable plan: [Agentic Markdown Documents](../plans/000332-agentic-documents-plan.md).

- [x] Add the pure lifecycle/reply model, shared transport, typed registry client and stateful fake with red/green coverage.
- [x] Integrate first-submit/reopen admission with the existing native edit-turn engine and real Alt+Return routing.
- [x] Preserve document identity, side folder/backlinks and operator turn through native/Parley renames and partial failures.
- [x] Add isolated real/fake conformance and docs/traceability; verify production-door submission feedback and native edit-turn regressions.
- [x] Add unchanged-submit suppression and explicit rapid resend with lifecycle and production-door regressions.
- [ ] Complete the required full suite on the final implementation before close.

Post-close acceptance remains pending: after SHIP and the green suite/conformance, stage under the existing hub authorization for the combined operator check. Pair#573 has landed; the TL coordinates the Couch and Neovim restart. Land only after operator acceptance; clear the stage and report the merge.

## Log

### 2026-10-15

- Read the approved ops S1 project/design and the frozen pair#573 caller contract. #327 landed and its stage cleared before claiming/starting this branch; no stacked work. Used brainstorming/writing-plans and read-only bounded scouts; no production code or tests changed.
- Contract agreed with pair:5: capitalized envelope/effective Registration+Changed, null-only absence, nonzero/invalid envelope as unavailable, metadata-only rename after caller filesystem effects, stable ID and exact-argument uncertain retry. Pair public verbs/full review were still pending at the last peer report.
- Exploration found legacy couch.query erases explicit-null key presence, and session_sync disk/lock paths change immediately with buffer name while loaded/baseline/callback observations do not. Native temporary probe confirmed saveas emits paired buffer-name events before destination creation; destination exists only after BufWritePost. Plan owns both classes explicitly (ARCH-DRY/ARCH-ORDER).
- Asked hub to settle safe unknown-lookup editing policy and pair to clarify legacy typed-state adoption plus supported isolated real CLI conformance. These remain plan inputs; no change-code/estimate/implementation yet.

- TL settled availability policy (verified submitted a70bb84a-9070-4d6b-a505-60f22af1a603): never block operator editing on unreachable Couch. Keep full protection for known/cached agentic paths; unknown/unavailable is editable with a one-line band and bounded re-lookup. Couch is the exclusive agent CAS writer, so down means no concurrent agent writes. Plan revised to include bounded local knowledge and preserve unknown-period edit baselines through auto-save. Durable forward-only rename recovery approved.

- Verified TL design approval f96cd3f0-f712-4ed6-917f-eb348dc75b8c (submitted): approves the full draft with editable unknown/cache policy, durable rename journal and save→register→submit. Source inspection resolves queued pair questions: Register imports typed legacy state/shadow/path history; rename requires an existing registration, so typed OLD must be registered before native move. COUCH_ISOLATED_ROOT and an isolated adopt-store preview/apply are required for standalone CLI conformance; HOME/XDG alone do not isolate the OS-account singleton. Candidate CLI execution remains pending; no installed-binary/live claim is made.

- Plan-quality round1 raised PQ-1 cross-editor migration ownership, PQ-2 test-strategy inventories, and Minor PQ-3 cleanup coverage. Refined the whole ownership/cleanup class: per-ID POSIX kernel lease spans execution/recovery, exact pending tuples cannot be replaced, process death releases ownership, retired inode acquisition is revalidated, and only lease-owned manifested temps are cleaned. A local runtime probe confirmed LuaJIT FFI exports flock; unsupported platforms refuse unsafe migration while ordinary editing remains available. Test plan is now one strategy per risky function, with real two-editor ordering and native triggers.

- Plan-quality round2 returned CLEAN: PQ-1/PQ-2/PQ-3 all addressed, no new findings. Gate now asks for the estimate, so derive against v3.1/baseline-v3.1 after the design has cleared; no implementation yet.

### Implementation evidence (2026-10-15)

- change-code admitted the full design at3859cf1f after CLEAN plan-quality and informational estimate review. Pair's submitted answer a6560099 confirms legacy adoption/pre-register-OLD and isolated public adopt-store bootstrap. Implementing with executing-plans and bounded pure-model, lease, writer and migration tasks.
- Observed missing-feature REDs before implementation. Focused GREEN: lifecycle11, lease9 (real two-editor/process-death/inode races), registry3, Couch5, move projection8, helper IO57. Native registered plain dd/x/p/u/dot acquire before existing auto-save; observed clean auto-saves retain their pre-edit baseline. Initial admission4 cases pass, including native saveas with side/backlinks; corrupt-cache and reopened-journal recovery regressions are being added.
- Ran python3 scripts/check-couch-registry-conformance.py --couch /Users/xianxu/workspace/worktree/pair-slot5/pair/bin/couch: real and stateful fake pass the production Lua registry transport's register/lookup/replay/filesystem+metadata rename/conflicts/null checks; malformed/unsupported fake cases pass; deliberately corrupted fake is rejected. Candidate reports revision49c3285c847133f6f10005c12fee584bac30989a with modified build flag. This is isolated candidate evidence, not pair#573 landing or operator acceptance.
- Migration tests found a foreign backlink edit during replacement preparation and malformed persisted witnesses. Their REDs were observed; fixes now pass those regressions. No suite/close/stage/landing claim yet.

- Editor/runtime verification: admission11, native input/turn/recovery60, migration14, model18 and review-send18 pass. Added real-process restart recovery of lock/baseline proofs, synthetic free-turn protection through metadata publication, safe no-effect return after a refused native target, canonical-alias cancellation, edited in-flight registration confirmation without resend, and owner confirmation after save. Corrupt caches remain editable. Known-null/replaced registry identity goes through turn reconciliation before detachment; existing locks are retained.
- Broader mapped checks found three architecture guard failures (exported function names missing in Core-concepts rows; reverse-definition selection consequently empty; a local fence regex) and five obsolete assertions against the fake's persisted fallback Owner. Corrected the entire table/parser ownership class and made tests assert effective Owner via the production lookup API. The review mapping passes, the session-sync behavioral spec now passes all58 cases, and the shared writer57/lease9/projection9 focused rerun passes. Keybinding/architecture rerun is in progress; full suite and close remain pending.

- 2026-10-15 — packaging VM confinement flake filed as [#336](000336-packaging-vm-focus-flake.md), unclaimed for separate work. The issue records test, first-seen head, failed/full-remainder log and unchanged17-pass focused rerun; rerun success does not dispose of the flake.

- 2026-10-15 — feedback RED/green:18 admission cases and64 native edit cases pass after observing13/5 and60/4 RED. Success is set after the actual send succeeds, stays through own writes/owed probes and clears before auto-save on the next edit or on foreign write. Registration/owner resolution/lookup/send errors show a bounded literal winbar error, including before attachment. #322 is superseded by this implementation; duplicate triage does not claim parent landing. Full suite and close remain pending on the final code head.

- 2026-10-15 — required suite on e9a1622d completed lint (745 files, zero warnings/errors), all unit files and all architecture/integration recipes; only packaging_vm_spec failed the same guest current-buffer confinement assertion tracked as #336. Full failed log: /Users/xianxu/workspace/parley.nvim/.git/sdlc/test-stats/failed/894c995da011381b869a9bd450c9545b.log. No close/stage or waiver. Reported blocker to the hub for a separate main-based fix. Isolated real/fake production-client conformance and corrupted-negative rejection pass against clean installed Couch build6d65c4c4ef29bcdea3ea5b45f3dfdeed41ce1154, independently verified to contain pair#573 merge55ae58b124219edbd63c2782e8c00327eeda1327; /tmp/parley332-conformance-landed.log.

- 2026-10-15 — TL applied the approved issue-backed known-flake rule: a passing full rerun counts as landing evidence while #336 remains open for a separate main-based fix; no waiver or quarantine. Preserve both packaging failures: first on b6c67239 in /tmp/parley332-full-remainder.log (make -k completion after unit failure; original required log /Users/xianxu/workspace/parley.nvim/.git/sdlc/test-stats/failed/5d220af4fdd46df3a464757351ca06ac.log), second on e9a1622d in /Users/xianxu/workspace/parley.nvim/.git/sdlc/test-stats/failed/894c995da011381b869a9bd450c9545b.log. The exact e9 rerun was refused because it is no longer a remote tip; rerunning pushed1eaefd96 changes only this issue documentation, with code/tests identical to e9. Required rerun remains pending; no close/stage yet.

- 2026-10-15 — full rerun on1eaefd96 passed packaging_vm_spec (18s) but hit50s harness deadlines in entity_delete_parity, file_history and issue_tracker, with no preceding failed assertions. Those identical-code files passed the prior run at83/63/67s. Recorded this separate shared timing/deadline class as published, unclaimed #337; failed log /Users/xianxu/workspace/parley.nvim/.git/sdlc/test-stats/failed/572dbf1a77bfb77320a173d6409874e8.log. Exact pushed1eaefd96 full rerun started under the issue-backed policy, with all tests and deadlines unchanged. No close/stage yet.

- 2026-10-15 — TL parks #332 and assigns #337 to this slot from main. Exact1eaefd96 full rerun still failed: packaging_vm (#336) plus branch_child, file_history, issue_tracker and packaging_release whole-file deadlines (#337); entity_delete_parity passed56s. Full retained run log is /Users/xianxu/workspace/parley.nvim/.git/sdlc/test-stats/inflight/6f81bbfaed0b35a39900598fdc471e11/run.log (will move to failed/6f81bbfaed0b35a39900598fdc471e11.log on completion). Session52513 is finishing the final recipe. No more blind reruns. This branch remains unclosed/unstaged; after #336 and #337 land, return here, merge main, run the suite once, close on SHIP and stage for combined operator acceptance before landing. PR241 retains all implementation and receipts; clean landed-Couch conformance remains /tmp/parley332-conformance-landed.log.

- 2026-10-15 — final parked-run result: exact1eaefd96 suite completed every recipe in3m47s; packaging_vm assertion (#336), plus branch_child, file_history, issue_tracker, packaging_release and starter_bootstrap whole-file deadlines (#337). Full saved log /Users/xianxu/workspace/parley.nvim/.git/sdlc/test-stats/failed/6f81bbfaed0b35a39900598fdc471e11.log. No active suite remains. All #332 implementation and continuation instructions are committed on PR241; work switches to #337 from main as directed.

- 2026-10-15 — continued implementation verification: model18, registry7, lease9, Couch5, native edit-turn60, existing session-sync58, review-send18 and focused architecture25 checks pass; mapped keybindings exposed a duplicated documentation catalog timeout, corrected by keeping the symbol catalog in the durable plan (unchanged guard passes). Isolated production-client conformance passes against the unlanded pair candidate and the stateful fake, including the deliberately corrupted negative control. Native migration19/projection15 checks passed before extending actual Parley mover coverage. Actual public movers accept ordinary Markdown and rename before native hooks, requiring owned-file journal effects; executor RED observed (21 pass/7 expected failures). Initial public-door fixture itself errored on a private setup helper and is being corrected before claiming behavior evidence. Full suite, mandatory close review, stage and live acceptance remain pending.

- 2026-10-15 — owned Parley mover integration green:8 real public-door checks (both doors, free/held turn, unloaded file, unavailable/occupied refusal, typed legacy ledger adoption) plus29 durable executor checks, including atomic no-replace race and crash recovery. The initial legacy public-door failure proved OLD was deleted before registration; admission now confirms register OLD first. Final mapped ui/keybindings exits0, full lint741 files0 warnings/errors, git diff check clean. Current isolated real/fake conformance exits0 after the fake-ledger changes; corrupted fake is rejected. Code is checkpointed before main integration and the required full suite; no close/stage/live acceptance claimed.

- 2026-10-15 — final no-clobber class sweep: the parent move already used exclusive rename, but the side-directory move still used overwriting POSIX rename. A stale-absence/foreign-empty-directory regression observed29 pass/1 failure; sharing the exclusive primitive yields30 passing executor checks. Nine public-door checks pass, including legacy native saveas through an alias. A real clean Neovim probe showed both edit and buffer-name APIs canonicalize that directory alias; registration correctly receives the actual canonical buffer spelling, so no invented lexical-state fix was applied. The first required suite was cancelled while still queued behind the machine-wide cap, before tests started, so the final code head can be checked. Main49d8097a is integrated, PR241 server checks passed on afb97362. Full suite and close still pending.

- 2026-10-15 — classifier class regression: the new mover shortcut used timestamp filename recognition as full chat admission, bypassing registry migration for a dated ordinary note lacking topic/file metadata. Production-door RED observed10 pass/1 failure (identity stranded after filesystem move). Reuse the full existing not_chat classifier, with supplied file lines for unloaded paths, rather than duplicating header rules;11 public-door cases pass, including an actual chat moving while registry lookup is unsupported. The queued full-suite attempt on4ef8b25c was stopped before execution to verify this final code fix on a new pushed head (ARCH-DRY).

- 2026-10-15 — required suite onb6c67239 failed unit/chat_finder_logic (3 invalid one-line chat fixtures) and unit/prepare_dir (cache bypassed shared mkdir seam). Finished all integration/architecture recipes with make-k: nodiscard, sidecar_authority, single_source_sweeps, agentic_document and packaging_vm failed; every other file ran. Fixed the actual classes: cache uses fs.ensure_dir and consumes atomic-write failure, all three new state readers have real corruption/ownership exercises in the shared sidecar registry, chat fixtures are valid transcripts, and admission tests wait for exact completed payloads with an end-to-end10s budget rather than file existence or a3s multi-command budget. Added not_chat to the Core catalog; the integrated #333 symbols were false attribution while the local main reference lagged and disappear with main current (no guard edits). Seven focused files now pass (nodiscard, sidecar authority, single-source sweeps, admission, corrupt-sidecar degradation, ChatFinder and directory preparation). The packaging VM failure was a guest current-buffer confinement assertion; its unchanged17-case focused rerun passes, so it is preserved as a transient observation and not waived. Required suite must rerun on the fixed head.


- 2026-10-15 — main #336 and #337 integrated cleanly; #337 landed as PR244 before returning here. Dedup Revision approved by hub (submitted receipt95a7c746-0942-49ca-b786-eb581e2c2c4b): bounded in-memory receipt, owner-confirmed saved content, explicit idle rapid resend, no restart persistence. #337 interrupted runner was rerun on the identical head and passed before landing; cancellation was external SIGINT, not a test flake.

- 2026-10-15 — dedup Revision TDD: pure lifecycle observed19 green/13 expected red, then33 green; the additional failed-delivery-after-edit regression observed33/1 before34 green. Captured receipt, deterministic two-second boundary, stale callback, owner/ID replacement and rename seed tests use the production controller. Logs: /var/folders/07/b9wcwwld4_v2w9r3hk525bm80000gn/T/parley-332-receipt.q2j7Tr/{red,reload-red,failure-edit-red,green}.log. Production-door initial RED19/5 retained at /tmp/parley332-dedup-red.log; changed/unchanged/resend, owner-lookup busy presses and stale-success cases passed after wiring the controller. A background-open regression initially asserted synchronous completion incorrectly; it now awaits the real scheduled registry callback while deliberately holding any extra lookup, so an unintended queued resend cannot pass by timing.

- 2026-10-15 — the new owned-move receipt tests exposed a real native-buffer handoff defect: both public doors moved successfully, but the next ordinary :write failed E13 because nvim_buf_set_name sets Neovim's not-edited flag, which checktime skips. Isolated native probe confirmed a non-bang native edit clears it and preserves identity/view; modified buffers refuse E37 without overwriting. The journal executor already proves NEW's inode and bytes immediately before the handoff. A guarded read acknowledges that proven NEW, preserves undo even above undoreload, and reinstalls session-sync's edit callback after movement finishes (reload detaches it while the moving guard suppresses BufReadPost). Native and owned moves retain the successful receipt; no force-write bypass was introduced. Additional public-door checks cover the next edit/write and an edit made during name handoff, retaining the journal and protected NEW for recovery. Full required suite, close and stage remain pending.

- 2026-10-15 — final targeted candidate passes34 lifecycle,26 admission and14 public-move cases (/tmp/parley332-dedup-final-targeted.log), including scheduled busy-open completion, edit-during-send/reload and modified name handoff. Lint751 files0 warnings/errors and git diff check pass. No test processes survive. The required full suite and close remain pending.

- 2026-10-15 — required suite on b5de7d2b4c3d336679135d016baeb58654f262aa completed all443 spec files after2043s queue /3m11s execution:442 pass, sole failure tests/integration/cliproxy_lifecycle_spec.lua (persistent-404 credential_health first await at778, fixed8s callback budget;53pass/1fail/0errors). No surviving processes. Packaging_vm and all former #337 deadline failures passed; all #332 spec files passed. Retained log /Users/xianxu/workspace/parley.nvim/.git/sdlc/test-stats/failed/acebcf70a6676a7e2e96ef8c6624e95a.log, SHA256 e330d2ee07a369850bc8d6bb9233559fa4b86a510c95acd6cef89e06672a5548. This is a new independent failure, recorded unclaimed as #340 rather than changed inside this branch.

- 2026-10-15 — one focused unchanged-code cliproxy reproduction passes54/0/0, no survivors, log /var/folders/07/b9wcwwld4_v2w9r3hk525bm80000gn/T/parley-332-cliproxy-triage.keheOK/target.log. HEAD differs from pushed b5de7d2b only in this issue and its plan. Static repair terms can exceed the spec's8s wait (up to10s configured probes/polls plus synchronous process discovery); the exact delayed stage is unmeasured, so this supports a budget-sensitive flake, not a proven missing callback. Asked hub whether the known-open-flake rule permits one full rerun on the exact same pushed code head while another slot fixes #340 from main (receipt4dde4dcc-7995-4612-b254-0aa46af8f34f). No waiver or blind full rerun; close/stage remain pending. Fresh real/fake conformance passes at /tmp/parley332-conformance-final.log against clean Couch revision6d65c4c4ef29bcdea3ea5b45f3dfdeed41ce1154 containing the landed pair#573 merge.

## Revisions

- 2026-10-15 — record the already-approved persistent-feedback acceptance explicitly in Done when. Separate implementation verification from post-close staging/live/landing so the checklist records observed work without claiming future acceptance. The required suite is still pending; no close waiver or live acceptance is implied.

- 2026-10-15 — spell out agreed registry boundary and native rename/recovery work in the durable plan without changing the original S1 purpose. Explicit couch-owner is a route override per this issue, superseding #316 refusal only where that new requirement applies. Pending admission-failure policy requires TL review.

- 2026-10-15 — replace the draft read-only admission proposal with the TL-approved editable unknown state, local known-agentic cache and recovery reconciliation. This resolves the failure-policy question; plan review and pair legacy-adoption/isolation details remain pending.

- 2026-10-15 — freeze callable boundaries and legacy/native-rename preflight from primary source; adopt the explicit temporary singleton setup for future conformance. Full design approved, ready for change-code plan-quality admission; estimate remains unset until it passes.

- 2026-10-15 — PQ-1/PQ-2/PQ-3 refinement adds explicit cross-editor ownership and cleanup, and compresses test case prose into function strategies. Retains the approved purpose and editable offline policy.

### 2026-10-15 — Operator-requested persistent submission feedback

Extend the existing S1 first-submit behavior: successful save→register→submit shows submitted to OWNER · HH:MM in the winbar until the next operator edit or agent write; explicit failures show an error there, never a silent return. Preserve feedback through own saves and status refresh. Reuse the single turn renderer with a coordinator fallback before attachment, keeping lock/baseline semantics unchanged. Add production-door and native regression coverage, and close #322 as covered after verification. The TL also permits close review alongside a queued suite only when the binary admits it without a waiver; staging/finalization still waits for a suite pass and pair#573 landing.


### 2026-10-15 — Suppress unchanged submits; explicit rapid resend

Operator request after the #337 diversion: compare against the content at the last confirmed successful submit, never the latest auto-save. Save/reconcile and confirm the effective registration owner before deciding whether to send. An unchanged explicit idle press shows `nothing to submit: no changes since HH:MM` and arms a two-second monotonic confirmation window; a second explicit idle press inside that window sends the same `submitted: PATH` payload and shows `resent to OWNER · HH:MM`. Changed content/identity/owner sends normally. Busy or pending presses cannot arm or authorize a resend; only the initial admission lookup may queue one first-submit intent.

The pure document_session controller owns one bounded in-memory receipt (namespace, stable ID, effective owner, captured post-save hash and success time), confirmation and captured send identity (ARCH-PURE/ARCH-ORDER). Failed or unconfirmed delivery never advances it. A completed issued send records its captured hash even if the operator edited meanwhile, but must not install stale success feedback or release a newer turn. Identity/namespace changes invalidate receipt use; edits invalidate only the confirmation. Preserve receipt through confirmed same-ID native and owned moves; controller detach/editor restart discards it, with no new durable storage (ARCH-FUNERAL). Confirming rename must not itself arm resend.

Add deterministic clock/event tests for unchanged/changed/window boundaries, effective-owner replacement, stale/failed completion and busy presses; production-door tests count complete fake deliveries, verify literal feedback and minimal payload, and cover both move routes and explicit detach/reopen behavior. Keep existing turn reconciliation, baseline and outside-Couch routes shared (ARCH-DRY); no protocol change or additional Couch verb.

- 2026-10-15 — clarify the original no-band Done-when sentence as proven-plain membership, matching the already-approved unknown/unavailable band policy. Record the existing stage authorization and landed Couch dependency so acceptance does not ask for them again. No behavior change.

## Estimate

Produced via brain/data/life/42shots/velocity/estimate-logic-v3.1.md against baseline-v3.1.md. Method A only. Calibration source is marked stale, so figures remain provisional.

The now-admitted plan decomposes into four focused Lua/Neovim concerns (pure lifecycle/replies, admission/edit-turn integration, filesystem migration, and native lease; the registry transport/fake/conformance is the API-integration primitive), one shared-writer/transport refactor, docs and one close review. Tests belong to each component, not an extra duplicate testing primitive. The real-API discovery item owns active isolated singleton bootstrap/CLI inspection only; the API-integration item owns the actual driver/fake implementation. Idle dependency/operator/machine-gate waits are excluded from the estimate.

Raw table selections and discounts: lifecycle Lua1.5/1; registry API2/1.5; admission Lua3/1.5; migration Lua3/1.5; lease Lua1.5/1; refactor0.6/0.5; docs0.2/0.2; review0.2/0.5; API-discovery0/0.6 (design/implementation hours). Apply design×0.2 for the thorough approved/gate-cleared design. For the bounded native lease, the current kernel flock facility short-circuits hand-built ownership/recovery (library availability design×0.5 before spec discount); its symbol was probed locally. Existing Neovim/libuv helpers and the shared writer cover other concerns without new dependencies. Familiar current stack×1.0; v3.1 implementation×0.4; design buffer+15%.

Design subtotal2.25 + buffer0.3375 + implementation3.32 =5.9075h.

```estimate
model: estimate-logic-v3.1
familiarity: 1.0
item: lua-neovim design=0.3 impl=0.4
item: api-integration design=0.4 impl=0.6
item: lua-neovim design=0.6 impl=0.6
item: lua-neovim design=0.6 impl=0.6
item: lua-neovim design=0.15 impl=0.4
item: cross-cutting-refactor design=0.12 impl=0.2
item: atlas-docs design=0.04 impl=0.08
item: milestone-review design=0.04 impl=0.2
item: real-api-discovery design=0 impl=0.24
design-buffer: 0.15
total: 5.9075
```
