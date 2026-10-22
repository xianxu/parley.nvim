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
| `remaining_ms(deadline_ms, now_ms)` | `lua/parley/couch.lua` | new |

`remaining_ms` is arithmetic only: `math.max(0, math.floor(deadline_ms - now_ms))`. It takes clock readings as data and cannot refresh a deadline. Test directly in `tests/unit/couch_spec.lua`: start, partially consumed, exact expiry, overrun, fractional remainder. Keep it beside the existing timeout owner rather than introducing a new module for arithmetic (ARCH-DRY/PURE).

`operator_admission` and the document lifecycle's operation/witness model remain unchanged: the budget is scheduling context, not lock ownership or edit history. Existing pure sequence tests remain regression coverage.

### Integration points

| Name | Lives in | Status | Wraps |
|------|----------|--------|-------|
| `M.attach` / insert-entry callback | `lua/parley/agentic_document.lua` | modified | native InsertEnter, exact active lookup, bounded event-loop wait |
| `adopt` | `lua/parley/agentic_document.lua` | modified | registration adoption and session-sync handoff |
| `M.attach`, `M.acquire_observed`, `dispatch_admission` | `lua/parley/session_sync.lua` | modified | existing admission owner and nested late attachment |
| `M.operator_lock` | `lua/parley/couch.lua` | modified | synchronous operator acquire process and wait |
| stateful registry/operator fixtures | `tests/helpers/fake_couch.lua`, `tests/fixtures/fake_couch_registry.py`, `tests/fixtures/fake_couch_operator.py` | modified as needed | controlled request completion and persisted registration/lock state |

Extend the internal attachment/observed-acquire handoff with an optional admission scope, preserving current callers. `M.operator_lock(verb, identity, token, deadline_ms)` defaults to its existing per-call 500 ms behavior when no enclosing scope exists. Release remains unchanged. No new producer protocol is required.

## Scheduling and ownership

On S1 InsertEnter, inspect the controller's current lifecycle operation. Join only an existing `lookup` for this loaded buffer/path/namespace/incarnation, with no confirmed identity; exclude register, confirm-parent, move/recovery and another buffer's operation. Snapshot that operation's witness. Allocate one scope with absolute monotonic deadline `now + couch.OPERATOR_LOCK_TIMEOUT_MS` and this controller/witness; install it before yielding to `vim.wait`.

The scope has only `waiting`, `acquiring`, `settled`, `closed` phases. It is private to this input event; no module-global active deadline. Joining another callback cannot allocate a replacement scope. A nested callback for the same scope reuses it; an irrelevant or stale controller cannot receive it. Clear by exact scope identity on all exits, including errors, detach and supersession.

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

### Task 1: Native red cases for pending discovery

Files: `tests/integration/session_sync_native_spec.lua`, `tests/integration/agentic_document_lifetime_spec.lua`, existing fake helpers/fixtures if controlled completion needs a seam.

- [ ] Add a native helper that opens an uncached registered parent/side document through S1, holds its already-started lookup, and queues actual `iX`. Release lookup under test control; race an external file write at operator acquire. Assert InsertCharPre sees confirmed protection and fresh text, and X applies to the fresh content.
- [ ] Add pending-through-deadline case: first edit applies after the bound, lookup is still outstanding, then late completion preserves/reconciles the original edit baseline. Include autosaved outstanding edits, not only modified=true.
- [ ] Add absence/failure/no-pending controls and detach/reopen, another-buffer, superseded-witness cases. Assert zero synchronous discovery launches and no foreign gating. Controls distinguish ordinary background discovery from newly launched input work.
- [ ] Run `make test-spec SPEC=modes/session_sync` and observe relevant new cases fail for the intended ordering/budget reasons before implementation. Preserve logs in disposable scratch.

### Task 2: Shared deadline and one acquire per scope

Files: `lua/parley/couch.lua`, `lua/parley/agentic_document.lua`, `lua/parley/session_sync.lua`, `tests/unit/couch_spec.lua`.

- [ ] Write pure remaining-budget tests and process-seam tests with an already-consumed deadline: both child timeout and synchronous wait receive only remaining time; expiry launches no child. Verify default acquire/release behavior is unchanged.
- [ ] Red-run `make test-spec SPEC=modes/review` (the mapping containing `couch_spec.lua`); implement arithmetic and optional absolute-deadline argument in the existing seam.
- [ ] Implement exact pending lookup scope and bounded InsertEnter join. Forward the same scope through adopt/attach/observed acquisition, claim the acquire once before running effects, and clear by identity on every exit. Keep operator_admission as sole history owner.
- [ ] Green-run native races. Add nested callback regression consuming most of the budget before attachment, followed by a slow acquire: total cannot become lookup wait + 500. Test confirmed, unavailable, held and invalid outcomes; stale scope cannot retry or retire a newer turn.
- [ ] Commit code/tests with issue reference, Co-Authored-By and session Agent trailer after targeted green evidence.

### Task 3: Bounds, conformance and acceptance

Files: native/integration tests above, `tests/unit/operator_admission_spec.lua` only if interface usage needs additional sequence coverage, `README.md`, `atlas/modes/session_sync.md`, `atlas/traceability.yaml` only for new files.

- [ ] Count 4/8-turn process/read work and preserve existing refused retry mappings, lost-ack, release, dirty-buffer, Ctrl-C and clean-reload coverage. Run architecture guards, including sole admission owner and spec-authoring guards, and `make lint`.
- [ ] Run focused mappings serially on preferred runtime and installed operator runtime using environment `PARLEY_TEST_NVIM`; identify exact executable paths from harness/tooling rather than assume versions.
- [ ] Run `python3 scripts/check-couch-registry-conformance.py --fake-only` and `make check-couch-registry-conformance` against a disposable real Couch supporting the landed operator protocol. Extend only the existing probe if residual timeout semantics require new real-command evidence.
- [ ] Document the pending-lookup shared budget and retained editable-unknown boundary; keep atlas links and mapped tests consistent. Record measured timing/counters and deferred approvals in issue Log.
- [ ] Push via `sdlc pr`; run recorded `sdlc local-check run --name suite` on pushed head. Send TL results and request the required disposable real-profile live check before landing. Any :0 stage/visible editor action requires TL authorization; no live store/documents touched.
- [ ] Close through `sdlc close --issue 410 --verified '<measured evidence>'` after required checks; its fresh-context review owns this boundary. Report PR and review/live-check result to hub and await SHIP for merge.

## Approval checkpoint

Planning only. Send this committed plan to ops:0 and wait for approval before `sdlc change-code` or product/test implementation. The explicit dispatch asks for plan-before-code; no quick-flow self-approval substitutes for that checkpoint.
