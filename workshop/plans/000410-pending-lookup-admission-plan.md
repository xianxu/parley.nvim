---
collaboration-mode: discussion
---

# Pending lookup admission implementation plan

> **For agentic workers:** Follow AGENTS.md Section 3 for execution and SDLC for review boundaries. Checkboxes below form one atomic implementation; no milestone tags.

**Goal:** Give an already pending registration lookup and any resulting operator acquisition one shared 500 ms input-admission budget.

**Architecture:** S1 owns a short-lived insert-entry scope tied to its exact controller incarnation and existing lookup witness. Adoption passes that scope to session-sync, which retains #408's private operator_admission owner and existing confirmed/refused/unavailable policies. The Couch process seam accepts an absolute deadline and consumes only its remaining time.

**Tech stack:** Lua, Neovim native input/autocmds, vim.system, existing filesystem-backed Couch fake, Python conformance runner.

## Existing contract and alternatives

#410's filed Spec is the requirements contract. #408 is landed; its private operator_admission module exclusively owns baseline, proof, token and outcome history. This work adds no alternate writer of those facts.

Recommended: carry one immutable absolute deadline through an ephemeral insert scope. A lookup-only wait followed by today's acquire violates the total budget. Deferring every attach/acquire to a new global coordinator would replace working background behavior and broaden the state machine unnecessarily. No synchronous discovery is started on InsertEnter.

## Core concepts

### Pure entities

| Name | Lives in | Status |
|------|----------|--------|
| `remaining_ms` | `lua/parley/couch.lua` | new |
| `dispatch` | `lua/parley/operator_admission.lua` | modified |

`remaining_ms` is arithmetic only: `math.max(0, math.floor(deadline_ms - now_ms))`. It takes clock readings as data and cannot refresh a deadline. Its arithmetic properties are tested directly without IO in `tests/unit/couch_spec.lua`. Keep it beside the existing timeout owner rather than introducing a new module for arithmetic (ARCH-DRY/PURE).

The document lifecycle's operation/witness model remains unchanged. The private operator_admission dispatch gains an internal `legacy_release` acquisition stage, retaining its existing public phases and sole ownership of baseline/content/history/proof/token. This stage is a continuation of acquisition, never an ordinary history-retiring release (history-preserving re-plan below).

### Integration points

| Name | Lives in | Status | Wraps |
|------|----------|--------|-------|
| `attach` | `lua/parley/agentic_document.lua` | modified | native InsertEnter, exact active lookup, bounded event-loop wait |
| `adopt` | `lua/parley/agentic_document.lua` | modified | registration adoption and session-sync handoff |
| `pending_lookup` | `lua/parley/agentic_document.lua` | new | exact eligible lookup in live controller state |
| `admit_insert` | `lua/parley/agentic_document.lua` | new | one bounded native input join shared by both callback owners |
| `attach` | `lua/parley/session_sync.lua` | modified | existing admission owner and nested late attachment |
| `acquire_observed` | `lua/parley/session_sync.lua` | modified | observed edit handoff into existing admission dispatcher |
| `finish_input_scope` | `lua/parley/session_sync.lua` | new | exact-scope cleanup after native input wait |
| `operator_lock` | `lua/parley/couch.lua` | modified | synchronous operator acquire process and wait |
| stateful registry/operator fixtures | `tests/helpers/fake_couch.lua`, `tests/fixtures/fake_couch_registry.py`, `tests/fixtures/fake_couch_operator.py` | modified as needed | controlled request completion and persisted registration/lock state |

Extend the internal attachment/observed-acquire handoff with an optional admission scope, preserving current callers. `M.operator_lock(verb, identity, token, deadline_ms)` defaults to its existing per-call 500 ms behavior when no enclosing scope exists. Ordinary registered/legacy release remains unchanged; the separate acquisition continuation below does not retire history. No new producer protocol is required.

## Scheduling and ownership

Whichever controller already owns native InsertEnter invokes S1's shared `admit_insert`. `pending_lookup` supplies only an existing eligible lookup for the exact loaded buffer/path/namespace/incarnation without confirmed identity. The first join snapshots its witness and allocates one absolute deadline `now + couch.OPERATOR_LOCK_TIMEOUT_MS` before yielding to vim.wait; reentry joins that scope. S1's own callback does not start a second wait when session-sync already owns entry. The legacy callback therefore cannot establish tokenless protection ahead of pending discovery. An unresolved pending lookup defers legacy writes while feeding the first observed pre-edit baseline into the private owner; proven absence returns to existing legacy behavior without another Couch wait.

~~The scope has only `waiting`, `acquiring`, `settled`, `closed` phases.~~ The scope uses a deadline, original incarnation/witness, one attempted/result guard and a closed marker; these schedule the single input event and never duplicate lock/history state (Revision below). It is private to this input event; no module-global active deadline. Joining another callback cannot allocate a replacement scope. A nested callback for the same scope reuses it; an irrelevant or stale controller cannot receive it. Clear by exact scope identity on all exits, including errors, detach and supersession.

Lookup completion uses normal lifecycle dispatch and `adopt`. Adoption forwards the exact live scope through both attachment and outstanding-edit reconciliation. Session-sync's first acquire for that scope marks it acquiring before effects; further entry/observed callbacks join its result rather than launching another acquisition, including when the first result is unavailable/refused. The original admission owner still makes every lock/history transition. Do not write admission history from S1 or store parallel proof/token/baseline fields on the scope.

Before spawning operator-acquire, compute the remaining budget. Zero means the existing unavailable policy without spawning a process. Otherwise pass that remaining amount to both vim.system timeout and wait; never use a fresh 500. Confirmed acknowledgment still needs exact proof plus completed clean freshness before input. Native reload's local work is measured as part of entry latency; the deadline prevents additional blocking waits, not preemption of arbitrary third-party autocmd execution.

After the joined operation completes, is superseded, or exhausts the deadline, end the input wait and close its scope. Do not cancel discovery. If lookup is still pending, allow today's unknown-period input; later completion follows normal attachment and outstanding-edit reconciliation outside the completed entry scope. The closed scope cannot govern a later insert or a different buffer. Discovery absence/failure does not start another lookup inside this wait.

## State and recovery table

Actions: type, leave insert, retry existing refused admission, submit existing edits.

| Internal state / failure mode | Visible state | Recovery action | Possible loss |
|-------------------------------|---------------|-----------------|---------------|
| No qualifying pending lookup | Current ordinary-file behavior | type | Existing unknown-period conflict risk |
| Lookup pending inside budget | Input briefly waits; no new notice | type once wait ends | None from waiting |
| Lookup confirms; acquire confirms; clean freshness completes | Existing protected operator turn, fresh content | type | None; modified text retains existing conflict safety |
| Lookup confirms; acquire held/invalid/uncertain | Existing refused band; queued keys not applied | retry existing refused admission | Queued keys intentionally discarded, no buffer edits discarded |
| Lookup confirms; remaining acquire budget exhausted/unavailable | Existing not-locked warning | type | Existing concurrent-write risk; preserve clobber-copy behavior |
| Lookup still pending at deadline | Existing editable unknown period | type | Existing concurrent-write risk; later reconciliation retains edits |
| Lookup returns absent/failure | Current unknown/plain behavior | type | No newly claimed protection |
| Detached/replaced controller or superseded witness | No stale gating or attachment | type in current buffer | No old callback may affect new text |

No new operator choice, refusal policy, recovery command, persisted state or producer acknowledgment shape. Process death leaves only #408's existing uncertain/held protection handling. Closing the wait never proves lookup absence or acquisition failure (ARCH-STATE).

## Operating envelope and lifecycle

- Interaction path: InsertEnter, not every keystroke. Required total blocking wait budget is 500 ms from the outer entry, shared by discovery and acquire. Test wall time with harness scheduling allowance and independently assert each requested inner timeout against the original deadline.
- Growth drivers: N qualifying entries, B loaded buffers, document size L for existing freshness hashing/reread. At most one joined lookup and one acquire attempt per entry; zero added process launches for ordinary entries. Inspect only the exact buffer's existing operation, no B-buffer scan. Existing document hashing remains O(L); this work adds no full-content scan per polling tick.
- Count N=4 and 2N=8 entries: new discovery launches = 0; acquire attempts <= N; record full reads and ensure no superlinear increase over existing freshness work. Use counters, not elapsed time alone.
- Event ordering: scheduled lookup completion, native late attach, queued input and native reread are controlled in embedded Neovim tests. No live fleet test. CPU contention permits test observation slack, never a new production deadline.
- Scope exists only during the outer input admission, cleared in a protected cleanup path. Existing registry request retains its own bounded lifetime and owns cancellation on controller retirement. No new timer, subprocess family, cache, file or durable format (ARCH-FUNERAL/EVOLVE).
- External replies still cross the existing registry classifier and operator_result proof validator; stale witnesses remain ignored. Fixtures use disposable roots and no live credentials, stores or documents (ARCH-SECURE/MOCK).

## Implementation tasks

### Function-level verification strategies

| Functions under test | Adversarial strategy and mechanical guard |
|----------------------|------------------------------------------|
| `remaining_ms` | Arithmetic boundary properties over monotonic inputs; assert nonnegative clipping and no deadline renewal without IO. |
| `operator_lock` | Controlled clock/spawn progression plus a real hung child; assert every requested timeout is bounded by the original deadline and expired work creates no child. |
| S1 `pending_lookup`, `admit_insert` | Native event scheduling with real fake-backed discovery and superseded controller witnesses; assert one joined request, one total deadline, and no effects on another incarnation. |
| S1 `adopt`; session-sync `attach`, `acquire_observed` | Production attachment order and controlled external writes across the existing/new-controller boundary; assert first-input proof/freshness and retention of the original saved-edit baseline. |
| operator_admission `dispatch` | Controlled event-sequence tests against the actual pure transition function; assert baseline/history invariance through handoff failures and ignore outcomes whose witness was superseded. |
| Native legacy handoff IO | Stateful sidecar replacements and exact ownership evidence; assert only proven owned bytes may be removed and refused input never gets a writable gap. |

The native counted workload tests compare 4 and 8 entries, with process/read counters that reject worse than linear growth. Supported runtime and disposable producer conformance checks remain below. This strategy table replaces prose test-case inventories (PQ-2).

### Task 1: Native red cases for pending discovery

Files: `tests/integration/session_sync_native_spec.lua`, `tests/integration/agentic_document_lifetime_spec.lua`, existing fake helpers/fixtures if controlled completion needs a seam.

- [ ] Preserve production controller attachment order in the native helper and implement the S1/adoption strategies above with actual queued input and the shared stateful fake.
- [ ] Run `make test-spec SPEC=modes/session_sync` and observe relevant new cases fail for the intended ordering/budget reasons before implementation. Preserve logs in disposable scratch.

### Task 2: Shared deadline and one acquire per scope

Files: `lua/parley/couch.lua`, `lua/parley/agentic_document.lua`, `lua/parley/session_sync.lua`, `lua/parley/operator_admission.lua`, `tests/unit/couch_spec.lua`, `tests/unit/operator_admission_spec.lua`.

- [ ] Write the pure arithmetic, process deadline and history-preserving owner sequence tests using the named strategies above.
- [ ] Red-run `make test-spec SPEC=modes/review` (the mapping containing `couch_spec.lua`); implement arithmetic and optional absolute-deadline argument in the existing seam.
- [ ] Implement the shared entry contract and owner-controlled acquisition continuation below; retain one attempt/deadline and exact scope cleanup.
- [ ] Green-run the named native/owner strategies with counted effects and measured deadline evidence.
- [ ] Commit code/tests with issue reference, Co-Authored-By and session Agent trailer after targeted green evidence.

### Task 3: Bounds, conformance and acceptance

Files: native/integration tests above, `tests/unit/operator_admission_spec.lua` only if interface usage needs additional sequence coverage, `README.md`, `atlas/modes/session_sync.md`, `atlas/traceability.yaml` only for new files.

- [ ] Run counted growth tests, architecture guards (including sole admission ownership and spec authoring), and `make lint`; preserve the existing native regression mapping.
- [ ] Run focused mappings serially on preferred runtime and installed operator runtime using environment `PARLEY_TEST_NVIM`; identify exact executable paths from harness/tooling rather than assume versions.
- [ ] Run `python3 scripts/check-couch-registry-conformance.py --fake-only` and `make check-couch-registry-conformance` against a disposable real Couch supporting the landed operator protocol. Extend only the existing probe if residual timeout semantics require new real-command evidence.
- [ ] Document the pending-lookup shared budget and retained editable-unknown boundary; keep atlas links and mapped tests consistent. Record measured timing/counters and deferred approvals in issue Log.
- [ ] Push via `sdlc pr`; run recorded `sdlc local-check run --name suite` on pushed head. Send TL results and request the required disposable real-profile live check before landing. Any :0 stage/visible editor action requires TL authorization; no live store/documents touched.
- [ ] Close through `sdlc close --issue 410 --verified '<measured evidence>'` after required checks; its fresh-context review owns this boundary. Report PR and review/live-check result to hub and await SHIP for merge.

## Approval checkpoint

TL approved via a1825097 before change-code and implementation. Recorded suite and SDLC review precede the separately authorized disposable operator-profile live check; ask TL before any :0 stage and preserve #411's stage ownership.

## Revisions

### 2026-10-22 — native timing and explicit insert intent

TL approval a1825097 accepted this design before implementation. The quick-flow change-code gate passed. Native red reproduced input before acquisition in both parent/side cases and premature input while lookup remained pending; Couch seam red reproduced five missing residual-budget behaviors.

Native late attachment reports mode `n` during InsertEnter, so the exact live scope explicitly carries insert intent into attachment. Scope cleanup has its own small integration function, `M.finish_input_scope`, checking exact reference identity. The scope's attempted/result guard represents a single synchronous call; no additional history model or user-visible state was introduced.

The timeout-only native input wait overran to the registry timeout (measured 14889 ms). An explicit monotonic deadline predicate, within the approved absolute-deadline mechanism, restored the bound (measured 500.25 ms) while leaving discovery outstanding. Focused native cases now cover confirmed freshness, bounded pending fallback and late saved-edit reconciliation, nested residual acquisition, held/invalid refusal, absence and stale detach/rename. The full native file and broader checks remain required. Test helpers use actual S1 buffer IDs; unlike session-sync, S1 does not normalize buffer 0.

### 2026-10-22 — late autosaved baseline and architecture inventory

Preferred native 153/0/0; operator 0.11.7 exposed late attachment acquiring a saved edited snapshot before the existing observed-edit handoff. Adoption now supplies observed edits through attach's existing observed argument before its automatic insert acquisition; the private owner and failure policy are unchanged. This directly fulfills the existing late-reconciliation acceptance criterion. Architecture checks require individual public-symbol table rows; normalized those names and retained direct synchronous spawn/wait expression for the existing spawn census.

Both-runtime focused corrections pass 80/0/0, including the late saved-baseline cases, 4/8-entry counters and affected architecture guards. Broader map: 840 pass with only the three subsequently corrected inventory/classification failures. Isolated real/fake conformance and final lint pass. Independent #408 native o-retry timing is filed as #412, per TL; it is not a change to #410's scope or lock policy.

### 2026-10-22 — BR-1 production attachment order; proposed correction

Round-one boundary review returned REWORK with Critical BR-1, family `admission-handoff-covers-existing-controllers`. Verified source: setup_markdown_keymaps attaches session-sync before S1. Typed session files therefore already have the legacy controller/InsertEnter callback; current existing-controller attach updates identity and returns. Its earlier callback can take tokenless protection, and acquire_observed then sees an operator turn and skips registered acquisition. Review probes reproduced zero acquisitions/stale first input on both runtimes and zero acquisitions with saved edits. The native helper's detach masked this production consumer. The old queued suite was explicitly cancelled (lease-1901041664); it cannot verify this correction.

Proposed design, awaiting TL approval before code:

1. Extract S1's exact pending predicate and bounded input join into reusable `pending_lookup` and `admit_insert` integration functions, retaining one absolute-deadline scope and one original request. The document's InsertEnter callback invokes the join only when no session-sync controller already owns entry.
2. Session-sync's pre-existing legacy InsertEnter callback invokes S1's join BEFORE any tokenless write; if joined, return after that same admission (including timeout/absence) rather than starting another wait/acquire. Normal-mode legacy edit observation also defers tokenless writes while this exact S1 lookup remains pending; S1 retains the existing outstanding-edit baseline for later attachment. Outside pending S1 discovery, legacy behavior stays unchanged.
3. Existing-controller adoption consumes the same scope, applies observed edits first, and invokes its registered acquisition entry directly when scope/actual insert intent is active. It must not return merely because a controller exists or a legacy turn reads operator. Acquisition remains in the private operator_admission owner, with only residual deadline time and one attempt guard.
4. The proposed ordinary release/reacquire sequence is superseded by the history-preserving re-plan below (PQ-1); no ordinary released event may clear history mid-acquisition.
5. Preserve production controller attachment order in the native verification strategies above, using counted effects and independently stated input/history invariants. Reproduce BR-1 before implementation.

The invariant is one S1 lookup scope and one registered acquisition attempt for the exact input event, regardless of which module's native callback runs first. The controller/owner resource already exists; the fix routes every entry consumer to it instead of observing absence twice (ARCH-DRY/PURPOSE/STATE). No new UI state, recovery command, watcher, journal or producer acknowledgment format. New public integration names get individual Core-concept rows when approved. Re-run change-code for the revised design; if the diff exceeds the quick shell, use its full-flow plan-quality gate before implementation.

### 2026-10-22 — history-preserving re-plan after PQ-1/PQ-2

TL c8405302 approved the first production-order correction and required a re-plan if review found another mechanism hole. The full plan-quality review identified PQ-1: ordinary `released` clears baseline/content/history (`operator_admission.lua:78–80`) and cannot be used mid-handoff. Stopped before code. PQ-2 requests function-level strategies rather than prose case inventories; the active verification table/tasks above now use that form.

The simplest alternative, ordinary release followed by shell-held baseline restoration, fails because it retires owner history and temporarily restores the edit gate before reacquisition; failure/expiry can then leave saved work unanchored. Refusing every locally owned legacy turn avoids deletion but strands an otherwise provable turn and does not fulfill existing-controller adoption. Use one acquisition operation owned by the existing private model instead:

- `dispatch(acquire)` captures freshness eligibility against the original history. When this owner has a non-nil exact tokenless proof, it emits `legacy_release`, retaining baseline, content, history and old proof; the requested registered token and freshness snapshot live only on that operation record. The public phase remains acquiring.
- The shell removes only matching exact legacy bytes and returns the existing witnessed released/release_failed outcome. Ordinary release handling remains separate by operation kind. A foreign replacement or missing/unknown witness produces no deletion and no producer acquire.
- A released outcome matching `legacy_release` clears only the now-removed proof, adopts the pending registered token, and immediately emits acquire under a new operation witness. It preserves original baseline/content/history and the original freshness eligibility. It does not enter idle, restore modifiable, or expose an intermediate completion to the caller. The subsequent acquire still receives the original scope deadline.
- A release failure matching this stage enters the existing refused phase, retains exact proof/tokenless baseline/history and blocks input through existing retry mappings. A superseded/duplicate outcome does nothing. No new phase or recovery action is introduced.
- After successful legacy removal, expiry/unavailability retains original history and saved edits in the existing editable unconfirmed phase; refusal retains them in the existing blocked phase. Confirmed clean freshness may advance a baseline only if the original history had no outstanding edit and the content witness still matches. A clean reload during the handoff updates that eligibility snapshot through the existing reload fact. Dirty or auto-saved outstanding work remains ineligible for clean freshness throughout.
- While discovery is pending, legacy edit observation feeds the original pre-edit baseline to the private owner without writing a tokenless lock. This retains the first unknown-period edit even if discovery later fails and legacy behavior resumes before a retry confirms registration.

This is a history-preserving continuation of the already approved exact owned-proof exception, with one owner and one producer acquisition; no ordinary release/reset, shell rollback, new protocol or parallel history cache. New owner dispatch sequence tests use controlled witnesses/failures and assert invariant history after each event. No implementation may resume until the TL reviews this re-plan and the plan-quality gate clears.

### 2026-10-22 — retire-legacy alternative requested by TL

Retiring tokenless admission outright for files the registered owner can admit would remove future mixed-protocol turns, and is a reasonable separate simplification. Retiring it only after registration is confirmed does not remove #410's handoff: an existing controller may already hold exact tokenless proof when pending discovery completes, so that proof and its original edit history still require a transition. Retiring it before confirmation would also change admission for typed files whose lookup is absent, unavailable or still pending, removing their existing legacy protection and retry behavior; #410 explicitly retains the editable unknown-period fallback and existing admission policy. That broader policy choice needs operator approval and migration/recovery criteria rather than being folded into this lookup-budget fix. The proposed continuation therefore handles already-owned turns while pending discovery defers new tokenless writes. TL f0654bf4 approved returning this design to plan-quality and required stopping, without another patch, if it identifies a further handoff hole; in that event the hub will take retirement to the operator.

### 2026-10-22 — BR-2; implementation stopped without another delta

Plan-quality accepted the owner continuation (PQ-1/PQ-2 addressed, no new findings). R2 boundary review disposed BR-1 addressed but found Critical BR-2: background absent completion never settles a legacy turn whose lock write was deferred during discovery. Existing normal-mode legacy regression fails at the new head and passes with prior modules. This is the second finding in the existing-controller admission family. Do not implement another continuation under this plan; the TL/operator must decide the retire-legacy policy question above and authorize any subsequent design. The obsolete queued suite was cancelled; live acceptance and staging remain unrun. Review ledger and sidecar carry the evidence.
