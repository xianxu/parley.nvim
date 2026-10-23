# Boundary Review — parley.nvim#405 (whole-issue close)

| field | value |
|-------|-------|
| issue | 405 — remote-session: start a private RPC server when attached to a registered session file or side doc, and register its address with Couch |
| repo | parley.nvim |
| issue file | workshop/issues/000405-remote-session-start-a-private-rpc-server-when-attached-to-a-registered-session-file-or-side-doc-and-register-its-address-with-couch.md |
| boundary | whole-issue close |
| milestone | — |
| window | 69657dfa119c3b70cd27dccca42db5c088bdf255..fcde202739ba3364c3015c1d0da9724a6a4f700d |
| command | sdlc close --issue 405 |
| reviewer | codex (openai; author openai) |
| isolation | fenced |
| timestamp | 2026-10-22T23:55:04-07:00 |
| verdict | SHIP |

## Review

```verdict
verdict: SHIP
confidence: medium
```

The pinned implementation matches the issue’s Spec and revised Plan. Attachment authority, private listeners, supersession, discovery, and teardown have substantive regression coverage. No blocking findings remain. Real-producer conformance was not independently rerun during this review.

```findings
dispose:
  - id: BR-1
    disposition: addressed
    note: |
      Exact listener handles and queued publication are canceled on retirement; controlled startup-stage, held-acquisition, and queued-register regressions pass.
  - id: BR-2
    disposition: addressed
    note: |
      resource.startup_deadline carries acquisition's absolute deadline through first-listener durability; both delayed-fsync regressions pass.
  - id: BR-3
    disposition: addressed
    note: |
      The plan's Core concepts table names lua/parley/remote_runtime_record.lua, where the implemented codec and cleanup decision reside.
  - id: BR-4
    disposition: addressed
    note: |
      The final-consumer drain automatically closes its runtime; final-detach directory-removal and attachment-during-drain regressions pass.
  - id: BR-5
    disposition: addressed
    note: |
      README.md:214 documents --editor-endpoints --fake-only; that exact invocation passed, including the corrupted-reply control.
  - id: BR-6
    disposition: addressed
    note: |
      The owner normalizes rejected confirmations and the dispatcher reports its accepted result. The regression passes at head and fails against the pre-fix model with confirmed instead of uncertain.
  - id: BR-7
    disposition: addressed
    note: |
      Shared pending/listening validation precedes allocation and activation; rejected-input and constructor cases verify completion, cleanup, subsequent attachment, and close.
  - id: BR-8
    disposition: addressed
    note: |
      Discovery failures share a lifetime-scoped notice owner. Native failure/reopen/stale-callback controls pass; the unavailable-command regression fails against the pre-fix implementation.
  - id: BR-9
    disposition: addressed
    note: |
      README.md:222 supplies the required absolute --bridge invocation, supported by argument validation in scripts/check-couch-registry-conformance.py; adjacent text covers build, PATH, and candidate selection.
```

**1. Strengths**

- The pure attachment model owns accepted authority and returns copied snapshots, preventing transport replies from bypassing ownership validation.
- Listener cleanup checks exact socket identity before `serverstop`, preserving foreign replacements (`lua/parley/remote_runtime.lua:263`).
- Tests control cancellation and acknowledgment ordering, including retirement before publication and late cleanup.
- README, indexed atlas documentation, and traceability mappings cover the new surface.

**2. Critical findings:** None.

**3. Important findings:** None.

**4. Minor findings:** None.

**5. Test coverage notes**

- Mapped suite: **275 passed, 1 failed, 0 errors**. The failure came from review scratch placement inside the checkout; the affected zero-config spec passed **9/9** with external isolated scratch.
- Fake/native endpoint conformance and its corrupted-reply control passed.
- BR-6 and BR-8 counterfactual regressions failed for their expected reasons.
- Final process census was clean; tracked files remain unchanged.

**6. Architectural notes**

| Principle | Result |
|---|---|
| ARCH-DRY | Pass — existing registry transport and lease reused. |
| ARCH-PURE | Pass — both declared pure entities have IO-free logic tests. |
| ARCH-PURPOSE | Pass — parent/side documents, outside-pane discovery, takeover, and teardown delivered. |
| ARCH-MOCK | Pass — stateful external doubles share production seams; native conformance driver provided. |
| ARCH-CONSTRAINTS | Pass — capacity, byte, queue, startup, and exit bounds exercised. |
| ARCH-SECURE | Pass — private directories, validated tuples, exact ownership checks. |
| ARCH-ORDER | Pass — authoritative transitions and controllable event sequences exercised. |
| ARCH-FUNERAL | Pass — ordinary cleanup, bounded residue, and death-proven reclamation defined. |
| ARCH-EVOLVE | Pass — unknown root/nested marker fields survive rewrites; malformed and duplicate fields are rejected. |

**7. Plan revision recommendations:** None. Existing revisions describe the implemented refinements.

<!-- sdlc-review-usage [{"version":1,"intent":{"disposable_root":true,"id":"4ca3fc2c-873d-4919-b307-bf484900c457","repository":"github.com/xianxu/parley.nvim","issue_id":"000405","recipe":"milestone-review","round":8,"attempt":1,"agent":"codex","root":"/Volumes/TestScratch/review-checkouts/ca7558981ab4af4d","reviewed_head":"fcde202739ba3364c3015c1d0da9724a6a4f700d","slot":"parley.nvim:1","requested_at":"2026-10-23T06:48:40.142714Z"},"phase":"finished","pid":11170,"started_at":"2026-10-23T06:48:40.267884Z","finished_at":"2026-10-23T06:55:03.667126Z","session_id":"01a16784-d44d-7750-a402-32d909052ddc","outcome":"returned"}] -->
