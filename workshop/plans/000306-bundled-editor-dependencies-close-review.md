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
