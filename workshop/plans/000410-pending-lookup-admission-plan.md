---
collaboration-mode: discussion
---

# Pending lookup admission implementation plan

> **For agentic workers:** Follow AGENTS.md Section 3 for execution and SDLC for review boundaries. Checkboxes below form one atomic implementation; no milestone tags.

**Goal:** Give an already pending registration lookup and any resulting operator acquisition one shared 500 ms input-admission budget.

**Architecture:** S1 owns a short-lived insert-entry scope tied to its exact controller incarnation and existing lookup witness. Adoption passes that scope to session-sync, which retains #408's private operator_admission owner and existing confirmed/refused/unavailable policies. The Couch process seam accepts an absolute deadline and consumes only its remaining time.

**Tech stack:** Lua, Neovim native input/autocmds, vim.system, existing filesystem-backed Couch fake, Python conformance runner.

> **Active design:** the RETIRE revision at the end of `## Revisions` supersedes the earlier implementation tasks and compatibility mechanism. Earlier text is retained as design history; its tables are marked historical. No code is authorized until the TL agrees the existing-lock/journal rule and fresh plan-quality clears.

## Existing contract and alternatives

#410's filed Spec is the requirements contract. #408 is landed; its private operator_admission module exclusively owns baseline, proof, token and outcome history. This work adds no alternate writer of those facts.

Recommended: carry one immutable absolute deadline through an ephemeral insert scope. A lookup-only wait followed by today's acquire violates the total budget. Deferring every attach/acquire to a new global coordinator would replace working background behavior and broaden the state machine unnecessarily. No synchronous discovery is started on InsertEnter.

## Core concepts

### Pure entities

| Name | Lives in | Historical status |
|------|----------|--------|
| `remaining_ms` | `lua/parley/couch.lua` | new |
| `dispatch` | `lua/parley/operator_admission.lua` | modified |

`remaining_ms` is arithmetic only: `math.max(0, math.floor(deadline_ms - now_ms))`. It takes clock readings as data and cannot refresh a deadline. Its arithmetic properties are tested directly without IO in `tests/unit/couch_spec.lua`. Keep it beside the existing timeout owner rather than introducing a new module for arithmetic (ARCH-DRY/PURE).

The document lifecycle's operation/witness model remains unchanged. The private operator_admission dispatch gains an internal `legacy_release` acquisition stage, retaining its existing public phases and sole ownership of baseline/content/history/proof/token. This stage is a continuation of acquisition, never an ordinary history-retiring release (history-preserving re-plan below).

### Integration points

| Name | Lives in | Historical status | Wraps |
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


### 2026-10-22 — RETIRE: one S1 admission route (active design, awaiting TL agreement)

**Authority and delta.** TL delivery 8f18c995 reports the operator chose RETIRE. This revision supersedes the original scheduling/compatibility implementation tasks and the history-preserving legacy_release continuation. Keep the shared absolute-deadline seam and #408's owner; remove the dual-protocol handoff. PR #333 remains unlanded. The card's previous remaining-work estimate describes the superseded scope; derive the revised estimate only after fresh plan-quality accepts this design.

**Requirement.** From file opening, a live S1 controller owns admission for that exact buffer/path/pane namespace, whether membership is confirmed, absent, pending or unavailable. It never creates a tokenless operator turn. Typed session-sync files without confirmed registration stay editable and visibly not protected; the first explicit submit registers through the existing path. Outside S1, standalone legacy behavior is unchanged. A confirmed registered identity uses #408 acquisition and freshness; joining an existing lookup still shares one original 500 ms deadline, one producer attempt and exact incarnation/witness cleanup.

**Chosen alternative.** Turning legacy off only after discovery preserves the same handoff family; adding terminal legacy-restoration callbacks preserves two admission protocols. The operator instead chose retirement at S1 ownership from opening. This is a policy change for unregistered/unknown typed files, not a promise to retrofit registered proof onto old locks (ARCH-PURPOSE/DRY).

#### Existing-lock and journal rule — requires TL agreement before code

1. **No old proof:** S1 may track edits while unregistered but cannot create a tokenless sidecar. Upon confirmed registration, the ordinary #408 owner admits with its original observed pre-edit baseline, including autosaved edits. Absence, failure and scope expiry never restore a legacy writer; the not-protected indication remains until registration.
2. **Proven live tokenless turn:** preserve its exact owned bytes, baseline and history. A registered acquisition request refuses locally without creating a registered token, deleting/replacing protection, or emitting an acquisition continuation. The existing explicit Alt+Return save/release/send path may finish this exact owned turn; it uses ordinary witnessed release and only then retires that turn's history. Registration/lookup completion and inside-S1 Esc/undo do not release the old turn automatically. A later input event can start an ordinary registered turn after explicit completion. Outside S1, existing baseline-release behavior remains unchanged.
3. **Unproven/replaced/foreign old sidecar:** do not adopt it from disk or infer authority from its age, filename or header. Registered admission and submission retain refusal; Retry cannot unlock it. The message names the file and asks for the original owner to finish/release the turn. After restart without live proof or a validated journal there is no safe plugin unlock command: the operator must arrange an explicit release of that single identified lock with its owner. No new generic unlock command, bulk cleanup, guessed token or automatic conversion is included.
4. **Existing v1/v2 move journal:** preserve the record and exact persisted protection. Leave Insert mode and reopen the destination, or use the existing displayed save/Alt+Return retry, to resume the same validated intent. Recovery continues under the existing ID lease and checks namespace, tuple, hashes, editor preimage, exact lock bytes and persisted finalization before each effect; journal removal remains last. A journal may reinstall/copy its already-authorized old proof to finish that existing move; this is not permission to begin a new tokenless turn. Failed validation leaves the record/protection interrupted, never swept. Normal admission waits for that recovery to finish.
5. **New move:** an old tokenless sidecar is not authority to begin another move or mint a new journal. New moves use the same registered-owner admission/owned-proof check; old or unknown protection refuses with the same finish/release guidance. Existing journal recovery stays on its distinct validated restore/finalization seam.

The explicit compatibility operations above finish an old resource; none silently replaces it with a new registered acquisition. No new phase, journal format, producer command or parallel history store is introduced. An unknown file remains editable; confirmed membership with refused protection retains #408's input gate. No claim that a stopped supervisor alone makes local Couch commands unavailable.

#### Active core concepts

Relationships: S1 owns one admission policy for one exact live controller; the temporary insert scope references that controller and its original lookup witness. Registered baseline/proof/token history remains exclusively in operator_admission. S1's existing pre-adoption observation is transferred once at adoption, never reconstructed from an autosaved snapshot. Old turn completion and journal restoration reuse the existing owner and exact-proof seams.

| Name | Lives in | Status |
|------|----------|--------|
| `remaining_ms` | `lua/parley/couch.lua` | new |
| `dispatch` | `lua/parley/operator_admission.lua` | modified |
| `unprotected_view` | `lua/parley/document_session.lua` | new |

`unprotected_view` is a pure projection of the lifecycle snapshot and typed-header classification into an optional not-protected label. It owns no state: pending/absent/unavailable typed files show `not protected · Alt+Return registers`, composed with pending/error feedback without losing the warning. Registered identity removes this pre-registration warning; #408 continues to own its acquired/unavailable/refused presentation. Ordinary unregistered prose keeps its current plain presentation. Header edits refresh the projection without changing S1 admission ownership (ARCH-PURE/STATE).

The modified owner `dispatch` removes this branch's legacy_release stage. Acquire against a retained tokenless owned proof returns the existing refused phase without IO or token/history mutation. The ordinary explicit release and validated restore/reload behavior stays in that owner; no new state enum.

| Name | Lives in | Status | Wraps |
|------|----------|--------|-------|
| `setup_markdown_keymaps` | `lua/parley/init.lua` | modified | S1-first attachment, standalone fallback |
| `owns_admission` | `lua/parley/agentic_document.lua` | new | exact live S1 controller eligibility, independent of registration |
| `attach` | `lua/parley/agentic_document.lua` | modified | initial ownership, old-controller retirement and journal precedence |
| `admit_insert` | `lua/parley/agentic_document.lua` | new | S1's single pending-lookup input join |
| `pending_lookup` | `lua/parley/agentic_document.lua` | deleted | remove the dual-consumer export; retain only the private exact-lookup selector |
| `adopt` | `lua/parley/agentic_document.lua` | modified | confirmed attachment with observed baseline and exact live scope |
| `attach` | `lua/parley/session_sync.lua` | modified | registered controller or retained old completion; no S1 legacy creation |
| `acquire_observed` | `lua/parley/session_sync.lua` | modified | registered observed-edit acquisition only within S1 |
| `release_if_baseline` | `lua/parley/session_sync.lua` | modified | preserve inside-S1 old tokenless proof until explicit completion |
| `begin_move` | `lua/parley/session_sync.lua` | modified | reject new moves backed only by old/unproven tokenless protection |
| `finish_input_scope` | `lua/parley/session_sync.lua` | new | exact-scope cleanup |
| `operator_lock` | `lua/parley/couch.lua` | modified | residual process deadline |
| stateful registry/operator fixtures | `tests/helpers/fake_couch.lua`, `tests/fixtures/fake_couch_registry.py`, `tests/fixtures/fake_couch_operator.py` | modified as needed | existing persisted membership, proof and outcome model |

#### Executable integration sequence

- Opening: setup_markdown_keymaps tries S1 attachment first; only a false result enables the existing standalone legacy attachment. S1 publishes its controller before any legacy attachment decision. `owns_admission` derives from that exact live controller, not header recognition, successful lookup or a cached boolean.
- Structural guard: session-sync attachment without a registered identity cannot create a legacy controller while S1 owns admission. Its central tokenless `write_lock` seam also refuses new writes under S1, protecting pre-existing callbacks and non-init callers. An idle legacy attachment with no owner history may be retired; an existing turn keeps only the compatibility completion described above. No pending-lookup special case or deferred legacy write remains.
- Recovery precedence: reuse the existing bounded journal check once at attachment, before cached-identity adoption can trigger ordinary acquisition. If recovery owns the document, its validated restoring_move attachment bypasses normal acquisition and finishes the persisted intent. On the no-journal branch, adopt a known identity and start normal discovery. No new journal scan on input or every edit.
- Input: S1 invokes its own exact pending-lookup join regardless of a typed header or retained old controller. Session-sync no longer invokes that join or schedules a second wait. Confirmed adoption into an existing registered/compatible controller consumes the exact scope and observed baseline; registered fast-held proof still deduplicates ordinary entry. At most one producer acquire per scope; unavailable/refused does not permit another attempt in that scope. The absolute deadline predicate and residual Couch timeouts remain.
- Unknown edits and first submit: S1 retains its existing pre-edit observation through pending, absent and unavailable outcomes until adoption/explicit submission lifecycle settles it; a plain-band update must not erase outstanding edits. Its save effect selects an actually attached controller through the identity accessor, not the header-aware is_session_sync predicate. Thus an unregistered typed file takes the ordinary S1 save/register path without accidentally attaching legacy. Explicit routing, inheritance and owner-prefix rules are unchanged.
- UI: S1's existing band composes the pure not-protected projection with lifecycle/submit feedback on open, reply, edit, save and header refresh. It cannot disappear merely because lookup returns absent or auto-save clears modified. Once registered, the existing registered turn/refusal band takes over. No new overlay owner or watcher is added.
- Cleanup: remove the legacy_release effect from model and IO dispatcher, remove SS-to-S1 join/deferred-write branches and replace their tests. Keep exact old-turn release only on explicit submission and keep validated journal restore/finalization. No automatic old-lock release in registered acquisition, registration completion, scope cleanup or new-move admission.

#### State, actions and failure policy

Actions: edit/save; submit (Alt+Return); retry registered admission; finish/release the original old turn with its owner; leave Insert and reopen the journal destination.

| Internal state / failure mode | Visible state | Recovery action | Possible loss |
|-------------------------------|---------------|-----------------|---------------|
| S1 typed, no confirmed identity; lookup pending/absent/unavailable | Editable, not protected, registration hint; existing error detail retained | submit | No local lock; concurrent agent edits can conflict |
| Confirmed registration, ordinary proof available | Existing acquired/freshened or editable unavailable presentation | edit/save | Existing #408 unavailable conflict risk |
| Confirmed registration with old live tokenless proof | Existing refused input plus finish-old-turn guidance | submit to explicitly finish exact owned turn | No history/proof discarded on failure |
| Confirmed registration with unproven/replaced sidecar | Existing refused input; exact path and owner-assisted release guidance | finish/release the original old turn with its owner | No guessed deletion; input keys remain unapplied |
| Existing journal matches validated recovery | Existing moving/interrupted presentation | leave Insert and reopen destination | Existing forward-only partial progress retained |
| Journal witness/lease/bytes invalid or unknown | Existing interrupted/refused recovery | restore/prove expected state with owner assistance, then reopen | Record and lock retained; no sweep |
| Controller detached/superseded or scope expired | Current controller's ordinary policy; shared discovery retains its lifetime | edit/save or submit in current buffer | No stale acquire or warning from old incarnation |
| No live S1 controller | Existing standalone legacy behavior | existing edit/submit workflow | Existing standalone semantics |

#### Operating envelope and architecture

This remains an input-event feature: a required total 500 ms blocking-wait budget spans only an already-running lookup and one registered acquire. Expiry never launches another child. No synchronous discovery is added. For N entries, new discovery launches remain zero and registered producer attempts are at most N; verify N=4/8 with effect/full-read counters. Ownership checks inspect one exact controller and add no B-buffer or document-content scan per poll. Existing freshness hashing is O(document size); the journal scan stays the existing bounded open/recovery operation. Scope cleanup retains the existing exact-reference/incarnation checks and independent request lifetime (ARCH-CONSTRAINTS/FUNERAL).

One S1 owner gates every new tokenless writer, rather than proving absence at each callback (ARCH-DRY/PURPOSE). UI projection and old-proof acquisition refusal are pure, with native scheduling/IO in the existing seams (ARCH-PURE). Registry replies and sidecars retain typed validation; old proof and journal provenance never come from age or location (ARCH-SECURE/ORDER). Reuse the persisted fake and disposable real producer conformance (ARCH-MOCK). Existing journals, unknown fields, cache bounds and producer acknowledgments do not change format (ARCH-EVOLVE).

#### Verification strategies (functions, adversarial inputs, mechanical guards)

| Functions under test | Strategy and guard |
|----------------------|--------------------|
| lifecycle `unprotected_view`; S1 band integration | Drive actual lifecycle snapshots/header changes and feedback under controlled completion; assert typed unregistered warnings persist until confirmed registration, while registered/standalone views retain their policies. |
| S1 `owns_admission`, `attach`; init `setup_markdown_keymaps`; SS `attach`/tokenless writer | Open through production setup, then drive edits and direct existing attachment callers across namespace/incarnation boundaries using the stateful fake; assert zero new tokenless sidecars throughout S1 and retained standalone locks outside it. Extend the existing owner architecture guard to reject ungated S1 legacy creation. |
| S1 `admit_insert`, `adopt`; SS `acquire_observed`; Couch `operator_lock` | Control lookup completion, external file writes and process scheduling with queued native input; assert first-input proof/freshness, original saved baseline, one absolute deadline and 4/8 linear effect/read bounds on both runtimes. |
| owner `dispatch`; SS explicit release and `release_if_baseline` | Pure event sequences and stateful exact-byte replacement: assert old-proof acquisition has no release/acquire effect or history/token mutation, ordinary S1 input cannot release it, and explicit completion removes only matching owned bytes. |
| SS `begin_move`; S1 `move_path` and native rename entry | Present old/foreign proof before a new move and control metadata replies; assert no new tokenless journal/copy/cleanup is authorized, while current registered proof uses the existing move route. |
| `recover_migration`, SS `restore_move`, existing finalization | Resume actual v1/v2 filesystem journals under controlled saved/dirty content, proof replacement and interrupted outcomes; assert only the persisted authorized effects occur, mismatches retain evidence, and journal removal is last. |
| Existing standalone/refusal regression mappings | Run the full session-sync mapping serially; keep standalone assertions under no S1 namespace, and change inside-S1 fallback expectations only where the operator's retirement policy explicitly changes them. Never make the whole legacy suite pass by registering every fixture. |

#### Tasks — one atomic implementation boundary

1. **Admit the design.** Send this committed plan to the TL and agree the existing-lock/journal rules. Run fresh `sdlc change-code --issue 410 --flow full` without bypass; after plan-quality accepts, derive/reconcile the revised estimate. No product or test code before those gates.
2. **Red, then clean retirement.** Using TDD, modify `tests/integration/session_sync_native_spec.lua`, `tests/integration/session_sync_spec.lua`, `tests/integration/agentic_document_lifetime_spec.lua`, `tests/integration/document_band_spec.lua`, `tests/unit/operator_admission_spec.lua`, existing lifecycle-unit and move/recovery mappings, and `tests/arch/operator_admission_owner_spec.lua` as required by the strategies above. Run `make test-spec SPEC=modes/session_sync` and preserve the intended policy reds. Then implement the listed seams in `lua/parley/init.lua`, `lua/parley/agentic_document.lua`, `lua/parley/session_sync.lua`, `lua/parley/operator_admission.lua`, `lua/parley/document_session.lua`. Remove the superseded handoff/deferred-restoration mechanism rather than adding its missing completion callback. Run targeted mappings serially, then commit the coherent replacement.
3. **Verify the entire policy.** Run the session-sync and affected architecture mappings on preferred `/opt/homebrew/opt/neovim/bin/nvim` and operator `/opt/homebrew/bin/nvim` through environment PARLEY_TEST_NVIM; run `make lint`, fake-only and real registry conformance with the negative control. Preserve timing/count assertions and existing standalone/journal regressions. Coordinate the shared native file with #412; its refusal-only process-budget work must not widen #410's actual 500 ms deadline tests.
4. **Document and accept.** Rewrite `README.md` and `atlas/modes/session_sync.md` around retirement, exact old-proof recovery and standalone compatibility; keep new symbols/tests mapped. Commit/push via `sdlc pr`, queue a new recorded suite on final code, and run fresh `sdlc close`. Only after both pass, run the already authorized copied-profile scratch-only live check; update that unrun fixture to assert S1-first setup and no new tokenless turn. Any :0 stage still requires another TL ask. Send results to the hub, await SHIP, then land through `sdlc merge --yes`. Unknown failures block; only the exact #412 exception has the prior limited rerun authorization until typed Lua registration is available.

**Stop rule:** another gap in this single-route mechanism or an existing-lock/journal rule that cannot be implemented as agreed goes back to the TL before another mechanism delta. Do not claim prior green native runs or the cancelled suite verify this retirement revision.

### 2026-10-22 — dead-owner recovery condition on agreed RETIRE plan

TL aa353a9d agreed the retirement/compatibility rule subject to naming and testing an existing way out when the old nvim owner crashed. The concrete existing workflow for a typed legacy file is: reopen the file in a standalone editor with COUCH_THREAD_SCOPE and COUCH_THREAD_TAG absent, then press Alt+Return. For example, the operator may launch `env -u COUCH_THREAD_SCOPE -u COUCH_THREAD_TAG nvim /absolute/file.md`. S1 is not attached there; review_send falls through to session_sync.submit. The existing standalone release_owned branch explicitly adopts the observed tokenless bytes for that submit, rechecks/removes only those exact bytes, and sends the saved document. It needs neither the original nvim process nor its lost in-memory baseline. Reopen normally inside S1 afterward; later admission uses registered proof. A send failure remains its existing visible retry condition after explicit release, not permission to recreate the old lock.

This makes the owner-assistance wording above concrete: an operator can finish a crashed typed legacy turn through that unchanged outside-S1 route; it does not require a dead process to act. The stale timer alone only changes the reminder colour and never unlocks. A validated v1/v2 journal still uses its existing leave-Insert/reopen-destination/save-or-Alt+Return recovery. A non-typed orphan lacking both live proof and a valid journal has no existing plugin recovery command; report that limit to the TL, preserve refusal/evidence, and add no generic unlock or automatic metadata repair.

Before gate re-entry, a disposable probe of the actual standalone Alt+Return mapping seeded a pre-existing tokenless lock before opening a fresh controller, proved S1 was absent and no registered ID existed, then verified exact lock release and the submitted message. Preferred-runtime result: 1/0/0 with clean process census (`/tmp/parley-410-dead-owner-probe.log`); this is existing-path evidence, not a tracked regression or permission to weaken S1 refusal. The operator-runtime probe and the permanent test are recorded separately when complete.

After plan-quality admits implementation, add the permanent regression in `tests/integration/session_sync_native_spec.lua`: create an outstanding tokenless turn in a standalone child, end that child while retaining its lock, and reopen the same file in a fresh standalone child with no retained admission history. Assert opening does not remove/change the lock and actual Alt+Return releases it through the existing route. The paired S1 case must retain/refuse an unproven tokenless sidecar, and existing journal tests must still prove validated recovery. Run both runtimes and retain the outside-S1 workflow in README/atlas. This is an additional adversarial strategy for session_sync.submit/release_owned and review_send's standalone fallback, not a new recovery mechanism.

### 2026-10-22 — recovery guidance accepted; include it in the refusal

TL b128ed41 accepted the standalone recovery path and required discoverable guidance. For a stale old tokenless lock on a typed legacy file, the refusal must name its file and include this exact one-line instruction: `open it in nvim outside Couch and press Alt+Return to release`. README and `atlas/modes/session_sync.md` must contain that workflow, including the standalone scope/tag condition. Extend the paired S1 refusal regression to assert the path and instruction while proving no automatic release; the restarted standalone test proves the advertised action works. Non-typed or malformed/unproven protection without a validated journal remains owner-assisted refusal, without falsely promising the typed-legacy action can unlock it.

The existing-path probe also passed 1/0/0 on operator Neovim 0.11.7 (`/tmp/parley-410-dead-owner-operator-probe.log`), with clean census. The first fresh review was cancelled before a verdict to include this newly received UI requirement in its input; re-enter plan-quality on the committed amended plan. The prior estimate is preserved as historical text and must be rederived after this fresh review accepts the retirement scope.

### 2026-10-22 — clarify native and explicit Parley move behavior

TL 84d246e3 confirms native rename/saveas of a clean unregistered typed file remains plain under RETIRE; its first submit registers the current canonical path. The old auto-register-on-native-rename expectation depended on a legacy attachment as the typed-owner signal. TL ba57d44c separately preserves the existing deliberate Parley move command's typed-header registration (independent of lock attachment). No registration side effects are added to native file operations and no existing explicit Parley feature is removed. Tests and atlas record the asymmetry; registered move and persisted-journal behavior remain unchanged.

### 2026-10-23 — scope revision: bounded atomic fold-case diagnostics (#420)

TL90ab1620 /1eed042d authorize this genuine harness change inside #410 after the exact-head full rerun passed all tests but the previous unstructured failure prevented success publication. Production admission is frozen. This does not adopt #415, make old evidence attributable, claim a root-cause fix for the occasional hang, or remove the old failure.

**Core concepts**

| Name | Lives in | Status |
|------|----------|--------|
| Case deadline (name, monotonic start/deadline, residual milliseconds) | tests/helpers/embedded_nvim.lua | new |
| Timeout observation (pending RPC, elapsed, child PID/channel, signal-0 result, bounded last stderr) | tests/helpers/embedded_nvim.lua | modified |

The deadline arithmetic is pure: request budget is min(existing request cap, ceil(nonnegative case residual)); zero residual refuses before sending another RPC. The clock, child RPC, stderr stream and signal-0/kill are the thin IO seam. Reuse the helper's ONE timer and child teardown (ARCH-DRY); no independent watchdog or extra diagnostic RPC. Case metadata and stderr tail die with Child; no new durable artifact (ARCH-FUNERAL). A case starts after the existing before_each child setup; its budget is the existing load-scaled Embedded.request_ms(), with no budget increase. Ordinary callers without case metadata keep their current request behavior. The stderr tail is capped at4096bytes, not an accumulating log.

| Integration | Lives in | Status | Wraps |
|-------------|----------|--------|-------|
| Embedded case envelope | tests/helpers/embedded_nvim.lua | modified | existing child RPC timer and jobstart stderr callback |
| Atomic fold checkpoints | tests/integration/document_fold_uncertainty_retirement_spec.lua | modified | existing one-RPC fold regression |

Keep the original fold fixture in ONE child nvim_exec_lua call. Splitting it into RPCs could dispatch pending fold callbacks between stages and weaken the scenario. A child-local stage(label) writes a short stderr marker with label, elapsed and current mode immediately before each potentially expensive block: fixture construction, document drain, initial manual folds/setup, uncertainty/suspension loop, detachment hook preparation, and restoration/flush. These are nonblocking progress observations, not synchronization or await points. Parent jobstart on_stderr stores a bounded diagnostic tail while its existing RPC waits. At timeout the existing timer captures elapsed/request and case budgets, method, pending/unresponsive editor state, PID/channel and signal-0 liveness BEFORE killing the same child. Mode in stderr is explicitly last checkpoint mode; unavailable current mode stays unknown rather than issuing a second request into a hung editor. Job/channel IDs and signal probe are current timeout observations; post-kill exit status is identified separately if reported. No fabricated mode or inferred absence. Callback uses only fast-safe state/uv calls.

**Implementation and evidence (one close boundary, no Mx tags)**

- [x] Red: extend tests/integration/embedded_nvim_spec.lua with a real child that writes a distinctive stage/mode marker then wedges. Assert named case/stage, elapsed/budget, pending editor state and child liveness diagnostic, bounded failure, and exact child reaping. Existing helper lacks this case envelope/diagnostic so the test must fail before implementation. Use the existing short REQUEST_MS test seam and arrival bounds; restore globals after_each.
- [x] Red: a real-child multi-request case consumes part of its total budget in one request and wedges in the next. Assert the second request receives only residual budget and that the same case deadline is not reset. Add a successful ordinary/named return case and exhausted-before-dispatch coverage. Keep negative wedges in the existing bounded helper tests and clean every child.
- [x] Green: add Child:begin_case(name,budget_ms) and bounded stderr capture in Embedded.start; make Child:request reuse its timer with residual case budget and emit captured timeout diagnostics before its existing exact-PID kill. No change to production code, suite configuration, adapter, global default timeout or existing unnamed error prefix. Prove bounded stderr retention through an oversized marker stream.
- [x] Instrument only the uncertainty-retirement fixture with the case envelope and six stderr checkpoints, preserving original line counts, folds, mutation order, one RPC, detach callback and all final behavior assertions.
- [x] Run helper and both fold-retirement specs on preferred and installed0.11.7 via make test-spec with a scratch map. Check syntax, whitespace, lint and clean process censuses. Record negative deadline proof and successful original behavior.
- [ ] Update atlas/infra/test_harness.md and issue Log with the case envelope, bounded last-checkpoint diagnostics, honest unknown-mode semantics and #415 distinction. Commit/push genuine harness code, then ONE new recorded full suite. Do not restart a queued/running check. If the new suite fails, diagnose its named evidence and stop/report rather than another blind rerun.
- [ ] On real recorded suite pass, perform the required fixed-then-ship re-close including full-suite evidence (cover the #412 conflict and harness scope revision), then sdlc merge --yes under existing SHIP. If any gate refuses, retain its evidence/report instead of bypass.

Alternatives rejected: changing only the timeout cannot locate a hang; splitting the atomic fixture across RPCs changes event ordering; an independent watchdog duplicates the helper timer; synchronous mode/job diagnostic RPCs can hang behind the same request. The selected stderr seam preserves atomic child execution and reuses existing parent-side RPC waiting. Mandatory fresh plan-quality precedes implementation; the TL approves this concrete design before code.

2026-10-23 implementation evidence: preferred0.12.5 and installed0.11.7 targeted runs each pass helper10/0/0 and both retirement fixtures1/0/0, clean census. Arrival-budget/embedded-RPC architecture checks each2/0/0; lint823 files zero warnings/errors; luac and whitespace pass. Diagnostic implementation and atlas are complete. The new-code recorded suite and fresh close/landing remain pending. No production change.
