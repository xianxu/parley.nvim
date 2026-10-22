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
