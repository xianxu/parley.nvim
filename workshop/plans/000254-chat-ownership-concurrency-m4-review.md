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

---

## Re-review — 2026-09-15T10:55:58-07:00 (REWORK)

| field | value |
|-------|-------|
| issue | 254 — Harden chat ownership and concurrency |
| repo | 000254-chat-ownership-concurrency |
| issue file | workshop/issues/000254-chat-ownership-concurrency.md |
| boundary | milestone M4 |
| milestone | M4 |
| window | 506d2c344fd177cba7f9afaee6fe89980a675425..97ac580524fc75c250c6ef90e5a3b34d834410cd |
| command | sdlc milestone-close --issue 254 --milestone M4 |
| reviewer | codex |
| timestamp | 2026-09-15T10:55:58-07:00 |
| verdict | REWORK |

## Review

```verdict
verdict: REWORK
confidence: high
```

The three prior findings are addressed with code, documentation, and regression evidence. One additional correctness bug blocks M4: typing a later draft before response admission falsely marks the earlier answer stale and pauses its tool continuation. The repository was left unchanged.

```findings
dispose:
  - id: BR-14
    disposition: addressed
    note: |
      response_tools.lua:156 reserves inert text; lines 92–99 serialize only known outcomes. Regression tests cover pending, cancellation, reload, unknown/rejected outcomes, sibling completion, and provider projection. Restoring the previous implementation in scratch reproduces parsed content="(pending)", is_error=false.
  - id: BR-15
    disposition: addressed
    note: |
      Public ChatResumeResponse now reaches identity-validated resume_original; stale annotations survive completion. Native public-workflow tests cover continuation, focus changes, revoked output, detach, and fresh-answer clearing. Restoring the previous runner in scratch makes four regression tests fail.
  - id: BR-16
    disposition: addressed
    note: |
      README.md:64–87 documents Stop/StopDocument, active-output edits, deletion/reload, native history, pending results, and stale continuation. The pinned additions match init.lua:1583–1585, chat_history.lua:6–8, and the response adapters.
findings:
  - id: new
    severity: Critical
    family: semantic-publication-evidence
    title: |
      Later-draft edits before admission falsely stale and pause an earlier response
    detail: |
      response_target.lua:99–101 sets input_stale=true for every document edit, regardless of captured input dependencies. A scratch public-workflow regression submits the first question, immediately edits the later draft, then completes a tool round: the earlier generation becomes paused with stale_input=true and never issues its second request. This contradicts plan line 145. This is the 8th finding in family semantic-publication-evidence: do not patch only this site; enforce dependency-backed stale evidence across waiting-target admission, active generation, presentation, and continuation (ARCH-PURPOSE, ARCH-SECURE, ARCH-ORDER).
```

## 1. Strengths

- Generation decisions use private pure state; architecture tests prohibit editor/IO dependencies and positional asynchronous writes.
- Tool reservation tests exercise the real parser and provider projections, establishing that pending text cannot become successful result evidence.
- Public resume tests validate captured identity across focus changes and reject revoked output authority.
- README and atlas updates cover the new commands and ownership behavior.

## 2. Critical findings

**False stale evidence during admission** — [response_target.lua:100](/Users/xianxu/workspace/worktree/parley.nvim/000254-chat-ownership-concurrency/lua/parley/response_target.lua:100).

The edit listener unconditionally sets `input_stale`. That value enters the generation reducer and triggers the continuation pause, even when only a later question changed.

Fix the underlying rule: stale evidence must follow captured input dependencies throughout admission and execution. Sweep question/context edits, later-draft edits, disjoint writer output, structural uncertainty, and edit/undo sequences. Share dependency classification where possible.

The [scratch reproduction](/tmp/parley254-suffix-pause-repro.txt) records `phase="paused"`, `stale_input=true`, and one provider request where two were expected.

## 3. Important findings

None additional.

## 4. Minor findings

None.

## 5. Test coverage notes

- Ownership mapping: **25 files passed**.
- Lifecycle mapping: **58 files, 690 tests passed**.
- Scratch rollback controls established regression sensitivity for BR-14 and BR-15.
- The new native public-workflow regression fails on pinned HEAD; the eight existing tests in that file pass.
- Full performance benchmarking was not rerun. Mapped lifecycle performance tests passed.

## 6. Architectural notes

| Principle | Result |
|---|---|
| ARCH-DRY | **Pass:** shared document authority replaces legacy lease/tool registries. |
| ARCH-PURE | **Pass:** generation decisions remain independent of IO; adapters execute effects. |
| ARCH-PURPOSE | **Flag:** pre-admission typing violates the promised later-question independence. |
| ARCH-MOCK | **Pass for M4:** controllable editor/provider/process seams and native conformance tests exercise production boundaries. |
| ARCH-CONSTRAINTS | **Pass for inspected scope:** bounded queues, grants, payloads, and mapped workload tests; no new latency guarantee inferred. |
| ARCH-SECURE | **Flag:** an unrelated edit is promoted into unsupported stale-input evidence. |
| ARCH-ORDER | **Flag:** admission timing changes whether the same later-draft edit pauses continuation. |
| ARCH-FUNERAL | **Pass:** inspected cursors, subscriptions, pending handles, and annotations have retirement paths or explicit bounds. |

The milestone-applicable core entities exist; future M5/M6 entities were not treated as missing M4 deliverables.

## 7. Plan revision recommendations

Add **“Pre-admission dependency affinity”** under `## Revisions`: specify one stale-evidence rule spanning target capture through generation completion, enumerate relevant edit classes, and require equivalent public-workflow outcomes for edits immediately before and after admission.

---

## Re-review — 2026-09-15T11:10:58-07:00 (REWORK)

| field | value |
|-------|-------|
| issue | 254 — Harden chat ownership and concurrency |
| repo | 000254-chat-ownership-concurrency |
| issue file | workshop/issues/000254-chat-ownership-concurrency.md |
| boundary | milestone M4 |
| milestone | M4 |
| window | 506d2c344fd177cba7f9afaee6fe89980a675425..d30d8bff1578ecf45c195eb3f93b3c3e275cdb7c |
| command | sdlc milestone-close --issue 254 --milestone M4 |
| reviewer | codex |
| timestamp | 2026-09-15T11:10:58-07:00 |
| verdict | REWORK |

## Review

```verdict
verdict: REWORK
confidence: high
```

BR-17 is fixed and has meaningful regression evidence: its new public test passes at Head and fails with the pre-fix implementation. M4’s scoped ownership and documentation are substantially delivered. Shipping is blocked by a reproduced tool-retirement ordering bug and an existing integration test that still asserts the stale-input behavior BR-17 removed.

```findings
dispose:
  - id: BR-17
    disposition: addressed
    note: |
      response_target.lua shares consumed-input selection between waiting guards and admitted dependencies. Public pre/post-admission regressions pass; restoring the pre-fix target implementation makes chat_stop_generation_spec.lua:176 fail because continuation never starts.
  - id: BR-14
    disposition: addressed
    note: |
      response_tools.lua reserves inert pending text and serializes confirmed results. Passing response_tools_spec.lua cases cover pending, cancellation, reload, unknown/rejected outcomes, and confirmed sibling publication.
  - id: BR-15
    disposition: addressed
    note: |
      Public chat_stop_generation_spec.lua tests verify stale presentation, explicit original-input continuation across focus changes, and refusal after ownership changes or detach.
  - id: BR-16
    disposition: addressed
    note: |
      README.md's added editing section documents Stop selection, StopDocument, stale continuation, and native history; the command implementation and passing public command tests support these descriptions.
findings:
  - id: new
    severity: Critical
    family: scope-owned-callback-cleanup
    title: |
      Cancelled tools remain outstanding when positive outcome evidence arrives after cleanup acknowledgment
    detail: |
      lua/parley/response_tools.lua:98 returns without maybe_resolve after cancellation. Reproduced sequence: unknown outcome, producer resolved, cancellation, cancellation resolved, then known outcome; the generation remains stopping with one outstanding operation despite complete evidence. This is the 3rd finding in family scope-owned-callback-cleanup. Do NOT fix only this instance: enforce the rule that every update to outcome, physical completion, or publication completion reevaluates retirement; cancellation suppresses publication, not retirement. Sweep their orderings, duplicates, and teardown paths (ARCH-ORDER, ARCH-FUNERAL, ARCH-PURPOSE).
  - id: new
    severity: Important
    family: semantic-publication-evidence
    title: |
      Existing affinity regression still requires an unrelated suffix edit to stale input
    detail: |
      tests/integration/generation_input_affinity_spec.lua:39–56 appends a later question and asserts input_stale=true; the pinned Head fails at line 45. This is the 9th finding in family semantic-publication-evidence. Do NOT merely flip this assertion: apply the consumed-dependency rule across the stale-input test inventory, use an actual consumed-prefix edit to test stale evidence propagation into preparation, and retain a separate negative suffix case (ARCH-PURPOSE).
```

## 1. Strengths

- Consumed-input selection is shared across admission stages in `response_target.lua`; BR-17’s regression demonstrably fails without the fix.
- Private generation transitions and architecture checks enforce separation from editor state and IO.
- Tool tests validate parsed and wire-level outcomes, including independently completed siblings.
- README and atlas cover the new ownership vocabulary and user commands.

## 2. Critical findings

**Tool retirement ordering — `lua/parley/response_tools.lua:98`.**  
The reproduced sequence leaves the generation permanently `stopping`, retaining its admission capacity. Calling the existing retirement check on the early-return path makes the scratch regression pass, confirming the cause. The complete correction should enforce the retirement rule across all contributing events.

Reproducer: [review_tool_order_spec.lua](/tmp/parley-m4-review-a0j6t0nc/source/tests/integration/review_tool_order_spec.lua:238).

## 3. Important findings

**Contradictory regression — `tests/integration/generation_input_affinity_spec.lua:45`.**  
Repair the fixture to exercise genuine consumed-input invalidation while preserving its preparation-propagation checks. Sweep sibling assertions and rerun the mapped suites.

## 4. Minor findings

None.

## 5. Test coverage notes

- Tested an isolated archive of the pinned Head; the checkout was unchanged.
- **57 changed spec files:** 55 passed; 767 test cases passed.
- One genuine assertion failure: stale-input affinity.
- Two HTTP fixture failures: local socket binding is prohibited here (`EPERM`); these do not establish a product defect.
- BR-17 mutation check: regression fails without the fix.
- New cancellation-ordering regression: fails at Head; passes with the diagnostic retirement-check correction.
- Full performance validation was not rerun.

## 6. Architectural notes

| Principle | Assessment |
|---|---|
| ARCH-DRY | **Pass:** shared input-region builder and coordinator ownership. |
| ARCH-PURE | **Pass:** generation decisions remain pure; IO uses adapters. |
| ARCH-PURPOSE | **Flag:** complete the lifecycle-ordering and stale-test family sweeps. |
| ARCH-MOCK | **Pass:** stateful seams permit deterministic reproduction; HTTP validation remains environment-limited. |
| ARCH-CONSTRAINTS | **Flag:** stranded operations retain bounded admission slots. |
| ARCH-SECURE | **Pass:** reviewed publication paths require provenance or confirmed outcomes. |
| ARCH-ORDER | **Flag:** outcome-after-cleanup ordering fails retirement. |
| ARCH-FUNERAL | **Flag:** confirmed cancelled work lacks effective retirement in that ordering. |

M5/M6 work remains explicitly staged for later boundaries; it is not treated as missing M4 delivery.

## 7. Plan revision recommendations

Add `## Revisions` entries recording:

- Retirement as a join of outcome, physical completion, and publication completion, reevaluated after every contributing event regardless of cancellation.
- The stale-input regression inventory correction and fresh mapped verification results before claiming M4 closure.

---

## Re-review — 2026-09-15T11:32:05-07:00 (SHIP)

| field | value |
|-------|-------|
| issue | 254 — Harden chat ownership and concurrency |
| repo | 000254-chat-ownership-concurrency |
| issue file | workshop/issues/000254-chat-ownership-concurrency.md |
| boundary | milestone M4 |
| milestone | M4 |
| window | 506d2c344fd177cba7f9afaee6fe89980a675425..dd5a5a47130accdefc7a2e8a240234d2828e4a4d |
| command | sdlc milestone-close --issue 254 --milestone M4 |
| reviewer | codex |
| timestamp | 2026-09-15T11:32:05-07:00 |
| verdict | SHIP |

## Review

```verdict
verdict: SHIP
confidence: medium
```

BR-18 and BR-19 are addressed with meaningful regression evidence. The reviewed M4 ownership paths, cancellation cleanup, consumed-input tracking, and documentation match the milestone’s scope. No new blocking defect was confirmed. Confidence is limited by sandbox restrictions preventing HTTP integration verification; this is M4 clearance, not issue-close clearance.

```findings
dispose:
  - id: BR-18
    disposition: addressed
    note: |
      response_tools.lua:98–104 reserves publication before callbacks and reevaluates retirement after outcome updates. All 35 tool tests pass; restoring the pre-fix implementation in a scratch copy produces nine failures.
  - id: BR-19
    disposition: addressed
    note: |
      generation_input_affinity_spec.lua:39–65 separately tests consumed-prefix staleness and excluded-suffix freshness through preparation. All three tests pass; disabling runner stale-evidence propagation makes the consumed-prefix regression fail.
  - id: BR-14
    disposition: addressed
    note: |
      Pending reservations remain inert text. Passing response_tools regressions verify that cancellation, reload, unknown outcomes, and reparsing cannot turn reservations into successful tool results.
  - id: BR-15
    disposition: addressed
    note: |
      The public resume command selects stale paused responses and validates captured identity through resume_original. The changed chat_stop_generation regression suite passes.
  - id: BR-16
    disposition: addressed
    note: |
      README.md documents cursor-scoped ParleyStop, its picker, and ParleyStopDocument; chat_respond.cmd_stop and cmd_stop_document implement those respective scopes.
  - id: BR-17
    disposition: addressed
    note: |
      response_target.lua derives waiting guards and admitted dependencies from input_regions. Passing target, submission, and native affinity tests preserve freshness for excluded suffix edits.
```

## 1. Strengths

- **Retirement regression coverage is effective.** Tests exercise reordered cleanup, cancellation/detach, duplicate callbacks, and reentrant publication—not just the originally reported sequence.
- **Input provenance survives admission.** The native affinity regression verifies both the runner’s stale state and the preparation callback’s frozen input.
- **Ownership boundaries are enforced.** Architecture tests prohibit positional streaming, asynchronous native buffer writes, and restoration of legacy lease/tool-loop authorities.
- **Documentation accompanies the surface.** README and atlas describe scoped Stop, resume, pending tool slots, and ownership behavior.

## 2. Critical findings

None newly identified.

## 3. Important findings

None newly identified.

## 4. Minor findings

None.

## 5. Test coverage notes

- Ran the required pinned stat and name-status commands before patch inspection.
- **56 of 57 changed spec files passed.** The remaining HTTP tool-loop spec could not start its fake server; an independent loopback bind returned `Operation not permitted`.
- A branch-topic test encountered shared scratch-directory initialization contention; its isolated retry passed all six tests.
- Mutation checks confirmed **nine failures without BR-18’s fix** and **one failure without stale-input propagation**.
- The broader suite was not green. Besides restricted-environment integrations, its core-table fitness test fails on a mismatch already present at Base: the guard expects individual exported symbols, while the plan tables enumerate architectural entities.
- No fresh performance measurement or unrestricted full-suite clearance is claimed.

## 6. Architectural notes

| Principle | Assessment |
|---|---|
| **ARCH-DRY** | **Pass:** document authority and position-free dispatch replace competing legacy writers. |
| **ARCH-PURE** | **Pass:** generation decisions reside in the pure reducer; adapters execute effects. |
| **ARCH-PURPOSE** | **Pass:** both open findings address their underlying rules and sibling orderings. M5/M6 work remains explicitly assigned. |
| **ARCH-MOCK** | **Pass for inspected M4 seams:** stateful doubles control editor, producer, and transport events. HTTP conformance remains environment-blocked. |
| **ARCH-CONSTRAINTS** | **Pass for inspected bounds:** admission, staging, result sizes, and tool rounds have explicit limits. |
| **ARCH-SECURE** | **Pass:** identity and outcome validation precede publication; scratch tests remain isolated. |
| **ARCH-ORDER** | **Pass:** production generation transitions use the model; cancellation and late-evidence orderings have executable coverage. |
| **ARCH-FUNERAL** | **Pass:** retirement releases callbacks, payloads, subscriptions, and deferred work after required evidence arrives. |

## 7. Plan revision recommendations

None required for this round. The BR-18/19 revision accurately describes the verified corrections.
