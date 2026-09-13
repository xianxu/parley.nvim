# Boundary Review — parley.nvim#244 (whole-issue close)

| field | value |
|-------|-------|
| issue | 244 — Shrink pasted and generated images before saving: sips first, probe other tools, keep the original when none |
| repo | parley.nvim |
| issue file | workshop/issues/000244-shrink-images-on-save.md |
| boundary | whole-issue close |
| milestone | — |
| window | 132d90a8618df2bcc4a04eb78514e3896cf1dea7..0b5eb07d016e5ba7ddf745f19b2a489a372e91eb |
| command | sdlc close --issue 244 |
| reviewer | codex |
| timestamp | 2026-09-13T12:08:56-07:00 |
| verdict | REWORK |

## Review

```verdict
verdict: REWORK
confidence: high
```

The shared-writer integration, pure policy, documentation, and normal sips behavior are sound. Three Important gaps remain: larger valid output is misdiagnosed after truncation, cleanup failures disappear, and non-sips hosts lack the promised independent dimension probe. No repository files were changed.

1. **Strengths**

   - Shared argv substitution preserves token-containing paths without shell interpolation.
   - Source-size and decoded-dimension admission precede conversion; tests exercise real timeout and file-size enforcement.
   - Metadata removal reuses the JPEG walker and covers progressive scans, escaped bytes, and restart markers.
   - README and atlas document configuration, transparency loss, limits, and asset ownership.

2. **Critical findings**

   None.

3. **Important findings**

   - **Larger valid output becomes a false converter failure** — [image_shrink.lua:157](/Users/xianxu/workspace/parley.nvim/lua/parley/image_shrink.lua:157). Reading only `#bytes` truncates a larger JPEG before validation. Reproduced with a real 281-byte, 1800×4 PNG: sips exits successfully, but shrinking reports “wrote something that is not a JPEG.” The approved contract requires silent retention for non-smaller output. Preserve output-size/completeness information and test this through the runner, including metadata-heavy output that becomes smaller after stripping. **ARCH-PURPOSE**.

   - **Cleanup failures are silently discarded** — [image_shrink.lua:159](/Users/xianxu/workspace/parley.nvim/lua/parley/image_shrink.lua:159). Both thrown removal errors and `nil, error` returns disappear. Injecting permission-denied removal returned code `0`, empty stderr, and left both files behind. Attempt both removals, distinguish absent files from failed deletion, and surface cleanup failures. Add fault-injection coverage for both error forms. **ARCH-FUNERAL**.

   - **Independent output probes require sips on every platform** — [image_shrink_live_spec.lua:31](/Users/xianxu/workspace/parley.nvim/tests/integration/image_shrink_live_spec.lua:31). On a Linux host with ImageMagick, ffmpeg, or libvips, conformance checks dimensions only through Parley’s parser. The Spec promises a real-tool dimension probe. Add an appropriate probe for each supported recipe and exercise the no-sips branch. **ARCH-MOCK**.

4. **Minor findings**

   None.

5. **Test coverage notes**

   - Attachment-mapped tests passed.
   - Golden normalization: 7 tests passed; golden round trips: 11 passed.
   - Lint: zero warnings/errors across 391 files; diff whitespace check passed.
   - Live sips conversion and metadata checks passed. Other converters were unavailable and skipped.
   - The non-smaller test calls `classify` with complete bytes, bypassing the truncating runner. Cleanup tests omit removal failures.
   - Full repository suite was not rerun.

6. **Architectural notes**

   - **ARCH-DRY — pass:** shared argv grammar and JPEG traversal.
   - **ARCH-PURE — pass:** policy and parsing remain deterministic; IO uses explicit dependencies. Core-concept locations match.
   - **ARCH-PURPOSE — flag:** non-smaller fallback violates its documented outcome.
   - **ARCH-MOCK — flag:** cross-platform independent conformance probes are incomplete.
   - **ARCH-CONSTRAINTS — pass:** admission, timeout, and file-growth limits are exercised.
   - **ARCH-SECURE — pass:** structural validation and argv separation protect the introduced boundaries.
   - **ARCH-ORDER — pass:** explicit resolution states and reset behavior; synchronous conversion bounds sequencing.
   - **ARCH-FUNERAL — flag:** cleanup is attempted but failure is invisible.

7. **Plan revision recommendations**

   Append a `## Revisions` entry specifying complete-versus-truncated output handling, visible cleanup-failure behavior, and independent probes for non-sips recipes. Extend the runner test strategy to cover these paths.

```findings
findings:
  - id: new
    severity: Important
    family: bounded-read-outcome-fidelity
    title: |
      Preserve output completeness when classifying non-smaller conversions.
    detail: |
      lua/parley/image_shrink.lua:157 truncates output at the input size before JPEG validation, misreporting valid larger output as invalid instead of silently retaining the original. Reproduced through the configured fake and real sips; preserve size/completeness information and add runner-level coverage, including metadata stripping (ARCH-PURPOSE).
  - id: new
    severity: Important
    family: cleanup-failure-observability
    title: |
      Surface failed temporary-file removal.
    detail: |
      lua/parley/image_shrink.lua:159-160 discards both exceptions and unsuccessful removal returns. Injected permission-denied removal leaves both files while run returns success; attempt all cleanup, distinguish missing files, and report genuine failures with regression coverage (ARCH-FUNERAL).
  - id: new
    severity: Important
    family: independent-conformance-oracle
    title: |
      Provide independent dimension probes on non-sips hosts.
    detail: |
      tests/integration/image_shrink_live_spec.lua:31 gates every independent dimension probe on sips availability. Other supported platforms consequently rely only on Parley's parser; add recipe-appropriate real-tool probes and exercise the no-sips path to fulfill the Spec (ARCH-MOCK).
```

---

## Re-review — 2026-09-13T12:18:28-07:00 (SHIP)

| field | value |
|-------|-------|
| issue | 244 — Shrink pasted and generated images before saving: sips first, probe other tools, keep the original when none |
| repo | parley.nvim |
| issue file | workshop/issues/000244-shrink-images-on-save.md |
| boundary | whole-issue close |
| milestone | — |
| window | 132d90a8618df2bcc4a04eb78514e3896cf1dea7..f5f1248aee6ba2008c920ce9b7ef1cc84b37f4a6 |
| command | sdlc close --issue 244 |
| reviewer | codex |
| timestamp | 2026-09-13T12:18:28-07:00 |
| verdict | SHIP |

## Review

```verdict
verdict: SHIP
confidence: high
```

The pinned range satisfies the issue’s approved Spec and revised Plan. All three prior findings are addressed, with regression tests that fail when their protections are removed. No new findings. Repository files remain unchanged.

```findings
dispose:
  - id: BR-1
    disposition: addressed
    note: |
      Complete bounded output survives through metadata stripping and classification; restoring input-sized reads causes four test failures, including both configured-fixture regressions.
  - id: BR-2
    disposition: addressed
    note: |
      Both removals are attempted, ENOENT is distinguished, and genuine failures retain process context; disabling cleanup reporting causes five regression failures.
  - id: BR-3
    disposition: addressed
    note: |
      Live conformance invokes recipe-specific independent probes without a sips availability guard; forcing sips dispatch causes all four non-sips probe cases to fail.
```

1. **Strengths**
   - Shared argv grammar preserves path boundaries and avoids rescanning substituted paths.
   - `assets.save` owns conversion, extension selection, and outcome reporting.
   - Output acceptance checks format, dimensions, metadata removal, and actual byte reduction.
   - README, atlas, traceability, and plan revisions cover the new behavior.

2. **Critical findings:** None.

3. **Important findings:** None.

4. **Minor findings:** None.

5. **Test coverage**
   - Attachment suite passed.
   - Golden normalization: 7 tests passed; golden round trips: 11 passed.
   - Lint: zero warnings/errors across 393 files.
   - Live sips conversion, independent dimensions, no-upscale behavior, and metadata removal passed.
   - Other converters were unavailable; their live cases remain pending.
   - Scratch-only mutation checks confirmed the prior regressions turn red.

6. **Architecture**
   - **ARCH-DRY — pass:** shared argv grammar and JPEG walker.
   - **ARCH-PURE — pass:** policy and parsing remain pure; IO dependencies are injected.
   - **ARCH-PURPOSE — pass:** shared writer delivers the approved transformation contract.
   - **ARCH-MOCK — pass:** filesystem-backed converter fixture shares the production seam; independent live probes exist.
   - **ARCH-CONSTRAINTS — pass:** admission, timeout, output growth, and bounded reads are enforced and tested.
   - **ARCH-SECURE — pass:** paths remain argv data; external output is validated.
   - **ARCH-ORDER — pass:** explicit resolution states and synchronous conversion keep ordering bounded.
   - **ARCH-FUNERAL — pass:** both temporary paths receive cleanup attempts; failures are observable.

7. **Plan revision recommendations:** None; existing revisions capture the repairs.
