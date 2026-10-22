# Boundary Review — parley.nvim#408 (whole-issue close)

| field | value |
|-------|-------|
| issue | 408 — session-sync: fence insert admission and reload after lock acquisition |
| repo | parley.nvim |
| issue file | workshop/issues/000408-insert-admission-freshness.md |
| boundary | whole-issue close |
| milestone | — |
| window | ec4dcf71361ed40c78c76044928d4bea23e5caa3..ed02d19c4306e0acec8b256c3666b7a527506aa4 |
| command | sdlc close --issue 408 |
| reviewer | codex (openai; author openai) |
| isolation | fenced |
| timestamp | 2026-10-22T00:31:58-07:00 |
| verdict | REWORK |

## Review

```verdict
verdict: REWORK
confidence: high
```

The acquisition validation, native freshness ordering, and ownership checks have strong coverage. However, a refused retry can erase the acquisition baseline and subsequently release an unsubmitted edit. The admission lifecycle also lacks the required pure transition model, and one Core-concepts status contradicts the pinned diff.

Done-when: current — the existing criteria still cover the revised confirmed-identity admission boundary, failure policy, freshness, and producer contract.

1. **Strengths**

- Native tests observe acknowledgment and fresh contents at `InsertCharPre`, before queued input applies.
- Acquire/release validation checks document, canonical path, turn token, and ownership evidence.
- README and atlas explain degraded editing, refusal recovery, and the pending-discovery exception.

2. **Critical findings**

```findings
findings:
  - id: new
    severity: Critical
    family: acquisition-baseline-preservation
    title: |
      A refused retry discards the baseline and permits release of an unsubmitted edit
    detail: |
      lua/parley/session_sync.lua:532-533 clears baseline when protection is absent and admission changes from unavailable to refused; a subsequent successful acquire at lines 649-659 adopts the saved edited content as its baseline. Reproduced through the production Couch client and executable fake: unavailable acquire → edit and save → refused retry → confirmed retry → unchanged exit removes the lock, whereas the control without the refused retry retains it; preserve the original outstanding baseline across failures and add this regression sequence.
  - id: new
    severity: Critical
    family: admission-transition-ownership
    title: |
      Admission state changes bypass an explicit pure transition model
    detail: |
      lua/parley/session_sync.lua:632-675 makes admission decisions inside the IO callback and directly mutates admission, acquire_token, owned_lock, baseline, and unconfirmed_edit; refresh, release_owned, and on_lines independently mutate the same authoritative state. ARCH-ORDER and ARCH-PURE require an encapsulated pure state/event transition component: extract the admission submodel, route its mutations through that component, and test failure/retry/save/release sequences against independent invariants.
  - id: new
    severity: Critical
    family: core-concept-traceability
    title: |
      The Core-concepts table marks the new operator_lock function as modified
    detail: |
      workshop/plans/000408-insert-admission-freshness-plan.md:29 classifies operator_lock as modified, but the base contains no such function and the pinned diff adds its definition at lua/parley/couch.lua:103. Correct the status to new and record the correction under Revisions, as required by the Core-concepts cross-check; this correction needs source inspection, not a wording-presence test.
```

The first defect originates in [refresh](/Volumes/TestScratch/review-checkouts/4671b59d88890d45/lua/parley/session_sync.lua:532). Preserve outstanding edit history independently of the current acquisition outcome.

3. **Important findings**

None.

4. **Minor findings**

None.

5. **Test coverage notes**

- All 29 mapped session-sync test files passed on Neovim 0.12.5.
- All 126 native cases passed on both 0.12.5 and 0.11.7.
- All 19 Couch unit cases passed on both versions.
- Fake conformance and its corrupted-fake negative control passed.
- The focused failure-sequence probe reproduced premature release; existing lost-ack coverage omits an intervening refusal.
- Real producer conformance was not rerun during this review. No tracked files changed.

6. **Architectural notes for upcoming work**

- **ARCH-DRY: pass** — registered acquisition and token-owned release share helpers.
- **ARCH-PURE: flag** — admission decisions remain mixed with IO; see finding above.
- **ARCH-PURPOSE: flag** — retry behavior violates preservation of unsubmitted turns.
- **ARCH-MOCK: pass** — stateful executable fake shares the production process boundary.
- **ARCH-CONSTRAINTS: pass** — deadlines, hung-child termination, and counted turn costs are tested.
- **ARCH-SECURE: pass** — acknowledgment mismatches refuse admission; unknown ownership does not authorize release.
- **ARCH-ORDER: flag** — authoritative admission state lacks structurally enforced transitions.
- **ARCH-FUNERAL: pass** — attachment state has cleanup; sidecars have explicit release paths.
- **ARCH-EVOLVE: pass** — journal formats remain unchanged and move protection retains opaque bytes.

7. **Plan revision recommendations**

Add `## Revisions` entries documenting:

- Baseline preservation across unavailable, refused, and confirmed retries, with the complete regression sequence.
- The admission transition component, authoritative state ownership, and sequence-testing invariants.
- `operator_lock` as a **new INTEGRATION** entity.

<!-- sdlc-review-usage [{"version":1,"intent":{"disposable_root":true,"id":"7d712088-7f80-4894-9cec-657788ef0020","repository":"github.com/xianxu/parley.nvim","issue_id":"000408","recipe":"milestone-review","round":1,"attempt":1,"agent":"codex","root":"/Volumes/TestScratch/review-checkouts/4671b59d88890d45","reviewed_head":"ed02d19c4306e0acec8b256c3666b7a527506aa4","slot":"parley.nvim:1","requested_at":"2026-10-22T07:24:44.91298Z"},"phase":"finished","pid":76584,"started_at":"2026-10-22T07:24:45.108244Z","finished_at":"2026-10-22T07:31:57.951594Z","session_id":"01a1627f-8097-7b72-a9f7-391b14bc0d94","outcome":"returned"}] -->

---

## Re-review — 2026-10-22T02:32:44-07:00 (SHIP)

| field | value |
|-------|-------|
| issue | 408 — session-sync: fence insert admission and reload after lock acquisition |
| repo | parley.nvim |
| issue file | workshop/issues/000408-insert-admission-freshness.md |
| boundary | whole-issue close |
| milestone | — |
| window | ec4dcf71361ed40c78c76044928d4bea23e5caa3..3a8c455256e0ff2b7629d578adee08ba30ee6264 |
| command | sdlc close --issue 408 |
| reviewer | codex (openai; author openai) |
| isolation | fenced |
| timestamp | 2026-10-22T02:32:44-07:00 |
| verdict | SHIP |

## Review

```verdict
verdict: SHIP
confidence: high
```

All three prior findings are addressed. The pure admission owner preserves outstanding history across failed retries, production transitions use that owner, and regression tests exercise the reported failure sequence. No new blocking findings emerged.

Done-when: current — the criteria still cover freshness before input, bounded degraded admission, refusal safety, and producer exclusion semantics.

```findings
dispose:
  - id: BR-1
    disposition: addressed
    note: |
      operator_admission.lua:41-67 preserves the original baseline across retries. The native unavailable → edit/save → refused → confirmed → unchanged-exit regression passes on both runtimes. A disposable baseline-clearing mutation makes three pure tests fail, including the reported sequence.
  - id: BR-2
    disposition: addressed
    note: |
      operator_admission.lua encapsulates authoritative history and witnessed transitions; session_sync.lua:426 executes effects and returns outcomes through that owner. Pure sequence tests, the ownership guard, and the native stale-release regression pass.
  - id: BR-3
    disposition: addressed
    note: |
      The plan's Core-concepts row at line 30 now marks operator_lock as new, and Revisions lines 235-241 records the correction. Base-source inspection confirms the function was absent; the pinned diff adds its definition.
```

1. **Strengths**

   - Native tests verify acknowledgment and fresh content before the first queued character.
   - Admission history is private; snapshots cannot mutate authoritative state.
   - Refusal recovery preserves displaced mappings and removes temporary mappings on admission or detach.
   - README and atlas document the retry command, degraded editing, ownership restrictions, and discovery boundary.

2. **Critical findings:** None.

3. **Important findings:** None.

4. **Minor findings:** None.

5. **Test coverage notes**

   - All 31 mapped session-sync test files passed on Neovim 0.12.5.
   - All 141 native cases passed on Neovim 0.11.7.
   - Couch’s 19 cases passed on both runtimes.
   - Pure transitions, ownership guards, spawn guards, and source-traceability checks passed.
   - Fake conformance and its corrupted-fake negative control passed.
   - The disposable mutation was removed; tracked files remain unchanged.
   - Real-producer/live-profile acceptance and the full recorded suite were not repeated here; retain their planned landing gates.

6. **Architectural notes**

   | Principle | Assessment |
   |---|---|
   | ARCH-DRY | Pass — acquisition and owned release share helpers. |
   | ARCH-PURE | Pass — admission decisions reside in the IO-free owner. |
   | ARCH-PURPOSE | Pass — the complete failure/retry sequence preserves outstanding edits. |
   | ARCH-MOCK | Pass — the stateful executable fake exercises the production process boundary. |
   | ARCH-CONSTRAINTS | Pass — deadlines, child termination, and counted turn costs are tested. |
   | ARCH-SECURE | Pass — mismatched acknowledgments refuse admission; unknown ownership cannot authorize release. |
   | ARCH-ORDER | Pass — witnessed outcomes reject stale replies; sequence tests cover retries and failed release. |
   | ARCH-FUNERAL | Pass — attachment resources and refusal UI have cleanup paths; protection has explicit release paths. |
   | ARCH-EVOLVE | Pass — existing journal formats remain unchanged and retain opaque protection bytes. |

7. **Plan revision recommendations:** None required.

<!-- sdlc-review-usage [{"version":1,"intent":{"disposable_root":true,"id":"066496e4-8393-40b7-ad34-584e1fbabfff","repository":"github.com/xianxu/parley.nvim","issue_id":"000408","recipe":"milestone-review","round":2,"attempt":1,"agent":"codex","root":"/Volumes/TestScratch/review-checkouts/6e7faea0d0a7ff61","reviewed_head":"3a8c455256e0ff2b7629d578adee08ba30ee6264","slot":"parley.nvim:1","requested_at":"2026-10-22T09:26:35.651774Z"},"phase":"finished","pid":29422,"started_at":"2026-10-22T09:26:35.820119Z","finished_at":"2026-10-22T09:32:44.480482Z","session_id":"01a162ef-0dbc-7a73-8470-fca85d4edd33","outcome":"returned"}] -->

---

## Re-review — 2026-10-22T02:49:34-07:00 (SHIP)

| field | value |
|-------|-------|
| issue | 408 — session-sync: fence insert admission and reload after lock acquisition |
| repo | parley.nvim |
| issue file | workshop/issues/000408-insert-admission-freshness.md |
| boundary | whole-issue close |
| milestone | — |
| window | ec4dcf71361ed40c78c76044928d4bea23e5caa3..4805170dcbd53e6d71529c75ac2a2881f76e2416 |
| command | sdlc close --issue 408 |
| reviewer | codex (openai; author openai) |
| isolation | fenced |
| timestamp | 2026-10-22T02:49:34-07:00 |
| verdict | SHIP |

## Review

```verdict
verdict: SHIP
confidence: high
```

The pinned implementation matches the revised Spec and Plan. Acquisition, freshness, refusal recovery, and release preserve ownership and outstanding-edit history. No new blocking findings emerged. Required diff inspections completed; the reviewed checkout remains unchanged.

```findings
dispose:
  - id: BR-1
    disposition: addressed
    note: |
      operator_admission.lua:41–60 preserves the original baseline across retries. The native regression at session_sync_native_spec.lua:301 passes on both runtimes; removing baseline preservation in a disposable checkout caused four pure regression failures.
  - id: BR-2
    disposition: addressed
    note: |
      operator_admission.lua owns private transition state; session_sync.lua dispatches witnessed effects and outcomes. Pure sequence tests and the ownership guard pass, including stale completion rejection and negative bypass fixtures.
  - id: BR-3
    disposition: addressed
    note: |
      The plan's Core concepts table at line 30 correctly marks operator_lock as new. Inspection confirms the function is absent at base and added in couch.lua within the pinned range.
```

1. **Strengths**

   - Native tests observe confirmed acquisition and fresh content before the first queued character, for parent and side documents.
   - Baseline retention, clean foreign reloads, stale outcomes, and failed releases have independent sequence coverage.
   - README and atlas explain the new retry command, temporary mappings, degraded editing, and known-identity boundary.

2. **Critical findings:** None.

3. **Important findings:** None.

4. **Minor findings:** None.

5. **Test coverage**

   - Full `modes/session_sync` mapping passed on Neovim 0.12.5.
   - All 142 native cases passed on both 0.12.5 and 0.11.7.
   - Admission model: 18 tests; Couch protocol: 19; ownership guard: 2—all passed on both runtimes.
   - Fake conformance, corrupted-fake negative control, and eight executable fake tests passed.
   - Lint: zero warnings/errors across 822 files. `git diff --check` passed.
   - Real-producer conformance and live-profile staging were not rerun during this review.

6. **Architecture**

   - **ARCH-DRY — pass:** acquisition and release share the protocol seam and admission owner.
   - **ARCH-PURE — pass:** private transition logic is tested directly without IO.
   - **ARCH-PURPOSE — pass:** registered admission consumers share the implementation; discovery deferral is explicitly approved and documented.
   - **ARCH-MOCK — pass:** production flow and stateful executable fake share the Couch boundary; conformance tooling covers that seam.
   - **ARCH-CONSTRAINTS — pass:** deadline, child termination, and 4/8-turn work bounds are exercised.
   - **ARCH-SECURE — pass:** acknowledgments require matching identity, path, token, and ownership evidence.
   - **ARCH-ORDER — pass:** transitions own history; witnessed outcomes reject stale completions.
   - **ARCH-FUNERAL — pass:** temporary gates/mappings restore on admission or detach; no new production artifact family grows.
   - **ARCH-EVOLVE — pass:** existing journal formats remain unchanged and retain opaque protection bytes.

7. **Plan revisions:** None required. Recorded-suite completion and the approved post-review stage/clear remain landing obligations.

<!-- sdlc-review-usage [{"version":1,"intent":{"disposable_root":true,"id":"4bd5859c-b143-442e-8d75-0480f6ec28df","repository":"github.com/xianxu/parley.nvim","issue_id":"000408","recipe":"milestone-review","round":3,"attempt":1,"agent":"codex","root":"/Volumes/TestScratch/review-checkouts/b936ef8f4f9f6565","reviewed_head":"4805170dcbd53e6d71529c75ac2a2881f76e2416","slot":"parley.nvim:1","requested_at":"2026-10-22T09:44:06.968586Z"},"phase":"finished","pid":48334,"started_at":"2026-10-22T09:44:07.135625Z","finished_at":"2026-10-22T09:49:34.004179Z","session_id":"01a162ff-1852-7323-88fc-c28fcfef002d","outcome":"returned"}] -->
