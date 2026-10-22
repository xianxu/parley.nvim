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
