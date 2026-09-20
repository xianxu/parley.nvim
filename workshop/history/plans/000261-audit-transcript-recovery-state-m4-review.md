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

---

## Re-review — 2026-09-19T10:25:53-07:00 (FIX-THEN-SHIP)

| field | value |
|-------|-------|
| issue | 261 — Audit transcript as the complete recovery state |
| repo | parley.nvim |
| issue file | workshop/issues/000261-audit-transcript-recovery-state.md |
| boundary | milestone M4 |
| milestone | M4 |
| window | 31ca6eb92e68d51572692e266d4801bc4524d9e0..7945b796c50ab10fbf857f1eff51e32d84abb5df |
| command | sdlc milestone-close --issue 261 --milestone M4 |
| reviewer | claude |
| timestamp | 2026-09-19T10:25:53-07:00 |
| verdict | FIX-THEN-SHIP |

## Review

```verdict
verdict: FIX-THEN-SHIP
confidence: high
```

Round 1's fixes mostly hold, and I checked each one by reverting it. I exported HEAD to a scratch tree and ran 20 specs: all green (`generation_settles_spec` 18/18, `spawn_seam_spec` 13/13 once the tree had a git index). Then I reverted each claimed fix on its own and re-ran its specs:

- **Red on revert:** the W15 `cancel_entry` guards, the Copilot forward, 7 of 7 sampled oauth scope sites, the `fault` snapshot, W14's widened pcall, and the stopped-scope refusal.
- **All four stop causes:** with SIGKILL escalation disabled, the stop, edit, reload and detach cases all go red.

Nothing blocks the gate, but four things fall short:

- **Atlas missing the refusal.** The fix commit changed `tasker.stop_scope`'s contract (a stopped key is closed for good, up to 1024 keys) and added a refusal to `tasker.run`. No atlas page says so.
- **W16 has no test that pins it.** Reverting its condition to `not s.handle` leaves `response_topic_spec` green (BR-52).
- **One new guard is untested.** Reverting the batch-cancel guard this commit added to `cancel_responses` reddens nothing.
- **The WAITS check can't fail for some rows.** It searches the raw text of each named file. For the 7 citations that point at `generation_settles_spec.lua` itself, the WAITS list contains the case name, so the check always matches. Renaming the W11 case left it green.

## 1. Strengths

- **The stop-cause test drives the real paths.** `CAUSES` in `generation_settles_spec.lua` covers Stop, an in-answer edit, `:e!` and `:bd`, each run twice against a stream that ignores SIGTERM. With escalation disabled, all four cause cases and the 3 other end-to-end cases go red.
- **The oauth table test really catches every site.** Each of the 7 hops I sampled (`oauth.lua` lines 1393, 1756, 1926, 2059, 2143, 2371, 2505) reddened at least one row when its scope was dropped.
- **The stopped-scope refusal is sound.** The epoch is a process-wide counter (`document/init.lua:15-16`), so a chat generation's `(epoch, generation)` key really is never reused. Skill keys go through `stop_owner`, never `stop_scope`, so they are never recorded. The set is bounded at 1024 with oldest-first eviction.
- **W14 is safe to widen.** `dispatch` only queues effects; they run later in `step`. So moving `sync` and the first `dispatch` inside the pcall cannot orphan started IO.
- **The WAITS list is accurate today.** All 29 citations resolve to a real `it`/`describe` name.

## 2. Critical findings

None.

## 3. Important findings

**Atlas missing the stopped-scope refusal** (`lua/parley/tasker.lua:387-393, 500-502`).
- *This is the 8th finding in family `seam-change-collateral`.* The rule already exists in the lessons ("grep the seam's name…"). This time it was applied to the review's list, not to the seams the fix round itself changed.
- What is stale: `atlas/providers/tool_execution.md:100` still says only that "`tasker.stop_scope(key)` stops every process of one generation". `atlas/chat/lifecycle.md:334-337` says the scope kill reaches the fetches but not that the scope stays closed afterwards.
- Rule-level fix: each round's close greps the name of every public function whose body the round changed across `atlas/`, and the fix round is not exempt.
- Instance fix: one bullet in `tool_execution.md` covering the refusal, the 1024-key bound, and what happens to an evicted key (it is admitted again, bounded by its deadline).

**The new `cancel_responses` batch guard has no red-on-revert test** (`lua/parley/chat_respond.lua:1357`).
- *This is the 3rd finding in family `behavior-change-without-regression-test`.*
- The commit says "Every edited site now has a test that fails when that site alone is reverted". The per-site sweep covered the prior review's list (the 39 oauth sites), not the sites the fix commit itself added.
- Measured: with the guard reverted, 6 specs stay green: `chat_cancel_entry_spec`, `batch_lifecycle_spec`, `batch_respond_spec`, `batch_validation_budget_spec`, `chat_stop_generation_spec` and `generation_settles_spec`.
- Rule: the mutation sweep runs over every behavior-changing hunk in the whole boundary diff, including the fix round's own hunks.
- Instance fix: add a case with a throwing `batch_response.cancel` and a pending `batches[buf]`, asserting the entry sessions are still cancelled.

## 4. Minor findings

- **W16 (BR-52, re-raised as not addressed):** see the dispose block.
- **The WAITS check can't fail for some rows** (`generation_settles_spec.lua:379`).
  - It uses a raw-text `find` over the whole named file. For the 7 citations of the spec itself (W1×3, W9, W11, the W13 fault row, W14), the list satisfies its own check.
  - Fix: match `it%(%s*["']` followed by the case name, and strip the `WAITS` block before searching.
- **W5's branch is unreachable from chat-level specs.**
  - I instrumented `response_provider.lua:125`: the branch was hit 0 times across the six chat specs and the end-to-end spec. The only hits came from `response_provider_spec`.
  - The `dispatcher.query` doubles register a call synchronously, so there is no pre_query window for a Stop to land in.
  - The `stop_owner` double only marks a call stopped through its own stop, so it cannot return 0 for a pending request.
  - `plan:2215` and the comment in `respond_fixture.lua` both claim chat specs now take the branch.
- Five in-window specs still hand-roll a pcall-and-restore instead of using `with_stub`. They are correct, but it is duplicated code, and the lesson's "only through `with_stub`" rule is not enforced anywhere.
- The office conversion now uses `vim.fn.tempname()`. On a normal machine, reverting it fails nothing. It is also a small security improvement: the temp file moves from `/tmp` to Neovim's private per-session directory.

## 5. Test coverage notes

- **Commands:** everything ran in a `git archive` copy of HEAD with isolated HOME/XDG/TMPDIR. Each fix was reverted in its own copy.
- **Went red:**
  - `providers_pre_query_spec` (Copilot forward)
  - `chat_cancel_entry_spec` (`cancel_entry` guards)
  - `tasker_supervision_spec` (stopped-scope refusal)
  - `generation_settles_spec` (`fault` snapshot, W14, escalation)
  - `unscoped_kill_spec` (7/7 oauth sites)
  - `response_session_spec` (the `stopping` hook)
- **Stayed green:** W16's condition, the `cancel_responses` batch guard, and a renamed W11 case.
- **Worth knowing:** disabling the scope kill leaves the end-to-end describe green. The provider's own `stop_owner` does that work there, so the scope kill is pinned only at the session level.

## 6. Architectural notes

- **ARCH-DRY: pass.** Six doubles became one (plus one declared variant, guarded), there is a single `guarded` helper, and `with_stub` exists.
- **ARCH-PURE: pass.**
- **ARCH-PURPOSE: pass.** Every stop cause the Done-when names is driven end to end.
- **ARCH-MOCK: flag (Minor).** The chat-level doubles can't reach W5's branch.
- **ARCH-CONSTRAINTS: pass.** Stopped-scope lookup is O(1), with a 1024-key bound.
- **ARCH-SECURE: pass.** No credential reaches the new log lines, and temp files are now private.
- **ARCH-ORDER: pass, with BR-52 open.** `fault` now has one authority for "terminal", but W16's reordering has no test for the order it changed.
- **ARCH-FUNERAL: pass.** The stopped-scope set is bounded, and office temp files are removed on both paths.

**For M5:** add the stopped-scope refusal text (`task start rejected: its generation has already stopped`) to the M5 message inventory (Chunk 5), alongside `fault` and `Response completion not started`.

## 7. Plan revision recommendations

- **Round-1 disposition (`plan:2215`):** replace "so chat specs take W5's branch" with "W5 is pinned at the adapter (`response_provider_spec`); chat-level doubles have no pre_query window".
- **Core concepts, `tasker` row:** add that `stop_scope` records the key and that `run` refuses a scoped run into a recorded key (bounded at 1024).
- **W16 as-built:** name the test that tells `start_threw` apart from "no handle yet" (a stop arriving while the request is still running).

```findings
dispose:
  - id: BR-47
    disposition: addressed
    note: |
      Atlas passages a-c corrected; one returning stop_owner double plus an arch guard. Chat-level reachability of W5 raised separately (Minor).
  - id: BR-48
    disposition: addressed
    note: |
      Reverting the cancel_entry guard, the Copilot forward, or any of 7 of 7 sampled oauth sites (1393,1756,1926,2059,2143,2371,2505) turns a test red.
  - id: BR-49
    disposition: addressed
    note: |
      With SIGKILL escalation disabled, all four stop-cause cases (stop, edit, reload, detach) and the 3 other end-to-end cases go red.
  - id: BR-50
    disposition: addressed
    note: |
      WAITS list accurate (29/29 citations resolve); atlas points at it; plan revision supersedes Chunk 4. The check's self-match raised as a new Minor.
  - id: BR-51
    disposition: addressed
    note: |
      Removing the final_outcome line from M.snapshot reddens the fault case.
  - id: BR-52
    disposition: not-addressed
    note: |
      Code now keys on start_threw, but reverting to `not s.handle` leaves response_topic_spec 13/13 green; no test drives a stop arriving during provider.request.
  - id: BR-53
    disposition: addressed
    note: |
      tasker refuses a run into a stopped scope; removing the refusal reddens tasker_supervision_spec.
  - id: BR-54
    disposition: addressed
    note: |
      generation_runner.lua:362-365 now states the residual (a process spawned before the throw runs until the scope kill).
  - id: BR-55
    disposition: addressed
    note: |
      Moving sync and dispatch back outside the pcall errors the W14 dispatch case.
  - id: BR-56
    disposition: addressed
    note: |
      Both named sites use with_stub, which restores on every path.
findings:
  - id: new
    severity: Important
    family: seam-change-collateral
    title: |
      stop_scope now closes a scope for good and tasker.run refuses into it, but the atlas says neither
    detail: |
      8th in family. The rule already exists (grep the seam's name); the fix round
      applied it to the review's list, not to the seams it changed itself.
      tool_execution.md:100 still says only that stop_scope stops every process
      of one generation, and lifecycle.md:334-337 omits the refusal. Rule-level
      fix: each round's close greps every public function whose body the round
      changed across atlas/, fix rounds included. Instance: document the refusal,
      the 1024-key bound, and what happens to an evicted key.
  - id: new
    severity: Important
    family: behavior-change-without-regression-test
    title: |
      The fix commit's own new cancel_responses batch guard reddens nothing when reverted
    detail: |
      3rd in family. The commit claims every edited site has a red-on-revert test,
      but the sweep covered the prior review's list, not the commit's own new
      hunks. Reverting chat_respond.lua:1357 leaves chat_cancel_entry,
      batch_lifecycle, batch_respond, batch_validation_budget, chat_stop_generation
      and generation_settles green. Rule: the mutation sweep runs over every
      behavior-changing hunk of the whole boundary diff, including the fix round's.
  - id: new
    severity: Minor
    family: allowlist-without-dead-entry-check
    title: |
      The WAITS check always passes for the 7 citations that name generation_settles_spec itself
    detail: |
      generation_settles_spec.lua:379 does a raw-text find over the named file, and
      that file contains the WAITS list with every case name in it. Renaming the W11
      case left the check green. Fix: match `it(` followed by the case name, and
      strip the WAITS block before searching.
  - id: new
    severity: Minor
    family: stateless-double-at-stateful-seam
    title: |
      No chat-level spec can reach W5's zero-match branch, though the plan says they now do
    detail: |
      4th in family. Instrumenting response_provider.lua:125 gave 0 hits across the
      six chat specs and generation_settles; the only hits came from
      response_provider_spec. The dispatcher.query doubles register calls
      synchronously (no pre_query window), and the stop_owner double only marks a
      call stopped through its own stop. Rule: a double models every phase of the
      seam the consumer branches on, and a claim that a test level takes a branch
      is measured, not inferred. plan:2215 claims otherwise.
```

---

## Re-review — 2026-09-19T10:57:35-07:00 (FIX-THEN-SHIP)

| field | value |
|-------|-------|
| issue | 261 — Audit transcript as the complete recovery state |
| repo | parley.nvim |
| issue file | workshop/issues/000261-audit-transcript-recovery-state.md |
| boundary | milestone M4 |
| milestone | M4 |
| window | 31ca6eb92e68d51572692e266d4801bc4524d9e0..57ba424d2178e6fc8687901cad10b7dbbdfa9938 |
| command | sdlc milestone-close --issue 261 --milestone M4 |
| reviewer | claude |
| timestamp | 2026-09-19T10:57:35-07:00 |
| verdict | FIX-THEN-SHIP |

## Review

```verdict
verdict: FIX-THEN-SHIP
confidence: high
```

Round 2 holds up under counterfactual testing: I reverted each claimed fix in its own scratch export of HEAD and all but one went red. W16's new condition is pinned from both directions (keying on `not s.handle`, or sending the cancel without waiting for the handle, each fail the new `response_topic_spec` case); the `cancel_responses` batch guard now reddens `batch_lifecycle_spec`; the WAITS check can no longer vouch for its own entries (renaming the W11 case fails it, and a counterfactual case pins that); and the stopped-scope refusal is documented with its 1024-key bound. `make test` on a clean export of HEAD is green apart from one load-sensitive perf flake (`perf_ownership_spec` passes alone) and `fresh_clone_spec`, which fails only in a scratch tree and passes in the real checkout. What keeps this from SHIP is the same rule this round was supposed to close, applied one level wider: round 1's sweeps reached the sites the review listed, and this round's reached round 1's — but neither reached the seams M4's *original* commits changed. `copilot.pre_query` gained an error argument in Task 4.3, and `dispatcher.lua:884` still tells adapter authors that a one-arg `pre_query` (naming copilot) is fine, which is the hazard W6 closed. And one W15 site (`chat_respond.lua:1728`) still reddens nothing on revert, so BR-48 is not fully addressed.

## 1. Strengths

- **The W16 fix is the right shape and is pinned both ways.** `response_topic.lua:48-55` now distinguishes "the request threw" (`start_threw`) from "no handle yet"; I mutated the condition back to `not s.handle` and separately widened `elseif s.handle` to `else`, and each fails `answers a stop that arrives during its request once the request returns`. Dropping `s.start_threw=true` at `:87` also reddens the W16 case.
- **The batch-guard test is a real one**, not an assertion about `pcall`: it makes a live batch's `cancel` throw and then waits for the transport to actually see the cancel (`batch_lifecycle_spec.lua:60-70`). Reverting `chat_respond.lua:1357` fails it.
- **The WAITS check was fixed at the mechanism, not the symptom** (`generation_settles_spec.lua:364-375`): it strips the list, then matches a real `it(`/`describe(` opener, and a counterfactual case asserts both directions. Renaming `W11: a continuation whose start threw` now fails the check; under the old raw `find` it stayed green.
- **The W5 claim was measured and retracted rather than defended.** `respond_fixture.lua:9-16` now says the fixture registers calls synchronously so no chat spec reaches the branch, and points at `response_provider_spec` where it is pinned — an honest downgrade of a claim the previous round had written from how the double looked.
- **The atlas refusal text matches the code exactly**, including the eviction consequence: `tool_execution.md:103-109` states the 1024 bound and that a forgotten key is admitted again bounded by its deadline, and `content_run` (`oauth.lua:1356-1357`) does set a deadline on every content spawn, so that claim holds for the chains that can actually resume.

## 2. Critical findings

None.

## 3. Important findings

**A seam M4 changed still has its old contract restated in the dispatcher's own docs** (`lua/parley/dispatcher.lua:884-885`, `atlas/providers/cliproxy-managed.md:257-266`).

*This is the 9th finding in family `seam-change-collateral`.* Do not patch these two sites. The rule exists twice already and got narrower each time it was written: round 1's lesson said "every restatement — prose, comments, doubles — enumerated by grepping the seam name and the old claim"; round 2's narrowed it to "grep each changed public function's name across `atlas/`", which excludes code comments, and both rounds enumerated from *the review's list of seams* rather than from the change's own list. The enumeration that covers all nine instances already exists in this plan: it is the W-table. Rule: **at the boundary, every W-row (or equivalent change row) whose fix alters a seam's contract gets its own `grep -rn <seam name> lua/ atlas/ tests/`, and the as-built records the hit list with each hit's disposition (updated / unaffected). The fix rounds' rows are appended to the same table.** Measured instances this round, both from rows nobody re-grepped:
- `dispatcher.lua:884-885` — "a one-arg `pre_query` (e.g. copilot) simply ignores the error callback the dispatcher passes it". W6 (`providers.lua:1079-1081`) made copilot two-arg precisely because a `pre_query` that never reports its failure leaves the request waiting; after M4 no production adapter is one-arg, so the doc now names the wrong example *and* blesses the hazard for the next adapter author.
- `atlas/providers/cliproxy-managed.md:257-266` — the "claim contract" enumerates falsy / truthy / no-hook, but W8 added a third precondition ahead of all of them: `transport_alive(transport_opts)` at `dispatcher.lua:808`, so a stopped owner never reaches the hook and takes `deliver()` instead.

## 4. Minor findings

- **The topic's cancel-through-a-handle is written twice and settles differently in each copy** (`response_topic.lua:49-55` vs `:89-94`). *2nd in family `partial-guard-window`.* Round 2 created an obligation — "a stop arriving while the request is still being made is answered once the request returns, below" — and `request()` discharges it only on its *normal* exit. I measured the other exit with a probe case (a fake whose `request` stops the topic re-entrantly and then throws): `stop()` at `:87` returns `false` because `s.stopping` is already set, and the topic sits in `stopping` forever, holding its generation and two user captures. The same asymmetry covers two more outcomes the deferred copy ignores: it is not `pcall`ed (the inline copy is), and neither copy looks at `cancel_operation`'s `false` return, which means "I did not accept your cancel" — ARCH-ORDER, uncertainty collapsed into success. Not reachable through `response_provider`'s adapter today (its only throws are the entry asserts, before any callback, and it always returns a handle), which is why this is Minor. Fix the class: one `cancel_through(s, handle)` used by both sites, handling throw / falsy-return / deferred-resolve, with the deferred caller retiring when the cancel was not accepted.
- **The Core-concepts `tasker` row still does not carry the refusal** (`plan:113`). *3rd in family `plan-tracking-not-updated`.* The previous round recommended it explicitly; round 2 applied its other three plan revisions and recorded the refusal in the Revisions prose (`plan:2249`, `:2265`) but not in the greppable table the review cross-checks. Rule: **a round's revision entry enumerates the prior review's plan-revision recommendations and marks each applied or declined-with-reason, so a silently dropped one is visible.**

## 5. Test coverage notes

All runs are in `git archive` exports of HEAD with isolated `HOME`/`XDG_*`/`TMPDIR`; each mutation is its own copy.

- **Red on revert (fix confirmed):** W16's condition, two ways (`m52a`, `m52b`); `s.start_threw` (`m52c` → `retires when its provider request throws`); the `cancel_responses` batch guard (`m58` → `batch_lifecycle_spec`); the office temp dir (`mtmp` → `unscoped_kill_spec`, 2 cases); the WAITS matcher (renamed W11 case).
- **Green on revert (gap):** `chat_respond.lua:1728`, the W15 terminal-handler guard, reverted to its base unguarded form — `chat_cancel_entry_spec`, `branch_topic_input_spec`, `topic_presentation_spec`, `chat_stop_generation_spec`, `chat_scoped_response_spec`, `generation_settles_spec`, `chat_onboarding_capture_spec`, `chat_remote_preparation_spec`, `batch_lifecycle_spec`, `batch_respond_spec`, `chat_ownership_spec`, `chat_pending_spec` all pass.
- **Full suite:** `make test` (lint + 6-way fan-out) on the export — lint clean, every file passing except `perf_ownership_spec` (passes alone; timing under parallel load) and `fresh_clone_spec` (a scratch-tree artifact: 3/3 green in the real checkout).
- The impact of the one gap is bounded: a throwing topic cancel there skips `release()`, which only unhooks Stop/UI membership (`chat_respond.lua:1507-1513`) and cannot hold an admission slot — which is why the right fix is evidence, not urgency.

## 6. Architectural notes

- **ARCH-DRY — flag (Minor above).** One `stop_owner` double with an arch guard, one `with_stub`, one `guarded`, one `finish` — all good. The exception is the duplicated `cancel_operation` call in `response_topic`, and the divergence is exactly where the bug lives.
- **ARCH-PURE — pass.** The new code is thin glue; `fault` still puts a terminal decision in the shell, but `s.final_outcome` now gives it one authority.
- **ARCH-PURPOSE — pass.** The W-table's shadow sweep is complete (18 rows, one drop argued from the machine's accept rules), and the end-to-end cases drive every stop cause the Done-when names.
- **ARCH-MOCK — flag, already disposed (BR-60).** The chat-level doubles cannot reach W5's branch; the claim was corrected rather than the double extended, and W5 is pinned at the adapter, which is where the branch lives.
- **ARCH-CONSTRAINTS — pass.** The stopped-scope lookup is an O(1) hash probe on the spawn path; eviction is O(n) but runs only on a stop past 1024 keys.
- **ARCH-SECURE — pass.** `failed()` in `vault.lua` carries only `exit_reason` text; the new refusal string carries a scope key, not user content.
- **ARCH-ORDER — pass with the Minor.** `fault` has one authority for "terminal" now. `response_topic` remains a constellation of `started`/`stopping`/`finished`/`resolved`/`start_threw`/`handle` whose legal combinations are unwritten — round 2 added a sixth implicit state ("stopping, no handle, request in flight"), and the unreachable-today stuck case is in the difference. For M5, a tagged phase on the topic would collapse it.
- **ARCH-FUNERAL — pass.** `stopped_scopes` is bounded with eviction and reset; the per-run skill augroup is deleted by `release_owner` on every exit path.

## 7. Plan revision recommendations

- **Core concepts, `tasker` row** (`plan:113`) — add that `stop_scope` records the key and `run` refuses a scoped run into a recorded one (1024, oldest evicted).
- **W16 as-built** — record that the deferred cancel discharges only on `request`'s normal exit, and either name the helper that covers the throw/falsy-return exits or state the residual and why it is unreachable through `response_provider`.
- **W15 as-built** — record that `chat_respond.lua:1728` has no site-level test (the WAITS row cites a helper test), and name the enforcement chosen: an arch check that `response_topic').cancel` appears only inside `cancel_topic`, or a terminal-path case with a throwing cancel.
- **Boundary sweep** — add the per-W-row grep ledger described in the Important, covering the fix rounds' own rows.

```findings
dispose:
  - id: BR-52
    disposition: addressed
    note: |
      Measured: keying on `not s.handle`, or widening `elseif s.handle` back to `else`, each fails the new stop-during-request case.
  - id: BR-57
    disposition: addressed
    note: |
      tool_execution.md:103-109 documents the refusal, the 1024 bound and the evicted key; lifecycle.md:337 says the scope stays closed. Matches tasker.lua:389-393,500-502.
  - id: BR-58
    disposition: addressed
    note: |
      Reverting chat_respond.lua:1357 fails batch_lifecycle_spec's new throwing-batch-cancel case.
  - id: BR-59
    disposition: addressed
    note: |
      `declares` strips the WAITS block and matches a real it(/describe( opener; renaming the W11 case now fails the check, and a counterfactual case pins both directions.
  - id: BR-60
    disposition: addressed
    note: |
      The claim is retracted in respond_fixture.lua:9-16 and plan Revisions; W5 stays pinned at response_provider_spec, which is where the branch lives.
  - id: BR-48
    disposition: not-addressed
    note: |
      The W15 terminal-handler site (chat_respond.lua:1728) still reddens nothing: reverted to its base unguarded form, 12 related specs stay green. The WAITS W15 row cites a test of the shared helper, not of this site.
findings:
  - id: new
    severity: Important
    family: seam-change-collateral
    title: |
      The dispatcher still documents a one-arg pre_query, naming copilot, after W6 made it two-arg
    detail: |
      9th in family. Do not patch the sites. The rule was written twice and narrowed
      each time (round 2's lesson limits the grep to atlas/, excluding comments), and
      both rounds enumerated from the review's list of seams rather than the change's
      own. The enumeration that covers all nine already exists: the W-table. Rule -
      every change row whose fix alters a seam's contract gets its own
      `grep -rn <seam name> lua/ atlas/ tests/`, and the as-built records the hit list
      with each hit's disposition; fix-round rows are appended to the same table.
      Measured instances, both from rows nobody re-grepped: dispatcher.lua:884-885
      still says a one-arg pre_query "(e.g. copilot) simply ignores the error callback",
      which is the hazard W6 closed and names the wrong example, since providers.lua:1079
      is now two-arg and no production adapter is one-arg; and
      atlas/providers/cliproxy-managed.md:257-266 enumerates the claim contract as
      falsy/truthy/no-hook without W8's new precondition, the transport_alive check at
      dispatcher.lua:808 that stops a dead owner reaching the hook at all.
  - id: new
    severity: Minor
    family: partial-guard-window
    title: |
      The topic's deferred cancel discharges only on the request's normal exit
    detail: |
      2nd in family. Round 2 made a stop during the request wait for the handle
      (response_topic.lua:49-55), but request() answers that obligation only when it
      returns normally (:89-94). Probed with a fake whose request stops the topic
      re-entrantly and then throws: stop() at :87 returns false because s.stopping is
      already set, and the topic sits in `stopping` forever holding its generation and
      two user captures. The deferred copy is also not pcall-ed while the inline copy
      is, and neither copy reads cancel_operation's false return (ARCH-ORDER,
      uncertainty collapsed into success). Unreachable through response_provider today,
      hence Minor. One cancel_through(s, handle) helper covering throw, falsy return
      and deferred resolve removes the divergence (ARCH-DRY).
  - id: new
    severity: Minor
    family: plan-tracking-not-updated
    title: |
      The Core-concepts tasker row still omits the stopped-scope refusal the prior round asked for
    detail: |
      3rd in family. plan:113 lists tasker's surface without stop_scope's recording or
      run's refusal; the fact lives only in the Revisions prose (plan:2249, :2265), and
      the greppable table the review cross-checks is what went stale. Round 2 applied
      the prior review's other three plan-revision recommendations and dropped this one
      silently. Rule: a round's revision entry enumerates the prior review's
      plan-revision recommendations and marks each applied or declined-with-reason.
```

---

## Re-review — 2026-09-19T11:34:39-07:00 (FIX-THEN-SHIP)

| field | value |
|-------|-------|
| issue | 261 — Audit transcript as the complete recovery state |
| repo | parley.nvim |
| issue file | workshop/issues/000261-audit-transcript-recovery-state.md |
| boundary | milestone M4 |
| milestone | M4 |
| window | 31ca6eb92e68d51572692e266d4801bc4524d9e0..ac958dc5525fa1c5c14b1a2379e4746a9e5a5fa1 |
| command | sdlc milestone-close --issue 261 --milestone M4 |
| reviewer | claude |
| timestamp | 2026-09-19T11:34:39-07:00 |
| verdict | FIX-THEN-SHIP |

## Review

```verdict
verdict: FIX-THEN-SHIP
confidence: high
```

Round 3's code fixes hold up when each one is reverted. I exported HEAD to a scratch tree, confirmed lint is clean and every spec file passes except `fresh_clone_spec`, then reverted each claimed fix on its own:
- **W15 terminal site (`chat_respond.lua:1728`):** fails the new onboarding case.
- **`cancel_through`:** the refused-cancel check fails its case, and the request-throw branch fails its case. Restoring the whole round-2 `response_topic.lua` fails both new topic cases.
- **Plan and atlas:** the `tasker` row and the `transport_alive` precondition are fixed as recommended.

`fresh_clone_spec` failing is a scratch artifact: the real repo force-tracks `construct/generated/vocabulary/issue.json`, which my scratch `git add -A` skipped as ignored. The previous round found it passes in the real checkout.

What keeps this from SHIP is BR-61. The seam ledger it asked for exists, but the W6 row leaves out a hit that its own `grep -rn pre_query … tests/` returns. The dispatcher's unit spec still has a case named "backward compatible" whose one-arg `pre_query` double is commented "one-arg adapter ignores the error cb the dispatcher passes". That is the exact contract W6 and this round's doc fix removed. There is also one new Minor: two exits of the new `cancel_through` helper have no test that fails when they are reverted.

## 1. Strengths

- **`cancel_through` fixes the class, not the instance** (`response_topic.lua:46-52`). One helper serves both the direct and the deferred cancel. It retires on a thrown or refused cancel. The deferred caller at `:103` and the request-throw branch at `:88` now answer the pending stop on every exit from the request.
- **The W15 terminal-site test drives the real handler** (`chat_onboarding_capture_spec.lua:79-102`). A refused completion leads to a failed finalize while the topic is running. The topic cancel throws, and the test checks that the cleanup after it (`finalize_mutated_api_leg`) still runs. With only `:1728` reverted to the raw call, it fails.
- **The round-3 revision records how each prior recommendation was handled** (`plan:2292-2311`). That is the BR-63 rule, applied.
- **The atlas claim contract matches the code.** `cliproxy-managed.md:260-263` agrees with `dispatcher.lua:808-809`: the hook is skipped when `transport_alive` is false, and `deliver()` runs instead.

## 2. Critical findings

None.

## 3. Important findings

**BR-61, not addressed: the W6 ledger row misses a stale test double** (`tests/unit/dispatcher_query_spec.lua:602-607`, `tests/integration/response_provider_spec.lua:89`).
- The H2 case is titled "pre_query success runs the query as before (backward compatible)". Its double is `pre_query = function(on_success)`, with the comment "one-arg adapter ignores the error cb the dispatcher passes".
- The ledger's scope line (`plan:2313-2316`) covers only "prose (comments and docs)" and leaves out call sites. In practice it also left out **doubles**, which round 1's rule names explicitly ("prose, comments, and doubles alike"). That is the same narrowing BR-61 described.
- The new guard (`spawn_seam_spec.lua:445`) scans only `lua/**`. The stop_owner double guard in the same file (`:426`) does scan `tests/**`.
- **Rule-level fix, not a site patch:**
  - A ledger row lists every grep hit that defines or describes the seam: prose, comments and doubles. Only pure call sites are excluded.
  - The `pre_query` guard also scans `tests/**`, so a one-arg double fails it the way a stop_owner copy does.
- The instances then fall out: make H2's double two-arg and drop "backward compatible" and the comment. `response_provider_spec.lua:89` also gets `(fn, _on_error)`.

## 4. Minor findings

**New: two exits of `cancel_through` fail no test when reverted** (`response_topic.lua:47`, `:60`).
- **This is the 4th finding in family `behavior-change-without-regression-test`.** Earlier rounds wrote the rule twice: "red on revert per edited site", then "the sweep covers the fix round's own hunks". Round 3 met it for BR-48, but its own evidence was a whole-file revert. The plan says "they are red on the old code" (`plan:2306`), and that does not prove any single hunk is covered.
- Measured:
  - **Throw exit:** with the pcall removed, 6 specs stay green: `response_topic`, `chat_onboarding_capture`, `topic_presentation`, `branch_topic_input`, `chat_stop_generation` and `generation_settles`. No test makes a topic's `cancel_operation` throw. The pcall came in with a2ee8102 and has never had a test.
  - **Direct site:** reverting `:60` to the old inline copy, which ignores a `false` return, leaves `response_topic_spec` passing 16/16.
- Both exits are unreachable through `response_provider` today, hence Minor.
- **Rule:** record counterfactuals per hunk in a mutation ledger next to the seam ledger. Each row is hunk → mutation → the test that failed, or "none, unreachable because X". A revert of a whole file or commit counts as evidence for no individual hunk.

## 5. Test coverage notes

- **Setup:** a `git archive` export of HEAD with isolated HOME, XDG and TMPDIR.
  - Lint: 0 warnings and 0 errors across 640 files.
  - Unit and integration: 382 spec files pass. The only failure is `fresh_clone_spec`, which is a scratch-tree artifact.
- **Fails on revert (fix confirmed):**
  - The W15 terminal site (m48).
  - The `accepted==false` check (m62a).
  - The request-throw branch (m62b).
  - The whole pre-round-3 `response_topic.lua` (m62, 2 cases).
- **Passes on revert (gap):**
  - The `cancel_through` pcall (m62d).
  - The direct-site refused-cancel exit (m62c).
- The parametrized "retires when …" cases don't assert `final.status`. The refused case retires `failed` even after an operator stop. No consumer reads the status today (`chat_respond.lua:1554`), but the case pins nothing about it.

## 6. Architectural notes

- **ARCH-DRY: pass.** Two cancel copies became one.
- **ARCH-PURE: pass.** The changes are thin glue code.
- **ARCH-PURPOSE: flag (BR-61).** The shadow-sweep missed a test double.
- **ARCH-MOCK: flag (BR-61).** Two `pre_query` doubles still model the retired one-arg contract, and the guard can't see them.
- **ARCH-CONSTRAINTS: pass.** The guard is a line scan inside an arch test.
- **ARCH-SECURE: pass.** No new parsing. Error text stays capped at 512 characters.
- **ARCH-ORDER: pass, with one note.** After a refused or thrown cancel, the topic retires while its request may still be running. Nothing calls `stop_scope` for a topic's generation; `response_session.lua:234` is the only caller. The comment at `:42-45` should say the request runs until it ends on its own. That is reasonable while the path is unreachable.
  - For M5: the topic is still a set of independent flags (`started`, `stopping`, `finished`, `resolved`, `start_threw`, `handle`). A tagged phase would replace them.
- **ARCH-FUNERAL: pass.** Round 3 creates nothing that persists.

## 7. Plan revision recommendations

- **Seam ledger W6 row** (`plan:2324`): add `dispatcher_query_spec.lua:602-607` and `response_provider_spec.lua:89` with their dispositions. Change the scope line to "prose, comments and doubles; only pure call sites excluded".
- **Round-3 W16 as-built** (`plan:2306`): replace "red on the old code" with the per-hunk result. Either name tests for the throw exit and the direct-site refused exit, or state that they are unreachable through `response_provider`.

```findings
dispose:
  - id: BR-48
    disposition: addressed
    note: |
      Reverting only chat_respond.lua:1728 to the raw response_topic.cancel call fails chat_onboarding_capture_spec "finishes its ending cleanup when the topic cancel throws"; round 2 confirmed the Copilot forward and oauth sites.
  - id: BR-61
    disposition: not-addressed
    note: |
      Named sites fixed and ledger built, but the W6 row omits dispatcher_query_spec.lua:602-607 (H2 "backward compatible", one-arg double commented "one-arg adapter ignores the error cb") and response_provider_spec.lua:89; ledger scope excluded doubles, and the new guard scans lua/ only while the stop_owner guard (:426) scans tests/.
  - id: BR-62
    disposition: addressed
    note: |
      cancel_through (response_topic.lua:46-52) serves both sites; reverting accepted==false (m62a) or the request-throw branch (m62b) each fails its new case. Untested throw exit raised separately.
  - id: BR-63
    disposition: addressed
    note: |
      plan:113 tasker row now records stop_scope's key and run's refusal (1024, oldest evicted); plan:2294-2311 disposes each prior recommendation.
findings:
  - id: new
    severity: Minor
    family: behavior-change-without-regression-test
    title: |
      cancel_through's throw exit and the direct site's refused-cancel exit fail nothing when reverted
    detail: |
      4th in family. Rule: record counterfactuals per hunk in a mutation ledger next
      to the seam ledger (hunk -> mutation -> failing test, or "none, unreachable
      because X"); a whole-file or whole-commit revert is not evidence for any single
      hunk. plan:2306's "red on the old code" was a whole-file revert. Measured:
      removing the pcall at response_topic.lua:47 leaves response_topic,
      chat_onboarding_capture, topic_presentation, branch_topic_input,
      chat_stop_generation and generation_settles passing (no test makes a topic's
      cancel_operation throw; the pcall came in with a2ee8102). Reverting :60 to the
      old inline copy that ignores `false` leaves response_topic_spec 16/16 passing.
      Unreachable through response_provider today.
```

---

**A side effect of this review:** my first scratch-setup command left files in your home Git repo.
- **Cause:** `mktemp -d /tmp/...` failed, and the script kept going with an empty path. It ran `git init` and `git add -A` in your home directory, where a `~/.git` already existed.
- **What I did:** I stopped it after about 1.5 minutes. Your home repo's index is unchanged (still the 5 Jul file), no commit was made, and nothing was sent anywhere.
- **What it left:** it did write, all dated 11:24–11:25 today:
  - about 12,455 unreferenced loose objects in `~/.git/objects/`;
  - a ~210 MB `~/.git/objects/pack/tmp_pack_xeEUQI`.
  - These blobs are compressed copies of files from your home directory, so they may include sensitive files. They are only in `~/.git`, with the same permissions.
- **Already there before this session:** a ~2 GB `tmp_pack_sH6Lx7` from 01:11 and about 17.6k older loose objects. They look like an earlier incident of the same kind; I didn't touch them.
- **Cleanup:** I haven't deleted anything. Whether to clean up is your call.
  - `rm ~/.git/objects/pack/tmp_pack_xeEUQI` removes the stray pack from this session.
  - `git -C ~ prune --expire=now` removes all unreferenced loose objects. That includes the older ones, so check first that you don't need anything from that repo.
- **Stopping a repeat:** since then, every scratch path is checked before it's used. The scratch copies from this review have been removed.
