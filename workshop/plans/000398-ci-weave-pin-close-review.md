# Boundary Review — parley.nvim#398 (whole-issue close)

| field | value |
|-------|-------|
| issue | 398 — CI: build weave from a pinned ariadne commit |
| repo | parley.nvim |
| issue file | workshop/issues/000398-ci-weave-pin.md |
| boundary | whole-issue close |
| milestone | — |
| window | d292a18656c5659e4fb8991cc10511ecc32048b2..8488538679a6e9759c229979cbd85bc59460961f |
| command | sdlc close --issue 398 |
| reviewer | codex (openai; author openai) |
| isolation | fenced |
| timestamp | 2026-10-19T22:17:11-07:00 |
| verdict | FIX-THEN-SHIP |

## Review

```verdict
verdict: FIX-THEN-SHIP
confidence: high
```

The executable migration matches the Spec: the approved compiler is built and verified before bootstrap, failure paths stop execution, and the workflows match the reviewed upstream templates. Conformance checks passed. The remaining gap is documentation for the newly authored pin and CI flow. Operator verification remains pending as the tracker explicitly records.

```findings
findings:
  - id: new
    severity: Important
    kind: defect
    family: surface-documentation
    title: |
      README and atlas updates are missing for the compiler-pin surface
    detail: |
      .sdlc/weave-compiler-ref:1 and .github/workflows/merge-check.yml:23 introduce consumer-owned compiler configuration and a new acquisition/build flow, but this range changes neither README.md nor atlas/. Document the pin location, format, bump/recovery procedure and operator verification in README's contributor guidance, and add an indexed repository-owned atlas entry linking the upstream contract. The inherited, ignored atlas/workflow projection does not provide the same-range atlas update required by this review's docs gate.
```

1. **Strengths**

   - Strict pin validation precedes fetching; source HEAD and binary revision/cleanliness are checked before PATH publication (`merge-check.yml:38–106`).
   - Both changed workflows match the reviewed upstream templates byte-for-byte.
   - The authored pin is absent from `construct/base.manifest`; real compiler conformance confirms preservation.
   - Bootstrap, repository setup and merge checks retain their required ordering.

2. **Critical findings**

   None.

3. **Important findings**

   The documentation finding above. Add concise contributor instructions near `README.md:184` and an indexed atlas map. Avoid maintaining another workflow implementation.

4. **Minor findings**

   None.

5. **Test coverage notes**

   - Passed upstream actual-block conformance covering malformed/missing pins, fetch/build/identity/metadata failures, older PATH exclusion, ordering and event ranges.
   - Passed real pinned-compiler compatibility checks across six noun exports: changed cold regeneration, unchanged cold output, and tampered/missing/malformed/symlink/undeclared refusal controls.
   - Confirmed binary metadata identifies `63d6bfd86509d97649e10d7a5dd1e9a06db17d21`, with `vcs.modified=false`.
   - Independently checked [CI run 39370460605](https://github.com/xianxu/parley.nvim/actions/runs/39370460605): Go 1.26.3, correct compiler identity, bootstrap before setup, and both merge checks passed.
   - The recorded suite status is successful. Its tested commit differs from the reviewed head only in the issue file. The full product suite was not rerun here.
   - No prior findings require disposition.

6. **Architectural notes for upcoming work**

   - **ARCH-DRY — pass:** upstream template reuse confirmed; shared build rule avoids duplicate build logic.
   - **ARCH-PURE — pass:** changes are confined to CI orchestration; no product logic moves into IO.
   - **ARCH-PURPOSE — pass:** the active merge-check consumer uses the exact approved compiler before bootstrap.
   - **ARCH-MOCK — pass:** actual workflow blocks exercise stateful command/filesystem fixtures, supplemented by real compiler and hosted CI execution.
   - **ARCH-CONSTRAINTS — pass:** consumer work is one compiler checkout/build within a 45-minute job timeout.
   - **ARCH-SECURE — pass:** bounded strict parsing, quoted arguments, read-only permissions and provenance checks enforce the relevant boundaries.
   - **ARCH-ORDER — pass:** sequential steps publish PATH only after successful verification; failure prevents bootstrap.
   - **ARCH-FUNERAL — pass:** compiler sources and binaries live in runner-temporary storage and end with the hosted job.
   - **ARCH-EVOLVE — pass:** no existing persisted format changes meaning or undergoes a lossy rewrite.

7. **Plan revision recommendations**

   Add a `## Revisions` entry covering repository-owned README/atlas documentation. Correct the issue’s line 76 rationale: inherited upstream documentation exists, but the explicit same-range docs gate still requires an update here.

<!-- sdlc-review-usage [{"version":1,"intent":{"disposable_root":true,"id":"746ea4df-bebc-4d33-abc2-e180fa852ac6","repository":"github.com/xianxu/parley.nvim","issue_id":"000398","recipe":"milestone-review","round":1,"attempt":1,"agent":"codex","root":"/Volumes/TestScratch/review-checkouts/f69f9f9b9964edb8","reviewed_head":"8488538679a6e9759c229979cbd85bc59460961f","slot":"parley.nvim:2","requested_at":"2026-10-20T05:15:25.013144Z"},"phase":"finished","pid":2741,"started_at":"2026-10-20T05:15:25.27134Z","finished_at":"2026-10-20T05:17:10.425979Z","session_id":"01a157bc-6178-7d93-a54c-ccf82a3c06c0","outcome":"returned"}] -->

---

## Re-review — 2026-10-19T22:59:09-07:00 (SHIP)

| field | value |
|-------|-------|
| issue | 398 — CI: build weave from a pinned ariadne commit |
| repo | parley.nvim |
| issue file | workshop/issues/000398-ci-weave-pin.md |
| boundary | whole-issue close |
| milestone | — |
| window | d292a18656c5659e4fb8991cc10511ecc32048b2..79b7328ce077d82d381dd838beaae10ce514774f |
| command | sdlc close --issue 398 |
| reviewer | codex (openai; author openai) |
| isolation | fenced |
| timestamp | 2026-10-19T22:59:09-07:00 |
| verdict | SHIP |

## Review

```verdict
verdict: SHIP
confidence: high
```

The pinned range satisfies the issue’s compiler migration contract. The workflow validates and builds the exact compiler before bootstrap, verifies provenance, and preserves failure propagation and execution order. BR-1’s documentation correction is complete. No new blocking findings were identified.

```findings
dispose:
  - id: BR-1
    disposition: addressed
    note: |
      README.md:190–193 documents the authored pin, format and operator approval; atlas/infra/ci_compiler.md:3–26 explains ownership, verification, updates and recovery, indexed at atlas/index.md:87 and linking the inherited contract at line 28. These passages agree with the workflow’s validation, build and PATH ordering and the manifest’s exclusion of the pin. This is a prose-only correction; no executable regression test is required.
```

Done-when: current — it still covers exact compiler selection, cold regeneration and refusal safety, pin preservation, operator verification and acceptance reporting.

1. **Strengths**

   - Both changed workflows match the upstream templates byte for byte.
   - Strict pin parsing, fetched-HEAD checks and clean binary metadata verification precede PATH publication (`.github/workflows/merge-check.yml:38–114`).
   - Repository-owned documentation now covers the complete compiler configuration lifecycle.
   - Independently confirmed successful [hosted CI](https://github.com/xianxu/parley.nvim/actions/runs/39370460605), recorded suite success and the operator-held label on [PR #323](https://github.com/xianxu/parley.nvim/pull/323).

2. **Critical findings**

   None.

3. **Important findings**

   None remaining.

4. **Minor findings**

   None.

5. **Test coverage notes**

   - Passed actual-workflow-block conformance: malformed/missing pins, fetch/build/provenance failures, older PATH exclusion, execution ordering and event ranges.
   - Passed real pinned-compiler compatibility checks across six noun exports: changed and unchanged cold outputs, tampered/missing/malformed/symlink/undeclared refusal controls, and authored-pin preservation.
   - Verified the compiler binary reports the approved revision and `vcs.modified=false`.
   - Full product suite was not rerun. Its recorded successful commit has identical executable content to this head; subsequent changes are documentation and tracker artifacts.
   - Whitespace checks passed.

6. **Architectural notes for upcoming work**

   - **ARCH-DRY — pass:** shared upstream templates and one build rule.
   - **ARCH-PURE — pass:** changes remain in CI orchestration.
   - **ARCH-PURPOSE — pass:** the active consumer builds and uses the approved compiler before bootstrap.
   - **ARCH-MOCK — pass:** stateful command/filesystem fixtures exercise production Bash blocks; real compiler and hosted checks supplement them.
   - **ARCH-CONSTRAINTS — pass:** one consumer compiler checkout/build, bounded by the job timeout.
   - **ARCH-SECURE — pass:** bounded parsing, quoted arguments, read-only permissions and provenance checks.
   - **ARCH-ORDER — pass:** sequential verification precedes PATH publication and bootstrap; failures stop progression.
   - **ARCH-FUNERAL — pass:** acquisition/build artifacts use runner-temporary storage; test fixtures clean up automatically.
   - **ARCH-EVOLVE — pass:** no lossy persisted-format rewrite or changed field meaning.

7. **Plan revision recommendations**

   None. The existing BR-1 revision accurately records the documentation repair.

<!-- sdlc-review-usage [{"version":1,"intent":{"disposable_root":true,"id":"8f15ebb9-55c8-4d9f-a6f2-cd13d671240f","repository":"github.com/xianxu/parley.nvim","issue_id":"000398","recipe":"milestone-review","round":2,"attempt":1,"agent":"codex","root":"/Volumes/TestScratch/review-checkouts/c2cf284fc7281b86","reviewed_head":"79b7328ce077d82d381dd838beaae10ce514774f","slot":"parley.nvim:2","requested_at":"2026-10-20T05:57:05.648329Z"},"phase":"finished","pid":20939,"started_at":"2026-10-20T05:57:06.042072Z","finished_at":"2026-10-20T05:58:30.944807Z","session_id":"01a157e2-8a40-7380-9206-6973682c626c","outcome":"returned"}] -->
