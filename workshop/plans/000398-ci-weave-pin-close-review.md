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
