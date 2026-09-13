---
gate: boundary-review
issue: 244
id_prefix: BR
rounds:
    - "n": 1
      timestamp: "2026-09-13T12:08:56-07:00"
      agent: codex
      findings:
        - id: BR-1
          severity: Important
          title: Preserve output completeness when classifying non-smaller conversions.
          detail: lua/parley/image_shrink.lua:157 truncates output at the input size before JPEG validation, misreporting valid larger output as invalid instead of silently retaining the original. Reproduced through the configured fake and real sips; preserve size/completeness information and add runner-level coverage, including metadata stripping (ARCH-PURPOSE).
          family: bounded-read-outcome-fidelity
          round: 1
        - id: BR-2
          severity: Important
          title: Surface failed temporary-file removal.
          detail: lua/parley/image_shrink.lua:159-160 discards both exceptions and unsuccessful removal returns. Injected permission-denied removal leaves both files while run returns success; attempt all cleanup, distinguish missing files, and report genuine failures with regression coverage (ARCH-FUNERAL).
          family: cleanup-failure-observability
          round: 1
        - id: BR-3
          severity: Important
          title: Provide independent dimension probes on non-sips hosts.
          detail: tests/integration/image_shrink_live_spec.lua:31 gates every independent dimension probe on sips availability. Other supported platforms consequently rely only on Parley's parser; add recipe-appropriate real-tool probes and exercise the no-sips path to fulfill the Spec (ARCH-MOCK).
          family: independent-conformance-oracle
          round: 1
      blocked: true
    - "n": 2
      timestamp: "2026-09-13T12:18:28-07:00"
      agent: codex
      dispose:
        - id: BR-1
          disposition: addressed
          note: Complete bounded output survives through metadata stripping and classification; restoring input-sized reads causes four test failures, including both configured-fixture regressions.
          round: 2
        - id: BR-2
          disposition: addressed
          note: Both removals are attempted, ENOENT is distinguished, and genuine failures retain process context; disabling cleanup reporting causes five regression failures.
          round: 2
        - id: BR-3
          disposition: addressed
          note: Live conformance invokes recipe-specific independent probes without a sips availability guard; forcing sips dispatch causes all four non-sips probe cases to fail.
          round: 2
      blocked: false
---

# Gate ledger — parley.nvim#244 (boundary-review)

Findings this gate raised, the stable ids the binary assigned them, and how
later rounds disposed of them. Generated — edit the gate, not this file.

## Round 1 — 2026-09-13T12:08:56-07:00 (codex) — BLOCKED

### Raised

- **BR-1** [Important] `bounded-read-outcome-fidelity` Preserve output completeness when classifying non-smaller conversions.
  lua/parley/image_shrink.lua:157 truncates output at the input size before JPEG validation, misreporting valid larger output as invalid instead of silently retaining the original. Reproduced through the configured fake and real sips; preserve size/completeness information and add runner-level coverage, including metadata stripping (ARCH-PURPOSE).
- **BR-2** [Important] `cleanup-failure-observability` Surface failed temporary-file removal.
  lua/parley/image_shrink.lua:159-160 discards both exceptions and unsuccessful removal returns. Injected permission-denied removal leaves both files while run returns success; attempt all cleanup, distinguish missing files, and report genuine failures with regression coverage (ARCH-FUNERAL).
- **BR-3** [Important] `independent-conformance-oracle` Provide independent dimension probes on non-sips hosts.
  tests/integration/image_shrink_live_spec.lua:31 gates every independent dimension probe on sips availability. Other supported platforms consequently rely only on Parley's parser; add recipe-appropriate real-tool probes and exercise the no-sips path to fulfill the Spec (ARCH-MOCK).

## Round 2 — 2026-09-13T12:18:28-07:00 (codex) — passed

### Disposed

- BR-1 — addressed — Complete bounded output survives through metadata stripping and classification; restoring input-sized reads causes four test failures, including both configured-fixture regressions.
- BR-2 — addressed — Both removals are attempted, ENOENT is distinguished, and genuine failures retain process context; disabling cleanup reporting causes five regression failures.
- BR-3 — addressed — Live conformance invokes recipe-specific independent probes without a sips availability guard; forcing sips dispatch causes all four non-sips probe cases to fail.

## Open findings

(none — every finding has been disposed)
