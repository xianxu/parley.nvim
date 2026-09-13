---
gate: plan-quality
issue: 244
id_prefix: PQ
rounds:
    - "n": 1
      timestamp: "2026-09-13T11:48:26-07:00"
      agent: codex
      findings:
        - id: PQ-1
          severity: Important
          title: Compress the implementation transcript into contracts and test strategies.
          detail: Tasks 1–8 prescribe implementation bodies, extensive test bodies, repeated run/commit instructions, and line-numbered edit inventories, contrary to this gate's explicit plan-format requirement. Preserve decisions, file/function ownership and acceptance criteria; replace the transcript with one adversarial-input and mechanical-guard strategy per risky function, including dimensions, argv_for, classify and run.
          family: plan-strategy-over-diff
          round: 1
        - id: PQ-2
          severity: Important
          title: Bound decoder workload independently of compressed input bytes.
          detail: 'ARCH-CONSTRAINTS and ARCH-SECURE: the 10 MB source cap permits highly compressed images with enormous dimensions; assets.lua:220–243 permits PNG dimensions up to 0x7FFFFFFF. Define a dimension/pixel admission bound and kept-original behavior before spawning, and account for subprocess memory and output-file growth: reading only #bytes after execution bounds neither resource. Name adversarial compressed-input coverage for decide/run and the guard it verifies.'
          family: decoded-resource-envelope
          round: 1
        - id: PQ-3
          severity: Important
          title: Validate the requested dimension cap before accepting transformed bytes.
          detail: 'ARCH-PURPOSE: classify currently accepts any smaller valid JPEG without checking its dimensions, so an ineffective recipe or shrink_cmd can produce an oversized image that is reported as successfully shrunk. Pass the requested edge into classification, require output dimensions to satisfy it, and keep the original with a named diagnostic on violation; exercise this with structurally valid output that violates the requested cap.'
          family: enforce-transformation-postconditions
          round: 1
        - id: PQ-4
          severity: Minor
          title: Reconcile embedded max tokens with configured-command validation.
          detail: The configuration documentation allows {max} inside an argument, but SELECT_WORDS requires it as a whole argument through argv_recipe.select. Consequently a configured ImageMagick-style resize argument is rejected; state one consistent grammar and test configured recipes against it.
          family: configuration-contract-consistency
          round: 1
      blocked: true
    - "n": 2
      timestamp: "2026-09-13T11:51:05-07:00"
      agent: codex
      dispose:
        - id: PQ-1
          disposition: addressed
          note: The canonical plan replaces the implementation transcript with contracts, file/function ownership, and focused adversarial strategies for dimensions, argv_for, classify, and run.
          round: 2
        - id: PQ-2
          disposition: addressed
          note: Pre-spawn admission caps dimensions at 16384 and pixels at 32 million with diagnostic fallback; file growth and timeout are enforced, memory assumptions are explicit, and compressed-input/resource-limit tests are named.
          round: 2
        - id: PQ-3
          disposition: addressed
          note: classify receives requested_edge and rejects structurally valid JPEG output exceeding it with a tool-named diagnostic; the strategy explicitly tests this violation.
          round: 2
        - id: PQ-4
          disposition: addressed
          note: One shared grammar permits embedded numeric max tokens while requiring whole-argument path tokens, including configured-command validation and substitution.
          round: 2
      blocked: false
content_hash: fe97d4ea191587fb58201a4d9ebb2f262130ceeafc713aa7002647b60f617e8f
---

# Gate ledger — parley.nvim#244 (plan-quality)

Findings this gate raised, the stable ids the binary assigned them, and how
later rounds disposed of them. Generated — edit the gate, not this file.

## Round 1 — 2026-09-13T11:48:26-07:00 (codex) — BLOCKED

### Raised

- **PQ-1** [Important] `plan-strategy-over-diff` Compress the implementation transcript into contracts and test strategies.
  Tasks 1–8 prescribe implementation bodies, extensive test bodies, repeated run/commit instructions, and line-numbered edit inventories, contrary to this gate's explicit plan-format requirement. Preserve decisions, file/function ownership and acceptance criteria; replace the transcript with one adversarial-input and mechanical-guard strategy per risky function, including dimensions, argv_for, classify and run.
- **PQ-2** [Important] `decoded-resource-envelope` Bound decoder workload independently of compressed input bytes.
  ARCH-CONSTRAINTS and ARCH-SECURE: the 10 MB source cap permits highly compressed images with enormous dimensions; assets.lua:220–243 permits PNG dimensions up to 0x7FFFFFFF. Define a dimension/pixel admission bound and kept-original behavior before spawning, and account for subprocess memory and output-file growth: reading only #bytes after execution bounds neither resource. Name adversarial compressed-input coverage for decide/run and the guard it verifies.
- **PQ-3** [Important] `enforce-transformation-postconditions` Validate the requested dimension cap before accepting transformed bytes.
  ARCH-PURPOSE: classify currently accepts any smaller valid JPEG without checking its dimensions, so an ineffective recipe or shrink_cmd can produce an oversized image that is reported as successfully shrunk. Pass the requested edge into classification, require output dimensions to satisfy it, and keep the original with a named diagnostic on violation; exercise this with structurally valid output that violates the requested cap.
- **PQ-4** [Minor] `configuration-contract-consistency` Reconcile embedded max tokens with configured-command validation.
  The configuration documentation allows {max} inside an argument, but SELECT_WORDS requires it as a whole argument through argv_recipe.select. Consequently a configured ImageMagick-style resize argument is rejected; state one consistent grammar and test configured recipes against it.

## Round 2 — 2026-09-13T11:51:05-07:00 (codex) — passed

### Disposed

- PQ-1 — addressed — The canonical plan replaces the implementation transcript with contracts, file/function ownership, and focused adversarial strategies for dimensions, argv_for, classify, and run.
- PQ-2 — addressed — Pre-spawn admission caps dimensions at 16384 and pixels at 32 million with diagnostic fallback; file growth and timeout are enforced, memory assumptions are explicit, and compressed-input/resource-limit tests are named.
- PQ-3 — addressed — classify receives requested_edge and rejects structurally valid JPEG output exceeding it with a tool-named diagnostic; the strategy explicitly tests this violation.
- PQ-4 — addressed — One shared grammar permits embedded numeric max tokens while requiring whole-argument path tokens, including configured-command validation and substitution.

## Open findings

(none — every finding has been disposed)
