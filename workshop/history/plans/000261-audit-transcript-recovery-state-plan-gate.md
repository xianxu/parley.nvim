---
gate: plan-quality
issue: 261
id_prefix: PQ
rounds:
    - "n": 1
      timestamp: "2026-09-18T23:23:13-07:00"
      agent: claude
      findings:
        - id: PQ-1
          severity: Minor
          title: W13 claims its query's full output but lists 5 of the 10 Deferred owners
          detail: |-
            The stated query returns document/init.lua:67, diagnostic_refresh.lua:216,
            tool_folds.lua:468 and outline.lua:289 besides the five named; say why they
            are out of scope rather than asserting the list is the query. Same table:
            W16 cites response_topic.lua:142, but the throwing provider.request is at
            :80 (called from :154) with s.started set at :59.
          family: enumeration-claims-completeness
          round: 1
        - id: PQ-2
          severity: Minor
          title: Task 3.3's refusal of deadline-less unscoped runs reddens 43 untouched test call sites
          detail: |-
            tests/integration/tasker_run_spec.lua calls tasker.run 43 times with no opts
            table, so every one is unscoped with no deadline_ms. M3's file lists name
            only tasker_supervision_spec and tasker_unit_spec.
          family: seam-change-collateral
          round: 1
        - id: PQ-3
          severity: Minor
          title: The legacy answer-recovery directory loses its last mention along with its last reader
          detail: |-
            M1 deletes every reader and removes the README sentence, leaving up to
            256 MiB of answer snapshots on disk that nothing names. One line in
            atlas/chat/transcript_truth.md naming the path and saying it is safe to
            delete satisfies ARCH-FUNERAL without reopening the no-migration decision.
          family: residue-names-no-end
          round: 1
        - id: PQ-4
          severity: Minor
          title: Full implementation bodies and per-case test enumerations pre-image code that lands within the hour
          detail: |-
            Tasks 1.4, 2.2, 2.3 and 2.6 embed the implementation verbatim, and most
            tasks enumerate test cases in prose. The function names, the one-line
            strategy per risky function, the counterfactuals and the census specs are
            the durable part. The removal tables are exempt: each carries its
            re-run query and a correct-the-table-first instruction.
          family: plan-restates-the-diff
          round: 1
      blocked: false
content_hash: 63750a49fae3ccefe83771a79e508b953c3159a1ac25be2f4ac8c05dd98b032f
---

# Gate ledger — parley.nvim#261 (plan-quality)

Findings this gate raised, the stable ids the binary assigned them, and how
later rounds disposed of them. Generated — edit the gate, not this file.

## Round 1 — 2026-09-18T23:23:13-07:00 (claude) — passed

### Raised

- **PQ-1** [Minor] `enumeration-claims-completeness` W13 claims its query's full output but lists 5 of the 10 Deferred owners
  The stated query returns document/init.lua:67, diagnostic_refresh.lua:216,
  tool_folds.lua:468 and outline.lua:289 besides the five named; say why they
  are out of scope rather than asserting the list is the query. Same table:
  W16 cites response_topic.lua:142, but the throwing provider.request is at
  :80 (called from :154) with s.started set at :59.
- **PQ-2** [Minor] `seam-change-collateral` Task 3.3's refusal of deadline-less unscoped runs reddens 43 untouched test call sites
  tests/integration/tasker_run_spec.lua calls tasker.run 43 times with no opts
  table, so every one is unscoped with no deadline_ms. M3's file lists name
  only tasker_supervision_spec and tasker_unit_spec.
- **PQ-3** [Minor] `residue-names-no-end` The legacy answer-recovery directory loses its last mention along with its last reader
  M1 deletes every reader and removes the README sentence, leaving up to
  256 MiB of answer snapshots on disk that nothing names. One line in
  atlas/chat/transcript_truth.md naming the path and saying it is safe to
  delete satisfies ARCH-FUNERAL without reopening the no-migration decision.
- **PQ-4** [Minor] `plan-restates-the-diff` Full implementation bodies and per-case test enumerations pre-image code that lands within the hour
  Tasks 1.4, 2.2, 2.3 and 2.6 embed the implementation verbatim, and most
  tasks enumerate test cases in prose. The function names, the one-line
  strategy per risky function, the counterfactuals and the census specs are
  the durable part. The removal tables are exempt: each carries its
  re-run query and a correct-the-table-first instruction.

## Open findings

- **PQ-1** [Minor] `enumeration-claims-completeness` W13 claims its query's full output but lists 5 of the 10 Deferred owners
- **PQ-2** [Minor] `seam-change-collateral` Task 3.3's refusal of deadline-less unscoped runs reddens 43 untouched test call sites
- **PQ-3** [Minor] `residue-names-no-end` The legacy answer-recovery directory loses its last mention along with its last reader
- **PQ-4** [Minor] `plan-restates-the-diff` Full implementation bodies and per-case test enumerations pre-image code that lands within the hour
