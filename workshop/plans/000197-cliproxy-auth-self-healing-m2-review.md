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

---

## Re-review — 2026-08-01T12:28:31-07:00 (REWORK)

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
| timestamp | 2026-08-01T12:28:31-07:00 |
| verdict | REWORK |

## Review

```verdict
verdict: REWORK
confidence: high
```

M2's architecture is sound and the round-2 rework genuinely landed: `rfc3339_sec` is now correct (I verified it against an external oracle including 2024/2028/2100 and the 400-year rule — all exact), `decide`/`credential_action` are one pure policy with two real consumers, `restart_managed` collapsed the duplicated repair, and the `_once` fake modes let the e2e prove the answer actually arrives. I re-ran everything independently: 15 mapped specs, **275 examples, 0 failed, 0 errors** (conformance really booted a real binary), `make lint` **0/0 in 313 files** — every count in the Log checks out. What blocks SHIP is that the restart rung has been fixed twice on the wrong axis and is still wrong on a third: **`health.modtime` is the credential file's own mtime, re-stat'd by the proxy at request time**, and `loaded_credential_mtime` stats *the same file* — so `auth_file_is_stale` compares a value to itself and the `restart` rung is unreachable. I proved this three ways: two live probes against the real binary (after `touch`, `modtime` advanced with no restart; `updated_at` did not), and an end-to-end run through this repo's own fake in the honest scenario (`disk mtime=1785612284 | parsed loaded=1785612284 | ACTION=retry`, `stops=0`). The one test covering the rung passes only because it injects `modtime="2020-01-01T00:00:00Z"` through the fake's overlay — a value neither the fake's own record-builder nor the binary can produce. That leaves the issue's Done-when "a recoverable failure (proxy down, **stale in-memory auth**, transient) is repaired" undelivered. Alongside it, this window also carries three M3 commits that no boundary review has seen, and M3's new code repeats the axis and timestamp-compare mistakes the milestone's own lessons just recorded.

## 1. Strengths

- **`rfc3339_sec` is now genuinely correct, not just green.** I checked it against Python-derived epochs the repo doesn't contain — `2100-03-01T00:00:00Z → 4107542400` (the 400-year non-leap rule) — and every case matched. Round 2's C1 is properly closed, and the "external oracle" assertions at `tests/unit/cliproxy_auth_spec.lua:333-342` are the right shape.
- **One policy, two real consumers.** `credential_action` (`cliproxy_auth.lua:374`) is called from `decide` (`:427`) and `init.lua:419` — the round-1 I2 divergence on `error` is structurally gone, and `cliproxy_command_spec.lua:117-136` asserts the exact channel set `{aistudio, gemini, gemini-cli}`, which pins the C2 fix on the axis that actually carries it.
- **`restart_managed` (`cliproxy.lua:398`) is the correct extraction** — both the 404 repair (`:456`) and the ladder's restart rung (`:1173`) now inherit the port-release wait, and the comment explaining why no Python-fake test can catch its absence travelled with the code.
- **The anti-loop property test (`cliproxy_auth_spec.lua:379-393`)** sweeps 5 kinds × 6 states × liveness at `attempt=1` and asserts no repair action can be returned. That is the safety argument expressed as a property rather than a case list, and it is the strongest test in the diff.
- **`--error-mode` + `_once` (`tests/fixtures/fake_cliproxy:203-240`)** put the transience *inside* the fake instead of swapping servers mid-flight, which is what lets `cliproxy_recovery_e2e_spec.lua:156-161` assert `out.failure == nil` and `content` contains the answer — the Done-when, not its shadow.

## 2. Critical findings

**C1 — `auth_file_is_stale` compares the credential file's mtime against itself, so the `restart` rung is dead code and the "stale in-memory auth" repair does not exist.** `lua/parley/cliproxy.lua:885-892` + `lua/parley/cliproxy_auth.lua:359-363`

`loaded_credential_mtime(health)` returns `uv.fs_stat(health.path).mtime.sec`. `auth_file_is_stale` compares that against `rfc3339_sec(health.modtime)`. The premise — that `modtime` is "the copy the proxy loaded" — is false. Probed live against the installed binary (7.2.110), touching the credential with **no restart**:

```
read 1:  modtime = 2026-08-01T12:12:37.068024338-07:00   file mtime = 12:12:37.068024
  touch
read 2:  modtime = 2026-08-01T12:12:43.181687-07:00      file mtime = 12:12:43.181687
```

`modtime` tracks the file on disk, re-stat'd per request. A second probe with a real **content** rewrite (what a fresh login does) shows the field that actually carries load time:

```
before: modtime=12:16:21.235762407  updated_at=12:16:21.556781
after:  modtime=12:16:27.331418643  updated_at=12:16:27.331998   (watcher reloaded)
touch-only case: modtime advanced, updated_at did NOT
```

Driven end to end through this repo's own harness and fake, in the honest scenario (proxy holding the credential, file rewritten ~1.5s later, no `state.json` override):

```
REVIEW: proxy-reported modtime=2026-08-01T12:24:44-0700 | disk mtime(sec)=1785612284
      | parsed loaded(sec)=1785612284 | ACTION=retry
REVIEW: settled=retry stops=0 health.state=healthy
```

Bit-identical, because they are the same quantity. Failure scenario: an operator's proxy misses an fsnotify write (the case the Spec calls out — "the proxy hot-reloads auth files … restart is a fallback"), the credential on disk is fresh and the in-memory one is dead, and the ladder returns `retry` forever. `attempt` then forbids any repair on the second pass, so the operator gets a report. The `restart` row in the atlas ladder table (`atlas/providers/cliproxy-managed.md:151`) describes behavior that cannot occur.

Both prior rounds fixed the *comparison* (timezone axis, then calendar axis) without ever asking whether the two sides are the same quantity — this is the third instance of that class in one milestone.

Fix sketch — compare within the record; no `fs_stat`, and the check becomes fully pure (dropping an IO term from the repair budget too):
```lua
-- cliproxy_auth.lua
local function auth_file_is_stale(health)
    local on_disk = M.rfc3339_sec(health and health.modtime)   -- file mtime
    local loaded  = M.rfc3339_sec(health and health.updated_at) -- in-memory load
    return on_disk ~= nil and loaded ~= nil and on_disk > loaded + STALE_SKEW_SEC
end
```
This needs `updated_at` carried through `classify_auth_files` (beside `path`), added to `REQUIRED_FIELDS` in `cliproxy_conformance_spec.lua:24-27`, and — the part that matters most — a test that does **not** fabricate `modtime`. Delete the `state.json` override at `tests/integration/cliproxy_auth_login_spec.lua:372` and reproduce staleness the way the system produces it (the fake would need to model `updated_at` as load time, which is one line and is what makes the fake honest here). Also verify against the real binary that `updated_at` is stable across an *unloaded* write, since that is the exact signal being relied on.

## 3. Important findings

**I1 — `:ParleyProxy reap` is unreachable by discovery: absent from `SUBS_HELP`, from completion, and from README (Docs update gate + ARCH-DRY).** `lua/parley/init.lua:326-335`, `README.md:191`

`SUBS_HELP` lists eight subcommands, no `reap`; `SUBS = vim.tbl_map(…, SUBS_HELP)` feeds `complete`, so `:ParleyProxy re<Tab>` yields nothing and bare `:ParleyProxy` never mentions it. The atlas states outright that `SUBS_HELP` "is the single source for both the usage text and the completion list (ARCH-DRY)" — this new branch is the first thing to bypass it. `README.md:191` still enumerates `status|start|stop|restart|models <provider>|providers|login <provider>|update`. A prevention feature the operator cannot find does not prevent anything. Fix: one row in `SUBS_HELP`, one word in README.

**I2 — the `_stray_spawned` sweep is dead code, and its regression test does not pin it.** `lua/parley/cliproxy.lua:31-34, 524, 676-686`, `tests/integration/cliproxy_lifecycle_spec.lua:919`

`_spawned[pid]` is set on every spawn (`:523`) and never removed for any individual pid — only wholesale in `_reset_spawned()` and at `stop():666`, *after* the loop at `:662-665` has already SIGTERMed everything in it. So every pid in `_stray_spawned` is, by construction, already in `_spawned`. I deleted the entire sweep in a scratch copy and re-ran the spec:

```
Success || cliproxy IO lifecycle peers and reap stop() also reaps a parley-spawned proxy on a non-managed port
Success: 49   Failed: 0   Errors: 0
```

The test passes without the code it was written to pin (the M1 review used exactly this deletability check on `recover_query`'s registration). The code comment's rationale — "`_spawned` is cleared by stop()" — is backwards. Worth stating plainly: the actual #197 leak was proxies from *previous* nvim sessions, which neither `_spawned` nor `_stray_spawned` can reach; only `reap` addresses it, and the atlas + Log claim of a `stop()` fix overstates what changed.

**I3 — `run_login` resolves the wrong channel and `await_credential` ignores its channel entirely — the third-axis defect, in the code shipped after fixing it.** `lua/parley/cliproxy.lua:963, 989, 1044-1050`

`channels_for_login("google")` returns sorted `{aistudio, gemini, gemini-cli}`, so `[1]` is `aistudio` — but a `-login` writes a `gemini-cli-*.json`. `credential_health(cb, "aistudio")` then reads `missing`, and the success notice degrades to `"cliproxy: google login succeeded"` with no account for the one provider the whole third-axis fix was about. `codex-device` resolves to no channels at all and falls through to itself. `credential_health_for_login` — written this milestone for exactly this — is not used here. Separately, `await_credential(_channel, …)` discards the channel and `newest_credential_mtime` scans every `*.json` in the auth-dir, so a peer proxy's 15-minute token refresh rewriting an unrelated credential satisfies the watch and reports a login that never completed. Fix: `credential_health_for_login(provider, …)` for the report, and filter the watch by each file's decoded `type`.

**I4 — `run_login` can settle twice, emitting a spurious "login did not complete" three minutes after the failure was already reported.** `lua/parley/cliproxy.lua:1029-1036` vs `:1044`

`on_exit` with a non-zero code calls `on_done(false)` immediately, but `await_credential` was already started and keeps polling to its 180 000 ms deadline, then calls `on_done` a second time and notifies at WARN. Failure scenario: `dies_early` (the #197 mode) → operator sees "claude login exited 3", re-runs successfully → the *first* watcher is still live and fires again on the new credential, or times out and tells them the login they just completed did not complete. The `dies_early` spec (`tests/integration/cliproxy_login_spec.lua:79-88`) can't see it because it stops waiting at 20s. Fix: one `tasker.once`-style latch around `on_done`, and `jobstop` + cancel the watch on the exit path.

**I5 — `peers()` runs a blocking `ps ax` + `lsof` on every query, for a warning that fires once per session.** `lua/parley/cliproxy.lua:589-592`

`ensure_running` is the cliproxyapi adapter's `pre_query`, so this is on the dispatch hot path, and both `vim.system(...):wait()` calls block the event loop. Measured here: `lsof -nP -iTCP:<port>` ≈ **80–90 ms**, three runs. The once-per-session guard `_peer_warning_shown` lives *inside* `warn_about_peers`, after the expensive call. Fix: check the flag first — `if not _peer_warning_shown then pcall(function() M.warn_about_peers(M.peers()) end) end`.

**I6 — `reap()` does not perform the identity probe its docstring and the plan both promise.** `lua/parley/cliproxy.lua:845-865`

The docstring says "after an identity probe per pid so a process that merely shares a name is never killed" and plan Task 14 Step 3 says "SIGTERMs peers **after an identity probe** (reuse `port_holds_cliproxy`'s discipline)". The code does `peer.command:match("%-config%s")` — a command-line substring test. `parse_peers`' executable matching is good defence, but this is a documented contract the code does not keep, on a function that sends SIGTERM. Also `pcall(uv.kill, …)` returns true even when `uv.kill` returns `nil, err`, so `killed` counts processes that were not killed.

**I7 — the compound "404 repair then restart" path is not made unreachable as the code and atlas claim; it is ~36s against a 30s backstop.** `lua/parley/cliproxy.lua:422-424, 456-462, 1163-1173`

`execute` guards the restart rung on `_management_restart_done`, but `credential_health`'s second read clears that flag (`:458-460`) *before* invoking `cb`, and `cb` is what computes the decision. So the guard reads `false` on exactly the path it exists to block. Terms: probe 2 + auth_files 2 + [repair: stop 2 + release 4 + ensure 2 + poll 7] + read 2 + [restart: stop 2 + release 4 + ensure 2 + poll 7] = **36s**. Latent only because C1 makes `restart` unreachable — it goes live the moment C1 is fixed. This is the third round this budget relationship has been re-opened; the derived table (`M._repair_budget_sec`, 21s) is a good improvement but it models the single-repair path only. Fix: latch a per-claim boolean in `recover` rather than reading module state that the repair itself resets, and add the compound case to the budget or to `cliproxy_budget_spec`.

**I8 — `warn_about_peers` picks the "oldest" peer by lexicographic compare of `ps lstart`, which starts with the day of the week.** `lua/parley/cliproxy.lua:832-837`

Verified counterexample:
```
peers: "Fri Aug  1 03:00:00 2026" and "Mon Jun 15 09:00:00 2026"
oldest chosen: the Aug 1 one   (truth: Jun 15)
```
The date is the only thing making the count actionable ("oldest since %s"), and the fixture test (`cliproxy_lifecycle_spec.lua`, asserting `Jun 12`) passes by luck because `F` < `S`. This is a new string-compare-on-timestamps in the same window as two `lessons.md` rules forbidding exactly that, tested with the same degenerate-fixture shape a third rule warns about. Fix: parse `lstart` (or carry `etime`/start epoch from `ps -o lstart=` → a numeric field) and compare numbers.

**I9 — `atlas/providers/cliproxy-managed.md:129` still says "A 15s `recovery_timeout_ms` backstop"; the code says 30000.** Flagged at M2 round 1 (I4) and round 2 (I4); the number has since moved 25000 → 30000, so the doc is now off by 2×. The new "Timeout budget" paragraph correctly refuses to restate arithmetic — `:129` is the leftover that should get the same treatment (name the relationship, not the number).

**I10 — scope: this M2 window contains three M3 commits, and M3 is already ticked `[x]` in the issue Plan with no boundary review of its own.** `ba0992d`, `bf98f8d`, `65d4402`

Per AGENTS.md §3 an `Mx` row commits to its own `milestone-close`; M2's two prior verdicts were REWORK, so the boundary was never crossed, yet M3 landed on top. The practical consequence is that this review is the only fresh-eyes pass M3 will get — which is where C1's cousins (I3, I6, I8) live. Either run `milestone-close --milestone M3` separately after this rework, or state in the Log that M2's review deliberately absorbed M3 and record the verdict against both. Relatedly, the plan's checkboxes for Tasks 9–15 are unticked apart from a single `[x]` at line 425, so the plan does not reflect what shipped.

## 4. Minor findings

- `lua/parley/cliproxy.lua:1108` — `@param _retry fun() # unused in M1: this milestone diagnoses, it never repairs`; the parameter is `retry` and drives the ladder. Flagged in round 1 and round 2, still unfixed.
- The Log records conformance as "real 7.1.71"; `discover_binary` resolves to `/opt/homebrew/bin/cliproxyapi` = **7.2.110** (the spec's `_set_data_dir(tempname())` hides the 7.1.71 tarball binary). Conforming against the newer binary is fine — the label is what's wrong, and `PINNED_VERSION = "7.1.71"` means download and conformance test different versions.
- `tests/integration/cliproxy_recovery_e2e_spec.lua:186,195` — `local port = select(2, ("x"):find("x")) -- keep luacheck quiet about unused` plus `assert.is_truthy(port)` is still dead scaffolding (flagged twice). Same pattern at `cliproxy_auth_spec.lua:305,326`.
- `tests/integration/cliproxy_recovery_e2e_spec.lua:118` — `vim.ui.select` replaced in `before_each`, never restored.
- `lua/parley/cliproxy.lua:479-496` — `credential_health_for_login` issues one full `/v0/management/auth-files` request per channel (3 curls + 3 key reads for `google`) when a single response already carries every channel.
- `tests/integration/cliproxy_lifecycle_spec.lua` peer test printed `SKIP: ps unavailable — peer detection not exercised` in my run — the M3 peer detection has no live coverage in this environment; the skip is loud, which is right, but the coverage claim in the Log should note it.
- `lua/parley/cliproxy.lua:1060-1061` — two stray blank lines left after `run_login`; `:405-406` likewise after `restart_managed`.
- Carried unfixed from M1/M2: `render_opts()` does `mkdir` + a file read on every call and sits on every query; `resolve_channel` iterates `pairs()` (nondeterministic when a model appears under two channels); `classify_auth_files` treats a record with no `status` as healthy (`cliproxy_auth.lua:131`).

## 5. Test coverage notes

Verified independently, not from the Log: `cliproxy_auth` 55, `cliproxy_config` 46, `cliproxy_budget` 2, `dispatcher_query` 56, `failure_notice` 6, `providers_pre_query` 6, `cliproxy_lifecycle` 49, `cliproxy_command` 10, `cliproxy_auth_login` 19, `cliproxy_recovery_e2e` 4, `cliproxy_login` 8, `cliproxy_conformance` 3, `cliproxy_dispatch` 3, `cliproxy_caller_teardown` 5, `cliproxy_download` 3 — **275 examples, 0 failed, 0 errors**; `make lint` 0/0 in 313 files. Every number in the Log matches. One loud SKIP (peer detection).

Gaps, in the order I'd close them:

1. **The restart rung has no honest test** (C1). Its only coverage fabricates `modtime` through the fake's overlay — a value the fake's own record-builder computes live and would never emit. Any test that must override a field the fake derives from real state is testing a state the system cannot reach; that's the tell.
2. **`loaded_credential_mtime` has zero direct coverage** — the function whose premise is wrong. A single unit test asserting it returns something *different* from `health.modtime` would have failed on day one.
3. **`_stray_spawned`'s test passes with the code deleted** (I2). Run the deletability check on new mechanisms before writing the Log entry that claims them.
4. **`run_login`'s outcome contract is untested** — no test asserts `on_done` fires exactly once (I4), and none asserts the channel it reports on (I3). The `dies_early` spec stops waiting 160s before the second settle.
5. **`warn_about_peers`' oldest-selection fixture is degenerate** (I8) — three peers whose lexicographic and chronological orders coincide.

`cliproxy_auth_spec`'s external-oracle epoch assertions are the pattern to copy: they falsify the implementation rather than restate it. The staleness rows still don't, because the quantity they compare is self-referential regardless of representation.

## 6. Architectural notes for upcoming work

- **ARCH-DRY — flag.** Three in the diff: `_stray_spawned` duplicates `_spawned`'s key set exactly (I2); `run_login` re-derives a channel by hand where `credential_health_for_login` exists for that purpose (I3); `:ParleyProxy reap` bypasses `SUBS_HELP`, the single source the atlas names for help + completion (I1). Consolidated correctly this window: `restart_managed`, `credential_action`, `channels_for_login`, `healthier` — all single-source with two real callers each.
- **ARCH-PURE — pass, with the same structural caveat as round 2, now realized.** `decide`, `credential_action`, `rfc3339_sec`, `parse_peers` are genuinely pure and mock-free. But the pure function's precondition is again unenforced by the shell: `auth_file_is_stale` assumes its two inputs are *different measurements*, and the boundary hands it the same one twice (C1). Purity doesn't protect a contract the seam doesn't keep — and here the fix makes it *more* pure, since `modtime` vs `updated_at` needs no `fs_stat` at all. That is the shape to reach for: when a pure predicate needs an IO-gathered second operand, first check whether the record already carries it.
- **ARCH-PURPOSE — flag.** Shadow sweep on "who infers auth state": dispatch derives from the management API ✓; `:ParleyProxy models` derives, on the right axis ✓; all three hand-maintained restatements of the disproved empty-list inference are corrected ✓. But the issue's Done-when enumerates three recoverable failures — proxy down, **stale in-memory auth**, transient — and the middle one is not delivered (C1); its atlas row and plan row assert a repair that cannot fire. Second: prevention was the *point* of M3, and the only operator-facing lever, `:ParleyProxy reap`, ships undiscoverable (I1). Both are the deferred-purpose pattern, not separable follow-ups.
- **ARCH-MOCK — flag.** The `--error-mode`/`_once` work is genuinely good: captured 7.1.71 bodies over the boundary production uses. The failure is on the field the ladder branches on. The fake models `modtime` *faithfully* (`os.path.getmtime(path)` per request, matching the binary I probed) — and the test reached past it with a `state.json` override to manufacture a value the real dependency cannot produce. That is the ARCH-MOCK anti-pattern in its subtlest form: a faithful fake, defeated by a fixture. Two conformance assertions would have caught it: that `modtime` equals the on-disk mtime, and that `updated_at` does not advance when only mtime does.
- **Plan-gate carry-forward:** `workshop/plans/000197-cliproxy-auth-self-healing-plan-gate.md` `## Open findings` reads "(none — every finding has been disposed)" — verified on disk. PQ-5 was the item deferred into M2; it is delivered and on the right axis. Nothing to carry.
- **Prior-review carry-forward:** M2 round 2's plan-revision recommendations #1–#4 have **no** Revisions entry (the plan's only M2 block, `:553`, corresponds to round 1). Round 1's recommendation #1 — the `expired` row — has now survived two reviews.
- **Core concepts cross-check:** every existing row verifies against the filesystem — `classify_response`/`classify_auth_files`/`diagnosis`/`decide`/`parse_peers` in `cliproxy_auth.lua` ✓, `resolve_channel` + `render` in `cliproxy_config.lua` ✓, `detect_auth_failure` and `check_auth_failure` absent from `lua/` ✓ (only historical comments remain), `_failure_notice` in `chat_respond.lua` ✓. All PURE rows run without IO. The table is *incomplete*, not wrong: `credential_action`, `rfc3339_sec`, `healthier`, `channels_for_login` (M2) and `restart_managed`, `credential_health_for_login`, `peers`, `reap`, `callback_port_blocked`, `await_credential`, `run_login` (M3) have no rows.
- **For the close:** `stop()` now has four callers and `peers()` two; before a fifth appears, the port-release discipline and the `ps`/`lsof` cost both want to be behind one seam.

## 7. Plan revision recommendations

Append to `workshop/plans/000197-cliproxy-auth-self-healing-plan.md` `## Revisions`:

1. **Record what `modtime` actually is, and which field carries load time.** Task 9 Step 3 and the `decide` table both describe "auth file newer than the proxy's copy" as if the record's `modtime` were the loaded copy's timestamp. Verified against the binary: `modtime` is the file's mtime re-stat'd per request, and `updated_at` is when the proxy loaded the credential (probe evidence in C1). Record the corrected staleness definition, that it is computed entirely from the record (no `fs_stat`, so it leaves the repair budget), and that `updated_at` joins `REQUIRED_FIELDS` in the conformance spec.
2. **The `decide` table's `expired` row still contradicts the code** (`:421`: `| expired | true | any | any | prompt_login |`). The shipped policy retries on `healthy` — deliberately — and reports on `unknown`. Recommended in M2 round 1 and again in round 2; correct the row or record why it stands.
3. **Add Core-concepts rows for the entities M2 and M3 introduced** — `credential_action`, `rfc3339_sec`, `healthier`, `channels_for_login`, `restart_managed`, `credential_health_for_login`, `peers`, `reap`, `callback_port_blocked`, `await_credential`, `run_login` — with kind/location/status/milestone, so the next reviewer's table-vs-filesystem cross-check sees the real surface. (Round 2's recommendation #2, undone.)
4. **State the anti-fabrication rule for fake-backed tests.** The restart rung's test overrode a field the fake derives from real state. Record that a test may not override a `state.json` field the fake computes live — if a state can't be produced, that is the finding, not the fixture.
5. **Correct the compound-budget claim.** Task 5 / the atlas say the 404-repair→`restart` composition is "made unreachable"; the guard is reset by the repair's own second read before the decision is taken (I7). Record either the per-claim latch or the compound worst case as a budgeted term.
6. **Name `reap` as user-facing surface.** Task 14 Step 3 stops at the command's behavior; add `SUBS_HELP` registration (the completion + help single source) and the README subcommand list to the task, so the Docs update gate has something to check against.

---

## Re-review — 2026-08-01T12:44:31-07:00 (REWORK)

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
| timestamp | 2026-08-01T12:44:31-07:00 |
| verdict | REWORK |

## Review

```verdict
verdict: REWORK
confidence: high
```

The milestone's core is finally right, and I verified that independently rather than taking the Log's word: `rfc3339_sec` matches an external oracle on every boundary I threw at it (leap years, epoch, the 100/400-year rules through 2400), and — the thing three rounds got wrong — I probed the **real binary** (7.2.110, throwaway auth-dir, fabricated credential) and confirmed the staleness operands are genuinely different quantities: a touch-only write advances `modtime` and leaves `updated_at` alone, a content rewrite advances both. The restart rung is real for the first time, and its test now reproduces the condition the way the system produces it instead of fabricating a field. Suite: 276 examples across 15 specs, 0 failed, 0 errors (conformance really booted the binary); `make lint` 0/0 in 313 files. What blocks SHIP is a defect **introduced by this window's fix for the previous round's hot-path finding**: the once-per-session peer guard only latches when peers *exist*, so on a clean machine — the state `:ParleyProxy reap` drives toward — `ensure_running` shells out to `ps ax` + `lsof` on **every single query**; I measured 145–151 ms of blocking event-loop work, and nothing tests the wiring. Alongside it, three findings from round 3 are still open and I reproduced all three: the compound repair→restart path runs two full repairs past the backstop while the code and atlas assert it is "made unreachable"; `run_login` still emits a contradictory operator notification three minutes after it already settled; and `reap()` reports killing processes it did not kill.

## 1. Strengths

- **The staleness rung is correct for the first time, and provably so.** `auth_file_is_stale` (`lua/parley/cliproxy_auth.lua:364-368`) now compares `modtime` against `updated_at` *within one record*, which my live probe confirms are distinct quantities. It also became **more** pure — no `fs_stat`, so an IO term left the repair budget entirely. That is the right shape: when a pure predicate needs an IO-gathered second operand, check first whether the record already carries it.
- **The test that pins it does not fabricate.** `tests/integration/cliproxy_auth_login_spec.lua:367-393` seeds the proxy's load time with a real read, then `fs_utime`s the file — a genuine missed-fsnotify signature — and asserts `stop()` was called exactly once. Its sibling at `:346-365` asserts `stop()` was **not** called on the healthy path. Those two assertions are what make `retry` and `restart` distinguishable at all, and they were round 1's #1 recommendation.
- **`rfc3339_sec` is verified against an oracle, not itself.** `tests/unit/cliproxy_auth_spec.lua:333-342` asserts absolute epochs including `2024-02-29` and `2028-06-15`; I independently confirmed every value against Python's `datetime`, plus `2400-02-29` (13574563200) which the suite doesn't cover.
- **Conformance now pins the field the ladder branches on.** `updated_at` joined `REQUIRED_FIELDS` (`tests/integration/cliproxy_conformance_spec.lua:24-32`) against the real binary — the ARCH-MOCK gap round 3 named.
- **One policy, real consumers.** `credential_action` (`cliproxy_auth.lua:379`) is called from `decide` (`:432`) and `init.lua:420`; `channels_for_login` (`cliproxy_config.lua:195`) inverts `CHANNEL_LOGIN` rather than adding a table; `restart_managed` (`cliproxy.lua:393`) gives both repair callers the port-release wait. The `:ParleyProxy models google` spec asserts the exact channel set `{aistudio, gemini, gemini-cli}` (`cliproxy_command_spec.lua:117-136`), so the axis bug cannot silently return.

## 2. Critical findings

**C1 — the once-per-session peer guard never latches when there are no peers, so `ps ax` + `lsof` (~150 ms, blocking) runs on every query in the default configuration.** `lua/parley/cliproxy.lua:586-590` + `:824-827`

`warn_about_peers` sets `_peer_warning_shown = true` only *after* the `#peers == 0` early return:

```lua
if _peer_warning_shown or #peers == 0 then return end
_peer_warning_shown = true
```

so on a machine with zero peers the flag stays false forever, and `ensure_running`'s guard — `if not M.peer_warning_shown() then ... M.warn_about_peers(M.peers()) end` — re-evaluates `M.peers()` on every dispatch. Reproduced:

```
before: false
after warn_about_peers({}): false  -> ensure_running re-runs peers() on the NEXT dispatch, and every one after
after warn with 1 peer: true
```

and measured on this machine:

```
run 1: ps ax = 63.0 ms, lsof = 88.4 ms, total = 151.4 ms
run 2: ps ax = 62.8 ms, lsof = 82.3 ms, total = 145.2 ms
run 3: ps ax = 69.5 ms, lsof = 80.4 ms, total = 149.9 ms
```

Both are `vim.system(...):wait()` — synchronous on the main loop — and `pre_query` runs per query (`dispatcher.lua:550-556`), with `cliproxy.manage` on by default. `M.peers()` also calls `render_opts()` → `management_key()`, adding a `mkdir` + file read each time. The failure scenario is the *healthy* machine: an operator reaps their leaked proxies as this milestone instructs, and is rewarded with a ~150 ms UI stall at the start of every chat request, permanently. The code's own comment (`:582-585`) asserts the mitigation works, and `workshop/lessons.md`'s new rule ("on a hot path, check the flag before doing the work it gates") is the intent — the guard moved to the right place but never arms.

Fix sketch — latch on the scan, not on the warning:

```lua
-- ensure_running
if not M.peer_warning_shown() then
    pcall(function()
        local peers = M.peers()
        M._mark_peer_scan_done()   -- always, regardless of count
        M.warn_about_peers(peers)
    end)
end
```
or simply set `_peer_warning_shown = true` unconditionally at the top of `warn_about_peers` (the `#peers == 0` case has nothing to say on a later dispatch either). The test this needs is the deletability check in reverse: drive `ensure_running` twice against the fake with **no** peers and assert `M.peers` was invoked once. No test currently references `ensure_running` and the peer warning together — the whole wiring is uncovered (`grep` shows only direct `warn_about_peers`/`peers()` calls in `cliproxy_lifecycle_spec.lua:875-914`).

## 3. Important findings

**I1 — `run_login`'s abandoned watcher still notifies the operator three minutes after the login already settled.** `lua/parley/cliproxy.lua:1053-1066`

The `settled` latch (`:988-996`) guards `on_done` but **not** the `vim.notify` that precedes it, and the exit path never cancels `await_credential`. Reproduced with the fake's `dies_early` mode against a patched copy (watch shortened to 2.5 s so the 180 s deadline is observable):

```
SETTLE #1 ok=false at +88ms
+   84ms  lvl=2  cliproxy: complete the login in your browser. | …
+   88ms  lvl=4  cliproxy: claude login exited 3 | fake login: exiting non-zero before any callback
+ 2504ms  lvl=3  cliproxy: claude login did not complete — no credential was written. Re-run `:ParleyProxy login claude`.
settle count: 1
```

Failure scenario at the real 180 s: the login dies, the operator is correctly told so, re-runs it successfully — and three minutes later the stale watcher tells them their login "did not complete" (or, if the new credential lands first, fires a duplicate "succeeded"). That is round 3's I4; the settle count was fixed, the operator-visible half was not. `cliproxy_login_spec.lua:79-88` cannot see it because it stops waiting at 20 s. Fix: check the latch before notifying (hoist `settled` into both branches) and `jobstop` + cancel the watch on the non-zero exit path.

**I2 — the compound "404 repair then restart" path is not unreachable; it runs two full repairs (~36 s) past the 30 s backstop, and the guard that claims to prevent it always reads false.** `lua/parley/cliproxy.lua:417-419`, `:452-456`, `:1172-1181`

`credential_health` resets `_management_restart_done = false` at `:454` **before** invoking `cb(second)` at `:456`, and `cb` is what computes the decision — so `execute`'s guard at `:1173` can never be true on the path it exists to block. (The only state where the flag *is* true is a second consecutive 404, which yields `state = "unknown"` → `report`, never `restart`.) Reproduced by stubbing only the IO boundary (`health_probe`, `auth_files`, `restart_managed`) on a patched copy:

```
PROBE: restart rung reached; _management_restart_done=false
settled     = retry
auth_files reads = 2
restart_managed calls = 2   (1 = repair only; 2 = COMPOUND, the case claimed unreachable)
```

Terms: liveness 2 + auth_files 2 + [repair 2+4+2+7] + read 2 + [restart 2+4+2+7] ≈ **36 s** against `recovery_timeout_ms = 30000`, so the backstop fires, spends the claim's one-shot, and replaces a correct diagnosis with "recovery timed out" — the exact outcome the budget exists to prevent. `cliproxy_budget_spec` cannot see it: `M._repair_budget_sec` models the single-repair path (21 s) only. Trigger is narrow (proxy booted without the management key, then a credential written during the ~11 s restart window), but the invariant asserted in the code comment *and* in `atlas/providers/cliproxy-managed.md:172-173` is simply false. Fix: latch a per-claim boolean inside `recover` rather than reading module state the repair itself resets, and add the compound case to the budget spec.

**I3 — `reap()` counts processes it did not kill, and does not perform the identity probe its docstring and plan step promise.** `lua/parley/cliproxy.lua:846-863`

`local ok = pcall(uv.kill, peer.pid, "sigterm")` — luv returns `nil, err` rather than raising, so `ok` is true on both ESRCH and EPERM. Verified:

```
pcall ok= true  ret= nil ESRCH: no such process
pid1 pcall ok= true  ret= nil EPERM: operation not permitted
```

Failure scenario: a peer owned by another user, or one that exited between the scan and the kill → `:ParleyProxy reap` reports "stopped 5 process(es)" having stopped none, and the operator believes the rotation race is resolved when it isn't. Fix: `local ok, err = uv.kill(...)` inside the pcall and count on `ok == 0`. Separately, the docstring says "after an identity probe per pid" and plan Task 14 Step 3 says "SIGTERMs peers **after an identity probe** (reuse `port_holds_cliproxy`'s discipline)"; the code does `peer.command:match("%-config%s")`, a command-line substring test. `parse_peers`' executable matching bounds the risk, but this is a documented contract not kept on a function that sends SIGTERM — either probe or correct the contract. `reap()` has **zero** test coverage of any kind.

**I4 — `warn_about_peers` picks the "oldest" peer by lexicographic compare of `ps lstart`, which begins with the day of the week.** `lua/parley/cliproxy.lua:830-835`

Verified counterexample:

```
peers: "Fri Aug  1 03:00:00 2026" and "Mon Jun 15 09:00:00 2026"
chosen oldest: pid 1 (Fri Aug  1)   -- truth: pid 2, Jun 15
```

The date is the only thing that makes the count actionable ("oldest since %s"); getting it wrong tells the operator their leak is hours old when it is seven weeks old — the #197 situation exactly. The fixture test passes by luck (`Fri Jun 12` is lexicographically smallest in `ps_cliproxy_peers.txt`, so lexicographic and chronological order coincide) — the degenerate-fixture shape `workshop/lessons.md` warns about, applied to a string-compare-on-timestamps in the *same window* that added a rule forbidding exactly that. Fix (ARCH-PURE): have `parse_peers` carry a parsed start epoch and compare numbers; the fixture must then include a peer whose two orders disagree.

**I5 — the Done-when "a successful [login] is detected **and resumes the query**" is not delivered, and is not recorded as descoped.** `lua/parley/init.lua:490`, `lua/parley/cliproxy.lua:1097-1102`

`:ParleyProxy login` calls `cliproxy.run_login(arg, argv)` with **no** `on_done` (the only production caller; `grep` confirms), and `prompt_login` calls `vim.cmd(prefix .. "Proxy login ...")` then `done()` → `give_up(message)` immediately. So a successful login notifies and stops there; the pending query is never re-issued. Plan Task 15 Step 3 is explicit: "Success → notify with the account, **then retry the pending query**." I understand why holding the claim is impossible — an OAuth flow outstrips the 30 s backstop by two orders of magnitude — but that is an argument for recording the descope, not for leaving the issue's Done-when reading as delivered while M3 is ticked `[x]` (ARCH-PURPOSE).

**I6 — Docs update gate: the atlas asserts three things the code does not do.** `atlas/providers/cliproxy-managed.md:129`, `:144`, `:172-173`

- `:129` — "A 15s `recovery_timeout_ms` backstop" against `dispatcher.lua:30`'s `30000`. Flagged at M2 rounds 1, 2 and 3; the constant has since moved 25000 → 30000, so the doc is now 2× off.
- `:144` — "`recover` gathers the inputs (liveness probe, credential health, **the auth-dir mtime**)"; the auth-dir stat was deleted in this window's own fix, and staleness is now entirely inside the record.
- `:172-173` — "The compound case … is made unreachable rather than budgeted: one restart per claim" — disproved above (I2).

The new "Timeout budget" paragraph is right to refuse to restate arithmetic; `:129` should get the same treatment (name the relationship, not the number).

**I7 — the plan no longer describes what shipped, on four counts.** `workshop/plans/000197-cliproxy-auth-self-healing-plan.md`

- **55 of 56 checkboxes are unticked** (only `:425` is `[x]`) while the issue marks M1, M2 **and** M3 all `[x]`. Tasks 9 Steps 2–5, 10, 11, 12, 13, 14, 15 all read as unstarted.
- `:421` — the `decide` table still reads `| `expired` | true | any | any | `prompt_login` |`; the shipped policy retries on `healthy` (deliberately) and reports on `unknown`. Recommended in M2 rounds 1, 2 **and** 3.
- `:427` — Task 9 Step 3 still specifies `proxy_state = {running, auth_file_modtime, record_modtime}` and "a string compare on RFC3339 timestamps".
- Revisions entry #1 (`:555-562`), added *last* round, is now itself stale: it records normalization "at the IO seam (`uv.fs_stat().mtime.sec`)" and `proxy_state` carrying `auth_file_modtime` — the design this window deleted. The Core-concepts table (`:66-76`) is still missing all eleven entities M2/M3 introduced (`credential_action`, `rfc3339_sec`, `healthier`, `channels_for_login`, `restart_managed`, `credential_health_for_login`, `peers`, `reap`, `callback_port_blocked`, `await_credential`, `run_login`).

**I8 — scope: this M2 window carries three M3 commits, and M3 is ticked `[x]` with no boundary review of its own.** `ba0992d`, `bf98f8d`, `65d4402`, `c3d11ef`

Per AGENTS.md §3 each `Mx` row commits to its own `milestone-close`. M2's boundary was never crossed (three REWORKs), so M3 landed on top of it — which means this review is the only fresh-eyes pass M3 gets, and four of the seven Importants above (C1, I1, I3, I4) are M3 code. Either run `milestone-close --milestone M3` separately after the rework, or state in the `## Log` that M2's review deliberately absorbed M3 and record the verdict against both. Raised at round 3; unaddressed.

## 4. Minor findings

- `cliproxy.lua:1117` — `@param _retry fun() # unused in M1: this milestone diagnoses, it never repairs`; the parameter is `retry` and drives the whole ladder. Flagged rounds 1, 2 and 3.
- `cliproxy_auth.lua:441` — `auth_file_is_stale(health, proxy_state)` passes a second argument the function no longer takes; `:411` still documents `proxy_state` as `{ running, auth_file_modtime }`.
- The `## Log` records conformance as "real 7.1.71"; `discover_binary` resolves `/opt/homebrew/bin/cliproxyapi` = **7.2.110**, while `PINNED_VERSION = "7.1.71"` — download and conformance exercise different versions.
- `:ParleyProxy reap` scans `peers()` twice (`init.lua:453` for the confirmation list, then again inside `reap()`), so the operator approves one list and a re-scan is what gets SIGTERMed.
- The rotation-race explanation is hand-copied in two places (`init.lua:463-465` and `cliproxy.lua:836-839`) — ARCH-DRY on operator-facing prose.
- `channels_for_login("codex-device")` returns `{}`, so `newest_credential_mtime` falls back to matching **any** `*.json` — the peer-refresh filter it exists to provide doesn't apply to that login.
- `run_login`: a login that exits 0 without writing a credential waits the full 180 s before saying anything.
- `newest_credential_mtime` (`cliproxy.lua:886-888`) re-derives the `~/.cli-proxy-api` default that `config.lua:118` documents.
- `credential_health_for_login` issues one full `/v0/management/auth-files` request per channel (3 curls + 3 key reads for `google`) when a single response carries every channel.
- `cliproxy_recovery_e2e_spec.lua:186,195` — `local port = select(2, ("x"):find("x")) -- keep luacheck quiet about unused` plus `assert.is_truthy(port)` is still dead scaffolding (flagged rounds 1, 2, 3). `:118` — `vim.ui.select` set in `before_each`, never restored.
- Carried from M1/M2: `render_opts()` does `mkdir` + a file read on every call; `resolve_channel` iterates `pairs()` (nondeterministic when a model appears under two channels); `classify_auth_files` treats a record with no `status` as healthy (`cliproxy_auth.lua:131`).

## 5. Test coverage notes

Verified independently, not from the Log: `cliproxy_auth_login` 19, `cliproxy_caller_teardown` 5, `cliproxy_command` 10, `cliproxy_conformance` 3 (real binary, no skip), `cliproxy_dispatch` 3, `cliproxy_download` 3, `cliproxy_lifecycle` 49, `cliproxy_login` 8, `cliproxy_recovery_e2e` 4, `cliproxy_auth` 56, `cliproxy_budget` 2, `cliproxy_config` 46, `dispatcher_query` 56, `failure_notice` 6, `providers_pre_query` 6 — **276 examples, 0 failed, 0 errors**. `make lint` 0/0 in 313 files. The Log says `cliproxy_auth_spec` 55 (it is 56 post-`c3d11ef`) and "real 7.1.71" (it is 7.2.110). One loud SKIP: `SKIP: ps unavailable — peer detection not exercised` — in my sandbox `vim.system({"ps",…})` raises EPERM, which is exactly the degradation `peers()` is written to survive, so the skip is honest; it does mean M3's live peer detection went unexercised in this run.

Gaps, in the order I'd close them:

1. **`ensure_running`'s peer wiring has no test at all** (C1). One assertion — drive `ensure_running` twice with zero peers, count `M.peers` invocations — would have failed the day this landed. The existing peer specs call `warn_about_peers`/`peers()` directly, so they are blind to how it's wired.
2. **`reap()` has zero coverage** (I3) — not the `-config` filter, not the kill count, not the `:ParleyProxy reap` command branch. It is the milestone's one operator-facing prevention lever and it sends SIGTERM.
3. **`run_login`'s post-settle behavior is untested** (I1) — the `dies_early` spec stops waiting 160 s before the contradictory notification arrives. A shortened-timeout seam would make it observable.
4. **The oldest-peer fixture is degenerate** (I4) — all six entries order identically lexicographically and chronologically. Add a peer whose two orders disagree.
5. **The compound repair→restart path is untested** (I2), and `cliproxy_budget_spec` asserts a hand-written table rather than the code's actual worst case.
6. **No live conformance that `updated_at` stays put on a touch-only write.** I verified it against 7.2.110 today; nothing in the suite will notice if upstream changes it, and the entire restart rung now rests on that behavior. `assert.is_not_nil(ca.rfc3339_sec(record.modtime))` plus the same for `updated_at` would also pin the format (the fake emits `%z` = `-0700`; the binary emits `.994488305-07:00` — both parse today, so this is drift protection, not a live bug).

## 6. Architectural notes for upcoming work

- **ARCH-DRY — pass with two nits.** The consolidations in this window are real and each has two live callers: `restart_managed`, `credential_action`, `channels_for_login`, `healthier`. Remaining duplication is prose and defaults, not logic: the rotation-race explanation exists twice (`init.lua:463-465` / `cliproxy.lua:836-839`), and `newest_credential_mtime` re-derives the auth-dir default. `_stray_spawned` was correctly deleted rather than kept, which is the right response to round 3's deletability finding.
- **ARCH-PURE — flag, narrowly.** `decide`, `credential_action`, `rfc3339_sec`, `parse_peers`, `channels_for_login`, `healthier` are genuinely pure, mock-free, and now *externally* validated. `auth_file_is_stale` becoming pure — reading two fields of one record instead of stat'ing a file — is the best structural move in this window and the one that finally made the rung correct. The flag is `warn_about_peers` (`cliproxy.lua:830-835`): choosing the oldest peer is business logic, it lives in the IO shell, and it is done with a string compare on a human-formatted timestamp. `parse_peers` is already pure and already parses the `lstart` field; it should carry a start epoch so the comparison is numeric and unit-testable.
- **ARCH-PURPOSE — flag.** Shadow sweep on "who infers auth state": dispatch derives from the management API ✓; `:ParleyProxy models` derives on the correct channel axis ✓; all three hand-maintained restatements of the disproved empty-list inference are corrected ✓; and the third Done-when — "stale in-memory auth … repaired" — is *finally* delivered and verified against the real dependency ✓. What remains under-delivered is the login half: "a successful one is detected **and resumes the query**" (I5) is not wired, and the prevention lever `reap` mis-reports what it did and is untested (I3). Both are the point of M3, not separable follow-ups.
- **ARCH-MOCK — pass with a gap.** The fake modelling `updated_at` as "first time we saw this content" (`tests/fixtures/fake_cliproxy:104-110`) is exactly right — it makes the fake honest about the distinction the rung reads, rather than letting a fixture manufacture it, which is what defeated round 3. `--error-mode`/`_once` and the four login modes run production's own HTTP and process boundaries. The gap is conformance depth: the spec pins that `modtime` and `updated_at` *exist*, not that they parse, and — more importantly — not that `updated_at` holds still on a touch-only write. That behavior is now load-bearing; I confirmed it manually against 7.2.110, and the suite should confirm it on schedule so drift surfaces here rather than as a silently dead rung a fourth time.
- **Plan-gate carry-forward:** `workshop/plans/000197-cliproxy-auth-self-healing-plan-gate.md` `## Open findings` reads "(none — every finding has been disposed)" (verified on disk, line 233). PQ-5 was the item deferred into M2; it is delivered and on the right axis. Nothing to carry.
- **Core concepts cross-check:** every existing row verifies against the filesystem — `classify_response`/`classify_auth_files`/`diagnosis`/`decide`/`parse_peers` in `cliproxy_auth.lua` ✓, `resolve_channel` + `render` in `cliproxy_config.lua` ✓, `detect_auth_failure` absent from `lua/` ✓, `_failure_notice` in `chat_respond.lua` ✓. All PURE rows run without IO (`cliproxy_auth_spec` uses no mocks). The table is *incomplete*, not wrong — eleven M2/M3 entities have no row (I7).
- **Prior-review carry-forward:** M2 round 2's four plan-revision recommendations and round 3's six have no Revisions entry; the `expired`-row correction has now survived three reviews. Of round 3's ten findings, C1 and I1/I2/I5 are closed; **I6, I7, I8, I9 and I10 remain open** and are re-filed above at their original severity.
- **For the close:** `stop()` now has four callers and `peers()` two; before a fifth appears, both the port-release discipline and the `ps`/`lsof` cost want to sit behind one seam with one latch.

## 7. Plan revision recommendations

Append to `workshop/plans/000197-cliproxy-auth-self-healing-plan.md` `## Revisions`:

1. **Correct the staleness definition — again, and this time to what shipped.** Task 9 Step 3 (`:427`) still names `{running, auth_file_modtime, record_modtime}` and "a string compare on RFC3339 timestamps", and Revisions entry #1 (`:555-562`) names `uv.fs_stat().mtime.sec` at the IO seam. Both describe deleted designs. Record the shipped one: staleness is computed **entirely inside the management record** (`modtime` = the file's mtime, re-stat'd per request; `updated_at` = when the proxy loaded it), verified against 7.2.110 — a touch-only write advances `modtime` alone, a content rewrite advances both — with no `fs_stat`, so the check is pure and leaves the repair budget.
2. **The `decide` table's `expired` row still contradicts the code** (`:421`). The shipped policy retries on `healthy` (deliberately) and reports on `unknown`. Recommended at rounds 1, 2 and 3; correct the row or record why it stands.
3. **Add Core-concepts rows for the eleven M2/M3 entities** — `credential_action`, `rfc3339_sec`, `healthier`, `channels_for_login`, `restart_managed`, `credential_health_for_login`, `peers`, `reap`, `callback_port_blocked`, `await_credential`, `run_login` — with kind/location/status/milestone (round 2 rec #2, round 3 rec #3, still undone).
4. **Correct the compound-budget claim.** Task 5 / the atlas say the 404-repair→`restart` composition is "made unreachable"; the guard is reset by the repair's own second read before the decision is taken (I2, reproduced). Record either the per-claim latch or the compound worst case as a budgeted term asserted by `cliproxy_budget_spec`.
5. **Record whether "resumes the query" is in scope.** Task 15 Step 3 says "then retry the pending query" and the issue's Done-when says the same. Either wire `run_login`'s `on_done` back to a re-issue, or record the descope with the reason (an OAuth flow outlives the claim's 30 s backstop by two orders of magnitude) so the Done-when stops reading as delivered.
6. **Tick what shipped.** 55 of 56 checkboxes are unticked while M1/M2/M3 are all `[x]` in the issue. The plan is the greppable record of what was built; leaving it at 1/56 makes the next reviewer's traceability pass meaningless.

---

## Re-review — 2026-08-01T12:55:37-07:00 (REWORK)

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
| timestamp | 2026-08-01T12:55:37-07:00 |
| verdict | REWORK |

## Review

```verdict
verdict: REWORK
confidence: high
```

The milestone's core is now genuinely right, and I verified it rather than taking the Log's word: the staleness rung compares two real, distinct quantities (`modtime` vs `updated_at` inside one management record) and both are pinned against the live binary by `cliproxy_conformance_spec.lua:24-32`; the peer guard from round 4 now latches on the **scan** and has a wiring test that drives `ensure_running` three times and asserts one scan; `reap()` counts only kills the OS accepted; the compound repair→restart is blocked by a per-claim latch instead of module state the repair itself resets. Suite: **281 examples across 15 specs, 0 failed, 0 errors** (conformance really booted a real binary), `make lint` **0/0 in 313 files**. What blocks SHIP is a regression this window introduced in M3's login rework: `run_login` pipes the binary's stdout/stderr into callbacks that discard every line except one claude-shaped URL pattern, **while unconditionally passing `-no-browser`** — so for the providers whose authorize URL doesn't match that pattern the operator now gets no browser, no URL, no device code, and nothing at all until a 180 s "did not complete". I extracted the real 7.2.110 binary's OAuth strings and confirmed only claude and codex match; google, kimi, xai and antigravity do not. That is strictly worse than the terminal split it replaced, and the fake emits exactly one URL shape so no test can see it. Alongside it, five findings from round 4 are still open and I reproduced each: the "oldest peer" date is chosen by lexicographic compare of a string that starts with the day of the week; the Done-when "a successful [login] … resumes the query" is neither wired nor descoped; the atlas still says 15 s where the code says 30000; the plan is at 1/56 checkboxes with a `decide` row that has now contradicted the code across four reviews; and M3 rides in this M2 window with no boundary review of its own.

## 1. Strengths

- **The staleness rung is correct and honestly tested.** `auth_file_is_stale` (`lua/parley/cliproxy_auth.lua:364-368`) reads two different fields of one record and needs no `fs_stat` — the check got *more* pure while getting correct. `tests/integration/cliproxy_auth_login_spec.lua:367-393` reproduces staleness the way the system produces it (seed the load time with a real read, then `fs_utime` the file) and asserts `stop()` fired exactly once; its sibling at `:346-365` asserts `stop()` did **not** fire on the healthy path. Those two assertions are what finally make `retry` and `restart` distinguishable.
- **Round 4's C1 is properly closed, latch and wiring both.** `warn_about_peers` (`cliproxy.lua:824-831`) sets `_peer_warning_shown` before the `#peers == 0` return, and `cliproxy_lifecycle_spec.lua` drives `ensure_running` three times asserting one `peers()` call. That is the deletability check in the right direction — the test fails if the guard stops arming.
- **`reap()` counts real kills** (`cliproxy.lua:865-870`): `local called, rc = pcall(uv.kill, …)` + `rc == 0`, with a spec that reaps a nonexistent pid and asserts `killed == 0, skipped == 1`. luv's `nil, err` convention is now handled rather than swallowed.
- **`run_login`'s settle latch wraps the notify, not just the callback** (`cliproxy.lua:997-1007`), and `cliproxy_login_spec.lua:90-111` asserts nothing further is said after settling. The contradictory "did not complete" three minutes later is gone.
- **The budget is derived and the "unreachable" claim is checkable.** `M._repair_budget_sec` (`cliproxy.lua:341-350`) is computed from `CURL_MAX_TIME`/`PORT_RELEASE_MS`/`POLL_BUDGET_MS` including the one-probe overrun each bounded poll can incur, and `cliproxy_budget_spec` asserts both the single-repair inequality and the compound arithmetic, so a regressed latch shows up as a failing test rather than a 36 s timeout in production.

## 2. Critical findings

**C1 — `run_login` swallows the login binary's entire output except one claude-shaped URL, while suppressing the binary's own browser open; for google/kimi/xai/antigravity the operator sees nothing and the login cannot be completed.** `lua/parley/cliproxy.lua:1019`, `:1023-1037`, `:1040-1057`

`local cmd = vim.list_extend(vim.deepcopy(argv), { "-no-browser" })` is applied to **every** provider, and `jobstart` pipes stdout/stderr into `on_stdout`/`on_stderr`, which call `handle_line` and then drop the line (stderr is kept only in `stderr_tail`, shown only on a non-zero exit). `handle_line` surfaces a line only when it matches `"(https://[%w%.%-]+/oauth/authorize%S*)"`.

I extracted the OAuth endpoints from the installed binary (`strings /opt/homebrew/bin/cliproxyapi`, 7.2.110) and tested the pattern against them:

```
MATCH  https://claude.ai/oauth/authorize?...
MATCH  https://auth.openai.com/oauth/authorize?...
MISS   https://accounts.google.com/o/oauth2/auth?...
MISS   https://accounts.google.com/o/oauth2/v2/auth?...
MISS   https://oauth2.googleapis.com/device/code          (kimi/xai device flows)
MISS   Starting Codex device authentication... <user code>
```

Failure scenario: `:ParleyProxy login xai` (or `kimi`, `antigravity`, `codex-device`) → parley passes `-no-browser` so the binary does not open anything → the device code / verification URL is printed to stdout → parley's pattern misses it → the line is discarded → the operator stares at an idle editor for three minutes and is then told the login "did not complete". Before this window the same command opened a terminal split showing all of it (`init.lua`, pre-`bf98f8d`), so this is a regression on documented user-facing surface, in the milestone whose stated purpose is login robustness.

The fake cannot catch it: `tests/fixtures/fake_cliproxy:162` emits exactly one URL, claude-shaped, so `cliproxy_login_spec.lua:64-72` passes for the one provider that works (ARCH-MOCK — the fake models one provider's login output while production runs seven).

Fix sketch — stop discarding output, and stop suppressing the browser where parley can't substitute for it:
```lua
-- only take the URL out of parley's hands where parley can actually open it
local can_capture = URL_PATTERNS[provider] ~= nil
local cmd = vim.deepcopy(argv)
if can_capture then table.insert(cmd, "-no-browser") end
...
local function handle_line(line)
    local url = can_capture and line:match(URL_PATTERNS[provider])
    if url and not url_seen then ... end
    tail[#tail + 1] = line          -- keep everything
end
-- and surface `tail` once no URL has been seen after a short grace period,
-- so a device-code flow's user code reaches the operator
```
Tests: give the fake a `PARLEY_FAKE_LOGIN_MODE=device_code` mode that prints a `https://…/device` + user code and no `/oauth/authorize` URL, and assert the operator is shown that text. A conformance-style assertion that each supported provider's first stdout line is surfaced would close the drift permanently.

## 3. Important findings

**I1 — `warn_about_peers` picks the "oldest" peer with a lexicographic compare of `ps lstart`, which begins with the day of the week.** `lua/parley/cliproxy.lua:837-841`

Reproduced:
```
peers: Sat Aug  1 03:00:00 2026 | Sun Jun 14 09:50:39 2026 | Mon Jun 15 09:00:00 2026
chosen oldest: pid 3 (Mon Jun 15)     truth: pid 2 (Sun Jun 14)
```
The date is the only actionable content in the warning ("oldest since %s") — telling an operator their leak is a day old when it is seven weeks old is the #197 situation exactly. The fixture (`tests/fixtures/ps_cliproxy_peers.txt`) passes by luck: `Fri Jun 12` is lexicographically smallest, so the two orders coincide. This is a string-compare-on-timestamps in the same window that added two `workshop/lessons.md` rules forbidding exactly that, tested with the degenerate-fixture shape a third rule warns about. Raised at round 4 (I4), unfixed. Fix (ARCH-PURE): have `parse_peers` — already pure and already parsing `lstart` — carry a numeric start epoch, compare numbers, and add a fixture peer whose two orders disagree.

**I2 — the Done-when "a successful [login] is detected **and resumes the query**" is not delivered and not recorded as descoped.** `lua/parley/init.lua:490`, `lua/parley/cliproxy.lua:1174-1178`

`cliproxy.run_login(arg, argv)` is the only production caller and passes no `on_done`; `prompt_login` runs `:ParleyProxy login …` then calls `done()` → `give_up(message)` immediately. Plan Task 15 Step 3 says "Success → notify with the account, **then retry the pending query**." I accept that holding the claim across an OAuth flow is impossible (180 s watch vs a 30 s backstop) — but that is a reason to record the descope, not to leave the issue's Done-when reading as delivered with M3 ticked `[x]` (ARCH-PURPOSE). Raised at round 4 (I5), unfixed.

**I3 — Docs update gate: the atlas asserts two things the code does not do.** `atlas/providers/cliproxy-managed.md:129-130`, `:143-144`

- `:129-130` — "A 15s `recovery_timeout_ms` backstop" against `dispatcher.lua:30`'s `30000`. Flagged at M2 rounds 1, 2, 3 **and** 4; the constant has since moved 25000 → 30000, so the doc is now 2× off.
- `:143-144` — "`recover` gathers the inputs (liveness probe, credential health, **the auth-dir mtime**)"; the auth-dir stat was deleted by this window's own round-3 fix. Staleness is now entirely inside the record.

The new "Timeout budget" paragraph is right to refuse to restate arithmetic; `:129` should get the same treatment — name the relationship, not the number.

**I4 — the plan no longer describes what shipped, on five counts.** `workshop/plans/000197-cliproxy-auth-self-healing-plan.md`

- **1 of 56 checkboxes is ticked** (only `:425`) while the issue marks M1, M2 and M3 all `[x]`. Tasks 9 Steps 2–5, 10–15 read as unstarted.
- `:421` — the `decide` table still reads `| expired | true | any | any | prompt_login |`; the shipped policy retries on `healthy` (deliberately) and reports on `unknown`. Recommended at rounds 1, 2, 3 and 4.
- `:427` — Task 9 Step 3 still specifies `proxy_state = {running, auth_file_modtime, record_modtime}` and "a string compare on RFC3339 timestamps".
- Revisions entry #1 (added *last* round) is itself stale: it records normalization "at the IO seam (`uv.fs_stat().mtime.sec`)" and `proxy_state` carrying `auth_file_modtime` — the design round 3 deleted.
- Core concepts (`:66-76`) is still missing all eleven M2/M3 entities. Every row that *is* there verifies against the filesystem (I checked each: `classify_response`, `classify_auth_files`, `diagnosis`, `decide`, `parse_peers`, `resolve_channel`, `render`, `_failure_notice` present; `detect_auth_failure` absent from `lua/`), and all PURE rows run without IO — the table is incomplete, not wrong.

**I5 — `:ParleyProxy login google` cannot work against the installed binary: `-login` is not a flag on 7.2.110.** `lua/parley/cliproxy.lua:744`

```
$ cliproxyapi -login -config /nonexistent.yaml
flag provided but not defined: -login
```
`LOGIN_FLAGS.google = "-login"` predates this window (#131), so it is not a regression — but M3 is the login-robustness milestone, `providers`/`login` completion advertises `google`, and nothing in the suite exercises the argv against the real binary. Worth noting that M3 *improves* the symptom (the operator now sees "google login exited 2" instead of a silently dead terminal). Fix: verify each `LOGIN_FLAGS` entry against `--help` in the conformance spec — that is one assertion and it pins the whole table.

**I6 — scope: this M2 window carries four M3 commits, and M3 is ticked `[x]` with no boundary review of its own.** `ba0992d`, `bf98f8d`, `65d4402`, `2f98176`

Per AGENTS.md §3 each `Mx` row commits to its own `milestone-close`. M2's boundary was never crossed (four REWORKs), so M3 landed on top — meaning this review is the only fresh-eyes pass M3 gets, and C1 plus I1 are both M3 code. Either run `milestone-close --milestone M3` separately after the rework, or state in the `## Log` that M2's review deliberately absorbed M3 and record the verdict against both. Raised at round 4 (I8), unaddressed.

## 4. Minor findings

- `cliproxy.lua:860-862` — the comment inside `reap()`'s loop still claims "a process we cannot identify as a proxy we started is left alone"; the docstring was corrected but no such filter exists in the loop. On a function that sends SIGTERM, delete the stale comment.
- `cliproxy.lua:1133` — `@param _retry fun() # unused in M1: this milestone diagnoses, it never repairs`; the parameter is `retry` and drives the whole ladder. Flagged rounds 1, 2, 3 and 4.
- `cliproxy_auth.lua:441` passes a second argument `auth_file_is_stale` no longer takes, and `:411` still documents `proxy_state` as `{ running, auth_file_modtime }`.
- `init.lua:453` + `cliproxy.lua:858` — `:ParleyProxy reap` scans `peers()` twice; the operator approves list A and list B is SIGTERMed.
- The rotation-race explanation is hand-copied in two places (`init.lua:463-465`, `cliproxy.lua:836-839`) — ARCH-DRY on operator-facing prose.
- `channels_for_login("codex-device")` returns `{}`, so `newest_credential_mtime` falls back to matching **any** `*.json` — the peer-refresh filter it exists to provide doesn't apply to that login.
- `run_login`: a login that exits 0 without writing a credential waits the full 180 s before saying anything (`on_exit` only settles on non-zero).
- `newest_credential_mtime` (`cliproxy.lua:886-888`) re-derives the `~/.cli-proxy-api` default that `config.lua` documents.
- `credential_health_for_login` issues one full `/v0/management/auth-files` request per channel (3 curls + 3 key reads for `google`) when a single response carries every channel.
- `cliproxy_recovery_e2e_spec.lua:186,195` — `local port = select(2, ("x"):find("x")) -- keep luacheck quiet about unused` plus `assert.is_truthy(port)` is still dead scaffolding (flagged four rounds); `:118` — `vim.ui.select` set in `before_each`, never restored.
- Carried from M1/M2: `render_opts()` does `mkdir` + a file read on every call and sits on every query; `resolve_channel` iterates `pairs()` (nondeterministic when a model appears under two channels); `classify_auth_files` treats a record with no `status` as healthy (`cliproxy_auth.lua:131`).

## 5. Test coverage notes

Verified independently, not from the Log: `cliproxy_auth_login` 19, `cliproxy_caller_teardown` 5, `cliproxy_command` 10, `cliproxy_conformance` 3, `cliproxy_dispatch` 3, `cliproxy_download` 3, `cliproxy_lifecycle` 52, `cliproxy_login` 9, `cliproxy_recovery_e2e` 4, `cliproxy_auth` 56, `cliproxy_budget` 3, `cliproxy_config` 46, `dispatcher_query` 56, `failure_notice` 6, `providers_pre_query` 6 — **281 examples, 0 failed, 0 errors**; `make lint` 0/0 in 313 files. One loud SKIP (`ps unavailable — peer detection not exercised`), which is the degradation `peers()` is written to survive, so the skip is honest.

The `## Log` predates the round-4 commit and is now wrong in five places: it lists `cliproxy_auth_spec` 55 (56), `cliproxy_lifecycle_spec` 49 (52), `cliproxy_budget_spec` 2 (3), `cliproxy_login_spec` 8 (9), omits `cliproxy_download_spec` 3, and labels conformance "real 7.1.71" — `discover_binary` resolves `/opt/homebrew/bin/cliproxyapi` = **7.2.110**, while `PINNED_VERSION = "7.1.71"` means download and conformance exercise different versions.

Gaps, in the order I'd close them:

1. **`run_login` is tested against one provider's output shape** (C1). Every assertion rides on a claude-shaped `/oauth/authorize` URL the fake hardcodes. A device-code mode in the fake, plus an assertion that unmatched output still reaches the operator, is the test that would have failed the day `-no-browser` went unconditional.
2. **`LOGIN_FLAGS` is never checked against the binary** (I5). One conformance assertion per entry against `--help` pins the whole table.
3. **The oldest-peer fixture is degenerate** (I1) — all entries order identically lexicographically and chronologically. Add one whose two orders disagree.
4. **No live conformance that `updated_at` stays put on a touch-only write.** The whole restart rung rests on that behavior; `REQUIRED_FIELDS` pins the fields' *existence*, not that the gap means what the ladder reads it to mean.
5. **`reap()`'s command branch is untested** — the spec covers the kill count but not `:ParleyProxy reap`'s double scan or its confirmation list.

The `decide` table-test plus the `attempt >= 1` property sweep (`cliproxy_auth_spec.lua`) and the external-oracle epoch assertions remain the strongest patterns in this diff — they falsify the implementation rather than restate it.

## 6. Architectural notes for upcoming work

- **ARCH-DRY — pass with nits.** Every consolidation this milestone made has two live callers and one source: `restart_managed`, `credential_action`, `channels_for_login`, `healthier`, `SUBS_HELP` (now including `reap`, closing round 3's discoverability finding, with README updated in the same range). `_stray_spawned` was correctly *deleted* rather than kept after round 3's deletability check — the right response. Remaining duplication is prose and defaults, not logic: the rotation-race explanation twice, and `newest_credential_mtime` re-deriving the auth-dir default.
- **ARCH-PURE — flag, narrowly.** `decide`, `credential_action`, `rfc3339_sec`, `parse_peers`, `channels_for_login`, `healthier` are genuinely pure, mock-free and externally validated; `recover` is gather-then-execute with no policy in it. Two things sit on the wrong side of the seam: choosing the oldest peer is business logic done in the IO shell with a string compare (I1) when `parse_peers` already parses the field, and `run_login`'s "which line is the URL" is a per-provider policy decision embedded in a `jobstart` callback (C1) — a pure `authorize_url(provider, line)` table would be unit-testable across all seven providers without spawning anything.
- **ARCH-PURPOSE — flag.** Shadow sweep on "who infers auth state" is clean: dispatch derives from the management API ✓, `:ParleyProxy models` derives on the correct channel axis ✓, all three hand-maintained restatements of the disproved empty-list inference are corrected ✓, and "stale in-memory auth … repaired" is delivered and verified ✓. The residue is the login half, which *is* M3's point rather than a separable extension: the flow is unusable for most providers (C1) and "resumes the query" is neither wired nor descoped (I2).
- **ARCH-MOCK — flag.** The fake's `updated_at` modelling (`fake_cliproxy:104-110`, load time = first sighting of this content) is exactly right — it makes the fake honest about the distinction the restart rung reads, instead of letting a fixture manufacture it, which is what defeated round 3. `--error-mode`/`_once` run production's own HTTP boundary with captured 7.1.71 bodies. The gap is the *process* boundary: `run_login` is the one place production shells out to a binary whose output it parses, and the fake models a single provider's output. A fake satisfies this principle only when the behavior we branch on is the behavior we check — here the branch is "does this line carry the authorize URL", and it is checked for one of seven providers.
- **Plan-gate carry-forward:** `workshop/plans/000197-cliproxy-auth-self-healing-plan-gate.md` `## Open findings` reads "(none — every finding has been disposed)" — verified on disk. PQ-5 was the item deferred into M2; delivered, on the right axis. Nothing to carry.
- **Prior-review carry-forward:** of round 4's nine findings, C1, I1, I2 and I3 are closed and verified closed. **I4, I5, I6, I7 and I8 remain open** and are re-filed above at their original severity. The `expired`-row plan correction has now survived four reviews; the `_retry` docstring four; the e2e dead scaffolding four.
- **For the close:** `stop()` has four callers and `peers()` two. Before a fifth appears, the port-release discipline, the `ps`/`lsof` cost and the peer-scan latch all want to sit behind one seam with one arming point.

## 7. Plan revision recommendations

Append to `workshop/plans/000197-cliproxy-auth-self-healing-plan.md` `## Revisions`:

1. **Rewrite Revisions entry #1 — it now describes a deleted design.** It records normalization "at the IO seam (`uv.fs_stat().mtime.sec`)" and `proxy_state` carrying `auth_file_modtime`; round 3 replaced that with a comparison *entirely inside the management record* (`modtime` = the file's mtime re-stat'd per request, `updated_at` = when the proxy loaded it), verified against the real binary, with no `fs_stat` — so the check is pure and left the repair budget. Correct Task 9 Step 3 (`:427`) to match instead of leaving it specifying `record_modtime` and a string compare.
2. **The `decide` table's `expired` row still contradicts the code** (`:421`). The shipped policy retries on `healthy` (deliberately) and reports on `unknown`. Recommended at rounds 1, 2, 3 and 4 — correct the row or record why it stands.
3. **Add Core-concepts rows for the eleven M2/M3 entities** — `credential_action`, `rfc3339_sec`, `healthier`, `channels_for_login`, `restart_managed`, `credential_health_for_login`, `peers`, `reap`, `callback_port_blocked`, `await_credential`, `run_login` — with kind/location/status/milestone (round 2 rec #2, round 3 rec #3, round 4 rec #3, still undone).
4. **Record `run_login`'s per-provider contract.** Task 15 assumes one authorize-URL shape; the binary emits at least three (`/oauth/authorize`, `/o/oauth2/auth`, device-code flows). Record that `-no-browser` may only be passed where parley can capture and open the URL, that unmatched output must still reach the operator, and that the fake grows a device-code login mode so the rule is testable.
5. **Record whether "resumes the query" is in scope.** Either wire `run_login`'s `on_done` back to a re-issue, or record the descope with the reason (an OAuth flow outlives the claim's 30 s backstop by two orders of magnitude) so the Done-when stops reading as delivered.
6. **Tick what shipped.** 1 of 56 checkboxes is ticked while M1/M2/M3 are all `[x]` in the issue; the plan is the greppable record of what was built, and at 1/56 the next reviewer's traceability pass is meaningless.
