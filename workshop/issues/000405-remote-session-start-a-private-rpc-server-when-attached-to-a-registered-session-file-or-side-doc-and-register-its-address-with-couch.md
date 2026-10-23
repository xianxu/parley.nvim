---
id: 000405
status: working
deps: []
github_issue:
created: 2026-10-20
updated: 2026-10-22
estimate_hours: 5.41
collaboration-mode: collaboration
card_mirror: '315a57b4c66add1f567d61997625aae88ea856d1' # card fields mirrored from issue-cards; edit via sdlc
started: 2026-10-22T04:55:52-07:00
claimant:
    operator: Xian Xu
    machine: 4716879978a7b90f6b583da1716fd0e9
    machine_name: Xian’s MacBook Pro
    workspace: parley.nvim:1
    worktree: /Users/xianxu/workspace/worktree/parley.nvim-slot1/parley.nvim
    repository: github.com/xianxu/parley.nvim
flow: {kind: full, provenance: inferred}
---

# remote-session: start a private RPC server when attached to a registered session file or side doc, and register its address with Couch

## Problem

Project remote-session (ops `teams/devinfra/projects/remote-session/`, operator-approved 10-20) makes the phone a
remote view of the live nvim buffer for each hub's session file and side docs. Couch needs to reach the nvim that has
the file open, without the operator starting nvim with special flags.

## Spec

- When parley attaches to a registered session file or side doc, it starts a private RPC server for that nvim
  (`serverstart()` on a per-file socket under a private runtime folder) and registers the address with Couch, the same
  way it reports submits; it unregisters on buffer wipe or nvim exit.
- Plain `nvim session.md` keeps working; no flag.
- If two nvims open the same file, the most recent registration wins and the other is told (parley already warns
  about a second editor on a locked file).
- Related: parley.nvim#404 (take the lock on entering insert mode) is the desktop half of "keyboard shown = locked".

## Done when

- Tests: attach registers an address, wipe and exit unregister, a second nvim supersedes the first; the socket is
  private (0700 folder).

## Plan

- [x] M1 — endpoint model, private listeners and producer conformance (see [durable plan](../plans/000405-remote-session-endpoint-plan.md)).
- [ ] M2 — attachment lifecycle, outside-pane discovery, native takeover/teardown and real-profile acceptance.

## Log

### 2026-10-20

### 2026-10-22 — claimed and planned against producer prerequisite
- 2026-10-22: closed M1 — TL0bb56c13 authorizes round5 after complete input/construction boundary sweep. Shared pure pending/listening validation RED46pass6fail ->52PASS both versions; native rejection sequence RED26pass4fail ->31PASS including unsupported filename before allocation, allocated Socket rejection, refused/throwing constructors, invalid native buffer control, subsequent ordinary attachment and close. Canonical195PASS both Neovim0.12.5/0.11.7, clean censuses; lint0warnings0errors834files; endpoint fake conformance and corrupt-identity negative controls pass both. Fresh recorded suite pending on411be8eb; no landing until final pass. Real producer acceptance remains M2 pending pair#758/#801. Any further new finding family returns to TL for scope decision before patching.; review verdict: SHIP

Ran tl-worker/help and start-plan. The startup weave refresh changed only a generated CI workflow; restored that refresh delta under the TL's standing instruction, so no workflow/local-gates change is part of #405.

Inspected current admission/move/exit seams and remote-session design. Couch has no existing editor-endpoint API. TL approved pair:6's independently landed pair#758 M1 producer prerequisite, then #405, then the proxy; producer contract is being pinned before any code. TL also confirmed one read-only Markdown-open lookup outside Couch panes, with outside-pane submit unchanged.

The durable plan identifies the pure sole owner, private per-file sockets, exact generation cleanup, notice-before-ack and detach-before-ack races, bounded shutdown, executable fake and real native conformance. No estimate before the full-flow change-code plan-quality gate.


### 2026-10-22 — M1 runtime, transport and dispatcher evidence

Runtime ownership completed with21 passing integration cases on0.12.5 and0.11.7, including native SIGKILL residue reclamation, competing allocation at cap-1, killed guard holder, foreign/symlink/live/reused/unknown controls, deadline cancellation, marker/directory replacement and exact listener stop. Logs: parley-405-runtime-final.log and parley-405-runtime-final-0117.log under TestScratch. A native red test proved serverstop can unlink a foreign replacement: immediately revalidate the owned socket identity before calling it, otherwise retain the listener/artifact. This does not claim control over Neovim's eventual exit cleanup. At the256-marker inspection limit, inspect own PID plus255 deterministically selected distinct marker PIDs; any uninspected marker remains unknown and counted. No additional process scan or weaker death proof.

Typed outbound protocol: RED9 new failures, GREEN34 unit cases both versions (including existing owner cases). Endpoint transport: RED7 failures/0errors, GREEN7 both versions, plus12 unchanged registry regressions on preferred; timed-out/canceled child PID is ESRCH before result callback. Same existing4-active/64-queued Couch seam, strict request sizes/shapes and1MiB streaming reply cap. The persisted endpoint fake shares the registry flock and high-water evidence; Namespace is an additive projection, generated fake IDs match real32hex IDs.

Dispatcher: initial7 cases green; ordered lifecycle/count additions exposed one callback loss between native serverstart and durable listen completion (13pass/1fail/0errors). Fix retires that listener and reports attach completion exactly once. Final14 cases pass on both runtimes, including notice-before-ack, detach-before-ack with successor protection, held-startup cancellation and counted8/16 opens with exactlyN register children and one startup process-source batch despite duplicate events. Process censuses clean. Logs: parley-405-dispatch-final.log and parley-405-dispatch-final-0117.log under TestScratch. make lint:0 warnings/0 errors in834 files.

Pair:6 confirmed in delivery18c97b6d that endpoint CLI is a bounded private IPC observer; native nvim subprocesses belong to the daemon and use its bounded/joined lifetime, never CLI stdout pipes/process descendants. Killing the client may leave admitted publication, so the same AttachID intent remains unconfirmed. Producer PR542 is queued for its recorded suite; no landed merge pin yet. Real native producer conformance, canonical focused/architecture checks, recorded suite and M1 close remain outstanding. No automatic session wiring or :0 stage yet.

### 2026-10-22 — M1 focused completion and real-acceptance sequencing

Canonical modes/remote_session mapping passes144 cases on both0.12.5 and0.11.7, including architecture declarations and unchanged registry regressions; clean process censuses (parley-405-m1-focused-final.log and -final-0117.log). Final make lint has0warnings/0errors in834files. Endpoint fake conformance passes both native versions through actual private socket RPC and two editors; deliberately wrong-identity fake is rejected for the expected confirmation failure. Existing registry fake conformance still passes. Logs: parley-405-editor-conformance-preferred.log, -0117.log and parley-405-registry-conformance-compat.log under TestScratch.

TL77d91d23 explicitly approved continuing M1 on fake/native evidence while real acceptance waits: the shared isolated hold-open Couch bridge is a separate pair issue (pair:6 filing), not a new launcher in Parley and not part of pair#758. Readiness/teardown interface will be pinned with pair:6 before consumer integration. No fake result is real-producer evidence. Real acceptance moves to M2 once both prerequisites land; automatic attachment lifecycle remains M2. Next: durable checkpoint, push, recorded suite and M1 boundary review.

### 2026-10-22 — M1 review R1, approved correction

PR330 at2b4916d7. M1 review returned REWORK with BR-1 queued publication/orphan startup, BR-2 reset aggregate deadline, BR-3 stale Core concepts location, BR-4 retained final runtime and BR-5 missing README invocation. Measured M1 candidate actual2.78h; no waiver. Canceled only superseded recorded suite lease-2667035583 before admission; cancellation completed, no suite result claimed. TL23d2aca3 approves the cohesive runtime lifetime correction and red cases recorded in the plan. Pair:6 filed bridge pair#801 separately, dependent on pair#758. No M1 close or M2 implementation yet.

### 2026-10-22 — R1 corrections verified

BR-1/BR-4: runtime epoch tracks live consumers separately from retained cleanup. Last consumer cancels/joins startup immediately and calls the typed handle's cancel_unstarted for queued register work; admitted publication observers remain for exact late-ack cleanup. Drain automatically closes the exact runtime before a waiting new attachment allocates. Terminal superseded/permanently refused history remains without resources; unconfirmed publication retains its listener. Controlled red cases observed14pass/4fail/0errors, then owner20 cases pass both versions. A refusal fixture required explicit empty JSON objects rather than Lua's empty-array encoding.

BR-2: one acquire deadline carries through first-listener marker durability; controlled800ms source plus1500ms fsync red cases observed22pass/2fail, then runtime24 cases pass both versions. Later listeners retain their operation budget. BR-3 authoritative concepts/integration inventory corrected, including the separate pure codec and runtime shell. BR-5 README names the runnable fake conformance and real prerequisites. Added the general runtime-lifetime/deadline lessons and mapped the current atlas behavior.

Final canonical focused mapping153pass/0fail/0errors on0.12.5 and0.11.7, clean process censuses; make lint0warnings/0errors in834files. Logs parley-405-r1-focused-final.log and -final-0117.log, parley-405-r1-lint.log under TestScratch. Endpoint fake conformance and wrong-identity negative control pass both versions after the owner changes; existing registry fake conformance still passes (parley-405-editor-conformance-{preferred,0117}-r1.log and parley-405-registry-conformance-compat-r1.log). No real-producer claim. Next fresh pushed-head suite and M1 review R2.

### 2026-10-22 — R2 cancellation sweep re-plan

M1 review R2 returned REWORK: BR-2/3/4/5 disposed, BR-1 not addressed at listener reservation/publication. Reviewer held reservation fsync, detached, then observed one later serverstart and zero cancellation calls. Canceled only superseded suite lease-1486643512 before admission, cancellation completed. TL a142bd29 approved the whole startup-cancellation table appended to the durable plan: exact per-consumer listener transaction/fs ownership, shared acquisition ownership, queued-vs-admitted Couch distinction and witnessed interrupted publication cleanup. Round3 finding outside that table must return to the TL. No M1 close or M2 code yet.

### 2026-10-22 — R2 whole-table cancellation evidence

The dispatcher retains and cancels the exact per-consumer listen handle through callback delivery. Four controlled native startup boundaries plus the foreign replacement control initially reproduced five missing-cancellation failures (20pass/5fail). A stronger reservation case with a live keeper then reproduced the missing cleanup join (24pass/1fail): no resource.stop, so the slot could not be reused. The failure branch now joins exact reservation cleanup and frees a slot only on confirmed cleanup. All25 dispatcher cases pass on0.12.5 and0.11.7, including keeper RPC continuity, durable marker removal, exact socket-slot reuse and one terminal callback. Logs: parley-405-r2-slot.5xGty9/{red,green,green-0117}.log under TestScratch.

Native runtime cancellation captures the created temporary inode and intended bytes before a canceled coroutine resumes. A finite cleanup-only finalizer holds the existing guard until native work and exact listener cleanup finish. An interrupted committed marker is adopted only for cleanup when its created inode, bytes and private directory all match; a same-byte foreign inode remains untouched. Initial directory creation and marker publication also retain exact ownership witnesses, permitting empty-directory cleanup before a resource was returned. Controlled listen RED26pass/5fail and acquisition RED33pass/3fail; final37 runtime cases pass both versions, including foreign directory/temp/marker controls and cleanup-error guard release. Logs: parley-405-runtime-r2-finalization-{red,green,green-0117}.log and parley-405-runtime-r2-acquire-finalization-red.log under TestScratch. No real-producer evidence or M2 wiring is claimed.

Final canonical modes/remote_session mapping171pass/0fail/0errors on0.12.5 and0.11.7, both process censuses clean (parley-405-r2-focused-final.log and -final-0117.log). make lint0warnings/0errors in834files (parley-405-r2-lint.log). Native endpoint fake conformance and deliberately corrupt-identity negative control pass both versions; unchanged registry fake conformance and its negative control pass too (parley-405-editor-conformance-{preferred,0117}-r2.log and parley-405-registry-conformance-compat-r2.log). Atlas and general cancellation/identity lessons updated. Next: commit/push this correction, fresh recorded suite and M1 review round3 under the approved table.

### 2026-10-22 — R3 cancellation verified; acknowledgment correction approved

R3 on1b91aadf returned FIX-THEN-SHIP, disposing BR-1..BR-5 with executable counterfactual evidence. New BR-6 Important (validated-authority-outcomes) prevents finalization: a wrong canonical File acknowledgment leaves the model unconfirmed but is stored/reported as confirmed, suppressing the unavailable notice. Stopped and reported because it lies outside the startup table. TL81b7ba7a approved pure-owner normalization plus shell use of only the accepted outcome and authorized another milestone-close round. Canceled only own queued suite lease-537115140 on superseded1b91aadf; cancellation confirmed, no suite result claimed. Pure and dispatcher red sequences precede implementation; plan Revision records the class sweep.

M2 preparation only: scratch native traces on both supported versions show checktime/autoread produces BufReadPre/Post, on_reload and FileChangedShellPost without on_detach/BufUnload; explicit edit/edit! or bunload/reopen produces on_detach, BufUnload, BufReadPre/Post. Managed session_sync.with_buffer_read(edit!) keeps the guard true through those events, so it preserves authority but must reinstall the observer. Traces are retained in parley-read-events.5Hsu87 under TestScratch. No M2 code or reload-policy change.

### 2026-10-22 — BR-6 accepted-outcome correction

Pure RED34pass/12fail; model now normalizes every confirmed-but-unowned binding before its sole result assignment to uncertain, useful error, no binding evidence. All46 pure cases pass both versions, covering the transport-valid canonical-File gap, eight other pending-identity mismatches, malformed binding fields before/after retirement, no false unregister, exact retry and copied cleanup evidence (parley-405-br6-model.m8PrKc logs). Dispatcher RED25pass/1fail returned confirmed instead of uncertain; it now uses only the owner snapshot result for callback and notice. New regression also asserts duplicate attach returns that same accepted result without another register, local editing remains unchanged and rejection never unregisters an unowned binding. The reply/report sweep found duplicate attach already uses the model snapshot; unregister replies are cleanup completion only, and startup reports are locally constructed outcomes. Final canonical focused mapping184pass/0fail/0errors on both0.12.5 and0.11.7 with clean censuses (parley-405-br6-focused-final.log and -final-0117.log). Atlas and lesson now describe the sole accepted-outcome boundary.

Final make lint0warnings/0errors in834files (parley-405-br6-lint.log). Endpoint native fake conformance and deliberate corrupt-identity negative control pass both versions after BR-6 (parley-405-editor-conformance-{preferred,0117}-br6.log). Real acceptance still waits for producer and shared bridge; no stage, real-producer claim or M2 wiring. Checkpoint before the fixed-head recorded suite and TL-authorized milestone-close round.

### 2026-10-22 — R4 complete admission correction approved

R4 on3ae64367 returned REWORK: BR-1..BR-6 disposed, BR-7 Critical (validate-before-resource-allocation) is new. A canonical filename containing a newline passes partial preflight, then model.new throws after native listener creation and strands the shared IO queue. Reviewer reproduced no callback, no later ordinary attach and no close on both versions. Stopped and reported before code. TL0bb56c13 approved shared complete-known-field validation before allocation, allocated Socket validation before activation and unavailable/cleanup/completion on constructor rejection, with native continuation controls; another review round authorized. If R5 finds another new family, send the family summary and decide scope before patching. Canceled only own queued suite lease-389571463 on superseded3ae64367; cancellation confirmed, no suite pass claimed.

M2 read-only preflight also found unregister has one top-level Namespace. TL14e010ac approves one batch per Namespace sharing one absolute500ms exit observation budget, queued cancellation and owned/joined admitted observers, with a delayed-second-namespace regression. Native SystemObj.wait(500) is unsuitable because0.12 may wait twice; use the existing async seam and a queue-inclusive absolute deadline. Pair:7 now owns pair#801 and accepted the proposed Version/Namespace/Socket/Environment readiness fields, complete isolated environment, explicit candidate/scratch-parent flags and joined EOF/TERM teardown. Its final executable and bounds still require confirmation before bridge code. No M2 code or stage.

### 2026-10-22 — BR-7 complete validation and continuation evidence

One shared pure validate_context owns the existing field rules: pending requires all eight known fields without Socket, listening requires the full nine-field tuple, and unknown stages refuse. M.new returns nil/error instead of throwing for invalid context. Pure RED46pass/6fail, GREEN52 cases on both versions, including missing/extra/invalid fields, canonical path spelling and the Socket stage boundary (parley-405-br7-model.mzChl9 logs).

Frontend admission builds and validates its immutable known context before runtime allocation. Listener completion validates the allocated tuple, catches a rejected/throwing constructor, joins exact listener cleanup and releases the shared queue before reporting rejection. Four native RED cases (26pass/4fail/0errors) prove unsupported canonical filename, invalid allocated Socket, constructor refusal and constructor exception each previously prevented continuation. The permanent embedded sequence now requires one unavailable result, a succeeding ordinary attachment and completed close, with exact socket/directory cleanup and unchanged local editability. An additional large invalid native buffer-handle control already passes without code changes. First experimental parent-side RPC polling hit the spec deadline (no pass claimed); replacing it with one bounded child-side wait produced the expected four assertion failures and clean census (parley-405-br7-dispatch-red-bounded.log). Final canonical mapping195pass/0fail/0errors on0.12.5 and0.11.7, including all31 dispatcher cases and clean censuses (parley-405-br7-focused-final.log and -final-0117.log). Atlas and general input-before-allocation lesson updated. No M2 code or real-producer claim.

Final lint0warnings/0errors in834files (parley-405-br7-lint.log); endpoint native fake conformance and corrupt-identity negative controls pass both versions (parley-405-editor-conformance-{preferred,0117}-br7.log). Next pushed-head recorded suite and TL-authorized M1 round5; another new family goes to the hub for a scope decision before patching.

### 2026-10-22 — M1 SHIP; M2 red lifecycle and owned IO seams

M1 R5 returned SHIP, all seven findings disposed, no new family. SDLC committed/pushed evidence219cd3e0da42b157b7a8f6a872c18d8962a4b1ba. Reviewer reproduced195PASS both versions and10counterfactual BR-7 failures with zero errors. Recorded suite lease-3944042560 on code411be8eb remains queued; no suite pass claimed and no landing yet. Reported the milestone to the hub; M2 proceeds under its approved plan.

M2 owned IO seams: existing registry queue supports optional queue-inclusive absolute_deadline_ms without resetting on spawn; queued expiration never launches, admitted expiration kills only its CLI and retains joined completion ownership. Runtime stop_listeners reuses exact native ownership checks without marker IO or a lease wait; close reuses it. Controlled RED registry8pass/4fail, runtime37pass/2fail; GREEN51 total on both versions, clean census (parley-405-m2-io-{red,green,green-0117}.log). Six new embedded native lifecycle cases are RED0pass/6fail/0errors before wiring, covering outside-pane discovery/absence, passive+guarded active/superseded reads and in-pane parent/side admission (parley-405-m2-native.j_mnudiu/red.log). Plan refinement uses the proven global BufUnload/read guard boundary, avoiding a second per-buffer observer lifecycle. No real-producer acceptance yet; pair#801 interface remains in coordination with pair:7.

### 2026-10-22 08:35 PDT — M2 lifecycle and exit sequences

The native lifecycle suite now passes13 cases on both0.12.5 and0.11.7 with clean censuses (parley-405-m2-native.pi6KMs/{green,green-0117}.log under TestScratch). In addition to the initial six RED cases, it holds a real lookup reply across unload/reopen, exercises real move_path and saveas with held rename confirmation, preserves ID with a fresh AttachID, resumes a proven no-effect abort, retains an interrupted move without advertisement, and counts exactlyN lookups/registers at8 and16 opens despite duplicate events and managed reads. No new operator-turn or outside-pane submit behavior.

Pure exit composition RED52pass/10fail becomes62PASS on both versions (parley-405-exit-batches-{red,green,green-0117}.log). The shell uses the existing model close transition and typed registry queue, freezes exact Namespace batches once, and gives every batch the same queue-inclusive absolute500ms deadline. It stops only exact owned native listeners, retains marker residue and never claims late/missing authority clean. Retained CLI selection is an absolute binary plus a complete copied environment; runtime/process-source identity remains shared. Later ambient or caller-option changes cannot redirect detach or exit cleanup.

Exit native tests: missing API RED0pass/2fail; private producer mutation RED2pass/2fail; held startup incorrectly clean RED9pass/1fail; admitted register observer not explicitly canceled RED9pass/1fail. All10 exit cases now pass on both versions with clean censuses (parley-405-m2-exit.MCGdm1/{green,green-0117}.log). They cover one batch at8/16 files, two namespaces sharing the original budget behind three occupied registry slots, all four slots occupied with no later expired spawn, held/malformed publication, startup uncertainty, exact cancellation with post-return native join, repeated exit, frozen private client selection and stale-generation/foreign-listener controls. Ordinary detach keeps late-ack cleanup; global exit cancels its exact retained observers because a Lua deadline cannot run after VimLeavePre. No promise of asynchronous filesystem/reap callbacks after exit returns.

Canonical modes/remote_session passes235 cases on both0.12.5 and0.11.7 with clean censuses (parley-405-m2-focused-first.log and -first-0117.log). Actual VimLeavePre hook qualification is in progress. M1 recorded suite lease-3944042560 is still queued on411be8eb, now position3; no suite pass claimed. Real producer/bridge acceptance, M2 final suite, review and staging remain outstanding.

### 2026-10-22 — native quit, broad regressions and short default preflight

Actual setup/qa! tests exposed duplicate unregister calls on both versions: native ExitPre has null v:exiting; detach/BufUnload runs with numeric0 before VimLeavePre, then the exit batch sent another unregister. Reserve native quitting buffers for the shared batch using the numeric exit witness; ordinary unload/reopen still retires immediately. Two actual-quit cases pass both versions. A deliberately disabled exit callback leaves the current binding and fails the registered-document assertion (agent tool-output evidence; no separate saved counterfactual log). Canonical mapping with these cases passes237 on both versions with clean censuses (parley-405-m2-focused-final.log and -final-0117.log). Lint passes0warnings/0errors837files (parley-405-m2-lint-final.log). These results precede the short default-parent change below.

Existing S1 handoff/move/lifetime/session-sync/zero-config regressions pass354 on both versions with clean censuses (parley-405-m2-s1-first.log and -first-0117.log). Their remote-unavailable notices led to a default-path preflight: this slot's default s1/s256 is103/105 bytes; the standard macOS temp path from getconf, canonicalized, gives117/119 bytes. Runtime bounds names at103. Explicit short parents had hidden this default-selection defect. TLda79d200 approved the short physical /tmp/parley-rpc-UID parent and strict precreation ownership/type/0700 refusal policy. Native-private RED39pass/5fail becomes44PASS both versions (parley-405-short-parent-{red,green,green-0117}.log); unsafe parents remain byte-identical, and s256 fits. No real global runtime was touched.

Stopped broad runs before this default could allocate into operator state. TLbe8c4b7d approved a native default_parent getter plus private harness helper/guard, including clean embedded and zero-config entrypoints; no product test flag. Helper implementation and guard qualification are in progress, after which affected broad evidence must be refreshed. No local-gates protected paths or workflows are changed.

Producer prerequisite pair#758 landed as PR542, merge03e736c71e60ba1428e601a0bcb9d94f4c66f2e7, verified from Git and as an ancestor of pair origin/main. Fixed CLI/ack contract unchanged. Real acceptance still waits for separately owned pair#801; no private Couch launcher or fake result substituted. Its final executable/deadline pins remain in coordination with pair:7. No :0 stage or M2 close yet.

## Revisions

### 2026-10-22 — producer prerequisite and outside-pane discovery

Reason: existing Couch document membership is not an editor endpoint registry, and in-pane admission does not cover a plain terminal nvim open. Delta: pair#758 M1 supplies the shared endpoint contract first; #405 consumes it. Add one read-only lookup on Markdown open outside a Couch pane for RPC discovery; preserve all outside-pane submit behavior. Endpoint authority stays with Couch, listener ownership with Parley.

### 2026-10-22 — approved runtime cleanup correction and producer pin

TL031822bc approved the two-milestone plan. Native0.11.7 SIGKILL probe showed that run directory,0700 child and socket survive both kill and the next nvim. TL4967ea9e approved the explicit startup-only, positive-death cleanup lifecycle now detailed in the plan; no assumption of automatic runtime collection remains.

Pair:6's durable producer M1 contract is aa24764a339d7f001dba02c0ec1db50727880362, workshop/plans/000758-editor-endpoints-plan.md. Checked exact JSON version/envelopes/codes/bounds, monotone uint64-string AttachID, native ProcessIdentity, registration Namespace, batch unregister and fixed callbacks. Confirmed by receipt7d43957e with established-channel wording correction: #405 cannot revoke native RPC calls on an existing connection; later pair#798 must fence each proxy operation by generation. No production code yet; change-code owns plan-quality/estimate next.

### 2026-10-22 — plan-quality refinement approved

Plan-quality R1 raised PQ-1 shared-resource-admission-serialization and PQ-2 external-process-boundary-contract (Important). TL396d2c15 approved reusing document_lease's kernel guard for runtime count/create/reclaim and the named remote_process seam/stateful fake,1s inspection/2s async startup budget. Plan revised with controlled concurrency, interruption and canceled-completion tests. No implementation yet; rerun plan-quality to dispose the two findings before estimating.

### 2026-10-22 — M1 pure/process checkpoint

change-code accepted design at89d9906f after plan-quality CLEAN (PQ-1/PQ-2 disposed), estimate5.41h derived from accepted scope. Estimate review INFO: runtime verification may be compressed; track actuals rather than back-fit. Runtime/process Lua item includes its stateful fixtures/native failure tests; CLI integration includes fake/conformance; lifecycle Lua item includes real-profile staging/cleanup; milestone items include suite admission/results and review handling. Pre-resolved design discount is applied; remaining allowance covers implementation-level boundary details and evidence-driven adjustments.

Attachment model: RED22assertion failures/0errors, GREEN26cases on preferred and0.11.7 (parley-405-model.86eYnC logs). Native process seam: RED19failures/0errors, GREEN19cases both runtimes, including deadline/cancel child join; final preferred log parley-405-process-final.log. Runtime ownership codec: RED17failures/0errors, GREEN17cases both runtimes (parley-405-record.D0Yfh4 logs). All logs under TestScratch; process censuses clean. No real Couch endpoint conformance yet: producer implementation/landing remains in pair:6.

File organization separates computational marker ownership in remote_runtime_record.lua and private filesystem/listener ownership in remote_runtime.lua from the attachment dispatcher; no new behavior or protocol. Runtime final pre-effect death confirmation may use a third native liveness observation after process seam's initial+confirmed-dead observations; counted bound is3P at8/16, still one batched ps start-time read and no host-table scan per endpoint. Native runtime allocation and CLI transport tests remain in progress; M1 is not closed.

## Estimate

Produced via brain/data/life/42shots/velocity/estimate-logic-v3.1.md against baseline-v3.1.md. Method A only; source is marked stale by sdlc estimate-source, so calibration is provisional. Derived after plan-quality R2 CLEAN, before implementation.

Decomposition follows the accepted two milestones: one issue/spec primitive, three focused Lua features (pure attachment owner; runtime/process/listener lifecycle; real attachment/move/exit wiring), one Couch API integration with fake/conformance, three API discovery surfaces (native Neovim socket, native ps/liveness, producer command), two milestone reviews and atlas/docs. These are distinct responsibilities, not one feature counted twice.

Base design picks: issue1.0h, Lua2.0/3.0/2.0h, API2.0h and atlas0.15h; apply thorough-spec x0.2. Base implementation picks: issue0.2h, Lua1.2/1.5/1.0h, API1.5h, discovery0.45h each, reviews0.4h each and atlas0.15h; write all impl values at v3.1's40%. Library check: builtin Neovim serverstart/serverstop, existing document_lease flock, existing bounded Couch queue and embedded-native test helper cover the mechanisms; no custom RPC codec or native process library is being built. Familiarity1.0: warm admission/move code and existing IO patterns; no exploratory new runtime stack. Thorough-plan design buffer15%; no vendor-mode cross-repo propagation multiplier (producer owned independently by pair:6).

```estimate
model: estimate-logic-v3.1
familiarity: 1.0
item: issue-spec design=0.20 impl=0.08
item: lua-neovim design=0.40 impl=0.48
item: lua-neovim design=0.60 impl=0.60
item: api-integration design=0.40 impl=0.60
item: lua-neovim design=0.40 impl=0.40
item: real-api-discovery design=0.00 impl=0.18
item: real-api-discovery design=0.00 impl=0.18
item: real-api-discovery design=0.00 impl=0.18
item: milestone-review design=0.00 impl=0.16
item: milestone-review design=0.00 impl=0.16
item: atlas-docs design=0.03 impl=0.06
design-buffer: 0.15
total: 5.41
```

Design2.03 x1.15 + implementation3.08 =5.4145h, rounded5.41h. A reasonable execution range is roughly4–7h; queue/outage/producer wait is not a code-effort allowance. Native conformance and both milestone review boundaries are included.

### 2026-10-22 — corrected sizing, isolated bootstrap and final native admission

Correction to the preceding default-path preflight: the sizing probe incorrectly substituted the32-hex incarnation for the actual e-XXXXXX mkdtemp directory. M1 Git source and the native socket capture establish the real shape. Standard macOS old-default s1/s256 paths measure91/93 bytes, and this slot77/79, which fit103. Long TMPDIR-derived harness paths still exceed the bound. TL557e9342 explicitly keeps the already-tested short physical system parent for robustness to long TMPDIR; the durable plan's rationale and numbers are corrected. The earlier117/119 and103/105 calculations are not native failure evidence.

Harness qualification: missing getter/helper RED50pass/6fail; alias bypass RED5pass/1fail; GREEN66 on both versions, clean censuses (parley-405-runtime-fixture-{red,guards-red,green,green-0117}.log). One helper owns private short defaults, captures the real native prefix and rejects canonical/lexical aliases before acquire effects. The guard negative control uses a fake-runtime effect counter, never operator writes. A0.11 clean-child module lookup failure was fixed by adding the repository test-module package path. Minimal init, embedded and zero-config entrypoints all install isolation explicitly, without a product test flag.

Intentional child-kill cleanup RED12pass/4fail becomes17PASS on both versions with clean censuses (parley-405-child-fixture-{red,green,green-0117}.log). Bootstrap captures an immutable root witness before test actions; parent and child reuse exact cleanup after confirmed native exit. Unknown joins and replaced roots are retained and named. Whole-parent-and-child SIGKILL can leave private temporary residue; no surviving owner is claimed. Shared native fixture-tree removal now lives in tests/helpers/fixture_files.lua and serves both query-dir and runtime cleanup (ARCH-DRY/FUNERAL/SECURE).

Native final-unload publication test RED2pass/1fail proves endpoint(query) and duplicate attach still accepted while v:exiting was numeric. One shared native-exit predicate now gates endpoint witnesses, admission/observation and callback retirement, while preserving known bindings for the same exit batch. All3 actual setup/quit cases pass both versions (parley-405-m2-quit-admission-{red,green,green-0117}.log). Combined guarded endpoint mapping passes267 cases on both versions with clean censuses (parley-405-m2-focused-guarded.log and -guarded-0117.log); these precede only the shared test-cleanup extraction. Refreshed existing S1 regressions pass354 on preferred with clean census (parley-405-m2-s1-guarded.log); operator-version and final shared-cleanup checks continue. Remaining two remote-unavailable notices are the intentional forgotten-parent/changed-owner inheritance refusals, not default socket-length failures. Lint passes0warnings/0errors840files (parley-405-m2-lint-isolated.log).

No real-producer acceptance, final M2 recorded suite, stage or close is claimed. pair#758 is landed; pair#801's supported bridge remains the real-acceptance prerequisite. Own original recorded suite is still retained; no duplicate runner started after Couch restart.

### 2026-10-22 — original recorded suite completed; architecture corrections

The retained M1 run lease-3944042560 / attempt03b79fe303c4473bd688542de9302c6b completed on411be8eb with three architecture failures, not flakes: arrival_budget_spec found the child wait bound hidden behind varargs; json_decode_spec could not see the nested ownership-record key decode inside the parser-wide pcall; module_reachability_spec found the intentionally not-yet-wired M1 endpoint modules. The raw failed log is .git/sdlc/test-stats/failed/03b79fe303c4473bd688542de9302c6b.log. No runner was lost or duplicated, and no passing suite is claimed.

M2 startup wiring resolves reachability. The nested member decode now uses a local pcall and raises an invalid-member parse error into the existing outer protected parser. Child waits retain their supplied arrival.MS budget under an arrival_ms name, including the new native lifecycle and quit tests exposed by the current-head guard. The focused red run reproduced the additional wait-name violations; its JSON and reachability guards already passed. A new pushed-head suite will verify the code corrections; this is not a same-head flake resume.

Both final S1 mappings pass354 cases with zero failures/errors and clean censuses (parley-405-m2-s1-guarded.log and -guarded-0117.log). This includes the shared fixture cleanup extraction. pair:7 confirms #801 still waits for its checkout; final executable and bounds remain unpinned, so real-producer acceptance stays pending.

Final focused refresh:95PASS/0FAIL/0ERROR on each nvim0.12.5 and0.11.7, with clean censuses (parley-405-m2-final-helper-green.log and -green-0117.log). It includes all three formerly failing architecture guards, the ownership-record codec, shared fixture/embedded cleanup, dispatcher, native lifecycle, shared exit budget and actual quit. Lint840files is clean (parley-405-m2-lint-final.log); git diff --check is clean. The fake endpoint production-client probe and deliberately corrupt identity negative control pass both versions (parley-405-m2-editor-fake-final.log and -0117.log). These do not qualify the real producer's native handshake or advisory notification.

Checkpoint M2 native implementation and these results before the next recorded suite. No M2 close, real-profile stage or landing yet; the pending #801 bridge is still required for real-producer acceptance and its final argv/bounds are not pinned.

Recorded-suite continuation: M2 code8726e742921f248cc9fb347982c3bef3b8464383 pushed to PR330. The fresh supported runner is lease-3826755436, attempt5e80962d43811d5f3a8a39098aa0037c, detached checkout /Volumes/TestScratch/local-checks/sdlc-local-2201507114, log .git/sdlc/test-stats/inflight/5e80962d43811d5f3a8a39098aa0037c/run.log. It is queued (initial position9); no suite pass claimed. Retain its FIFO place and verify this exact run after any restart, never duplicate it. Pair#801 remains the independent real-producer acceptance prerequisite. No staging permission or M2 close is requested yet.

### 2026-10-22 — suite sentinel finding and bridge qualification resumes

The M2 suite attempt5e80962d43811d5f3a8a39098aa0037c finished: individual specs passed and the census was clean, but #365's real-CLI sentinel refused outside-pane discovery lookups from existing specs without registry fakes. It is a branch harness defect, not a flake; no same-head retry. Fix the ordinary-test discovery fixture boundary on this branch after consumer qualification, retaining the sentinel itself.

Pair#801 contract confirmed at a5361b1111668cfaf7dc5e593833d5c231c56ce8 with the ordered registered parent/side layout and per-invocation nvim selection. Pair:7 now supplies an executable for provisional consumer qualification, not a final landed acceptance pin. The actual binary reports vcs.revision4b18b409a209717e02a28b5148e6dcacd1d20ebf and vcs.modified=true. Existing fake/client baseline passes in the auxiliary checkout (parley-405-consumer-baseline.log). The #405 branch is attached at /Volumes/TestScratch/parley-405-consumer-fi0fq3qq/parley.nvim; it shares Git history but is an ordinary worktree, while parley.nvim:1 remains on #413 with its active merge runner. The supported bridge-adapter contract and test plan are appended to the durable plan before code. No live profile/stage or final real acceptance claimed.

### 2026-10-22 — supported bridge consumer checkpoint

Adapted the existing endpoint probe to pair#801: async bounded bridge ownership, full advertised environment replacement, actual parent/side IDs, distinct per-file listeners in one editor, exact side-detach acknowledgment, and producer-owned teardown. Readiness and process-lifetime regressions caught hardcoded fixture names, duplicate environment keys and signals after a process had already been reaped; corrected before real qualification. Parent orchestration has4 passing cases; helper has14 passing cases. Fake endpoint plus corrupt-identity control pass both Neovim versions (parley-405-consumer-side-fake-green.log and -0117.log). The short consumer runtime and bridge scratch parents are retained on unknown cleanup. No separate producer launcher or recursive producer cleanup.

Candidate bridge build metadata now pins clean eee3547fd06b624351dee871a4f0630a03d2f612 (PR548). Real0.12.5 and0.11.7 qualification is next, not yet claimed. #413 remains on the numbered checkout with its retained merge runner; these #405 changes stay in the auxiliary worktree on the original #405 branch.

Real bridge attempt0.12 stopped before readiness: TestScratch cb parent exceeded the native wrapper Unix-socket bound. Bridge diagnostics report native fleet cleaned, generations absent, direct child and IO joined. No acceptance claimed. Consumer socket-bearing fixtures now use short physical /tmp, matching the approved long-TMPDIR policy; bulk logs stay on TestScratch. Failed evidence: parley-405-bridge-real-012.log.

Pair:7 resolves the scratch-parent integration: direct physical /private/tmp is supported; the bridge alone creates and removes exact private pc-* and couch-candidate-* roots there. The consumer must not add an extra private parent or ever remove /private/tmp. Updated ownership accordingly; only the separate private editor runtime parent is consumer-cleaned. This corrects the previous consumer assumption, not the producer contract. Both failed bootstrap attempts reported exact joined producer cleanup.

Suite sentinel correction: ordinary outside-pane discovery RED2 absent-vs-unavailable failures; GREEN5 new plus9 existing isolation cases on each Neovim version,28 total, clean censuses. Shared harness fixture delegates only exact lookup when bare Couch otherwise resolves to the sentinel, through the persisted registry fake with per-call empty-store environment; explicit spec fakes win. Direct bare CLI and other verbs still hit97, no product test flag or sentinel weakening. Logs parley-405-discovery-{red,green-012,green-011}.log;3 touched Lua files lint clean.

### 2026-10-22 — real bridge consumer qualification passed

Against the clean bridge binary eee3547fd06b624351dee871a4f0630a03d2f612 (PR548, vcs.modified=false), the actual existing driver PASSES on invocation-PATH-selected nvim0.12.5 and0.11.7. Direct physical /private/tmp is the supported shared allocation parent; producer alone owns its pc/candidate roots, and the consumer removes only its separate private editor runtime after confirmed close. Each run proves real private-socket handshake, exact supersession notice, same-attach retry, desktop takeover, stale register/unregister fencing, detach/lookup retirement, parent+side and same-editor distinct listeners. Fake control and deliberately corrupted identity rejection also pass both. Bridge EOF completed with exit0 and joined IO, with no consumer producer-teardown code. Logs: /Volumes/TestScratch/parley-405-bridge-real-direct-012.log and -0117.log.

This is candidate qualification, not final landed-producer acceptance; wait for #801's actual merge pin, then bind final evidence to it. No live profile, :0 stage, M2 close or landing claimed. #413 retains the numbered checkout and its merge runner; #405 changes are durable on the existing branch in the auxiliary worktree.

### 2026-10-22 — historical red-run orphan removed

TL reported headless nvim PID69636. Repeated native ps established start Thu Oct22 08:55:00 2026, PPID1, exact0.12.5 clean embedded argv and this slot1 checkout cwd. lsof tied its open temporary directory/socket to /Volumes/TestScratch/parley-405-runtime-fixture-red/tmp/nvim.xianxu/LFa2op/nvim.69636.0; all standard streams were /dev/null. That completed08:55 red run exercised embedded_nvim_spec, remote_runtime_fixture_spec and remote_runtime_spec. The exact individual case cannot be established from its log. The red log incorrectly ended with a clean census, despite this surviving child; its missing fixture/default getter failures and later parent/child cleanup corrections are already documented above. No live run owns this process.

After rechecking exact PID/start/PPID/argv/cwd, SIGTERM did not exit within5s. Rechecked the same identity, sent SIGKILL to that exact PID only and confirmed native ps absence. No process group, other PID or runtime directory was removed. This is historical leak evidence, not a claim that the census had detected it or that an additional harness fix was verified today.

### 2026-10-22 — returned to numbered slot after #413 landing

#413 landed as PR335 and its merge runner ended. Verified both worktrees clean; detached the auxiliary #405 worktree at36027746 and resumed the original #405 branch in its claimant slot parley.nvim:1. Current origin/main merged without conflict, including the registered-file FileChangedShell handling from #411 and #413. The auxiliary checkout remains detached, with no live native tests or branch ownership. No code is stacked on an unlanded issue.

Next: push this integrated checkpoint and run the recorded pre-close suite. Candidate bridge qualification on both runtimes remains provisional pending pair#801 merge pin; no :0 stage or final acceptance claimed.

### 2026-10-22 — resume after #417 and pin landed bridge

Verified #417 landed PR337 at df83def3404a005611b2daeab17a7705a91317f5, tracker done and archive present. Returned to the original #405 branch at7924a14c. The retained suite attempt f2bf5c7b2996847ab0a5adcedf83cdb0 completed with exactly two reproducible architecture defects: discovery_registry_fixture_spec.lua's embedded positive wait used literal5000 rather than arrival.MS; executable fake_couch_bridge.py lacked the shared parent-death watchdog. The failed log is retained under .git/sdlc/test-stats/failed; no blind retry or flake classification. Correct both through existing shared helpers (ARCH-DRY/FUNERAL), then a fresh pushed-head suite.

Pair#801 is landed: PR548 merge b5c1cb99260fa8131b48092e4601c2ac86abf5d7 (pair:7 delivery72662f66). Final acceptance pins that exact source, distinct from prior candidate eee3547f evidence. The currently shared pair:7 executable is modified and newer, so build an isolated detached exact-pin bridge rather than relabel it as the landed pin. Existing supported argv/readiness/environment/EOF cleanup contract is unchanged. Go1.27.3 slot tools were rebuilt after the authenticated lifted freeze; no duplicate runner remains for the failed suite.

Watchdog regression RED: the fake bridge survived direct parent death while stdin remained independently open. GREEN: existing fixture_watchdog.exit_with_parent is installed before fixture IO;19 Python consumer/orchestration tests pass. After fixing the watchdog the lifecycle guard exposed its stale inventory assertion (actual19 versus expected18); the added bridge is the seventh watched executable, so update the total to19 without an exemption. Embedded discovery imports the shared arrival helper inside the clean Lua chunk, retaining its positive wait semantics. Changed Lua lint is clean. Focused harness and landed-pin acceptance remain in progress; no new suite pass claimed.

### 2026-10-22 — final landed-producer acceptance and traceability repair

Clean bridge build reports vcs.revision b5c1cb99260fa8131b48092e4601c2ac86abf5d7, vcs.modified=false, Go1.27.3. Actual driver passes real/fake and corrupt-identity negative control on nvim0.12.5 and0.11.7; logs /Volumes/TestScratch/parley-405-landed-801-012.log and -0117.log. Parent/side distinct listeners, native handshake, same-attach retry, desktop takeover and exact notice, stale fencing, detach/lookup retirement and joined producer EOF cleanup all pass. TL23088180 explicitly accepts this as the live check, waiving the earlier profile-stage step; no :0 stage, profile change or operator state touched.

Harness180PASS/0FAIL/0ERROR with clean census; lint843files clean. Initial remote mapping ran267 Lua cases successfully and a clean census, but failed overall because two Python test modules were listed as Plenary inputs. This is a mapping defect, not a flake. Add the existing bounded Lua-to-unittest wrapper pattern and map that wrapper; Python checks then run in normal suite as well. No gate/workflow edits. Fresh focused/suite evidence follows.

Checkpoint before the corrected-head recorded suite: mapping wrapper and final acceptance pin are durable; the0.11 focused mapping is running and its preferred-version repeat follows. No full-suite pass claimed. Final acceptance is complete under TL23088180, so M2 has no external bridge/profile dependency. Do not duplicate a queued recorded suite after restart; inspect the exact lease/attempt printed by the next run and preserve its evidence.
