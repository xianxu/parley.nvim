# Boundary Review — parley.nvim#400 (whole-issue close)

| field | value |
|-------|-------|
| issue | 400 — couch.run: session-sync status/actors queries and sends have no deadline |
| repo | parley.nvim |
| issue file | workshop/issues/000400-couch-run-session-sync-status-actors-queries-and-sends-have-no-deadline.md |
| boundary | whole-issue close |
| milestone | — |
| window | f5afbf45bf761ff0249f1e6a9d345ebe44814b1d..9d5d5f7586131f1f162f46fbfea75abe4d4f7f26 |
| command | sdlc close --issue 400 |
| reviewer | claude (anthropic; author anthropic) |
| isolation | checkout |
| timestamp | 2026-10-19T12:56:33-07:00 |
| verdict | FIX-THEN-SHIP |

## Review

Reviewing the diff for the couch deadline; now checking the probe path and Neovim's `vim.system` timeout semantics.

Running the new specs to confirm they pass at head.

All green. Now reverting the default in a scratch edit to confirm the new integration tests go red.

Red-check confirmed (all three new integration tests fail without the default; file restored). One last check on attention's explicit timeout.

```verdict
verdict: FIX-THEN-SHIP
confidence: high
```

The main change works. `couch.run` (`lua/parley/couch.lua:27-28`) now gives every child a deadline unless the caller names one. `timeout = false` lets `document_registry` keep its own timer, and the `finish` guard means the callback fires once. I checked Neovim 0.11's `_system.lua`: on timeout it sends SIGTERM and turns exit code 0 or 1 into 124, so `couch.timed_out` matches what Neovim actually reports. Both targeted suites pass at head (`make test-spec SPEC=modes/review`, `SPEC=modes/session_sync`). When I removed the default from `couch.run` in the checkout, all three new #400 integration tests failed; I then restored the file and the tree is clean. Two things should be fixed first. The Spec's timeout table says a timed-out status query leaves the band showing its last owed state, but the code clears it. And the deadline uses the shipped value of `agentic_submit_timeout_ms`, not the user's configured one.

### 1. Strengths
- The default lives in one place, `couch.run`, so every caller gets it, including future ones (`couch.lua:27`). Opting out with `timeout = false` is explicit and is used exactly once (`document_registry.lua:114`).
- The unit spec covers both the default and the explicit timeout, `false`, a real killed `sleep` child, and two reports racing (`tests/unit/couch_spec.lua:79-131`).
- The `nap` trap in the fake fixes a real problem: an orphaned `sleep` would hold the pipes open and stop `vim.system` from reporting. The lesson is written down in `workshop/lessons.md`.
- The probe test waits on an actual timed-out result rather than a spawn count, so a duplicate probe can't make it pass by accident.
- The legacy submit treats a timeout as unconfirmed, not failed (`session_sync.lua:865-868`), and there is a test that checks no "failed" message appears.

### 2. Critical findings
None.

### 3. Important findings
- **A timed-out status query clears the band's owed state, contradicting the Spec** (`lua/parley/session_sync.lua:405-420`). On timeout `query` returns nil, which makes `since` nil. If `s.owed` was set, it gets set to nil and `refresh(buf)` runs, so the owed minutes disappear until the next probe that succeeds. The Spec's table says "Visible: nothing; the band keeps its last owed state". Every member of this family in the window:
  - the status query: diverges, as described;
  - the actors query (`:428`): `actor` is nil, so there's no ping and `s.probing` is cleared, which matches the Spec;
  - `own_slot`: the caller gets `actors = {}` and `own = nil`, and attention shows its "slot unavailable" warning, which is consistent.
  - **Fix:** in the status callback, when `status == nil`, set `s.probing = false` and return before touching `s.owed`. Add a test that an owed band survives a status timeout. Or, if clearing is intended, correct the Spec table instead.
- **ARCH-DRY: the deadline ignores the user's configured submit budget** (`lua/parley/couch.lua:14`). `M.DEADLINE_MS` is read once at load time from `parley.config`'s shipped default (15000). The registry and agentic-document submits read the user's value through `document_registry.config_ms("agentic_submit_timeout_ms")` (`document_registry.lua:14-18`). A user who raised the setting because couch is slow will see legacy submits reported "not confirmed" after 15 s, while registry submits get the full budget. The Spec calls this "the budget a submit already gets", but submits actually get the configured value.
  - **Fix:** resolve the default when `run` is called, through the same config read (move `config_ms` into a shared place such as `couch` or a small config helper to avoid a require cycle). Also use that value in the "%g s" message at `session_sync.lua:866`.

### 4. Minor findings
- `couch.timed_out` requires `signal == 15`. If a child traps SIGTERM and exits 0, Neovim reports code 124 with signal 0, and the legacy submit would show "failed". This doesn't happen with the real couch binary, but `obj.code == 124` alone would be the more robust test.
- The `couch.query` doc comment (`couch.lua:53`) still offers `{ timeout = ms }` as an example option. It could mention that a default now applies.

### 5. Test coverage notes
- Both Done-when clauses are covered. Clause 1 is tested with the default, an explicit value and `false`, plus fire-once on expiry. Clause 2 is tested with a fake couch that hangs and then answers on the next poll.
- No test checks the band's owed state after a status timeout; that's the gap behind Important #1.
- No test covers a user-configured `agentic_submit_timeout_ms` reaching `couch.run`; that's the gap behind Important #2.

### 6. Architectural notes
- **ARCH-DRY:** flagged, see Important #2. Otherwise the deadline has a single source.
- **ARCH-PURE:** pass. `timed_out` is a pure predicate with its own unit test, and the IO seam stays inside `couch.run`.
- **ARCH-PURPOSE:** pass. I checked every `couch.run` path: the probe's status and actors queries, the ping and violation sends, the legacy submit, `own_slot`, attention (passes its own 5000 ms at `attention.lua:82`) and `document_registry` (`false`). Each one is bounded.
- **ARCH-EVOLVE:** pass, not applicable. No persisted format changes.

### 7. Plan revision recommendations
- If clearing the owed state on a timeout is kept as intended, add a `## Revisions` entry correcting the timeout table's "Visible" cell for status or actors queries.
- If the shipped default is kept on purpose, add a `## Revisions` entry saying the couch deadline ignores the user's override of `agentic_submit_timeout_ms`, and why.

```findings
findings:
  - id: new
    severity: Important
    kind: defect
    family: spec-claim-diverges-from-code
    title: |
      A timed-out status probe clears the band's owed state; the Spec says it keeps it
    detail: |
      In session_sync.lua:405-420 a nil status (timeout) makes since nil, so s.owed gets set to nil and refresh(buf) drops the owed minutes. The Spec's timeout table says the band keeps its last owed state. Family sweep: the actors query (:428) and own_slot behave as the Spec says; only the status query diverges. Fix: on nil status, clear s.probing and return before updating s.owed, and add a test that an owed band survives a status timeout. Or correct the Spec table.
  - id: new
    severity: Important
    kind: defect
    family: config-read-single-source
    title: |
      couch.DEADLINE_MS uses the shipped agentic_submit_timeout_ms, not the user's configured value
    detail: |
      couch.lua:14 reads require("parley.config") once at load time, while the registry and agentic_document submits use document_registry.config_ms (user override first). A user who raised the budget gets legacy submits killed and reported unconfirmed at 15 s. ARCH-DRY: resolve the default per call through a shared config_ms, and use the same value in the session_sync.lua:866 message.
  - id: new
    severity: Minor
    kind: defect
    family: timeout-detection-predicate
    title: |
      couch.timed_out requires signal 15; a child that traps TERM and exits 0 reads as failed
    detail: |
      Neovim sets code 124 whenever its timer fired and the exit code was 0 or 1, whatever the signal. Checking obj.code == 124 alone would be more robust. The real couch binary dies by the signal, so this is low impact.
```

<!-- sdlc-review-usage [{"version":1,"intent":{"disposable_root":true,"id":"911c58ab-03f3-42b5-984e-dddd63e03545","repository":"github.com/xianxu/parley.nvim","issue_id":"000400","recipe":"small-diff-review","round":1,"attempt":1,"agent":"claude","root":"/Users/xianxu/Library/Caches/sdlc/review-checkouts/637be2cad62ad5ba","reviewed_head":"9d5d5f7586131f1f162f46fbfea75abe4d4f7f26","slot":"parley.nvim:3","requested_at":"2026-10-19T19:36:39.794063Z"},"phase":"finished","pid":28189,"started_at":"2026-10-19T19:36:39.898306Z","finished_at":"2026-10-19T19:56:26.078862Z","session_id":"cce98557-87ad-433a-a7ac-5e56c2e22bc6","outcome":"returned"}] -->
