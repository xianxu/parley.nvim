# Boundary Review — parley.nvim#405 (milestone M2)

| field | value |
|-------|-------|
| issue | 405 — remote-session: start a private RPC server when attached to a registered session file or side doc, and register its address with Couch |
| repo | parley.nvim |
| issue file | workshop/issues/000405-remote-session-start-a-private-rpc-server-when-attached-to-a-registered-session-file-or-side-doc-and-register-its-address-with-couch.md |
| boundary | milestone M2 |
| milestone | M2 |
| window | d4f332353feca049bb17eb68643b40a66176d25d..6b35f51b1b61a3c440775c213b63876344b35562 |
| command | sdlc milestone-close --issue 405 --milestone M2 |
| reviewer | codex (openai; author openai) |
| isolation | fenced |
| timestamp | 2026-10-22T23:24:09-07:00 |
| verdict | FIX-THEN-SHIP |

## Review

```verdict
verdict: FIX-THEN-SHIP
confidence: medium
```

The endpoint lifecycle, bounded exit cleanup, ownership checks, and native tests are strong. Two Important gaps remain: failed outside-pane discovery is silent, and README omits the newly required real-conformance invocation. The focused suite also had one zero-config failure described below; it was not established as a regression from this range.

```findings
findings:
  - id: new
    severity: Important
    kind: defect
    family: visible-remote-availability-failures
    title: |
      Report unavailable outside-pane discovery
    detail: |
      lua/parley/remote_session.lua:370-374 handles only registered results and silently drops unavailable discovery, contradicting the plan's promised remote-unavailable notice. A production-observe probe returning unavailable produced one lookup, zero notices and zero allocations; duplicate observe did not retry. ARCH-PURPOSE, ARCH-SECURE: distinguish positive absence from discovery failure, emit one bounded notice per buffer incarnation, and sweep discovery-to-attachment rejection paths. Add regressions covering timeout/malformed results, silent positive absence, and duplicate-event deduplication.
  - id: new
    severity: Important
    kind: defect
    family: readme-runnable-surface-documentation
    title: |
      Document the required real-conformance bridge invocation in README
    detail: |
      scripts/check-couch-registry-conformance.py:175-186 adds --bridge and requires it for real endpoint conformance, but README.md:213-218 still documents only fake-only execution and prerequisites; README is unchanged in this range. This is the 2nd finding in family readme-runnable-surface-documentation. Earlier rounds fixed instances. State and apply the rule across the changed runnable surface: every introduced or changed invocation must have usable README guidance. Document the real command, absolute bridge requirement and native Neovim selection; atlas/modes/remote_session.md already supplies the concrete referent. No wording-presence test is needed.
```

1. **Strengths**

   - The pure exit composer validates every binding, preserves exact generations, and compares decimal attachment IDs without floating-point conversion (`remote_session_model.lua:150`).
   - Exit batches share one queue-inclusive deadline; tests cover occupied transport slots, delayed replies, and multiple namespaces.
   - Native tests cover passive rereads, explicit reopen, move interruption, parent/side documents, and actual quit ordering.
   - Runtime fixtures guard the real default parent and retain replaced or unconfirmed cleanup roots.

2. **Critical findings**

   None.

3. **Important findings**

   The two findings above need correction before close. Discovery failures need behavioral regression tests; the README repair needs source-and-command inspection.

4. **Minor findings**

   None.

5. **Test coverage notes**

   Ran the required stat/name-status inspections, targeted patches, `git diff --check`, and `make test-spec SPEC=modes/remote_session`.

   Endpoint-related checks passed, including 44 runtime, 31 dispatcher, 13 native lifecycle, 10 exit, 3 native quit, 62 attachment-model, and 17 ownership-record cases. Bridge protocol tests passed; the final process census was clean.

   The focused command exited nonzero because the zero-config chat test selected the checkout’s `workshop/parley` directory instead of scratch storage. It left untracked `workshop/parley/2026-10-22.23-22-27.393.md`; I left it untouched. Real-producer conformance was not rerun in this review.

6. **Architectural notes**

   - **ARCH-DRY — pass:** existing registry transport and ownership helpers are reused.
   - **ARCH-PURE — pass:** attachment authority and batch composition remain directly testable without IO.
   - **ARCH-PURPOSE — flag:** discovery failure omits the planned visible recovery guidance.
   - **ARCH-MOCK — pass:** stateful executable fakes exercise the production seams.
   - **ARCH-CONSTRAINTS — pass:** bounded capacities, shared deadlines, and scaling controls are exercised.
   - **ARCH-SECURE — flag:** discovery uncertainty currently degrades silently.
   - **ARCH-ORDER — pass:** controlled late replies, retirement, reopen, and native exit ordering are covered.
   - **ARCH-FUNERAL — pass:** listeners, runtime residue, bridge processes, and fixture roots have named cleanup owners.
   - **ARCH-EVOLVE — pass:** ownership-record tests preserve unknown root and nested members while rejecting malformed known fields.

   Atlas covers the new architecture. README fails the runnable-surface update gate.

7. **Plan revision recommendations**

   Add a `## Revisions` entry specifying discovery outcomes: positive absence stays silent; unavailable or rejected discovery produces one notice; duplicate events do not retry; explicit reopen permits fresh discovery. Record the regression enumeration and README invocation sweep.

<!-- sdlc-review-usage [{"version":1,"intent":{"disposable_root":true,"id":"2bbf7b4d-ee55-4f16-a8f6-dbc99491c11a","repository":"github.com/xianxu/parley.nvim","issue_id":"000405","recipe":"milestone-review","round":1,"attempt":1,"agent":"codex","root":"/Volumes/TestScratch/review-checkouts/3bd173b7adfcdbd3","reviewed_head":"6b35f51b1b61a3c440775c213b63876344b35562","slot":"parley.nvim:1","requested_at":"2026-10-23T06:20:36.303908Z"},"phase":"finished","pid":79298,"started_at":"2026-10-23T06:20:36.409341Z","finished_at":"2026-10-23T06:24:08.111983Z","session_id":"01a1676b-22bd-78b2-8df1-857f77225bbe","outcome":"returned"}] -->
