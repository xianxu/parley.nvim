# Boundary Review — parley.nvim#441 (whole-issue close)

| field | value |
|-------|-------|
| issue | 441 — Standalone review: forced tool choice rejected by claude-sonnet-5-5; expose upstream failure reason |
| repo | parley.nvim |
| issue file | workshop/issues/000441-standalone-forced-tool.md |
| boundary | whole-issue close |
| milestone | — |
| window | 64c2744fb9cc4378aad67bd039e6c5a2c30a3efa..443af7ec707b78f44ad44c44d0d20108620eccc0 |
| command | sdlc close --issue 441 |
| reviewer | codex (openai; author openai) |
| isolation | fenced |
| timestamp | 2026-10-24T17:24:37-07:00 |
| verdict | REWORK |

## Review

```verdict
verdict: REWORK
confidence: high
```

Automatic tool choice reaches the provider wires, and proposal admission remains ahead of effects. Both runtime test runs pass. Shipping is blocked by a reproduced disclosure gap in error sanitization and the explicitly outstanding operator retry.

Done-when: current — the prose-only revision is covered by the existing empty/no-proposal refusal clause; the required operator retry remains incomplete.

```findings
findings:
  - id: new
    severity: Critical
    kind: defect
    family: public-diagnostics-exclude-sensitive-values
    title: |
      Structured error messages can still expose document text and credentials
    detail: |
      lua/parley/skill_failure.lua:15-36 treats arbitrary error.message text as safe unless it matches selected markers or complete quoted spans. At pinned HEAD, direct calls returned "HTTP 400: Invalid value: PRIVATE DOCUMENT", an unmatched-quote variant containing PRIVATE DOCUMENT, and "HTTP 400: Invalid x-api credential: abcdef123456" unchanged. Enumerated affected paths: skill_invoke.lua:662 puts this output in result.msg; skills/review/init.lua:619 uses it for the caption; line 621 stores result.msg in message history. Recognize safe diagnostic templates with constrained values and fall back for unknown messages. Add regression tests for unquoted echoes, unmatched quotes, and unrecognized credential forms while retaining the captured rejection.
  - id: new
    severity: Important
    kind: defect
    family: required-acceptance-before-close
    title: |
      The required real standalone operator retry remains outstanding
    detail: |
      workshop/issues/000441-standalone-forced-tool.md:56 requires a real operator retry, but lines 67, 79 and 81 explicitly leave it pending or unclaimed. These are all instances of this acceptance gap in the window. Payload assertions and injected rejection callbacks do not establish that the captured model/provider accepts the revised request. ARCH-PURPOSE: complete and record sanitized standalone retry evidence before whole-issue close, including the actual model/provider and observed outcome.
```

1. **Strengths**
   - Provider wire owners encode automatic choice; voice-apply retains named forcing.
   - Zero-proposal rejection occurs before producer execution (`skill_invoke.lua:479`).
   - Tests exercise mixed command/question edits and both prose-only and empty responses.
   - README and atlas describe the new behavior and manifest field.

2. **Critical findings**
   - The formatter’s denylist cannot establish the promised exclusion of request text and credentials. Reproductions and affected consumers are enumerated above.

3. **Important findings**
   - Complete the acceptance retry required by the unchanged Done-when contract.

4. **Minor findings**
   - None.

5. **Test coverage notes**
   - `make test-spec SPEC=skills/skill-system`: **311 passed, zero failures/errors** on each of Neovim **0.12.5** and **0.11.7**; both process censuses clean.
   - Existing sanitization tests miss the reproduced disclosure cases.
   - `git diff --check` passed; checkout remained unchanged.

6. **Architectural notes**
   - **ARCH-DRY: pass** — wire encoding and public-reason formatting have shared owners.
   - **ARCH-PURE: pass** — deterministic formatting is separated from transport and notice effects.
   - **ARCH-PURPOSE: flag** — required live acceptance remains deferred.
   - **ARCH-EVOLVE: pass** — optional manifest policy is additive; no persisted rewrite path changes.

7. **Plan revision recommendations**
   - Add a `## Revisions` entry defining safe diagnostic recognition and fallback behavior, covering all disclosure cases above.
   - Keep operator acceptance outstanding until measured evidence is recorded; the current Done-when needs no revision.

<!-- sdlc-review-usage [{"version":1,"intent":{"disposable_root":true,"id":"a2483b0b-bd35-48fa-9778-165d480ea10e","repository":"github.com/xianxu/parley.nvim","issue_id":"000441","recipe":"small-diff-review","round":1,"attempt":1,"agent":"codex","root":"/Volumes/TestScratch/review-checkouts/ac005ed5c4e67eb1","reviewed_head":"443af7ec707b78f44ad44c44d0d20108620eccc0","slot":"parley.nvim:2","requested_at":"2026-10-25T00:22:02.91089Z"},"phase":"finished","pid":58633,"started_at":"2026-10-25T00:22:03.100476Z","finished_at":"2026-10-25T00:24:36.219744Z","session_id":"01a1706f-998b-72d1-9a4f-6ae66b9ff7ca","outcome":"returned"}] -->

---

## Re-review — 2026-10-24T20:05:20-07:00 (SHIP)

| field | value |
|-------|-------|
| issue | 441 — Standalone review: forced tool choice rejected by claude-sonnet-5-5; expose upstream failure reason |
| repo | parley.nvim |
| issue file | workshop/issues/000441-standalone-forced-tool.md |
| boundary | whole-issue close |
| milestone | — |
| window | 64c2744fb9cc4378aad67bd039e6c5a2c30a3efa..475638abdc2bd0cb6de83318df9720a9bfb1572e |
| command | sdlc close --issue 441 |
| reviewer | codex (openai; author openai) |
| isolation | fenced |
| timestamp | 2026-10-24T20:05:20-07:00 |
| verdict | SHIP |

## Review

```verdict
verdict: SHIP
confidence: high
```

Automatic tool choice reaches the provider wires while proposal validation remains ahead of effects. The privacy fix addresses the reported disclosure class, and the tracker records the required standalone operator acceptance. No new blocking findings.

Done-when: current — its no-proposal refusal and safe-diagnostics clauses cover the revisions; operator acceptance is now recorded.

```findings
dispose:
  - id: BR-1
    disposition: addressed
    note: |
      skill_failure.lua:4-34 emits only fixed descriptions and validated HTTP integers. With the prior formatter temporarily restored, nine formatter tests and all three real review-path privacy regressions failed; the pinned implementation passes. Result messages, captions and history all consume the corrected formatter.
  - id: BR-2
    disposition: addressed
    note: |
      workshop/issues/000441-standalone-forced-tool.md:87-89 records outside-Couch acceptance on staged fc955fb249525287f25da4a472f23f6711ced846 with claude-sonnet-5-5 through CLIProxy: the command applied and the question remained. Comparing that candidate with pinned HEAD shows only issue-record changes, so the accepted code matches this review.
```

1. **Strengths**

   - Provider wire owners encode automatic choice; voice-apply retains named forcing.
   - Zero proposals refuse before tool execution, backup or reload (`lua/parley/skill_invoke.lua:479`).
   - Privacy tests exercise actual review captions and message history, alongside direct formatter coverage.
   - README and atlas document the behavior and optional manifest policy.

2. **Critical findings**

   None.

3. **Important findings**

   None.

4. **Minor findings**

   None.

5. **Test coverage notes**

   - `make test-spec SPEC=skills/skill-system` passed on Neovim **0.12.5** and **0.11.7**; the mapped suite contains **322 tests**.
   - Both runs reported clean process censuses.
   - Restoring the old formatter produced **12 regression failures**, confirming the correction is exercised.
   - Diff whitespace checks passed. The pinned formatter was restored and the checkout remained clean.

6. **Architectural notes**

   - **ARCH-DRY: pass** — wire encoding and public diagnostic formatting retain shared owners.
   - **ARCH-PURE: pass** — deterministic formatting stays separate from transport and UI effects.
   - **ARCH-PURPOSE: pass** — automatic choice preserves proposal admission, and required live acceptance is recorded.
   - **ARCH-EVOLVE: pass** — the optional manifest field is additive; no persisted rewrite path changes.

7. **Plan revision recommendations**

   None. Existing revisions describe the implemented diagnostic rule and proposal refusal behavior.

<!-- sdlc-review-usage [{"version":1,"intent":{"disposable_root":true,"id":"55e74838-201d-4faa-bb29-7e32f10e764f","repository":"github.com/xianxu/parley.nvim","issue_id":"000441","recipe":"small-diff-review","round":2,"attempt":1,"agent":"codex","root":"/Volumes/TestScratch/review-checkouts/932d9e95124f2f17","reviewed_head":"475638abdc2bd0cb6de83318df9720a9bfb1572e","slot":"parley.nvim:2","requested_at":"2026-10-25T03:01:26.537365Z"},"phase":"finished","pid":32929,"started_at":"2026-10-25T03:01:26.693378Z","finished_at":"2026-10-25T03:05:19.353809Z","session_id":"01a17101-84a5-70c0-93a0-87630dcadb2a","outcome":"returned"}] -->
