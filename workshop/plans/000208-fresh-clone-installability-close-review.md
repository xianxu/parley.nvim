# Boundary Review — parley.nvim#208 (whole-issue close)

| field | value |
|-------|-------|
| issue | 208 — parley must install and load from a fresh clone |
| repo | parley.nvim |
| issue file | workshop/issues/000208-fresh-clone-installability.md |
| boundary | whole-issue close |
| milestone | — |
| window | 97155eca3ffc92e6e4ba47a7157d8f16048571ba..a03c9814883da20c75a26d50cc97d6092c119109 |
| command | sdlc close --issue 208 |
| reviewer | codex |
| timestamp | 2026-09-13T13:18:42-07:00 |
| verdict | REWORK |

## Review

```verdict
verdict: REWORK
confidence: high
```

The implementation delivers standalone loading and contributor testing: the pinned archive passed all four vocabulary variants and all 232 spec files. No critical runtime defect found. The explicit README documentation gate remains unmet; standalone `make help` also exposes a small discoverability gap.

1. **Strengths**
   - Vocabulary loading is bounded, anchored to the installed module, and caches explicit unavailable outcomes (`lua/parley/issue_vocabulary.lua:154`).
   - Unavailable-data tests exercise actual command/finder handlers and verify unchanged issue contents.
   - Shell-route tests use persistent fake state and injection-like titles across executable, function, and alias routes.
   - Archive acceptance independently exercises startup, chat creation, damaged data, and the complete test suite.

2. **Critical findings:** None.

3. **Important findings**
   - **README update missing for standalone contributor setup.** `Makefile.parley:233–251` introduces dependency checking and three verification commands; `TOOLING.md:13` documents them, but README.md is unchanged. Add a brief standalone-testing entry near `README.md:24`, with the `PLENARY` override and a link to the new TOOLING section. This satisfies the explicit README gate without duplicating detailed instructions.

4. **Minor findings**
   - **Standalone help is empty** (`Makefile:16`). `make --no-print-directory WF_WORKFLOW= help` exits successfully without output because the optional overlay supplies the help dependencies. Connect `help-parley` through the product-owned Makefile.local and cover help without the overlay.

5. **Test coverage notes**
   - Pinned full archive: **232 spec files passed**, zero failure blocks.
   - Lint: **zero warnings/errors**.
   - Intact/missing/corrupt/malformed startup variants passed.
   - Real vocabulary export comparison, read-only sdlc conformance, and range whitespace checks passed.
   - Evidence: `/tmp/parley208-boundary-review.log`.

6. **Architectural notes**
   - **ARCH-DRY — pass:** shipped vocabulary remains derived; semantic drift checking enforces it.
   - **ARCH-PURE — pass:** model validation/calculation remains separate from file loading and runtime adapters.
   - **ARCH-PURPOSE — pass:** independent loading and full contributor testing are demonstrated.
   - **ARCH-MOCK — pass:** creation tests share the production runner seam and persist requests/files.
   - **ARCH-CONSTRAINTS — pass:** bounded reads and cached probes match the operating envelope.
   - **ARCH-SECURE — pass:** isolated archive execution and literal command arguments are exercised.
   - **ARCH-ORDER — pass:** explicit cache states and reload/invalidation tests cover recovery.
   - **ARCH-FUNERAL — pass:** temporary archive/export state has cleanup ownership; shipped data is one replaceable file.

7. **Plan revision recommendations**
   - Append a `## Revisions` entry extending documentation acceptance to README discoverability and adding standalone help verification.

```findings
findings:
  - id: new
    severity: Important
    family: readme-surface-discoverability
    title: |
      README update appears missing for standalone contributor setup and verification commands
    detail: |
      Makefile.parley:233–251 adds dependency checking and verification commands, documented at TOOLING.md:13–46, while README.md is unchanged. Add a short contributor entry near README.md:24 showing the PLENARY override and linking to standalone setup; the explicit README gate requires this surface to be discoverable there.
  - id: new
    severity: Minor
    family: optional-overlay-help-ownership
    title: |
      Standalone make help succeeds without displaying product targets
    detail: |
      Makefile:16 depends on WF_HELP_TARGETS supplied by the absent maintainer overlay. Reproduced with make --no-print-directory WF_WORKFLOW= help, which returns no output. Connect help-parley in Makefile.local and verify help with the overlay absent.
```

---

## Re-review — 2026-09-13T13:23:25-07:00 (SHIP)

| field | value |
|-------|-------|
| issue | 208 — parley must install and load from a fresh clone |
| repo | parley.nvim |
| issue file | workshop/issues/000208-fresh-clone-installability.md |
| boundary | whole-issue close |
| milestone | — |
| window | 97155eca3ffc92e6e4ba47a7157d8f16048571ba..d26b0f7ba6faefbd05bf064ad1a4b9a37d349d6d |
| command | sdlc close --issue 208 |
| reviewer | codex |
| timestamp | 2026-09-13T13:23:25-07:00 |
| verdict | SHIP |

## Review

```verdict
verdict: SHIP
confidence: high
```

The pinned range delivers standalone installability and safely degrades issue features when vocabulary is unavailable. Both prior findings are addressed. Independent archive verification passed all four startup variants, 232 spec files, and lint across 401 files with zero warnings/errors. No blocking defects found.

```findings
dispose:
  - id: BR-1
    disposition: addressed
    note: |
      README.md:24–31 now documents the PLENARY override, help, archive acceptance, and standalone TOOLING.md instructions. The documented commands match the Makefile targets.
  - id: BR-2
    disposition: addressed
    note: |
      Makefile.local:7 supplies help-parley independently of the overlay. In isolated scratch, portable_make_spec.lua passes 3/3; removing that prerequisite makes the help regression fail while the other two tests pass.
findings:
  - id: new
    severity: Minor
    family: plan-table-structure
    title: |
      A test-strategy row is misplaced in the core-concepts table
    detail: |
      workshop/plans/000208-fresh-clone-installability-plan.md:35 puts materialize test inputs and assertions into the location/status columns. Move this duplicate strategy row into Function-level test strategies; the preceding entity row correctly identifies its implementation and classification.
```

1. **Strengths**
   - Vocabulary loading validates structure, bounds reads, and caches explicit ready/unavailable outcomes.
   - Unavailable-data tests exercise actual commands and finder handlers, including unchanged file and buffer assertions.
   - Shell-route tests use a filesystem-backed fake across executable, function, and alias routes, checking literal argument handling.
   - Archive acceptance independently verifies startup, chat creation, contributor tests, and absence of escaping links.

2. **Critical findings:** None.

3. **Important findings:** None.

4. **Minor findings:** The misplaced plan-table row described above.

5. **Test coverage**
   - Pinned full archive: four startup variants and 232 spec files passed.
   - Lint: zero warnings/errors in 401 files.
   - Real vocabulary comparison, read-only sdlc conformance, standalone help, and diff whitespace checks passed.
   - BR-2 was independently mutation-tested; BR-1 was verified against its concrete documentation and command referents.
   - Hosted CI provisioning was inspected, but not rerun as a hosted job.

6. **Architecture**
   - **ARCH-DRY — pass:** Shared vocabulary/default helpers; generated data has an executable drift gate.
   - **ARCH-PURE — pass:** Model derivation uses direct data tests; filesystem/cache consumers are classified as integration.
   - **ARCH-PURPOSE — pass:** Independent archive tests substantiate the installation and contributor goals.
   - **ARCH-MOCK — pass:** Command/export tests share production boundaries with portable fakes and explicit conformance checks.
   - **ARCH-CONSTRAINTS — pass:** Bounded vocabulary reads and cached failures avoid repeated runtime probing.
   - **ARCH-SECURE — pass:** Malformed data degrades visibly; shell arguments remain quoted; acceptance isolates profile state.
   - **ARCH-ORDER — pass:** Cache transitions and explicit recovery are exercised.
   - **ARCH-FUNERAL — pass:** Scratch has cleanup ownership; shipped vocabulary replaces one bounded artifact.

7. **Plan revision recommendation:** Append a `## Revisions` entry recording relocation of the misplaced `materialize` strategy row.
