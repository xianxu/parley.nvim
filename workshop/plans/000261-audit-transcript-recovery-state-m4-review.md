# Boundary Review — parley.nvim#261 (milestone M4)

| field | value |
|-------|-------|
| issue | 261 — Audit transcript as the complete recovery state |
| repo | parley.nvim |
| issue file | workshop/issues/000261-audit-transcript-recovery-state.md |
| boundary | milestone M4 |
| milestone | M4 |
| window | 31ca6eb92e68d51572692e266d4801bc4524d9e0..4c4ab385c919bd28809411e7c5069bf652550008 |
| command | sdlc milestone-close --issue 261 --milestone M4 |
| reviewer | claude |
| timestamp | 2026-09-19T09:54:45-07:00 |
| verdict | FIX-THEN-SHIP |

## Review

```verdict
verdict: FIX-THEN-SHIP
confidence: high
```

M4 delivers what it set out to: every settle path in the W-table has a code change, the runner's `fault`/`kill_scope`/`stats` trio is clean and well-factored (`finish` is now shared by the machine's terminal and the fault), and the end-to-end proof is real — I ran `generation_settles_spec`, `response_topic_spec` and `skill_invoke_spec` at HEAD and all are green (12/13/42 cases, 0 failures). I found no correctness defect that breaks a stated contract, so nothing blocks. What keeps this from SHIP is evidence and collateral: three atlas passages now state the *pre-M4* contract on the very seams this milestone changed (content fetches "unscoped", "a zero-match stop can still mean asynchronous readiness is pending", "cleanup remains tracked until positive completion evidence"); several behavior-changing edits have no test that goes red on their revert — I confirmed by counterfactual that dropping Copilot's `pre_query` error forward leaves every related spec passing, and W15's three guards are ticked `[x]` in the plan with no test at all; and the only stop cause driven end-to-end is `:ParleyStop`, while both the Done-when clause and the plan's own test strategy enumerate an edit, reload and detach — the reported #261 shape is the edit.

## 1. Strengths

- **`kill_scope` is correctly once-and-early.** `generation_runner.lua:60-77` fires on the first *accepted* transition into `stopping` **or** `terminal`, uses `G.phase` (O(1), no snapshot) and runs before `s.adapters={}` — both entry points are genuinely needed and both are pinned (`generation_settles_spec.lua:130-160`), including the successful-terminal case that never enters `stopping`.
- **`finish` extraction (`generation_runner.lua:452-465`) is the right DRY move**: the machine's terminal and `fault` cannot drift in what they release, and `active-=1` now has exactly one site to pair with the one increment.
- **W14 releases everything it took and returns `nil, reason`** (`generation_runner.lua:653-675`), and the test proves the *region* is free by admitting the same start again — a stronger assertion than checking a counter.
- **W17's fix is keyed to the real event.** `BufUnload` (measured to fire for both `:bd` and `:e!`, not for autoread) frees the buffer-number guard while letting the stranded read settle its own pool admission through `_gen`; both reopen paths are tested, and the pre-existing "invalid scheduled completion" test was honestly re-pinned to its new ending rather than deleted.
- **The oauth scope threading is complete.** I walked every hop (`fetch_content` → public/`_try_saved_accounts` → `_try_account_fetch` → `fetch_with_access_token` → each provider's metadata/content/fallback/convert): all 12 spawn sites go through `content_run`, and the arch census declares the forwarded parameter with an exact count so a dead entry fails too (`spawn_seam_spec.lua:271-308`).

## 2. Critical findings

None.

## 3. Important findings

**I1 — atlas + test doubles still describe the pre-M4 contract on the seams M4 changed** (`atlas/providers/tool_execution.md:88`, `atlas/providers/architecture.md:44`, `atlas/chat/ownership.md:71-73`, `tests/helpers/respond_fixture.lua:23`). *This is the 7th finding in family `seam-change-collateral`* — do not patch these four sites; the rule is what needs fixing. Rule: **when a change makes a seam behave differently, or makes a previously-ignored part of its contract load-bearing, every restatement of that contract changes in the same commit — prose, comments, and doubles alike; the enumeration is produced by grepping the seam's name and the old claim, not by memory.** Measured instances here: (a) `tool_execution.md:88` lists content fetches among the **unscoped** helpers, while the new `lifecycle.md:337` says the scope kill reaches "the content fetches its preparation made" and links to that very section; (b) `architecture.md:44-45` "A zero-match stop can still mean asynchronous readiness is pending" is precisely what W5 reversed; (c) `ownership.md:71-73` "a cancellation request alone does not prove an effect stopped" now has W2 and W5 as exceptions, sitting two lines below the new sentence that contradicts it; (d) `stop_owner`'s **return value** became load-bearing at `response_provider.lua:124`, but the shared double (`respond_fixture.lua:23`) and its five inline copies (`batch_lifecycle_spec:20`, `branch_topic_input_spec:26`, `chat_onboarding_capture_spec:24`, `chat_scoped_response_spec:24`, `chat_stop_generation_spec:23`) return `nil`, so no chat-level test ever takes the new branch (ARCH-MOCK: production flow and test flow no longer share the boundary; also ARCH-DRY — one double, not six).

**I2 — behavior-changing edits with no test that fails on their revert, one of them ticked as tested.** *This is the 2nd finding in family `behavior-change-without-regression-test`.* Rule: **every behavior-changing edit site has a test that goes red when that site alone is reverted; the as-built "each test turns red on revert" line is written per edited site, not per W-row — and a guard that only matters when its callee throws is only a behavior change if a test makes the callee throw.** Enumeration on this diff: (a) **W15 has no test at all** — `chat_respond.lua:1337`, `:1338`, `:1716` are pure `pcall` guards and no spec makes `batch_response.cancel` or `response_topic.cancel` throw, yet Task 4.2 Step 1 ("Failing tests for … W15 and W16") is checked `[x]`; (b) **the Copilot forward** (`providers.lua:1079-1081`) — I exported HEAD to a scratch tree, dropped `on_error` from the forward, and `vault_spec`, `dispatcher_query_spec`, `providers_pre_query_spec`, `cliproxy_catalog_spec`, `cliproxy_dispatch_spec`, `response_provider_spec` and `unscoped_kill_spec` all still pass — the vault half is tested, the hop that actually reaches the waiting request is not; (c) **11 of the 12 oauth scope sites** — only the public-fetch hop is asserted (`unscoped_kill_spec.lua:201`); dropping `scope` from `_fetch_google_api_once`, either Dropbox request, either Microsoft request or `_convert_office_to_text` reddens nothing. A table-driven case over {public, google, dropbox, microsoft, office} asserting `spawn_options[n].detached` closes (c) in one test.

**I3 — only `:ParleyStop` drives the settle/kill path end to end; the reported shape does not.** *This is the 2nd finding in family `done-when-clause-untested`.* Rule: **a Done-when clause that enumerates alternatives ("Stop, an edit that revokes it, reload or detach") is tested per alternative — parametrize over the enumerated list so a missing one is visible in the test name.** Every M4 case stops through `Runner.cancel`/`cancel_responses` (`generation_settles_spec.lua:132,151,243`; `response_session_spec.lua:57`); the plan's own strategy said each case "triggers each stop cause that applies (Stop, a revoking edit, `:e!`, `:bd`)" (`plan:1329-1333`). The E2E reloads only *after* the generation is already terminal, so no test drives an edit-revoked or reload-detached generation against a TERM-ignoring process — and an edit during generation is the shape #261 was filed from. `submit_and_stop` already has the harness; parametrizing its stop step is cheap.

**I4 — the atlas claims a completeness the spec does not have.** `atlas/chat/lifecycle.md:347` — "The proof is `generation_settles_spec.lua`. It holds one case per wait". It holds W1, W9, W11, W14, `fault`, the scope kill and `stats`; W2–W8, W12, W13, W15–W18 live in seven other specs, and W10 was dropped. *This is the 9th finding in family `enumeration-claims-completeness`.* Rule: **prose never asserts a count or completeness over an enumeration it does not carry — give the enumeration itself the evidence column (a `test:` column on the W-table naming spec and case) and have the prose point at the table.** That also fixes the unrevised plan text (`plan:1329` "One case per row, W1–W17"; `plan:1335` `after_each` asserting `tasker.stats().active == 0`, which the as-built `after_each` does not assert).

## 4. Minor findings

- `generation_runner.lua:685` — after a `fault`, `M.snapshot(r)` reports the *machine's* phase (e.g. `streaming`), while the host was handed `phase='terminal', outcome='fault'`; two authorities for "terminal" (ARCH-ORDER). Either make `fault` a machine event or have `M.snapshot` report the final it delivered.
- `response_topic.lua:45-46` keys W16 on `not s.handle`, the exact condition Task 4.1's as-built rejected for W1 ("the start threw, not no handle"). It makes `response_topic.lua:88-92` dead, and a stop arriving *during* `provider.request` now retires the topic while a just-spawned process is unconfirmed. Mark `start_threw` around the request instead.
- `chat_respond.lua:1577-1580` comment ("whatever the remote fetch started dies with the generation's scope kill") overstates: a chain resuming from an *unscoped* hop (keychain, refresh, auth prompt) after the one-shot kill spawns fresh processes into the dead scope, bounded only by the 120 s/60 s deadline. Either say so, or have tasker refuse a scoped run whose scope was already stopped.
- `generation_runner.lua:360-364` — resolving a thrown `start_child` "since nothing was started" treats a throw as proof of absence (ARCH-ORDER); it is the same assumption `chat_remote_preparation_spec` used to pin against. Outcome `unknown` is honest; the residual (a tool process that started before its adapter threw runs on until the generation's terminal kill) should be stated rather than denied.
- `generation_runner.lua:675-678` — `active=active+1` sits before `sync(s)` and `dispatch(s,{type='start'})`, which are outside W14's pcall; a throw there reopens the leak W14 closed, narrower.
- `generation_settles_spec.lua:56-59` stubs `D.subscribe` and restores it outside a pcall (same shape at `skill_invoke_spec.lua:250-256` for `FS.new`); if the fix regresses, the stub leaks into every later case in the file. *2nd in family `stub-restored-outside-finally`* — rule: a spec replaces a module field only through a `with_stub(tbl, key, value, body)` helper that restores in all paths.

## 5. Test coverage notes

Green at HEAD (isolated HOME/XDG/TMPDIR): `generation_settles_spec` 12, `response_topic_spec` 13, `skill_invoke_spec` 42, 0 failures. The E2E cases are the strongest part of this milestone — 5-in-a-buffer, 17-across-`:e!` and `:bd`+reopen each assert admission, `Tasker.stats().active == 0`, the runner baseline, and that SIGKILL actually reached the stream. Gaps are enumerated in I2/I3; additionally the `after_each` of the E2E describe waits for `Tasker.stats().active == 0` without asserting it (`generation_settles_spec.lua:222`), so a tasker leak there is silent.

## 6. Architectural notes

ARCH-DRY: pass, with I1(d) (six copies of one double) and the W16/W1 divergence. ARCH-PURE: pass — the new logic is thin glue over the pure machine, though `fault` puts a terminal decision in the shell. ARCH-PURPOSE: pass — the shadow-sweep over the oauth content tree found every consumer deriving the scope from `content_run`, and W10's drop is argued from the machine's accept rules rather than waved away. ARCH-MOCK: flag — I1(d). ARCH-CONSTRAINTS: pass — the kill bound is 2 s + drain, `scope_kill` is an O(1) phase check on the dispatch path, and the process-wide cap is exercised at 17 iterations. ARCH-SECURE: pass — no credential reaches a new log line; `_token_body_summary` is untouched; the new abort text carries a Lua error, not a payload. ARCH-ORDER: mostly pass and the strongest area of this diff (fake timers make the kill escalation reproducible), flagged twice above for uncertainty collapsed into absence (`fault` snapshot, thrown `start_child`). ARCH-FUNERAL: pass — the only new residue is the per-run skill augroup, deleted by `release_owner` on every exit path; processes spawned into a dead scope die at their deadline.

For M5: `fault` is a new terminal outcome with no words, and `chat_respond.lua:1703` adds a new raw-token channel (`'Response completion not started: ' .. why`) — neither is in Chunk 5's "What is broken today" inventory, so Task 5.3's "replace every site under it" would miss both.

## 7. Plan revision recommendations

- **"M4 test strategy, as built"** — record that W-rows are tested in their owner's spec rather than one case per row in `generation_settles_spec`, add a `test:` column to the W-table naming spec + case per row (including "none" for W15), and correct the `after_each` claim (`plan:1329-1336`).
- **"M4 Task 4.2, as built — W15"** — either add the throwing-cancel test or un-tick Step 1 and state that W15 ships as an unguarded-path hardening with no regression evidence.
- **"M4 Task 4.3, as built — W4 coverage"** — record that only the public hop is asserted, and name the table-driven test that covers the remaining 11 spawn sites and the `providers.lua` forward.
- **M5 scope** — add `fault` and `Response completion not started` to Chunk 5's producer inventory.

```findings
findings:
  - id: new
    severity: Important
    family: seam-change-collateral
    title: |
      Three atlas passages and six stop_owner doubles still state the contract M4 replaced
    detail: |
      7th in this family: do not patch the sites. Rule — a change to how a seam
      behaves, or that makes a previously-ignored part of its contract
      load-bearing, updates every restatement of it (prose, comments, doubles)
      in the same commit, enumerated by grepping the seam name and the old
      claim. Instances: tool_execution.md:88 still lists content fetches as
      unscoped while lifecycle.md:337 links there claiming the scope kill reaches
      them; architecture.md:44 keeps "a zero-match stop can still mean
      asynchronous readiness is pending" (reversed by W5); ownership.md:71-73
      keeps "a cancellation request alone does not prove an effect stopped" two
      lines under the new sentence that contradicts it; stop_owner's count is now
      load-bearing at response_provider.lua:124 but respond_fixture.lua:23 and
      five inline copies return nil, so no chat-level test takes the branch
      (ARCH-MOCK, and ARCH-DRY for the six copies).
  - id: new
    severity: Important
    family: behavior-change-without-regression-test
    title: |
      W15, the Copilot pre_query forward and 11 of 12 oauth scope sites redden nothing on revert
    detail: |
      2nd in this family. Rule — every behavior-changing edit site has a test
      that goes red when that site alone is reverted, and the as-built
      "red on revert" line is written per edited site, not per W-row; a pcall
      guard is a behavior change only once a test makes its callee throw.
      Measured: W15's three guards (chat_respond.lua:1337, 1338, 1716) have no
      test, yet Task 4.2 Step 1 is ticked as covering W15; removing on_error from
      providers.lua:1081 in a scratch export left vault, dispatcher_query,
      providers_pre_query, cliproxy_catalog, cliproxy_dispatch, response_provider
      and unscoped_kill all passing; only the public hop of the oauth content
      tree asserts its scope (unscoped_kill_spec.lua:201).
  - id: new
    severity: Important
    family: done-when-clause-untested
    title: |
      Only Stop drives the settle and scope kill; edit, reload and detach are untested
    detail: |
      2nd in this family. Rule — a Done-when clause that enumerates alternatives
      is tested per alternative, parametrized over the list so a missing one is
      visible in the test name. Every M4 case stops via Runner.cancel or
      cancel_responses; the plan's own strategy (plan:1329-1333) required each
      applicable stop cause per case, and the Done-when names "Stop, an edit that
      revokes it, reload or detach". The E2E only reloads after terminal, so the
      shape #261 was filed from — an edit during generation — never drives the
      kill path. submit_and_stop already has the harness.
  - id: new
    severity: Important
    family: enumeration-claims-completeness
    title: |
      Atlas says the settles spec holds one case per wait; it holds 7 of 18
    detail: |
      9th in this family. Rule — prose never asserts a count or completeness over
      an enumeration it does not carry: give the W-table a `test:` column naming
      the spec and case for each row (including "none"), and have the prose point
      at the table. atlas/chat/lifecycle.md:347 claims one case per wait, while
      W2-W8, W12, W13 and W15-W18 live in seven other specs and W10 was dropped;
      plan:1329 and plan:1335 still state the superseded strategy, including an
      after_each assertion on tasker.stats().active that was not built.
  - id: new
    severity: Minor
    family: state-change-bypasses-model
    title: |
      After a fault the runner's snapshot reports the machine's non-terminal phase
    detail: |
      generation_runner.lua:470-474 ends the generation outside the pure machine,
      so M.snapshot (:685) reports e.g. phase='streaming' while the host was given
      phase='terminal', outcome='fault' (ARCH-ORDER: two authorities for the same
      fact). Make fault a machine event, or have M.snapshot report the final it
      delivered.
  - id: new
    severity: Minor
    family: canonical-form-not-shared
    title: |
      W16 keys on a missing handle, the condition Task 4.1 rejected for W1
    detail: |
      response_topic.lua:45-46 infers "the request threw" from `not s.handle`,
      while the runner marks `start_threw` because a nil handle is not the same
      thing. It makes response_topic.lua:88-92 unreachable and retires the topic
      while a process spawned during a re-entrant stop is still unconfirmed.
  - id: new
    severity: Minor
    family: one-shot-cleanup-not-a-gate
    title: |
      A fetch chain resuming after the scope kill spawns into a dead scope
    detail: |
      chat_respond.lua:1577-1580 says whatever the fetch started dies with the
      scope kill. A chain paused at an unscoped hop (keychain, refresh, auth
      prompt) resumes after the kill and spawns fresh scoped processes nothing
      will signal, bounded only by their 120 s/60 s deadline. State the residual,
      or refuse a scoped run whose scope has already been stopped.
  - id: new
    severity: Minor
    family: absence-inferred-from-throw
    title: |
      A thrown start_child is resolved as "nothing was started"
    detail: |
      generation_runner.lua:360-364 resolves the child at once on the rationale
      that nothing started; a throw is not proof of that — the same assumption the
      remote-preparation spec used to pin against. The `unknown` outcome is
      honest, but the residual (a tool process started before its adapter threw
      runs into the next round and dies only at the generation's terminal kill)
      should be stated rather than denied.
  - id: new
    severity: Minor
    family: partial-guard-window
    title: |
      W14's pcall stops one statement short of the admission increment
    detail: |
      generation_runner.lua:675-678 increments `active` before `sync(s)` and
      `dispatch(s,{type='start'})`, both outside the guard that W14 added; a throw
      there reopens the same leak in narrower form.
  - id: new
    severity: Minor
    family: stub-restored-outside-finally
    title: |
      D.subscribe and FS.new stubs are restored outside a pcall
    detail: |
      2nd in this family. Rule — a spec replaces a module field only through a
      with_stub(tbl, key, value, body) helper that restores on every path, so a
      regression fails one case instead of cascading. Instances:
      generation_settles_spec.lua:56-59 (D.subscribe) and
      skill_invoke_spec.lua:250-256 (FS.new).
```
