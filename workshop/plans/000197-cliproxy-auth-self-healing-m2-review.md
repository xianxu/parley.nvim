# Boundary Review — parley.nvim#197 (milestone M2)

| field | value |
|-------|-------|
| issue | 197 — cliproxy auth failures must self-heal: detect, diagnose, recover |
| repo | parley.nvim |
| issue file | workshop/issues/000197-cliproxy-auth-self-healing.md |
| boundary | milestone M2 |
| milestone | M2 |
| window | 819a781a71859450cb5f22aa6940d9213004bb70..HEAD |
| command | sdlc milestone-close --issue 197 --milestone M2 |
| reviewer | claude |
| timestamp | 2026-08-01T11:43:04-07:00 |
| verdict | REWORK |

## Review

```verdict
verdict: REWORK
confidence: high
```

M2's shape is right and the hard part landed: `decide` is a genuinely pure, table-tested policy with a real anti-loop property test, `recover` shrank to gather-and-execute (closing the M1 review's ARCH-PURE carry-forward), the fake grew the real 503/401/402 chat-completions bodies so an e2e can drive `dispatcher.query → recover_query → the operator notice`, and the `start`/`restart` rungs correctly route through `ensure_running` (closing M1's "retry doesn't re-run pre_query" note). I re-ran everything independently: `make test-spec SPEC=providers/cliproxy-managed` → 13 specs, **245 examples, 0 failed, 0 errors**, conformance genuinely booting the real binary (3 examples, no SKIP); `make lint` → **0/0 in 311 files**. The Log's counts match. What blocks SHIP is two correctness bugs I reproduced, both in new M2 code and both defeating this issue's own Done-when. **(C1)** `auth_file_modtime` emits UTC-`Z` while cliproxy reports a local-offset RFC3339, and `auth_file_is_stale` compares them *lexicographically* — so at UTC or west of it the file is **always** "stale": the headline "credential healthy ⇒ retry, no prompt" rung never runs, and every transient failure SIGTERMs and respawns the proxy instead. I confirmed it twice, including through this milestone's own e2e (`cliproxy.stop()` called once on the "transient ⇒ retry" case). **(C2)** Task 12 passes `:ParleyProxy models`' *model-owning-provider* argument into `credential_health`, which wants a *cliproxy channel* — the exact namespace defect M1 round 2 found and fixed, re-introduced in the code whose stated purpose was to stop guessing: a healthy `gemini-cli` credential reads as `missing` and prompts a spurious `google` login.

## 1. Strengths

- **`decide` is the ladder, and it is honestly pure** (`lua/parley/cliproxy_auth.lua:261-311`). No IO, no clock, no `vim.*`; 43 unit examples with zero mocks. The anti-loop **property** test (`tests/unit/cliproxy_auth_spec.lua:317-331`) sweeps 5 kinds × 6 states × liveness at `attempt = 1` and asserts no repair action can ever be returned — that is the whole safety argument expressed as a property rather than a case list, and it is the right shape.
- **The M1 carry-forward that mattered most is genuinely closed.** `needs_human` no longer lives in the IO shell; `recover`'s job is now gather-inputs → `decide` → `execute`, with a single `execute` whose every branch terminates the claim (`cliproxy.lua:828-858`). M2 ships with one policy owner, which is exactly what the M1 review asked for.
- **`execute` routes `start`/`restart` through `ensure_running` before retrying** (`cliproxy.lua:840-844`), which answers M1's "decide deliberately whether `restart` should route through `pre_query`" design note — the retry cannot fire before the replacement proxy is confirmed healthy.
- **The fake's error modes are a real ARCH-MOCK improvement** (`tests/fixtures/fake_cliproxy:158-178`): the captured 7.1.71 bodies served over the same HTTP boundary production uses, which is what lets `cliproxy_recovery_e2e_spec.lua:127-134` assert the outage's 503 now yields a notice naming `me@example.com` and `expired` with **no** `body_bytes` — the issue's headline Done-when, tested end to end rather than by hand-built failure tables.
- **The "leave other providers alone" e2e** (`cliproxy_recovery_e2e_spec.lua:183-196`) pins that the seam is opt-in per adapter by asserting `failure.message` is nil for openai against the same failing endpoint. Cheap, and it protects every non-cliproxy provider from this machinery.

## 2. Critical findings

**C1 — the staleness check compares two different timestamp representations, so `restart` fires on every healthy-credential failure and the documented `retry` rung is unreachable.** `lua/parley/cliproxy.lua:736` + `lua/parley/cliproxy_auth.lua:243-247`

`auth_file_modtime` formats the disk mtime as UTC with a `Z` suffix; cliproxy reports the credential it loaded in local-offset RFC3339 with nanoseconds (`tests/fixtures/cliproxy_auth_files.json:14`: `"2026-08-01T00:34:46.994488305-07:00"`). `auth_file_is_stale` then does a plain `disk > loaded` string compare. For the *same file at the same instant* in US Pacific:

```
proxy-reported modtime : 2026-08-01T11:35:01-0700   state=healthy
parley disk modtime    : 2026-08-01T18:35:01Z
"…T18:…Z" > "…T11:…-0700"  ⇒ stale = true
```

Reproduced through `cliproxy.recover` with a healthy credential:
```
claimed=true settled=retry  stop_calls=1 ensure_running_calls=1
>>> took the RESTART rung (proxy was killed)
```
and again through **this milestone's own e2e**, by instrumenting `cliproxy.stop` in a copy of `cliproxy_recovery_e2e_spec.lua`:
```
REVIEW: cliproxy.stop() called 1 time(s) — 0 means the RETRY rung, >0 means the RESTART rung
```

The direction of the error depends on the operator's offset: at UTC (`Z` > `+`) and anywhere west of it, *always* stale; east of UTC, *never* stale (the rung is dead). Failure scenario: any transient cliproxy failure for a US operator → parley SIGTERMs the proxy (which may be a `brew services` daemon shared with other nvim instances), respawns it, and retries — instead of the silent retry the atlas table (`atlas/providers/cliproxy-managed.md:152`) and the issue's Done-when promise. Compounded by I1 below, on the real binary the restarted proxy is likely the *dying* one, so the retry lands on a shutting-down process and the "self-repaired" query fails.

Every test misses it for two separate reasons: the unit cases (`cliproxy_auth_spec.lua:297-309`) use two `-07:00` strings on both sides — a degenerate fixture of exactly the class `workshop/lessons.md` records from M1 C1 — and the integration/e2e cases cannot distinguish the rungs because `restart` also ends in `retry()`.

Fix sketch: normalize in the IO shell and let `decide` compare numbers, so the pure function isn't relying on an unenforceable string-comparability assumption:
```lua
-- cliproxy.lua: seconds since epoch, not a formatted string
local function auth_file_mtime_sec(channel) … return newest end   -- st.mtime.sec
-- cliproxy_auth.lua: parse the proxy's RFC3339 (offset + optional fraction) to epoch
local function rfc3339_sec(s) … end
local function auth_file_is_stale(health, proxy_state)
    local d, l = tonumber(proxy_state.auth_file_modtime), rfc3339_sec(health.modtime)
    return d ~= nil and l ~= nil and d > l + SKEW   -- SKEW absorbs fs/report granularity
end
```
Tests to add: `decide` rows with mixed representations (`Z` vs `-07:00` vs `+02:00`, and the real binary's fractional-second form) asserting *not* stale for the same instant; and make the integration case distinguishable — assert `stop()` is not called on the healthy path, or assert the returned `decision.action` directly.

**C2 — `:ParleyProxy models <provider>` reads credential health on the model-owning-provider axis where the cliproxy channel axis is required; a healthy google-family credential is reported as "no credential" and prompts a login.** `lua/parley/init.lua:414,434`

`credential_health(cb, channel)` → `classify_auth_files` matches `(f.provider or f.type) == channel` (`cliproxy_auth.lua:147`), i.e. the cliproxy channel (`gemini-cli`, `aistudio`, …). But `arg` here comes from `cliproxy_config.providers()` — the `PROVIDER_OWNED_BY` axis (`antigravity, claude, codex, google, kimi, xai`), which the atlas itself calls out as a *different* axis (`atlas/providers/cliproxy-managed.md:222-227`). Reproduced against the fake with a **healthy** `gemini-cli` credential loaded:

```
credential_health(_, "google"    ) -> state=missing   message=no credential for google
credential_health(_, "gemini-cli") -> state=healthy   message=credential is healthy
```

Failure scenario: `:ParleyProxy models google` with an authenticated gemini-cli account whose models aren't in the dynamic registry → `state == "missing"` → falls past both new guards into `vim.ui.select` (`init.lua:427-433`) with `"cliproxy: no google models — no credential for google"` and an offer to log in. That is the exact fabrication this issue exists to eliminate, in the commit that claims to have eliminated it, and it breaks Done-when "only a genuinely dead credential prompts". Five of six providers coincide with their channel; `google` — the one that motivated M1's C1 fix — does not.

Fix sketch: `PROVIDER_OWNED_BY`'s key set is the login-provider axis, and `CHANNEL_LOGIN` already maps channel → login provider, so the inverse is derivable rather than a new hand-maintained table (ARCH-DRY):
```lua
-- cliproxy_config.lua (pure)
function M.channels_for_login(login)      -- "google" → { "gemini", "gemini-cli", "aistudio" }
```
then read health for each and keep the healthiest (`HEALTH_RANK` already expresses "healthiest wins"). Add a `gemini-cli` case to `cliproxy_command_spec` — and see I5: the current stubs make this bug unobservable by construction.

## 3. Important findings

**I1 — the `restart` rung SIGTERMs and immediately re-probes, without the port-release wait that exists five hundred lines away for exactly this reason.** `lua/parley/cliproxy.lua:837-844` vs `:411-413`

`credential_health`'s repair is `stop()` → `wait_port_released` → `ensure_running`, with a comment stating why (`cliproxy.lua:337-341`): "M.stop() returns immediately, and the REAL cliproxyapi shuts down gracefully — so without this the follow-up probe can still see the dying proxy, take ensure_running's reuse-if-healthy branch, and never spawn the replacement. The Python fake dies instantly, which is why a test alone would not surface this." The new rung is that same sequence with the fix omitted. Failure scenario: stale in-memory auth → `restart` → `stop()` → `ensure_running` probes the still-listening dying proxy → reuse branch → `retry()` against a process that is exiting → the retry fails and, at `attempt 1`, no repair is allowed → the operator gets a report. Two copies of one repair sequence, one correct (ARCH-DRY). Fix: extract the stop→wait→ensure sequence into one helper and call it from both.

**I2 — Task 12 is a second hand-rolled policy, not `decide`; the two disagree on `error`.** `lua/parley/init.lua:414-434`

The plan's Task 12 says "Route it through `auth_files` + `decide` so both paths give the same diagnosis and the same prompt" (`…-plan.md:451`); the code routes through `credential_health` plus an inline three-branch ladder. Concrete divergence: for `health.state == "error"` with a non-auth-shaped `status_message` (a DNS failure, an upstream 5xx), `decide` returns `report` precisely so nobody is sent through OAuth for a network blip (`cliproxy_auth.lua:290-295`), while this branch prompts "Log in (…)". Same input, two answers, two owners — the ARCH-DRY/ARCH-PURPOSE failure the milestone set out to remove. Fix: either derive (a `decide`-shaped entry that takes no verdict, or a small shared `health_to_action(health, login)` both call), or revise the plan to say a hand-rolled branch is intended and why.

**I3 — atlas + two docstrings still assert the inference this milestone deleted (Docs update gate).** `atlas/providers/cliproxy-managed.md:215`, `lua/parley/cliproxy.lua:882-885`, `lua/parley/cliproxy_config.lua:231-233`

The atlas's Models & providers section still reads "an unauthenticated provider contributes no models → **empty list** → the command prompts `:ParleyProxy login <provider>`. Chosen over the management API precisely because it auth-detects for free and needs no management secret" — a direct description of the behavior Task 12 replaced, and a justification for *not* doing what M2 just did. `list_models`' own docstring says the same ("An EMPTY list means the provider isn't authenticated … which the command layer turns into a `login <provider>` prompt"), as does `filter_models_by_owner`'s ("The match-or-empty is what gives per-provider auth detection"). The M1 review named these two docstrings explicitly and said the contradiction "must not survive M2". The atlas got a good new §"The recovery ladder" but no pass over the surface Task 12 actually changed.

**I4 — the repair's timeout budget was not re-checked when M2 added steps to the same claim, though the comment demands exactly that.** `lua/parley/cliproxy.lua:366-378`, `atlas/providers/cliproxy-managed.md:164-169`

Both itemize "≤15s, against a 25s backstop" and close with "Change either number and re-check the other; they are related by design, not by luck." M2 added two terms on the same claim that aren't in the list: `recover`'s pre-flight `health_probe` (≤2s, `cliproxy.lua:862`) and the `start`/`restart` rung (`stop()`'s blocking identity probe ≤2s + `ensure_running`'s probe ≤2s + `poll_until_healthy` 5s = ≤9s). A 404-repair followed by a `restart` decision worst-cases at ~26s — past `recovery_timeout_ms`, which spends the claim's one-shot and replaces the diagnosis with "recovery timed out". That is M1 round-3's I3 re-opened. Fix: update the itemization to cover the whole `recover` path, and derive the budget from `D.recovery_timeout_ms` rather than restating a constant. (Separately, `atlas/…:129` still says "A 15s `recovery_timeout_ms` backstop" while `:166` and `dispatcher.lua:27` say 25s — one file, two numbers.)

**I5 — the Task-12 specs stub `credential_health` with a signature that discards the channel, so the bug in C2 is unobservable by construction.** `tests/integration/cliproxy_command_spec.lua:88,102,117`

All three read `cliproxy.credential_health = function(cb) … end` — the second parameter (the thing C2 gets wrong) is dropped, so no assertion can ever see which key the lookup uses. This is the plan's own warning ("The fake is the deliverable, not scaffolding… the seam exists and the fake speaks HTTP", `…-plan.md:560`) and the same single-channel blindness M1 round 2 filed as I5. Fix: drive these three cases against the fake's credential store with a `gemini-cli` credential present, or at minimum assert the channel argument.

Also missing from Task 10 as planned: "add a spec that exercises **every** action value and asserts an outcome landed, so a future action added to the enum cannot silently skip this" (`…-plan.md:436`). No such spec exists, and `restart` has no integration coverage at all — which is a large part of why C1 shipped.

**I6 — the e2e's self-repair test asserts only the absence of a prompt, never that the query completed.** `tests/integration/cliproxy_recovery_e2e_spec.lua:171`

The Done-when is "repaired **and the query retried** without a prompt"; the only assertion is `assert.is_false(prompted)`, which also holds when the retry fails (a failed retry never prompts either). I verified the stronger assertions pass today, so this costs two lines:
```lua
assert.is_nil(out.failure, "the retried query still failed")
assert.is_truthy(out.content:find("ok", 1, true))
```

## 4. Minor findings

- `cliproxy.lua:785-786` — `recover`'s docstring still reads `@param _retry fun() # unused in M1: this milestone diagnoses, it never repairs`; the parameter is now `retry` and drives the whole ladder.
- `cliproxy.lua:729` — `auth_file_modtime` prefix-matches `channel .. "-"`, so channel `gemini` also matches `gemini-cli-*.json`.
- `cliproxy.lua:728` — `vim.fn.readdir` on a missing auth-dir emits `E484: Can't open file …` into the message area (verified; it does not raise), contradicting the "Best-effort — nil when the dir is unreadable" comment. Guard with `isdirectory`/`pcall`.
- `tests/fixtures/fake_cliproxy:113` — the fake's `modtime` uses `%z` (`-0700`, no colon, no fractional seconds) where the real binary emits `…46.994488305-07:00`; the conformance spec asserts `modtime` *exists* but not its shape, and the ladder now branches on comparing it (ARCH-MOCK: conformance-check the behavior you branch on).
- `cliproxy.lua:852` — the "no login offered, add it to oauth-model-alias" hint now fires only for `health.state == "missing"`; M1's restored guidance covered every needs-human state.
- `cliproxy_recovery_e2e_spec.lua:186,195` — `local port = select(2, ("x"):find("x")) -- keep luacheck quiet about unused` plus `assert.is_truthy(port)` is dead scaffolding; delete the variable instead.
- `cliproxy_recovery_e2e_spec.lua:118` — `vim.ui.select` is set in `before_each` and never restored (contained per-file, but it's the leak class `workshop/lessons.md` documents).
- Carried unfixed from M1 and still open: `dispatcher.lua:497` `deliver()` is not once-guarded; `cliproxy.lua:703` banner is 81 chars where the file's rule is 80; `render_opts()` does `mkdir` + file read on every call and sits on every query; `resolve_channel` iterates `pairs()` (nondeterministic when a model is listed under two channels); `classify_auth_files` treats a record with no `status` as healthy.

## 5. Test coverage notes

Verified independently, not from the Log: 13 specs under `providers/cliproxy-managed` → **245 examples, 0 failed, 0 errors** (`cliproxy_auth` 43, `cliproxy_config` 46, `dispatcher_query` 56, `cliproxy_lifecycle` 45, `cliproxy_auth_login` 16, `cliproxy_command` 9, `recovery_e2e` 4, `conformance` 3, `failure_notice` 6, `pre_query` 6, plus dispatch/teardown/download). Zero SKIP lines — conformance really booted the binary. `make lint` → 0/0 in 311 files. The Log's counts match exactly.

Gaps, in the order I'd close them:

1. **The rungs are not distinguishable by any test** (C1). `retry` and `restart` both end in `retry()`, so every assertion is on the settle, never on the decision. Assert `decide`'s action, or assert `stop()` is not called on the healthy path — that one line would have failed the day C1 landed.
2. **Timestamp representations are never mixed** (C1). Both sides of every staleness case are `-07:00` strings. Add `Z`/`+HH:MM`/fractional-second cases; the real payload shape is already on disk at `tests/fixtures/cliproxy_auth_files.json:14`.
3. **Single-axis blindness, again** (C2/I5). `cliproxy_auth_login_spec` learned its gemini-cli lesson; `cliproxy_command_spec` did not, and stubs away the parameter that carries the defect.
4. **No `restart`-rung integration test at all**, and no "every action value lands an outcome" spec, both of which Task 10 Step 3 specified.
5. **The self-repair e2e under-asserts** (I6) — and note it currently passes partly because parley's own restart respawns the fake in `ok` mode, racing the test's manual restart on the same port. Worth making the intent explicit rather than leaving two servers to fight over a bind.

The `decide` table-test is the best pattern in this diff — one `it` per ladder row plus a property sweep is exactly right; it just needs rows that exercise the representations the shell actually produces.

## 6. Architectural notes for upcoming work

- **ARCH-DRY — flag.** Three duplications, all in the diff: the repair sequence (`cliproxy.lua:837-844` re-implements `:411-413` minus the port wait, I1); the recovery policy (`init.lua:414-434` re-implements `decide`, I2); and a timestamp *representation* produced in one place and consumed in another with no shared normalizer (C1). Each has an obvious consolidation target that already exists.
- **ARCH-PURE — pass, with one structural caveat.** `decide` is genuinely pure and mock-free, and moving `needs_human` out of the IO shell is the milestone's best architectural move. The caveat is C1's real shape: the pure function assumes two inputs are lexicographically comparable, and nothing enforces that — the shell hands it a `Z` string and the proxy hands it an offset string. Purity doesn't protect a contract the boundary doesn't keep. Normalize to a scalar (epoch seconds) at the seam so the pure function's precondition is unfalsifiable.
- **ARCH-PURPOSE — flag.** Shadow sweep over "who infers auth state": the dispatch path derives from the management API ✓; `detect_auth_failure`/`check_auth_failure` remain gone ✓; `:ParleyProxy models` now asks the proxy instead of guessing ✓ — **but it asks with the wrong key** (C2), so for the google family the derivation is structurally present and semantically wrong, the same verdict M1 round 2 reached about `recover`. And three hand-maintained restatements of the disproved inference survive (`cliproxy.lua:882-885`, `cliproxy_config.lua:231-233`, `atlas/…:215`) — the M1 review said explicitly they must not survive M2.
- **ARCH-MOCK — pass with a gap.** The chat-completions error modes are the right addition: production and test share the HTTP boundary, the bodies are the captured real ones, and the e2e drives the real dispatch path rather than hand-built failure tables — which is what the M1 review asked for. The gap is fidelity on the one field the new ladder *branches on*: the fake emits a `modtime` shape the real binary does not (no colon in the offset, no fractional seconds), and the conformance spec pins the field's existence but not its format. A fake satisfies this principle only when the behavior we branch on is the behavior we conformance-check — and here, a faithful fake still would not have caught C1, because parley's own side is what diverges. Consider a conformance assertion that the real `modtime` parses, and that `auth_file_is_stale` returns false for the file the proxy just loaded.
- **Plan-gate carry-forward:** `workshop/plans/000197-cliproxy-auth-self-healing-plan-gate.md` `## Open findings` is empty (verified on disk — all nine PQ findings disposed across three rounds). PQ-5 was the one deferred *into* M2; it is delivered in shape but defective in substance (C2/I2). Nothing else to carry.
- **M1 review carry-forward:** the three items M1 explicitly deferred to M2 are all addressed — `needs_human` moved into `decide` ✓, the e2e spec exists ✓, Task 12 landed ✓ (with C2) — as is the design note about `retry` bypassing `pre_query` (the rungs route through `ensure_running`) ✓. Still open from M1's Minor list: unguarded `deliver()`, banner width, `render_opts` per-call filesystem work, `resolve_channel`'s `pairs()` nondeterminism, status-less record read as healthy.
- **For M3:** `parse_peers` will want the same axis discipline (`cliproxyapi` vs `cli-proxy-api`, already noted in the Log), and `stop()` is now called from three paths — the port-release discipline should be one helper before a fourth caller appears.

## 7. Plan revision recommendations

Add a `## Revisions` entry to `workshop/plans/000197-cliproxy-auth-self-healing-plan.md`:

1. **The `decide` table's `expired` row no longer matches the code.** The table (`…-plan.md:421`) says `expired | true | any | any | prompt_login`; the shipped policy retries on `healthy` (deliberately — prompting while displaying "looks healthy" is self-contradictory) and reports on `unknown`. Correct the row so the table stays the greppable contract.
2. **State the staleness comparison as a normalization, not a string compare.** Task 9 Step 3 says "the staleness comparison is a string compare on RFC3339 timestamps only when both are present" (`…-plan.md:427`) — that is the instruction C1 followed, and it is only valid when both sides carry the same offset, which the shell cannot guarantee. Record that both timestamps are normalized to epoch seconds at the IO seam (with the source of each: `uv.fs_stat().mtime.sec` and cliproxy's offset-bearing, fractional-second RFC3339), and that `proxy_state` carries `auth_file_modtime` compared against `health.modtime` (the plan still names a `record_modtime` field that does not exist).
3. **Task 12 needs a provider→channels resolver, and the plan should say which policy it shares.** The plan says "Route it through `auth_files` + `decide`"; the code routes through `credential_health` plus a private ladder, and `decide` needs a verdict this command has no way to produce. Record the intended shape — a pure `channels_for_login` derived from `CHANNEL_LOGIN`, plus whichever health→action helper both consumers share — so the third axis (`providers()` vs channel vs login) is named in the plan the way M1 round 2 named the first two.
4. **Record the M2 terms of the repair budget.** Task 5's itemization predates `recover`'s pre-flight liveness probe and the `start`/`restart` rung; say the budget covers the whole claimed path and is derived from `recovery_timeout_ms`, not restated beside it.
5. **Task 10 Step 3's exhaustive-action spec was not delivered** — either tick it with the spec, or record why the `execute` fall-through (a bare `give_up`) is deemed sufficient.

---

## Re-review — 2026-08-01T12:02:49-07:00 (REWORK)

| field | value |
|-------|-------|
| issue | 197 — cliproxy auth failures must self-heal: detect, diagnose, recover |
| repo | parley.nvim |
| issue file | workshop/issues/000197-cliproxy-auth-self-healing.md |
| boundary | milestone M2 |
| milestone | M2 |
| window | 819a781a71859450cb5f22aa6940d9213004bb70..HEAD |
| command | sdlc milestone-close --issue 197 --milestone M2 |
| reviewer | claude |
| timestamp | 2026-08-01T12:02:49-07:00 |
| verdict | REWORK |

## Review

```verdict
verdict: REWORK
confidence: high
```

The rework from round 1 is substantial and mostly right: `decide`/`credential_action` are genuinely pure and shared by both consumers, `channels_for_login` derives the third axis from `CHANNEL_LOGIN` instead of adding a table, `restart_managed` collapses the duplicated repair sequence, and the fake's `_once` transient modes let the e2e assert the answer actually arrives. I re-ran everything independently against the committed HEAD (the working tree carries uncommitted M3 work, so I extracted `ad2ce42` to review): all 14 mapped specs green — `cliproxy_auth` 46, `cliproxy_config` 46, `cliproxy_budget` 2, `dispatcher_query` 56, `cliproxy_auth_login` 17, `cliproxy_command` 10, `cliproxy_recovery_e2e` 4, `cliproxy_conformance` 3 (real binary, no skip) — and `make lint` 0/0 in 312 files. The Log's counts match. What blocks SHIP is that the C1 fix introduced a new, verified defect of the same class it replaced: `rfc3339_sec` returns the wrong epoch — off by exactly one day — for **every date in a leap year**, which kills the `restart` rung from 2028-01-01 onward. I confirmed this against Python's reference for 2000, 2020, 2024 and 2028. It survived review because every staleness test feeds the parser's own output back in as the "disk" side, so the entire suite is invariant under any parser error. Alongside it, the budget's "mutually exclusive" argument is false (a 404 repair *can* be followed by a `restart`, ~28s against a 25s backstop), and `auth_file_modtime`'s prefix match makes the `gemini` channel read `gemini-cli`'s file.

## 1. Strengths

- **`decide` + `credential_action` are one policy with two real consumers.** `credential_action` (`lua/parley/cliproxy_auth.lua:311`) is called from both `decide` (`:364`) and `init.lua:419-420`, so the round-1 I2 divergence on `error` is genuinely gone — not documented away. Both now report on a DNS-shaped `error` and prompt only on an auth-shaped one.
- **C2's fix is derived, not restated.** `channels_for_login` (`cliproxy_config.lua:195`) inverts `CHANNEL_LOGIN` rather than adding a third hand-maintained table (ARCH-DRY), and `cliproxy_command_spec.lua:117-136` now asserts the exact channel set `{aistudio, gemini, gemini-cli}` — closing round 1's I5, where the stub discarded the very argument carrying the bug.
- **`restart_managed` (`cliproxy.lua:375`) is the right extraction.** Both the 404 repair (`:436`) and the ladder's `restart` rung (`:892`) now go through the port-release wait, and the comment explaining why the wait can't be caught by the Python fake travelled with it.
- **The e2e now proves the Done-when rather than its shadow** (`cliproxy_recovery_e2e_spec.lua:156-161`): `assert.is_nil(out.failure)` + `assert.matches("ok", out.content)`, driven by the fake's `_once` mode. Modelling transience *inside* the fake instead of swapping servers mid-flight is the better ARCH-MOCK answer, and it removed the race round 1 flagged.
- **Task 10's exhaustive-action spec is delivered** (`cliproxy_auth_login_spec.lua:315-339`) and drives all five actions through the real `recover`, giving `restart` its only integration path.

## 2. Critical findings

**C1 — `rfc3339_sec` is off by +1 day for every date in a leap year, so the `restart` rung goes dead for all of 2028 and every leap year after.** `lua/parley/cliproxy_auth.lua:258-284` (specifically `:268` and `:273`)

The days-before-year-Y term `math.floor(y/4) - math.floor(y/100) + math.floor(y/400)` counts year Y's **own** leap day, so `days` is one too high whenever Y is a leap year; the separate `mm > 2` adjustment at `:273` does not cancel it. Verified at HEAD against Python's `datetime`:

```
2026-08-01T18:35:01Z    got=1785609301  want=1785609301  +0    OK
2024-02-29T00:00:00Z    got=1709251200  want=1709164800  +1d   WRONG
2024-03-01T00:00:00Z    got=1709337600  want=1709251200  +1d   WRONG
2028-06-15T12:00:00Z    got=1844769600  want=1844683200  +1d   WRONG
2020-01-01T00:00:00Z    got=1577923200  want=1577836800  +1d   WRONG
2000-03-01T00:00:00Z    got=951955200   want=951868800   +1d   WRONG
```

Failure scenario: from 2028-01-01, `loaded` is 86400s larger than the true instant, so `disk > loaded + STALE_SKEW_SEC` (`:299`) is never true — `auth_file_is_stale` returns false for a file that is genuinely up to a day newer, `decide` falls through to `retry`, and the stale-in-memory-auth repair the issue's Done-when promises silently stops existing. This is the "never-stale east of UTC / dead rung" half of round 1's C1, reintroduced on the calendar axis instead of the timezone axis. It is wrong *today* as a documented public function (`M.rfc3339_sec`, "Parse an RFC3339 timestamp to epoch seconds") in the base-layer repo that propagates to consumers; only the behavioral manifestation is deferred.

Fix sketch — count leap years strictly *before* Y:

```lua
local yy = tonumber(y)
local prev = yy - 1
local days = (yy * 365) + math.floor(prev / 4) - math.floor(prev / 100) + math.floor(prev / 400)
-- epoch_days is unchanged: floor(1969/4)=492, floor(1969/100)=19, floor(1969/400)=4
```

The test that must come with it is the point (see I5): assert **absolute** epochs, not the parser against itself, and include at least one leap-year date —

```lua
assert.equals(1785609301, ca.rfc3339_sec("2026-08-01T18:35:01Z"))
assert.equals(1709164800, ca.rfc3339_sec("2024-02-29T00:00:00Z")) -- fails today
assert.equals(1844683200, ca.rfc3339_sec("2028-06-15T12:00:00Z")) -- fails today
```

## 3. Important findings

**I1 — the budget's "mutually exclusive" argument is false; a 404 repair followed by a `restart` costs ~28s against the 25s backstop, and the spec that is supposed to prevent this drift cannot see it.** `lua/parley/cliproxy.lua:400-404`, `:336`, `tests/unit/cliproxy_budget_spec.lua`

The comment claims "a `restart` follows a SUCCESSFUL read, which means no repair ran". The successful read can be the **second** read *after* the repair: `credential_health` (`:436-442`) calls `restart_managed`, then re-reads `auth_files`, then hands `second` to `cb` — and `recover` (`:920-923`) feeds exactly that into `decide`, which can return `restart` (`cliproxy_auth.lua:373`) and drive `restart_managed` a second time (`:892`). Path cost: probe 2 + auth_files 2 + [repair: stop 2 + release 2 + ensure 2 + poll 5 + read 2] + [restart: stop 2 + release 2 + ensure 2 + poll 5] = **28s**. Reachable when a login writes the auth file during the ~11s repair window.

Compounding it, two terms are understated even on the non-compound path: `wait_port_released` (`:356`) and `poll_until_healthy` (`:530`) check their wall-clock deadline only *after* a probe returns, so each can overrun by one `--max-time 2` curl — real bounds 4s and 7s, not the table's 2s and 5s, making the plain 404 repair ~21s against a claimed 17s. `cliproxy_budget_spec` detects neither, because it sums `M._repair_budget_sec` — a hand-maintained restatement of the path — against the dispatcher constant. This is the third round the budget has been re-opened (M1 round 3 I3, M2 round 1 I4). Fix: either make the compound case unreachable (skip the `restart` rung when the 404 repair already restarted this proxy — the guard state is right there in `_management_restart_done`), or derive the terms from the constants they name (`POLL_BUDGET_MS`, the port-release deadline, `--max-time`) plus the per-step probe overrun, so the table cannot be right while the code is wrong.

**I2 — `auth_file_modtime` prefix-matches, so channel `gemini` reads `gemini-cli`'s credential file and takes the `restart` rung forever after a gemini-cli login.** `lua/parley/cliproxy.lua:772-788` (`:780`)

Verified:

```
files on disk: gemini-cli-g@example.com.json, aistudio-g@example.com.json
channel "gemini" matched: { "gemini-cli-g@example.com.json" }
```

Failure scenario: an operator logs in to gemini-cli. A later `gemini`-channel failure reads `auth_file_modtime("gemini")` → the gemini-cli file's mtime, which is permanently newer than gemini's own record `modtime` → `restart` on **every** subsequent gemini failure, SIGTERMing a possibly-shared proxy — precisely the harm round 1's C1 was raised for. This was round 1's Minor; C1's fix made the comparison load-bearing, so it now has teeth.

Fix sketch (ARCH-DRY, removes the second channel→file mapping entirely): the management record already carries `path`, and `classify_auth_files` already picked the winning record by channel. Carry `path` through health and `uv.fs_stat(health.path).mtime.sec` in the shell — no directory glob, no duplicated auth-dir default (`:774-777`), no E484 (Minor below). That needs `path` added to `REQUIRED_FIELDS` in `cliproxy_conformance_spec.lua:24-27`.

**I3 — `decide` raises on a malformed `modtime`, and the throw is outside the dispatcher's guard, so the claim is never settled.** `lua/parley/cliproxy_auth.lua:273`

`mdays[mm]` is nil for month `00` or `13`; verified:

```
decide with month=13: ok=false err=cliproxy_auth.lua:323: attempt to perform arithmetic on a nil value
```

The dispatcher's `pcall` (`dispatcher.lua:477`) wraps only the **synchronous** claim; `decide` runs inside `credential_health`'s async callback (`cliproxy.lua:922`), so a throw there settles nothing and the operator gets "recovery timed out" 25s later instead of the diagnosis — the exact outcome the budget note exists to prevent. Input is proxy-supplied JSON, so likelihood is low, but a documented pure function on the ladder's critical path should be total. Fix: range-check `mo` (and `d`) before indexing, returning nil like every other unparseable input.

**I4 — Docs update gate: the atlas now carries three different numbers for one budget, two of them wrong.** `atlas/providers/cliproxy-managed.md:129`, `:164-166`

`:129` still reads "A 15s `recovery_timeout_ms` backstop" against `dispatcher.lua:27`'s 25000 — flagged in round 1, unfixed. Worse, the **new** "Timeout budget" paragraph added in this same window (`:164`) says "The repair's worst case (≤15s: …)" while the code comment and `M._repair_budget_sec` added in the same window say ≤17s, and its itemization omits `recover`'s liveness probe — the term round 1 flagged as missing. A doc that restates a number the code already owns will keep drifting; state the relationship, not the arithmetic.

**I5 — the staleness suite is structurally incapable of catching a parser bug, and the seam where the previous C1 lived is still untested.** `tests/unit/cliproxy_auth_spec.lua:298-334`, `lua/parley/cliproxy.lua:772`

Every staleness case supplies the "disk" side as `ca.rfc3339_sec(...)`'s own output (`:301` `= ca.rfc3339_sec(loaded) + 3600`, `:322` `= sec`, `:348` `= ca.rfc3339_sec(loaded) + 1`), and the parser's own test compares it only to itself (`:329-332`: `assert.equals(utc, ca.rfc3339_sec("2026-08-01T11:35:01-07:00"))`). Any systematic parser error cancels on both sides — which is why C1 above is green. The one variable holding an absolute instant, `local instant = 1785000000` (`:305`), is never compared to anything; it ends at `assert.is_truthy(instant)` (`:326`).

Separately, `auth_file_modtime` — the IO function where round 1's C1 actually lived — still has **zero** coverage. Round 1's #1 recommended gap was "assert `stop()` is not called on the healthy path — that one line would have failed the day C1 landed"; the assertion was not added, and no integration test drives the stale path through the fake. The `restart` rung's *decision* is exercised only by the exhaustive spec, which forces the action and bypasses `decide` entirely.

## 4. Minor findings

- `cliproxy.lua:836` — `@param _retry fun() # unused in M1: this milestone diagnoses, it never repairs`; the parameter is `retry` and drives the whole ladder. Flagged round 1, unfixed.
- `cliproxy.lua:779` — `vim.fn.readdir` on a missing auth-dir prints `E484: Can't open file …` to the message area (verified; it does not raise), contradicting best-effort intent, on the one path whose purpose is a clean diagnosis. Flagged round 1, unfixed; disappears with I2's fix.
- `cliproxy_recovery_e2e_spec.lua:186,195` — `local port = select(2, ("x"):find("x")) -- keep luacheck quiet about unused` + `assert.is_truthy(port)` is still dead scaffolding. Flagged round 1, unfixed. Same pattern newly added at `cliproxy_auth_spec.lua:305,326`.
- `cliproxy_recovery_e2e_spec.lua:118` — `vim.ui.select` set in `before_each`, never restored.
- `cliproxy.lua:459-476` — `credential_health_for_login` issues one full `/v0/management/auth-files` request per channel (3 curls + 3 management-key file reads for `google`) when a single response already contains every channel; `classify_auth_files(files, ch)` per channel over one body would do, and would remove the 3-way fan-in on the 404-repair guard.
- `cliproxy_auth_login_spec.lua:336` — the exhaustive spec waits on `settles > 0` then asserts `== 1`, so a *second* settle arriving after the wait is not caught; a short additional `vim.wait` closes it.
- Carried unfixed from M1 and still open: `render_opts()` does `mkdir` + a file read on every call and sits on every query; `resolve_channel` iterates `pairs()` (nondeterministic when a model is listed under two channels); `classify_auth_files` treats a record with no `status` as healthy (`cliproxy_auth.lua:131`).
- Round 1's `deliver()`-not-once-guarded note: verified not a defect — `deliver` is reached only via `tasker.once` or the unclaimed fall-through.

## 5. Test coverage notes

Verified independently against `ad2ce42` (the tree is dirty with M3 WIP; I extracted HEAD to review and ran the M2 specs from the working tree, whose M3 additions are purely additive — `git diff HEAD` shows insertions only): `cliproxy_auth` 46, `cliproxy_config` 46, `cliproxy_budget` 2, `failure_notice` 6, `providers_pre_query` 6, `dispatcher_query` 56, `cliproxy_auth_login` 17, `cliproxy_command` 10, `cliproxy_recovery_e2e` 4, `cliproxy_conformance` 3 (real 7.1.71, no SKIP). `make lint` 0/0 in 312 files. Every count in the Log checks out. The three failures I saw in the M3 `peers and reap` block are uncommitted WIP outside this window.

Gaps, in the order I'd close them:

1. **Absolute-epoch assertions for `rfc3339_sec`** (C1/I5) — self-comparison cannot falsify a parser. One leap-year row would have caught this.
2. **Break the self-reference in the staleness rows** — supply the disk side as a literal epoch, not `rfc3339_sec(...)`'s output.
3. **`auth_file_modtime` has no test at all** (I2/I5) — a case with `gemini-cli-*.json` on disk asserting `auth_file_modtime("gemini")` is nil, and an integration case asserting `stop()` is not called when the credential is healthy.
4. **The `restart` decision has no end-to-end path** — the exhaustive spec forces the action; nothing drives fake-modtime + real-file-mtime through `decide`.
5. **The budget spec asserts its own table** (I1), not the code. Deriving the terms from `POLL_BUDGET_MS`, the port-release deadline and `--max-time` would make it a real gate.

## 6. Architectural notes for upcoming work

- **ARCH-DRY — flag.** Two restatements remain: `auth_file_modtime` re-derives channel→file *and* the auth-dir default that the management record's `path` already gives (I2), and `M._repair_budget_sec` restates by hand a path the code owns (I1). Everything else in this diff consolidated correctly — `restart_managed`, `credential_action`, `channels_for_login`, `healthier` are all single-source and all have two real callers.
- **ARCH-PURE — pass with a flag.** `decide`, `credential_action` and `rfc3339_sec` are genuinely pure, mock-free, and carry 46 unit examples; `recover` is now gather-then-execute with no policy in it. The flag is that purity bought less than it should have: `rfc3339_sec` is *partial* where the ladder needs it total (I3), and its correctness is unverified because the tests are self-referential (I5). A pure function is only as trustworthy as an assertion against an external oracle — here, a known epoch.
- **ARCH-PURPOSE — pass on the shadow sweep.** Enumerating "who infers auth state": the dispatch path derives from the management API ✓; `:ParleyProxy models` now derives, and on the correct channel axis ✓ (C2 closed); all three hand-maintained restatements of the disproved empty-list inference are corrected (`cliproxy.lua:932-936`, `cliproxy_config.lua:249-253`, `atlas/…:211-221`) ✓. The residue is the budget: still documentation asserting what the code does, restated in the atlas with a third number (I1/I4).
- **ARCH-MOCK — pass with a gap.** `--error-mode` and the `_once` transient modes are the right shape: the captured 7.1.71 bodies over the same HTTP boundary production uses, with the state that makes "transient" real living inside the fake. The gap is fidelity on the one field the ladder branches on — the fake emits `%z` (`-0700`, `fake_cliproxy:115`) where the real binary emits `.994488305-07:00`, and `REQUIRED_FIELDS` (`cliproxy_conformance_spec.lua:24-27`) pins `modtime`'s *existence* but not that it parses. One line — `assert.is_not_nil(ca.rfc3339_sec(record.modtime))` — would conformance-check the behavior we branch on.
- **Plan-gate carry-forward:** `workshop/plans/000197-cliproxy-auth-self-healing-plan-gate.md` `## Open findings` reads "(none — every finding has been disposed)" (verified on disk). PQ-5 was the item deferred into M2; it is delivered and, after C2's fix, delivered on the right axis. Nothing to carry.
- **Core concepts cross-check:** every row verifies. `classify_response`/`classify_auth_files`/`diagnosis` at `cliproxy_auth.lua` ✓, `resolve_channel` + `render` at `cliproxy_config.lua` ✓, `detect_auth_failure` absent from the tree ✓, `_failure_notice` in `chat_respond.lua` ✓, `decide` at `cliproxy_auth.lua:347` ✓ (M2, new), `parse_peers` correctly still absent (M3). All PURE rows run without IO — `cliproxy_auth_spec` uses no mocks. The table is *incomplete* rather than wrong: `credential_action`, `rfc3339_sec`, `healthier` and `channels_for_login` are four new pure entities introduced this milestone with no row (see §7).
- **For M3:** `stop()` will have a fourth caller once `reap` lands — the port-release discipline should be one helper before that, and `parse_peers` needs the same axis care (`cliproxyapi` vs `cli-proxy-api`, already in the Log).

## 7. Plan revision recommendations

Append to `workshop/plans/000197-cliproxy-auth-self-healing-plan.md` `## Revisions`:

1. **The `decide` table's `expired` row still contradicts the code** — `:421` reads `` | `expired` | true | any | any | `prompt_login` | `` while the shipped policy retries on `healthy` (deliberately) and reports on `unknown`. This was plan-revision recommendation #1 from the M2 round-1 review and is the one item the rework's five Revisions entries did not cover. The table is the greppable contract; correct the row or record why it stands.
2. **The four new pure entities are missing from Core concepts** — `credential_action`, `rfc3339_sec` and `healthier` (`cliproxy_auth.lua`) and `channels_for_login` (`cliproxy_config.lua`) are all new M2 pure entities the Revisions prose names but the greppable table does not list. Add rows with kind/location/status/milestone so an M3 reviewer cross-checking the table against the filesystem sees the real surface.
3. **Record `rfc3339_sec`'s contract, not just its existence** — that it must be total (nil for any unparseable input, including out-of-range months) and that its tests assert absolute epochs against an external oracle including a leap-year date. The self-referential test shape is what let both C1s through; naming it in the plan is what stops a third.
4. **Restate the budget as a derivation** — Revisions entry #4 says the budget "is asserted by `cliproxy_budget_spec` rather than restated in a comment", but the spec sums a hand-written table. Record that the terms derive from `POLL_BUDGET_MS`, the port-release deadline and `--max-time` (including the one-probe overrun each bounded loop can incur), and that the 404-repair-then-`restart` composition is either excluded by construction or included in the worst case.
