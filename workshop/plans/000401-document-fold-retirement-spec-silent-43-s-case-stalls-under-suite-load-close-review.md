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
