# Boundary Review — parley.nvim#242 (milestone M1)

| field | value |
|-------|-------|
| issue | 242 — Retrofit ARCH-MOCK to the chat providers: one stateful fake per provider at the curl seam, integration tests through it, and a live conformance check that re-records the fixtures |
| repo | parley.nvim |
| issue file | workshop/issues/000242-arch-mock-stateful-fake-per-chat-provider.md |
| boundary | milestone M1 |
| milestone | M1 |
| window | a53472921f064c68ee2992246396794b593d01b9..ba0d3021074610bd8de5ad44097bc53c15bd8884 |
| command | sdlc milestone-close --issue 242 --milestone M1 |
| reviewer | claude |
| isolation | fenced |
| timestamp | 2026-10-16T07:43:38-07:00 |
| verdict | FIX-THEN-SHIP |

## Review

Reviewing the dispatcher's ending-notice path to check whether S3's assertion reflects user-visible behavior.

Now running the new specs and checking how the suite invokes single files.

Specs are running; checking the new files' results specifically.

All 11 new cases pass. Now probing whether S6's byte-split actually reaches parley's reader as many chunks, or curl coalesces them.

Byte-splitting does reach the reader (79 reads vs 1), so S6 is real, though not asserted. Checking S7a's "partial kept" assertion strength.

I've finished the review. Writing up the verdict.

```verdict
verdict: FIX-THEN-SHIP
confidence: high
```

M1 mostly delivers what it promises. There is one shared dialect module (`sse_dialects.py`), with pure `anthropic`, `behaviour` and `split` functions behind a thin `fake_provider` shell built on `LoopbackHTTPServer`. Integration specs S1–S7b run the real dispatcher → curl → out_reader path with the transport left alone. There is also a standalone proof driver for #228 and #229 on their pre-fix parents. I ran the `providers/architecture` and `providers/anthropic` spec keys in the harness. All new cases pass (sse_dialects 3/3, provider_anthropic 8/8), and the orphan check reports "clean: no surviving test processes". I also probed S6 with a wrapper around `tasker.run`. With `--split every_byte` the reader gets 79 calls, against 1 with `none`, so the byte splitting really reaches parley.

Three cheap issues block a clean SHIP:
- **Task 2's unit spec is missing.** `tests/unit/fake_provider_spec.lua` was never written, and no plan revision drops it.
- **S3 checks an internal function.** It calls `_classify_ending` directly instead of checking the notice the user actually sees.
- **S7a's "partial kept" check can't fail.** It asserts that a field initialized to `""` is not nil.

**1. Strengths**
- **One source for the wire format.** The anthropic SSE bytes come from one pure function (`tests/fixtures/sse_dialects.py:40`). The unit spec decodes them with parley's real parsers and checks them event by event against `anthropic_stream.txt` (`tests/unit/sse_dialects_spec.lua:35-48`). That makes them faithful to real bytes by construction, not by assertion.
- **The fake picks its reply from the request, not a counter** (`sse_dialects.py:103-124`). S2 checks the second request parley actually sent, via the request log, including the first call's `tool_use_id` (`provider_anthropic_spec.lua:53-58`).
- **The proofs are built well.** `run_proofs.sh` uses scratch worktrees, an isolated HOME and XDG, `PROOF-REACHED` markers so a run that never gets there counts as inconclusive, and a trap that removes everything. It needs nothing from the new code on the old trees, which follows PQ-1 closely.
- **Test-process lifecycle comes for free.** The fake inherits parent-death exit, the fixture arch count was bumped (`tests/arch/fixture_lifecycle_spec.lua:87`), and the orphan check is clean.
- **Credentials:** only dummy secrets are used, and the request log is a per-case temp file deleted in `after_each` (PQ-4/PQ-5 honoured).

**2. Critical findings**
None.

**3. Important findings**
- **Missing Task 2 spec** (ARCH-PURPOSE, ARCH-PURE). The plan lists `tests/unit/fake_provider_spec.lua` with four checks:
  - a table of request shapes → reply kind for `behaviour`;
  - "the slices concatenate back to the input, for every mode" for `split`;
  - one curl per failure mode, checking status and body;
  - the request log appears only when its variable is set.

  None of these exist, so the pure core is tested only indirectly, through the integration cases. **Fix:** add the spec. `behaviour` and `split` can be tested without IO through `python3 -I`, the same way `sse_dialects_spec` already runs the module. Otherwise, add a Revisions entry saying why it was dropped.
- **S3 bypasses the path it claims to test** (`tests/integration/provider_anthropic_spec.lua:66`).
  - The test calls `dispatcher._classify_ending(out.qt)` itself, so it would still pass if the dispatcher stopped reporting the in-band error.
  - In fact the dispatcher *does* show it to the user. `_ending_notice` returns "answer is TRUNCATED … an error the provider sent in-band — Overloaded" at warning level (`lua/parley/dispatcher.lua:362-370`), and the dispatcher logs warnings unconditionally (`:856-863`).
  - So the Log's reason for the workaround ("logs error-level notices only for empty response") is misleading.
  - **Fix:** assert `any(out.warnings, "in-band — Overloaded")`, as S5 already does for the cap, and correct the plan's M1 revision note.
- **S7a's "partial answer kept" check is vacuous** (`provider_anthropic_spec.lua:101`). `qt.response` starts as `""` (`lua/parley/dispatcher.lua:479`), so `out.qt.response ~= nil` is always true. A 600-byte cut of the ok stream contains exactly the first delta. **Fix:** `assert.equals("Hello,", out.qt.response)`.

**4. Minor findings**
- **S6 doesn't assert that splitting reached the reader.** I measured 79 reads against 1, but nothing pins that, and the plan's Risk said to measure it in Task 2; no measurement is logged. Count reader calls and assert more than 1.
- **No input validation in the fake.**
  - `behaviour` silently falls back to plain text for any unknown mode.
  - `fake_provider` doesn't check `--mode` at startup, so a bad `http_<x>` raises inside the handler and curl just sees an empty reply.
  - Validate both in argparse.
- **Scope gaps against the plan:**
  - The plan's `--split frames` mode isn't implemented.
  - S4 covers only 429, not 529 or 500.
  - Decision 2's "missing stop reason" has a unit check only, with no integration case.
  - The `http_<status>_once` mode has no consumer.
- **Weak vocabulary entry.** `'"stop_reason"'` (`tests/helpers/provider_vocabulary.lua:11`) also matches `message_start`'s `"stop_reason":null`. Use `'"stop_reason":"end_turn"'` or a `message_delta`-scoped needle.
- **Leftover state in the helper.** `provider_scenarios.query` registers a dummy vault secret and may create a `D.providers[p]` entry, and doesn't undo either.
- **Duplicated route.** The route table appears in both `fake_provider:28` and `provider_scenarios.lua:12`.
- **Traceability placement.** `provider_anthropic_spec.lua` is filed under `providers/architecture` rather than `providers/anthropic`.
- **Proof port.** `proof_run.lua:20` picks a random port without checking it is free.
- **Docs.** No atlas prose covers the new test-fake surface, and the plan defers it to M3 Task 11. That is acceptable at M1, but it should not slip past M3. No README surface is involved.

**5. Test coverage notes**
- Covered and passing in the real path: S1, S2, S4 (including no retry), S5, S6 and S7b.
- S3 and S7a are weaker than their titles claim, as above.
- The regression proofs were not re-run in this review, because they need `construct/generated/vocabulary/*.json` and two scratch worktrees. Their design is sound, though:
  - the #229 old-tree check is "LOG COMPLETE", not the plan's "later chunks consumed";
  - `handled=` is printed but not asserted.

**6. Architectural notes for upcoming work**
| Principle | Result |
|---|---|
| ARCH-DRY | pass (one dialect module; only the small route/constant duplication above) |
| ARCH-PURE | pass for structure, but the missing Task 2 spec leaves the pure core without direct tests |
| ARCH-PURPOSE | flagged, see the Important findings |
| ARCH-MOCK | pass for M1: a real process-level fake behind the production endpoint seam. Live conformance is scheduled for M3, and the vocabulary list is already shared for it |
| ARCH-CONSTRAINTS | pass (the 5 s envelope is asserted in S6) |
| ARCH-SECURE | pass (dummy keys only, isolated HOME/XDG for the proofs, a temp request log) |
| ARCH-ORDER | pass: production state is untouched, the fake's only counter (`served`) is scoped to `_once`, and the reply is chosen from the request |
| ARCH-FUNERAL | pass: the request log is deleted in `after_each`, and the worktrees and temp dir are removed by an EXIT trap. A SIGKILL would leave a worktree registered; `git worktree prune` recovers it |

For M2: give `fake_cliproxy` the same `ROUTES`/dialect lookup instead of a third route table. Also make `behaviour` take the dialect, because its `_has_tool_result` check is anthropic-specific today.

**7. Plan revision recommendations**
- Either deliver `tests/unit/fake_provider_spec.lua`, or add a "## Revisions" entry recording that Task 2's unit spec was folded into the integration specs, and why.
- Correct the M1-build revision note: the in-band error with text *is* logged, as a "TRUNCATED … in-band" warning. Only error-level notices are limited to empty responses.
- Record that the `frames` split mode and the S4 529/500 variants are deferred, or implement them.

```findings
findings:
  - id: new
    severity: Important
    kind: defect
    family: plan-item-undelivered
    title: |
      Task 2's tests/unit/fake_provider_spec.lua (behaviour table, split invariant, per-mode shell, request-log gating) is not delivered
    detail: |
      The plan's Task 2 names this spec and its four checks. The file does not exist at head, and no Revisions entry drops it, so the pure behaviour and split functions (sse_dialects.py:103,127) have no direct test (ARCH-PURPOSE, ARCH-PURE). Add the spec (pure checks via python3 -I, as sse_dialects_spec already does) or record a revision.
  - id: new
    severity: Important
    kind: defect
    family: test-oracle-bypasses-path
    title: |
      S3 asserts dispatcher._classify_ending directly instead of the user-visible in-band notice the dispatch path emits
    detail: |
      provider_anthropic_spec.lua:66 re-runs the classifier on qt, so it passes even if the dispatcher drops the report. In fact _ending_notice returns a warning-level 'answer is TRUNCATED ... in-band — Overloaded' (dispatcher.lua:362-370) that the dispatcher logs (:856-863). Assert out.warnings contains 'in-band — Overloaded', as S5 does, and correct the Log/plan note that claims nothing is logged.
  - id: new
    severity: Important
    kind: defect
    family: vacuous-assertion
    title: |
      S7a's 'partial answer kept' assertion cannot fail: qt.response starts as an empty string, never nil
    detail: |
      provider_anthropic_spec.lua:101 checks out.qt.response ~= nil, but dispatcher.lua:479 initializes response to "". The 600-byte cut contains exactly the first delta, so assert.equals('Hello,', out.qt.response).
  - id: new
    severity: Minor
    kind: defect
    family: vacuous-assertion
    title: |
      S6 does not assert that the byte split reached the reader; the vocabulary entry '"stop_reason"' also matches message_start's null field
    detail: |
      A probe measured 79 reader calls with every_byte against 1 with none, but the spec pins nothing, so curl coalescing would make S6 vacuous without anyone noticing. Count reader calls and assert more than 1, and tighten the stop_reason needle.
  - id: new
    severity: Minor
    kind: defect
    family: unvalidated-fake-config
    title: |
      fake_provider accepts any --mode: unknown modes silently serve text, and a malformed http_ mode raises inside the handler
    detail: |
      Validate --mode and --split at argparse time, so a typo fails loudly at startup instead of producing a passing ok stream or an empty reply.
  - id: new
    severity: Minor
    kind: defect
    family: plan-item-undelivered
    title: |
      The plan's --split frames mode, S4's 529/500 variants and an integration no_stop case are not delivered or recorded as deferred
```

<!-- sdlc-review-usage [{"version":1,"intent":{"disposable_root":true,"id":"6061256b-84ce-4528-8579-08bde2bd6fb2","repository":"github.com/xianxu/parley.nvim","issue_id":"000242","recipe":"milestone-review","round":1,"attempt":1,"agent":"claude","root":"/Users/xianxu/Library/Caches/sdlc/review-checkouts/634d322e8b7cda1d","reviewed_head":"ba0d3021074610bd8de5ad44097bc53c15bd8884","slot":"parley.nvim:4","requested_at":"2026-10-16T14:40:48.035655Z"},"phase":"finished","pid":9302,"started_at":"2026-10-16T14:40:48.188207Z","finished_at":"2026-10-16T14:43:35.481583Z","session_id":"0a2f26f5-caa1-4d9c-910a-7b14cd4c16cb","outcome":"returned"}] -->
