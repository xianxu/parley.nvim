# Boundary Review — parley.nvim#303 (whole-issue close)

| field | value |
|-------|-------|
| issue | 303 — Use familiar keys for app completion |
| repo | parley.nvim |
| issue file | workshop/issues/000303-app-completion-keys.md |
| boundary | whole-issue close |
| milestone | — |
| window | 4539950f811407dc477b5064b043631cea2b760c..d8d32e92dbe181ba95b3f6b972ef83d8493ff254 |
| command | sdlc close --issue 303 |
| reviewer | codex |
| timestamp | 2026-09-29T12:07:02-07:00 |
| verdict | SHIP |

## Review

```verdict
verdict: SHIP
confidence: high
```

The pinned range delivers #303’s completion behavior and preserves the inherited pairing and context-projection contracts. Independent tests passed; removing the five new mappings in memory made the keyboard regression fail as expected. No blocking findings.

1. **Strengths**

   - Starter mappings reuse Blink commands with native fallbacks (`packaging/starter-config/init.lua:169`).
   - Real keyboard tests cover selected/unselected acceptance, dismissal preserving Insert mode, fallback behavior, and prepared-chat coexistence.
   - Context projection preserves raw document content and serialized tool payloads.
   - README and atlas document the changed user-facing behavior.

2. **Critical findings:** None.

3. **Important findings:** None.

4. **Minor findings:** Trailing whitespace in `workshop/plans/000300-app-labels-buffer-completion-close-review.md:45` causes the pinned-range `git diff --check` to report an error. Remove that whitespace.

5. **Test coverage notes**

   - Exact pinned Blink commit: **35 keyboard steps passed**.
   - `infra/starter`: **185 tests passed**.
   - Focused pairing, question-tag, message-building, and ancestor suites: **151 tests passed**.
   - In-memory removal of the five mappings failed at step 7: “Tab did not select first candidate.”
   - Full suite not rerun. The harness could not perform its process census because `ps` was unavailable.
   - Repository files remained unchanged.

6. **Architectural notes**

   - **ARCH-DRY — pass:** Built-in Blink commands and shared projection helpers.
   - **ARCH-PURE — pass:** Pairing decisions remain pure; editor effects stay in the mapping callback.
   - **ARCH-PURPOSE — pass:** Requested keys and native fallbacks are implemented and exercised.
   - **ARCH-MOCK — pass:** No new external-service boundary; completion tests exercise real pinned Blink.
   - **ARCH-CONSTRAINTS — pass:** Current-buffer completion and line-local pairing avoid broader scans.
   - **ARCH-SECURE — pass:** No added credential surface; verification uses isolated profiles.
   - **ARCH-ORDER — pass:** Completion state remains Blink-owned; actual event-loop typing exercises transitions.
   - **ARCH-FUNERAL — pass:** No new durable runtime artifact or background owner.

7. **Plan revision recommendations:** None.

```findings
findings:
  - id: new
    severity: Minor
    family: diff-hygiene
    title: |
      Remove trailing whitespace from the committed review transcript
    detail: |
      workshop/plans/000300-app-labels-buffer-completion-close-review.md:45 contains trailing whitespace reported by git diff --check across the pinned range. Remove the whitespace; runtime behavior is unaffected.
```
