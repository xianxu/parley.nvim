# Boundary Review — parley.nvim#197 (milestone M1)

| field | value |
|-------|-------|
| issue | 197 — cliproxy auth failures must self-heal: detect, diagnose, recover |
| repo | parley.nvim |
| issue file | workshop/issues/000197-cliproxy-auth-self-healing.md |
| boundary | milestone M1 |
| milestone | M1 |
| window | 1bbe3050ddd7e4a3193bc7691f51ca1168b27a32^..HEAD |
| command | sdlc milestone-close --issue 197 --milestone M1 |
| reviewer | claude |
| timestamp | 2026-08-01T02:11:53-07:00 |
| verdict | REWORK |

## Review

```verdict
verdict: REWORK
confidence: high
```

M1 delivers what it claims: `cliproxy_auth.lua` is genuinely pure and well-tested, the status gate that PQ-2 demanded is a real property test, the claim contract PQ-8 demanded is implemented faithfully in the dispatcher (including the once-guard and backstop), the management route is read from the running proxy rather than inferred, the fake serves it from a portable credential store, and a live conformance spec boots the real 7.1.71 binary. I re-ran everything: `make test-spec SPEC=providers/cliproxy-managed` → 0 failed / 0 errors across all 11 specs (conformance ran for real, no SKIP line), `make lint` → 0/0 in 309 files. What blocks SHIP is one confirmed regression: the diff deleted the `pcall` that guarded the old auth-failure hook and did not replace it at the new seam, so any throw inside `cliproxy.recover` now aborts the terminal closure *before* `deliver()` and *before* the backstop timer is armed — and `tasker.run` swallows that error — leaving the chat leg stranded with no message at all. I reproduced this (0 `on_error` deliveries). That plus a small cluster of Important items around the repair's one-shot guard and untested wiring.

## 1. Strengths

- **`cliproxy_auth.lua` is honestly pure** (`lua/parley/cliproxy_auth.lua:1-191`) — no `vim.*`, no clock, no IO. `tests/unit/cliproxy_auth_spec.lua` runs it with zero mocks, and the `HEALTH_RANK` max-reduction is tested for order-independence *and* account attribution, which is the subtle part. ARCH-PURE passes cleanly here.
- **The PQ-2 property test is a real property, not a case list** (`cliproxy_auth_spec.lua:22-36`): bodies × 2xx statuses, with the prose case quoting every trigger word. This is exactly the regression the gate asked for and it would catch a future refactor that moves the status check.
- **The claim contract is implemented as specified, including the hard parts** (`dispatcher.lua:453-478`): one shared `tasker.once` behind both continuations, the backstop that can't double-fire, and `local function start_query` threaded as its own restart entry point. J4/J5/J6/J7 pin retry-once, no re-entry, anti-double-fire, and the timer — driven by overriding `recovery_timeout_ms` rather than sleeping.
- **ARCH-MOCK is satisfied at the boundary that matters**: the fake serves `/v0/management/auth-files` from a folder of credential JSONs plus a mutable `state.json` overlay (`tests/fixtures/fake_cliproxy:66-118`), production and test both reach it through `api_argv` + curl over HTTP, and `cliproxy_conformance_spec.lua` checks the real binary still emits every field `classify_auth_files` reads — including pinning *why* a separate management key exists (the api-key bearer gets 401).
- **The PATH pin is the right defensive fix** (`cliproxy_lifecycle_spec.lua:73-84`): the discovery that the suite could spawn a real proxy against the operator's live auth-dir is the same rotation race this issue exists to fix, and the comment explains why `_set_data_dir` didn't cover it.

## 2. Critical findings

**C1 — `adapter.recover_query` is called unprotected; a throw strands the chat leg forever, with no notice.** `lua/parley/dispatcher.lua:462`

The deleted code was `pcall(function() require("parley.cliproxy").check_auth_failure(...) end)`. The replacement has no guard: `providers.lua:1123` pcalls only the `require`, not the call into `cliproxy.recover`. `recover` reaches `render_opts()` → `management_key()` → `vim.fn.mkdir` (raises E739 on an unwritable data dir) and `vim.system(...)` (raises if `curl` isn't executable), all synchronously, before it returns its claim.

Failure scenario: `curl` missing from PATH (or the data dir unwritable) → `recover` raises at `dispatcher.lua:462` → `deliver()` at line 478 is skipped and `vim.defer_fn` at 472 was never reached, so no backstop → `tasker.lua:355` `call_safely` xpcalls the terminal and swallows the error (logs only `task terminal callback failed`) → `on_error` never fires → `teardown_chat_leg` never runs → spinner and chat lease hang for the rest of the session. This is strictly worse than the pre-#197 behavior it replaced.

Confirmed empirically with a throwing `recover_query`: the terminal closure raised and `on_error` deliveries = 0.

Fix sketch (in the dispatcher, since it owns the mechanism):
```lua
local ok, claimed = pcall(adapter.recover_query, failure, function() settle("retry") end,
    function(msg) settle("give_up", msg) end)
if not ok then
    logger.error(provider .. ": recover_query raised: " .. tostring(claimed))
    claimed = false        -- a hook that blew up never claimed anything
end
if claimed then … end
```
Note the J-group harness cannot catch this class: `tasker.run` is stubbed and the test calls `captured_terminal(...)` directly, so the real `call_safely` swallow never participates. Add a test that asserts a throwing `recover_query` still produces exactly one `on_error`.

## 3. Important findings

**I1 — Nothing verifies `cliproxyapi.recover_query` is actually wired to the adapter.** `lua/parley/providers.lua:1122-1127`
The J-group tests install their *own* `recover_query` via a patched `providers.get`; `cliproxy_auth_login_spec` calls `cliproxy.recover(...)` directly. Delete or rename the registration at `providers.lua:1123` and every test in the boundary still passes while the feature is dead. `pre_query` has exactly this coverage (`providers_pre_query_spec.lua`: "is registered on the cliproxyapi adapter" + "delegates … with BOTH callbacks"). Fix: add the mirrored pair — assert `providers.get("cliproxyapi").recover_query` is a function and that it delegates to `cliproxy.recover` returning its value.

**I2 — `_management_restart_done` is never reset after a successful restart; the comment says it is.** `lua/parley/cliproxy.lua:325-334, 345-361`
The comment claims the flag "is reset explicitly (tests, and after a successful restart) so it can never become a permanently-latched flag" and cites `workshop/lessons.md:406`. In the code only `M._reset_management_restart()` (the test seam) clears it — `credential_health` sets it at line 350 and nothing in the success path clears it. Failure scenario: the repair succeeds; later in the same session the operator runs `brew services restart cliproxyapi` (or another nvim spawns from an older rendered config); the new proxy 404s; parley reports `no_management_route` forever and every diagnosis degrades to "could not read credential state". Fix: clear the flag in the success continuation once `auth_files` returns a non-`no_management_route` health, or key the guard to the restarted pid — then correct the comment either way.

**I3 — The repair races SIGTERM and can silently "succeed" against the dying proxy.** `lua/parley/cliproxy.lua:353-355`
`M.stop()` sends SIGTERM and returns immediately (`cliproxy.lua:523,531`); `ensure_running` then renders and probes. Failure scenario: the old proxy is still listening when the probe lands (real `cliproxyapi` does a graceful shutdown, unlike the Python fake the test uses) → `ensure_running` takes the reuse-if-healthy branch at `cliproxy.lua:453` and never spawns → `auth_files` re-404s → and by I2 the one-shot is already spent, so the session can never repair. The lifecycle test passes only because the fake dies instantly. Fix: before `ensure_running`, poll (bounded) until the port stops answering — or until the killed pids are reaped — then proceed.

**I4 — The exact symptom the issue names is still emitted: `cliproxyapi response is empty: body_bytes=215`.** `lua/parley/dispatcher.lua:310-315`
`logger.error` notifies the user (`logger.lua:100` → `vim.notify(..., ERROR)`), and `finish_stdout` runs before the terminal closure, so on the #197 503 the operator sees the misleading empty-response error *first*, then the new diagnosis. The issue's Done-when reads "produces a diagnosis … — **not** `response is empty`". Fix sketch: don't log it in `finish_stdout`; record `qt.empty_response = true` there and emit the error from the non-failed branch of the terminal closure (which is the only scope that knows the request actually succeeded).

**I5 — The `chat_respond` behavior change has no test.** `lua/parley/chat_respond.lua:2049-2065`
Preferring `failure.message` over `failure.body` is the last mile of the whole milestone — it's what puts the diagnosis in front of the user — and the only existing assertion (`chat_respond_spec.lua:1740`) matches on `"provider request failed"`, which passes either way. Fix: assert that a failure carrying `message` surfaces the message and not the raw body, and that a failure without `message` still falls back to the body.

**I6 — The actionable `oauth-model-alias` guidance was deleted with no replacement.** `lua/parley/cliproxy.lua:708-723`
The old `check_auth_failure` warned `"<model>" — unknown provider / missing auth. Add it to cliproxy.config['oauth-model-alias'], or :ParleyProxy login <provider>`, and `cliproxy_auth_login_spec` tested it ("WARNs (no prompt) when the model isn't in any oauth-model-alias channel"). That test was removed and nothing replaced it. Now, when the 503 names `providers=claude` but the model isn't in any alias channel, `channel` is truthy (from `verdict.provider`) while `login` is nil, so no prompt fires and the diagnosis says "log in to create one" without telling the operator that the reason no login was offered is the missing alias entry. Fix: when `needs_human` holds but `login` is nil, append the alias hint to the message, and restore a test for that path.

## 4. Minor findings

- `cliproxy.lua:713-714` — ARCH-DRY: `resolve_login_provider` is recomputed with an inlined alias lookup, though `channel_for(verdict.model)` at line 708 already computed exactly that value. `local login = channel_for(verdict.model)` is equivalent and removes the second derivation.
- `cliproxy.lua:134-137` — `split_status` was introduced as the shared body/status splitter but the two pre-existing copies of the same regex were left in place: `classify` (`cliproxy.lua:97`) and `list_models` (`cliproxy.lua:757`). ARCH-DRY: the consolidation target already exists; use it.
- `cliproxy.lua:701-706` — the comment says "Diagnose without claiming so the operator still learns why", but the streamed path only calls `logger.warning` with a generic sentence; no `credential_health`, no `ca.diagnosis`. Either produce the diagnosis or fix the comment.
- `cliproxy.lua:715-722` — an `expired` verdict prompts for login even when the proxy reports the credential `healthy`, while the message it prompts *with* reads "the credential looks healthy". Contradictory, and untested (the healthy-no-prompt spec only exercises `no_auth`).
- `cliproxy_auth.lua:61` — `http_status == 0` (curl produced no HTTP response) is treated as a classifiable failure status, which contradicts the docstring's own "never classify what you cannot situate" rule that motivates the nil case. Treat 0 like nil.
- `cliproxy.lua:213-223` — `io.open(path, "w")` creates `management.key` at the umask default before the `fs_chmod(0600)`; a brief world-readable window. Also `render_opts()` now performs `mkdir` + `open` on every call, and `render_opts` is on the `ensure_running` path for every query.
- `cliproxy.lua:638` — the section banner is ~150 chars while every other rule in the file is 80; looks like an accidental edit.
- `workshop/parley/2026-08-01.00-06-47.671_hello.md` — an empty scratch chat ("hello" / no reply) committed into the boundary. Noise in the window; drop it.

## 5. Test coverage notes

Verified independently: all 11 specs under `providers/cliproxy-managed` pass (0 failed / 0 errors), the conformance spec genuinely booted the real binary (no SKIP line printed), and `make lint` is 0/0 across 309 files. The Log's counts match what I observed.

Gaps, in the order I'd close them:

1. **No end-to-end path.** Every recover test hand-builds a `failure` table and calls `cliproxy.recover` directly; nothing drives a failing cliproxy chat through `dispatcher.query` → `recover_query` → `on_error` → the chat notice. The plan's integration-points table lists `/v1/chat/completions` error modes (`no_auth`, `expired`, `quota`, `ok`) for the fake — those were not implemented in this diff. Combined with I1 and I5, the three links that actually deliver the milestone's user-visible outcome (adapter registration → failure-table field names → the chat notice) are each individually untested. Plan Task 11 schedules the e2e spec for M2; adding the fake's `no_auth` mode now would let one spec cover all three.
2. **No test for a throwing `recover_query`** (C1). The harness stubs `tasker.run`, so it doesn't model the real `call_safely` swallow — worth a comment in Group J noting that limitation.
3. `management_key()`'s non-persistable branch (`cliproxy.lua:213-218`) is untested; it's the path that silently forces a restart next session.
4. The `expired` + `healthy` combination (Minor above) is unexercised in both the unit and integration specs.

The fixture-tie test (`cliproxy_auth_spec.lua:206-215`, classifying the captured 7.1.71 payload) is a good pattern — it stops the hand-written `rec()` helper from drifting away from the real schema. Worth keeping in mind for M2's `decide`.

## 6. Architectural notes for upcoming work

- **ARCH-DRY — flag.** Two consolidations named above (`resolve_login_provider` recomputed at `cliproxy.lua:713`; `split_status` added but its two pre-existing duplicates left at `cliproxy.lua:97` and `:757`). The `api_argv` generalization itself is a clean pass — four call sites, one request shape, and the atlas claim is now true.
- **ARCH-PURE — pass.** `cliproxy_auth.lua` holds the reasoning, `cliproxy.lua` gathers inputs and executes, and the pure tests need no mocks. One thing to watch in M2: `recover` is already growing policy inline (the `needs_human` predicate at `cliproxy.lua:715-717` is decision logic living in the IO shell). That predicate belongs inside `decide` when Task 9 lands — otherwise M2 will have two policy owners.
- **ARCH-PURPOSE — pass with a tracked deferral.** The shadow-sweep over "who infers auth state": the dispatch path now derives from the management API ✓; `detect_auth_failure`/`check_auth_failure` are gone with no leftovers (grepped `lua/ tests/ atlas/ README.md` — only historical comments remain) ✓; `classify()`'s `needs_login` stays a liveness verdict as the plan directs ✓. The one remaining hand-maintained inference is `:ParleyProxy models` at `init.lua:408-419`, which still reads "empty model list ⇒ not authenticated" — the exact inference this issue disproved. That's a *separable* consumer (a different command surface, not the dispatch failure that is M1's point) and it is scheduled as M2 Task 12 per PQ-5, so the deferral is legitimate — but until Task 12 lands the codebase asserts two contradictory things about auth state, and that contradiction should not survive M2.
- **ARCH-MOCK — pass.** Stateful fake behind the same HTTP boundary, portable file-backed credential store, live conformance check against the real binary, and the safety note about never pointing it at the operator's auth-dir is the right thing to have written down. The one thing missing for M2 is the chat-completions error modes; without them the recovery ladder will be forced back onto hand-built failure tables.
- **Plan-gate carry-forward:** `workshop/plans/000197-cliproxy-auth-self-healing-plan-gate.md` `## Open findings` is empty — all nine PQ findings disposed. I re-checked each disposition against the code: PQ-1 (no config-drift restart; 404-driven instead) ✓, PQ-2 (status gate + property test) ✓, PQ-3 (`model` threaded from `payload.model`) ✓, PQ-4 (single seam, both old functions deleted) ✓, PQ-5 (still scheduled as M2 Task 12) ✓, PQ-6 (login modes still scheduled, M3 Task 15) ✓, PQ-7 (`disable-control-panel` defaults true, `allow-remote` never set, both tested) ✓, PQ-8 (claim contract as specified) ✓, PQ-9 (plan compressed) ✓. Nothing to carry forward.

## 7. Plan revision recommendations

Add a `## Revisions` entry to `workshop/plans/000197-cliproxy-auth-self-healing-plan.md`:

1. **Integration-points table is incomplete for what M1 shipped.** `credential_health` — a new public function in `cliproxy.lua` carrying the whole 404-repair policy — appears nowhere in the table; the plan describes the repair only as prose in Task 5. Add the row (`credential_health | lua/parley/cliproxy.lua | new | auth_files + the one unattended restart`), and `split_status` alongside `api_argv`.
2. **The fake's `/v1/chat/completions` error modes were not delivered in M1.** The integration-points table lists them (`no_auth`, `expired`, `quota`, `ok`) under the same `fake_cliproxy` bullet as the management route, and Task 4 Step 1 reads as if the whole bullet lands there. Record that only the management route + credential store + 404 behavior shipped in M1, and move the error modes explicitly into M2 Task 10/11 — otherwise the table claims a fake capability that doesn't exist.
3. **Mark the Core-concepts table rows by milestone.** `decide`, `parse_peers`, `peers`/`reap`, and the hardened `login` are all listed as "new" with no milestone column, so an M1 reviewer cross-checking the table against the filesystem finds four entities that don't exist. Adding an `M1/M2/M3` column makes the table verifiable at each boundary rather than only at final close.

---

## Re-review — 2026-08-01T04:23:47-07:00 (unknown)

| field | value |
|-------|-------|
| issue | 197 — cliproxy auth failures must self-heal: detect, diagnose, recover |
| repo | parley.nvim |
| issue file | workshop/issues/000197-cliproxy-auth-self-healing.md |
| boundary | milestone M1 |
| milestone | M1 |
| window | 1bbe3050ddd7e4a3193bc7691f51ca1168b27a32^..HEAD |
| command | sdlc milestone-close --issue 197 --milestone M1 |
| reviewer | claude |
| timestamp | 2026-08-01T04:23:47-07:00 |
| verdict | unknown |

## Review

API Error: Connection closed mid-response. The response above may be incomplete.
API Error: Connection closed mid-response. The response above may be incomplete.

---

## Re-review — 2026-08-01T10:44:54-07:00 (REWORK)

| field | value |
|-------|-------|
| issue | 197 — cliproxy auth failures must self-heal: detect, diagnose, recover |
| repo | parley.nvim |
| issue file | workshop/issues/000197-cliproxy-auth-self-healing.md |
| boundary | milestone M1 |
| milestone | M1 |
| window | 1bbe3050ddd7e4a3193bc7691f51ca1168b27a32^..HEAD |
| command | sdlc milestone-close --issue 197 --milestone M1 |
| reviewer | claude |
| timestamp | 2026-08-01T10:44:54-07:00 |
| verdict | REWORK |

## Review

```verdict
verdict: REWORK
confidence: high
```

M1 largely delivers what it claims, and the round-1 rework is real: `cliproxy_auth.lua` is genuinely pure and mock-free, the PQ-2 status gate is pinned by an actual property test, the dispatcher claim contract is implemented faithfully (once-guard, backstop, `pcall` around the hook — the round-1 C1 is fixed and J7b pins it), the "response is empty" symptom is gone from the failure path (J7c/J7d), the adapter registration and the user-visible notice are now both tested, and the conformance spec really does boot 7.1.71. I re-ran everything myself: `make test-spec SPEC=providers/cliproxy-managed` → 12 specs, 209 examples, **0 failed / 0 errors** (the conformance spec ran against the real binary — no SKIP line); `make test-spec SPEC=chat/lifecycle` → 0/0 including `chat_respond_spec` 66; `make lint` → 0 warnings / 0 errors in 310 files. What blocks SHIP is two correctness bugs I reproduced empirically, both in the new code and both defeating the issue's own Done-when. **(C1)** `recover` feeds `classify_auth_files` a *login provider* where a *cliproxy channel* is required, so every Google-family channel reports `missing` and pops a login prompt even with a healthy credential loaded — I confirmed against the real binary that it emits `provider: "gemini-cli"`, while `resolve_login_provider` maps that channel to `"google"`. **(C2)** the 404 repair SIGTERMs the proxy unconditionally, but `ensure_running` no-ops when `manage = false`, so a user who runs their own cliproxyapi has it killed and never restarted — reproduced end to end.

## 1. Strengths

- **`cliproxy_auth.lua` is honestly pure** (`lua/parley/cliproxy_auth.lua:1-194`): no clock, no IO, no `vim.*` state. Its 28 unit tests run with zero mocks, and `HEALTH_RANK`'s max-reduction is tested for order-independence *and* account attribution — the subtle part. ARCH-PURE passes cleanly.
- **The PQ-2 property test is a real property** (`tests/unit/cliproxy_auth_spec.lua:22-36`): bodies × 2xx statuses, with prose quoting every trigger word. I verified it green; it would catch a refactor that moves the status gate.
- **The round-1 C1 fix is correct and well-placed** (`lua/parley/dispatcher.lua:471-479`): the hook is `pcall`ed *and* a raise is normalised to "never claimed anything", so `deliver()` still runs. J7b pins it, and the test even documents its own harness limitation (`tasker.run` is stubbed, so the real `call_safely` swallow doesn't participate) rather than overclaiming.
- **The I4 fix lands the issue's headline Done-when** (`dispatcher.lua:310-318, 493-497`): `finish_stdout` now *records* `empty_response` and only the success branch reports it. J7c/J7d pin both directions.
- **ARCH-MOCK is satisfied at the boundary that matters**: the fake serves `/v0/management/auth-files` from a folder of credential JSONs plus a mutable `state.json` overlay (`tests/fixtures/fake_cliproxy:67-116`), production and test both reach it through `api_argv` + curl over HTTP, and `cliproxy_conformance_spec.lua` checks the real binary still emits every field `classify_auth_files` reads — including pinning *why* a separate management key exists (the api-key bearer gets 401).
- **The PATH pin is the right defensive fix** (`tests/integration/cliproxy_lifecycle_spec.lua:73-84`): the discovery that the suite could spawn a real proxy against the operator's live auth-dir is the same rotation race this issue exists to fix.

## 2. Critical findings

**C1 — `recover` passes a login provider where a cliproxy channel is required; a healthy gemini-cli/aistudio credential is reported as "no credential is loaded" and prompts a spurious login.** `lua/parley/cliproxy.lua:747-748` (and `:777`)

```lua
local login = channel_for(verdict.model)   -- returns CHANNEL_LOGIN[channel], a LOGIN provider
local channel = login or verdict.provider  -- verdict.provider IS a channel; login is not
M.credential_health(function(health) … end, channel or "claude")
```

`channel_for` → `cc.resolve_login_provider` returns `CHANNEL_LOGIN[channel]` (`cliproxy_config.lua:140-149,165`), which collapses `gemini`/`gemini-cli`/`aistudio` → `"google"`. `classify_auth_files` matches `(f.provider or f.type) == channel` (`cliproxy_auth.lua:121`), and the real binary emits `gemini-cli`. Two namespaces, and the wrong one wins — `verdict.provider` (the correct axis, captured from `providers=…`) is only the *fallback*.

Confirmed against the real 7.1.71 binary (fabricated credential, throwaway auth-dir):
```
[{'provider': 'gemini-cli', 'type': 'gemini-cli', 'account': 'probe@example.invalid', 'status': 'active'}]
```
Confirmed end to end through `recover` against the fake, with a **healthy** gemini-cli credential loaded:
```
health(gemini-cli) = { state = "healthy", account = "me@example.com" }
health(google)     = { state = "missing" }
claimed=true settled=give_up
DIAGNOSIS: cliproxy for "gemini-2.5-pro": no credential is loaded for this channel — log in to create one
PROMPTED:  cliproxy for "gemini-2.5-pro": no credential is loaded for this channel — log in to create one
```
This breaks the issue's Done-when ("only a genuinely dead credential prompts") and fabricates the state the issue exists to report honestly. It survives every test because the fake store and all ten `recover` specs use `claude`, where the two namespaces coincide.

The `channel or "claude"` fallback is the second half of the same defect: when neither axis resolves, parley diagnoses an arbitrary channel and can confidently report *another* account's health for the failing model.

Fix sketch: extract the channel resolution as its own pure function and build the login mapping on top of it (ARCH-DRY, one model→channel source):
```lua
-- cliproxy_config.lua
function M.resolve_channel(model, oauth_model_alias) … return channel end
function M.resolve_login_provider(model, alias)
    local ch = M.resolve_channel(model, alias)
    return ch and CHANNEL_LOGIN[ch] or nil
end
```
then in `recover`: `local channel = verdict.provider or cc.resolve_channel(verdict.model, alias)`, `local login = channel and CHANNEL_LOGIN[channel]`, and when `channel` is nil **do not guess** — skip the lookup and pass `{state="unknown", reason="unknown_channel"}` so `diagnosis` takes its existing "could not read credential state" branch. Add a non-claude case to `cliproxy_auth_login_spec` and a `gemini-cli` credential to the fake store.

**C2 — the 404 repair kills a proxy parley does not manage, and cannot restart it.** `lua/parley/cliproxy.lua:378-395`

`credential_health` calls `M.stop()` unconditionally. `M.stop()` reaps whoever holds the port after an identity probe (`cliproxy.lua:556-573`) — including a 401 `client_key_mismatch`, i.e. a proxy with the operator's own api-key. `M.ensure_running` then returns immediately without spawning when `not M.is_managed()` (`cliproxy.lua:479-481`). `recover_query` is registered on the adapter unconditionally (`providers.lua:1122-1127`) and `M.recover` never checks `is_managed()`, so this path is reachable for a user who opted out with `cliproxy = { manage = false }` — a configuration README:191 documents and the atlas calls "cooperative for those who run their own (it reuses it)".

Reproduced (fake proxy started keyless, `parley.config = { cliproxy = { manage = false } }`):
```
Parley.nvim: cliproxy: proxy is running without the management route — restarting it …
HEALTH: { state = "unknown", reason = "unreachable", message = "" }
UNMANAGED PROXY STILL ALIVE: false
PORT STATE AFTER: down
```
Worse: because the second lookup returns `unreachable` (not `no_management_route`), the I2 fix clears `_management_restart_done` (`cliproxy.lua:386-388`), so the next auth failure kills the proxy again if the operator restarted it.

Fix sketch: gate the repair on `M.is_managed()`; when unmanaged, return the 404 health as-is with actionable text ("this proxy is not managed by parley — add `remote-management.secret-key` to your own cliproxy config so parley can read credential health"). Add a spec that asserts an unmanaged proxy survives `credential_health`.

## 3. Important findings

**I1 — `extract_message` truncates at the first escaped quote, so the diagnosis degrades to a fragment.** `lua/parley/cliproxy_auth.lua:44-46`
`body:match('"message"%s*:%s*"(.-)"')` stops at the backslash-escaped quote Go's `%q` error wrapping produces — and cliproxy's own captured `status_message` is exactly that shape (`Post "https://api.anthropic.com/v1/messages?beta=true": dial tcp: …`). Verified:
```
MESSAGE: Post \
DIAG: cliproxy: the request failed but the credential (me@x.com) looks healthy: Post \
```
`verdict.message` is the entire informational payload of the `healthy`, `unknown`, and `quota` branches, so this reproduces the naked-fragment notice #197 set out to replace. Fix: `pcall(vim.json.decode, body)` and read `.error.message` / `.message` (still pure), falling back to the pattern; or unescape `\"`/`\\` in the captured span. Add the escaped-quote body to `cliproxy_auth_spec`.

**I2 — a retry re-runs `format_headers` on a payload whose route marker was already consumed, silently changing the request.** `lua/parley/dispatcher.lua:531-534` + `lua/parley/providers.lua:1053, 1060-1064`
`format_payload` sets `payload._parley_route = "anthropic"` once, before `D.query`; `cliproxyapi.format_headers` reads it and sets it to `nil`. `start_query(attempt+1)` re-enters `query` with the *same* payload table, so attempt 1 sees `nil` and falls back to `route = "openai"` — an anthropic-routed claude request would be retried against the OpenAI-shaped endpoint with OpenAI headers. `googleai.format_headers` has the same shape (`providers.lua:831` nils `payload.model`), so this is a property of the seam, not of one adapter. M1 never calls `retry()`, so there is no user impact yet — but M2's ladder calls it on exactly the claude path, and J4 only asserts the start count, not payload identity. Fix: snapshot the payload per attempt (`local attempt_payload = vim.deepcopy(payload)` inside `query`, or have `start_query` pass a fresh copy).

**I3 — `wait_port_released`'s "bounded" 3s wait is not bounded to 3s.** `lua/parley/cliproxy.lua:342-355`
`waited` accumulates only the 150ms defer interval, never the probe time; each `health_probe` is a curl with `--max-time 2`. A port that accepts but does not answer therefore takes up to ~43s (20 iterations × ~2.15s) — well past the dispatcher's 15s backstop, so the chat leg has already been told "recovery timed out" while `stop()`/`ensure_running` keep mutating proxies behind it. `poll_until_healthy` five lines below does this correctly with `uv.now() + BUDGET` (`cliproxy.lua:451,462`). Fix: use the same wall-clock deadline — and consider one shared bounded-poll helper (ARCH-DRY).

**I4 — the docs contradict the code on the repair guard.** `atlas/providers/cliproxy-managed.md:148` and `lua/parley/cliproxy.lua:361`
Both still say the repair happens "at most once per session", but the round-1 I2 rework deliberately changed it to bound *consecutive* attempts (cleared on any successful lookup — `cliproxy.lua:369-372, 386-388`), which the inline comment three lines below correctly describes. New surface documented wrongly in two places, including the atlas the docs gate covers. Fix both to "at most once per consecutive run of 404s".

**I5 — no test exercises a non-claude channel, which is precisely why C1 shipped.** `tests/integration/cliproxy_auth_login_spec.lua`, `tests/integration/cliproxy_lifecycle_spec.lua:600-720`
The fake's credential store, the `MANAGED` alias config, and all ten `recover` specs use `claude`, where channel and login provider happen to be the same string. One `gemini-cli` fixture in the store plus one `recover` case would have failed loudly. Add it alongside the C1 fix.

## 4. Minor findings

- `dispatcher.lua:491` — `deliver()` is not once-guarded; an adapter that calls `give_up()` and then returns falsy fires `on_error` twice. Route the fallthrough through `settle("give_up")` so the contract is enforced, not merely documented.
- `cliproxy.lua:229-242` — `render_opts()` calls `management_key()`, which does `vim.fn.mkdir` + `io.open` on **every** call; `render_opts` is on `write_rendered_config` → `ensure_running` → every query. Memoize per data-dir (with the existing `_set_data_dir` seam clearing it).
- `cliproxy.lua:382` — `M.stop()` on the recovery path performs two blocking `vim.system():wait()` calls (curl `--max-time 2`, `lsof`) on the main loop, i.e. a UI stall on a chat failure.
- `cliproxy.lua:674` — the section banner is 81 chars while every other rule in the file is 80 (round-1 Minor, not applied).
- `dispatcher.lua:485-487` — the 15s backstop timer is armed for every claimed failure and still fires into a spent `once` after a fast settle; harmless, but a stray timer per failed query.
- `tests/integration/cliproxy_auth_login_spec.lua:110,112` — `vim.ui.select = saved_select` twice in `after_each`.
- `tests/integration/cliproxy_auth_login_spec.lua:65-70` — the spec overwrites `parley.dispatcher.providers.cliproxyapi` and never restores it (`saved_config` only covers `parley.config`).
- `cliproxy_auth.lua:100-108` — a record with no `status` field is treated as `healthy`; the conformance spec asserts `status` exists, but a defensive `missing`/`unknown` would be safer than assuming health.

## 5. Test coverage notes

Verified independently rather than from the Log: 12 specs under `providers/cliproxy-managed` → **0 failed / 0 errors** (config 42, auth 28, dispatcher 55, lifecycle 44, auth_login 10, failure_notice 6, pre_query 6, conformance 2, plus dispatch/command/teardown/download); `chat/lifecycle` → 0/0 with `chat_respond_spec` 66; `make lint` → 0/0 in 310 files. The conformance spec genuinely booted the real binary — no SKIP printed.

Gaps, in the order I'd close them:

1. **Single-channel blindness (I5).** Everything is `claude`. C1 is a whole-namespace error that no test could see.
2. **No end-to-end path.** Every recover test hand-builds a `failure` table; nothing drives a failing cliproxy chat through `dispatcher.query` → `recover_query` → `on_error` → the chat notice. The plan now correctly defers the fake's `/v1/chat/completions` error modes to M2 Task 10 — but until they exist, the three links that produce the milestone's user-visible outcome are each tested only in isolation.
3. **Retry fidelity.** J4 counts `tasker.run` invocations; nothing asserts the retried request is the *same* request (I2 shows it isn't).
4. **Unmanaged mode.** No spec runs `recover`/`credential_health` with `manage = false` (C2).
5. `management_key()`'s non-persistable branch (`cliproxy.lua:213-219`) and `auth_files`' `no_endpoint` branch (`cliproxy.lua:290-293`, which calls `cb` *synchronously* — the one path where `give_up` fires before `recover` returns its claim) are both untested.

The fixture-tie test (`cliproxy_auth_spec.lua:206-215`, classifying the captured 7.1.71 payload) remains a good pattern; extend it with a second captured channel when fixing C1.

## 6. Architectural notes for upcoming work

- **ARCH-DRY — flag.** C1 is a DRY failure at heart: "which channel serves this model" has no single owner, so `resolve_login_provider` (the login axis) is reused as if it were the channel axis. I3 is a second one — two bounded-poll loops in the same file with different (and one incorrect) deadline arithmetic. **Pass** on the parts that were the point: `api_argv` really is the single request shape (four call sites verified), and `split_status` now consolidates the two pre-existing regex copies in `classify` and `list_models`.
- **ARCH-PURE — pass.** `cliproxy_auth.lua` holds the reasoning, `cliproxy.lua` gathers and executes, and the pure tests need no mocks. The plan's own carry-forward already names the thing to watch: `needs_human` at `cliproxy.lua:755-761` is decision logic living in the IO shell and must move inside `decide` when M2 Task 9 lands, or M2 ships with two policy owners.
- **ARCH-PURPOSE — flag.** The shadow sweep: the dispatch path derives from the management API ✓; `detect_auth_failure`/`check_auth_failure` are gone with no callers left (grepped `lua/ tests/ atlas/ README.md`) ✓; `classify()` stays a liveness verdict as the plan directs ✓. But C1 means the derivation is structurally present and *semantically wrong* for three of the eight channels — "every consumer derives from the source" is not satisfied when the key used to query the source is from a different vocabulary. Separately, two hand-maintained restatements of the disproved inference remain: `init.lua:408-419` ("empty model list ⇒ not authenticated") and its docstring twin at `cliproxy.lua:786-788`. Both are legitimately deferred to M2 Task 12 (PQ-5), but until then the codebase asserts two contradictory things about auth state, and that must not survive M2.
- **ARCH-MOCK — pass with a gap.** Stateful fake behind the same HTTP boundary, portable file-backed credential store, live conformance against the real binary (which I confirmed actually ran), and an explicit safety note about never pointing it at the operator's auth-dir. The gap is coverage of the fake's *state space*, not its architecture: one channel, and no chat-completions error modes yet.
- **Plan-gate carry-forward:** `workshop/plans/000197-cliproxy-auth-self-healing-plan-gate.md` `## Open findings` is empty. I re-checked each disposition against the code — PQ-1 (404-driven, no config-drift check) ✓, PQ-2 (status gate + property test, verified green) ✓, PQ-3 (`model` threaded from `payload.model`, `dispatcher.lua:425`) ✓, PQ-4 (single seam, both old functions deleted) ✓, PQ-5 (still scheduled M2 Task 12) ✓, PQ-6 (M3 Task 15) ✓, PQ-7 (`disable-control-panel` default true, `allow-remote` never set, both tested) ✓, PQ-8 (claim contract as specified) ✓, PQ-9 ✓. Nothing to carry forward.
- **Round-1 review carry-forward:** C1 ✓ (J7b), I1 ✓, I2 ✓, I3 ✓ (but see I3 above — the new wait is not bounded as advertised), I4 ✓ (J7c/J7d), I5 ✓, I6 ✓; Minors: `split_status` ✓, single `resolve_login_provider` derivation ✓, `http_status == 0` ✓, 0600-on-create ✓, expired-vs-healthy ✓, scratch chat dropped ✓. Still open: banner width, and `render_opts` doing `mkdir` + file read per call.

## 7. Plan revision recommendations

Add a second `## Revisions` entry to `workshop/plans/000197-cliproxy-auth-self-healing-plan.md`:

1. **Name the channel axis explicitly.** The plan describes credential health as keyed by "channel" but only ever names `resolve_login_provider` as the resolver — a different namespace (C1). Add a pure `resolve_channel(model, oauth_model_alias)` to the Core-concepts table (M1, `cliproxy_config.lua`), state that `resolve_login_provider` derives from it, and record that when no channel resolves, parley reports `unknown_channel` rather than defaulting to `claude`.
2. **State the managed-mode precondition on the repair.** Task 5's restart is only legitimate when `is_managed()`; the plan should say so, because `stop()` reaps the port holder from any session and `ensure_running` no-ops when unmanaged (C2).
3. **Record the retry's payload contract.** Task 10's ladder calls `retry()`, and `format_headers` mutates the payload (`_parley_route`, `model`). Say the seam re-issues from a per-attempt payload snapshot (I2), or Task 10 will silently change the request it retries.
4. **Give the Integration-points table a milestone column,** as the Core-concepts table now has. `peers`/`reap` and the hardened `login` are M3 and the fake's login modes are M3, but all four are listed as plain new/modified — the same cross-check problem the last revision fixed for pure entities.
5. **Correct one stale line:** `classify_response` is described as "Consumed by `decide`; never by the IO shell directly", but the plan's own Task 6 has `cliproxy.recover` (the IO shell) call it synchronously to make the claim cheap. Reword to reflect the shipped design.
