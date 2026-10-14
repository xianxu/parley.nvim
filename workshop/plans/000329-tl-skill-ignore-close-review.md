# Boundary Review — parley.nvim#329 (whole-issue close)

| field | value |
|-------|-------|
| issue | 329 — Track generated TL skill ignore entries |
| repo | parley.nvim |
| issue file | workshop/issues/000329-tl-skill-ignore.md |
| boundary | whole-issue close |
| milestone | — |
| window | bb2ce85c3a4afb83efbfc97ca6f2420045eeb1aa..10ba8720a5a71cd38cbb6a8276b762d69c6fe8cc |
| command | sdlc close --issue 329 |
| reviewer | codex |
| isolation | fenced |
| timestamp | 2026-10-14T16:23:25-07:00 |
| verdict | REWORK |

## Review

```verdict
verdict: REWORK
confidence: high
```

The four-line change matches the Spec exactly and passes Git ignore checks. The preserved suite log covers all 427 spec files, with no failures and no subsequent implementation changes. Compile idempotence remains unverifiable: the required substrate is absent and the read-only compile preview fails.

```findings
findings:
  - id: new
    severity: Important
    kind: unverifiable
    family: generated-output-verification
    title: |
      Compile cleanliness cannot be verified without the declared substrate.
    detail: |
      The Done-when contract requires weave compile to leave the committed tree clean. `weave compile --dry-run` exits 1 because /Users/xianxu/Library/Caches/sdlc/review-checkouts/ariadne is missing. This affects the entire four-entry family: .agents/skills/xx-tl-lead, .agents/skills/xx-tl-worker, .claude/skills/xx-tl-lead, and .claude/skills/xx-tl-worker. Provide measured host evidence from the pinned head with the intended substrate revision: successful compile, byte-identical .gitignore before/after, and clean git status.
```

1. **Strengths**

   - Verified exactly four insertions; every other `.gitignore` byte is preserved.
   - All four paths match their specific rules at `.gitignore:24–25` and `:53–54`.
   - Root anchoring excludes nested paths and similarly named siblings.
   - The preserved suite log’s checksum matches; all 427 spec files passed with a clean process census.

2. **Critical findings:** None.

3. **Important findings:** Compile verification gap above. Supply measured evidence; no implementation defect was found.

4. **Minor findings:** None.

5. **Test coverage notes:** Independently checked exact scope, all four ignore rules, representative descendants, and negative path boundaries. Inspected the full-suite log rather than relying on the tracker’s success claim. PR CI remains a pre-landing requirement.

6. **Architectural notes**

   - **ARCH-DRY — pass:** Extends the existing generated block without adding generation logic.
   - **ARCH-PURE — pass:** No business logic or IO boundary changes.
   - **ARCH-PURPOSE — verification pending:** Both harness destinations are covered; generator cleanliness still needs measurement.
   - No new architectural or user-invoked surface requires atlas or README changes.

7. **Plan revision recommendations:** None to the implementation plan. Attach compile verification evidence to substantiate its checked completion item.
