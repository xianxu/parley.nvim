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

- [ ] M1 — endpoint model, private listeners and producer conformance (see [durable plan](../plans/000405-remote-session-endpoint-plan.md)).
- [ ] M2 — attachment lifecycle, outside-pane discovery, native takeover/teardown and real-profile acceptance.

## Log

### 2026-10-20

### 2026-10-22 — claimed and planned against producer prerequisite

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
