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
