# Boundary Review — 000254-chat-ownership-concurrency#254 (whole-issue close)

| field | value |
|-------|-------|
| issue | 254 — Harden chat ownership and concurrency |
| repo | 000254-chat-ownership-concurrency |
| issue file | workshop/issues/000254-chat-ownership-concurrency.md |
| boundary | whole-issue close |
| milestone | — |
| window | c95231c73563ced097b95abce5ed938634519b96..ec59ce9bbed01a1521aec8e01ed310f8cbbf619d |
| command | sdlc close --issue 254 |
| reviewer | codex |
| timestamp | 2026-09-15T14:11:30-07:00 |
| verdict | SHIP |

## Review

```verdict
verdict: SHIP
confidence: medium
```

The pinned range satisfies the reviewed ownership, cancellation, recovery, and concurrency contracts. BR-13 and BR-32 are verified addressed; earlier dispositions remain unchanged. No new blocking findings emerged. The repository was left unchanged. The plan’s operator live-testing requirement before merge still applies.

## 1. Strengths

- Production execution consumes pure lifecycle permissions; rejection tests verify that adapters cannot bypass them.
- Controlled event sequences exercise cancellation, late completion, human edits, uncertainty, and recovery.
- All **108 added spec files** are registered in traceability. README and atlas cover the new commands, configuration, and architectural boundaries.
- BR-32’s regression passes at HEAD and fails with only the deadline clamp removed: `5000 ~= 5550`.

## 2. Critical findings

None.

## 3. Important findings

None remaining. BR-13’s mappings are present at `atlas/traceability.yaml:384–385`; both mapped regressions passed. Removing either entry from a scratch mapping fails the inclusion check.

## 4. Minor findings

None remaining. BR-32 is corrected at `lua/parley/tools/operation.lua:121`, with the full scheduled-sequence regression at `tests/unit/tool_operation_spec.lua:164`.

## 5. Test coverage notes

- **1,659 passing test executions** across document, ownership, batch, recovery, lifecycle, and tool-execution mappings; includes overlapping tests between mappings.
- `make lint`: **zero warnings/errors across 616 files**.
- Required pinned stat/name-status inspections completed.
- Full `make test` and standalone `make perf` were not rerun; mapped suites included native conformance and performance-contract tests.

## 6. Architectural notes

| Principle | Result | Evidence |
|---|---|---|
| ARCH-DRY | Pass | Shared grammar, document projection, and file transformations replace competing implementations. |
| ARCH-PURE | Pass | Lifecycle decisions reside in pure models; adapters consume their permissions. |
| ARCH-PURPOSE | Pass | Reviewed mutation and rendering consumers derive authority from the document coordinator. |
| ARCH-MOCK | Pass | Stateful editor/process/filesystem doubles share production seams; native conformance tests passed. |
| ARCH-CONSTRAINTS | Pass | Admission limits, bounded work, retained uncertainty, and deadline enforcement are exercised. |
| ARCH-SECURE | Pass | Path identity and recovery corruption checks reject unsupported authority. |
| ARCH-ORDER | Pass | Sequence and rejection tests cover reordered evidence, cancellation, and late completion. |
| ARCH-FUNERAL | Pass | Document retirement, retained-operation cleanup, and recovery quota/deletion paths are implemented. |

## 7. Plan revision recommendations

None. Existing revisions explain the delivered inventory and deadline correction.

```findings
dispose:
  - id: BR-1
    disposition: addressed
  - id: BR-2
    disposition: addressed
  - id: BR-3
    disposition: addressed
  - id: BR-4
    disposition: addressed
  - id: BR-5
    disposition: addressed
  - id: BR-6
    disposition: addressed
  - id: BR-7
    disposition: addressed
  - id: BR-8
    disposition: addressed
  - id: BR-9
    disposition: addressed
  - id: BR-10
    disposition: addressed
  - id: BR-11
    disposition: addressed
  - id: BR-12
    disposition: addressed
  - id: BR-13
    disposition: addressed
    note: |
      atlas/traceability.yaml:384–385 registers both fold-retirement regressions. The documented mapping includes both and both tests passed. Removing either entry from a scratch mapping fails the inclusion check; all 108 added specs are registered.
  - id: BR-14
    disposition: addressed
  - id: BR-15
    disposition: addressed
  - id: BR-16
    disposition: addressed
  - id: BR-17
    disposition: addressed
  - id: BR-18
    disposition: addressed
  - id: BR-19
    disposition: addressed
  - id: BR-20
    disposition: addressed
  - id: BR-21
    disposition: addressed
  - id: BR-22
    disposition: addressed
  - id: BR-23
    disposition: addressed
  - id: BR-24
    disposition: addressed
  - id: BR-25
    disposition: addressed
  - id: BR-26
    disposition: addressed
  - id: BR-27
    disposition: addressed
  - id: BR-28
    disposition: addressed
  - id: BR-29
    disposition: addressed
  - id: BR-30
    disposition: addressed
  - id: BR-31
    disposition: addressed
  - id: BR-32
    disposition: addressed
    note: |
      operation.lua:121 clamps the next tick to the deadline. The regression at tool_operation_spec.lua:164 follows every scheduled tick, reaches 5000 ms, and verifies retained ownership. It passes at HEAD and fails at 5550 ms when only the clamp is removed in memory. Production scheduler polling consumes this deadline.
```
