# Boundary Review — parley.nvim#237 (milestone M2)

| field | value |
|-------|-------|
| issue | 237 — ParleyProxy update fetches the latest release unless pinned; status shows the version |
| repo | parley.nvim |
| issue file | workshop/issues/000237-proxy-update-latest.md |
| boundary | milestone M2 |
| milestone | M2 |
| window | 00dbd4365d60c19e9ca4231d3b1264a32ffd1d68..4dce2f3036ce8cddf91bc02eefd5db10560350d5 |
| command | sdlc milestone-close --issue 237 --milestone M2 |
| reviewer | claude |
| timestamp | 2026-09-12T16:09:00-07:00 |
| verdict | REWORK |

## Review

```verdict
verdict: REWORK
confidence: high
```

The M2 code is small, clean and well tested where the fake reaches: `status` joins three bounded reads through a counter, `version_summary` stays pure, the route pin goes red when the fix is reverted (verified in a scratch worktree), and the four new conformance cases pass against the real 7.2.159 with the live GitHub check. What blocks SHIP is an operating fact of the release this issue installs that nothing in the window pins: on 7.2.159, five unauthenticated requests to `/v0/management/*` ban 127.0.0.1 from the **whole** management API for 30 minutes, keyed requests included. `version_probe` sends exactly such a request on every `:ParleyProxy status` and twice per `update`, so the feature locks parley out of credential health, recovery and login after a handful of uses. The operator's live proxy was already in that state when I first probed it.

## Strengths

- `lua/parley/cliproxy.lua:934-964` — the status join is the simplest correct shape: one counter, each read bounded, one callback, opted-out installs never touch GitHub (pinned by the request log in `cliproxy_update_spec.lua:617-623`).
- `lua/parley/providers.lua:196-212` — the route rewrite collapsed three ad-hoc `gsub`s into one suffix table; `tests/unit/dispatcher_spec.lua:373-394` pins all four configured shapes and fails without the fix (64/1 with base `providers.lua`).
- `tests/integration/cliproxy_conformance_spec.lua:334-360` derives each chat route the way dispatch does and asks the real binary; that is the right seam for "upstream removed a route".
- The `updated_at` case (`:172-181`) was loosened to the property the staleness rung reads, not to whatever 7.2.x happens to emit.
- `workshop/lessons.md` lesson 6 names the class (a fake that answers every path), not the symptom.

## Critical

**C1 — The unauthenticated version probe trips 7.2.x's management-auth lockout, banning parley's own keyed reads for 30 minutes** (ARCH-MOCK, ARCH-CONSTRAINTS; `lua/parley/cliproxy.lua:203-211`, call sites `:949`, `:2150`, `:2181`).

Measured against a throwaway 7.2.159 (`~/.local/share/nvim/parley/cliproxy/bin/cli-proxy-api`, temp config, free port):

| step | result |
|---|---|
| keyed `GET /v0/management/latest-version` | 200 |
| 12 unauthenticated GETs | `401 ×5`, then `403 ×7` |
| keyed GET afterwards | 403 `{"error":"IP banned due to too many failed attempts. Try again in 30m0s"}` |
| `X-Cpa-Version` on the 403 | present |
| `X-Cpa-Version` on `/v1/models` (401 or 200) | absent |

The operator's live proxy on 8317 answered my very first unauthenticated probe with that same 403 body, so the ban was already in force from today's status and update runs. Consequences: `auth_files` (`:368`) gets 403 → `reason = "http_403"` and credential health, the recovery ladder and login all read "unknown" for half an hour; `status` keeps printing the version (header rides on the 403) and never shows the ban; `restart_outcome`'s confirming probe (`:2181`) adds another failed attempt per update. Design decision 3 was verified on 7.1.71 only; the fake's 401 is stateless where the real binary carries a failure counter — exactly the ARCH-MOCK "stateless mock for a stateful interaction" case.

Fix sketch:
1. `version_probe` sends `M.management_key()` through `api_argv` the way `auth_files` does (`:368`); the header rides on the 200, no failed attempt is recorded, and the key goes only where `health_probe` already sends it (no new ARCH-SECURE exposure). Keep the header parse status-agnostic so a foreign proxy with another key still yields a version off its 401 (one failed attempt per status, which the message should say).
2. Model the counter in `fake_cliproxy` (N failed management attempts within a window → 403 with the ban body, keyed requests included), so `cliproxy_update_spec`'s status and update cases would have gone red.
3. Conformance: a keyed probe answers 200 with the header; and pin the lockout itself (5 unauthenticated → keyed 403) so the fake's model has a live check.
4. `auth_files`' `http_<n>` branch (`:383`) should carry the body: "management API returned HTTP 403: IP banned…" is actionable, "HTTP 403" is not.
5. Docs: `atlas/providers/cliproxy-managed.md` "even when it answers 401", the `version_probe` doc comment (`:196`), and the plan's decision 3 + operating envelope (add the row: management failed-attempt budget 5 per 30 min, basis measured).

## Important

**I1 — The conformance spec cannot see parley's own managed download, so its live checks are `pending` on the environment parley itself produces** (ARCH-MOCK; `tests/integration/cliproxy_conformance_spec.lua:22` vs `:38`). `_set_data_dir(tempname)` runs before `discover_binary()`, so the managed binary at the real data root is invisible; only a PATH binary counts. On this machine (managed 7.2.159 installed, no brew) every M2 conformance case reports pending; they ran only because the operator symlinked the binary onto PATH by hand. The atlas sentence "boots a real binary (parley's download, or one on PATH)" and Task 13's "the managed download or brew" are therefore untrue.

**This is the 2nd finding in family `env-gated-coverage`.** Rule: an environment-gated check must be satisfiable by the environment the project itself produces, and its gate must be printed as a pending reason, not a silent skip. Fix that rule: resolve `BINARY` from the real data root before overriding it (or read `managed_binary()` explicitly), and keep the existing "SKIP:" prints as `pending(...)` so `make test` output counts them.

## Minor

- **M1** (`tests/fixtures/fake_cliproxy:360-369`) — the new 404 rule has no driver: no integration spec posts a claude request on the anthropic route through the fake over HTTP (`chat_respond_spec` stubs the tasker; the fake-spawning specs post `claude-x` on the OpenAI route). The unit pin is what protects the route; the fake's refusal is documentation until one e2e case goes through it. Family: `fake-rule-without-driver`.
- **M2** (ARCH-ORDER, `cliproxy_update_spec.lua:589-606`) — the join is exercised with only the latest leg slow; `fake_cliproxy` has no delay knob for the health/version legs. **2nd finding in family `interleaving-seam`.** Rule: every async join gets a per-leg delay seam in the fake so each leg can be made the last to land. The counter is symmetric, so this is a coverage note, not a bug.
- **M3** (ARCH-DRY, `cliproxy.lua:913-921`) — `status` re-walks the precedence `discover_binary` (`:85-103`) already encodes. Have `discover_binary` return `(path, source)` and drop the second ladder.
- **M4** — the claude route change (`providers.lua`) lives in the Log and plan Revisions but not in the issue `## Spec` or its `## Revisions`; the issue's contract still describes only update and status. Family: `spec-carries-discovered-scope`.

## Test coverage notes

- Run here: `cliproxy_release_spec` 50/0, `dispatcher_spec` 65/0, `cliproxy_command_spec` 17/0, `cliproxy_update_spec` 37/0, `cliproxy_lifecycle_spec` 53/0, `cliproxy_dispatch/openai_tool_loop/caller_teardown/recovery_e2e` all green, `make lint` 0/0.
- Conformance with the real 7.2.159 on PATH + `PARLEY_LIVE_GITHUB=1`: 9 pass, 2 fail — the two pre-existing #205 catalog cases the Log already names (empty catalog with the fabricated credential).
- `make test` exits 2 on `fold_invariants_spec` ("1 tracked transcript unreadable": `workshop/parley/2026-09-10.11-10-24.522.md`). That is the operator's uncommitted deletion in the working tree (`D` in git status), not this window, but the close gate's `make test` will stay red until that rename is committed.
- Revert check: with base `providers.lua`, `dispatcher_spec` goes 64/1 on the route case. Claim holds.

## Architecture notes for upcoming work

- ARCH-DRY: flag (M3). ARCH-PURE: pass — decisions in `cliproxy_release`, `status` is glue. ARCH-PURPOSE: Done-when sweep passes (atlas/help no longer mention a pin; grep clean), but C1 means the status purpose degrades the proxy it reports on. ARCH-MOCK: flag (C1, I1, M1). ARCH-CONSTRAINTS: flag — the envelope table has no row for the dependency's failed-attempt budget, which is the constraint that bit. ARCH-SECURE: pass — no credential in logs/args beyond what `health_probe` already sends; header/redirect parses stay strict. ARCH-ORDER: flag (M2).
- #213's `:checkhealth` should read `version_summary`, as planned, and should also surface a management ban once C1's message carries the body.

## Plan revision recommendations

1. `## Revisions` — "2026-09-12 — M2 review round 1: 7.2.x management lockout": record the measured fact (5 unauthenticated `/v0/management/*` requests → 30-min IP ban, keyed requests 403, header still present), amend design decision 3 to a keyed probe, add the envelope row, and add the fake's failure-counter model + the two conformance cases to Core concepts / Test surface.
2. Same entry: correct "the managed download or brew" (Task 13) and the atlas sentence — conformance discovers the binary before the data-dir override, or it does not see parley's download.

```findings
findings:
  - id: new
    severity: Critical
    family: stateless-fake-for-stateful-dependency
    title: |
      Unauthenticated version_probe trips 7.2.x's management lockout: 5 failed attempts ban 127.0.0.1 from keyed management reads for 30 min
    detail: |
      Measured on the installed 7.2.159: five unauthenticated GET /v0/management/latest-version answer 401, the sixth onward 403 "IP banned due to too many failed attempts. Try again in 30m0s", and a request with the correct management key is then 403 too. Each :ParleyProxy status is one failed attempt, each update two (cliproxy.lua:949, :2150, :2181), so auth_files/recovery/login read "unknown" after a few uses; the operator's live proxy was already banned. Send M.management_key() as auth_files does (cliproxy.lua:368), model the counter in fake_cliproxy, pin it in conformance, carry the 403 body in auth_files' message, fix atlas/decision 3.
  - id: new
    severity: Important
    family: env-gated-coverage
    title: |
      Conformance discovers the binary after _set_data_dir(tempname), so parley's managed download is never seen and every M2 live case is pending on a brew-less machine
    detail: |
      cliproxy_conformance_spec.lua:22 overrides the data dir before :38 discovers, so only a PATH binary counts; the atlas claim "parley's download, or one on PATH" is false. 2nd finding in env-gated-coverage: the rule is that a gated check must be satisfiable by the environment the project itself produces — resolve BINARY from the real data root first, and report the gate as pending rather than a print.
  - id: new
    severity: Minor
    family: fake-rule-without-driver
    title: |
      fake_cliproxy's new 404 rule has no spec that posts the anthropic route through it; the unit pin is the only protection
  - id: new
    severity: Minor
    family: interleaving-seam
    title: |
      The status join is reproducible only with the latest leg slow; health/version legs have no delay seam in fake_cliproxy
    detail: |
      2nd finding in interleaving-seam. Rule: every async join gets a per-leg delay seam so each leg can be made to land last. Counter is symmetric, so coverage note only.
  - id: new
    severity: Minor
    family: binary-provenance-single-source
    title: |
      status re-walks discover_binary's precedence to label binary_source; return (path, source) from discover_binary instead
  - id: new
    severity: Minor
    family: spec-carries-discovered-scope
    title: |
      The claude /v1/messages route change is recorded in the Log and plan Revisions but not in the issue Spec or its Revisions
```

---

## Re-review — 2026-09-12T16:28:46-07:00 (unknown)

| field | value |
|-------|-------|
| issue | 237 — ParleyProxy update fetches the latest release unless pinned; status shows the version |
| repo | parley.nvim |
| issue file | workshop/issues/000237-proxy-update-latest.md |
| boundary | milestone M2 |
| milestone | M2 |
| window | 00dbd4365d60c19e9ca4231d3b1264a32ffd1d68..88d97dd518e8c21350541d1dc006d7959211d4aa |
| command | sdlc milestone-close --issue 237 --milestone M2 |
| reviewer | claude |
| timestamp | 2026-09-12T16:28:46-07:00 |
| verdict | unknown |

## Review

Nothing else is independent of the two background runs still going (revert checks and the full suite). Both notify on completion, so I'm waiting for those before writing the verdict.

---

## Re-review — 2026-09-12T17:24:57-07:00 (FIX-THEN-SHIP)

| field | value |
|-------|-------|
| issue | 237 — ParleyProxy update fetches the latest release unless pinned; status shows the version |
| repo | parley.nvim |
| issue file | workshop/issues/000237-proxy-update-latest.md |
| boundary | milestone M2 |
| milestone | M2 |
| window | 00dbd4365d60c19e9ca4231d3b1264a32ffd1d68..88d97dd518e8c21350541d1dc006d7959211d4aa |
| command | sdlc milestone-close --issue 237 --milestone M2 |
| reviewer | claude |
| timestamp | 2026-09-12T17:24:57-07:00 |
| verdict | FIX-THEN-SHIP |

## Review

```verdict
verdict: FIX-THEN-SHIP
confidence: high
```

Round 2 of the M2 gate. The blocking finding from round 1 is genuinely fixed: `version_probe` now sends parley's management key, the fake carries the real binary's failure counter, and reverting the key in a scratch worktree turns the lockout case red (update spec 39/1). I re-measured the installed 7.2.159 against a throwaway config and it behaves exactly as the fake now models it (keyed 200; five unauthenticated 401s; then 403 with `{"error":"IP banned due to too many failed attempts. Try again in 30m0s"}` on keyed and wrong-key requests alike, header still present). Conformance runs 10/2 against that binary with the two failures being the pre-existing #205 catalog cases the Log already names; without a binary every real-binary case reports why it is pending. `make test` exits 2 only on `fold_invariants_spec`, which reads the operator's uncommitted deletion of `workshop/parley/2026-09-10.11-10-24.522.md` (outside this window; lint 0/0 in 372 files). What keeps this from SHIP is one claimed fix that does not do what it says: the new recovery-e2e case, offered as the HTTP driver for the fake's 404 rule, posts to `/v1/chat/completions` (I logged the fake's POST paths: seven requests, all on the OpenAI route), so it stays green with the route fix reverted. Minor, cheap, and the fix is a one-liner.

## Strengths

- `lua/parley/cliproxy.lua:208-216` — the keyed probe reuses `api_argv` and `management_key()` exactly as `auth_files` does; no new credential path, and the confirming probe after an update restart no longer spends an attempt either.
- `tests/fixtures/fake_cliproxy:278-327` — `_mgmt_gate` is one seam for both management routes, and the counter is per process like the real binary's; the lockout spec (`cliproxy_update_spec.lua:654-704`) pins both the no-failure path and the ban message in the proxy's own words.
- `tests/integration/cliproxy_conformance_spec.lua:386-407` pins the lockout on the real binary, so the fake's new state model has a live check. Confirmed against 7.2.159 today.
- `lua/parley/cliproxy.lua:388-396` — the 403 body reaches the operator; "HTTP 403" alone would have sent them to the logs.
- `discover_binary` returning `(path, source)` (`cliproxy.lua:83-104`) removed the duplicated precedence walk cleanly; lifecycle 53/0 and download 6/0 confirm the extra return value breaks no caller.
- `workshop/lessons.md` 6 and 7 name the classes (a fake that answers every path; a fake that does not keep the dependency's state), not the incidents.

## Critical findings

None.

## Important findings

None.

## Minor findings

- **BR-16 not addressed.** `tests/integration/cliproxy_recovery_e2e_spec.lua:121-130` sets `web_search_strategy` on the provider, but `dispatcher.query` takes a raw payload and never calls `format_payload`, which is where `_parley_route = "anthropic"` is stamped (`providers.lua:1129`). The request goes out on `/v1/chat/completions`, so the fake's 404 rule is still unexercised over HTTP. Fix: put `_parley_route = "anthropic"` on the payload `query()` passes (`format_headers` reads and strips it), then the case answers 503 on `/v1/messages` and 404 with the old alias. Verify by reverting `providers.lua` and watching it go red, which today it does not.
- **Conformance pins the ban's status but not the field parley parses.** `auth_files` now reads `payload.error` from a non-200 body; the lockout case asserts only `"403"`. Add `assert.equals("IP banned…", vim.json.decode(body).error)` style check, the same rule `REQUIRED_FIELDS` applies to auth-files. New family `conformance-pins-parsed-fields`.
- **Core-concepts rows lag the diff.** This is the 3rd finding in `plan-checkbox-tracking`. Rule: every entity the diff modifies gets its table row amended in the same commit, because the arch sweep only fires on definition-line changes. Sites: the `tests/fixtures/fake_cliproxy` row (plan line 287) omits the lockout counter, the POST 404 rule and `PARLEY_FAKE_GET_DELAY_MS`; `auth_files` has no `modified` row although its message contract changed.
- `atlas/providers/cliproxy-managed.md:484` now says conformance downloads under `PARLEY_LIVE_GITHUB=1`, which is correct, but the milestone-close routine in the plan's Test surface still says "runs whenever a binary is discoverable"; the close should run with that flag set on this brew-less machine.

## Test coverage notes

- Run at head: dispatcher 65/0, command 17/0, recovery_e2e 6/0, update 40/0 (none pending), lifecycle 53/0, download 6/0, conformance 10/2 with 7.2.159 on PATH, arch sweeps green apart from the XDG cases my direct invocation cannot satisfy (they pass under `make test`).
- Revert checks: keyed probe removed → update 39/1 (lockout case red). Route fix removed → dispatcher 64/1 (unit pin red), recovery_e2e 6/0 (the claimed driver stays green; BR-16 above).
- `make test`: one failure, `fold_invariants_spec`, caused by the operator's uncommitted chat deletion, not the window.

## Architectural notes

- ARCH-DRY: pass. One key source, one gate in the fake, one precedence walk.
- ARCH-PURE: pass. `status` stays glue; the new logic is a counter and a JSON field read at the IO seam.
- ARCH-PURPOSE: pass on the fix's class (both management routes share the gate; both probe sites are keyed). Flag on BR-16: the site was answered with a test that does not reach it.
- ARCH-MOCK: pass. The fake now counts, conformance pins the counter and the header on 200 and 401, and I reproduced the fake's model on the real binary.
- ARCH-CONSTRAINTS: pass. The envelope gained the failed-attempt budget row with a measured basis.
- ARCH-SECURE: pass. `render_opts` already minted the key before `status` reached the probe, so no new secret is created as a side effect; the key goes only to the loopback port the client bearer already reaches. The foreign-proxy cost (one attempt per status) is documented in the atlas, and the ladder branches only on `no_management_route`, so a 403 there changes nothing.
- ARCH-ORDER: pass. `PARLEY_FAKE_GET_DELAY_MS` gives the join its third ordering; the two ordering cases assert exactly one callback.

## Plan revision recommendations

1. `## Revisions` — "M2 review round 2": BR-16 re-opened; the recovery case must stamp `_parley_route` on the payload it hands `dispatcher.query`, and its revert check recorded.
2. Same entry: amend the `fake_cliproxy` row (lockout counter, POST 404 rule, GET delay seam) and add an `auth_files | modified | carries the proxy's error body on non-200` row; add the body-field pin to the Test surface.

```findings
dispose:
  - id: BR-14
    disposition: addressed
    note: |
      Keyed probe pinned: reverting the key turns the lockout case red (39/1); re-measured on 7.2.159 today, the fake's counter and ban body match the real binary.
  - id: BR-15
    disposition: addressed
    note: |
      Every real-binary case now reports the reason it is pending, and PARLEY_LIVE_GITHUB=1 installs the latest release through parley's own download; the milestone close on a brew-less machine must set that flag.
  - id: BR-16
    disposition: not-addressed
    note: |
      The recovery case posts to /v1/chat/completions (fake's POST log: 7 of 7); dispatcher.query never calls format_payload, so _parley_route is never "anthropic" and the case stays green with the route fix reverted.
  - id: BR-17
    disposition: addressed
    note: |
      PARLEY_FAKE_GET_DELAY_MS lands the proxy legs last; the case asserts a single callback with all three reads filled.
  - id: BR-18
    disposition: addressed
    note: |
      discover_binary returns (path, source); status reads it; lifecycle 53/0 and download 6/0 with the extra return value.
  - id: BR-19
    disposition: addressed
    note: |
      The issue's Revisions carry both the route change and the keyed probe.
findings:
  - id: new
    severity: Minor
    family: conformance-pins-parsed-fields
    title: |
      The conformance lockout case pins the 403 code but not the error body field auth_files now parses
    detail: |
      cliproxy.lua:388-396 reads payload.error from a non-200 management body; cliproxy_conformance_spec.lua:386-407 asserts only "403". Pin the field the way REQUIRED_FIELDS pins auth-files, so drift in the ban body is caught live rather than by an operator reading "HTTP 403".
  - id: new
    severity: Minor
    family: plan-checkbox-tracking
    title: |
      Core-concepts rows lag the diff: the fake_cliproxy row omits the lockout counter, the POST 404 rule and the GET delay seam, and auth_files has no modified row
    detail: |
      3rd finding in this family. Rule: every entity the diff modifies gets its table row amended in the same commit; the arch sweep fires only on definition-line changes, so a contract change inside a function (auth_files' message) or inside a fixture never trips it. Sweep the fake's row (plan line 287) and add the auth_files row.
```
