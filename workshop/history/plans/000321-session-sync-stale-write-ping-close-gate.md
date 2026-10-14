---
gate: boundary-review
issue: 321
id_prefix: BR
rounds:
    - "n": 1
      timestamp: "2026-10-13T23:02:08-07:00"
      dispatched: "2026-10-13T22:56:13-07:00"
      agent: codex
      findings:
        - id: BR-1
          severity: Critical
          title: Invalid LastWrite timestamps can trigger stale-work pings
          detail: lua/parley/session_sync.lua:342 trusts parse_time, whose implementation at lines 109–126 accepts invalid calendar dates, clock components, offsets, and malformed fractional syntax. A direct execution with LastWrite="2020-00-00T00:00:00Z", valid owed work, and a quiet owner sent one ping. The complete timestamp-consumer family in this probe is LastWrite at line 342, fallback Owed.At at line 332, and LastActivity at line 357. Validate through the shared parser and cover impossible dates, out-of-range times/offsets, and malformed fractions; the new test at tests/integration/session_sync_spec.lua:648 only checks "invalid".
          family: invalid-time-must-remain-unknown
          round: 1
        - id: BR-2
          severity: Important
          title: 'ARCH-PURE: separate ping admission policy from the query callback'
          detail: lua/parley/session_sync.lua:341–346 mixes baseline selection, generation identity, and threshold admission with configuration access, the clock, and lock-file reads; the related actor admission at lines 355–359 also combines policy and I/O. Extract deterministic decisions over supplied observations and retain queries, lock/mtime reads, state mutation, and sending in the shell. These are the two admission sites in this window. Test the policy without timers or subprocesses, and update the Core concepts table at workshop/issues/000321-session-sync-stale-write-ping.md:131 with PURE/INTEGRATION kinds.
          family: admission-policy-pure-boundary
          round: 1
        - id: BR-3
          severity: Important
          title: Boundary tests bypass the shipped fifteen-minute default
          detail: tests/integration/session_sync_spec.lua:552 sets session_sync_ping_minutes=nil, while the outer fixture at line 84 sets it to five. Consequently the new boundary tests cover only session_sync.lua:344's fallback; reverting config.lua:487 to five would leave them green. The complete default family is the shipped configuration and the runtime fallback. Exercise the shipped value at 899 and 900 seconds, retaining separate fallback and explicit-override coverage.
          family: shipped-default-regression-coverage
          round: 1
        - id: BR-4
          severity: Important
          title: README and atlas updates are missing for changed configuration and tracker surfaces
          detail: README.md is unchanged despite the session_sync_ping_minutes default change at lua/parley/config.lua:487. The generated vocabulary also adds area/severity card fields and setters at construct/generated/vocabulary/issue.json:108–119, plus repository-enum metadata at line 25; the only atlas change covers session-sync. These fields affect existing vocabulary-driven tracker consumers, including lua/parley/issue_cards.lua:172 and :375. Enumerated documentation gaps are the ping configuration/default, area and severity tracker fields/setters, and .sdlc/vocabulary.json repository-enum convention. Add appropriate README guidance and update the tracker atlas documentation.
          family: changed-surface-documentation
          round: 1
      recipe: small-diff-review
      isolation: fenced
      blocked: true
    - "n": 2
      timestamp: "2026-10-13T23:22:44-07:00"
      dispatched: "2026-10-13T23:19:22-07:00"
      agent: codex
      dispose:
        - id: BR-1
          disposition: addressed
          note: Shared parser validation covers calendar, clock, offset, and fraction errors. Restoring the old parser caused two unit failures and all three LastWrite/Owed.At/LastActivity integration regressions to fail.
          round: 2
        - id: BR-2
          disposition: addressed
          note: session_sync.lua:137–151 extracts both admission policies into deterministic helpers, called at lines 364 and 377. Direct unit tests require no timers, subprocesses, or filesystem observations; the Core concepts table now classifies the entities correctly.
          round: 2
        - id: BR-3
          disposition: addressed
          note: Integration tests load the shipped configuration and exercise 899/900 seconds, with separate fallback and override cases. Reverting only the shipped default to five caused two integration failures.
          round: 2
        - id: BR-4
          disposition: addressed
          note: README.md:48–52 documents the fifteen-minute default and override, matching config.lua:487. atlas/issues/issue-management.md:60–68 documents tracker fields, setters, and repository-enum metadata, matching construct/generated/vocabulary/issue.json and the generic issue_cards.lua consumers.
          round: 2
      findings:
        - id: BR-5
          severity: Important
          title: Vocabulary freshness verification remains unavailable
          detail: 'Makefile.parley:269 invokes scripts/check-vocabulary.sh, but the pinned checkout''s check fails with “no vocabulary noun "issue" (have: [])”. This is the sole failed verification command in this review. Restore the vocabulary dependency discovery needed by this checkout and rerun the check before crossing the boundary; no generated-content correction is established by this failure.'
          family: boundary-verification-available
          round: 2
      recipe: small-diff-review
      isolation: fenced
      blocked: true
    - "n": 3
      timestamp: "2026-10-13T23:27:28-07:00"
      dispatched: "2026-10-13T23:24:27-07:00"
      agent: codex
      dispose:
        - id: BR-1
          disposition: addressed
          note: Shared timestamp validation protects LastWrite, Owed.At, and LastActivity. Tests pass; restoring the old parser independently caused two unit failures.
          round: 3
        - id: BR-2
          disposition: addressed
          note: session_sync.lua:137 and :147 define directly tested pure admission helpers, consumed at :364 and :377. Core concepts classifications match the implementation.
          round: 3
        - id: BR-3
          disposition: addressed
          note: Integration coverage loads the shipped default and tests 899/900 seconds separately from fallback and override cases. Restoring five minutes independently caused two integration failures.
          round: 3
        - id: BR-4
          disposition: addressed
          note: README.md:48 documents the default and override matching config.lua:487; atlas/issues/issue-management.md:60 documents metadata matching the generated vocabulary and generic issue_cards.lua consumers.
          round: 3
        - id: BR-5
          disposition: withdrawn
          note: 'Independently ran the canonical checkout''s identical check-vocabulary.sh against this pinned artifact: exit 0, content matches upstream export. Confirmed blob 81cad8767aa6a444351e347dd551a408734c8738. Missing sibling dependency discovery in the review checkout does not establish product drift.'
          round: 3
      recipe: small-diff-review
      isolation: fenced
      reviewed: 6c3a89ede9ab0edecf027f969543fc08462bcfe3
      blocked: false
disputes:
    - id: BR-5
      rationale: The review checkout lacks the ../ariadne dependency named by construct/deps. The exporter reports no noun, not a content mismatch. The exact committed artifact is verified against the dependency model in the canonical checkout; changing product code or gate configuration to accommodate missing review dependencies is outside this consumer change.
      evidence: 'Re-ran make check-vocabulary: exit 0, issue vocabulary content matches upstream export. Also git show HEAD:construct/generated/vocabulary/issue.json to /tmp/parley-321-pinned-vocabulary.json then scripts/check-vocabulary.sh --artifact /tmp/parley-321-pinned-vocabulary.json: exit 0. Both pinned and working artifact Git blob 81cad8767aa6a444351e347dd551a408734c8738. Full make test passes all 427 files.'
      after: 2
      timestamp: "2026-10-14T06:23:59Z"
      by: Xian Xu on Xian’s MacBook Pro at parley.nvim:1 (/Users/xianxu/workspace/worktree/parley.nvim-slot1/parley.nvim)
---

# Gate ledger — parley.nvim#321 (boundary-review)

Findings this gate raised, the stable ids the binary assigned them, and how
later rounds disposed of them. Generated — edit the gate, not this file.

## Round 1 — 2026-10-13T23:02:08-07:00 (codex) — BLOCKED

### Raised

- **BR-1** [Critical] `invalid-time-must-remain-unknown` Invalid LastWrite timestamps can trigger stale-work pings
  lua/parley/session_sync.lua:342 trusts parse_time, whose implementation at lines 109–126 accepts invalid calendar dates, clock components, offsets, and malformed fractional syntax. A direct execution with LastWrite="2020-00-00T00:00:00Z", valid owed work, and a quiet owner sent one ping. The complete timestamp-consumer family in this probe is LastWrite at line 342, fallback Owed.At at line 332, and LastActivity at line 357. Validate through the shared parser and cover impossible dates, out-of-range times/offsets, and malformed fractions; the new test at tests/integration/session_sync_spec.lua:648 only checks "invalid".
- **BR-2** [Important] `admission-policy-pure-boundary` ARCH-PURE: separate ping admission policy from the query callback
  lua/parley/session_sync.lua:341–346 mixes baseline selection, generation identity, and threshold admission with configuration access, the clock, and lock-file reads; the related actor admission at lines 355–359 also combines policy and I/O. Extract deterministic decisions over supplied observations and retain queries, lock/mtime reads, state mutation, and sending in the shell. These are the two admission sites in this window. Test the policy without timers or subprocesses, and update the Core concepts table at workshop/issues/000321-session-sync-stale-write-ping.md:131 with PURE/INTEGRATION kinds.
- **BR-3** [Important] `shipped-default-regression-coverage` Boundary tests bypass the shipped fifteen-minute default
  tests/integration/session_sync_spec.lua:552 sets session_sync_ping_minutes=nil, while the outer fixture at line 84 sets it to five. Consequently the new boundary tests cover only session_sync.lua:344's fallback; reverting config.lua:487 to five would leave them green. The complete default family is the shipped configuration and the runtime fallback. Exercise the shipped value at 899 and 900 seconds, retaining separate fallback and explicit-override coverage.
- **BR-4** [Important] `changed-surface-documentation` README and atlas updates are missing for changed configuration and tracker surfaces
  README.md is unchanged despite the session_sync_ping_minutes default change at lua/parley/config.lua:487. The generated vocabulary also adds area/severity card fields and setters at construct/generated/vocabulary/issue.json:108–119, plus repository-enum metadata at line 25; the only atlas change covers session-sync. These fields affect existing vocabulary-driven tracker consumers, including lua/parley/issue_cards.lua:172 and :375. Enumerated documentation gaps are the ping configuration/default, area and severity tracker fields/setters, and .sdlc/vocabulary.json repository-enum convention. Add appropriate README guidance and update the tracker atlas documentation.

## Round 2 — 2026-10-13T23:22:44-07:00 (codex) — BLOCKED

### Disposed

- BR-1 — addressed — Shared parser validation covers calendar, clock, offset, and fraction errors. Restoring the old parser caused two unit failures and all three LastWrite/Owed.At/LastActivity integration regressions to fail.
- BR-2 — addressed — session_sync.lua:137–151 extracts both admission policies into deterministic helpers, called at lines 364 and 377. Direct unit tests require no timers, subprocesses, or filesystem observations; the Core concepts table now classifies the entities correctly.
- BR-3 — addressed — Integration tests load the shipped configuration and exercise 899/900 seconds, with separate fallback and override cases. Reverting only the shipped default to five caused two integration failures.
- BR-4 — addressed — README.md:48–52 documents the fifteen-minute default and override, matching config.lua:487. atlas/issues/issue-management.md:60–68 documents tracker fields, setters, and repository-enum metadata, matching construct/generated/vocabulary/issue.json and the generic issue_cards.lua consumers.

### Raised

- **BR-5** [Important] `boundary-verification-available` Vocabulary freshness verification remains unavailable
  Makefile.parley:269 invokes scripts/check-vocabulary.sh, but the pinned checkout's check fails with “no vocabulary noun "issue" (have: [])”. This is the sole failed verification command in this review. Restore the vocabulary dependency discovery needed by this checkout and rerun the check before crossing the boundary; no generated-content correction is established by this failure.

## Round 3 — 2026-10-13T23:27:28-07:00 (codex) — passed

### Disposed

- BR-1 — addressed — Shared timestamp validation protects LastWrite, Owed.At, and LastActivity. Tests pass; restoring the old parser independently caused two unit failures.
- BR-2 — addressed — session_sync.lua:137 and :147 define directly tested pure admission helpers, consumed at :364 and :377. Core concepts classifications match the implementation.
- BR-3 — addressed — Integration coverage loads the shipped default and tests 899/900 seconds separately from fallback and override cases. Restoring five minutes independently caused two integration failures.
- BR-4 — addressed — README.md:48 documents the default and override matching config.lua:487; atlas/issues/issue-management.md:60 documents metadata matching the generated vocabulary and generic issue_cards.lua consumers.
- BR-5 — withdrawn — Independently ran the canonical checkout's identical check-vocabulary.sh against this pinned artifact: exit 0, content matches upstream export. Confirmed blob 81cad8767aa6a444351e347dd551a408734c8738. Missing sibling dependency discovery in the review checkout does not establish product drift.

## Disputes

Findings the implementer declined (`sdlc finding dispute`), each answered by the
next review round.

- **BR-5** — after round 2 (2026-10-14T06:23:59Z, Xian Xu on Xian’s MacBook Pro at parley.nvim:1 (/Users/xianxu/workspace/worktree/parley.nvim-slot1/parley.nvim))
  rationale: The review checkout lacks the ../ariadne dependency named by construct/deps. The exporter reports no noun, not a content mismatch. The exact committed artifact is verified against the dependency model in the canonical checkout; changing product code or gate configuration to accommodate missing review dependencies is outside this consumer change.
  evidence: Re-ran make check-vocabulary: exit 0, issue vocabulary content matches upstream export. Also git show HEAD:construct/generated/vocabulary/issue.json to /tmp/parley-321-pinned-vocabulary.json then scripts/check-vocabulary.sh --artifact /tmp/parley-321-pinned-vocabulary.json: exit 0. Both pinned and working artifact Git blob 81cad8767aa6a444351e347dd551a408734c8738. Full make test passes all 427 files.

## Open findings

(none — every finding has been disposed)
