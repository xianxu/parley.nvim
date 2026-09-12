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
