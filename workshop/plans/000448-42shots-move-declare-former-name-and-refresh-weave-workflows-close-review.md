# Boundary Review — parley.nvim#448 (whole-issue close)

| field | value |
|-------|-------|
| issue | 448 — 42shots move: declare former name and refresh weave workflows |
| repo | parley.nvim |
| issue file | workshop/issues/000448-42shots-move-declare-former-name-and-refresh-weave-workflows.md |
| boundary | whole-issue close |
| milestone | — |
| window | af5aa66cf65e211df951a1e743d6f7a96c685015..ebc189afcaf84db73ea2850f66b5405e648ed56d |
| command | sdlc close --issue 448 |
| reviewer | claude (anthropic; author anthropic) |
| isolation | fenced |
| timestamp | 2026-10-26T11:13:04-07:00 |
| verdict | SHIP |

## Review

The workflows match the substrate byte for byte. Next I'm checking how sdlc reads `repository.json` and whether the vocabulary hash matches.

```verdict
verdict: SHIP
confidence: high
```

This change does what the Spec asks, and I checked each part against the code rather than the log. `.sdlc/repository.json` contains exactly `{"former_names": ["github.com/xianxu/parley.nvim"]}` plus a trailing newline. That is the format the substrate's strict reader expects (`cmd/sdlc/internal/gitx/repoidentity.go:82`, `jsonstrict.DecodeObject` with `former_names`). Both seeded workflows match the pinned ariadne substrate byte for byte, at head `ab5f74ec` and at `2e1114ec`. Both of those commits are descendants of `ee3d24ba`, as the Spec requires. `.sdlc/weave-compiler-ref` does not change in the window. The log worried that the vocabulary might be stale; commit `83d8dddb` regenerated it, and the new `issue.json` hashes to the value recorded in `issue.json.weave-sha256` (`cb7f2434…`). Nothing blocks SHIP. The three Minor findings are all about the issue file not being kept in step with what was done.

1. **Strengths**
   - `.github/workflows/merge-check.yml` and `.github/workflows/local-gates-guard.yml` match the substrate exactly (`cmp` against `$SDLC_DEP_SUBSTRATE/.github/workflows/*`). No hand edits drifted from the source of truth.
   - `.sdlc/repository.json:1` uses the exact shape the reader's error message prescribes (`repoidentity.go:53`). It has no extra keys and no duplicates.
   - The regenerated vocabulary is internally consistent. The `kind` enum, field and `card-enums-declared` entries were added together, and the sha sidecar matches the file.
   - `.gitignore:90` adds `side-doc.json` next to the generated entries it belongs with. It is already covered by `/construct/generated/vocabulary/*`, so this is harmless and produced by the generator.

2. **Critical findings**: none.

3. **Important findings**: none.

4. **Minor findings**
   - The `construct/deps` change to `42shots/ariadne.git` (`construct/deps:1`) is not in the Spec. The Log records that the TL approved it, but the Spec still says the branch is only the two listed items.
   - The Log's last entry ends with "Asked the hub how to proceed" about the stale vocabulary. It never records that `83d8dddb` regenerated it, so the issue file's story stops before the work does.
   - `## Plan` is still an empty `- [ ]`. That is acceptable for the quick flow, but the stub carries no information.

5. **Test coverage notes**
   - There is no executable code here; everything is configuration, and the contract checks are the gates. `repository.json` is checked against the reader's strict decoder, which already has tests for wrong type, null and duplicate keys (`repoidentity_test.go:55-58`). The workflow behaviour is covered upstream by ariadne's `scripts/test/portable-ci.test.sh`.
   - Both modes of the `CI_RUNS_ON` switch (unset and self-hosted) come from the substrate. This repo cannot exercise them until the TL sets the variable.

6. **Architectural notes**
   - **ARCH-DRY: pass.** The workflows are derived from the substrate rather than hand-copied with changes, and are byte-identical to it.
   - **ARCH-PURE: pass.** There is no logic in this diff.
   - **ARCH-PURPOSE: pass.** Both goals are met: the former-name declaration and workflows refreshed past `ee3d24ba` with the compiler ref unchanged. The process items in Done-when (issue closed, PR open, hub notified) are outside what the diff can show.
   - **ARCH-EVOLVE: pass.** `repository.json` is a new file with one known field. The reader tolerates unknown keys (`"later":1` test, `repoidentity_test.go:47`). The vocabulary change only adds entries.
   - Upstream, not for this repo: the seeded `merge-check.yml` still checks `CI_REPOSITORY = xianxu/ariadne` and the `github.com/xianxu/ariadne` module path. After the 42shots move, that is ariadne's to update.

7. **Plan revision recommendations**
   - Add a Spec or `## Revisions` line: "3. Repoint `construct/deps` substrate to `https://github.com/42shots/ariadne.git` (TL-approved; satisfies both the refresh origin check and acquire.checkExisting)."
   - Add a Log line recording that `83d8dddb` regenerated `issue.json` and the `.gitignore` entries, closing the stale-vocabulary question.

```findings
findings:
  - id: new
    severity: Minor
    kind: defect
    family: spec-tracks-delivered-scope
    title: |
      construct/deps repoint to 42shots/ariadne is delivered but absent from Spec
    detail: |
      construct/deps:1 changes the substrate URL; the Spec still lists only repository.json and the workflow refresh. TL approval is in the Log only. This is the only instance in the window; add it as a Spec item or a Revisions entry.
  - id: new
    severity: Minor
    kind: defect
    family: log-records-resolution
    title: |
      Log leaves the stale-vocabulary question open though 83d8dddb resolved it
    detail: |
      The last Log entry ends "Asked the hub how to proceed"; commit 83d8dddb regenerated issue.json (sha verified as cb7f2434...) and .gitignore without a Log line. This is the only instance in the window.
  - id: new
    severity: Minor
    kind: defect
    family: spec-tracks-delivered-scope
    title: |
      Plan section is an empty checklist stub
    detail: |
      The issue's Plan is a bare checkbox; acceptable for the quick flow but it carries no information. This is the only instance in the window.
```

<!-- sdlc-review-usage [{"version":1,"intent":{"disposable_root":true,"id":"466547a6-2852-4753-99d8-35087c1bab24","repository":"github.com/42shots/parley.nvim","issue_id":"000448","recipe":"small-diff-review","round":1,"attempt":1,"agent":"claude","root":"/Volumes/TestScratch/review-checkouts/c9e70369b3638ccc","reviewed_head":"ebc189afcaf84db73ea2850f66b5405e648ed56d","slot":"parley.nvim:1","requested_at":"2026-10-26T18:12:19.250334Z"},"phase":"finished","pid":80701,"started_at":"2026-10-26T18:12:19.334993Z","finished_at":"2026-10-26T18:13:03.431446Z","session_id":"9cd40308-932c-4e1d-b1f3-4d03092a1841","outcome":"returned"}] -->
