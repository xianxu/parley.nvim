---
gate: boundary-review
issue: 255
id_prefix: BR
rounds:
    - "n": 1
      timestamp: "2026-09-26T19:49:37-07:00"
      agent: codex
      findings:
        - id: BR-1
          severity: Critical
          title: Duplicate submission erases a streaming answer before ownership admission
          detail: 'lua/parley/chat_respond.lua:1512–1515 replaces the previous-answer slot and deletes output before admission. A deterministic scratch test fails on HEAD after partial output, but passes with the BASE chat_respond.lua: the duplicate must preserve the active writer and its text. Route mutation through admitted ownership and cover duplicate submissions before and after output (ARCH-ORDER, ARCH-PURPOSE).'
          family: mutation-before-admission
          round: 1
        - id: BR-2
          severity: Important
          title: README and atlas describe the superseded refresh lifecycle
          detail: README.md:74–75 promises old-answer visibility until replacement output, whereas chat_respond.lua:1515 deletes it immediately. atlas/chat/transcript_truth.md:59 omits pending previous-answer ownership before generation admission. Update both passages to match the corrected lifecycle.
          family: lifecycle-documentation-drift
          round: 1
      recipe: milestone-review
      blocked: true
---

# Gate ledger — parley.nvim#255 (boundary-review)

Findings this gate raised, the stable ids the binary assigned them, and how
later rounds disposed of them. Generated — edit the gate, not this file.

## Round 1 — 2026-09-26T19:49:37-07:00 (codex) — BLOCKED

### Raised

- **BR-1** [Critical] `mutation-before-admission` Duplicate submission erases a streaming answer before ownership admission
  lua/parley/chat_respond.lua:1512–1515 replaces the previous-answer slot and deletes output before admission. A deterministic scratch test fails on HEAD after partial output, but passes with the BASE chat_respond.lua: the duplicate must preserve the active writer and its text. Route mutation through admitted ownership and cover duplicate submissions before and after output (ARCH-ORDER, ARCH-PURPOSE).
- **BR-2** [Important] `lifecycle-documentation-drift` README and atlas describe the superseded refresh lifecycle
  README.md:74–75 promises old-answer visibility until replacement output, whereas chat_respond.lua:1515 deletes it immediately. atlas/chat/transcript_truth.md:59 omits pending previous-answer ownership before generation admission. Update both passages to match the corrected lifecycle.

## Open findings

- **BR-1** [Critical] `mutation-before-admission` Duplicate submission erases a streaming answer before ownership admission
- **BR-2** [Important] `lifecycle-documentation-drift` README and atlas describe the superseded refresh lifecycle
