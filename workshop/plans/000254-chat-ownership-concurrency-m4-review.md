# Boundary Review — 000254-chat-ownership-concurrency#254 (milestone M4)

| field | value |
|-------|-------|
| issue | 254 — Harden chat ownership and concurrency |
| repo | 000254-chat-ownership-concurrency |
| issue file | workshop/issues/000254-chat-ownership-concurrency.md |
| boundary | milestone M4 |
| milestone | M4 |
| window | 506d2c344fd177cba7f9afaee6fe89980a675425..ae2e12ecbc3ab596a7c89565eefc8d4ec2c26a0a |
| command | sdlc milestone-close --issue 254 --milestone M4 |
| reviewer | codex |
| timestamp | 2026-09-15T10:23:31-07:00 |
| verdict | REWORK |

## Review

```verdict
verdict: REWORK
confidence: high
```

The refactor establishes strong scoped ownership and deterministic lifecycle tests, but M4 is not ready to close. Pending tool slots masquerade as completed results, stale-input pauses lack a user-facing recovery path, and the new Stop surface is missing from README. Repository changes were not modified.

## 1. Strengths

- Generation state is private and IO-independent; tests cover duplicate events, cancellation, partial receipts, and completion ordering.
- Production tool-round tests verify declaration order, out-of-order completion, atomic capacity admission, and independent sibling progress.
- Stop tests confirm cursor-targeted cancellation, captured picker identities, and document-scoped cancellation.
- Atlas updates explain the new ownership and response composition.

## 2. Critical findings

**Pending reservations publish result evidence before execution.**  
At `lua/parley/response_tools.lua:153`, reservation serializes `(pending)` through the ordinary result serializer. It parses as `{content="(pending)", is_error=false}` before any producer reports an outcome. This contradicts plan lines 150–155 and can leave false result evidence after cancellation. Reserve slots without completed-result Markdown; test parser/provider projections throughout reservation, cancellation, and reload.

**Stale-input policy is not connected to the user workflow.**  
At `lua/parley/generation_runner.lua:317`, changed input pauses tool continuation until `Runner.resume` receives a policy. Production presentation does not consume staleness, and no public command invokes the session resume API. Consequently, context editing can leave a response silently paused; ordinary successful responses also lack the promised stale indication. Connect lifecycle status to presentation and provide an identity-validated continuation decision.

## 3. Important findings

**README update appears missing for Stop behavior.**  
`lua/parley/init.lua:1583–1584` changes Stop selection and introduces StopDocument, but README is unchanged. Document both commands, cursor/picker selection, and the active-output editing policy.

## 4. Minor findings

None.

## 5. Test coverage notes

- Independently ran **79 tests across five files**, all passing: generation unit/sequence tests, response tools, scoped Stop, and ownership architecture checks.
- A scratch-only regression added to the production tool fixture **failed as expected**: an unexecuted reservation parsed as a non-error tool result.
- Existing stale-input tests establish the pause but exercise internal resume/cancel APIs; they do not establish a usable public workflow.
- `git diff --check` passed. Full mapped suites and performance measurements were not rerun.
- No prior findings required disposition.

## 6. Architectural notes

| Marker | Result |
|---|---|
| ARCH-DRY | Pass — coordinator and serializer reuse centralize authority and formatting. |
| ARCH-PURE | Pass — the generation reducer is private and tested directly without IO mocks. |
| ARCH-PURPOSE | Flag — pending-result and stale-input contracts remain incomplete. |
| ARCH-MOCK | Pass — reviewed sequences use controllable stateful producers through production seams, plus native Neovim tests. |
| ARCH-CONSTRAINTS | Pass — explicit staging, grant, generation, and child-admission bounds are enforced. Performance claims were not independently remeasured. |
| ARCH-SECURE | Flag — persisted pending placeholders are accepted as ordinary result evidence. |
| ARCH-ORDER | Flag — a reachable paused state lacks a production user transition to validated continuation. |
| ARCH-FUNERAL | Pass — reviewed retirement paths release subscriptions, staged payloads, and capacity while retaining unresolved operations. |

The M4 generation/runner entities exist at their planned paths. Batch recovery and asynchronous builtin effects remain explicitly assigned to M5/M6.

## 7. Plan revision recommendations

Add `## Revisions` entries that:

- Reconcile the placeholder implementation and atlas description with the prohibition on fabricated completed-result Markdown.
- Specify stale/paused presentation and the public continuation decision, with production-path acceptance tests.
- Complete the README gate by sweeping all changed user-facing behavior.

```findings
findings:
  - id: new
    severity: Critical
    family: semantic-publication-evidence
    title: |
      Pending tool reservations parse as completed non-error results
    detail: |
      lua/parley/response_tools.lua:153 serializes an ordinary result before execution; a scratch production-fixture regression returned content="(pending)" and is_error=false. This is the 7th finding in family semantic-publication-evidence. Earlier rounds fixed instances: state and enforce the rule that only confirmed outcomes publish result evidence, sweeping reservation, cancellation, persistence, parsing, and provider projection (ARCH-PURPOSE, ARCH-SECURE, ARCH-ORDER). Plan lines 150–155 explicitly prohibit this representation.
  - id: new
    severity: Critical
    family: lifecycle-state-observability
    title: |
      Stale input can silently strand a response in paused state
    detail: |
      lua/parley/generation_runner.lua:317 pauses stale-input continuation until an explicit resume policy arrives, but production callers do not invoke the session resume API or publish stale/paused state; response_session.lua:52 wires only ordinary pending presentation. Expose the state and an identity-validated continuation decision, retain the promised stale indication on completed answers, and test through the public response workflow (ARCH-PURPOSE, ARCH-ORDER).
  - id: new
    severity: Important
    family: deferred-contract-traceability
    title: |
      README omits the new StopDocument command and changed Stop contract
    detail: |
      lua/parley/init.lua:1583–1584 introduces the user-facing command and selection behavior without any README change in the pinned range. This is the 4th finding in family deferred-contract-traceability. Do not repair only this command: enumerate all changed user-facing behavior, including active-output editing and native history, and complete the README gate for that inventory (ARCH-PURPOSE). Prose inspection is sufficient validation for this documentation correction.
```
