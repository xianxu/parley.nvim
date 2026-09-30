# Boundary Review — parley.nvim#306 (whole-issue close)

| field | value |
|-------|-------|
| issue | 306 — Bundle tested editor dependencies for offline app startup |
| repo | parley.nvim |
| issue file | workshop/issues/000306-bundled-editor-dependencies.md |
| boundary | whole-issue close |
| milestone | — |
| window | c57c616af1a940877b9e7160973c2da7d632490f..e2b868cd6f2066e53cfdaefa99777860b5ea10de |
| command | sdlc close --issue 306 |
| reviewer | codex |
| timestamp | 2026-09-30T11:46:59-07:00 |
| verdict | REWORK |

## Review

```verdict
verdict: REWORK
confidence: high
```

The manifest, bundled startup, and release integration are well covered, but writable-bundle verification does not establish source identity independently of its editable receipt. I reproduced that bypass and a separate download-deadline violation. Both need regression coverage before closing.

1. **Strengths**

   - Manifest projections centralize plugin pins and platform artifacts; tests check membership and defensive copies.
   - Bundled startup disables dependency installation, build hooks, rocks, and project-local specs.
   - Real subprocess tests verify lease inheritance and protection after parent termination.
   - Release tests exercise tagged-tree validation, failed publication, and retries. README and atlas document offline scope and migration.

2. **Critical findings**

   **Editable receipts can certify modified source** — [scripts/editor-dependencies.py:213](/Users/xianxu/workspace/parley.nvim/scripts/editor-dependencies.py:213), **ARCH-SECURE / ARCH-PURPOSE**.

   `verify_bundle` compares files against hashes from the same writable bundle’s receipt. Manifest equality does not bind those hashes to the pinned source archives; only the Preview executable has an independently checked payload hash.

   Reproduction: assemble the fixture, modify its plugin `init.lua`, regenerate the receipt with `seal_bundle`, then call `verify_bundle` and `prepare_bundle`. Both accept the modified source.

   Bind the complete expected payload inventory to trusted manifest data, or derive it from independently checksum-verified retained archives. Add regression cases for modified, added, and removed source files with correspondingly changed receipts.

3. **Important findings**

   **Download deadline is checked after a potentially unbounded read** — [scripts/editor-dependencies.py:281](/Users/xianxu/workspace/parley.nvim/scripts/editor-dependencies.py:281), **ARCH-CONSTRAINTS**.

   `urlopen(timeout=TIMEOUT)` limits socket inactivity, while `read(1 MiB)` can keep receiving small chunks beyond the total deadline. The elapsed-time check runs only afterward.

   A local drip-response fixture with `TIMEOUT=0.1` took **0.535 seconds** before rejection. Enforce the remaining wall-clock budget during network reads and add a slow-response regression.

4. **Minor findings**

   None.

5. **Test coverage notes**

   Independently passed: **86 packaging tests**, **15 artifact tests**, **13 local-launcher tests**, and pinned-range `git diff --check`. Repository remains unchanged.

   The harness could not perform its process census because `ps` was unavailable. I did not rerun real upstream offline conformance or an actual Homebrew installation. Existing tests miss both reproduced cases above.

6. **Architectural notes**

   - **ARCH-DRY — pass:** shared dependency records drive the main consumers.
   - **ARCH-PURE — pass:** manifest/projection logic is separated from artifact IO.
   - **ARCH-PURPOSE — flag:** source-parity verification remains incomplete.
   - **ARCH-MOCK — pass:** filesystem-backed artifacts, HTTP fixtures, and real subprocesses exercise boundaries.
   - **ARCH-CONSTRAINTS — flag:** download wall-clock bound is unenforced during reads.
   - **ARCH-SECURE — flag:** writable receipt hashes become trusted identity evidence.
   - **ARCH-ORDER — pass:** publication, interrupted staging, and inherited lease ordering have explicit handling and tests.
   - **ARCH-FUNERAL — pass:** staging cleanup, obsolete-bundle collection, repair, and keg lifecycle cover new artifacts.

7. **Plan revision recommendations**

   Append dated `## Revisions` entries specifying the independently trusted payload identity mechanism and the enforced network deadline, including their adversarial regression tests.

```findings
findings:
  - id: new
    severity: Critical
    family: payload-identity-trust
    title: |
      Writable receipts can certify modified plugin source
    detail: |
      scripts/editor-dependencies.py:203-214 compares source files against editable receipt hashes without binding that inventory to trusted archive identities. Modifying plugin source and regenerating its receipt passes verify_bundle and prepare_bundle. Bind expected payload identity to trusted manifest data or checksum-verified archives, with changed-receipt regressions (ARCH-SECURE, ARCH-PURPOSE).
  - id: new
    severity: Important
    family: wall-clock-deadline-enforcement
    title: |
      Streaming downloads can exceed the declared deadline inside read
    detail: |
      scripts/editor-dependencies.py:277-286 checks elapsed time only after read(1 MiB); the socket timeout measures inactivity. A drip-response reproduction exceeded a 0.1-second budget for 0.535 seconds before rejection. Enforce the remaining deadline during IO and add a slow-response regression (ARCH-CONSTRAINTS).
```

---

## Re-review — 2026-09-30T12:03:41-07:00 (REWORK)

| field | value |
|-------|-------|
| issue | 306 — Bundle tested editor dependencies for offline app startup |
| repo | parley.nvim |
| issue file | workshop/issues/000306-bundled-editor-dependencies.md |
| boundary | whole-issue close |
| milestone | — |
| window | c57c616af1a940877b9e7160973c2da7d632490f..5133c829d37af1993cc84fdae4167fa968c53baa |
| command | sdlc close --issue 306 |
| reviewer | codex |
| timestamp | 2026-09-30T12:03:41-07:00 |
| verdict | REWORK |

## Review

```verdict
verdict: REWORK
confidence: high
```

Both prior findings are addressed, with regressions that fail when the fixes are removed. One standalone migration gap remains: the new starter accepts older cached runtimes, then fails before loading the tool users are told to use for updates. Packaging validation also had a failure noted below.

```findings
dispose:
  - id: BR-1
    disposition: addressed
    note: |
      Source inventories are bound to trusted manifest hashes in scripts/editor-dependencies.py:185-195. All five changed-receipt regressions pass; restoring the previous check_layout makes every variant fail.
  - id: BR-2
    disposition: addressed
    note: |
      scripts/editor-dependencies.py:277-351 bounds blocking IO with worker deadlines and kill/reap cleanup. Slow-header/body regressions pass; restoring the previous fetch_archive makes them exceed the budget at approximately 0.8 seconds.
findings:
  - id: new
    severity: Important
    family: starter-runtime-compatibility
    title: |
      Standalone migration accepts runtimes missing newly required modules
    detail: |
      packaging/starter-config/init.lua:97-109 checks only theme.lua before requiring editor_dependencies and editor_bundle. An isolated cached pre-change runtime reproduces module-not-found before Lazy loads, making the documented :Lazy update recovery unavailable. Validate required capabilities for both fresh and cached runtimes, reject incompatible staging before publication, provide external recovery instructions, and add regressions preserving existing checkout contents (ARCH-PURPOSE, ARCH-SECURE).
```

1. **Strengths**
   - Sealing, verification and reuse enforce the same independently pinned source identity.
   - Download regressions exercise real trickling HTTP responses and verify worker cleanup.
   - Formula resources derive from the manifest; bundled startup disables installation/build paths.
   - Release checks use the tagged tree before tap mutation, including retries.

2. **Critical findings:** None.

3. **Important findings**
   - **Standalone compatibility:** [init.lua:97](/Users/xianxu/workspace/parley.nvim/packaging/starter-config/init.lua:97). Both fresh and cached runtime checks need the new module requirements. [Starter guidance:24](/Users/xianxu/workspace/parley.nvim/packaging/starter-config/README.md:24) still recommends an update command unavailable after this failure. Existing fixtures always include the new modules, masking the migration case.

4. **Minor findings:** None.

5. **Test coverage notes**
   - Artifact/download tests: **23 passed**.
   - Local launcher tests: **13 passed**.
   - Mutation checks independently confirmed both prior regressions.
   - `git diff --check` passed.
   - `make test-spec SPEC=infra/packaging` **failed** at `packaging_vm_spec.lua:167`: “guest chat file escaped isolated profile.” Attribution to this change remains unestablished. Process census was unavailable because `ps` was blocked.
   - Actual Homebrew installation and full offline conformance were not rerun in this review.

6. **Architectural notes**
   - **ARCH-DRY — pass:** dependency pins and checksums have one manifest.
   - **ARCH-PURE — pass:** manifest/projection logic remains separate from artifact IO.
   - **ARCH-PURPOSE — flag:** standalone migration is incomplete.
   - **ARCH-MOCK — pass:** filesystem, HTTP and subprocess tests exercise stateful boundaries.
   - **ARCH-CONSTRAINTS — pass:** download deadlines and size limits have behavioral coverage.
   - **ARCH-SECURE — flag:** cross-version runtime capability validation is incomplete; payload trust repair passes.
   - **ARCH-ORDER — pass:** publication leases, conversion rechecks and parent-death tests cover relevant ordering.
   - **ARCH-FUNERAL — pass:** staging, obsolete bundles and download workers have cleanup paths.

7. **Plan revision recommendation**
   - Append a `## Revisions` entry covering fresh/cached runtime capability checks, external upgrade guidance, and migration regressions that preserve existing user checkouts.

---

## Re-review — 2026-09-30T12:57:05-07:00 (SHIP)

| field | value |
|-------|-------|
| issue | 306 — Bundle tested editor dependencies for offline app startup |
| repo | parley.nvim |
| issue file | workshop/issues/000306-bundled-editor-dependencies.md |
| boundary | whole-issue close |
| milestone | — |
| window | c57c616af1a940877b9e7160973c2da7d632490f..00fa14f988ba2912224e0069212ac98cbb5d488f |
| command | sdlc close --issue 306 |
| reviewer | codex |
| timestamp | 2026-09-30T12:57:05-07:00 |
| verdict | SHIP |

## Review

```verdict
verdict: SHIP
confidence: medium
```

The pinned implementation satisfies the issue’s bundle, verification, migration, and documentation contracts. BR-3 is addressed with regression tests that fail when its guard is removed. No new blocking findings. Confidence is limited by a packaging VM containment-test failure described below.

```findings
dispose:
  - id: BR-1
    disposition: addressed
    note: |
      Source inventories remain bound to manifest hashes independently of writable receipts. Tamper-and-regenerate regression tests passed.
  - id: BR-2
    disposition: addressed
    note: |
      Download workers enforce total deadlines and are reaped before partial-file removal. Slow-header, slow-body, and independent worker-deadline tests passed.
  - id: BR-3
    disposition: addressed
    note: |
      packaging/starter-config/init.lua:85 checks all three required modules before fresh publication or cached selection. Tests at tests/integration/starter_bootstrap_spec.lua:120 verify rejection, cleanup, external recovery, and checkout preservation. Removing the guard in a temporary pinned copy produced exactly six failures; the other 14 tests passed.
```

1. **Strengths**

   - Manifest-derived pins reach starter, theme, recording, formula, and release consumers.
   - Bundle verification checks independent source identity, binary identity, and complete payload inventories.
   - Publication and cleanup share a lease retained by the consuming editor; tests cover parent death and lock-conversion interference.
   - BR-3 recovery documentation names terminal Git and matching-runtime recovery before Lazy is available.

2. **Critical findings:** None.

3. **Important findings:** None introduced by this range.

4. **Minor findings:** None.

5. **Test coverage notes**

   - Passed: 25 Python bundle/download tests; 13 local-launcher tests; mapped starter suite, including 20 bootstrap tests.
   - BR-3 mutation: six expected failures, 14 passes.
   - Packaging suite: 85 passed, one failed at `tests/integration/packaging_vm_spec.lua:167`, reporting guest chat **file** containment.
   - Separate pinned base and head copies both returned 16 passes and one failure in that same VM test, at its earlier chat **root** containment assertion. These comparisons do not explain the original failure; the relevant VM probe and starter code are unchanged.
   - `git diff --check` passed; repository remained clean.
   - Real offline conformance and an actual Homebrew installation were not rerun during this review.

6. **Architectural notes**

   - **ARCH-DRY — Pass:** dependency identities derive from the shared manifest.
   - **ARCH-PURE — Pass:** manifest/projection logic stays separate from provisioning IO.
   - **ARCH-PURPOSE — Pass:** app and recording consumers, release validation, and migration are covered.
   - **ARCH-MOCK — Pass:** filesystem-backed fixtures, real local HTTP responses, and process tests exercise production boundaries.
   - **ARCH-CONSTRAINTS — Pass:** archive limits, total deadlines, and bounded lease contention are enforced.
   - **ARCH-SECURE — Pass:** checksums, inventory binding, archive validation, and ownership checks defend the declared boundaries.
   - **ARCH-ORDER — Pass:** publication is serialized; inherited leases and post-conversion verification protect reader lifetime.
   - **ARCH-FUNERAL — Pass:** owned staging and obsolete bundles have cleanup paths; installed payload lifetime follows the keg.

7. **Plan revision recommendations:** None. Existing revisions explain the archive-only cache design, removal of the unused decision helper, and BR-3’s compatibility checks.

---

## Re-review — 2026-09-30T13:11:34-07:00 (SHIP)

| field | value |
|-------|-------|
| issue | 306 — Bundle tested editor dependencies for offline app startup |
| repo | parley.nvim |
| issue file | workshop/issues/000306-bundled-editor-dependencies.md |
| boundary | whole-issue close |
| milestone | — |
| window | c57c616af1a940877b9e7160973c2da7d632490f..5517c3bac4e0389da4262d74e24e0bf2aa1e8707 |
| command | sdlc close --issue 306 |
| reviewer | codex |
| timestamp | 2026-09-30T13:11:34-07:00 |
| verdict | SHIP |

## Review

```verdict
verdict: SHIP
confidence: high
```

The pinned range satisfies the issue’s revised contract. Dependency identities derive from one manifest, writable bundles receive independent payload verification, and dependency reset preserves user data. No new blocking findings emerged. All three prior corrections remain addressed.

1. **Strengths**
   - Manifest projections cover app, recording, theme and Homebrew consumers.
   - Bundle publication and repair share ownership checks and reader/writer leases.
   - `parley_app` reuses the repair operation for dependency-only `--nuke`; tests cover preservation, repeated cleanup, reprovisioning and contention.
   - README and atlas document offline scope, standalone recovery and starter migration.

2. **Critical findings:** None.

3. **Important findings:** None.

4. **Minor findings:** None.

5. **Test coverage**
   - Passed: 19 artifact tests, 6 download tests, 14 launcher tests and all 86 mapped packaging tests.
   - Mutation checks confirmed that removing BR-1’s source binding breaks forged-receipt regressions, and restoring BR-2’s old downloader breaks slow-header/body deadline tests.
   - Inspected BR-3’s six fresh/cached missing-module regressions and reachable guards; did not rerun that suite.
   - Pinned-range whitespace check passed.
   - Live offline conformance and actual Homebrew installation were not rerun. The harness could not check orphan processes because `ps` was unavailable.

6. **Architecture**
   - **ARCH-DRY — pass:** consumers derive pins from the shared manifest.
   - **ARCH-PURE — pass:** deterministic projections remain separate from filesystem/process orchestration.
   - **ARCH-PURPOSE — pass:** shipped and recording dependencies, local verification and migration are covered.
   - **ARCH-MOCK — pass:** stateful archive, HTTP and release fixtures exercise production boundaries.
   - **ARCH-CONSTRAINTS — pass:** download deadlines and size bounds are enforced; bundled startup disables dependency installation.
   - **ARCH-SECURE — pass:** archive validation and independent source identities protect payload selection.
   - **ARCH-ORDER — pass:** lease-scoped publication, downgrade revalidation and inherited reader ownership cover relevant ordering.
   - **ARCH-FUNERAL — pass:** staging and obsolete bundles have cleanup paths; installed bundles follow keg lifetime.

7. **Plan revision recommendations:** None. Existing revisions explain the implemented deviations and dependency-reset refinement.

```findings
dispose:
  - id: BR-1
    disposition: addressed
    note: |
      Seal and verification enforce manifest-pinned source inventories; removing that binding makes modified, added, removed and executable-mode forged-receipt regressions fail.
  - id: BR-2
    disposition: addressed
    note: |
      Deadline-owned workers bound blocking downloads and are reaped before cleanup; restoring the old downloader makes real slow-header and slow-body regressions fail.
  - id: BR-3
    disposition: addressed
    note: |
      Fresh and cached standalone runtime selection checks required modules before Lazy loads; six inspected regressions assert rejection, staging cleanup, cached checkout preservation and external recovery guidance.
```

---

## Re-review — 2026-09-30T13:28:45-07:00 (SHIP)

| field | value |
|-------|-------|
| issue | 306 — Bundle tested editor dependencies for offline app startup |
| repo | parley.nvim |
| issue file | workshop/issues/000306-bundled-editor-dependencies.md |
| boundary | whole-issue close |
| milestone | — |
| window | 8a650a36bdf9f0974c00e4b611ff909d9b48dcad..0f1671540c9a0b35c54788b11fd2b432c41aeb2b |
| command | sdlc close --issue 306 |
| reviewer | codex |
| timestamp | 2026-09-30T13:28:45-07:00 |
| verdict | SHIP |

## Review

```verdict
verdict: SHIP
confidence: medium
```

The pinned range delivers the shared dependency manifest, verified local bundles, packaged startup, and migration contract. No new blocking defects found. Prior fixes remain addressed. Validation is qualified by an unrelated packaging guard failure and real offline/Homebrew checks not rerun during this review.

1. **Strengths**
   - Source identity is independently pinned; rewritten receipts cannot certify modified plugins (`scripts/editor-dependencies.py:194`).
   - Downloads have process-owned deadlines, worker reaping, and partial-file cleanup.
   - Starter compatibility checks protect both fresh staging and existing checkouts (`packaging/starter-config/init.lua:85`).
   - Release tests verify tagged-tree conformance precedes tap mutation; README and atlas document the new surface.

2. **Critical findings:** None.

3. **Important findings:** None.

4. **Minor findings:** None.

5. **Test coverage**
   - Passed: 25 bundle/download tests, 14 launcher tests, 199 starter tests.
   - Packaging behavior tests passed. Its architecture guard failed because it compares against an older merge-base and attributes `project_root` to this issue; that symbol already exists at the pinned base.
   - Removing the source-identity check in memory made four tampering regression cases fail.
   - `git diff --check` passed; checkout remains clean.
   - Real offline conformance and Homebrew installation were not rerun. Process census was unavailable because `ps` is restricted.

6. **Architecture**
   - **ARCH-DRY — pass:** dependency identities derive from one manifest across consumers.
   - **ARCH-PURE — pass:** deterministic registry/projections remain separate from assembly and startup IO.
   - **ARCH-PURPOSE — pass:** local, installed, recording, and release paths are covered.
   - **ARCH-MOCK — pass:** filesystem, HTTP, and process fixtures exercise persisted behavior; live conformance is wired into releases.
   - **ARCH-CONSTRAINTS — pass:** downloads, extraction, and lock waits have explicit bounds.
   - **ARCH-SECURE — pass:** independent hashes, archive validation, and owned-root checks enforce the documented boundaries.
   - **ARCH-ORDER — pass:** exclusive publication, inherited reader leases, downgrade revalidation, and recovery have sequence coverage.
   - **ARCH-FUNERAL — pass:** staging and obsolete bundles have cleanup paths; installed bundles follow keg ownership.

7. **Plan revisions:** None required; existing revisions reconcile implementation choices.

```findings
dispose:
  - id: BR-1
    disposition: addressed
    note: |
      Independent source inventory hashes protect seal, verify, and reuse. Tampering regressions pass; removing the identity check in memory produces four failures.
  - id: BR-2
    disposition: addressed
    note: |
      Blocking downloads run in deadline-owned workers with kill/reap cleanup and a worker alarm. Real dripping-header/body, worker-deadline, and partial-file regressions pass.
  - id: BR-3
    disposition: addressed
    note: |
      Starter compatibility checks enumerate all three required modules before fresh publication or cached loading. Six fresh/cached regressions pass and verify preservation and actionable recovery.
```
