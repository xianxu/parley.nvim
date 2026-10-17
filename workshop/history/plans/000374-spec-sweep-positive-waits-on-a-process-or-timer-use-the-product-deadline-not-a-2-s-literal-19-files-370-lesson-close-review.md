# Boundary Review — parley.nvim#374 (whole-issue close)

| field | value |
|-------|-------|
| issue | 374 — Spec sweep: positive waits on a process or timer use the product deadline, not a 2 s literal (19 files; #370 lesson) |
| repo | parley.nvim |
| issue file | workshop/issues/000374-spec-sweep-positive-waits-on-a-process-or-timer-use-the-product-deadline-not-a-2-s-literal-19-files-370-lesson.md |
| boundary | whole-issue close |
| milestone | — |
| window | fcc6e18d062a99f7da6c823e9d3080342bdc5211..195b203c00f0b39c8e9007e9aa730b7c3e6dfcb8 |
| command | sdlc close --issue 374 |
| reviewer | claude |
| isolation | fenced |
| timestamp | 2026-10-17T04:40:36-07:00 |
| verdict | REWORK |

## Review

Reviewing the remaining literal waits in the issue's named files; nearly done.

```verdict
verdict: REWORK
confidence: high
```

The new pieces work: the shared budget (`tests/helpers/arrival.lua`), the rewrite of every `assert*(vim.wait(<literal>, …))` site, the hand conversions (the budget is passed as an RPC argument in `document_presentation_reentrant_spec.lua:144,162`, and interpolated into the child launcher source in `packaging_launcher_spec.lua:49`), and the atlas section. What blocks SHIP is that the sweep and the arch test only cover the one-line assert form. The most common positive-wait form in the files the issue names was left alone: a bare `vim.wait(2000, function() return done_result ~= nil end)` followed on the next line by `assert.is_not_nil(done_result, "on_done never ran")`. `define_spec` still has 7 of these 2 s waits and `skill_invoke_spec` has 6, and both files are on the issue's list of 19. So the first `## Done when` clause ("Each positive 2 s wait on a process or timer in those files uses the product deadline or the shared budget") is not met. The plan's "every positive wait's literal bound … becomes arrival.MS" is not true either, and the arch test can't see these waits, so new ones can be added.

1. **Strengths**
   - `tests/arch/arrival_budget_spec.lua:24-31` has a floor (`count >= 250`), so a pattern that stops matching fails instead of passing on zero sites. The mutation check described in the plan is a sensible way to prove the test works.
   - `packaging_launcher_spec.lua:49` caught and fixed a rewrite that reached into child source written out as a string. The Log records it as a lesson.
   - `document_presentation_reentrant_spec.lua:144` passes the budget into the child through RPC arguments rather than hard-coding it there, so the child derives from the single source.
   - The atlas section (`atlas/infra/test_harness.md:324-337`) states the rule, the `-- bound:` escape, the arch test's limit and the cost of slower failure reports.

2. **Critical findings**
   - **Positive waits written as a bare statement keep their literal bounds, including 2 s ones in the named files (ARCH-PURPOSE).** These are positive in substance: the next line asserts the arrived state, so under load they flake exactly like the assert form. Every instance of this family:
     - **2000 ms:**
       - `define_spec.lua`: lines 143, 160, 480, 760, 777, 791, 809
       - `skill_invoke_spec.lua`: lines 461, 546, 566, 604, 659, 698
       - `tasker_run_spec.lua`: line 334
       - `cliproxy_auth_spec.lua`: lines 734, 779
       - `clipboard_image_spec.lua`: lines 385, 402, 458
       - `cliproxy_recovery_e2e_spec.lua`: lines 81, 194
       - `cliproxy_login_spec.lua`: lines 72, 200
       - `cliproxy_conformance_spec.lua`: line 332 (line 143 is the declared out-of-scope 20 s wait)
     - **Other literals:**
       - `define_spec.lua`: 273, 304, 324 (500 ms)
       - `skill_invoke_spec.lua`: 585 (200 ms), 613 and 626 (500 ms)
       - `dispatcher_query_spec.lua`: 474 (100 ms)
       - `float_picker_spec.lua`: about 15 waits of 100–200 ms, at 512–1266
       - `clipboard_image_spec.lua`: 274–475 (300–3000 ms)
       - `cliproxy_catalog_spec.lua`: 45–443 (8000 ms)
       - `cliproxy_lifecycle_spec.lua`: 215–1248 (9000/15000 ms)
       - `unscoped_kill_spec.lua`: 363 (200 ms)

     **Fix:** use `arrival.MS` wherever a predicate wait is followed by an assertion on what it waited for. Simpler still, assert the wait itself (`assert.is_true(vim.wait(arrival.MS, …), "on_done never ran")`), which brings the site into the arch test's reach. Leave alone teardown drains (`vim.wait(100, function() return #T._handles==0 end)`) and `function() return false end` absence waits.

3. **Important findings**
   - **Positive waits assigned to a local and asserted later still use literals, yet the plan says only "the two" existed and were converted by hand.** Every instance:
     - `dispatcher_query_spec.lua:899` (100 ms; a named file)
     - `skill_invoke_spec.lua`: 200 (5000 ms), 377 and 414 (1000 ms; a named file)
     - `chat_stop_generation_spec.lua:128` (5000 ms)
     - `tool_result_evidence_spec.lua:26` (5000 ms)
     - `tool_process_scope_spec.lua:57` (10000 ms)
     - `cliproxy_lifecycle_spec.lua:1322` (3000 ms)
     - `fixture_reaping_spec.lua:62` (3000 ms)
     - `query_cache_spec.lua`: 115, 127 (500 ms)
     - `document_scheduler_spec.lua:19` (10000 ms)
     - `agentic_document_spec.lua:14` (10000 ms)
     - `tasker_run_spec.lua:676` (100 ms)

     `skill_invoke_spec.lua:377/414` fake `hrtime` before the wait, so a real-time bound there may matter; mark those `-- bound:` if so. **Fix:** convert these or give each a reason, and correct the plan's claim.
   - **The arch test can't see the two dominant forms of new literal positive waits.** `arrival_budget_spec.lua` only matches `assert*(vim.wait(` on one line, so neither form above can be refused, and the Done-when clause "A lint or arch test refuses a new literal positive `vim.wait(N, …)`" holds only for that form. **Fix:** also flag `vim.wait(<literal>, function` statements whose predicate isn't `return false`, and `local x = vim.wait(<literal>, …)`. Allow a `-- bound:` or `-- drain:` marker for legitimate teardown drains. Update the atlas sentence to match.

4. **Minor findings**
   - The plan's "275 sites in 93 files" count and the atlas's "Each one is bounded by…" overstate coverage once the bare forms are counted; restate them after the sweep.
   - `arrival_budget_spec.lua:16` skips only lines that start with a comment, so a literal inside a multi-line string, like the packaging child source, would be checked as code. That's harmless today.

5. **Test coverage notes**
   - I did not run the suite. The plan records `sdlc local-check` green on 236db111; head adds only plan edits on top of it.
   - The arch test's floor and mutation check are good evidence for the form it covers. The gap is the forms it doesn't cover (Important finding 2).

6. **Architectural notes**
   - **ARCH-DRY: pass.** There is one budget constant, and the child processes derive from it rather than restating it.
   - **ARCH-PURE: pass.** This is test-only code, and the arch test is a pure scan over files.
   - **ARCH-PURPOSE: flag.** The single source isn't enforced on every consumer: positive waits in bare-statement and local-assigned form, including waits in the issue's own named files, still restate literals, and the enforcement can't see them.

7. **Plan revision recommendations**
   - Add to `## Revisions`: "The assert-form sweep left bare-statement and local-assigned positive waits; they were swept in <round>, and the arch test was extended to the bare and local forms (or their limits documented)." Then correct "The two waits assigned to a local first" and the 275/93 count.

```findings
findings:
  - id: new
    severity: Critical
    kind: defect
    family: positive-wait-literal-bound
    title: |
      Bare-statement positive waits keep literal bounds, including 2 s waits in the issue's named files
    detail: |
      define_spec.lua:143,160,480,760,777,791,809 and skill_invoke_spec.lua:461,546,566,604,659,698 still have vim.wait(2000, pred) followed by an assert on the waited state, so Done-when clause 1 is unmet. Same family, other 2000 ms sites: tasker_run:334, cliproxy_auth:734,779, clipboard_image:385,402,458, cliproxy_recovery_e2e:81,194, cliproxy_login:72,200, cliproxy_conformance:332. Other literals: define:273,304,324; skill_invoke:585,613,626; dispatcher_query:474; float_picker 512-1266; clipboard_image 274-475; cliproxy_catalog 45-443; cliproxy_lifecycle 215-1248; unscoped_kill:363. Use arrival.MS, ideally asserting the wait itself; leave teardown drains and return-false absence waits alone.
  - id: new
    severity: Important
    kind: defect
    family: positive-wait-literal-bound
    title: |
      Local-assigned positive waits keep literals, though the plan says only two existed and both were converted
    detail: |
      Unconverted: dispatcher_query:899, skill_invoke:200,377,414, chat_stop_generation:128, tool_result_evidence:26, tool_process_scope:57, cliproxy_lifecycle:1322, fixture_reaping:62, query_cache:115,127, document_scheduler:19, agentic_document:14, tasker_run:676. Convert each or mark it '-- bound: <reason>' (skill_invoke:377/414 fake hrtime, so the bound may matter there), and correct the plan's claim.
  - id: new
    severity: Important
    kind: defect
    family: arch-rule-reach
    title: |
      Arch test only sees one-line assert forms, so new bare or local literal positive waits pass
    detail: |
      tests/arch/arrival_budget_spec.lua FORMS match only assert*(vim.wait( on one line; the bare vim.wait(N, function ...) statement and local x = vim.wait(N, ...) forms escape it. Extend the scan to those forms (excluding return-false predicates, with a drain or bound marker for teardown drains), and update the atlas reach sentence.
  - id: new
    severity: Minor
    kind: defect
    family: doc-claim-from-memory
    title: |
      Plan and atlas overstate coverage ("every positive wait", 275 sites in 93 files)
    detail: |
      Restate the counts and the atlas claim "Each one is bounded by arrival.MS" after the bare and local forms are swept.
```

<!-- sdlc-review-usage [{"version":1,"intent":{"disposable_root":true,"id":"c08f53cd-b76e-49e2-a6cb-d58aab6f450e","repository":"github.com/xianxu/parley.nvim","issue_id":"000374","recipe":"small-diff-review","round":1,"attempt":1,"agent":"claude","root":"/Users/xianxu/Library/Caches/sdlc/review-checkouts/b35dd15abe443f61","reviewed_head":"195b203c00f0b39c8e9007e9aa730b7c3e6dfcb8","slot":"parley.nvim:3","requested_at":"2026-10-17T11:38:51.589203Z"},"phase":"finished","pid":77938,"started_at":"2026-10-17T11:38:51.868497Z","finished_at":"2026-10-17T11:40:35.393212Z","session_id":"0fd3f54c-aedb-4405-82a1-54079d340fd0","outcome":"returned"}] -->

---

## Re-review — 2026-10-17T05:12:29-07:00 (FIX-THEN-SHIP)

| field | value |
|-------|-------|
| issue | 374 — Spec sweep: positive waits on a process or timer use the product deadline, not a 2 s literal (19 files; #370 lesson) |
| repo | parley.nvim |
| issue file | workshop/issues/000374-spec-sweep-positive-waits-on-a-process-or-timer-use-the-product-deadline-not-a-2-s-literal-19-files-370-lesson.md |
| boundary | whole-issue close |
| milestone | — |
| window | fcc6e18d062a99f7da6c823e9d3080342bdc5211..5090035e83e51b875ad3051932a743e5ce3aa88a |
| command | sdlc close --issue 374 |
| reviewer | claude |
| isolation | fenced |
| timestamp | 2026-10-17T05:12:29-07:00 |
| verdict | FIX-THEN-SHIP |

## Review

Remaining literal waits are down to 25, all marked. Now checking that the markers are honest and the named sites were converted.

Checking the named-constant bounds (SETTLE_MS, `ms or 3000`) that slip past the arch test's literal match.

Now running the arch test, plus a mutation check of the wrapper-default gap.

Arch test passes. Now the mutation: does a wrapper with a literal default, like paste_image's, get through?

Mutation confirmed: a literal default in a wait wrapper gets past the arch test. I'll run the full suite next to check the "suite green" claim.

The suite fails here. Checking whether the failures are environmental or caused by #374.

Most failures come from the review checkout's TMPDIR sitting inside the repo tree. One exception: `open_reference_spec` is a file this diff touched, so I'm checking that one specifically.

```verdict
verdict: FIX-THEN-SHIP
confidence: high
```

Round 2 fixed what round 1 found. The bare and local-assigned positive waits named in BR-1 and BR-2 now use `arrival.MS`, including the `define_spec`/`skill_invoke_spec` 2 s waits from Done-when clause 1. Every remaining direct literal wait in `tests/unit` and `tests/integration` has an honest reason marker: I counted 25 (11 absence, 11 drain, 3 bound) and read what follows each one. The arch test now reads every line that opens a `vim.wait(<literal>, <pred>)`, and it passes. One gap is left in the same class, and I confirmed it by mutation. A literal that reaches the bound through a variable or a default (`vim.wait(ms or 3000, …)`, `vim.wait(ms, …)` with literal callers) still gets past the arch test. That covers two existing positive process waits: `paste_image_spec`'s 3 s `wait_for` (20 callers, waiting on a spawned `fake_clipboard`) and `fixture_reaping_spec`'s `dies_within(pid, 6000, …)` (7 callers). It is cheap to fix and doesn't block shipping.

Done-when: current — every clause still holds against the diff. The widening to every literal wait in unit and integration specs is a strict superset of clause 1/2, and it is recorded under `## Revisions`; it doesn't change what "done" means.

1. **Strengths**
   - `tests/arch/arrival_budget_spec.lua:19-31`: the scan reads every line that opens a wait, whatever its form. It exempts `return false` sleeps, and the floor of ≥400 stops a pattern that silently stops matching from passing vacuously.
   - The reason vocabulary (`absence:` / `drain:` / `bound:`) is honest at every one of the 25 sites. I checked the line after each absence wait (e.g. `skill_invoke_spec.lua:585-586`, `cliproxy_login_spec.lua:72-73`, `drill_in_transaction_spec.lua:58-59`): each asserts the predicate stayed false. The reclassification of `cliproxy_login` 72/200 as absence checks is correct.
   - The `bound:` sites are real properties: `skill_invoke` 377/414 run on faked hrtime, and `query_cache:115` is the SIGTERM grace before SIGKILL.
   - Every file that uses `arrival.MS` requires the helper (0 missing). Code a spec writes for a child Neovim takes the budget by value (the `' .. arrival.MS .. '` site).

2. **Critical findings:** none.

3. **Important findings**
   - **Literal bounds hidden behind a variable or default escape the arch rule** (family `arch-rule-reach`, 2nd finding; the sites themselves are also instances of `positive-wait-literal-bound`).
     - Sites: `tests/integration/paste_image_spec.lua:42` (`vim.wait(ms or 3000, pred, 20)`, 20 positive callers on a spawned process) and `tests/integration/fixture_reaping_spec.lua:36` (`vim.wait(ms, …)`, callers at 46/63/78/87/95/103/109 pass a literal `6000`).
     - Full enumeration of non-literal bounds in scope: `ms or 3000` (1), `ms` (1), `budget` (1, already derived from `arrival.MS`), `SETTLE_MS` (product `recovery_timeout_ms`, fine), `ci.TIMEOUT_MS + 500` (product, fine), `arrival_ms(` (session_sync, fine). So exactly two sites leak.
     - Mutation check: I appended `local function wf(p, ms) return vim.wait(ms or 2000, p, 20) end` to `outline_spec`, and the arch test still passed 2/2.
     - **Rule to fix, rather than the two instances:** make the scan an allowlist instead of a literal denylist. A wait bound must be `arrival.MS`-derived, a named product or config deadline, or carry a reason marker. Any other expression, including a bare parameter or an `x or N` default, needs a marker or must derive.
     - Then convert `paste_image`'s default to `arrival.MS`, and either convert `dies_within`'s callers or mark them `-- bound:` if 6 s is the reaping property.
     - Update the atlas sentence "enforces it for every form" to match.

4. **Minor findings**
   - `tests/helpers/arrival.lua:15` hardcodes `M.MS = 15000` instead of reading `agentic_submit_timeout_ms` from `lua/parley/config.lua:501`. If the config default changes, the budget silently drifts from the source it claims (ARCH-DRY).
   - `arrival.lua:4` and `atlas/infra/test_harness.md` call 15 s "the product's longest round-trip deadline". That isn't true: `agentic_document.lua:322` uses `3 * agentic_submit_timeout_ms`, and the sweep itself needed `2 * arrival.MS` for six waits (family `doc-claim-from-memory`, 2nd finding). The rule for both doc fixes: write the claim from the code (a grep of `_timeout_ms` uses), not from memory. Reword it to "the agentic submit deadline".

5. **Test coverage notes**
   - Arch test: 2/2 green in the harness env.
   - Full `make test` in this review checkout: 30 failing cases, all environmental. They are scratch-outside-repo, starter, zero_config and `open_reference` D1, because the review checkout's TMPDIR is inside the repo tree. `open_reference_spec` fails identically with the base version of the file (2 failures, 59 pass), and its failure is at line 98, not the changed line 525.
   - I didn't re-measure the plan's "local-check green, 4m5s" claim on the implementor's host.

6. **Architectural notes**
   - **ARCH-DRY:** flag (Minor) — `arrival.MS` restates the config default instead of reading it.
   - **ARCH-PURE:** pass — the diff is test-only, and the arch test is a pure scan over files.
   - **ARCH-PURPOSE:** flag (Important) — enforcement covers the literal but not a literal that reaches the bound indirectly. Fixing the rule closes the class, rather than adding one more form.

7. **Plan revision recommendations**
   - In the round-2 entry, qualify the claim that the arch test reads "every `vim.wait(<literal>, <predicate>)` whatever its form". After the allowlist fix, restate it as "every wait bound", and record the paste_image and fixture_reaping sites.

```findings
dispose:
  - id: BR-1
    disposition: addressed
    note: |
      define_spec 143/273 and skill_invoke sites now use arrival.MS; only 25 direct literal waits remain, all marked, and I verified the line after each. cliproxy_login 72/200 are correctly absence checks.
  - id: BR-2
    disposition: addressed
    note: |
      dispatcher_query 899, chat_stop_generation 128, fixture_reaping 62, tasker_run 676, cliproxy_lifecycle 1322 use arrival.MS; skill_invoke 377/414 and query_cache 115 carry honest bound markers; the plan's round-2 entry retracts the "only two" claim.
  - id: BR-3
    disposition: addressed
    note: |
      The scan now reads every line that opens a wait (bare, local, asserted). Arch test passes 2/2; the remaining reach gap (a literal through a variable or default) is a different form, raised separately.
  - id: BR-4
    disposition: addressed
    note: |
      Plan Revisions now states that 275/93 covered only the assert form, and the round-2 counts (158/11/11/3) match the 25 marked literals I counted. The leftover atlas overstatement is folded into the new reach finding.
findings:
  - id: new
    severity: Important
    kind: defect
    family: arch-rule-reach
    title: |
      Literal wait bounds hidden behind a variable or default escape the arch rule (paste_image 3 s, fixture_reaping 6 s)
    detail: |
      paste_image_spec.lua:42 waits vim.wait(ms or 3000, pred) on a spawned fake_clipboard (20 positive callers), and fixture_reaping_spec.lua:36 waits vim.wait(ms, ...) with callers at 46/63/78/87/95/103/109 passing 6000. Mutation: a `vim.wait(ms or 2000, p)` wrapper appended to outline_spec still passes the arch test. Every non-literal bound in scope: ms or 3000, ms, budget (arrival-derived), SETTLE_MS and ci.TIMEOUT_MS (product), arrival_ms (session_sync), so these two sites are the whole leak. Also a 3rd instance of positive-wait-literal-bound. The rule to fix: allowlist the bound expression (arrival.MS-derived, a named product deadline, or a reason marker) instead of only denying a digit literal. Then convert or mark the two sites and reword the atlas line "enforces it for every form".
  - id: new
    severity: Minor
    kind: defect
    family: doc-claim-from-memory
    title: |
      arrival.MS is hardcoded to 15000 and described as the product's longest deadline, which it is not
    detail: |
      tests/helpers/arrival.lua:15 restates config.lua:501 agentic_submit_timeout_ms instead of reading it (ARCH-DRY). Both arrival.lua:4 and atlas/infra/test_harness.md call it "the product's longest round-trip deadline", but agentic_document.lua:322 uses 3x that value and the sweep needed 2 * arrival.MS for six waits. Read the config value, and write the claim from the code (a grep of _timeout_ms uses).
```

<!-- sdlc-review-usage [{"version":1,"intent":{"disposable_root":true,"id":"50a82fed-553f-4804-ad3d-dbd46e137a79","repository":"github.com/xianxu/parley.nvim","issue_id":"000374","recipe":"small-diff-review","round":2,"attempt":1,"agent":"claude","root":"/Users/xianxu/Library/Caches/sdlc/review-checkouts/722f70522434ed68","reviewed_head":"5090035e83e51b875ad3051932a743e5ce3aa88a","slot":"parley.nvim:3","requested_at":"2026-10-17T12:03:43.712555Z"},"phase":"finished","pid":22397,"started_at":"2026-10-17T12:03:43.808955Z","finished_at":"2026-10-17T12:12:12.750664Z","session_id":"52c9f070-e6f8-4380-98cd-5f5c28d8eb60","outcome":"returned"}] -->

---

## Re-review — 2026-10-17T05:17:48-07:00 (SHIP)

| field | value |
|-------|-------|
| issue | 374 — Spec sweep: positive waits on a process or timer use the product deadline, not a 2 s literal (19 files; #370 lesson) |
| repo | parley.nvim |
| issue file | workshop/issues/000374-spec-sweep-positive-waits-on-a-process-or-timer-use-the-product-deadline-not-a-2-s-literal-19-files-370-lesson.md |
| boundary | whole-issue close |
| milestone | — |
| window | fcc6e18d062a99f7da6c823e9d3080342bdc5211..354e4d8e2e5f3c8870fbf6e828b5bf554d304b4a |
| command | sdlc close --issue 374 |
| reviewer | claude |
| isolation | fenced |
| timestamp | 2026-10-17T05:17:48-07:00 |
| verdict | SHIP |

## Review

Checking the round-3 fixes; next I'll run the arch spec and do a quick mutation test.

Locating the arch-spec runner so I can run it and the mutation check.

The test harness refuses direct runs, so I'm emulating the `derived()` rule in plain Lua for the mutation check.

```verdict
verdict: SHIP
confidence: high
```

Round 3 fixes both open findings, and I checked each against the code, not the commit messages. For BR-5, the arch rule in `tests/arch/arrival_budget_spec.lua` used to block only bare number bounds. It now accepts a bound only if it comes from `arrival` or names an `_MS` deadline, so the reviewer's mutation `vim.wait(ms or 2000, p)` is now refused. The two sites that leaked are converted: the `paste_image` default and the `fixture_reaping` 6 s helper. For BR-6, `arrival.MS` now reads `parley.config`'s `agentic_submit_timeout_ms` instead of restating 15000, and both the helper and the atlas dropped the false "longest deadline" claim. One Minor gap remains, and it does not block: the rule accepts any bound whose text contains the substring "arrival", which is wider than the atlas's "only".

I could not run the arch spec itself. Its startup check refuses any run where `PARLEY_TEST_ENV_ROOT` is unset (#342) and says to use `make`. Instead I copied its `derived()` function into a standalone Lua script and ran the mutation inputs through it: `ms or 2000` → refused, `2000` → refused, `FOO_MS or 2000` → refused, `arrival.MS` / `2 * arrival.MS` / `SETTLE_MS` / `ci.TIMEOUT_MS + 500` → accepted. The old rule (`^[%d_]+$`) would have accepted `ms or 2000`, so the regression test does fail without the fix.

Done-when: current. The arch rule still enforces the second clause ("refuses a new literal positive `vim.wait(N, ...)`… naming the helper"), and now covers more ground: unit and integration specs, and bounds that hide behind a parameter or a default. The first and third clauses did not change this round.

1. **Strengths**
   - `tests/arch/arrival_budget_spec.lua:33` lists the bounds it accepts instead of the ones it rejects. That is the general fix for the `arch-rule-reach` family, not one more patched case.
   - `tests/helpers/arrival.lua:17` gets the value from the config, so the budget and the product deadline cannot drift apart (ARCH-DRY).
   - `fixture_reaping_spec.lua:35` drops a 6 s value that was only a guess. The test now checks what it is meant to check (the process dies once its parent is gone), with the shared budget as the timeout.
   - The atlas now names its own limit: the rule "cannot follow a literal passed into a helper's parameter from a call site". I grepped for that case and found no live instance.
   - The doc claims check out against the code: the six `2 * arrival.MS` sites exist, and `agentic_document.lua:322` uses `3 *` the deadline.

2. **Critical:** none.

3. **Important:** none.

4. **Minor**
   - `arrival_budget_spec.lua:34` accepts any bound containing the text "arrival". That lets through `arrival_ms or 2000`, and also `math.min(arrival.MS, 2000)` (the capture stops at the comma, leaving `math.min(arrival.MS`). This is the 3rd finding in family `arch-rule-reach`; the class-level fix is in the findings block below.

5. **Test coverage:** the floor of at least 400 matched waits keeps the rule from passing vacuously. I checked the bounds by hand: every remaining number bound is either a sleep (a `return false` predicate) or has an `-- absence:`, `-- drain:` or `-- bound:` reason. The other bounds are `SETTLE_MS`, `ci.TIMEOUT_MS + 500`, `arrival_ms`, and `ms or arrival.MS`. No spec splits a wait's bound onto the line after `vim.wait(`.

6. **Architecture**
   - **ARCH-DRY:** pass. BR-6 removed the restated 15000.
   - **ARCH-PURE:** pass. These are test-only changes.
   - **ARCH-PURPOSE:** pass. The rule now covers the whole class (bare, assigned, asserted, defaulted, parameterised), and the one remaining gap (call-site literals) is documented.

7. **Plan revisions:** none needed beyond the Minor item. If it is fixed, reword the atlas's "only when it derives from `arrival`" to list the exact forms.

```findings
dispose:
  - id: BR-5
    disposition: addressed
    note: |
      derived() at arrival_budget_spec.lua:33 accepts only bounds that derive from arrival or name an _MS deadline; I ran derived() standalone and `ms or 2000` is refused, while the old ^[%d_]+$ rule would have accepted it; paste_image:43 and fixture_reaping:36 now use arrival.MS.
  - id: BR-6
    disposition: addressed
    note: |
      arrival.lua:17 reads require("parley.config").agentic_submit_timeout_ms, which is a top-level key of the returned table (config.lua:501); the "longest deadline" claim is gone from the helper and from atlas/infra/test_harness.md:329.
findings:
  - id: new
    severity: Minor
    kind: defect
    family: arch-rule-reach
    title: |
      derived() accepts any bound whose text contains "arrival", so `arrival_ms or 2000` and `math.min(arrival.MS, 2000)` pass
    detail: |
      This is the 3rd finding in family arch-rule-reach. The fix is a rule for the whole class, not this one site: accept a bound only when the WHOLE expression matches one of the allowed forms, anchored at both ends: ^arrival%.MS$, ^%d+%s*%*%s*arrival%.MS$, ^arrival_ms$ (a child process's by-value copy), ^[%w_.]*_MS[%s%d+*]*$, or `<param> or arrival.MS`. Anything else needs a reason marker. Evidence: I ran derived() standalone; `arrival_ms or 2000` → true, and `math.min(arrival.MS` (the capture stops at the comma) → true. No live instance in the tree today. The atlas line "allows a bound only when it derives from arrival" (test_harness.md:337) overstates the rule until it is anchored. Instances in this window: just this one predicate (arrival_budget_spec.lua:34).
```

<!-- sdlc-review-usage [{"version":1,"intent":{"disposable_root":true,"id":"73ec1b4d-66e0-46fd-a423-5e30b04e9511","repository":"github.com/xianxu/parley.nvim","issue_id":"000374","recipe":"small-diff-review","round":3,"attempt":1,"agent":"claude","root":"/Users/xianxu/Library/Caches/sdlc/review-checkouts/18de00bbbb01d4dd","reviewed_head":"354e4d8e2e5f3c8870fbf6e828b5bf554d304b4a","slot":"parley.nvim:3","requested_at":"2026-10-17T12:16:08.628053Z"},"phase":"finished","pid":68321,"started_at":"2026-10-17T12:16:08.868012Z","finished_at":"2026-10-17T12:17:48.046072Z","session_id":"fc8fb5bc-6c20-4eff-9d6e-249810ca5bc8","outcome":"returned"}] -->
