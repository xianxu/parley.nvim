# Boundary Review — parley.nvim#261 (milestone M3)

| field | value |
|-------|-------|
| issue | 261 — Audit transcript as the complete recovery state |
| repo | parley.nvim |
| issue file | workshop/issues/000261-audit-transcript-recovery-state.md |
| boundary | milestone M3 |
| milestone | M3 |
| window | 8a753815ca9754084a75902f1f1c368ed5e54371..5086f24fc6f96c68bfdc144f052a84eca755855f |
| command | sdlc milestone-close --issue 261 --milestone M3 |
| reviewer | claude |
| timestamp | 2026-09-19T03:51:20-07:00 |
| verdict | FIX-THEN-SHIP |

## Review

```verdict
verdict: FIX-THEN-SHIP
confidence: high
```

M3 delivers what it claims at the code level, and I verified it rather than taking the commits' word: I re-ran both counterfactuals the plan asserts (restoring main's `detach = true` turns all three live-conformance cases red; making `target()` return `state.pid` instead of `-state.pid` turns 8 of the 12 new sequence tests red, including 2 and 3), ran 25 tasker/dispatcher/tool specs plus the three new/changed ones — all green — and `make lint` is 0/0 over 636 files. The pure lifecycle in `attempt.lua` is the strongest part: an explicit `(state, event) -> (state, effects)` reducer with a `drive` harness that injects event ordering deterministically and asserts *when* each effect fires, which is exactly what ARCH-ORDER asks for. Nothing here blocks the boundary. What holds it back from SHIP is a class the diff opened and swept only partway: the `code`/`io_error` seam contract changed, and the consumers that *render* those fields (rather than branch on them) were not swept — one of them writes "curl exited with code nil" into the user's transcript — and the same rule left `README.md` still telling users that Stop keeps running tools alive. Separately, the new atlas section quantifies over "every process Parley starts" and "every live process" when five families of spawn sites live outside the tasker seam and are absent from its own "Residuals, stated once" list.

## 1. Strengths

- `lua/parley/attempt.lua:25-31,73` — `open_stop_window` plus the `is_unresolved → reconcile_due = nil` invariant collapses the whole stop lifecycle into one place, and `tests/unit/attempt_spec.lua:54-76`'s `drive` harness is a real ordering seam: it replays sorted events against the reducer's own `reconcile_due` and asserts effect *timestamps* (`{3000}` escalate, `{6000}` unresolved), not just that an effect happened. Sample-size-one interleaving is exactly what ARCH-ORDER flags, and this avoids it.
- `lua/parley/tasker.lua:209-226` — `target()` (pure) / `send()` (IO) replaces three copy-pasted `pcall(kill) → ESRCH → observation` blocks at `reconcile_step`, `cleanup_stale_handles` and `stop_matching`. The ESRCH-is-an-observation change also fixes the old `scoped_stop` raise that skipped the caller's remaining cleanup.
- `lua/parley/tasker.lua:504-510` — putting "`code` is nil whenever `io_error` is set" at the *source* instead of adding `or io_error` at 16 call sites is the right ARCH-DRY call, and I confirmed it holds: every census callback tests `code ~= 0` / `code == 0`, so all of them now read a kill as failure with no per-site edit.
- `tests/integration/process_group_conformance_spec.lua` — a live check against the kernel on every `make test`, using `kill -0 -- -$$` rather than `ps`, and running the third case through the real `find` builtin + `process_bootstrap`. I confirmed all three go red on main's spelling. This is the ARCH-MOCK contract done properly: fake and production share the `M._uv` boundary, and drift is measured.
- `lua/parley/oauth.lua:568-571,821-826,865-874` — the unread-store weak set is a genuinely good answer to the empty-store hazard: it is identity-keyed, `__mode="k"` so it needs no cleanup, and I traced every `load_account_store → save_account_store` path (`:894`, `:1006`, `:1148`, `:2353`, `:2457`) to confirm the same table object is threaded through, so the guard can't be bypassed by a copy.

## 2. Critical findings

None.

## 3. Important findings

**A. `lua/parley/oauth.lua:1424` — a killed content fetch writes "code nil" into the transcript and drops the reason it has.**
`_fetch_public_content`'s callback takes `(code, _, stdout_data)` and formats `tostring(code)`. Post-M3 `code` is nil on every failure, so a deadline kill produces `Remote URL fetch failed: curl exited with code nil for <url>` — and that string is cached as the URL's error text and rendered in the chat. The `io_error` that says `killed: deadline` is available as the 5th argument and discarded. `tests/integration/unscoped_kill_spec.lua:103` asserts only that the body is not used; the spec run prints the degraded message itself. This is the Done-when clause "User-visible errors identify the recoverable action" failing on the one path M3 changed. Fix: take `io_error` and render `io_error or ("exit " .. tostring(code))`.

**B. `README.md:115-117` — the README still states the guarantee M3 inverted.**
"…while the process supervisor keeps tools that are still running and their resource claims." After M3, `:ParleyStop` reaches a scoped tool record through `stop_attempt → target() → -pid`, TERMs the group and escalates to SIGKILL at 2 s, so the process ends and its claim is released — which is what `tests/manual/chat-concurrency.md:48-51` now instructs the operator to verify. `atlas/chat/lifecycle.md` and `atlas/providers/tool_execution.md` were both updated in this range; README was not.

**C. `atlas/providers/tool_execution.md:71,113` — the new section quantifies over all processes, but five spawn families live outside the tasker seam and none is in its own residuals list.**
"Every process Parley starts is scoped or unscoped (`lua/parley/tasker.lua`, #261)" and "`tasker.leave()`: SIGKILL to every live process" are both false as written. Outside the seam: `cliproxy.lua:665` (`uv.spawn`, `detached = true`, `uv.unref`, whose own docstring says it is spawned "so it outlives nvim" — a *deliberate* counterexample to the leave claim); `cliproxy.lua:1380` (`jobstart`); ~13 `vim.system` calls in `cliproxy.lua`; `git_markdown_source.lua:140` (`uv.spawn` with its own TERM-only cancel, no group, no deadline, no escalation); and the synchronous `vim.fn.system` fallbacks in `tools/builtin/{ls,grep,find,ack,chat_history_search}.lua` plus `init.lua:4740`. The "**Residuals, stated once**" list names a kernel hold, a secret command's grandchild and an nvim crash — not these.

## 4. Minor findings

- `lua/parley/chat_respond.lua:1049` — `transport_opts = transport_opts or {…}` *replaces* rather than merges; a caller passing partial opts (no generation, no deadline) silently loses the deadline and is refused at spawn. One production caller today (`init.lua:4429`, passes nothing), but M4's W16 touches topic generation and is the likely trigger. Prefer `transport_opts = transport_opts or {}` then set `deadline_ms` only when unscoped and unset.
- `tests/helpers/fake_process.lua:95-113` — the group path always delivers the signal and ignores `process.probe` and `process.signal_result`, while the pid path honours `probe`, `signal_result` and `opts.finish_on_signal`. One double with two signal semantics: a scoped record can never be made to observe `unknown`/EPERM, and test 7 needs `finish_on_signal` while test 1 does not.
- `lua/parley/tasker.lua:212-216` — `target()` has no `state.pid == 0` guard. `-0 == 0` in Lua, so a zero pid would send the signal to Neovim's own process group. Unreachable today (luv never returns 0), but the fake added `if pid == 0 then error(...) end` precisely because the failure is catastrophic; the production side should be at least as defensive.
- `lua/parley/tasker.lua:564-571` — the one-shot deadline timer is closed only by `retire`. A record that goes unresolved-visible and is never retired keeps the (already-fired) uv handle. Bounded by held records, so small, but it is a handle with no removal path on the one code path that by definition never retires.
- `lua/parley/attempt.lua:29-30` duplicates the `reconcile_started/due/delay` assignment in the `reconcile_requested` branch at `:41`; one shared `open_probe_window(state, now)` would do.
- `atlas/traceability.yaml:282` routes `unscoped_kill_spec.lua` to `chat/response_progress`, but the claims it proves ("killed at 600 s", "an unfinished keychain read is neither cached nor saved") are the ones added to `atlas/infra/vault.md`. `make test-changed` on that page will not run the spec that defends it.

## 5. Test coverage notes

Coverage is strong and the counterfactual discipline is real, not asserted — I reproduced both. The 12 sequence tests in `tasker_supervision_spec.lua:150-292` cover every row of the plan's ARCH-ORDER table including the two hard ones (parent already exited + grandchild holding the pipe; a stop after the window went visible), and `attempt_spec` covers the pure reducer without IO. Two gaps:

- No test pins the *diagnostic* of a killed unscoped run — only that the result isn't used. That is exactly the hole finding A fell through: `unscoped_kill_spec.lua:103` would still pass with "code nil" in the message. An assertion that the content-fetch error text contains `killed:` (or at least contains no `nil`) closes it and would go red on the current code.
- `tasker_run_spec.lua:913` moved the failed-signal-retry case from a scoped attempt to an unscoped one, so no test exercises a *group* signal returning `unknown`/EPERM. The fake cannot express it (see the Minor above), which is why the case moved rather than being extended — the fake's asymmetry is what removed the coverage.

## 6. Architectural notes for upcoming work

Marker-by-marker: **ARCH-DRY** pass — `scope_key` retires both hand-built spellings (`response_provider.lua:103`, `producer.lua:120`; I swept for survivors and found none), `tasker.deadline` is the only source of every deadline literal in `lua/`, and `send`/`close_timer`/`call_safely` are real consolidations. **ARCH-PURE** pass — `attempt.lua` stays pure and its tests need no fake; `target` pure / `send` IO is a clean split. **ARCH-PURPOSE** pass on the code — I ran the shadow sweep on both new single sources and every consumer derives; `stop_scope`/`held` having no production caller yet is *not* a dead handle, because the plan names their consumers at Task 4.1 and M5 §refusals. Flagged on the docs (finding C). **ARCH-MOCK** pass with the Minor above. **ARCH-CONSTRAINTS** pass — every deadline has a kind, a value and a stated basis, and the reconcile clamp keeps KILL at exactly 2 s instead of the next back-off tick. **ARCH-SECURE** pass — the pgid-reuse window is stated in the plan and is genuinely narrow (POSIX will not reuse a pgid while a member lives, and a live member is what keeps the record unresolved); Minor on the pid-0 guard. **ARCH-ORDER** pass, best-in-diff. **ARCH-FUNERAL** pass — the `ParleyLeave` augroup is `clear = true` and tested for idempotence, the weak store set self-collects, the deadline timer retires with its record (Minor exception noted).

For M4/M5:
- The `attempt` state is still a constellation — `stop_requested`, `kill_due`, `escalated`, `unresolved_visible`, `signalled`, `stop_cause`, `exited`, two EOFs, `spawn_failed`, `delivered`. The legal combinations are written down (in the plan's table) but not in the type, so `escalated = true, kill_due = nil` is representable and undefined. I found no reachable contradiction today, but M4 adds `stopping`/`fault` on top. Deriving a single `phase` tag (`live | stopping | escalated | held | resolved`) inside the reducer, and having `held()`/`stop_matching` read *that*, would keep the growth bounded.
- `scoped_stop` drops the `cause` argument, so `stop_buf`/`stop_scope`/`stop_owner`/`stop_attempt` can only ever produce `killed: stop`. When M4 wires the scope kill and M5 builds the refusal vocabulary, a reload-caused kill and a user Stop will be indistinguishable in `io_error`. Threading `cause` through `scoped_stop` now is a two-line change that M5's "a user Stop is silent, but other `cancelled` paths warn" will need.
- The repo's established answer to "we swept the class" is an arch guard (`tests/arch/single_source_sweeps_spec.lua`, `json_decode_spec.lua`, `untrusted_path_spec.lua`) — and M1's own round-3 log says the findings were "fixed as classes with guards". There is no guard for either of M3's new single sources. A `tests/arch/` sweep asserting (a) no module outside `tasker.lua` spawns a process (`uv.spawn|vim.system|jobstart|vim.fn.system`) except a declared allowlist, and (b) no `deadline_ms` literal outside `tasker.deadline`, would convert finding C from a doc correction into a standing invariant. If you add the allowlist, note family `allowlist-without-dead-entry-check` already fired once on this issue — assert each entry is still live.

## 7. Plan revision recommendations

- **`## Revisions` — M3 Task 3.4, census method.** The step's census command `grep -rn "dispatcher.query(" lua/parley` misses two real call sites: `response_provider.lua:102` (`pcall(dispatcher.query, …)`) and `skill_invoke.lua:412` (`llm.query`, an alias). Both happen to be scoped, so the census *conclusion* (18 sites + 2 streams) is correct and nothing shipped broken — but it is correct by luck, and the record should say so rather than leave a literal-spelling grep standing as the method. Note that what actually makes the enumeration safe is tasker's runtime refusal, not the grep.
- **`## Revisions` — M3 Task 3.7, docs scope.** Record that `README.md:115-117` and the out-of-seam spawners (cliproxy, `git_markdown_source`, the builtin `vim.fn.system` fallbacks) were not covered by the "State the residuals once" bullet, and say which of the two fixes was taken: narrowing the atlas quantifiers to "every process **tasker** starts" plus adding the out-of-seam spawners to the residuals list, or an arch guard over the spawn seam.
- **`## Revisions` — M3 Task 3.4, deadline placement.** The existing 2026-09-19 delta already records that deadlines landed in 3.3; it should also record that `chat_respond.generate_topic` takes the `transport_opts or {…}` replace form (not a merge), since M4's W16 touches the same function and the delta is where M4 will look.

```findings
dispose:
  - id: BR-1
    disposition: addressed
  - id: BR-2
    disposition: addressed
  - id: BR-3
    disposition: addressed
  - id: BR-4
    disposition: withdrawn
findings:
  - id: new
    severity: Important
    family: seam-change-collateral
    title: |
      A killed content fetch writes "curl exited with code nil" into the transcript and drops the io_error that names the cause
    detail: |
      This is the 3rd finding in family `seam-change-collateral`. Do NOT fix
      oauth.lua:1424 alone. The rule: when a seam's contract changes the meaning
      of a value it hands out, sweep every consumer that RENDERS the value, not
      only those that BRANCH on it. Tasker now sets `code = nil` whenever
      `io_error` is set (tasker.lua:504-510); the branchers were swept by
      construction, the renderers were not. The enumeration over tasker exit
      callbacks is four: vault.lua:218 (fixed this round), dispatcher.lua:786
      (already prints io_error), dispatcher.lua:740 (log-only, now reads
      "exit code=nil signal=15"), and oauth.lua:1424 — the only user-visible
      one, which formats tostring(code) into transcript text that is then cached
      as that URL's error. The Done-when clause "User-visible errors identify
      the recoverable action" fails there. unscoped_kill_spec.lua:103 asserts
      only that the body is not used, so it stays green on the bad message.
  - id: new
    severity: Important
    family: seam-change-collateral
    title: |
      README still says Stop keeps running tools and their claims, which M3 inverted
    detail: |
      This is the 4th finding in family `seam-change-collateral`, and the second
      this round — which is the ledger reporting the enumeration was never
      written. Same rule as above, applied to prose consumers: a contract change
      must sweep every STATEMENT of the old contract, not only the code. The Stop
      contract changed (TERM to the group, SIGKILL at 2 s, claim released on
      resolution). atlas/chat/lifecycle.md and atlas/providers/tool_execution.md
      were updated in this range, tests/manual/chat-concurrency.md was updated,
      README.md:115-117 was not: "while the process supervisor keeps tools that
      are still running and their resource claims". The enumeration a boundary
      needs is "every file that states this contract", produced once, not per
      finding.
  - id: new
    severity: Important
    family: enumeration-claims-completeness
    title: |
      The new atlas section quantifies over every process Parley starts, but five spawn families sit outside the tasker seam
    detail: |
      This is the 7th finding in family `enumeration-claims-completeness`.
      Earlier rounds fixed instances. Do NOT fix this instance — state the rule
      and fix that. The rule: a statement quantified over a whole category
      ("every process", "all N sites") must either be produced by an executable
      enumeration over that category, or be scoped in words to the seam it
      actually covers. atlas/providers/tool_execution.md:71 says "Every process
      Parley starts is scoped or unscoped" and :113 says tasker.leave() sends
      "SIGKILL to every live process"; its own "Residuals, stated once" list
      names only a kernel hold, a secret command's grandchild, and an nvim
      crash. Measured exceptions: cliproxy.lua:665 (uv.spawn, detached,
      uv.unref, whose docstring says it is spawned to OUTLIVE nvim — a
      deliberate counterexample), cliproxy.lua:1380 (jobstart), ~13 vim.system
      calls in cliproxy.lua, git_markdown_source.lua:140 (uv.spawn with its own
      TERM-only cancel, no group, no deadline), and the vim.fn.system fallbacks
      in tools/builtin/{ls,grep,find,ack,chat_history_search}.lua plus
      init.lua:4740. The class fix that matches this repo's own convention is an
      arch guard over the spawn seam (tests/arch/), which also makes the atlas
      quantifier true by construction; if it carries an allowlist, note family
      `allowlist-without-dead-entry-check` already fired once on this issue.
  - id: new
    severity: Minor
    family: seam-change-collateral
    title: |
      generate_topic replaces rather than merges transport_opts, so partial opts lose the deadline and are refused
    detail: |
      chat_respond.lua:1049 uses `transport_opts or { deadline_ms = ... }`. One
      production caller today (init.lua:4429, passes nothing), so no defect
      ships. M4's W16 touches topic generation and is the likely trigger: a
      caller passing `{alive = fn}` with no generation gets refused at spawn.
      Set deadline_ms into the table when unscoped and unset instead.
  - id: new
    severity: Minor
    family: stateless-double-at-stateful-seam
    title: |
      The process fake models group signals and pid signals with two different semantics
    detail: |
      fake_process.lua:95-113: the group branch always delivers the signal and
      ignores process.probe and process.signal_result; the pid branch honours
      probe, signal_result and opts.finish_on_signal. A scoped record therefore
      cannot be made to observe unknown/EPERM at all — which is why
      tasker_run_spec.lua:913 had to move its failed-signal-retry case from a
      scoped attempt to an unscoped one, losing that coverage for groups rather
      than extending it.
  - id: new
    severity: Minor
    family: untrusted-input-unparsed
    title: |
      target() has no pid == 0 guard, and -0 == 0 would signal Neovim's own process group
    detail: |
      tasker.lua:212-216. Unreachable today (uv.spawn never yields pid 0, and a
      failed spawn is rejected before the record is armed), but the fake added
      `if pid == 0 then error("signalled Neovim's own process group") end`
      precisely because the failure mode is catastrophic and silent. The
      production side should be at least as defensive as its double.
  - id: new
    severity: Minor
    family: residue-names-no-end
    title: |
      The one-shot deadline timer is closed only by retire, the one path a held record never takes
    detail: |
      tasker.lua:564-571 arms the timer and tasker.lua:191 closes it in retire().
      A record that reaches unresolved-visible is retained by design and never
      retires, so its already-fired uv timer handle is retained with it. Bounded
      by held records, but it is a handle whose only removal path is the one
      branch that by definition does not run.
```

---

## Re-review — 2026-09-19T04:11:34-07:00 (unknown)

| field | value |
|-------|-------|
| issue | 261 — Audit transcript as the complete recovery state |
| repo | parley.nvim |
| issue file | workshop/issues/000261-audit-transcript-recovery-state.md |
| boundary | milestone M3 |
| milestone | M3 |
| window | 8a753815ca9754084a75902f1f1c368ed5e54371..4632ac8864f45ef91d25b6a453d1e70989a33152 |
| command | sdlc milestone-close --issue 261 --milestone M3 |
| reviewer | claude |
| timestamp | 2026-09-19T04:11:34-07:00 |
| verdict | unknown |

## Review

Failed to authenticate. API Error: 401 OAuth access token has been revoked.

---

## Re-review — 2026-09-19T07:53:50-07:00 (FIX-THEN-SHIP)

| field | value |
|-------|-------|
| issue | 261 — Audit transcript as the complete recovery state |
| repo | parley.nvim |
| issue file | workshop/issues/000261-audit-transcript-recovery-state.md |
| boundary | milestone M3 |
| milestone | M3 |
| window | 8a753815ca9754084a75902f1f1c368ed5e54371..4632ac8864f45ef91d25b6a453d1e70989a33152 |
| command | sdlc milestone-close --issue 261 --milestone M3 |
| reviewer | claude |
| timestamp | 2026-09-19T07:53:50-07:00 |
| verdict | FIX-THEN-SHIP |

## Review

```verdict
verdict: FIX-THEN-SHIP
confidence: high
```

M3's round-1 dispositions hold up under independent verification: I re-ran the full suite (`make test JOBS=6` — 381 spec files PASS, `luacheck` 0 warnings / 0 errors over 637 files, exit 0), and confirmed by reverting each fix in a scratch copy that the BR-38 fix goes red in two places (`unscoped_kill_spec` and the new `spawn_seam_spec` raw-code guard) and the BR-42 fake symmetry goes red in the newly parameterised `tasker_run_spec` group case. The new `tests/arch/spawn_seam_spec.lua` is a real guard, not a decoration — I planted a `vim.system` call in `logger.lua` and it failed. What holds this back from SHIP is that the *class* rule BR-38 stated ("sweep every consumer that RENDERS the value") was implemented as "every file that calls `tasker.run(`", and the value crosses one more seam: the dispatcher re-exports `code`/`signal`/`io_error` on its `failure` table, and both of that table's renderers still drop `io_error`. Separately, the BR-40 remedy made the atlas defer to `spawn_seam_spec` as the authoritative list of "how each out-of-seam process ends", but the per-entry reasons are free prose that nothing checks, and two of eighteen are wrong. Three of the four Minors landed correct fixes with no regression test at all — I wrote the tests and confirmed they go red on revert, so the debt is exactly measured, not speculative.

## 1. Strengths

- `tests/arch/spawn_seam_spec.lua` is the right shape for this repo's "we swept the class" convention: exact per-file counts (so a removed spawn fails too), a dead-entry check that answers `allowlist-without-dead-entry-check`, a vacuity guard (`the census finds the seam`), and inline counterfactuals for the matcher itself. Verified red on a planted spawn.
- `lua/parley/tasker.lua:344-350` — `exit_reason` as one renderer, with the guard at `spawn_seam_spec.lua:108-134` forbidding a raw `tostring(…code…)` in any module that hands callbacks to tasker, is the ARCH-DRY answer rather than four hand-edits. `unscoped_kill_spec.lua:127-130` pins the user-visible text (`killed: deadline`, "Resubmit the question", no `nil`) and I confirmed it reddens on the old message.
- `tests/integration/process_group_conformance_spec.lua` — three live kernel checks on every `make test`, including one through the real `find` builtin and `process_bootstrap`, asserting the grandchild's pid is actually gone. Fake and production share the `M._uv` seam; this is ARCH-MOCK done properly.
- `tests/helpers/fake_process.lua:104-141` — collapsing both kill paths onto one `scripted()` helper, and making `state.signals` mean "signals the kernel accepted" on both paths, is the correct fix for BR-42: the failed-signal-retry case is now parameterised over pid *and* group (`tasker_run_spec.lua:910-926`) instead of having been moved to keep working.
- `lua/parley/attempt.lua:25-35` — `open_probe_window` extracted so the probe window has one definition, and the reducer stays pure with `drive`-style sequence tests. Still the strongest part of M3.

## 2. Critical findings

None.

## 3. Important findings

**A. `lua/parley/chat_respond.lua:23-24` and `lua/parley/response_provider.lua:11-15` — the `code`/`io_error` sweep stopped at tasker's direct callbacks; the dispatcher re-exports both fields and neither renderer reads `io_error`.**
`dispatcher.lua:760-768` builds `failure = {code = code, signal = signal, io_error = io_error, …}` and hands it to `on_error`. Two consumers render it:
- `chat_respond._failure_notice` prints `" (exit " .. tostring(failure.code) .. ")"` — now skipped entirely, because `failure.code` is nil on every kill — and then up to 500 chars of `failure.body` (the raw partial SSE/JSON). A deadline-killed topic generation surfaces `parley: provider request failed: <raw JSON fragment>`.
- `response_provider.failure_reason` returns `'provider request failed (HTTP '..tostring(failure.http_status or 'unknown')..')'` — i.e. `(HTTP unknown)` for a killed or pipe-errored stream.

Neither file contains the literal `tasker.run(`, so `spawn_seam_spec.lua:117-131` does not scan them; and its `raw` pattern (`tostring%(%s*[%w_]*code%d*%s*%)`) would not match `tostring(failure.code)` anyway, since `.` is outside `[%w_]`. Fix sketch (the rule, not the site): anchor the sweep and its guard to the **value**, not to the callers of one function — have the dispatcher render once at the seam that produces it (`failure.reason = tasker.exit_reason(code, signal, io_error)`), make both renderers read `failure.reason`, and widen the guard's scope predicate from "file calls `tasker.run(`" to "file reads a `.code` off a table that also carries `io_error`", plus list the forms the matcher cannot see in its header (the convention `single_source_sweeps_spec` already follows).

**B. `tests/arch/spawn_seam_spec.lua:30-50` — the enumeration's per-entry reasons are unchecked prose, and the atlas now treats them as authoritative.**
`atlas/providers/tool_execution.md:125-128` says the spec "lists each of them, file by file, **with how it ends**", so each `reason` string is now load-bearing documentation. The test only asserts `type(entry[2]) == "string" and #entry[2] > 0`. Two entries are wrong as written:
- `:33` — `git_markdown_source.lua` is labelled "a bounded `git show` read with its own cancel". The command is `git ls-files -z --cached --others --exclude-standard -- *.md` (`git_markdown_source.lua:135-143`), and it is **not** bounded: `markdown_finder.lua` arms no timer, and `request_kill` (`git_markdown_source.lua:37-43`) sends `sigterm` once with no escalation, only when the caller cancels.
- `:31-32` — cliproxy's "its admin calls, probes and downloads carry curl or `vim.system` timeouts" is false for `lsof` (`:842`), `<bin> -h` (`:1024`), `ps ax` (`:1066`), `sha256sum`/`shasum` (`:2027`) and `tar -xzf` (`:2106`), none of which pass a timeout. They are all synchronous `:wait()`, which *is* an answer — but it is not the one the entry gives.

Fix sketch (the rule): make the justification checkable rather than narrative — give each entry a machine-verified classification the test asserts from the call form (e.g. `sync = true` ⇔ the line ends in `:wait()` / uses `vim.fn.system*`; `bounded = true` ⇔ the call carries `timeout =` or `--max-time`), and reserve free text for the genuine exceptions (the managed proxy). Then correct the two entries above.

## 4. Minor findings

- `atlas/chat/lifecycle.md:224-225` — "cancellation does not release unresolved subprocesses or tool effects" still leads the paragraph that the new M3 sentence immediately qualifies; it reads as the pre-M3 contract until the next sentence lands. Defensible as written ("unresolved" carries it), so recorded here only.
- `README.md:115-120` — the inserted sentences leave "2 s later" and "A tool whose process has ended holds nothing," on short ragged lines; a reflow would read better.
- `tests/helpers/fake_process.lua:45-52` — the fake has no option to spawn a pid other than `4242`/`next_pid`, which is why BR-43's guard has no test seam (see its disposition).

## 5. Test coverage notes

Full suite green: 381 spec files, lint 0/0 over 637 files. The counterfactual discipline on the *addressed* findings is real — I reproduced both. The gap this round is that three of the four Minors changed behaviour with no test, and all three are testable in under ten lines. I wrote and ran them, and confirmed each goes red on revert:

- **BR-44** — arm a `deadline_ms` run on the fake, give the process `ignores = {[15]=true,[9]=true}`, fire the deadline, tick `reconcile_step` past 5 s; assert `#T.held() == 1` and `deadline.closing`. Red without the in-callback `close_timer`.
- **BR-41** — stub `dispatcher.query`, call `generate_topic(..., {alive = fn})`, assert the captured `transport_opts` keeps `alive` **and** gains `tasker.deadline.stream`. Red on the old `transport_opts or {…}`.
- **BR-43** — not writable today; needs a `spawn_pid` option on the fake, after which `stop_attempt` on a pid-0 record should record `missing` and add nothing to `state.signals` (the fake already raises if pid 0 is ever signalled).

Also uncovered, and the hole finding A falls through: no test asserts what `_failure_notice` or `failure_reason` render for a failure whose only diagnostic is `io_error`.

## 6. Architectural notes for upcoming work

**ARCH-DRY** pass — `exit_reason`, `is_scoped`, `open_probe_window`, `scope_key`, `target`/`send`, `close_timer`, hoisted `call_safely`; I swept for survivors of the two hand-built scope-key spellings and found none. **ARCH-PURE** pass — `attempt.lua` and `target`/`exit_reason` stay pure; `send` is the IO edge. **ARCH-PURPOSE** flagged (finding A: the shadow sweep over `exit_reason`'s consumers stops one seam short; finding B: the enumeration's content is not derived). **ARCH-MOCK** pass — the fake's two kill paths now share one vocabulary, and live conformance runs every suite. **ARCH-CONSTRAINTS** pass — every deadline has a kind, a value and a basis; the reconcile clamp keeps KILL at exactly `kill_due`. **ARCH-SECURE** pass — the `pid <= 0` guard landed; the pgid-reuse window is narrow and stated. **ARCH-ORDER** pass — the reducer plus sequence tests cover the interrupting events, including a stop on a window an exit opened. **ARCH-FUNERAL** pass — the deadline timer now closes as it fires, the `ParleyLeave` augroup is `clear = true`, and `held()` bounds what is retained.

For M4/M5:
- The `attempt` state is still a boolean/nullable constellation (`stop_requested`, `kill_due`, `escalated`, `unresolved_visible`, `signalled`, `stop_cause`, `exited`, two EOFs, `spawn_failed`, `delivered`); `escalated = true, kill_due = nil` is representable and undefined. M4 adds `stopping`/`fault` on top. A derived `phase` tag (`live | stopping | escalated | held | resolved`) read by `held()` and `stop_matching` would bound the growth.
- `scoped_stop` still drops `cause`, so `stop_buf`/`stop_scope`/`stop_owner`/`stop_attempt` can only ever produce `killed: stop`. M5's "a user Stop is silent, other `cancelled` paths warn" needs the distinction; threading `cause` now is two lines. The plan already records this.
- Finding A is the same seam M5 Task 5.3 plans to keep (`failure_notice` as `detail`). If the dispatcher renders once into `failure.reason`, M5 inherits a value that already names the cause instead of re-deriving it.

## 7. Plan revision recommendations

- **`## Revisions` — M3 Task 3.4, renderer scope.** The round-1 delta records the enumeration as "every tasker exit callback that renders an outcome" (four sites). Record that the enumeration is one seam short: `dispatcher.query`'s `failure` table re-exports `code`/`signal`/`io_error`, and its two renderers (`chat_respond._failure_notice`, `response_provider.failure_reason`) are outside both the list and the guard's scope predicate.
- **`## Revisions` — M3 Task 3.7, the out-of-seam list's reasons.** Record that `spawn_seam_spec`'s `OUTSIDE` reasons are asserted only as non-empty strings, that `git_markdown_source` is `git ls-files` with no bound (not a bounded `git show`), and that several cliproxy calls carry no timeout — and say which remedy was taken (machine-checked classification vs. corrected prose).
- **`## Revisions` — M3 round-1 Minors, evidence.** Record that BR-41, BR-43 and BR-44 landed as correct code with no regression test, and name the three tests that close them (above), so M4 does not inherit them as "done".

```findings
dispose:
  - id: BR-38
    disposition: addressed
    note: |
      tasker.exit_reason plus the raw-render guard; verified red on revert in unscoped_kill_spec and spawn_seam_spec. Its stated four-callback enumeration is fully swept; the wider renderer class is raised anew below.
  - id: BR-39
    disposition: addressed
    note: |
      README.md:115-120 now states TERM then SIGKILL at 2 s and scopes the claim-holding to "until the process has ended"; I re-ran the superseded-claim sweep and found no other stale statement.
  - id: BR-40
    disposition: addressed
    note: |
      Atlas quantifiers scoped to tasker.run, and spawn_seam_spec is an executable per-file census with a dead-entry check; verified red on a planted spawn in logger.lua.
  - id: BR-41
    disposition: not-addressed
    note: |
      The merge is correct but untested; I wrote the 8-line test and it goes red on the old `transport_opts or {…}` form.
  - id: BR-42
    disposition: addressed
    note: |
      Both kill paths share one scripted() helper and the failed-signal-retry case is parameterised over pid and group; verified red when the group branch's scripted() call is removed.
  - id: BR-43
    disposition: not-addressed
    note: |
      The guard is correct but has no test, and the fake has no seam to spawn a pid other than 4242 — add a spawn_pid option, then assert a pid-0 record records `missing` and signals nothing.
  - id: BR-44
    disposition: not-addressed
    note: |
      The in-callback close is correct but untested; the existing supervision assertion at :232 passes via retire either way. I wrote the held-record test and it goes red without the fix.
findings:
  - id: new
    severity: Important
    family: seam-change-collateral
    title: |
      The dispatcher re-exports code/io_error on its failure table, and both of that table's renderers still drop io_error
    detail: |
      This is the 5th finding in family `seam-change-collateral`. Do NOT fix
      chat_respond.lua:24 and response_provider.lua:13 alone. The rule BR-38
      stated was "sweep every consumer that RENDERS the value"; it was
      implemented as "every file containing the literal tasker.run(", which is
      a call-site anchor, not a value anchor. The value crosses one more seam:
      dispatcher.lua:760-768 builds failure = {code, signal, io_error, …} and
      hands it to on_error. chat_respond._failure_notice (chat_respond.lua:23-24)
      renders tostring(failure.code) — now dead, since code is nil on every
      kill — then up to 500 chars of raw partial body; response_provider
      failure_reason (response_provider.lua:11-15) renders
      "provider request failed (HTTP unknown)". Neither reads io_error, so a
      deadline- or leave-killed stream never names its cause to the user, the
      same Done-when clause BR-38 cited. Neither file is in the guard's scope,
      and its pattern tostring%(%s*[%w_]*code%d*%s*%) cannot match
      tostring(failure.code) because `.` is outside [%w_]. The rule-level fix:
      render once at the seam that produces the value (failure.reason =
      tasker.exit_reason(code, signal, io_error)), have both consumers read it,
      widen the guard's scope predicate from "calls tasker.run(" to "reads a
      .code off a table that also carries io_error", and list the forms the
      matcher cannot see in its header, as single_source_sweeps_spec does.
      M5 Task 5.3 plans to keep _failure_notice as `detail`, so it inherits this.
  - id: new
    severity: Important
    family: enumeration-claims-completeness
    title: |
      The out-of-seam spawn list's per-entry reasons are unchecked prose, and two of eighteen are wrong
    detail: |
      This is the 8th finding in family `enumeration-claims-completeness`. Do
      NOT fix the two entries alone. atlas/providers/tool_execution.md:125-128
      now defers to tests/arch/spawn_seam_spec.lua as the list of each
      out-of-seam spawn "with how it ends", which makes every `reason` string
      load-bearing documentation — but the test asserts only that it is a
      non-empty string. spawn_seam_spec.lua:33 calls git_markdown_source "a
      bounded `git show` read with its own cancel": the command is `git ls-files
      -z --cached --others --exclude-standard -- *.md`
      (git_markdown_source.lua:135-143), markdown_finder arms no timer, and
      request_kill (git_markdown_source.lua:37-43) sends one sigterm with no
      escalation, only on caller cancel. spawn_seam_spec.lua:31-32 says
      cliproxy's calls "carry curl or vim.system timeouts": false for lsof
      (cliproxy.lua:842), `<bin> -h` (:1024), `ps ax` (:1066), sha256sum (:2027)
      and tar (:2106) — all synchronous :wait() with no timeout, which is an
      answer, but not the one given. The rule: an enumeration whose entries
      justify a documented claim must make each justification checkable — assert
      a classification derived from the call form (sync ⇔ :wait()/vim.fn.system*;
      bounded ⇔ the call carries `timeout =` or `--max-time`) and keep free text
      only for genuine exceptions such as the managed proxy.
```

---

## Re-review — 2026-09-19T08:39:37-07:00 (FIX-THEN-SHIP)

| field | value |
|-------|-------|
| issue | 261 — Audit transcript as the complete recovery state |
| repo | parley.nvim |
| issue file | workshop/issues/000261-audit-transcript-recovery-state.md |
| boundary | milestone M3 |
| milestone | M3 |
| window | 8a753815ca9754084a75902f1f1c368ed5e54371..68f095be8e18b897725f06976b072e4d3129dc45 |
| command | sdlc milestone-close --issue 261 --milestone M3 |
| reviewer | claude |
| timestamp | 2026-09-19T08:39:37-07:00 |
| verdict | FIX-THEN-SHIP |

## Review

```verdict
verdict: FIX-THEN-SHIP
confidence: high
```

M3's core is genuinely delivered and genuinely verified: I reverted `detached` to main's misspelled `detach` in a scratch edit and all three live-kernel conformance cases went red, so the process-group claim is load-bearing rather than asserted. All five prior findings are `addressed` with counterfactuals I ran myself (BR-41, BR-43, BR-44 each turn their new test red on revert; BR-45 reddens four specs including the value-anchored guard; BR-46's classification is now derived from the call form and I hand-verified all 15 cliproxy spawns and the two previously-wrong entries against the source). The full suite is 380 files green plus `perf_document_spec`, which dies under load and passes 5/5 alone — the recorded #267 flake family, not M3's. What blocks SHIP is one new Critical that this window introduced: the copilot bearer failure log now appends the whole `curl -v` stderr, and `-v` puts `authorization: token <copilot OAuth secret>` on stderr — I confirmed that with a real curl against a local listener, and confirmed the base's `string.format` silently dropped the argument, so the leak is new. Two Importants follow: the tool layer overwrites the inherited `io_error`, so a Stop of a scoped shell tool reports `scoped process bootstrap failed` (measured on M3's own conformance case), and the atlas's scoped-process claim about `scope_key` is false for skill processes with nothing enumerating the producers.

## 1. Strengths

- **The live conformance spec is real evidence, not ceremony** (`tests/integration/process_group_conformance_spec.lua:28-69`). Restoring `detach = true` in `tasker.lua:562` fails all three cases. It avoids `ps`, uses `kill -0 -- -$$` for group leadership, and case 3 drives the actual tool spawn path through `process_bootstrap`.
- **The ARCH-ORDER reducer testing is the strongest thing in the diff** (`tests/unit/attempt_spec.lua:54-77`). `drive()` is an explicit ordering seam: it feeds sorted external events interleaved with the reducer's own requested ticks and returns the *time* of each effect, so "KILL at exactly stop+2000" and the grandchild case (exit-opened window, later stop reopens, escalate at +5000) are pinned rather than sampled. Pure, no IO.
- **ARCH-DRY at the root cause, not the sites.** The `code == nil ⟺ io_error` rule lives once in `tasker.lua:520-527` instead of `or io_error` at 16 call sites; `target()`/`send()` (`tasker.lua:212-228`) collapsed three copies of the kill/errno idiom; `tasker.deadline` is one table with a guard against literals.
- **The BR-45 fix is anchored correctly**: the dispatcher stops *exporting* `code`/`signal` rather than asking consumers to be careful (`dispatcher.lua:759-766`). Removing the field is a stronger guard than any pattern, and the arch check is on the value (`spawn_seam_spec.lua:270`), not on `tasker.run(` callers.
- **BR-46's derivation is sound.** `classify()` (`spawn_seam_spec.lua:111-120`) plus the two "bound one call away" checks (`:173-211`) hold up: I verified all 15 cliproxy spawns independently and got exactly `sync=9, bounded=3, delegated=1, open=2`, and `git_markdown_source`'s new reason matches `git_markdown_source.lua:135-143` and `request_kill` at `:37-43`.

## 2. Critical findings

**`lua/parley/vault.lua:216-218` — the copilot bearer failure log leaks the Copilot OAuth token.**

```lua
local curl_params = ... "-s", "-v", ... "authorization: token " .. secret, ...
tasker.run(nil, "curl", curl_params, function(code, signal, stdout, stderr, io_error)
    if code ~= 0 then
        logger.error("copilot bearer resolve failed (" .. tasker.exit_reason(code, signal, io_error) .. "): "
            .. tostring(stderr))
```

`-v` (`vault.lua:193`) makes curl write its full trace to stderr, including `> authorization: token <secret>`. I verified this against a local listener: `curl -s -v -H 'authorization: token SECRET123'` puts `SECRET123` on stderr. `logger.error` with no `sensitive` flag writes the message verbatim to the log file (`logger.lua:89-92`) **and** `vim.notify`s it (`logger.lua:99-100`) — so the token lands in a plaintext log and flashes on screen, up to the 64 KiB stderr cap. This contradicts the contract the same atlas page states ("Vault debug messages are marked sensitive and follow `log_sensitive`", `atlas/infra/vault.md:23`).

This is new in this window. The base read `string.format("copilot bearer resolve failed: %d, %d", code, signal, stderr)` — two specifiers, three arguments, so Lua dropped `stderr` entirely (verified). M3 rewrote the line to fix the `%d`-on-nil throw and appended the trace on the way.

Fix sketch: drop `-v` from `args` (nothing reads the trace — the token is parsed from `stdout` at `:224-231`), then the log line is harmless. If the trace is wanted, pass `sensitive = true` **and** bound it, or strip `^[<>*] .*authorization` lines before logging. Add the regression: a killed/failed copilot fetch whose scripted stderr contains `authorization: token …` must not produce a log line containing the secret. ARCH-SECURE.

## 3. Important findings

**`lua/parley/tools/async_builtin.lua:197-200` — the tool layer overwrites the `io_error` it was handed, so every Stop of a scoped shell tool misnames its cause.**

```lua
if marker~=''then
    if err:sub(1,#marker)~=marker then
        io_error='scoped process bootstrap failed'
    else err=err:sub(#marker+1)end
end
```

The bootstrap writes its marker to stderr immediately before `execvp` (`scripts/tool_process.lua:51`), after a whole headless-nvim startup. A kill that lands before that point leaves stderr without the marker, and this line replaces `killed: stop` with a diagnosis blaming the bootstrap. Measured on M3's own conformance case: I added a temporary print to `process_group_conformance_spec.lua:67` and the stopped `find /` returns `error_code = "scoped process bootstrap failed", code = nil`. So the manual step Task 3.7 added (`tests/manual/chat-concurrency.md:48`) walks an operator straight into a wrong explanation, and the live test asserts only `physical_resolved`.

**This is the 7th finding in family `seam-change-collateral`.** Earlier rounds fixed instances. Do NOT fix this instance alone. Round 1 anchored the sweep on callers of `tasker.run(`; round 2 re-anchored it on the value's *renderers* and the table it is copied onto. The class still uncovered is the value's **other kinds of consumer**: code that *overwrites* `io_error`, or *computes* on `code`. State the rule — in a tasker exit callback, `io_error` is an inherited diagnosis, so a local reason is added with `io_error = io_error or '<reason>'`, never assigned over — and note that `tasker.lua:604` and `dispatcher.lua:754` already use that idiom, so `async_builtin.lua:199` is the single deviation. Extend `spawn_seam_spec`'s value-anchored describe block with a third check over the same file set: an assignment to a callback's `io_error` parameter that is not of the form `io_error or` fails, and list it in the header's "what the matchers cannot see". Assert the conformance case's `error_code == 'killed: stop'` so the path has an oracle.

**`atlas/providers/tool_execution.md:76-82` with `lua/parley/skill_invoke.lua:595` — the scoped-process claim asserts a key shape that one of its three named producers does not use.**

The atlas says: "**Scoped** processes belong to a generation: provider streams, tool processes, skill processes. They carry `logical_generation`, keyed by `tasker.scope_key(epoch, generation)`." Two producers derive from it (`response_provider.lua:105`, `tools/producer.lua:120` → `scheduler.lua:130`, validated at `scheduler.lua:150`). The third hand-builds a different namespace: `skill_invoke.lua:152` `local process_owner="skill:"..tostring(buf)..":"..tostring(gen)`, passed as `logical_generation` at `:595`, where `gen` is `_gen[buf]`, not the document epoch/generation. Nothing today breaks (the record is still `group=true` and `stop_owner(process_owner)` still group-kills it), but the documented key shape is false, and M4 Task 4.1's single scope kill — `tasker.stop_scope(tasker.scope_key(ctx.epoch, ctx.generation))`, plan line 1314 — will silently skip every skill process.

**This is the 9th finding in family `enumeration-claims-completeness`.** Do NOT fix this instance. The rule is the one BR-40/BR-46 already established and it simply was not applied to the second single-source value this milestone introduced: a doc sentence that quantifies over a set needs an executable enumeration of that set. `scope_key` is a single source with exactly one guard-less consumer class. Add to `spawn_seam_spec` (or beside it) a producer census over `grep -rn "logical_generation\s*=" lua/`: every production assignment either calls `tasker.scope_key`, or forwards a value that did, or is declared in a table with its reason and an exact count — the same `OUTSIDE`-table shape, with the same dead-entry check. Then either route `skill_invoke` through `scope_key` or declare it, and correct the atlas sentence to say what the enumeration proves.

## 4. Minor findings

- `dispatcher.lua:770` still exports `io_error` on the failure table while `spawn_seam_spec.lua:270` forbids every production read of `failure.io_error`, so the field is now unreachable from `lua/` by construction — its only readers are `dispatcher_query_spec.lua:692,740,784,792`. **5th in family `returned-handle-has-no-consumer`**; the rule: a guard that forbids every production read of a field retires that field, so the field and the guard entry go in the same change — drop one of the two.
- `process_group_conformance_spec.lua` pins the scoped side against the kernel but never the exemption the operator decision rests on (an unscoped child stays in Neovim's group so a prompting secret command works); only the fake pins it, as `assert.is_nil(processes.spawn_options[2].detached)`. A live check is two lines: for an unscoped `sleep`, `uv.kill(-pid, 0)` must fail (no group has that id), where the scoped case succeeds. **2nd in family `exemption-boundary-untested`** — rule: a conformance case that pins a rule against the real dependency pins the exemption's negative in the same file.
- `atlas/providers/tool_execution.md` "Processes outside tasker" summary bullets drift from the list they defer to: cliproxy's login helper (the second `open` entry, `spawn_seam_spec.lua:47-48`) is not mentioned, and "clipboard … lookups" is grouped under "user commands report their own exit" though `clipboard_image.lua` is classified `bounded`.
- `tests/integration/process_group_conformance_spec.lua:9-11` — `gone(pid)` treats any non-zero `uv.kill` return as gone, so an EPERM would read as gone; `ESRCH` specifically would be tighter.

## 5. Test coverage notes

- Full suite: 380 spec files pass, `make lint` clean (it runs first in the `test` target). Only `perf_document_spec.lua` fails under `JOBS=4` and passes 5/5 alone — the #267 flake family already recorded for the M1 and M2 closes, and it touches nothing in M3.
- Counterfactuals I ran, all red as claimed: `detached`→`detach` (3 conformance cases), `target()`'s `pid <= 0` guard and the fire-time timer close (2 supervision cases), the `transport_opts` merge (topic_gen), and the BR-45 render sweep (`failure_notice`, `dispatcher_query` I9, `response_provider`, `spawn_seam`).
- Real gap: the tool layer's consumption of the exit tuple has no test at all. The conformance case that exercises it asserts `physical_resolved` but not `error_code`, which is why the `scoped process bootstrap failed` misdiagnosis survived two review rounds.
- I chased two further consumers and cleared them — `process_scope.join_code(0, nil)` does throw (`attempt to compare number with nil`) and the builtins compare `exit_code >= 2` / concatenate it, but `await` (`async_builtin.lua:10-14`) raises on any outcome carrying `error_code`, and `code == nil` always implies `error_code` is set, so neither is reachable. Worth a one-line comment at `join_code` recording that invariant, since it is the only thing holding them up.

## 6. Architectural notes for upcoming work

- **ARCH-DRY** pass. **ARCH-PURE** pass — `attempt` stays a pure reducer and the escalation policy moved *into* it rather than into the timer callback. **ARCH-MOCK** pass and notably strong: fake, sequence tests over the fake, and a live conformance check against the kernel all share one seam. **ARCH-CONSTRAINTS** pass — the tick clamp keeps KILL at 2 s instead of the next back-off, `leave()` is a bounded synchronous loop at `VimLeavePre`, deadlines are validated ≤ 1 h. **ARCH-ORDER** pass, with the reservation that `scoped_stop` drops `cause` so every scoped stop reads `killed: stop` (already recorded in the plan for M5). **ARCH-FUNERAL** pass — the deadline timer closes as it fires *and* at retire, `unread_stores` is weak-keyed, the `ParleyLeave` augroup uses `clear = true` and has a double-`setup` test. **ARCH-PURPOSE** and **ARCH-SECURE** are where the three findings above land.
- For M4: `tasker.stop_scope` and `tasker.held` still have no production consumer. That is a legitimate deferral — the plan names both consumers with line-level specificity (Task 4.1 for the scope kill, Task 5.2/5.3 for `held()` in the capacity refusals) — but the `logical_generation` producer census above needs to land *before* the scope kill is wired, or the kill will pass its tests and miss skills.
- For M4/M5: `M.run`'s refusal of an unscoped run without `deadline_ms` reaches third-party tools through `context.tasker`. A custom `execute_async` that calls `context.tasker.run` without forwarding `context.logical_generation` is now refused. Worth one line in the README's custom-tool paragraph when M4 touches that surface.

## 7. Plan revision recommendations

- **`## Revisions`, M3 review round 3 — the exit tuple's non-rendering consumers.** Record that the value-anchored sweep covered branches and renders but not *overwrites*: `async_builtin.lua:199` replaces an inherited `io_error`, so the tool layer misnames every early kill. State the `io_error = io_error or …` rule, the guard that enforces it, and the conformance assertion added.
- **`## Revisions` — `scope_key`'s producers.** Task 3.3 claims "M3 makes it one function, `tasker.scope_key`" and the Core-concepts table lists `scope_key` as the single source. That holds for the two spellings the plan named and misses `skill_invoke.lua:152`. Record the corrected producer census and the guard, and correct the atlas sentence the same round.
- **`## Revisions` — Task 3.4's callback sweep was not only about rendering.** Its "as built" entry says "The sweep is that one rule in `tasker`, not `or io_error` added at 16 sites (ARCH-DRY)." That is true for the 18 `tasker.run(nil, …)` sites but the census never covered the *scoped* callbacks, and the one defect is there. Note that the census's scope was unscoped-only and say what covers the scoped side now.
- **`## Revisions` — the vault log line.** Task 3.4 records "The vault copilot fetch formatted `code` with `%d`, and now uses `%s`". Record that the same edit began logging `curl -v` stderr, that `-v` carries the authorization header, and what the fix was — so the next `exit_reason` adoption does not repeat it.
