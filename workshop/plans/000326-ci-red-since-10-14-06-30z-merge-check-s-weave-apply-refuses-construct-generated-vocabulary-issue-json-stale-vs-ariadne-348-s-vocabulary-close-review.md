# Boundary Review — parley.nvim#326 (whole-issue close)

| field | value |
|-------|-------|
| issue | 326 — CI red since 10-14 06:30Z: merge-check's weave apply refuses construct/generated/vocabulary/issue.json (stale vs ariadne#348's vocabulary) |
| repo | parley.nvim |
| issue file | workshop/issues/000326-ci-red-since-10-14-06-30z-merge-check-s-weave-apply-refuses-construct-generated-vocabulary-issue-json-stale-vs-ariadne-348-s-vocabulary.md |
| boundary | whole-issue close |
| milestone | — |
| window | 62a35b2aeb4a849cee910062a35ea02f0b5dba29..d42134d9a9cd4abc9168e794b5371a83e599c112 |
| command | sdlc close --issue 326 |
| reviewer | codex |
| isolation | fenced |
| timestamp | 2026-10-14T10:31:31-07:00 |
| verdict | SHIP |

## Review

```verdict
verdict: SHIP
confidence: high
```

The one-line regeneration is correct: the complete artifact matches current Ariadne’s canonical export byte for byte, while the base artifact differs. Candidate CI passed bootstrap and merge-check, and the upstream class-fix ticket exists. Main CI confirmation remains a post-landing step; the Plan prematurely marks that step complete.

```findings
findings:
  - id: new
    severity: Minor
    family: completion-claims-require-evidence
    title: |
      The final Plan checkbox includes unfinished landing and main-CI confirmation.
    detail: |
      workshop/issues/000326-ci-red-since-10-14-06-30z-merge-check-s-weave-apply-refuses-construct-generated-vocabulary-issue-json-stale-vs-ariadne-348-s-vocabulary.md:40 marks review/merge and main merge-check confirmation complete, while line 55 explicitly says confirmation follows landing. GitHub shows PR 233 remains open and main remains at 6b39be28 with a failing merge-check. This is the only instance in the window; leave the item unchecked or split candidate validation from landing confirmation, then record the successful main run.
```

1. **Strengths**
   - [issue.json:91](construct/generated/vocabulary/issue.json:91) matches the canonical setter and complete upstream export; no unrelated generated drift.
   - Existing ownership protection remains intact. Inspection of `prepareManaged` supports the Log’s cold-versus-warm explanation.
   - [Ariadne tracker issue 368](https://github.com/xianxu/ariadne/blob/main/workshop/issues/000368-consumer-vocabulary-cold-ci.md) explicitly covers reproducibility, advancement, cold/warm checkouts, and authored-edit protection.
   - [Candidate CI](https://github.com/xianxu/parley.nvim/actions/runs/38602841874) passed every step. Its non-tracker content matches the reviewed head.

2. **Critical findings:** None.

3. **Important findings:** None.

4. **Minor findings:** Premature completion checkbox, detailed above.

5. **Test coverage notes**
   - All four `vocabulary_drift_spec.lua` tests passed.
   - Direct canonical comparison rejects the base artifact and accepts the head artifact, demonstrating sensitivity to this fix.
   - `git diff --check` passed.
   - Local `make -k check-vocabulary` could not resolve the noun without the compiled overlay; direct upstream export comparison established full parity.

6. **Architectural notes**
   - **ARCH-DRY: pass.** Regenerated from the existing source.
   - **ARCH-PURE: pass.** No logic or IO boundary changes.
   - **ARCH-PURPOSE: pass.** Consumer repair and the requested class analysis/ticket are delivered.
   - No new Parley command, configuration, or architectural surface requires README or atlas changes.

7. **Plan revision recommendations:** No `## Revisions` entry needed. Correct the checkbox and record main CI success after landing.
