---
gate: plan-quality
issue: 227
id_prefix: PQ
rounds:
    - "n": 1
      timestamp: "2026-09-10T17:05:37-07:00"
      agent: claude
      findings:
        - id: PQ-1
          severity: Minor
          title: highlighting_spec.lua keeps production 250ms timers while the same file pumps the loop
          detail: |-
            Task 4 injects the repair deferral only into the new highlight_typing_spec.lua.
            The structural-edit tests in highlighting_spec.lua (around lines 572, 626, 729,
            745-773, 852) will arm real vim.uv timers, and that file waits on the event loop
            for 700ms at line 1198 (also 1173, 1236) — long enough for a stray repair to
            rebuild a prior test's buffer and fire nvim__redraw mid-test. Install the manual
            deferral in a top-level before_each/after_each there too, or expose the swap from
            tests/helpers/decoration.lua so both specs construct the ordering instead of
            sampling it.
          family: injected-clock-in-tests
          round: 1
        - id: PQ-2
          severity: Minor
          title: traceability lists highlighting_spec.lua at two sites, Task 6 names one
          detail: |-
            atlas/traceability.yaml references tests/integration/highlighting_spec.lua at both
            line 52 and line 624 (two different atlas entries). Task 6 Step 4 says to add the
            new spec "beside" it in the singular, so an implementer will likely update one and
            leave the other's coverage list incomplete. Decide which entries own the new spec
            and name both.
          family: class-not-instance
          round: 1
        - id: PQ-3
          severity: Minor
          title: two init.lua pointers in the issue's diagnosis are off by 5-7 lines
          detail: |-
            The Problem section cites init.lua:1707 for the chat buffer being
            filetype=markdown (the actual site is the prep_chat block near :1714) and
            init.lua:2865 as the highlight_question_block path (the wrapper is at :2872-2873).
            Both behavioral claims are correct; only the line numbers drifted, and a later
            reader following them lands on ExportMarkdown and on the _parley_bufs declaration.
          family: stale-file-line-pointer
          round: 1
      blocked: false
content_hash: 044101a1a95ad1bcf854367b1d640c5615e913c0050c6eb138e5a79c3f11c8c2
---

# Gate ledger — parley.nvim#227 (plan-quality)

Findings this gate raised, the stable ids the binary assigned them, and how
later rounds disposed of them. Generated — edit the gate, not this file.

## Round 1 — 2026-09-10T17:05:37-07:00 (claude) — passed

### Raised

- **PQ-1** [Minor] `injected-clock-in-tests` highlighting_spec.lua keeps production 250ms timers while the same file pumps the loop
  Task 4 injects the repair deferral only into the new highlight_typing_spec.lua.
  The structural-edit tests in highlighting_spec.lua (around lines 572, 626, 729,
  745-773, 852) will arm real vim.uv timers, and that file waits on the event loop
  for 700ms at line 1198 (also 1173, 1236) — long enough for a stray repair to
  rebuild a prior test's buffer and fire nvim__redraw mid-test. Install the manual
  deferral in a top-level before_each/after_each there too, or expose the swap from
  tests/helpers/decoration.lua so both specs construct the ordering instead of
  sampling it.
- **PQ-2** [Minor] `class-not-instance` traceability lists highlighting_spec.lua at two sites, Task 6 names one
  atlas/traceability.yaml references tests/integration/highlighting_spec.lua at both
  line 52 and line 624 (two different atlas entries). Task 6 Step 4 says to add the
  new spec "beside" it in the singular, so an implementer will likely update one and
  leave the other's coverage list incomplete. Decide which entries own the new spec
  and name both.
- **PQ-3** [Minor] `stale-file-line-pointer` two init.lua pointers in the issue's diagnosis are off by 5-7 lines
  The Problem section cites init.lua:1707 for the chat buffer being
  filetype=markdown (the actual site is the prep_chat block near :1714) and
  init.lua:2865 as the highlight_question_block path (the wrapper is at :2872-2873).
  Both behavioral claims are correct; only the line numbers drifted, and a later
  reader following them lands on ExportMarkdown and on the _parley_bufs declaration.

## Open findings

- **PQ-1** [Minor] `injected-clock-in-tests` highlighting_spec.lua keeps production 250ms timers while the same file pumps the loop
- **PQ-2** [Minor] `class-not-instance` traceability lists highlighting_spec.lua at two sites, Task 6 names one
- **PQ-3** [Minor] `stale-file-line-pointer` two init.lua pointers in the issue's diagnosis are off by 5-7 lines
