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

---

## Re-review — 2026-10-19T13:24:00-07:00 (SHIP)

| field | value |
|-------|-------|
| issue | 400 — couch.run: session-sync status/actors queries and sends have no deadline |
| repo | parley.nvim |
| issue file | workshop/issues/000400-couch-run-session-sync-status-actors-queries-and-sends-have-no-deadline.md |
| boundary | whole-issue close |
| milestone | — |
| window | f5afbf45bf761ff0249f1e6a9d345ebe44814b1d..5b58f710009b8d7191052e9908c7b57da51fbbf8 |
| command | sdlc close --issue 400 |
| reviewer | claude (anthropic; author anthropic) |
| isolation | checkout |
| timestamp | 2026-10-19T13:24:00-07:00 |
| verdict | SHIP |

## Review

Checking prior-round fixes against the code; next I'll look at attention.lua and run the specs.

```verdict
verdict: SHIP
confidence: high
```

**Summary.** All three findings from round 1 are fixed, and I checked each one against the code and the tests rather than the commit messages. The default deadline is now `couch.deadline_ms()`. It is read on every call through `document_registry.config_ms`, so the user's own `agentic_submit_timeout_ms` applies (`couch.lua:17-19`). Sends get three deadlines (`couch.send_deadline_ms` → `document_registry.lost_ms`). `couch.timed_out` checks only for code 124, and the Revisions entry corrects the Spec's status-query row. I searched for every way `couch` gets called (`couch.run`, `couch.query` and `couch.send`). Only `document_registry` opts out of the default deadline, with `timeout = false` (`document_registry.lua:120`). `attention` keeps its own explicit 5000 ms, and every other caller gets the default. I ran `make test-spec SPEC=modes/review` and `SPEC=modes/session_sync` in this checkout: 46 spec files, 0 failed, 0 errors. That includes the 6 new `couch.run deadline` unit specs, the 3 `#400` session-sync integration specs and the new agentic killed-send spec. One Minor finding remains, about prose: the Spec and Plan text still state the round-1 design that the Revisions replaced.

Done-when: current. Both clauses still hold under the revised design. Every child is bounded (1x the submit deadline for queries, 3x for sends, `timeout = false` only where the registry's own timer bounds the child), and the callback fires once on expiry. A timed-out probe clears `s.probing` and probes again, and a spec shows it. What the Revisions added (the send log line and the agentic band message) goes beyond Done-when, and it is tested.

1. **Strengths**
   - `document_registry.lost_ms` (`document_registry.lua:24-26`) is now the one source for "three submit deadlines". The rename default and the send deadline both read it (ARCH-DRY).
   - The legacy submit notice uses the `obj.stderr` that `couch.send` sets (`session_sync.lua:865-866`). The deadline value is formatted in one place only.
   - `finish` in `couch.run` drops a second report, and a unit spec pins that by feeding it two reports (`couch_spec.lua`, "delivers once").
   - The fake's `nap` helper ends on SIGTERM. Without it, an orphaned `sleep` would hold the pipes and keep the timeout from ever reporting. The lessons entry records this.
   - The session-sync spec checks that every spawn has the right deadline: queries get `deadline_ms()`, sends get `send_deadline_ms()`, registry children get none. It also checks that all five call kinds were actually exercised.

2. **Critical:** none.

3. **Important:** none.

4. **Minor**
   - The Spec and Plan body still describe the round-1 design. This is the 2nd finding in family `spec-claim-diverges-from-code`.
     - **The rule:** when a Revision replaces a Spec or Plan claim, edit or strike the replaced sentence where it stands, so the body never contradicts the code.
     - **Instances:**
       - Spec ¶1 says the default is `couch.DEADLINE_MS`, the shipped 15000.
       - Spec table: the ping/violation and legacy-submit rows say "default", but sends now get 3x.
       - Spec timeout table, status row: "the band keeps its last owed state".
       - ARCH-CONSTRAINTS says "at most 15 s", but sends now live up to 45 s.
       - Plan item 1 says "`DEADLINE_MS` … (code 124, signal 15)".

5. **Test coverage notes**
   - Done-when clause 2 says "a probe whose couch call times out". The integration spec hangs only the status query. A hung actors query is never reached (`--actors` hangs too, but the status query is already hanging). The code clears `s.probing` before using the result at `session_sync.lua:431`, so the behavior is right, but no spec pins it.
   - The #357 slow-send spec now has 1 s of slack (it sleeps 2 s against a 3 s send deadline). That is enough, but it could time out on a heavily loaded runner.
   - Reverting `deadline_ms` to read `require("parley.config")` would turn the "follows the user's submit budget, read per call" spec red. That is the regression evidence for BR-2.

6. **Architecture**
   - **ARCH-DRY: pass.** `lost_ms` is extracted and shared, and the timeout message has one source.
   - **ARCH-PURE: pass.** `timed_out` and `lost_ms` are pure. `couch.run` is the thin IO seam.
   - **ARCH-PURPOSE: pass.** Every `couch.run` caller is now bounded. No caller was left out of the search, and nothing that was the point of the issue was pushed to a follow-up.
   - **ARCH-EVOLVE: pass (not applicable).** No persisted format changed.

7. **Plan revision recommendations**
   - Fold the Revisions into the Spec and Plan body text, as listed under Minor. No other revision is needed.

```findings
dispose:
  - id: BR-1
    disposition: addressed
    note: |
      Revisions entry corrects the Spec row; a nil status reads as nothing owed like every failed status (session_sync.lua:405-420), which is consistent with pair 437's documented rule.
  - id: BR-2
    disposition: addressed
    note: |
      couch.deadline_ms reads document_registry.config_ms per call (couch.lua:17-19); the unit spec "follows the user's submit budget, read per call" pins it; the session_sync notice uses the stderr couch.send formats.
  - id: BR-3
    disposition: addressed
    note: |
      couch.timed_out is obj.code == 124 alone (couch.lua:43-45); the unit spec asserts code 124 with signal 0 counts as timed out.
findings:
  - id: new
    severity: Minor
    kind: defect
    family: spec-claim-diverges-from-code
    title: |
      Spec and Plan body still state the round-1 design the Revisions replaced
    detail: |
      This is the 2nd finding in this family. The rule: when a Revision replaces a Spec or Plan claim, edit or strike the replaced sentence where it stands. Instances: Spec paragraph 1 (couch.DEADLINE_MS, shipped 15000); Spec table ping/violation and legacy-submit rows (default, but sends get 3x); status row (the band keeps its last owed state); ARCH-CONSTRAINTS (at most 15 s, but sends live up to 45 s); Plan item 1 (DEADLINE_MS, code 124 with signal 15).
```

<!-- sdlc-review-usage [{"version":1,"intent":{"disposable_root":true,"id":"56294bd1-c2ca-44c7-8a11-7e23f60f7aa7","repository":"github.com/xianxu/parley.nvim","issue_id":"000400","recipe":"small-diff-review","round":2,"attempt":1,"agent":"claude","root":"/Users/xianxu/Library/Caches/sdlc/review-checkouts/5dff3a2815417e27","reviewed_head":"5b58f710009b8d7191052e9908c7b57da51fbbf8","slot":"parley.nvim:3","requested_at":"2026-10-19T20:16:23.456289Z"},"phase":"finished","pid":46937,"started_at":"2026-10-19T20:16:23.550931Z","finished_at":"2026-10-19T20:23:51.274626Z","session_id":"069186f2-920b-4347-9950-0286b567b407","outcome":"returned"}] -->

---

## Re-review — 2026-10-19T13:26:01-07:00 (SHIP)

| field | value |
|-------|-------|
| issue | 400 — couch.run: session-sync status/actors queries and sends have no deadline |
| repo | parley.nvim |
| issue file | workshop/issues/000400-couch-run-session-sync-status-actors-queries-and-sends-have-no-deadline.md |
| boundary | whole-issue close |
| milestone | — |
| window | 4de97dc37a92d11b9a806a4486693c44914b23f8..0167f8fadbe8886ac18a06c01d006d0c8f4e8126 |
| command | sdlc close --issue 400 |
| reviewer | claude (anthropic; author anthropic) |
| isolation | checkout |
| timestamp | 2026-10-19T13:26:01-07:00 |
| verdict | SHIP |

## Review

Checking the legacy-submit message in session_sync. After that I'll write the verdict.

```verdict
verdict: SHIP
confidence: high
```

This window changes only documents and touches no code. It edits the issue body, adds an entry to `workshop/lessons.md`, and adds the close-gate and close-review records. It fixes BR-4: every replaced claim that finding listed is now struck where it stands, the current claim sits beside it, and each cites its Revision. I checked each new claim against the code at head and found no mismatch. The new agentic-submit row and the "(legacy and agentic submit)" label are not a scope change. They put in the body what the existing "after round 1" Revisions entry already says. That entry was hub-approved and did not change in this window, and `## Done when` did not change either. Nothing blocks SHIP.

Done-when: current. Both bullets still hold under the 1x/3x design. Every `couch.run` caller gets a bounded deadline, either the default (`couch.lua:32`) or an explicit one (`couch.lua:72`, the send deadline). The test that a timed-out probe clears `s.probing` is unaffected.

1. **Strengths**
   - Every BR-4 instance is struck in place:
     - Spec paragraph 1: `DEADLINE_MS` is now `deadline_ms()` / `send_deadline_ms()`.
     - Caller table: both send rows now say send deadline (3x).
     - Status row: the BR-1 correction.
     - ARCH-CONSTRAINTS: 15 s for a query, 45 s for a send.
     - Plan item 1: `deadline_ms()`, with `signal 15` struck.
   - The struck-through text keeps the history readable and each new claim names its Revision.
   - Each new claim matches the code:
     - `couch.deadline_ms` reads the user setting on every call: `couch.lua:17-19` via `document_registry.config_ms` (`document_registry.lua:14-18`).
     - The send deadline is 3x: `send_deadline_ms` returns `lost_ms` (`couch.lua:55-57`), which is `3 * config_ms(...)` (`document_registry.lua:25-27`).
     - The agentic band text matches `agentic_document.lua:398`.
     - The legacy message is assembled at `session_sync.lua:866` together with `couch.lua:67`.
   - The lessons entry states the rule for the whole `spec-claim-diverges-from-code` family: strike the replaced claim where it stands. It does not just patch these instances, which is what ARCH-PURPOSE asks for.

2. **Critical findings:** none.

3. **Important findings:** none.

4. **Minor findings:** none new.

5. **Test coverage:** no code changed, so no regression test is needed. These are prose corrections, and I checked each one against the code it describes (cited above).

6. **Architecture (interdiff only)**
   - ARCH-DRY: pass. The Spec points to `lost_ms` as the source of the send deadline instead of restating a number.
   - ARCH-PURE: N/A, no code in the window.
   - ARCH-PURPOSE: pass. The sweep covers every instance BR-4 listed. I also checked the rest of the body for stale claims and found none. The Log keeps its history as written, which is correct.
   - ARCH-EVOLVE: N/A, no persisted format changed.

7. **Plan revisions:** none. The plan now matches the code.

```findings
dispose:
  - id: BR-4
    disposition: addressed
    note: |
      All five listed instances are struck in place with the current claim beside each, citing its Revision (Spec para 1, both send rows, status row, ARCH-CONSTRAINTS, Plan item 1). Each was checked against couch.lua:17-72, document_registry.lua:14-27, agentic_document.lua:398 and session_sync.lua:866. The lessons.md entry records the rule for the family.
```

<!-- sdlc-review-usage [{"version":1,"intent":{"disposable_root":true,"id":"b1b0837f-0ad5-4c32-bd44-a95954894222","repository":"github.com/xianxu/parley.nvim","issue_id":"000400","recipe":"fix-review","round":3,"attempt":1,"agent":"claude","root":"/Users/xianxu/Library/Caches/sdlc/review-checkouts/0c80eaee6e1e78f5","reviewed_head":"0167f8fadbe8886ac18a06c01d006d0c8f4e8126","slot":"parley.nvim:3","requested_at":"2026-10-19T20:25:17.757554Z"},"phase":"finished","pid":18327,"started_at":"2026-10-19T20:25:17.923746Z","finished_at":"2026-10-19T20:25:54.724354Z","session_id":"aea6bb4b-c811-45d3-ae6d-046f0ac4ad27","outcome":"returned"}] -->
