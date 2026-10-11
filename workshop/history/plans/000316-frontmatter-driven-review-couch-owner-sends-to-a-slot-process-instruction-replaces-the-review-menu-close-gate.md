---
gate: boundary-review
issue: 316
id_prefix: BR
rounds:
    - "n": 1
      timestamp: "2026-10-11T14:12:53-07:00"
      dispatched: "2026-10-11T14:10:27-07:00"
      agent: claude
      findings:
        - id: BR-1
          severity: Important
          title: review skill source() with multi-mode args.modes has no test; outside-pair spec stubs run_via_invoke
          detail: skills/review/init.lua:505-520 (mode_names, brief via instruction.brief, has_mode, journal mode concat) is reached only through the stubbed run_via_invoke. Add a review_mode_load_spec case with args.modes = two names, asserting both bodies plus the first mode's directives.
          family: consumer-path-untested-behind-stub
          round: 1
        - id: BR-2
          severity: Minor
          title: quoted process-instruction followed by an inline comment is misread as free-form
          detail: 'review_send.instruction_value unquotes fm.raw; for `"[x] y" # note` unquote fails and the leading quote hides [x]. Take the quoted span first when raw begins with a quote.'
          family: frontmatter-value-reading
          round: 1
        - id: BR-3
          severity: Minor
          title: diff since last send includes the agent's own in-place edits
          detail: The baseline is the operator's copy at send time; the agent replies by editing the file, so the next diff mixes both authors. Note it in the message, or reset the baseline on reload from disk.
          family: send-diff-semantics
          round: 1
        - id: BR-4
          severity: Minor
          title: completion inside an already-quoted value never closes the quote
          detail: 'requote returns nil when the value starts with a quote, so `process-instruction: "[` plus completion leaves an unclosed quote unless one already existed.'
          family: completion-quoting
          round: 1
        - id: BR-5
          severity: Minor
          title: fake couch has no live conformance check for Binding.Scope/Tag in --actors JSON
          detail: 'ARCH-MOCK: own-slot resolution depends on these fields; the fake is env-driven and nothing detects drift from real couch.'
          family: fake-conformance-check
          round: 1
      recipe: milestone-review
      isolation: fenced
      blocked: true
    - "n": 2
      timestamp: "2026-10-11T14:17:58-07:00"
      dispatched: "2026-10-11T14:15:32-07:00"
      agent: claude
      dispose:
        - id: BR-1
          disposition: addressed
          note: review_mode_load_spec drives the real source() with two modes; skill_invoke_review_spec covers has_mode and the journal name; the mutations go red.
          round: 2
        - id: BR-2
          disposition: addressed
          note: quoted_span is used by parse and instruction_value; the trailing-comment cases are pinned; reverting either site goes red.
          round: 2
        - id: BR-3
          disposition: addressed
          note: The message heading says the diff includes the agent's own edits (review_send.lua:103); asserted in review_send_spec.
          round: 2
        - id: BR-4
          disposition: addressed
          note: requote closes an opened, unclosed quote (review_send.lua:212-217); the new spec fails when this branch is reverted.
          round: 2
        - id: BR-5
          disposition: addressed
          note: couch_spec has a live conformance spec that resolves own_actor from the real couch --actors JSON; it is pending outside a pair slot.
          round: 2
      recipe: milestone-review
      isolation: fenced
      reviewed: 847acc93440d696637352c6eb85daee07404dee3
      blocked: false
---

# Gate ledger — parley.nvim#316 (boundary-review)

Findings this gate raised, the stable ids the binary assigned them, and how
later rounds disposed of them. Generated — edit the gate, not this file.

## Round 1 — 2026-10-11T14:12:53-07:00 (claude) — BLOCKED

### Raised

- **BR-1** [Important] `consumer-path-untested-behind-stub` review skill source() with multi-mode args.modes has no test; outside-pair spec stubs run_via_invoke
  skills/review/init.lua:505-520 (mode_names, brief via instruction.brief, has_mode, journal mode concat) is reached only through the stubbed run_via_invoke. Add a review_mode_load_spec case with args.modes = two names, asserting both bodies plus the first mode's directives.
- **BR-2** [Minor] `frontmatter-value-reading` quoted process-instruction followed by an inline comment is misread as free-form
  review_send.instruction_value unquotes fm.raw; for `"[x] y" # note` unquote fails and the leading quote hides [x]. Take the quoted span first when raw begins with a quote.
- **BR-3** [Minor] `send-diff-semantics` diff since last send includes the agent's own in-place edits
  The baseline is the operator's copy at send time; the agent replies by editing the file, so the next diff mixes both authors. Note it in the message, or reset the baseline on reload from disk.
- **BR-4** [Minor] `completion-quoting` completion inside an already-quoted value never closes the quote
  requote returns nil when the value starts with a quote, so `process-instruction: "[` plus completion leaves an unclosed quote unless one already existed.
- **BR-5** [Minor] `fake-conformance-check` fake couch has no live conformance check for Binding.Scope/Tag in --actors JSON
  ARCH-MOCK: own-slot resolution depends on these fields; the fake is env-driven and nothing detects drift from real couch.

## Round 2 — 2026-10-11T14:17:58-07:00 (claude) — passed

### Disposed

- BR-1 — addressed — review_mode_load_spec drives the real source() with two modes; skill_invoke_review_spec covers has_mode and the journal name; the mutations go red.
- BR-2 — addressed — quoted_span is used by parse and instruction_value; the trailing-comment cases are pinned; reverting either site goes red.
- BR-3 — addressed — The message heading says the diff includes the agent's own edits (review_send.lua:103); asserted in review_send_spec.
- BR-4 — addressed — requote closes an opened, unclosed quote (review_send.lua:212-217); the new spec fails when this branch is reverted.
- BR-5 — addressed — couch_spec has a live conformance spec that resolves own_actor from the real couch --actors JSON; it is pending outside a pair slot.

## Open findings

(none — every finding has been disposed)
