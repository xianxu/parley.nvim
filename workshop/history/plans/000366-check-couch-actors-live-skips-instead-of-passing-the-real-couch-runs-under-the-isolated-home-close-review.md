# Boundary Review — parley.nvim#366 (whole-issue close)

| field | value |
|-------|-------|
| issue | 366 — check-couch-actors-live skips instead of passing: the real couch runs under the isolated HOME |
| repo | parley.nvim |
| issue file | workshop/issues/000366-check-couch-actors-live-skips-instead-of-passing-the-real-couch-runs-under-the-isolated-home.md |
| boundary | whole-issue close |
| milestone | — |
| window | 4db64fd9862fe0b2deaf6240852c6fe0afb64da0..e6b4a8de051080a9f129ad213dab016e38ac8e6a |
| command | sdlc close --issue 366 |
| reviewer | claude |
| isolation | fenced |
| timestamp | 2026-10-17T01:48:51-07:00 |
| verdict | SHIP |

## Review

Running the two isolation spec files directly to confirm they pass at head.

```verdict
verdict: SHIP
confidence: high
```

This change does what the issue set out to do, and it is small. The plan's Revisions entry replaces the Spec's guess about HOME with the two causes that were actually measured: the isolated `XDG_DATA_HOME` clashes with the store `COUCH_STORE_DIR` selects, and the caller identity was missing `PAIR_SESSION_NAME` and `PAIR_LAUNCH_NONCE`. The diff fixes exactly those two. The allowlist (`scripts/test-env.sh:34`) now keeps the two identity names, but only when `PARLEY_LIVE_COUCH` is set. The Makefile works out the operator's data home and passes it as `PARLEY_LIVE_COUCH_DATA_HOME`. That name gets through `test-env.sh` because every `PARLEY_LIVE_*` name is kept (line 50). In `couch_spec`, only the one `vim.system` call gets `XDG_DATA_HOME` from it; `vim.system` merges `env` into the inherited environment when `clear_env` is false, so the spec process itself stays isolated. All five Plan checkboxes are delivered. I ran the three touched spec files at head: integration `test_isolation_spec` 9/0, unit `test_isolation_spec` 15/0, `couch_spec` 5/0 with the expected pending line. Both Done-when modes (unsandboxed Success, sandboxed Pending with stderr) need the operator's live socket, so I can't reproduce them in this checkout. The Log records both, plus a mutation check on the allowlist names. Nothing blocks.

1. **Strengths**
   - `Makefile.parley:328`: `$(or $(XDG_DATA_HOME),$(REAL_HOME)/.local/share)` is the right fallback. Make reads `XDG_DATA_HOME` from the operator's environment, and `TEST_ENV` only overrides it inline on the command it runs.
   - `tests/unit/couch_spec.lua:51-52`: the scope is as tight as it can be. Only the one child process sees the real data home, so the isolation design from #365 holds.
   - `tests/integration/test_isolation_spec.lua:125,132`: both modes are checked. The identity names are absent from a plain launch and present under `PARLEY_LIVE_COUCH`, and the Log's mutation check shows this assertion fails when the names are removed.
   - The pending message now carries the exit code and the first output line, so the "skipped, not passed" problem diagnoses itself next time.

2. **Critical:** none.

3. **Important:** none.

4. **Minor**
   - `atlas/infra/test_harness.md:101-102` says the pending message carries "the first stderr line". The code at `couch_spec.lua:56` falls back to the first stdout line, then to "no output". This is the only claim of its kind in the window.
   - Nothing pins `PARLEY_LIVE_COUCH_DATA_HOME` in the `check-couch-actors-live` recipe, or its use in `couch_spec`. If either is dropped, the live check quietly goes back to pending. `tests/unit/test_isolation_spec.lua` already inspects the Makefile's text, so a one-line assertion there would be cheap.

5. **Test coverage:** the allowlist change is covered in both directions. The data-home wiring can only be checked against a live socket by design, and the Log records that run. The improved pending message is what keeps a future regression visible.

6. **Architecture**
   - **ARCH-DRY: pass.** The data-home fallback appears only once; `PLENARY ?= $(HOME)/.local/share/...` is a different concern. The identity names are listed only in `test-env.sh`, which remains the one owner of the allowlist.
   - **ARCH-PURE: pass.** This is harness glue only; no business logic moved into IO.
   - **ARCH-PURPOSE: pass.** It fixes the purpose itself (a real pass from an unsandboxed operator terminal) by fixing both measured causes, rather than only improving the diagnostic.

7. **Plan revisions:** none needed. The existing 2026-10-17 Revisions entry already records the change from HOME to the measured causes.

```findings
findings:
  - id: new
    severity: Minor
    kind: defect
    family: doc-claim-drifts-from-code
    title: |
      atlas says pending shows the first stderr line; the code falls back to stdout, then "no output"
    detail: |
      atlas/infra/test_harness.md:101-102 vs tests/unit/couch_spec.lua:56. This is the only instance in the window. Reword to "the first line of its stderr (else stdout)".
  - id: new
    severity: Minor
    kind: defect
    family: live-wiring-unpinned
    title: |
      No static check pins PARLEY_LIVE_COUCH_DATA_HOME in the check-couch-actors-live recipe
    detail: |
      If Makefile.parley:332 drops PARLEY_LIVE_COUCH_DATA_HOME, or couch_spec.lua:52 stops reading it, the live case quietly goes back to pending, which is the failure #366 fixed. tests/unit/test_isolation_spec.lua already reads Makefile text, so a one-line assertion there would cover it.
```

<!-- sdlc-review-usage [{"version":1,"intent":{"disposable_root":true,"id":"8aba6309-5b3e-46cf-9d0c-59e2c916be5d","repository":"github.com/xianxu/parley.nvim","issue_id":"000366","recipe":"small-diff-review","round":1,"attempt":1,"agent":"claude","root":"/Users/xianxu/Library/Caches/sdlc/review-checkouts/1cedac7218701796","reviewed_head":"e6b4a8de051080a9f129ad213dab016e38ac8e6a","slot":"parley.nvim:3","requested_at":"2026-10-17T08:47:34.897775Z"},"phase":"finished","pid":57554,"started_at":"2026-10-17T08:47:35.004486Z","finished_at":"2026-10-17T08:48:50.69771Z","session_id":"656ce6f3-6948-4c08-8390-b107bfc71edc","outcome":"returned"}] -->
