# Boundary Review — parley.nvim#405 (milestone M1)

| field | value |
|-------|-------|
| issue | 405 — remote-session: start a private RPC server when attached to a registered session file or side doc, and register its address with Couch |
| repo | parley.nvim |
| issue file | workshop/issues/000405-remote-session-start-a-private-rpc-server-when-attached-to-a-registered-session-file-or-side-doc-and-register-its-address-with-couch.md |
| boundary | milestone M1 |
| milestone | M1 |
| window | 4b8e61ed5f5b5b3ab969bc3df6314dac442e753c..2b4916d7d41bf19cfcc4774381096c5fe6460041 |
| command | sdlc milestone-close --issue 405 --milestone M1 |
| reviewer | codex (openai; author openai) |
| isolation | fenced |
| timestamp | 2026-10-22T06:12:16-07:00 |
| verdict | REWORK |

## Review

```verdict
verdict: REWORK
confidence: high
```

The M1 foundation has strong ownership checks and meaningful native tests. All 144 mapped tests pass on Neovim 0.12.5 and 0.11.7. Additional probes nevertheless confirmed lifecycle and deadline violations. The documented M2 deferrals are respected; the findings below concern the delivered M1 foundation.

```findings
findings:
  - id: new
    severity: Critical
    kind: defect
    family: retirement-cancels-unstarted-effects
    title: |
      Detach leaves queued publication and orphaned startup work running
    detail: |
      lua/parley/remote_session.lua:91 discards the registry request handle, and detach at line 213 neither cancels queued publication nor cancels startup when its final consumer retires. This contradicts the plan's detach/cancellation contract at lines 80 and 94 (ARCH-ORDER, ARCH-PURPOSE). A native probe occupied all four transport slots, queued an attachment, detached it, and observed one register child start afterward. Retain request handles, cancel unstarted publication, and cancel/join startup when no attachments still need it; preserve exact cleanup for already-admitted effects.
  - id: new
    severity: Critical
    kind: defect
    family: aggregate-operation-deadline
    title: |
      First-listener startup resets the promised absolute deadline
    detail: |
      lua/parley/remote_runtime.lua:307 gives acquire its own 2000ms transaction, while listen at line 203 starts another independent 2000ms transaction. No deadline passes between them, contrary to the plan's entire-first-listener 2000ms budget at line 94 (ARCH-CONSTRAINTS). A controlled native probe with an 800ms process-source delay and 1500ms asynchronous fsync delay successfully returned listening after 2339ms. Carry one absolute deadline through acquisition and first-listener publication, rejecting new effects after it expires.
  - id: new
    severity: Critical
    kind: defect
    family: core-concept-location-consistency
    title: |
      The Core concepts table points RuntimeOwnershipRecord at the wrong module
    detail: |
      workshop/plans/000405-remote-session-endpoint-plan.md:22 declares RuntimeOwnershipRecord in remote_session_model.lua, but its codec and cleanup decision exist in lua/parley/remote_runtime_record.lua. The later revision acknowledges this split without correcting the authoritative table. This is the Core concepts contradiction classified Critical by this review contract (ARCH-PURE). Correct the table and add the runtime ownership shell to the integration inventory; retain the accurate PURE classification for the computational codec.
  - id: new
    severity: Important
    kind: defect
    family: last-consumer-resource-release
    title: |
      Detaching the final attachment retains an unused runtime directory
    detail: |
      lua/parley/remote_session.lua:109 permits runtime cleanup only after global close sets closing=true. Ordinary final detach therefore removes the socket but retains owner.json and the process directory, contrary to the plan's last-close cleanup rule at line 92 (ARCH-FUNERAL). A native probe confirmed the directory remained after its socket list became empty. Close the unused runtime after pending cleanup drains, safely coordinating a concurrent new attachment, and test final detach without calling frontend.close.
  - id: new
    severity: Important
    kind: defect
    family: readme-runnable-surface-documentation
    title: |
      README omits the new endpoint-conformance flag
    detail: |
      scripts/check-couch-registry-conformance.py:129 introduces the runnable --editor-endpoints flag, but README.md is unchanged in the pinned range. The explicit README update gate therefore remains unmet. Document the invocation, including --fake-only usage and the deferred real-producer prerequisites; no wording-presence test is needed.
```

1. **Strengths**

   - The pure attachment model preserves exact incarnation, AttachID, and generation witnesses, including notice-before-ack and detach-before-ack sequences.
   - Runtime cleanup conservatively retains foreign, replaced, live, and uncertain artifacts. Native tests exercise crash reclamation and competing allocation.
   - Endpoint transport reuses the existing bounded queue and joins canceled or timed-out children before reporting completion.
   - Marker tests verify nested unknown-field preservation and reject duplicate JSON members.

2. **Critical findings**

   - Cancel unstarted effects on retirement: [remote_session.lua:91](/Volumes/TestScratch/review-checkouts/a27e8ac1eb8c1a81/lua/parley/remote_session.lua:91).
   - Enforce one first-listener deadline: [remote_runtime.lua:203](/Volumes/TestScratch/review-checkouts/a27e8ac1eb8c1a81/lua/parley/remote_runtime.lua:203).
   - Correct the Core concepts location: [plan:22](/Volumes/TestScratch/review-checkouts/a27e8ac1eb8c1a81/workshop/plans/000405-remote-session-endpoint-plan.md:22).

3. **Important findings**

   - Release the runtime after final detach: [remote_session.lua:109](/Volumes/TestScratch/review-checkouts/a27e8ac1eb8c1a81/lua/parley/remote_session.lua:109).
   - Document the new conformance invocation: [script:129](/Volumes/TestScratch/review-checkouts/a27e8ac1eb8c1a81/scripts/check-couch-registry-conformance.py:129).

4. **Minor findings**

   None.

5. **Test coverage notes**

   - `make test-spec SPEC=modes/remote_session`: **144 passing on each supported runtime**, clean process censuses.
   - Fake endpoint conformance passed on installed Neovim 0.11.7; its deliberately corrupt identity control was rejected.
   - `git diff --check` passed.
   - Existing tests miss queued-publication retirement, final-detach directory cleanup, and the combined startup deadline. Add regressions that fail on this pinned head.
   - Real-producer acceptance remains explicitly deferred to M2; fake results do not establish it. No repository files were changed.

6. **Architectural notes for upcoming work**

   | Principle | Result |
   |---|---|
   | ARCH-DRY | Pass: existing transport and kernel lease reused. |
   | ARCH-PURE | Flag: concept-table location contradicts the otherwise separated pure codec. |
   | ARCH-PURPOSE | Flag: retirement does not cancel the promised unstarted work. |
   | ARCH-MOCK | Pass for M1: stateful seams exercised; real qualification remains an M2 requirement. |
   | ARCH-CONSTRAINTS | Flag: independent transaction budgets exceed the aggregate deadline. |
   | ARCH-SECURE | Pass: conservative ownership validation and exact artifact cleanup. |
   | ARCH-ORDER | Flag: retired attachments retain unstarted effects; acknowledged ownership races are otherwise tested. |
   | ARCH-FUNERAL | Flag: final detach retains an unused runtime directory. |
   | ARCH-EVOLVE | Pass: marker rewrites preserve unknown nested fields with strict duplicate validation. |

7. **Plan revision recommendations**

   Add a `## Revisions` entry correcting the ownership-record location and integration inventory. Record the shared absolute startup deadline and last-consumer cancellation/cleanup policy, including the new regression scenarios. Preserve the explicit M2 prerequisite for real-producer acceptance.

<!-- sdlc-review-usage [{"version":1,"intent":{"disposable_root":true,"id":"e58c4109-abfb-4384-a4ca-9adedec205f0","repository":"github.com/xianxu/parley.nvim","issue_id":"000405","recipe":"milestone-review","round":1,"attempt":1,"agent":"codex","root":"/Volumes/TestScratch/review-checkouts/a27e8ac1eb8c1a81","reviewed_head":"2b4916d7d41bf19cfcc4774381096c5fe6460041","slot":"parley.nvim:1","requested_at":"2026-10-22T13:06:25.711744Z"},"phase":"finished","pid":38707,"started_at":"2026-10-22T13:06:25.954374Z","finished_at":"2026-10-22T13:12:15.940146Z","session_id":"01a163b8-51df-7480-bf15-578e3861a2f4","outcome":"returned"}] -->

---

## Re-review — 2026-10-22T06:35:03-07:00 (REWORK)

| field | value |
|-------|-------|
| issue | 405 — remote-session: start a private RPC server when attached to a registered session file or side doc, and register its address with Couch |
| repo | parley.nvim |
| issue file | workshop/issues/000405-remote-session-start-a-private-rpc-server-when-attached-to-a-registered-session-file-or-side-doc-and-register-its-address-with-couch.md |
| boundary | milestone M1 |
| milestone | M1 |
| window | 4b8e61ed5f5b5b3ab969bc3df6314dac442e753c..a735c729fd37c90f6ef828eecaecad85286cbd31 |
| command | sdlc milestone-close --issue 405 --milestone M1 |
| reviewer | codex (openai; author openai) |
| isolation | fenced |
| timestamp | 2026-10-22T06:35:03-07:00 |
| verdict | REWORK |

## Review

```verdict
verdict: REWORK
confidence: high
```

The M1 foundation has strong ownership validation, bounded transport, and meaningful native tests. BR-2 through BR-5 are addressed. BR-1 remains partially unresolved: detaching the final consumer during listener reservation allows startup to continue and create a socket afterward.

```findings
dispose:
  - id: BR-1
    disposition: not-addressed
    note: |
      Queued publication and acquisition cancellation are fixed, with regressions that fail against the previous dispatcher. However, remote_session.lua:229 discards runtime.listen's operation handle; release_consumer at lines 36–44 cancels only acquisition, whose handle is cleared at line 92. A controlled native probe held first-listener reservation fsync, detached the final consumer, then released completion: cancellation calls were 0 and serverstart calls after detach were 1. Retain and cancel/join listener startup operations too, prevent subsequent startup effects after retirement, and add controlled reservation/publication cancellation tests. This remains the existing retirement-cancels-unstarted-effects family finding (ARCH-ORDER, ARCH-PURPOSE).
  - id: BR-2
    disposition: addressed
    note: |
      remote_runtime.lua carries the acquisition deadline into first-listener publication and clears it only after durable success. Both reservation and publication regressions pass at head and fail with the previous runtime loaded: 22 passed, 2 failed, 0 errors.
  - id: BR-3
    disposition: addressed
    note: |
      The plan's authoritative table now locates RuntimeOwnershipRecord in remote_runtime_record.lua:22, matching its computational codec and cleanup decision. The integration inventory at line 34 also names remote_runtime.lua's ownership shell. Both PURE entities have direct tests without IO dependencies.
  - id: BR-4
    disposition: addressed
    note: |
      Final consumer drain now closes the exact runtime without global frontend.close. The ordinary-detach regression at remote_session_spec.lua:426 passes at head and fails against the previous dispatcher; terminal-resource and attach-during-drain regressions also fail against that dispatcher.
  - id: BR-5
    disposition: addressed
    note: |
      README.md:208–213 documents --editor-endpoints --fake-only and the deferred producer/bridge prerequisites. This matches the script's options and the exercised fake/native probe, including its corrupt-reply negative control.
```

1. **Strengths**

   - Exact ownership checks preserve foreign or replaced runtime artifacts and pre-existing Neovim listeners.
   - Protocol validation preserves uncertain outcomes and fences acknowledgments by attachment identity.
   - Deadline and final-detach regressions demonstrably fail against the pre-fix modules.
   - Atlas, traceability, and README changes document the new M1 surface and its integration limits.

2. **Critical findings**

   **BR-1 remains open — `lua/parley/remote_session.lua:229`.** The listener operation escapes cancellation ownership after acquisition finishes. Retain its handle, cancel and join it when its consumer retires, and prevent further startup effects. Sweep acquisition, reservation, native listener creation, and durable publication under the same retirement rule; preserve exact cleanup for effects already completed.

3. **Important findings**

   None newly raised.

4. **Minor findings**

   None.

5. **Test coverage notes**

   - `make test-spec SPEC=modes/remote_session`: passed all 153 cases; process census clean.
   - Endpoint fake conformance and corrupt-reply negative control: passed.
   - In-memory pre-fix runtime: two deadline regressions failed.
   - In-memory pre-fix dispatcher: six lifecycle regressions failed.
   - Missing coverage: detach during listener reservation/publication. The held-source regression exercises acquisition only.
   - Repository files remain unchanged.

6. **Architectural notes**

   - **ARCH-DRY — pass:** existing transport and kernel lease are reused.
   - **ARCH-PURE — pass:** attachment transitions and ownership-record decisions are directly testable without IO.
   - **ARCH-PURPOSE — flag:** BR-1 leaves the promised cancellation contract incomplete.
   - **ARCH-MOCK — pass for M1:** stateful fixtures share production seams; real-producer acceptance remains explicitly deferred.
   - **ARCH-CONSTRAINTS — pass:** aggregate startup deadline is enforced and regression-tested.
   - **ARCH-SECURE — pass:** malformed ownership evidence is retained conservatively; destructive cleanup requires exact witnesses.
   - **ARCH-ORDER — flag:** BR-1 leaves listener startup outside the lifetime owner's cancellation path.
   - **ARCH-FUNERAL — pass for normal teardown:** final detach and terminal attachments release their runtime resources.
   - **ARCH-EVOLVE — pass:** marker tests verify nested unknown-field preservation and strict known-field/duplicate validation.

7. **Plan revision recommendations**

   Add a `## Revisions` entry enumerating cancellation ownership across acquisition, reservation, native listen, and durable publication, with controlled detach tests at each asynchronous boundary. Keep the existing cancellation requirement; complete its implementation.

<!-- sdlc-review-usage [{"version":1,"intent":{"disposable_root":true,"id":"3015590d-e175-4372-a526-3b622c7b7450","repository":"github.com/xianxu/parley.nvim","issue_id":"000405","recipe":"milestone-review","round":2,"attempt":1,"agent":"codex","root":"/Volumes/TestScratch/review-checkouts/ddfef1796eb77f5c","reviewed_head":"a735c729fd37c90f6ef828eecaecad85286cbd31","slot":"parley.nvim:1","requested_at":"2026-10-22T13:30:25.684184Z"},"phase":"finished","pid":94209,"started_at":"2026-10-22T13:30:25.859369Z","finished_at":"2026-10-22T13:35:02.894578Z","session_id":"01a163ce-4b5f-7412-87ed-b730abb4194b","outcome":"returned"}] -->

---

## Re-review — 2026-10-22T07:09:19-07:00 (FIX-THEN-SHIP)

| field | value |
|-------|-------|
| issue | 405 — remote-session: start a private RPC server when attached to a registered session file or side doc, and register its address with Couch |
| repo | parley.nvim |
| issue file | workshop/issues/000405-remote-session-start-a-private-rpc-server-when-attached-to-a-registered-session-file-or-side-doc-and-register-its-address-with-couch.md |
| boundary | milestone M1 |
| milestone | M1 |
| window | 4b8e61ed5f5b5b3ab969bc3df6314dac442e753c..1b91aadf4c99449d99397c3a7a0cecc46ccd61c6 |
| command | sdlc milestone-close --issue 405 --milestone M1 |
| reviewer | codex (openai; author openai) |
| isolation | fenced |
| timestamp | 2026-10-22T07:09:19-07:00 |
| verdict | FIX-THEN-SHIP |

## Review

```verdict
verdict: FIX-THEN-SHIP
confidence: high
```

M1’s cancellation correction is verified, including meaningful counterfactual failures. The focused suite passes on both supported runtimes. One inexpensive API correction remains: an acknowledgment rejected by the attachment model can still reach callers as `confirmed`. Automatic attachment wiring and real-producer acceptance remain explicitly scoped to M2.

```findings
dispose:
  - id: BR-1
    disposition: addressed
    note: |
      Exact listener handles are retained and canceled at remote_session.lua:43. Removing that call produced five dispatcher failures; reverting runtime finalization produced nine runtime failures. Pinned-head tests pass, including live-keeper continuity, reservation cleanup and slot reuse.
  - id: BR-2
    disposition: addressed
    note: |
      Acquisition carries ctx.deadline into resource.startup_deadline and the first listener transaction. Reservation/publication deadline regressions pass on both supported runtimes.
  - id: BR-3
    disposition: addressed
    note: |
      The pinned before/after diff corrects the Core concepts passage to RuntimeOwnershipRecord at lua/parley/remote_runtime_record.lua; that module implements the pure codec and cleanup decision.
  - id: BR-4
    disposition: addressed
    note: |
      Last-consumer draining reaches exact runtime close. The regression at remote_session_spec.lua:422 verifies removal of the final socket, marker and directory without closing the editor.
  - id: BR-5
    disposition: addressed
    note: |
      README.md:208 documents --editor-endpoints --fake-only and the real-producer prerequisites. The documented command passes and rejects its deliberately corrupted reply.
findings:
  - id: new
    severity: Important
    kind: defect
    family: validated-authority-outcomes
    title: |
      A rejected canonical-file acknowledgment is still reported as confirmed
    detail: |
      At lua/parley/remote_session.lua:131-135, dispatch can reject a binding whose File differs from the attachment identity, yet the shell checks and reports the original confirmed result. remote_session_model.lua:285 also stores that rejected result unchanged. A disposable native probe returning File=/different-document.md observed callback=confirmed and phase=unconfirmed, without an unavailable notice. Normalize rejected confirmations through the model’s accepted outcome, use that outcome for callbacks and notices, and add a dispatcher regression. ARCH-SECURE, ARCH-ORDER.
```

1. **Strengths**

   - Per-consumer cancellation now covers reservation, native listener creation, durable publication and delayed callback delivery.
   - Cleanup uses exact ownership witnesses and preserves foreign replacements.
   - Pure attachment transitions and marker validation have direct tests without IO mocks; integration tests control real IO completion ordering.

2. **Critical findings**

   None.

3. **Important findings**

   The finding above affects the new internal API’s reliability. Preserve the model’s safe refusal to activate, and make callback results, stored results and notices agree with that decision.

4. **Minor findings**

   None.

5. **Test coverage notes**

   - Focused mapping: **171 passed** on Neovim **0.12.5** and **0.11.7**; clean process censuses.
   - Lint: **0 warnings, 0 errors** across 834 files.
   - Endpoint fake conformance and corrupt-identity negative control passed.
   - Counterfactuals confirmed the cancellation regressions detect removed fixes.
   - The additional wrong-file probe failed as described above.
   - Disposable checkout removed; reviewed checkout unchanged.

6. **Architectural notes**

   - **ARCH-DRY — pass:** existing registry queue and allocation lease reused.
   - **ARCH-PURE — pass:** computational models remain separate from IO.
   - **ARCH-PURPOSE — pass for M1:** deferred M2 work is explicitly documented.
   - **ARCH-MOCK — pass for M1:** stateful fakes share production seams; real-producer qualification remains outstanding for M2.
   - **ARCH-CONSTRAINTS — pass:** bounded admission, deadlines and counted scaling tests.
   - **ARCH-SECURE — flag:** rejected external evidence still produces a confirmed public result.
   - **ARCH-ORDER — flag:** phase and reported outcome disagree in that same finding.
   - **ARCH-FUNERAL — pass:** cancellation joins cleanup; final consumers release resources.
   - **ARCH-EVOLVE — pass:** marker tests cover nested unknown-field preservation and strict duplicate/known-field validation.

7. **Plan revision recommendations**

   None required; the remaining correction enforces the existing acknowledgment-validation contract.

<!-- sdlc-review-usage [{"version":1,"intent":{"disposable_root":true,"id":"60178087-20d6-466e-8544-644f1b2bc26a","repository":"github.com/xianxu/parley.nvim","issue_id":"000405","recipe":"milestone-review","round":3,"attempt":1,"agent":"codex","root":"/Volumes/TestScratch/review-checkouts/bf660ed24e2a3884","reviewed_head":"1b91aadf4c99449d99397c3a7a0cecc46ccd61c6","slot":"parley.nvim:1","requested_at":"2026-10-22T14:04:21.316156Z"},"phase":"finished","pid":38139,"started_at":"2026-10-22T14:04:21.488193Z","finished_at":"2026-10-22T14:09:18.857247Z","session_id":"01a163ed-5ac1-7c11-a18c-c6bd35b84cd8","outcome":"returned"}] -->

---

## Re-review — 2026-10-22T07:26:18-07:00 (REWORK)

| field | value |
|-------|-------|
| issue | 405 — remote-session: start a private RPC server when attached to a registered session file or side doc, and register its address with Couch |
| repo | parley.nvim |
| issue file | workshop/issues/000405-remote-session-start-a-private-rpc-server-when-attached-to-a-registered-session-file-or-side-doc-and-register-its-address-with-couch.md |
| boundary | milestone M1 |
| milestone | M1 |
| window | 4b8e61ed5f5b5b3ab969bc3df6314dac442e753c..3ae643672ab1a24d763cd40141533899ec980d07 |
| command | sdlc milestone-close --issue 405 --milestone M1 |
| reviewer | codex (openai; author openai) |
| isolation | fenced |
| timestamp | 2026-10-22T07:26:18-07:00 |
| verdict | REWORK |

## Review

```verdict
verdict: REWORK
confidence: high
```

BR-6 is addressed with meaningful regression evidence. M1’s ownership, cancellation, transport, and documentation work is otherwise well supported. One new blocking defect remains: an unsupported filename can throw after listener creation and permanently stall the shared dispatcher. This reproduces on both supported Neovim versions.

```findings
dispose:
  - id: BR-1
    disposition: addressed
    note: |
      Exact listener cancellation remains implemented; queued-publication, held-startup, reservation/publication cancellation, and slot-reuse regressions pass on both runtimes.
  - id: BR-2
    disposition: addressed
    note: |
      Acquisition passes its absolute deadline into first-listener publication; reservation and publication deadline regressions pass on both runtimes.
  - id: BR-3
    disposition: addressed
    note: |
      The Core concepts table names lua/parley/remote_runtime_record.lua, whose implementation contains the pure ownership codec and cleanup decision.
  - id: BR-4
    disposition: addressed
    note: |
      remote_session_spec.lua:462 verifies final detach removes the listener, marker, and directory without closing the editor; it passes on both runtimes.
  - id: BR-5
    disposition: addressed
    note: |
      README.md:208 documents --editor-endpoints --fake-only and the deferred real prerequisites; the documented command passes its positive and corrupt-reply controls.
  - id: BR-6
    disposition: addressed
    note: |
      Model normalization and shell consumption of snapshot().result are reachable. Removing the correction produces 12 model failures and one dispatcher failure; pinned-head regressions pass.
findings:
  - id: new
    severity: Critical
    kind: defect
    family: validate-before-resource-allocation
    title: |
      Unsupported attachment paths throw after listener creation and wedge the dispatcher
    detail: |
      lua/parley/remote_session.lua:197-200 validates Namespace and DocumentID but not File against the complete attachment-context contract. A real canonical filename containing a newline passes preflight, starts a listener, then throws at model.new on line 238 because remote_session_model.lua:47 rejects that spelling. The exception skips done(listening) at line 254, leaving io_busy set. Native probes on 0.12.5 and 0.11.7 observed invalid attachment context, no attachment callback, and no subsequent ordinary-attachment or close callback. Validate the complete context through shared pure validation before allocating resources, handle rejected construction through normal cleanup/completion, and add a sequence regression proving a rejected attachment cannot block later attachment or close. ARCH-SECURE, ARCH-ORDER.
```

1. **Strengths**

   - The pure owner now controls accepted acknowledgment outcomes; callbacks, notices, and duplicate attachment responses consume that result.
   - Runtime cleanup preserves uncertain and replaced artifacts, with exact ownership checks before destructive operations.
   - Stateful process and Couch fixtures exercise production seams and controlled event ordering.
   - README, indexed atlas, and traceability cover the new M1 surface and explicitly identify M2 prerequisites.

2. **Critical findings**

   - **Attachment validation can strand the shared queue — `lua/parley/remote_session.lua:238`.** Apply the validation/completion rule above across every field passed to `model.new`, including `File` and the allocated socket path. Unsupported input must produce one terminal result and permit subsequent work.

3. **Important findings**

   None.

4. **Minor findings**

   None.

5. **Test coverage notes**

   - Focused mapping: **184 passed, zero failures/errors** on both Neovim **0.12.5 and 0.11.7**, with clean process censuses.
   - BR-6 counterfactual: **12 model failures and one dispatcher failure** without the correction.
   - Endpoint fake conformance and its corrupt-identity negative control passed.
   - The new filename sequence fails on both runtimes. [Probe evidence](/Volumes/TestScratch/parley-405-review.qicKbs/input-probe-sequence.log).
   - Real-producer acceptance remains explicitly deferred to M2. The disposable checkout was removed; the reviewed repository is unchanged.

6. **Architectural notes for upcoming work**

   - **ARCH-DRY — pass:** existing transport and lease seams are reused.
   - **ARCH-PURE — pass:** both declared pure entities have IO-free computational tests.
   - **ARCH-PURPOSE — pass for M1 scope:** automatic attachment wiring and real acceptance remain documented M2 work.
   - **ARCH-MOCK — pass for M1:** stateful doubles share production boundaries; real conformance remains outstanding.
   - **ARCH-CONSTRAINTS — pass:** bounded admission, deadlines, and counted workloads have executable coverage.
   - **ARCH-SECURE — flag:** complete context validation occurs after resource creation.
   - **ARCH-ORDER — flag:** constructor failure bypasses queue completion and teardown progress.
   - **ARCH-FUNERAL — pass structurally:** artifact removal and crash-residue collection are defined; the new finding interrupts normal cleanup progress.
   - **ARCH-EVOLVE — pass:** marker tests verify nested unknown-field preservation and strict duplicate/known-field validation.

7. **Plan revision recommendations**

   Add a `## Revisions` entry defining complete attachment-context validation before allocation and guaranteed completion/cleanup on rejection. Require a native sequence test: unsupported canonical filename → one unavailable result → ordinary attachment succeeds → close completes.

<!-- sdlc-review-usage [{"version":1,"intent":{"disposable_root":true,"id":"72d1245b-ab98-424b-b7ea-7faf5f1f8a8c","repository":"github.com/xianxu/parley.nvim","issue_id":"000405","recipe":"milestone-review","round":4,"attempt":1,"agent":"codex","root":"/Volumes/TestScratch/review-checkouts/fdff89dc44fd75be","reviewed_head":"3ae643672ab1a24d763cd40141533899ec980d07","slot":"parley.nvim:1","requested_at":"2026-10-22T14:19:27.681127Z"},"phase":"finished","pid":4997,"started_at":"2026-10-22T14:19:27.784398Z","finished_at":"2026-10-22T14:26:17.934885Z","session_id":"01a163fb-2db7-7de0-a101-866e044d9e3b","outcome":"returned"}] -->

---

## Re-review — 2026-10-22T07:49:51-07:00 (SHIP)

| field | value |
|-------|-------|
| issue | 405 — remote-session: start a private RPC server when attached to a registered session file or side doc, and register its address with Couch |
| repo | parley.nvim |
| issue file | workshop/issues/000405-remote-session-start-a-private-rpc-server-when-attached-to-a-registered-session-file-or-side-doc-and-register-its-address-with-couch.md |
| boundary | milestone M1 |
| milestone | M1 |
| window | 4b8e61ed5f5b5b3ab969bc3df6314dac442e753c..411be8ebf62e2b04ba101cd14225e04f13300a03 |
| command | sdlc milestone-close --issue 405 --milestone M1 |
| reviewer | codex (openai; author openai) |
| isolation | fenced |
| timestamp | 2026-10-22T07:49:51-07:00 |
| verdict | SHIP |

## Review

```verdict
verdict: SHIP
confidence: high
```

M1 is ready. BR-7 is addressed with executable regression evidence: removing the fix reproduced six pure-test failures and four native continuation failures. The focused suite passes on both supported runtimes. No new findings. Automatic attachment wiring and real-producer acceptance remain explicitly scoped to M2.

```findings
dispose:
  - id: BR-1
    disposition: addressed
    note: |
      Existing cancellation regressions pass, including held acquisition, queued registration, all four listener startup boundaries, cleanup joining and slot reuse.
  - id: BR-2
    disposition: addressed
    note: |
      remote_runtime.lua carries startup_deadline through first-listener durability; reservation and publication deadline regressions pass on both runtimes.
  - id: BR-3
    disposition: addressed
    note: |
      The plan's Pure entities table identifies remote_runtime_record.lua as RuntimeOwnershipRecord's location; that module implements the codec and cleanup decision.
  - id: BR-4
    disposition: addressed
    note: |
      Last-consumer drain closes the runtime automatically; final-detach cleanup and attach-during-drain regressions pass on both runtimes.
  - id: BR-5
    disposition: addressed
    note: |
      README.md documents --editor-endpoints --fake-only and the deferred real prerequisites; the parser implements that invocation and its fake conformance check passed.
  - id: BR-6
    disposition: addressed
    note: |
      The model normalizes unowned confirmations before storing results, and the dispatcher consumes that accepted result. Mismatched-identity and canonical-file regressions pass.
  - id: BR-7
    disposition: addressed
    note: |
      Shared validation precedes allocation and checks the allocated tuple; constructor refusal or exception follows cleanup/completion. Removing the production fix in a disposable checkout caused six pure failures and four native continuation failures, with zero test errors. Pinned-head tests pass.
```

1. **Strengths**

   - Shared admission validation covers the complete pending and listening tuples, with construction failures contained by the dispatcher (`remote_session_model.lua:226`, `remote_session.lua:205`).
   - Native continuation tests assert one rejection callback, successful subsequent attachment, completed close, resource cleanup and unchanged local editability (`tests/integration/remote_session_spec.lua:180`).
   - Runtime cleanup uses exact ownership witnesses and retains foreign or uncertain artifacts (`remote_runtime.lua:238`).
   - README, indexed atlas and traceability document the delivered foundation and its M2 boundaries.

2. **Critical findings:** None.

3. **Important findings:** None.

4. **Minor findings:** None.

5. **Test coverage notes**

   - `make test-spec SPEC=modes/remote_session`: **195 passed** on Neovim **0.12.5** and **0.11.7**; both process censuses clean.
   - Endpoint fake conformance and corrupt-identity negative control passed.
   - BR-7 counterfactual: **10 failures, zero errors** after restoring the pre-fix production files while retaining current tests.
   - Disposable checkout removed; reviewed checkout unchanged. Full repository suite and real-producer acceptance were not run in this review.

6. **Architectural notes for upcoming work**

   | Principle | Assessment |
   |---|---|
   | ARCH-DRY | Pass — shared field validation, registry transport and kernel lease reused. |
   | ARCH-PURE | Pass — attachment authority and cleanup decisions are IO-free; native effects remain in shells. |
   | ARCH-PURPOSE | Pass for M1 — lifecycle wiring and real acceptance are explicitly retained in M2. |
   | ARCH-MOCK | Pass for M1 — stateful endpoint/process fakes share production seams; real conformance remains unqualified. |
   | ARCH-CONSTRAINTS | Pass — capacity, byte, deadline and counted-work bounds have focused coverage. |
   | ARCH-SECURE | Pass — complete admission validation, private directories and conservative ownership checks. |
   | ARCH-ORDER | Pass — pure authority transitions and controlled startup/retirement sequences exercise production paths. |
   | ARCH-FUNERAL | Pass — cancellation joining, last-consumer cleanup and bounded crash-residue reclamation are covered. |
   | ARCH-EVOLVE | Pass — marker rewrites preserve unknown nested fields; strict known-field and duplicate-key tests pass. |

   Core-concept locations and classifications match the delivered M1 modules. The `session_sync.lua` and `init.lua` integration rows belong to the documented M2 work.

7. **Plan revision recommendations:** None.

<!-- sdlc-review-usage [{"version":1,"intent":{"disposable_root":true,"id":"ed381057-522d-43f9-bd65-00fac7aabb7b","repository":"github.com/xianxu/parley.nvim","issue_id":"000405","recipe":"milestone-review","round":5,"attempt":1,"agent":"codex","root":"/Volumes/TestScratch/review-checkouts/399bef0f1bce698b","reviewed_head":"411be8ebf62e2b04ba101cd14225e04f13300a03","slot":"parley.nvim:1","requested_at":"2026-10-22T14:46:18.28294Z"},"phase":"finished","pid":92898,"started_at":"2026-10-22T14:46:18.416208Z","finished_at":"2026-10-22T14:49:51.323465Z","session_id":"01a16413-c1c9-77a0-be00-bb25d4dd8827","outcome":"returned"}] -->
