---
gate: plan-quality
issue: 203
id_prefix: PQ
rounds:
    - "n": 1
      timestamp: "2026-08-22T18:08:37-07:00"
      agent: claude
      findings:
        - id: PQ-1
          severity: Important
          title: Done-when requires fold_adversarial.md unchanged; Plan step 3 changes it
          detail: |-
            Done-when bullet 2 says "tests/fixtures/fold_adversarial.md and
            fold_tool_transcript.md unchanged", but Plan bullet 3 re-points that
            fixture's read_file body and the experiment patch rewrites it.
            fold_tool_transcript.md is genuinely unaffected; split the criterion so
            the byte-unchanged claim covers only what stays unchanged.
          family: acceptance-criteria-unsatisfiable
          round: 1
        - id: PQ-2
          severity: Important
          title: Plan does not state that only chat_parser gets the new close rule, diverging the three fence.scan consumers
          detail: |-
            The experiment adds an optional third is_structural predicate that only
            chat_parser passes, leaving answer_structure.lua:38 and
            fold_projection.lua:136 with wider body extents — contradicting the
            comments at answer_structure.lua:34-36 and fold_projection.lua:127-129
            and blinding verify_anchors' interior user check on exactly the recovered
            rows. State the signature change and whether all three share it
            (ARCH-DRY).
          family: shared-pass-divergence
          round: 1
        - id: PQ-3
          severity: Important
          title: '"a column-0 structural marker" names no kinds, yet the kind set decides which tests survive'
          detail: |-
            classify (highlight_structure.lua:56-71) yields thirteen kinds; the
            experiment used user|assistant. Excluding the tool kinds is what lets
            chat_parser_tools_spec.lua:383-395 pass untouched despite its unprefixed
            column-0 tool-result line. Name the set and the reason.
          family: undefined-predicate-set
          round: 1
        - id: PQ-4
          severity: Minor
          title: Producer-invariant guard hand-lists four tools of ten and only their success paths
          detail: |-
            tools/init.lua:158-173 registers nine builtins plus optional ack (not
            "eleven"); emit_definition is missing from the Revision's enumeration,
            and grep.lua:213 / ack.lua:179 / ls.lua:109 / find.lua:149 splice raw
            stderr after a prefixed first line. Drive the test from
            BUILTIN_NAMES/OPTIONAL_NAMES so a future builtin is covered by
            construction (ARCH-PURPOSE).
          family: guard-covers-instance-not-class
          round: 1
        - id: PQ-5
          severity: Minor
          title: fence.scan is not named as a unit-tested function despite owning the new rule
          detail: |-
            tests/unit/fence_spec.lua tests the pure grammar directly, but every test
            the plan names reaches the new close search through chat_parser fixtures.
            Name fence.scan with one strategy line - adversarial class is openers that
            never close and closes belonging to another pair, asserted on the returned
            bodies/markers model rather than a downstream exchange count (ARCH-PURE).
          family: pure-core-untested-directly
          round: 1
        - id: PQ-6
          severity: Minor
          title: chat_parser's second fence tracker keeps the old rule and is unmentioned
          detail: |-
            chat_parser.lua:456-465 tracks cb_state.tool_fence_len independently of
            fence.scan, so it will not stop at a structural marker. Harmless only
            because the fork finalizes the block first; say so in the plan (ARCH-DRY).
          family: duplicate-grammar-implementation
          round: 1
      blocked: true
    - "n": 2
      timestamp: "2026-08-22T18:12:53-07:00"
      agent: claude
      dispose:
        - id: PQ-1
          disposition: addressed
          note: Done-when bullet 2 is now behavioural; fold_adversarial.md's change is named as a fidelity correction.
          round: 2
        - id: PQ-2
          disposition: addressed
          note: Dedicated Plan bullet puts the predicate in the scan contract for all three consumers.
          round: 2
        - id: PQ-3
          disposition: addressed
          note: Set named and sourced from chat_parser.lua:288; note the widening also re-points chat_parser_tools_spec.lua:382-395, same unprefixed-fixture class as step 7.
          round: 2
        - id: PQ-4
          disposition: addressed
          note: Guard derives from BUILTIN_NAMES + OPTIONAL_NAMES; stderr-splice exception stated.
          round: 2
        - id: PQ-5
          disposition: addressed
          note: fence.scan named as directly unit-tested with one strategy line.
          round: 2
        - id: PQ-6
          disposition: addressed
          note: Second tracker gets a prove-or-derive bullet plus an agreement test.
          round: 2
      blocked: false
content_hash: 85da18a8aaf242a1b0c86c1111f88867f629c93072e14ba355812f0d894ff8e8
---

# Gate ledger — parley.nvim#203 (plan-quality)

Findings this gate raised, the stable ids the binary assigned them, and how
later rounds disposed of them. Generated — edit the gate, not this file.

## Round 1 — 2026-08-22T18:08:37-07:00 (claude) — BLOCKED

### Raised

- **PQ-1** [Important] `acceptance-criteria-unsatisfiable` Done-when requires fold_adversarial.md unchanged; Plan step 3 changes it
  Done-when bullet 2 says "tests/fixtures/fold_adversarial.md and
  fold_tool_transcript.md unchanged", but Plan bullet 3 re-points that
  fixture's read_file body and the experiment patch rewrites it.
  fold_tool_transcript.md is genuinely unaffected; split the criterion so
  the byte-unchanged claim covers only what stays unchanged.
- **PQ-2** [Important] `shared-pass-divergence` Plan does not state that only chat_parser gets the new close rule, diverging the three fence.scan consumers
  The experiment adds an optional third is_structural predicate that only
  chat_parser passes, leaving answer_structure.lua:38 and
  fold_projection.lua:136 with wider body extents — contradicting the
  comments at answer_structure.lua:34-36 and fold_projection.lua:127-129
  and blinding verify_anchors' interior user check on exactly the recovered
  rows. State the signature change and whether all three share it
  (ARCH-DRY).
- **PQ-3** [Important] `undefined-predicate-set` "a column-0 structural marker" names no kinds, yet the kind set decides which tests survive
  classify (highlight_structure.lua:56-71) yields thirteen kinds; the
  experiment used user|assistant. Excluding the tool kinds is what lets
  chat_parser_tools_spec.lua:383-395 pass untouched despite its unprefixed
  column-0 tool-result line. Name the set and the reason.
- **PQ-4** [Minor] `guard-covers-instance-not-class` Producer-invariant guard hand-lists four tools of ten and only their success paths
  tools/init.lua:158-173 registers nine builtins plus optional ack (not
  "eleven"); emit_definition is missing from the Revision's enumeration,
  and grep.lua:213 / ack.lua:179 / ls.lua:109 / find.lua:149 splice raw
  stderr after a prefixed first line. Drive the test from
  BUILTIN_NAMES/OPTIONAL_NAMES so a future builtin is covered by
  construction (ARCH-PURPOSE).
- **PQ-5** [Minor] `pure-core-untested-directly` fence.scan is not named as a unit-tested function despite owning the new rule
  tests/unit/fence_spec.lua tests the pure grammar directly, but every test
  the plan names reaches the new close search through chat_parser fixtures.
  Name fence.scan with one strategy line - adversarial class is openers that
  never close and closes belonging to another pair, asserted on the returned
  bodies/markers model rather than a downstream exchange count (ARCH-PURE).
- **PQ-6** [Minor] `duplicate-grammar-implementation` chat_parser's second fence tracker keeps the old rule and is unmentioned
  chat_parser.lua:456-465 tracks cb_state.tool_fence_len independently of
  fence.scan, so it will not stop at a structural marker. Harmless only
  because the fork finalizes the block first; say so in the plan (ARCH-DRY).

## Round 2 — 2026-08-22T18:12:53-07:00 (claude) — passed

### Disposed

- PQ-1 — addressed — Done-when bullet 2 is now behavioural; fold_adversarial.md's change is named as a fidelity correction.
- PQ-2 — addressed — Dedicated Plan bullet puts the predicate in the scan contract for all three consumers.
- PQ-3 — addressed — Set named and sourced from chat_parser.lua:288; note the widening also re-points chat_parser_tools_spec.lua:382-395, same unprefixed-fixture class as step 7.
- PQ-4 — addressed — Guard derives from BUILTIN_NAMES + OPTIONAL_NAMES; stderr-splice exception stated.
- PQ-5 — addressed — fence.scan named as directly unit-tested with one strategy line.
- PQ-6 — addressed — Second tracker gets a prove-or-derive bullet plus an agreement test.

## Open findings

(none — every finding has been disposed)
