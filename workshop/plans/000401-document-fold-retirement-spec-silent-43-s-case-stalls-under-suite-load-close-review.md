# Boundary Review — parley.nvim#401 (whole-issue close)

| field | value |
|-------|-------|
| issue | 401 — document_fold_retirement_spec: silent 43 s case stalls under suite load |
| repo | parley.nvim |
| issue file | workshop/issues/000401-document-fold-retirement-spec-silent-43-s-case-stalls-under-suite-load.md |
| boundary | whole-issue close |
| milestone | — |
| window | 7c99d689403ce315f1eca1dc5f5ba1924ac8d167..c676e97c0e62e3c2dd6b8aad947c979d8bd1ff59 |
| command | sdlc close --issue 401 |
| reviewer | claude (anthropic; author anthropic) |
| isolation | checkout |
| timestamp | 2026-10-19T18:25:00-07:00 |
| verdict | FIX-THEN-SHIP |

## Review

I'm running the new helper and retirement specs to check their behavior.

I'm setting up the repo's test environment so I can run the four specs directly.

Both retirement specs pass in about 1 s. Next I'm confirming they fail when the threshold override is removed.

The red check holds. One last run of the helper's own spec.

```verdict
verdict: FIX-THEN-SHIP
confidence: high
```

The change does what #401 asked for, and I confirmed it by running the specs. Every spec that drives a child nvim now goes through the new `tests/helpers/embedded_nvim.lua`, which puts a time limit on each request. I found no raw `rpcrequest` or `--embed` spawn left in `tests/` or `lua/`, and an arch spec now blocks new ones. Both retirement specs pass in about 1 s each. With `F.INTERACTIVE_ROWS=500` removed, both fail with "did not suspend", so the small fixtures still exercise suspension. The helper spec, arch spec, `spec_runner_spec` and `document_lease_spec` all pass. One cheap thing should be fixed before shipping. The Plan says `start()` "appends the repo to the child's runtimepath", but the helper doesn't do that. Every caller that needs it still writes that step out itself, so the plan claims something the code doesn't deliver, and the step is copied across files. The rest are Minor.

1. **Strengths**
   - `tests/helpers/embedded_nvim.lua:20-35`: when a request runs out of time, a libuv timer kills the child by pid. The pending `rpcrequest` then fails on the closed channel, and the error names the method, the time limit and the pid. This avoids `jobstop`, which isn't allowed inside that callback. The helper spec covers this path with a busy child and a 500 ms limit, and checks that the child is reaped.
   - All nine specs moved onto the helper in the same change, and `tests/arch/embedded_rpc_spec.lua` blocks new raw calls. That fixes the whole class of unbounded requests, not just the one spec in the issue (ARCH-PURPOSE passes).
   - `lua/parley/tool_folds.lua:71`: `INTERACTIVE_ROWS` became a module field that is read each time it's used. All three uses were switched, and the default stays 50,000, so the real threshold is still covered by the batches and perf specs.
   - The two retirement specs were also removed from `spec_runner`'s 180 s list, and `tests/unit/spec_runner_spec.lua` now asserts they get the default budget.

2. **Critical:** none.

3. **Important**
   - **The Plan says the helper sets the runtimepath, but it doesn't, and every caller still does it (ARCH-DRY):** the Plan says `start()` appends the repo to the child's runtimepath, but `M.start` (`tests/helpers/embedded_nvim.lua:54-62`) never does. These callers still do it themselves:
     - `document_fold_retirement_spec.lua:7`
     - `document_fold_uncertainty_retirement_spec.lua:7`
     - `document_presentation_reentrant_spec.lua:8`
     - `document_move_spec.lua:423`
     - `document_lease_spec.lua:16`
     - `entity_navigation_native_spec.lua:28`
     - `session_sync_native_spec.lua:100` and `:683`
     - `stream_view_spec.lua:11`, which uses `prepend` instead of `append`

     **Fix:** either add a `runtime` option to `start` (`'append'`/`'prepend'`, or default to `append`) and delete the per-spec lines, or add a `## Revisions` entry saying `start` does not touch the runtimepath.

4. **Minor**
   - **`start` can leak a child:** if `nvim_ui_attach` raises inside `M.start`, the child was already spawned, but `start` never returns it, so the caller's `after_each` can't stop it. Before this change, `child` was assigned before the attach, so cleanup could reach it. **Fix:** wrap the attach in `pcall`, stop the child on failure, then re-raise.
   - **The arch guard is easy to get around:** its pattern only catches `rpcrequest(`, so `pcall(vim.rpcrequest, …)` and `rpcnotify` slip through. Its count of nine users includes the arch spec itself and `embedded_nvim_spec.lua` (11 matches today), so two real users could disappear without the check noticing.
   - **Done-when asks for a margin measured under suite load:** the log measures each spec run alone (1–2 s). Against a 50 s budget the margin is clearly large, but no number under load was recorded.
   - **Comments still hardcode 50k:** `tool_folds.lua:19` ("The >50k-row paths…") and `:263` ("At most 50k affected rows…") now restate the field's default value instead of naming `INTERACTIVE_ROWS`.
   - **Small timer race in `Child:request`:** if the child answers just as the timer fires, the request reports a kill even though it succeeded. This is unlikely at 60 s.

5. **Test coverage notes:** I ran the four new or changed core specs plus `spec_runner_spec` and `document_lease_spec`: all green, each in about 1 s. I reverted the threshold override in both retirement specs and they went red, then restored the checkout (`git status` is clean). The helper's time-limit path is tested with an injected `REQUEST_MS`. The other swept specs (`document_move`, `session_sync_native`, `entity_navigation_native`, `stream_view`, `document_fold_native`, `document_presentation_reentrant`) were not re-run by me; the implementer's log says their targeted runs were green.

6. **Architectural notes:**
   - ARCH-DRY: flagged once (the runtimepath setup above). Otherwise the helper is the single way specs drive a child nvim.
   - ARCH-PURE: passes. This is a test-only IO helper, and the product change is a one-field visibility change.
   - ARCH-PURPOSE: passes. The class was swept and is now enforced by the arch spec.
   - ARCH-EVOLVE: passes, not applicable. No persisted formats changed.

7. **Plan revision recommendations:** unless the helper takes over the runtimepath setup, add a `## Revisions` entry: "`start()` does not modify the child's runtimepath; callers append or prepend the repo themselves."

```findings
findings:
  - id: new
    severity: Important
    kind: defect
    family: helper-owns-shared-setup
    title: |
      embedded_nvim.start does not set the runtimepath as the Plan claims; nine call sites still restate it
    detail: |
      The Plan says start() "appends the repo to the child's runtimepath", but M.start (tests/helpers/embedded_nvim.lua:54-62) never touches it (ARCH-DRY, plan drift). Instances: document_fold_retirement_spec.lua:7, document_fold_uncertainty_retirement_spec.lua:7, document_presentation_reentrant_spec.lua:8, document_move_spec.lua:423, document_lease_spec.lua:16, entity_navigation_native_spec.lua:28, session_sync_native_spec.lua:100 and :683, stream_view_spec.lua:11 (prepend). Fix: add a runtime option to start and delete the per-spec lines, or add a Revisions entry.
  - id: new
    severity: Minor
    kind: defect
    family: spawned-child-ownership
    title: |
      Embedded.start leaks the spawned child if nvim_ui_attach raises
    detail: |
      The child is spawned before the attach, but start never returns it on failure, so the caller's after_each cannot stop it. Before this change the spec held the job id before attaching. Fix: pcall the attach, stop the child, then re-raise.
  - id: new
    severity: Minor
    kind: defect
    family: arch-guard-coverage
    title: |
      Arch guard misses pcall(vim.rpcrequest, ...) and rpcnotify; its user floor counts itself and the helper spec
    detail: |
      RAW only matches "rpcrequest(" and quoted "--embed". The users floor of 9 currently counts 11 files, including tests/arch/embedded_rpc_spec.lua and tests/integration/embedded_nvim_spec.lua, so two real users could disappear unnoticed.
  - id: new
    severity: Minor
    kind: defect
    family: done-when-both-states
    title: |
      Done-when asks for a margin measured under suite load; only run-alone times were logged
    detail: |
      The log records 1-2 s per spec run alone on both runtimes. No timing under parallel suite load was recorded, though the margin against the 50 s budget is plainly large.
  - id: new
    severity: Minor
    kind: defect
    family: comment-restates-constant
    title: |
      tool_folds comments still hardcode 50k instead of naming INTERACTIVE_ROWS
    detail: |
      lua/parley/tool_folds.lua:19 and :263 restate the field's default value as a fixed number now that a spec can change it.
```

<!-- sdlc-review-usage [{"version":1,"intent":{"disposable_root":true,"id":"2ef97936-8c5b-470d-be8c-a555a1167992","repository":"github.com/xianxu/parley.nvim","issue_id":"000401","recipe":"small-diff-review","round":1,"attempt":1,"agent":"claude","root":"/Volumes/TestScratch/review-checkouts/f529fa537503d4c9","reviewed_head":"c676e97c0e62e3c2dd6b8aad947c979d8bd1ff59","slot":"parley.nvim:3","requested_at":"2026-10-20T01:23:16.664057Z"},"phase":"finished","pid":28415,"started_at":"2026-10-20T01:23:16.751915Z","finished_at":"2026-10-20T01:25:00.232673Z","session_id":"4a1286f6-da49-41b9-8ae2-e5d80c370fcc","outcome":"returned"}] -->

---

## Re-review — 2026-10-19T18:38:17-07:00 (REWORK)

| field | value |
|-------|-------|
| issue | 401 — document_fold_retirement_spec: silent 43 s case stalls under suite load |
| repo | parley.nvim |
| issue file | workshop/issues/000401-document-fold-retirement-spec-silent-43-s-case-stalls-under-suite-load.md |
| boundary | whole-issue close |
| milestone | — |
| window | 7c99d689403ce315f1eca1dc5f5ba1924ac8d167..08c40cc09b69f2eb922f80eedc31c87ee3de2c99 |
| command | sdlc close --issue 401 |
| reviewer | claude (anthropic; author anthropic) |
| isolation | checkout |
| timestamp | 2026-10-19T18:38:17-07:00 |
| verdict | REWORK |

## Review

I'm checking the prior-round fixes and testing whether the helper's 60 s request bound fires before the runner's 50 s idle kill.

Confirmed: under normal load, the runner kills a wedged child at 50 s, before the helper's 60 s bound fires. Next I'm checking the remaining prior findings.

```verdict
verdict: REWORK
confidence: high
```

The helper sweep is in good shape. All nine specs now drive their child through `tests/helpers/embedded_nvim.lua`, the arch guard catches the forms round 1 named, and both retirement specs now take about 2 s. One problem blocks shipping: the issue's second Done-when clause ("a wedged embedded child fails the case with a named cause, not a harness kill") does not hold on a quiet machine. The helper's request bound is `REQUEST_MS = 4 × arrival.MS` = 60 s. Every spec that uses the helper runs on the runner's default budget of 50 s × load factor. The two retirement specs only joined that budget in this same change, which removed them from the 180 s list. So when the load factor is below 1.2, the runner kills the spec before the helper's bound can fire. I ran a temporary spec whose child spins forever (`zz_wedge_probe_spec.lua`, deleted afterwards) through the real runner at load 10 on 12 CPUs. The result was `DEADLINE: … stalled after 0 completed case(s); idle 50000ms`, with no method named. That is exactly the silent harness kill this issue was opened to remove.

**1. Strengths**
- `tests/helpers/embedded_nvim.lua:20-35`: the libuv timer kills the child by pid (`uv.kill`), because `jobstop` is not allowed in that callback, and the pending request is then failed. This is sound and has a test (`embedded_nvim_spec.lua:19-31`).
- ARCH-DRY: there is now one place that spawns and drives a child, nine near-identical setup blocks are gone, and `start()` puts the repository on the child's runtimepath. No restatement is left except the `rtp = "prepend"` option for `stream_view`.
- The arch guard really goes red. I appended `pcall(vim.rpcrequest, 0, "x")` to `stream_view_spec.lua` and it failed, naming the line. The user floor excludes the guard and the helper spec, so it counts exactly the 9 real users.
- `tool_folds.INTERACTIVE_ROWS` as a module field lets the retirement specs cross the threshold with a 1,210-line fixture. The log says that removing the override makes both cases fail with 'did not suspend', so the small fixture still tests suspension. I re-ran both specs at load about 11 on 12 CPUs: 2 s each, green.

**2. Critical findings**
- **The helper's bound (60 s) is longer than the runner's idle budget on a quiet machine (50 s), so a wedged child still dies by harness kill with no cause** (`tests/helpers/embedded_nvim.lua:12`, against `tests/helpers/spec_runner.lua:22` and `spec_deadline.lua:27,34`).
  - **Instances of the same class:**
    - The header comment at `embedded_nvim.lua:1-4` says "well before the harness's idle kill (180 s)".
    - `embedded_nvim.lua:9-10` says "named long before the idle kill".
    - `atlas/infra/test_harness.md:296-297` says "well before the runner's idle kill".
    - The Plan says "named well before the 180 s idle kill".
    - All 9 helper users are on the 50 s default budget; none of the 180 s specs use the helper.
  - **Fix:** derive the bound from the deadline it has to beat. The runner can pass its idle budget to the spec child, for example through an environment variable. The helper then sets `REQUEST_MS` to a fraction of it, about ½, which leaves room for the case's earlier work.
  - **Tests:** add a test that pins `REQUEST_MS` below the runner's idle budget at load factor 1. Also add a `spec_runner.execute` test that runs a fixture spec whose child spins forever and asserts the output names `nvim_exec_lua`, not `DEADLINE`.
  - **Docs:** correct the comments, the atlas text and the Plan.

**3. Important findings**
- None.

**4. Minor findings**
- Comments in the helper restate the value of a constant instead of naming it. This is the 2nd finding in family `comment-restates-constant`.
  - **Rule:** a comment names the source of a value (field, function, runner option), never the value itself.
  - **Instances:** `embedded_nvim.lua:3` "(180 s)", which is also wrong for these specs, and `embedded_nvim.lua:9` "(at most 4)", which restates the cap in `Deadline.load_factor`.
  - **Checked and fine:** the "(nine specs on 2026-10-19)" in the arch spec is dated, so it is not a restatement.

**5. Test coverage notes**
- The helper's timeout test only runs with an injected 500 ms bound. Nothing checks the real `REQUEST_MS` against the real runner budget, and that gap is how the Critical finding shipped.
- BR-2's fix (stopping the child when setup fails) has no test. No test sends a setup that fails, such as a bad `nvim_ui_attach`, and checks the child is reaped.

**6. Architectural notes**
- **ARCH-DRY: pass.** One helper with nine users.
- **ARCH-PURE: pass.** This is test-harness IO glue; there is no business logic.
- **ARCH-PURPOSE: flag.** The bound is the purpose of the issue, and it only beats the harness when the load factor is about 1.2 or more. That is the Critical finding above.
- **ARCH-EVOLVE: pass.** No persisted format changes.

**7. Plan revision recommendations**
- Add a `## Revisions` entry. The rationale "named well before the 180 s idle kill" stopped being true once the retirement specs moved to the 50 s budget. `REQUEST_MS` should be derived from the runner's idle budget at the current load factor, and pinned below it by a test.

```findings
dispose:
  - id: BR-1
    disposition: addressed
    note: |
      M.start appends (or prepends) cwd at embedded_nvim.lua:67; grep finds no rtp restatement left in the nine specs; their existing require('parley...') behavior is the evidence.
  - id: BR-2
    disposition: not-addressed
    note: |
      The pcall/stop in M.start (embedded_nvim.lua:62-71) is plausible, but no test drives a failed setup and asserts the child is reaped, so there is no regression evidence.
  - id: BR-3
    disposition: addressed
    note: |
      Red-checked: appending pcall(vim.rpcrequest, 0, "x") to stream_view_spec fails the guard naming the line; NOT_USERS excludes both non-users, so the floor counts exactly 9.
  - id: BR-4
    disposition: addressed
    note: |
      Log records 1 s and 2 s in the recorded parallel suite on c676e97; I reproduced 2 s each at load 11 on 12 CPUs.
  - id: BR-5
    disposition: addressed
    note: |
      tool_folds.lua:19 and :263-264 now name M.INTERACTIVE_ROWS; prose-only.
findings:
  - id: new
    severity: Critical
    kind: defect
    family: inner-deadline-derives-from-outer
    title: |
      REQUEST_MS (60 s) exceeds the runner's 50 s quiet-machine idle budget, so a wedged child still dies by an unnamed harness kill
    detail: |
      embedded_nvim.lua:12 sets 4*arrival.MS = 60 s, but every helper user runs on spec_runner DEFAULT_TIMEOUT 50 s times load_factor (1 to 4). The retirement specs left the 180 s list in this same change. A probe spec spinning its child forever, run through the real runner at load 10 on 12 CPUs, ended "DEADLINE ... stalled after 0 completed case(s); idle 50000ms" with no method named, so Done-when clause 2 fails whenever load_factor is below about 1.2. Instances: helper comments :1-4 ("180 s") and :9-10, atlas/infra/test_harness.md:296-297, and the Plan's REQUEST_MS rationale. Fix: derive REQUEST_MS from the runner's idle budget (for example, the runner exports it to the spec child and the helper uses about half), pin it below that budget with a test, add a spec_runner.execute test where a spinning child's failure names nvim_exec_lua rather than DEADLINE, and correct the comments, atlas and plan.
  - id: new
    severity: Minor
    kind: defect
    family: comment-restates-constant
    title: |
      Helper comments restate harness values (180 s, at most 4) instead of naming their source
    detail: |
      This is the 2nd finding in family comment-restates-constant. Rule: a comment names the source of a value (field, function, runner option), never the value itself. Instances in this window: embedded_nvim.lua:3 "(180 s)", already wrong for every helper user, and embedded_nvim.lua:9 "(at most 4)", which restates the Deadline.load_factor cap. Checked and fine: the dated "(nine specs on 2026-10-19)" in embedded_rpc_spec.lua.
```

<!-- sdlc-review-usage [{"version":1,"intent":{"disposable_root":true,"id":"52c2925f-38c7-4a13-9a4b-c96f2a2bdb1a","repository":"github.com/xianxu/parley.nvim","issue_id":"000401","recipe":"small-diff-review","round":2,"attempt":1,"agent":"claude","root":"/Volumes/TestScratch/review-checkouts/f1f8f9ffa319cce7","reviewed_head":"08c40cc09b69f2eb922f80eedc31c87ee3de2c99","slot":"parley.nvim:3","requested_at":"2026-10-20T01:34:58.306301Z"},"phase":"finished","pid":46162,"started_at":"2026-10-20T01:34:58.397947Z","finished_at":"2026-10-20T01:38:16.51042Z","session_id":"06a9602d-565b-4347-a8e3-e2d987660102","outcome":"returned"}] -->

---

## Re-review — 2026-10-19T18:56:22-07:00 (SHIP)

| field | value |
|-------|-------|
| issue | 401 — document_fold_retirement_spec: silent 43 s case stalls under suite load |
| repo | parley.nvim |
| issue file | workshop/issues/000401-document-fold-retirement-spec-silent-43-s-case-stalls-under-suite-load.md |
| boundary | whole-issue close |
| milestone | — |
| window | 7c99d689403ce315f1eca1dc5f5ba1924ac8d167..1d168ccaa7afba31b643dfb743400cb5b9a75bd5 |
| command | sdlc close --issue 401 |
| reviewer | claude (anthropic; author anthropic) |
| isolation | checkout |
| timestamp | 2026-10-19T18:56:22-07:00 |
| verdict | SHIP |

## Review

Verifying the round-2 fixes now: checking what `Deadline.snapshot(...).idle_ms` actually means, then running the helper and arch specs.

Specs refuse to run outside the isolated harness; switching to `make test-spec` for the infra/test_harness feature.

Helper and arch specs pass; the scratch_placement failures come from where this checkout lives, not from this diff. Next, I'll revert the runner's env pass to confirm the runner-level test goes red.

The runner-level test fails when the env pass is removed and passes when it's restored, so it is real regression evidence. One last check: whether `idle_ms` stays fixed after spawn.

```verdict
verdict: SHIP
confidence: high
```

This change adds a bounded embedded-nvim helper and moves all nine child-driving specs onto it. Each RPC request is now limited by `request_ms()`, which is half of the load-scaled idle budget that `spec_runner` passes to the spec child as `PARLEY_SPEC_IDLE_MS`. That fixes BR-6 properly: the limit now comes from the runner's own budget instead of a fixed 60 s. I confirmed it in the disposable checkout. With the `env = { PARLEY_SPEC_IDLE_MS … }` line commented out of `tests/helpers/spec_runner.lua`, the runner-level test `names a wedged child before the runner's idle kill` fails (`embedded_nvim_spec.lua:77`). With the line restored it passes, along with the other four helper cases and both arch-guard cases, under `make test-spec SPEC=infra/test_harness`. That run's only failures are in `tests/arch/scratch_placement_spec.lua`. That file is unchanged in this window, and it fails because the review checkout sits under `/Volumes/TestScratch`, not because of this diff. Nothing blocks SHIP.

Done-when: current — the Spec still has two bullets (bounded cost, bounded and named failure), and each maps to a Done-when clause. Round 2 only changed how the bound is derived, not the scope. The cost clause is backed by the logged under-load timings (1 s and 2 s against the 50 s budget). The named-failure clause is now pinned by a test that runs through the real `spec_runner.execute` and asserts there is no `DEADLINE` and that `nvim_exec_lua` is named.

1. **Strengths**
   - `tests/helpers/spec_runner.lua:52-54` passes the exact value that `Deadline.new` fixes as `idle_ms`, which never changes after spawn (`spec_deadline.lua:30-33`). So the inner bound comes from the actual outer budget, not an estimate.
   - The runner-level test in `tests/integration/embedded_nvim_spec.lua:59-80` uses the real outer mechanism with a 20 s base. I checked that it fails without the fix.
   - `tests/helpers/embedded_nvim.lua:68-80`: a failed setup stops the child and re-raises (BR-2). It is tested with a real failing `nvim_ui_attach` (`ui = {-1,-1}`), and the test asserts the child was reaped.
   - The sweep is complete: the arch guard scans `tests/*.lua` for `rpcrequest`, `rpcnotify` and quoted `--embed`. Its floor of 9 matches the nine migrated specs exactly.
   - `M.INTERACTIVE_ROWS` is read at every use in `tool_folds.lua` (lines 143, 154, 260), so the small fixture really crosses the suspension threshold. The log records a check that removing the override fails both retirement cases.

2. **Critical findings** — none.

3. **Important findings** — none.

4. **Minor findings** — none raised. Two small things, not findings:
   - `embedded_rpc_spec.lua` names its own path twice, in `NOT_USERS` and in `scan`.
   - In `Child:request`, if the timer fires inside the same loop turn as a successful reply, the request would be reported as "did not answer". This only happens exactly at the limit.

5. **Test coverage notes**
   - `request_ms()` is tested both with the env var set and with it absent (falls back to `DEFAULT_TIMEOUT/2`).
   - The wedge test is covered at the helper level (500 ms override) and through the runner (10 s derived bound).
   - The spec_runner unit test now asserts that both retirement specs have left the 180 s list.

6. **Architectural notes**
   - ARCH-DRY: pass. Nine copies of the jobstart/attach/runtimepath setup collapse into `Embedded.start`, and `DEFAULT_TIMEOUT` is exported, not restated.
   - ARCH-PURE: pass. `request_ms()` is a small derivation tested directly; the timer and kill code stays in the thin `Child:request` layer.
   - ARCH-PURPOSE: pass. The whole class was swept: every raw request site was migrated and an arch guard stops new ones.
   - ARCH-EVOLVE: not applicable. Nothing persisted changes; `PARLEY_SPEC_IDLE_MS` is runtime environment only.
   - Future work: the "half the idle budget" bound is a heuristic. If one case spends more than half the budget on other work before a request wedges, the runner's unnamed kill can still win. If that ever shows up, the child could compute the remaining budget since the last completed case instead of using a fixed half.

7. **Plan revision recommendations** — none. The `## Revisions` entry already supersedes the old Steps text ("4 × arrival.MS (60 s)") and records the derived bound.

```findings
dispose:
  - id: BR-2
    disposition: addressed
    note: |
      embedded_nvim.lua:68-80 pcalls the setup (ui attach and rtp), stops the child, and re-raises; embedded_nvim_spec "stops the child when its setup fails" asserts the child is reaped after a real failing nvim_ui_attach.
  - id: BR-6
    disposition: addressed
    note: |
      spec_runner passes the fixed load-scaled Deadline idle_ms as PARLEY_SPEC_IDLE_MS and request_ms() takes half of it; the runner-level wedge test went red when the env pass was commented out and passes at head; atlas and the plan Revisions entry are corrected.
  - id: BR-7
    disposition: addressed
    note: |
      Helper comments now name their sources (request_ms, PARLEY_SPEC_IDLE_MS, DEFAULT_TIMEOUT) with no restated 180 s or 4x values; the only literal left is the dated floor note in the arch spec, already ruled fine.
```

<!-- sdlc-review-usage [{"version":1,"intent":{"disposable_root":true,"id":"ac50ec62-5e08-4bec-92a6-472f0197b328","repository":"github.com/xianxu/parley.nvim","issue_id":"000401","recipe":"small-diff-review","round":3,"attempt":1,"agent":"claude","root":"/Volumes/TestScratch/review-checkouts/e39b3505390ae340","reviewed_head":"1d168ccaa7afba31b643dfb743400cb5b9a75bd5","slot":"parley.nvim:3","requested_at":"2026-10-20T01:49:48.804228Z"},"phase":"finished","pid":94433,"started_at":"2026-10-20T01:49:49.035403Z","finished_at":"2026-10-20T01:56:21.834631Z","session_id":"bf7f1706-75e6-45d8-8a7e-7e272a49f98f","outcome":"returned"}] -->
