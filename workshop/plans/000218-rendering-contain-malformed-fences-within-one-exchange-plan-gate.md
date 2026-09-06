---
gate: plan-quality
issue: 218
id_prefix: PQ
rounds:
    - "n": 1
      timestamp: "2026-09-05T12:17:20-07:00"
      agent: claude
      findings:
        - id: PQ-1
          severity: Critical
          title: Step 2 swaps a post-transition accumulator for a pre-transition snapshot without saying so
          detail: |-
            state_before is written at highlight_structure.lua:161 BEFORE the fence
            toggle at :173, while highlighter.lua:149 toggles before use — so the two
            disagree on every fence-delimiter row (pinned by highlight_structure_spec.lua:52).
            Reading state_before per row inverts the fence line's own render at
            highlighter.lua:247 and dims every tool body's closing fence at :223.
            The plan checks only cost. Name the phase it adopts, and say the same for
            step 1's reset placement (footer guard runs before the snapshot, token
            branches after it).
          family: state-snapshot-phase-mismatch
          round: 1
        - id: PQ-2
          severity: Critical
          title: Length-typed in_code makes M.replace's fast path serve stale state
          detail: |-
            highlight_structure.lua:206-228 takes its fast path on fingerprint-token
            equality and reuses structure.state_before verbatim; it runs per keystroke
            via highlighter.lua:926. Three and four backticks share the token but
            differ in length, so editing a fence's width in place keeps stale state for
            the rest of the buffer. The plan must widen the cache key or force a
            rebuild on fence-token rows (ARCH-ORDER).
          family: fingerprint-key-underspecifies-state
          round: 1
        - id: PQ-3
          severity: Important
          title: parley.fence is scoped to tool bodies and is stricter than the current render predicate
          detail: |-
            fence.lua's first line scopes it to tool bodies; open_len matches
            "^(`+)([^`]*)$" — no leading whitespace — while classify at
            highlight_structure.lua:85 accepts "^%s*```". Adopting it changes indented
            fences from recognized to not, and makes a tool-body same-length rule the
            canonical prose grammar. State the delta and decide it deliberately.
          family: grammar-scope-widening
          round: 1
        - id: PQ-4
          severity: Important
          title: Fence-derivation sweep names one site; outline.lua and skills/review are also non-derived
          detail: |-
            outline.lua:31-33 toggles on "^%s*```" or "^%s*~~~"; skills/review/init.lua:166-172
            toggles on "^```". "Completes #200's sweep" is false with those standing.
            Put the enumeration of fence implementations in the plan and sweep it this
            round rather than as a "check whether" item with no stated action
            (ARCH-PURPOSE, ARCH-DRY).
          family: instance-not-class-sweep
          round: 1
        - id: PQ-5
          severity: Important
          title: Test plan enumerates five prose cases and names no function under test
          detail: |-
            Compress to the functions plus one strategy line each: highlight_structure.build
            (property/fuzz over arbitrary fence-run interleavings — in_code false at every
            partition row), highlight_structure.replace (fence-length-edit input class),
            and the highlighter render seam (highlighter.lua:878's caller;
            tests/unit/highlighter_spec.lua exists). Without the third, D1b — the site
            the plan calls the one a site-level fix would miss — ships untested.
          family: test-strategy-not-enumeration
          round: 1
        - id: PQ-6
          severity: Minor
          title: '"the only external reader is highlighter.lua:140" is wrong'
          detail: |-
            tests/unit/highlight_structure_spec.lua:14,52,54 compare in_code against
            booleans with assert.are.same, so the boolean-to-length change lands there too.
          family: unbacked-existing-behavior-claim
          round: 1
      blocked: true
    - "n": 2
      timestamp: "2026-09-05T12:22:31-07:00"
      agent: claude
      dispose:
        - id: PQ-1
          disposition: addressed
          note: Phase named for both the reset (pre-snapshot) and the dedup; the state_before-per-row approach is dropped for an extracted advance().
          round: 2
        - id: PQ-2
          disposition: addressed
          note: Fence fingerprints become "c"..n so a width edit invalidates M.replace's fast path; :173 becomes a prefix test.
          round: 2
        - id: PQ-3
          disposition: addressed
          note: 'parley.fence explicitly not adopted; the two grammars stay separate and the "completes #200''s sweep" claim is retracted.'
          round: 2
        - id: PQ-4
          disposition: addressed
          note: Enumeration is now four trackers, in a Plan row and a Done-when line; I verified sites 3 and 4 exist as described.
          round: 2
        - id: PQ-5
          disposition: addressed
          note: Three named functions with one strategy line each, including the highlighter render seam.
          round: 2
        - id: PQ-6
          disposition: addressed
          note: Retracted in the Log; in_code stays boolean with code_fence_len alongside.
          round: 2
      blocked: false
content_hash: f00407c5c80c2375aa66ca90f5c0c38809edb8b46645ac00e0eb76601f36d48d
---

# Gate ledger — parley.nvim#218 (plan-quality)

Findings this gate raised, the stable ids the binary assigned them, and how
later rounds disposed of them. Generated — edit the gate, not this file.

## Round 1 — 2026-09-05T12:17:20-07:00 (claude) — BLOCKED

### Raised

- **PQ-1** [Critical] `state-snapshot-phase-mismatch` Step 2 swaps a post-transition accumulator for a pre-transition snapshot without saying so
  state_before is written at highlight_structure.lua:161 BEFORE the fence
  toggle at :173, while highlighter.lua:149 toggles before use — so the two
  disagree on every fence-delimiter row (pinned by highlight_structure_spec.lua:52).
  Reading state_before per row inverts the fence line's own render at
  highlighter.lua:247 and dims every tool body's closing fence at :223.
  The plan checks only cost. Name the phase it adopts, and say the same for
  step 1's reset placement (footer guard runs before the snapshot, token
  branches after it).
- **PQ-2** [Critical] `fingerprint-key-underspecifies-state` Length-typed in_code makes M.replace's fast path serve stale state
  highlight_structure.lua:206-228 takes its fast path on fingerprint-token
  equality and reuses structure.state_before verbatim; it runs per keystroke
  via highlighter.lua:926. Three and four backticks share the token but
  differ in length, so editing a fence's width in place keeps stale state for
  the rest of the buffer. The plan must widen the cache key or force a
  rebuild on fence-token rows (ARCH-ORDER).
- **PQ-3** [Important] `grammar-scope-widening` parley.fence is scoped to tool bodies and is stricter than the current render predicate
  fence.lua's first line scopes it to tool bodies; open_len matches
  "^(`+)([^`]*)$" — no leading whitespace — while classify at
  highlight_structure.lua:85 accepts "^%s*```". Adopting it changes indented
  fences from recognized to not, and makes a tool-body same-length rule the
  canonical prose grammar. State the delta and decide it deliberately.
- **PQ-4** [Important] `instance-not-class-sweep` Fence-derivation sweep names one site; outline.lua and skills/review are also non-derived
  outline.lua:31-33 toggles on "^%s*```" or "^%s*~~~"; skills/review/init.lua:166-172
  toggles on "^```". "Completes #200's sweep" is false with those standing.
  Put the enumeration of fence implementations in the plan and sweep it this
  round rather than as a "check whether" item with no stated action
  (ARCH-PURPOSE, ARCH-DRY).
- **PQ-5** [Important] `test-strategy-not-enumeration` Test plan enumerates five prose cases and names no function under test
  Compress to the functions plus one strategy line each: highlight_structure.build
  (property/fuzz over arbitrary fence-run interleavings — in_code false at every
  partition row), highlight_structure.replace (fence-length-edit input class),
  and the highlighter render seam (highlighter.lua:878's caller;
  tests/unit/highlighter_spec.lua exists). Without the third, D1b — the site
  the plan calls the one a site-level fix would miss — ships untested.
- **PQ-6** [Minor] `unbacked-existing-behavior-claim` "the only external reader is highlighter.lua:140" is wrong
  tests/unit/highlight_structure_spec.lua:14,52,54 compare in_code against
  booleans with assert.are.same, so the boolean-to-length change lands there too.

## Round 2 — 2026-09-05T12:22:31-07:00 (claude) — passed

### Disposed

- PQ-1 — addressed — Phase named for both the reset (pre-snapshot) and the dedup; the state_before-per-row approach is dropped for an extracted advance().
- PQ-2 — addressed — Fence fingerprints become "c"..n so a width edit invalidates M.replace's fast path; :173 becomes a prefix test.
- PQ-3 — addressed — parley.fence explicitly not adopted; the two grammars stay separate and the "completes #200's sweep" claim is retracted.
- PQ-4 — addressed — Enumeration is now four trackers, in a Plan row and a Done-when line; I verified sites 3 and 4 exist as described.
- PQ-5 — addressed — Three named functions with one strategy line each, including the highlighter render seam.
- PQ-6 — addressed — Retracted in the Log; in_code stays boolean with code_fence_len alongside.

## Open findings

(none — every finding has been disposed)
