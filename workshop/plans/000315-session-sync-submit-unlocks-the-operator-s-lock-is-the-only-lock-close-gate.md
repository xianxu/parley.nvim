---
gate: boundary-review
issue: 315
id_prefix: BR
rounds:
    - "n": 1
      timestamp: "2026-10-11T09:40:44-07:00"
      dispatched: "2026-10-11T09:38:24-07:00"
      agent: claude
      findings:
        - id: BR-1
          severity: Minor
          title: Ping's "reply may have landed" guard (s.owed ~= since) can never be true
          detail: session_sync.lua:370-371. Only this same probe callback writes s.owed, and s.probing blocks a concurrent probe, so the check is always false. The old code re-read the lock there. Either drop the clause and its comment, or re-query status before pinging. This is the only instance in the window.
          family: dead-guard-after-model-change
          round: 1
        - id: BR-2
          severity: Minor
          title: The forced re-probe after a submit or reload can be dropped or skipped, so the band can lag up to 60 s
          detail: 'All instances: reload() at :265-271 and the submit success callback at :592-595 both return early when s.probing is set (a probe in flight), and a FileChangedShell reload (fcs_choice "reload", on focus or :checktime) forces no probe at all. Use a reprobe flag that the in-flight callback acts on, and call the forced probe from FileChangedShellPost, or reword the Plan/atlas claim.'
          family: forced-probe-not-guaranteed
          round: 1
        - id: BR-3
          severity: Minor
          title: The oldest-owed calculation is inline in the couch callback; could be a pure M.oldest_owed(status)
          detail: session_sync.lua:347-352 (ARCH-PURE). Pulling it out would let the unit tests cover null and garbage Owed entries without the fake couch. This is the only such site.
          family: pure-logic-in-io-callback
          round: 1
      recipe: small-diff-review
      isolation: checkout
      reviewed: c260fa2e658b3a087a865568104fa3c620833b7f
      blocked: false
---

# Gate ledger — parley.nvim#315 (boundary-review)

Findings this gate raised, the stable ids the binary assigned them, and how
later rounds disposed of them. Generated — edit the gate, not this file.

## Round 1 — 2026-10-11T09:40:44-07:00 (claude) — passed

### Raised

- **BR-1** [Minor] `dead-guard-after-model-change` Ping's "reply may have landed" guard (s.owed ~= since) can never be true
  session_sync.lua:370-371. Only this same probe callback writes s.owed, and s.probing blocks a concurrent probe, so the check is always false. The old code re-read the lock there. Either drop the clause and its comment, or re-query status before pinging. This is the only instance in the window.
- **BR-2** [Minor] `forced-probe-not-guaranteed` The forced re-probe after a submit or reload can be dropped or skipped, so the band can lag up to 60 s
  All instances: reload() at :265-271 and the submit success callback at :592-595 both return early when s.probing is set (a probe in flight), and a FileChangedShell reload (fcs_choice "reload", on focus or :checktime) forces no probe at all. Use a reprobe flag that the in-flight callback acts on, and call the forced probe from FileChangedShellPost, or reword the Plan/atlas claim.
- **BR-3** [Minor] `pure-logic-in-io-callback` The oldest-owed calculation is inline in the couch callback; could be a pure M.oldest_owed(status)
  session_sync.lua:347-352 (ARCH-PURE). Pulling it out would let the unit tests cover null and garbage Owed entries without the fake couch. This is the only such site.

## Open findings

- **BR-1** [Minor] `dead-guard-after-model-change` Ping's "reply may have landed" guard (s.owed ~= since) can never be true
- **BR-2** [Minor] `forced-probe-not-guaranteed` The forced re-probe after a submit or reload can be dropped or skipped, so the band can lag up to 60 s
- **BR-3** [Minor] `pure-logic-in-io-callback` The oldest-owed calculation is inline in the couch callback; could be a pure M.oldest_owed(status)
