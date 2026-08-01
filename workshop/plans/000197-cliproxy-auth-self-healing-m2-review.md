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
