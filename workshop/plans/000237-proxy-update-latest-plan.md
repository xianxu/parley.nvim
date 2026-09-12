# #237 ParleyProxy update installs the latest release — Implementation Plan

> **For agentic workers:** Consult AGENTS.md Section 3 (Subagent Strategy) to determine the appropriate execution approach: use superpowers-subagent-driven-development (if subagents are suitable per AGENTS.md) or superpowers-executing-plans to implement this plan. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** `:ParleyProxy update` installs the newest CLIProxyAPI release, or
`cliproxy.download_version` when set, swaps the binary in safely and restarts
the proxy when parley launched it; `:ParleyProxy status` shows the running
version against the latest.

**Architecture:** A new pure module, `lua/parley/cliproxy_release.lua`, owns
every decision: version parsing and comparison, the GitHub-redirect and
response-header parsers, the update decision table, and the status version
text. `lua/parley/cliproxy.lua` gains only thin IO around it: resolve the target
release, probe the running proxy's version, install a version atomically, and
orchestrate `update` and `status`. `init.lua` stays glue. A stateful fake of
GitHub's release endpoints backs the integration tests; the real binary and the
real redirect are checked by conformance specs.

**Tech Stack:** Lua on Neovim 0.10+ (`vim.system`, `vim.uv`), curl, tar,
`shasum`/`sha256sum`, plenary busted; Python 3 test fixtures.

---

## Facts this plan rests on (verified 2026-09-11)

- `M.update()` is `return M.download()` (`cliproxy.lua:1850-1852`); `download`
  picks `opts.version or c.download_version or PINNED_VERSION` (`:1797`) and
  `PINNED_VERSION = "7.1.71"` (`:1762`).
- The 7.1.71 binary embeds `claude-cli/2.1.63 (external, cli)`; Anthropic
  answers Fable requests with HTTP 400 "Claude Code 2.1.63 does not support this
  model; version 2.1.251 or newer is required". CLIProxyAPI v7.2.149 moved to
  Claude Code 2.1.258; the v7.2.158 binary carries `claude-cli/2.1.258`.
- `https://github.com/router-for-me/CLIProxyAPI/releases/latest` answers 302 to
  `…/releases/tag/v7.2.158`; `curl -o /dev/null -w '%{redirect_url}'` prints it
  without following. No API token, no rate-limit quota.
- A live 7.1.71 proxy stamps `X-Cpa-Version: 7.1.71` (and `X-Cpa-Commit`,
  `X-Cpa-Build-Date`, `X-Cpa-Support-Plugin`) on every `/v0/management/*`
  response — 200, 404, and the 401 an unauthenticated request gets. `/` and
  `/v1/models` carry no such header. The 7.2.158 binary's strings contain
  `X-CPA-VERSION` too.
- The management route `latest-version` returns `{"latest-version":"v7.2.158"}`
  with the management key. Not used (see decision 2).
- `api_argv` (`cliproxy.lua:146-154`) builds every probe's curl argv with
  `-w "\n%{http_code}"` and no `-D`, so no caller sees headers today.
- `:ParleyProxy restart` calls `M.restart` (`:800-803`: `stop()` then
  `ensure_running`, no wait). `M.restart_managed` (`:424-430`) waits for the port
  (`wait_port_released`, 2 s). `M.restart` has one caller, `init.lua:383`; the
  credential repair (`:482`) and recovery ladder (`:1408`) already use
  `restart_managed`.
- `M.status` reports a managed-dir binary as `"PATH"` (`:834`).
- `download()` blocks the main loop (`vim.system(...):wait()`, up to 300 s +
  30 s). auto_download calls it inside `ensure_running` (`:719-728`), and
  `tar -xzf … -C bin_dir` writes over the live binary path in place.
- `ca.parse_peers` (`cliproxy_auth.lua:356-386`) parses
  `ps ax -o pid,lstart,command` and matches on the executable token, never a
  substring (the #197 `zsh -c` lesson).
- `tests/minimal_init.vim:28` exports `$PARLEY_TEST_MODE`; plenary's child nvims
  inherit the environment, not `g:` variables (#227).

## Design decisions

1. **One target rule.** `update` and first-run auto_download both install
   `cliproxy.download_version` when set, else the latest release. The built-in
   `PINNED_VERSION` is deleted: a pin in code is what locked users out, and a
   silent fallback to it would bring the stale version back. If the latest
   cannot be resolved, fail and suggest `download_version`
   (`ARCH-PURPOSE`: a new user's first install must reach current models too).
2. **"Latest" comes from GitHub's redirect, fetched by parley**, for `update` and
   `status` alike (`ARCH-DRY`: one source). It works with the proxy down and
   needs no key. The proxy's `latest-version` route needs the management key and
   answers 401 on a proxy parley did not launch. `status` skips the read when
   `cliproxy.manage` is off, so an opted-out install makes no request on
   parley's behalf (PQ-2).
3. **Running version = `X-Cpa-Version`** from an unauthenticated GET to
   `/v0/management/latest-version`, body discarded. The header rides on the 401,
   so no credential leaves parley (`ARCH-SECURE`).
4. **Parley's proxy = launched with parley's rendered config.** The process
   listening on the managed port is "ours" when its command line carries
   `-config <parley's config.yaml>` as a whole token, from this nvim session or
   an earlier one. Ours → `restart_managed`. Anything else (a brew service,
   another tool) is left running and the message says how to replace it:
   killing a launchd-managed service only respawns it into a port fight. Only
   the listener's row is examined, so a shell that merely mentions the path can
   never match. An executable-path rule was rejected: it misses a parley launch
   that used a brew binary, and a script-based test fake shows `python3` as its
   executable.
5. **Atomic install.** Extract into `<data root>/staging`, `fs_rename` over the
   binary, then write `cli-proxy-api.version` (write-then-rename). A running
   proxy keeps its old inode; an interrupted install leaves the previous binary.
   A missing or garbled record reads as unknown, and the next update reinstalls.
6. **Refusals.** `manage = false` (parley does not run the proxy), `binary_path`
   set (parley runs that binary, so installing its own changes nothing), and an
   invalid `download_version` each refuse with the reason and what to do.
7. **`:ParleyProxy restart` goes through `restart_managed`**, and `M.restart` is
   deleted. The update restart and the manual restart share the one sequence
   that waits for the port (`ARCH-DRY`); without it the documented workaround
   ("update, then restart") can reuse a proxy that is still shutting down.
8. **Status shows** `version: 7.1.71 (latest 7.2.158 — run :ParleyProxy update)`,
   `7.2.158 (latest)`, `… (pinned to X; latest Y)`, `not running (installed X;
   latest Y)`, `unknown — the proxy sent no version header`, and `latest
   unknown: <reason>` when GitHub cannot be reached. The binary source reports
   `managed` correctly.

## Non-goals

- Making `download()` asynchronous. It still blocks the editor while fetching,
  bounded by curl's timeouts. The operator accepted the blocking fetch on
  2026-09-11 when approving this plan. The audit's B5 (unprompted download on
  the main loop) belongs to #209, which owns the auto_download default.
- Changing `stop()`, which reaps any cliproxy on the managed port.
- Using the proxy's `latest-version` management route.
- Windows auto-download (unchanged).
- Background or periodic update checks; both commands are user-invoked.

## Operating envelope (ARCH-CONSTRAINTS)

| Path | Workload | Budget | Basis | When exceeded |
|---|---|---|---|---|
| `update`: resolve latest | user command, one-shot | curl `--connect-timeout 5 --max-time 10` | operator choice | fails "could not find the latest cliproxyapi release"; nothing changed |
| `update`: install | one-shot | tarball ≤300 s, checksums ≤30 s, **synchronous — the editor blocks** | existing `download` | curl error; nothing installed |
| `update`: running identity | one-shot | `ps ax` + `lsof`, synchronous, ~80-150 ms | measured for `peers()` (`cliproxy.lua:696-699`) | read failure → "not ours" (never restart on doubt) |
| `update`: restart | one-shot | `PORT_RELEASE_MS` 2 s + `POLL_BUDGET_MS` 5 s + probes | existing `restart_managed` | error message; the new binary stays installed |
| `status` | user command | health and version probes `CURL_MAX_TIME` 2 s, latest `--max-time 5`, all three async and in parallel; one notify when the last lands; the UI never blocks | operator choice | that slot shows unknown with the reason |
| first-run auto_download | first dispatch with no binary | +1 synchronous resolve (≤10 s) before the existing synchronous download | existing path | existing `on_error` |
| disk | install | one staged copy of the binary (~60 MB) under the data root, removed after the rename | measured (7.2.158: 60,244,866 B) | error before the rename removes staging |
| network | per `update` / `status` | one GitHub HTTPS request, no API quota | — | — |

N/A: memory and CPU (trivial); keystroke and dispatch paths (untouched except
first-run auto_download above).

## Trust boundaries (ARCH-SECURE)

- **GitHub redirect URL** (untrusted): `parse_latest_response` returns a strict
  `X.Y.Z` or nil. Download URLs are built only from a parsed version, never from
  the raw redirect, so a hostile redirect cannot inject path segments.
- **`X-Cpa-Version` header** (untrusted): strict parse, else "unknown".
- **`cli-proxy-api.version` record** (persisted; may be missing, truncated,
  hand-edited, or from an older parley): strict parse, else unknown → the next
  update reinstalls.
- **`download_version`** (user config): strict parse; an invalid value refuses,
  naming the value.
- **`checksums.txt` and the tarball**: the existing sha256 check runs before
  extraction; only the `cli-proxy-api` member is extracted, into staging.
- **`ps` and `lsof` output**: parsed by the existing grammar (`cliproxy_auth`),
  never logged; only the listener's row is used. A read that fails, or a
  listener missing from the table, means "could not tell": update never
  restarts it and says so, naming the reason (BR-8).
- **Credentials**: the version probe sends none. The management key and client
  bearer are untouched; no new secret-bearing process argument is added.
- **Destructive calls**: `vim.fn.delete(stage, "rf")` removes only
  `<data root>/staging`, a leaf `download` constructs; the data root is never
  empty (stdpath or the test override).
- **Tests**: `_set_data_dir` and `_set_releases_url` keep specs off the real
  data dir and off GitHub. `tests/minimal_init.vim` points
  `$PARLEY_CLIPROXY_RELEASES_URL` at a dead local port, so a spec that forgets
  the seam fails fast instead of reaching github.com; parley reads that
  variable only when `$PARLEY_TEST_MODE` is `1`, so outside the harness it
  cannot redirect a download. The live GitHub check is
  opt-in (`PARLEY_LIVE_GITHUB=1`). Specs keep the restricted PATH so no real
  brew binary is spawned (#197). Every process a spec starts has an owner that
  outlives its assertions — see Process ownership.

## State and ordering (ARCH-ORDER)

`update` carries durable state (the installed binary and its version record)
across external events:

| State | Event | Next / effects |
|---|---|---|
| idle | `:ParleyProxy update` | refusal check, then resolving |
| resolving / installing / restarting | second `update` | refused: "an update is already running" (module-local guard, cleared on every terminal path) |
| resolving | target unresolved or plan refuses | idle; message; nothing changed |
| resolving | plan says install | installing |
| resolving | plan says no install, restart | restarting |
| installing | curl, checksum or tar fails | idle; error; staging removed; old binary and record intact |
| installing | nvim dies mid-download | only temp files (tempname); old binary intact |
| installing | dies between rename and record | new binary, stale record → the next update reinstalls (idempotent) |
| installed | listener is ours | restarting (`restart_managed`) |
| installed | listener not ours | idle; the message says it still runs the old version and how to replace it |
| installed | listener identity unknown (`ps`/`lsof` unreadable, or the listener not in the table) | idle; warn "could not tell whether parley started the proxy on port P (why), so it was left running (…); if parley started it, :ParleyProxy restart replaces it" |
| installed | nothing listening | idle; the message names the versions — the next request starts the new binary, so nothing more is said (PQ-4) |
| restarting | old proxy slow to exit | `restart_managed` waits ≤2 s for the port; a cliproxyapi still answering is reported ("…; the restart failed — the old proxy on port P still answers 2 s after…"), never reused |
| restarting | `ensure_running` fails | idle; error "…; the restart failed — …" |
| restarting | `ensure_running` answers | one `version_probe`: the target → "…; now serving T"; another version → warn "…; the proxy still reports V, so the old process has not exited"; no version → warn "…; could not confirm what it now serves (why)" |
| restarting | no answer at all (a raise inside an async leg) | idle after `UPDATE_RESTART_DEADLINE_MS` (20 s, above `restart_managed`'s ~13 s budget plus the 2 s confirming probe); error "…; the restart did not answer"; `finish` drops the late answer (PQ-3) |
| any | unexpected Lua error | idle; bounded error; details to the log (pcall boundary around the whole sequence) |

The event most likely to be mishandled is restarting before the old proxy
releases the port, which reuses the dying process. `restart_managed` handles it,
and `:ParleyProxy restart` now uses it too. Since BR-8 it reports a cliproxyapi
still answering when its wait ends, and the fake's `PARLEY_FAKE_EXIT_DELAY_MS`
reproduces that interleaving.

`status` holds no state between events, because each call builds a fresh `info`
and answers once. Its three reads (health, version, latest) complete in IO
order; a counter fires the single callback when the last lands. The ordering is
reproduced in tests with the release fake's `slow` mode.

Extent: nothing outlives a call except the proxy that `restart_managed` spawns,
which the existing `_spawned` table owns.

## Core concepts

### Pure entities

| Name | Lives in | Status |
|------|----------|--------|
| `parse_version` | `lua/parley/cliproxy_release.lua` | new |
| `compare_versions` | `lua/parley/cliproxy_release.lua` | new |
| `parse_latest_response` | `lua/parley/cliproxy_release.lua` | new |
| `parse_version_probe` | `lua/parley/cliproxy_release.lua` | new |
| `running_identity` | `lua/parley/cliproxy_release.lua` | new |
| `update_refusal` | `lua/parley/cliproxy_release.lua` | new |
| `plan_update` | `lua/parley/cliproxy_release.lua` | new |
| `restart_outcome` | `lua/parley/cliproxy_release.lua` | new |
| `version_summary` | `lua/parley/cliproxy_release.lua` | new |
| `parse_ps` | `lua/parley/cliproxy_auth.lua` | new (extracted from `parse_peers`) |
| `parse_peers` | `lua/parley/cliproxy_auth.lua` | modified (consumes `parse_ps`) |

- **`parse_version`** — normalizes `"7.2.158"`/`"v7.2.158"` to `"7.2.158"`,
  digits kept as published (they become the tag in a URL); anything else → nil.
  - **Relationships:** consumed by every other parser here and by
    `cliproxy.resolve_target`/`download`/`installed_version`.
  - **DRY rationale:** one version grammar; the redirect, the header, the
    record and the config all pass through it.
  - **Future extensions:** prerelease tags would widen the grammar here only.
- **`compare_versions`** — numeric `-1/0/1` on parsed versions; raises on an
  unparsed value (a programming error, not user input).
- **`parse_latest_response`** — curl result of the redirect request →
  `version, err`.
- **`parse_version_probe`** — curl result of the header probe →
  `version, reason` (`"down"` | `"no_header"`).
- **`running_identity`** — `parse_ps` rows + listener pids + parley's config path
  → `{ ours, exe }` or nil when nothing listens.
  - **Relationships:** 1 listener : 1 identity; the IO side (`port_identity`)
    supplies all three inputs.
- **`update_refusal`** — `{ managed, binary_path }` → reason or nil. Checked
  before any network call.
- **`plan_update`** — the update decision table: `{ target, target_err, pinned,
  installed, running }` → `{ ok, install?, restart?, target?, message }`.
  - **DRY rationale:** the only place that decides install/restart and words the
    outcome; `update` executes it.
  - **Future extensions:** #213's honest `:checkhealth` can report "proxy behind
    latest" from `version_summary`, not a second comparison.
- **`version_summary`** — the status `version:` text.
- **`parse_ps`** — `ps ax -o pid,lstart,command` → rows `{ pid, started,
  command, exe }`; the executable is the first token. `parse_peers` filters
  these rows; `running_identity` reads them.
  - **DRY rationale:** `cliproxy_auth` owns the ps grammar (lesson #189: export
    the smallest pure parser from the format owner); no second parser.

### Integration points

| Name | Lives in | Status | Wraps |
|------|----------|--------|-------|
| `api_argv` | `lua/parley/cliproxy.lua` | modified | curl argv (optional header dump) |
| `run` | `lua/parley/cliproxy.lua` | new | `vim.system` sync/async |
| `version_probe` | `lua/parley/cliproxy.lua` | new | curl → proxy `/v0/management/latest-version` headers |
| `ps_output` | `lua/parley/cliproxy.lua` | new (extracted from `M.peers`) | `ps ax -o pid,lstart,command` |
| `port_identity` | `lua/parley/cliproxy.lua` | new | `ps_output` + `pids_on_port` |
| `pids_on_port` | `lua/parley/cliproxy.lua` | modified | `lsof`, guarded; returns why it cannot answer |
| `_set_process_tools` | `lua/parley/cliproxy.lua` | new | test seam (the ps and lsof executables) |
| `is_cliproxy_state` | `lua/parley/cliproxy.lua` | new | the health states that mean a cliproxyapi answers |
| `port_holds_cliproxy` | `lua/parley/cliproxy.lua` | modified | reads through `is_cliproxy_state` |
| `wait_port_released` | `lua/parley/cliproxy.lua` | modified | passes the last health state |
| `restart_managed` | `lua/parley/cliproxy.lua` | modified | reports a cliproxyapi that outlives the port wait |
| `peers` | `lua/parley/cliproxy.lua` | modified | reads through `ps_output` |
| `_set_releases_url` | `lua/parley/cliproxy.lua` | new | test seam (releases root) |
| `_releases_url` | `lua/parley/cliproxy.lua` | new | test accessor: the releases root in force |
| `latest_release` | `lua/parley/cliproxy.lua` | new | curl → GitHub `releases/latest` |
| `resolve_target` | `lua/parley/cliproxy.lua` | new | config pin + `latest_release` |
| `installed_version` | `lua/parley/cliproxy.lua` | new | the version record file |
| `download` | `lua/parley/cliproxy.lua` | modified | curl + sha256 + tar + `uv.fs_rename` |
| `update` | `lua/parley/cliproxy.lua` | modified | orchestration |
| `status` | `lua/parley/cliproxy.lua` | modified | orchestration |
| `ensure_running` | `lua/parley/cliproxy.lua` | modified | first-run auto_download target |
| `M.restart` | `lua/parley/cliproxy.lua` | deleted | — |
| `register_proxy_command` | `lua/parley/init.lua` | modified | `:ParleyProxy` glue |
| `tests/fixtures/fake_github_releases` | `tests/fixtures/fake_github_releases` | new | GitHub release endpoints |
| `tests/fixtures/fake_cliproxy` | `tests/fixtures/fake_cliproxy` | modified | + `X-CPA-*` headers, `latest-version` route, an exit delay after SIGTERM |
| `fake_releases` | `tests/helpers/fake_releases.lua` | new | builds releases, runs the release fake |
| `settle` | `tests/helpers/await.lua` | new | waits for an async call; returns settled, result |
| `await` | `tests/helpers/await.lua` | new | the same, failing the spec on timeout |
| `tests/fixtures/fixture_watchdog.py` | `tests/fixtures/fixture_watchdog.py` | new | parent-death exit for the Python fixtures |
| `tests/fixtures/fake_ps` | `tests/fixtures/fake_ps` | new | prints the `ps` rows a spec gives it, where the real `ps` is refused |
| `_set_update_restart_deadline_ms` | `lua/parley/cliproxy.lua` | new | test seam (update's restart deadline) |

- **`M.latest_release` / `M.version_probe`** — sync when called without a
  callback (for `update` and first-run), async with one (for `status`); both go
  through `run` and a pure parser.
  - **Injected into:** `plan_update` receives their results as plain values.
- **`fake_github_releases`** — stateful: its state is a directory the spec owns
  (`latest` pointer, `v<ver>/` assets, `requests.log`); the spec publishes
  releases mid-test and reads the request log to prove what was fetched.
- **`fake_cliproxy`** — models the real binary's `X-CPA-*` stamp on
  `/v0/management/*`; a published fake release execs it with
  `PARLEY_FAKE_CPA_VERSION`, so "which release is running" is observable
  through the same header parley reads from the real binary.

## Test surface (ARCH-MOCK)

- Pure: `tests/unit/cliproxy_release_spec.lua` (new), `parse_ps` cases in
  `tests/unit/cliproxy_auth_spec.lua`.
- Integration against the fakes: `tests/integration/cliproxy_update_spec.lua`
  (new), `tests/integration/cliproxy_download_spec.lua` (migrated),
  `tests/integration/cliproxy_lifecycle_spec.lua` (auto_download cases),
  `tests/integration/cliproxy_command_spec.lua` (update/restart/status glue).
- Live conformance: `tests/integration/cliproxy_conformance_spec.lua` — the real
  binary's header with management on and off (runs whenever a binary is
  discoverable, pending otherwise), and the real redirect behind
  `PARLEY_LIVE_GITHUB=1`, run at each milestone close.

## Process ownership (PQ-1: fixture-process-leak)

#220 measured what an unowned fixture costs on this machine: hundreds of
`fake_cliproxy` orphaned to init, ~10 GB resident. The class is every process a
spec starts, and each needs an owner for both ways a spec ends early: a failing
assertion, and a crashed or killed nvim — the case #220 found dominant (killed
review agents). The enumeration for this plan:

| Process | Started by | Owner on a failing assertion | Owner on a crash or kill |
|---|---|---|---|
| release fake (`fake_github_releases`), shared | file scope of the update and download specs | lives for the file | `fixture_watchdog` (exits with its nvim); `VimLeavePre` as a backstop |
| release fake (`fake_github_releases`), `slow` | the status-ordering case (`start_server`) | `after_each` → `reap()` | `fixture_watchdog` |
| proxy fake (`fake_cliproxy`), direct | the `version_probe` cases and the foreign-proxy case (`spawn_fake`) | `after_each` → `reap()` | `fixture_watchdog` (`PARLEY_FAKE_EXIT_WITH_PARENT=1`) |
| managed proxy (a published release → `fake_cliproxy`) | `ensure_running`/`restart_managed` in the update, status and first-run cases | `after_each` → `cliproxy.stop()` | `fixture_watchdog` (the release wrapper exports `PARLEY_FAKE_EXIT_WITH_PARENT=1`) |
| real `cliproxyapi` | conformance `boot()` | the spec's existing `after_each` | unchanged; #220's suite-level sweep |

Rules every task follows: no `kill` as the last line of an `it` body; every
handle is asserted (`fixture_process.spawn` returns `handle, exited, err`, and a
nil handle would make `kill` raise rather than report); every describe that
starts a process has an `after_each` that reaps it. The watchdog is opt-in for
`fake_cliproxy` because other specs share that fixture; #220 owns making it the
default, alongside its suite-level sweep and exit-time survivor count.

An owner only owns what exists when it runs, so the rule is also temporal
(PQ-5): **an `it` body must not return while an async leg it started can still
spawn** — it awaits the callback, or keeps the spawner stubbed for the whole
body. The cases with such a leg, and how each holds the rule:

| Case | Async leg that can spawn | How it holds |
|---|---|---|
| `start_managed` (update and status cases) | `ensure_running` | `await` |
| restarts parley's own proxy | `update` → `restart_managed` | `await`, via `update()` |
| refuses a second update | the first update's `restart_managed` | waits for the first update before any assertion |
| restart-deadline case | `restart_managed` | stubbed for the whole body; restored only after both calls |
| an old proxy outlives the restart | `update` → `restart_managed`, which errors before `ensure_running` | `await`, via `update()`; the old proxy exits on its own 4 s after SIGTERM, and its watchdog covers a crash |
| first-run auto_download | `ensure_running` → download → spawn | `await`, via `ensure()` |

`await` gives up after 25 s, above `UPDATE_RESTART_DEADLINE_MS` (20 s) and
`restart_managed`'s ~13 s worst case, so it cannot return while the leg it waits
on is still bound to answer.

## Running tests

- One spec (TDD loop):
  `nvim -n --headless --noplugin -u tests/minimal_init.vim -c "PlenaryBustedFile <spec>" -c "qa!"`
- The mapped group: `make test-spec SPEC=providers/cliproxy-managed`
- Lint: `make lint`
- The gate (lint + every spec): `make test`. A green single spec is not
  evidence for a close (#160).

Commit subjects use `#237 M1: …` / `#237 M2: …`. Stage explicit paths only
(#157) and append the session's `Co-Authored-By` and `Claude-Session` trailers.

---

## Chunk 1: M1 — update installs the latest (or pinned) release safely

### Task 1: Versions and response parsers

**Files:**
- Create: `lua/parley/cliproxy_release.lua`
- Create: `tests/unit/cliproxy_release_spec.lua`

- [x] **Step 1: Write the failing tests**

```lua
-- Unit tests for lua/parley/cliproxy_release.lua (#237). Pure: no IO, no mocks.
local rel = require("parley.cliproxy_release")

describe("parse_version", function()
    it("accepts X.Y.Z with or without a leading v, trimming whitespace", function()
        assert.equals("7.2.158", rel.parse_version("7.2.158"))
        assert.equals("7.2.158", rel.parse_version("v7.2.158"))
        assert.equals("7.2.158", rel.parse_version(" v7.2.158\n"))
    end)

    it("keeps the digits exactly as published — they name the release tag", function()
        assert.equals("7.01.1", rel.parse_version("v7.01.1"))
    end)

    it("rejects everything that is not three numeric components", function()
        for _, s in ipairs({ "", "v", "7.2", "7.2.158-rc1", "7.2.x", "1.2.3.4", "latest", "v 7.2.158" }) do
            assert.is_nil(rel.parse_version(s), ("accepted %q"):format(s))
        end
        assert.is_nil(rel.parse_version(nil))
        assert.is_nil(rel.parse_version(7))
        assert.is_nil(rel.parse_version({}))
    end)
end)

describe("compare_versions", function()
    it("compares numerically, not as strings", function()
        assert.equals(1, rel.compare_versions("7.2.10", "7.2.9"))
        assert.equals(1, rel.compare_versions("7.10.0", "7.9.99"))
        assert.equals(-1, rel.compare_versions("7.1.71", "7.2.158"))
        assert.equals(0, rel.compare_versions("7.2.158", "7.2.158"))
    end)

    it("raises on a value that was never parsed", function()
        assert.has_error(function()
            rel.compare_versions("latest", "7.2.158")
        end)
    end)
end)

describe("parse_latest_response", function()
    it("reads the version from GitHub's redirect", function()
        local v, err = rel.parse_latest_response({ code = 0,
            stdout = "https://github.com/router-for-me/CLIProxyAPI/releases/tag/v7.2.158\n302" })
        assert.equals("7.2.158", v)
        assert.is_nil(err)
    end)

    it("reports the HTTP status when there is no redirect", function()
        local v, err = rel.parse_latest_response({ code = 0, stdout = "\n404" })
        assert.is_nil(v)
        assert.equals("no release in the redirect (HTTP 404)", err)
    end)

    it("rejects a redirect that is not to a release tag", function()
        assert.is_nil((rel.parse_latest_response({ code = 0, stdout = "https://github.com/login\n302" })))
        assert.is_nil((rel.parse_latest_response({ code = 0,
            stdout = "https://github.com/x/y/releases/tag/nightly\n302" })))
    end)

    it("reports curl's own error when the request failed", function()
        local v, err = rel.parse_latest_response({ code = 7, stdout = "",
            stderr = "curl: (7) Failed to connect to github.com port 443\n" })
        assert.is_nil(v)
        assert.equals("unreachable: curl: (7) Failed to connect to github.com port 443", err)
    end)
end)

describe("parse_version_probe", function()
    -- The shape captured from a live 7.1.71 on 2026-09-11:
    -- curl -s -w "\n%{http_code}" -D - -o /dev/null …/v0/management/latest-version
    -- with no credential.
    local CAPTURED = table.concat({
        "HTTP/1.1 401 Unauthorized",
        "Content-Type: application/json; charset=utf-8",
        "X-Cpa-Build-Date: 2026-06-12T19:59:09Z",
        "X-Cpa-Commit: b6c22f2d",
        "X-Cpa-Support-Plugin: 1",
        "X-Cpa-Version: 7.1.71",
        "Content-Length: 34",
        "",
        "",
    }, "\r\n") .. "\n401"

    it("reads X-Cpa-Version from an unauthenticated request's headers", function()
        local v, reason = rel.parse_version_probe({ code = 0, stdout = CAPTURED })
        assert.equals("7.1.71", v)
        assert.is_nil(reason)
    end)

    it("matches the header name case-insensitively", function()
        local v = rel.parse_version_probe({ code = 0,
            stdout = "HTTP/1.1 200 OK\r\nx-cpa-version: 7.2.158\r\n\r\n\n200" })
        assert.equals("7.2.158", v)
    end)

    it("says no_header when the proxy answered without a usable version", function()
        assert.same({ nil, "no_header" },
            { rel.parse_version_probe({ code = 0, stdout = "HTTP/1.1 404 Not Found\r\n\r\n\n404" }) })
        assert.same({ nil, "no_header" },
            { rel.parse_version_probe({ code = 0, stdout = "HTTP/1.1 200 OK\r\nX-Cpa-Version: dev\r\n\r\n\n200" }) })
    end)

    it("says down when curl could not connect", function()
        assert.same({ nil, "down" }, { rel.parse_version_probe({ code = 7, stdout = "" }) })
    end)
end)
```

- [x] **Step 2: Run the tests to verify they fail**

Run: `nvim -n --headless --noplugin -u tests/minimal_init.vim -c "PlenaryBustedFile tests/unit/cliproxy_release_spec.lua" -c "qa!"`
Expected: FAIL — `module 'parley.cliproxy_release' not found`.

- [x] **Step 3: Write the module**

```lua
-- cliproxy_release.lua — pure release/version logic for the managed
-- cliproxyapi (#237).
--
-- No IO: every function takes values the caller already gathered (a curl
-- result table, `ps` rows, config), so the whole decision surface is
-- unit-tested without mocks (ARCH-PURE). cliproxy.lua owns the IO around it.
--
-- A version is "X.Y.Z" with no leading v, digits kept exactly as published —
-- they become the release tag in a download URL. Anything else (a prerelease
-- suffix, two components, stray text) is not a version: parsers return nil and
-- callers report "unknown" rather than guess (ARCH-SECURE).

local M = {}

--- Normalize a release version: "7.2.158" / "v7.2.158" -> "7.2.158"; else nil.
---@param s any
---@return string|nil
function M.parse_version(s)
    if type(s) ~= "string" then
        return nil
    end
    local a, b, c = vim.trim(s):match("^v?(%d+)%.(%d+)%.(%d+)$")
    if not a then
        return nil
    end
    return a .. "." .. b .. "." .. c
end

--- -1, 0 or 1, comparing two parsed versions numerically.
---@param a string
---@param b string
---@return integer
function M.compare_versions(a, b)
    local pa = { (a or ""):match("^(%d+)%.(%d+)%.(%d+)$") }
    local pb = { (b or ""):match("^(%d+)%.(%d+)%.(%d+)$") }
    assert(#pa == 3 and #pb == 3, "compare_versions: not a parsed version")
    for i = 1, 3 do
        local x, y = tonumber(pa[i]), tonumber(pb[i])
        if x ~= y then
            return x < y and -1 or 1
        end
    end
    return 0
end

-- Split curl's `-w "…\n%{http_code}"` tail off its stdout.
local function split_code(stdout)
    local head, code = (stdout or ""):match("^(.*)\n(%d+)%s*$")
    return head, code
end

--- The release GitHub's `releases/latest` redirect names. `obj` is the
--- vim.system result of `curl -o /dev/null -w "%{redirect_url}\n%{http_code}"`.
---@param obj table # { code, stdout, stderr }
---@return string|nil version, string|nil err
function M.parse_latest_response(obj)
    if obj.code ~= 0 then
        return nil, "unreachable: " .. vim.trim(obj.stderr or "")
    end
    local url, code = split_code(obj.stdout)
    local tag = vim.trim(url or ""):match("/releases/tag/([^/?#%s]+)$")
    local version = M.parse_version(tag)
    if not version then
        return nil, ("no release in the redirect (HTTP %s)"):format(tostring(code))
    end
    return version
end

--- The version a running proxy reports: X-Cpa-Version, which every
--- /v0/management/* response carries (captured live, 7.1.71). `obj` is the
--- vim.system result of `curl -D - -o /dev/null -w "\n%{http_code}"`.
---@param obj table # { code, stdout }
---@return string|nil version, string|nil reason # "down" | "no_header"
function M.parse_version_probe(obj)
    if obj.code ~= 0 then
        return nil, "down"
    end
    local headers = split_code(obj.stdout) or ""
    for line in headers:gmatch("[^\r\n]+") do
        local name, value = line:match("^([%w%-]+):%s*(.-)%s*$")
        if name and name:lower() == "x-cpa-version" then
            local v = M.parse_version(value)
            if v then
                return v
            end
            break
        end
    end
    return nil, "no_header"
end

return M
```

- [x] **Step 4: Run the tests to verify they pass**

Run: the Step 2 command. Expected: PASS, 0 failures. Then `make lint`: 0 warnings.

- [x] **Step 5: Commit**

```bash
git add lua/parley/cliproxy_release.lua tests/unit/cliproxy_release_spec.lua
git commit -m "#237 M1: pure version and response parsers for cliproxy releases"
```

### Task 2: `parse_ps` and `running_identity`

**Files:**
- Modify: `lua/parley/cliproxy_auth.lua` (`parse_peers`, around lines 356-386)
- Modify: `lua/parley/cliproxy_release.lua`
- Test: `tests/unit/cliproxy_auth_spec.lua`, `tests/unit/cliproxy_release_spec.lua`

- [x] **Step 1: Write the failing tests**

Append to `tests/unit/cliproxy_auth_spec.lua` (use the spec's existing
`cliproxy_auth` module local; it is `ca` if the file follows the module's
convention — check the top of the file):

```lua
describe("parse_ps", function()
    local PS = table.concat({
        "  PID STARTED                      COMMAND",
        "  101 Fri Sep 11 09:00:00 2026     /Users/me/.local/share/nvim/parley/cliproxy/bin/cli-proxy-api -config /x/config.yaml",
        "  202 Thu Sep 10 18:14:54 2026     /opt/homebrew/bin/cliproxyapi -config /opt/homebrew/etc/cliproxyapi.conf",
    }, "\n")

    it("reads pid, start time, full command and the executable token", function()
        local rows = ca.parse_ps(PS)
        assert.equals(2, #rows)
        assert.same({
            pid = 101,
            started = "Fri Sep 11 09:00:00 2026",
            command = "/Users/me/.local/share/nvim/parley/cliproxy/bin/cli-proxy-api -config /x/config.yaml",
            exe = "/Users/me/.local/share/nvim/parley/cliproxy/bin/cli-proxy-api",
        }, rows[1])
        assert.equals("/opt/homebrew/bin/cliproxyapi", rows[2].exe)
    end)

    it("skips the header and malformed lines, and tolerates non-strings", function()
        assert.same({}, ca.parse_ps(nil))
        assert.same({}, ca.parse_ps("garbage\n  PID STARTED COMMAND"))
    end)
end)
```

Append to `tests/unit/cliproxy_release_spec.lua`:

```lua
describe("running_identity", function()
    local CFG = "/Users/me/.local/share/nvim/parley/cliproxy/config.yaml"
    local function row(pid, command)
        return { pid = pid, command = command, exe = command:match("^(%S+)") }
    end

    it("is nil when nothing holds the port", function()
        assert.is_nil(rel.running_identity({ row(1, "/b/cli-proxy-api -config " .. CFG) }, {}, CFG))
    end)

    it("is ours when the listener was launched with parley's rendered config", function()
        local id = rel.running_identity({ row(7, "/x/bin/cli-proxy-api -config " .. CFG) }, { 7 }, CFG)
        assert.same({ ours = true, exe = "/x/bin/cli-proxy-api" }, id)
    end)

    it("counts any binary parley launched, including one found on PATH", function()
        local id = rel.running_identity({ row(7, "/opt/homebrew/bin/cliproxyapi -config " .. CFG) }, { 7 }, CFG)
        assert.is_true(id.ours)
    end)

    it("is not ours when the listener runs another config (a brew service)", function()
        local id = rel.running_identity(
            { row(7, "/opt/homebrew/bin/cliproxyapi -config /opt/homebrew/etc/cliproxyapi.conf") }, { 7 }, CFG)
        assert.same({ ours = false, exe = "/opt/homebrew/bin/cliproxyapi" }, id)
    end)

    it("matches a config path containing a space", function()
        local spaced = "/Users/my name/.local/share/nvim/parley/cliproxy/config.yaml"
        assert.is_true(rel.running_identity({ row(7, "/b/cli-proxy-api -config " .. spaced) }, { 7 }, spaced).ours)
    end)

    it("requires the whole path, not a prefix of it", function()
        assert.is_false(rel.running_identity(
            { row(7, "/b/cli-proxy-api -config " .. CFG .. ".bak") }, { 7 }, CFG).ours)
    end)

    it("only looks at processes holding the port", function()
        local id = rel.running_identity(
            { row(3, "/b/cli-proxy-api -config " .. CFG), row(7, "/opt/homebrew/bin/cliproxyapi") }, { 7 }, CFG)
        assert.is_false(id.ours)
    end)

    it("is not ours when the process table could not be read", function()
        assert.same({ ours = false }, rel.running_identity({}, { 7 }, CFG))
    end)
end)
```

- [x] **Step 2: Run both specs to verify they fail**

Run the Step 2 command of Task 1 for `tests/unit/cliproxy_auth_spec.lua` and
`tests/unit/cliproxy_release_spec.lua`.
Expected: FAIL — `attempt to call field 'parse_ps' (a nil value)` and
`attempt to call field 'running_identity' (a nil value)`.

- [x] **Step 3: Extract `parse_ps` and rewrite `parse_peers` on it**

In `lua/parley/cliproxy_auth.lua`, add above `M.parse_peers` and replace its
body:

```lua
--- Parse `ps ax -o pid,lstart,command` into rows. The executable is the
--- command's first token — the only safe identity (see parse_peers). Shared by
--- parse_peers and cliproxy_release.running_identity (ARCH-DRY: one ps grammar).
---@param ps_output string|nil
---@return table[] # { pid, started, command, exe }
function M.parse_ps(ps_output)
    local rows = {}
    if type(ps_output) ~= "string" then
        return rows
    end
    for line in ps_output:gmatch("[^\n]+") do
        -- pid, lstart (Www Mmm DD HH:MM:SS YYYY), then the command
        local pid, started, command = line:match(
            "^%s*(%d+)%s+(%a+%s+%a+%s+%d+%s+[%d:]+%s+%d+)%s+(.+)$")
        if pid and command then
            rows[#rows + 1] = {
                pid = tonumber(pid),
                started = started,
                command = command,
                exe = command:match("^(%S+)"),
            }
        end
    end
    return rows
end

function M.parse_peers(ps_output, own_pids, managed_port_pids)
    local exclude = {}
    for _, list in ipairs({ own_pids or {}, managed_port_pids or {} }) do
        for _, pid in ipairs(list) do
            exclude[pid] = true
        end
    end
    local peers = {}
    for _, r in ipairs(M.parse_ps(ps_output)) do
        local base = r.exe and r.exe:match("([^/]+)$")
        if base and PROXY_BINARIES[base] and not exclude[r.pid] then
            peers[#peers + 1] = { pid = r.pid, started = r.started, command = r.command }
        end
    end
    return peers
end
```

Keep `parse_peers`'s existing docstring above it.

- [x] **Step 4: Add `running_identity`**

In `lua/parley/cliproxy_release.lua`, before `return M`:

```lua
--- Who holds the managed port (#237). A listener is ours when its command line
--- carries `-config <config_path>` as a whole token — launched by parley with
--- its rendered config, in this nvim session or an earlier one. Only the
--- listener's row is read, so a shell that merely mentions the path can never
--- match (the #197 lesson). A find, not the first token, so a data dir with a
--- space in it still matches.
---@param rows table[] # cliproxy_auth.parse_ps rows: { pid, command, exe }
---@param port_pids number[] # pids listening on the managed port
---@param config_path string|nil # parley's rendered config.yaml
---@return table|nil # { ours: boolean, exe: string|nil } — nil when nothing listens
function M.running_identity(rows, port_pids, config_path)
    if not port_pids or #port_pids == 0 then
        return nil
    end
    local on_port = {}
    for _, pid in ipairs(port_pids) do
        on_port[pid] = true
    end
    local needle = config_path and ("-config " .. config_path) or nil
    local exe
    for _, r in ipairs(rows or {}) do
        if on_port[r.pid] then
            exe = exe or r.exe
            if needle then
                -- Two locals from ONE call: `needle and cmd:find(...)` would
                -- truncate find's results to one value and lose `e`.
                local cmd = r.command or ""
                local s, e = cmd:find(needle, 1, true)
                if s and (e == #cmd or cmd:sub(e + 1, e + 1) == " ") then
                    return { ours = true, exe = r.exe }
                end
            end
        end
    end
    return { ours = false, exe = exe }
end
```

- [x] **Step 5: Run both specs to verify they pass**

Expected: PASS, including every pre-existing `parse_peers` case (lines
453-523) unchanged. `make lint`: 0 warnings.

- [x] **Step 6: Commit**

```bash
git add lua/parley/cliproxy_auth.lua lua/parley/cliproxy_release.lua \
  tests/unit/cliproxy_auth_spec.lua tests/unit/cliproxy_release_spec.lua
git commit -m "#237 M1: one ps grammar, and the identity of the proxy on the port"
```

### Task 3: The update decision table

**Files:**
- Modify: `lua/parley/cliproxy_release.lua`
- Test: `tests/unit/cliproxy_release_spec.lua`

- [x] **Step 1: Write the failing tests**

```lua
describe("update_refusal", function()
    it("refuses when parley does not manage the proxy", function()
        assert.is_truthy(rel.update_refusal({ managed = false }):find("cliproxy.manage is off", 1, true))
    end)

    it("refuses when binary_path points parley at another binary", function()
        local msg = rel.update_refusal({ managed = true, binary_path = "/usr/local/bin/cliproxyapi" })
        assert.is_truthy(msg:find("binary_path is set", 1, true))
        assert.is_truthy(msg:find("/usr/local/bin/cliproxyapi", 1, true))
    end)

    it("allows a managed proxy with no binary_path", function()
        assert.is_nil(rel.update_refusal({ managed = true }))
        assert.is_nil(rel.update_refusal({ managed = true, binary_path = "" }))
    end)
end)

describe("plan_update", function()
    local T = "7.2.158"

    it("fails with the pin's own error when download_version is invalid", function()
        local p = rel.plan_update({ pinned = true,
            target_err = 'cliproxy.download_version "latest" is not a release version (expected e.g. 7.2.158)' })
        assert.is_false(p.ok)
        assert.is_truthy(p.message:find('"latest" is not a release version', 1, true))
        assert.is_nil(p.message:find("set cliproxy.download_version", 1, true))
    end)

    it("points at download_version when the latest cannot be found", function()
        local p = rel.plan_update({ pinned = false, target_err = "unreachable: curl: (6) Could not resolve host" })
        assert.is_false(p.ok)
        assert.is_truthy(p.message:find("could not find the latest cliproxyapi release", 1, true))
        assert.is_truthy(p.message:find("Could not resolve host", 1, true))
        assert.is_truthy(p.message:find("set cliproxy.download_version", 1, true))
    end)

    it("installs into an empty managed dir and leaves nothing to restart", function()
        assert.same({ ok = true, install = T, target = T, message = "installed 7.2.158" },
            rel.plan_update({ target = T }))
    end)

    it("upgrades and restarts parley's own proxy", function()
        local p = rel.plan_update({ target = T, installed = "7.1.71",
            running = { version = "7.1.71", ours = true, port = 8317 } })
        assert.equals(T, p.install)
        assert.equals("managed", p.restart)
        assert.equals("updated 7.1.71 → 7.2.158 — restarting the proxy", p.message)
    end)

    it("upgrades but leaves a proxy parley did not launch running, and says how to replace it", function()
        local p = rel.plan_update({ target = T, installed = "7.1.71",
            running = { version = "7.1.71", ours = false, exe = "/opt/homebrew/bin/cliproxyapi", port = 8317 } })
        assert.equals("manual", p.restart)
        assert.is_truthy(p.message:find("/opt/homebrew/bin/cliproxyapi", 1, true))
        assert.is_truthy(p.message:find("was not started by parley", 1, true))
        assert.is_truthy(p.message:find("still runs 7.1.71", 1, true))
        assert.is_truthy(p.message:find("brew services stop cliproxyapi", 1, true))
    end)

    it("does nothing when the installed and running versions are current", function()
        assert.same({ ok = true, target = T, message = "already at 7.2.158" },
            rel.plan_update({ target = T, installed = T, running = { version = T, ours = true, port = 8317 } }))
    end)

    it("restarts a proxy still running the old version after an earlier install", function()
        local p = rel.plan_update({ target = T, installed = T,
            running = { version = "7.1.71", ours = true, port = 8317 } })
        assert.is_nil(p.install)
        assert.equals("managed", p.restart)
        assert.equals("already at 7.2.158 — restarting the proxy", p.message)
    end)

    it("honours a pin older than the latest, and says it is pinned", function()
        local p = rel.plan_update({ target = "7.1.71", pinned = true, installed = T })
        assert.equals("7.1.71", p.install)
        assert.equals("updated 7.2.158 → 7.1.71 (pinned by cliproxy.download_version)", p.message)
    end)

    it("does not restart when the running version is unknown and nothing was installed", function()
        assert.is_nil(rel.plan_update({ target = T, installed = T,
            running = { ours = true, port = 8317 } }).restart)
    end)

    it("restarts after an install even when the running version is unknown", function()
        assert.equals("managed", rel.plan_update({ target = T, installed = "7.1.71",
            running = { ours = true, port = 8317 } }).restart)
    end)
end)
```

- [x] **Step 2: Run to verify they fail** — `attempt to call field 'update_refusal' (a nil value)`.

- [x] **Step 3: Implement**

In `lua/parley/cliproxy_release.lua`, before `return M`:

```lua
--- Why parley will not update the managed binary, or nil when it may. Checked
--- before any network call.
---@param s table # { managed: boolean, binary_path: string|nil }
---@return string|nil
function M.update_refusal(s)
    if not s.managed then
        return "cliproxy.manage is off — parley does not run the proxy, so update your cliproxyapi yourself"
    end
    if type(s.binary_path) == "string" and s.binary_path ~= "" then
        return ("cliproxy.binary_path is set, so parley runs %s — update that binary, or unset "
            .. "binary_path to use parley's download"):format(s.binary_path)
    end
    return nil
end

--- The update decision table (#237, ARCH-ORDER): what to install, whether to
--- restart, and what to tell the user, from facts the IO layer gathered.
---@param s table
---   target      string|nil  version to install (download_version, else latest)
---   target_err  string|nil  why target is nil
---   pinned      boolean     target came from cliproxy.download_version
---   installed   string|nil  version recorded for the managed binary
---   running     table|nil   { version?, ours, exe?, port } — nil when nothing answers
---@return table # { ok, install?, restart?: "managed"|"manual", target?, message }
function M.plan_update(s)
    local target = s.target
    if not target then
        if s.pinned then
            return { ok = false, message = tostring(s.target_err) }
        end
        return { ok = false, message = ("could not find the latest cliproxyapi release (%s) — set "
            .. "cliproxy.download_version to install a specific one"):format(tostring(s.target_err)) }
    end
    local install = s.installed ~= target and target or nil
    local r, restart = s.running, nil
    if r and (install or (r.version and r.version ~= target)) then
        restart = r.ours and "managed" or "manual"
    end
    local msg
    if install then
        msg = s.installed and ("updated %s → %s"):format(s.installed, target) or ("installed %s"):format(target)
    else
        msg = ("already at %s"):format(target)
    end
    if s.pinned then
        msg = msg .. " (pinned by cliproxy.download_version)"
    end
    if restart == "managed" then
        msg = msg .. " — restarting the proxy"
    elseif restart == "manual" then
        msg = msg .. (" — the proxy on port %s (%s) was not started by parley and still runs %s; stop it "
            .. "(e.g. `brew services stop cliproxyapi`) so parley can start %s, or upgrade it"):format(
            tostring(r.port), r.exe or "another process", r.version or "an older version", target)
    end
    return { ok = true, install = install, restart = restart, target = target, message = msg }
end
```

- [x] **Step 4: Run to verify they pass** — PASS; `make lint` clean.

- [x] **Step 5: Commit**

```bash
git add lua/parley/cliproxy_release.lua tests/unit/cliproxy_release_spec.lua
git commit -m "#237 M1: the update decision table, pure and table-tested"
```

### Task 4: The fakes

**Files:**
- Create: `tests/fixtures/fixture_watchdog.py`
- Create: `tests/fixtures/fake_github_releases` (executable)
- Create: `tests/helpers/fake_releases.lua`
- Modify: `tests/fixtures/fake_cliproxy` (imports, its entry point, the `Handler` class and `do_GET`)
- Modify: `tests/minimal_init.vim` (next to the `$PARLEY_TEST_MODE` export, line 28)

- [x] **Step 0: Write `tests/fixtures/fixture_watchdog.py`** (imported, not executable)

```python
"""Exit a test fixture when the process that started it is gone (#237, #220).

A fixture reparented to init outlives its spec forever: #220 measured 897
orphaned fake_cliproxy processes holding ~10 GB. after_each teardown covers a
failing assertion, but not a crashed or killed nvim, which #220 found to be the
dominant case. This covers that one: the fixture polls its parent pid and exits
the moment it changes (reparenting to init, or to a subreaper).
"""
import os
import threading
import time


def exit_with_parent(poll_seconds=1.0):
    parent = os.getppid()

    def watch():
        while True:
            time.sleep(poll_seconds)
            if os.getppid() != parent:
                os._exit(0)

    threading.Thread(target=watch, daemon=True).start()
```

- [x] **Step 1: Write `tests/fixtures/fake_github_releases`**

```python
#!/usr/bin/env python3
"""Stateful fake of GitHub's release endpoints for CLIProxyAPI (issue #237).

Serves the same path shape as github.com, so parley's URL builder runs
unchanged; only the host differs:

  GET /router-for-me/CLIProxyAPI/releases/latest
        302 to .../releases/tag/v<ver>, where <ver> is read from <root>/latest
        on EVERY request (a spec publishes a new release mid-test by rewriting
        it); 404 when that file is absent.
  GET /router-for-me/CLIProxyAPI/releases/tag/v<ver>
        200 with a stub page (parley never follows the redirect; modelled so
        the shape is complete).
  GET /router-for-me/CLIProxyAPI/releases/download/v<ver>/<file>
        <root>/v<ver>/<file>, else 404.

State is the directory --root, owned by the spec. Every request is appended to
<root>/requests.log as "GET <path>", which is how a spec proves what parley did
and did not fetch.

Modes (--mode, or PARLEY_FAKE_RELEASES_MODE):
  normal   default
  slow     wait 1.5s before answering /latest, so a status spec can prove it
           waits for the slowest of its reads
"""
import os
import sys
import time
from http.server import BaseHTTPRequestHandler, HTTPServer

sys.dont_write_bytecode = True  # never write __pycache__ into the repo (#202)
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from fixture_watchdog import exit_with_parent  # noqa: E402

PREFIX = "/router-for-me/CLIProxyAPI/releases"


def parse_args(argv):
    port, root = None, None
    mode = os.environ.get("PARLEY_FAKE_RELEASES_MODE", "normal")
    i = 0
    while i < len(argv):
        if argv[i] == "--port":
            port = int(argv[i + 1])
            i += 2
        elif argv[i] == "--root":
            root = argv[i + 1]
            i += 2
        elif argv[i] == "--mode":
            mode = argv[i + 1]
            i += 2
        else:
            i += 1
    if port is None or root is None:
        sys.exit("usage: fake_github_releases --port <p> --root <dir> [--mode normal|slow]")
    return port, root, mode


def main():
    port, root, mode = parse_args(sys.argv[1:])
    exit_with_parent()  # a crashed or killed spec must not orphan this server (#220)

    class Handler(BaseHTTPRequestHandler):
        def log_message(self, *_a):
            pass

        def _send(self, status, body=b"", headers=None):
            self.send_response(status)
            for name, value in (headers or {}).items():
                self.send_header(name, value)
            self.send_header("Content-Length", str(len(body)))
            self.end_headers()
            self.wfile.write(body)

        def do_GET(self):
            with open(os.path.join(root, "requests.log"), "a") as log:
                log.write("GET " + self.path + "\n")
            if not self.path.startswith(PREFIX + "/"):
                return self._send(404)
            rest = self.path[len(PREFIX):]
            if rest == "/latest":
                if mode == "slow":
                    time.sleep(1.5)
                try:
                    with open(os.path.join(root, "latest")) as f:
                        ver = f.read().strip()
                except FileNotFoundError:
                    return self._send(404)
                location = "http://127.0.0.1:%d%s/tag/v%s" % (port, PREFIX, ver)
                return self._send(302, headers={"Location": location})
            if rest.startswith("/tag/"):
                return self._send(200, b"<html>release</html>", {"Content-Type": "text/html"})
            parts = rest.split("/")  # ["", "download", "v<ver>", "<file>"]
            if (len(parts) == 4 and parts[1] == "download" and parts[2].startswith("v")
                    and parts[3] not in ("", ".", "..")):
                path = os.path.join(root, parts[2], parts[3])
                if os.path.isfile(path):
                    with open(path, "rb") as f:
                        return self._send(200, f.read(), {"Content-Type": "application/octet-stream"})
            return self._send(404)

    HTTPServer(("127.0.0.1", port), Handler).serve_forever()


if __name__ == "__main__":
    main()
```

Run: `chmod +x tests/fixtures/fake_github_releases`.

- [x] **Step 2: Write `tests/helpers/fake_releases.lua`**

```lua
-- Build CLIProxyAPI-shaped releases on disk and serve them with
-- tests/fixtures/fake_github_releases (#237). One owner for the release
-- fixture the download and update specs share (ARCH-DRY).
--
-- A published release's cli-proxy-api is a wrapper that execs
-- tests/fixtures/fake_cliproxy with PARLEY_FAKE_CPA_VERSION set to the
-- release's version, so "which release is running" is observable through the
-- same X-Cpa-Version header parley reads from the real binary.

local cc = require("parley.cliproxy_config")
local fixture_process = require("tests.helpers.fixture_process")
local ready_port = require("tests.helpers.ready_port")

local M = {}

local SERVER = vim.fn.getcwd() .. "/tests/fixtures/fake_github_releases"
local FAKE_PROXY = vim.fn.getcwd() .. "/tests/fixtures/fake_cliproxy"

local function sha256(path)
    local cmd = vim.fn.executable("sha256sum") == 1 and { "sha256sum", path } or { "shasum", "-a", "256", path }
    return vim.trim(vim.fn.system(cmd)):match("^(%x+)")
end

--- Start a release server over a fresh root.
---@param mode string|nil # "normal" (default) | "slow"
---@return table # { root, port, url, handle }
function M.start(mode)
    local root = vim.fn.tempname()
    vim.fn.mkdir(root, "p")
    local port = ready_port.free_port()
    local args = { "--port", tostring(port), "--root", root }
    if mode then
        vim.list_extend(args, { "--mode", mode })
    end
    local handle, _, err = fixture_process.spawn(SERVER, args)
    assert(handle, "failed to start fake_github_releases: " .. tostring(err))
    ready_port.wait_listening(port)
    local server = {
        root = root,
        port = port,
        handle = handle,
        url = ("http://127.0.0.1:%d/router-for-me/CLIProxyAPI/releases"):format(port),
    }
    vim.api.nvim_create_autocmd("VimLeavePre", {
        callback = function()
            M.stop(server)
        end,
    })
    return server
end

--- Stop a server started by M.start.
function M.stop(server)
    pcall(function()
        if server.handle and not server.handle:is_closing() then
            server.handle:kill("sigkill")
        end
    end)
end

--- Publish release `ver`: its tarball and checksums.txt, and (unless
--- `opts.latest == false`) make it the latest. `opts.sha` publishes a wrong
--- checksum.
---@return table # { asset, sha }
function M.publish(server, ver, opts)
    opts = opts or {}
    local vdir = server.root .. "/v" .. ver
    vim.fn.mkdir(vdir, "p")
    local stage = vim.fn.tempname()
    vim.fn.mkdir(stage, "p")
    vim.fn.writefile({
        "#!/bin/sh",
        "PARLEY_FAKE_CPA_VERSION=" .. vim.fn.shellescape(ver),
        -- parley spawns this detached; it must still exit with the spec's nvim (#220)
        "PARLEY_FAKE_EXIT_WITH_PARENT=1",
        "export PARLEY_FAKE_CPA_VERSION PARLEY_FAKE_EXIT_WITH_PARENT",
        "exec " .. vim.fn.shellescape(FAKE_PROXY) .. ' "$@"',
    }, stage .. "/cli-proxy-api")
    vim.fn.system({ "chmod", "+x", stage .. "/cli-proxy-api" })
    local asset = cc.asset_name(ver, cc.platform())
    local asset_path = vdir .. "/" .. asset
    vim.fn.system({ "tar", "-czf", asset_path, "-C", stage, "cli-proxy-api" })
    local sha = sha256(asset_path)
    vim.fn.writefile({ (opts.sha or sha) .. "  " .. asset }, vdir .. "/checksums.txt")
    if opts.latest ~= false then
        vim.fn.writefile({ ver }, server.root .. "/latest")
    end
    return { asset = asset, sha = sha }
end

--- Requests the server has answered, as "GET <path>" lines.
function M.requests(server)
    local ok, lines = pcall(vim.fn.readfile, server.root .. "/requests.log")
    return ok and lines or {}
end

function M.clear_requests(server)
    vim.fn.delete(server.root .. "/requests.log")
end

return M
```

- [x] **Step 3: Teach `fake_cliproxy` the `X-CPA-*` stamp, the `latest-version` route, and to exit with its parent on request**

After `fake_cliproxy`'s imports:

```python
sys.dont_write_bytecode = True  # never write __pycache__ into the repo (#202)
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from fixture_watchdog import exit_with_parent  # noqa: E402
```

At the top of its entry point, before the login-mode branch and the server
start:

```python
    # Opt-in (#237 sets it for every fake it starts); #220 owns making it the
    # default, alongside its suite-level sweep.
    if os.environ.get("PARLEY_FAKE_EXIT_WITH_PARENT") == "1":
        exit_with_parent()
```

In `tests/fixtures/fake_cliproxy`, beside the other env reads inside the
function that defines `Handler` (where `mode` and `mgmt_key` are bound), add:

```python
    # The build the proxy reports in X-CPA-VERSION. A published fake release
    # (tests/helpers/fake_releases.lua) sets it to its own version (#237).
    CPA_VERSION = os.environ.get("PARLEY_FAKE_CPA_VERSION", "7.1.71")
```

Add to `class Handler`:

```python
        def end_headers(self):
            # The real binary stamps its build on every /v0/management/*
            # response — 200, 401 and 404 alike — and on nothing else (captured
            # live from 7.1.71 on 2026-09-11, #237). Whether it still does with
            # management DISABLED is pinned by the conformance spec; this fake
            # stamps only when a management key is configured until that spec
            # says otherwise.
            if self.path.startswith("/v0/management/") and mgmt_key:
                self.send_header("X-CPA-VERSION", CPA_VERSION)
                self.send_header("X-CPA-COMMIT", "fake")
                self.send_header("X-CPA-BUILD-DATE", "2026-01-01T00:00:00Z")
            BaseHTTPRequestHandler.end_headers(self)
```

In `do_GET`, before the `/v0/management/auth-files` branch:

```python
            if self.path.startswith("/v0/management/latest-version"):
                if not mgmt_key:
                    self.send_response(404)
                    self.end_headers()
                    return
                if self._bearer() != mgmt_key:
                    self._json(401, {"error": "unauthorized"})
                    return
                self._json(200, {"latest-version": "v" + os.environ.get("PARLEY_FAKE_LATEST", CPA_VERSION)})
                return
```

Add `latest-version` and the header to the module docstring's route list.

- [x] **Step 4: Point the harness away from GitHub**

In `tests/minimal_init.vim`, after line 28 (`let $PARLEY_TEST_MODE = '1'`):

```vim
" #237: cliproxy's release lookups go to github.com by default. Point them at a
" dead local port so a spec that forgets cliproxy._set_releases_url fails fast
" instead of reaching the network; plenary's child nvims inherit this.
let $PARLEY_CLIPROXY_RELEASES_URL = 'http://127.0.0.1:9/router-for-me/CLIProxyAPI/releases'
```

- [x] **Step 5: Confirm the existing specs still pass with the fake change**

Run: `make test-spec SPEC=providers/cliproxy-managed`
Expected: PASS — the new header and route are additive.

- [x] **Step 6: Commit**

```bash
git add tests/fixtures/fixture_watchdog.py tests/fixtures/fake_github_releases \
  tests/helpers/fake_releases.lua tests/fixtures/fake_cliproxy tests/minimal_init.vim
git commit -m "#237 M1: a stateful GitHub releases fake, and fake_cliproxy stamps its version"
```

### Task 5: Resolve the release, probe the running version

**Files:**
- Modify: `lua/parley/cliproxy.lua` (top-level requires; `api_argv`; beside `M.health_probe`; the release section at the end)
- Create: `tests/integration/cliproxy_update_spec.lua`

- [x] **Step 1: Write the failing tests**

Create `tests/integration/cliproxy_update_spec.lua`:

```lua
-- Integration tests for #237: resolving, installing and switching to a
-- CLIProxyAPI release, against tests/fixtures/fake_github_releases (a stateful
-- fake of GitHub's release endpoints) and tests/fixtures/fake_cliproxy.

local uv = vim.uv or vim.loop
local cliproxy = require("parley.cliproxy")
local fake_releases = require("tests.helpers.fake_releases")
local fixture_process = require("tests.helpers.fixture_process")
local ready_port = require("tests.helpers.ready_port")

local FAKE = vim.fn.getcwd() .. "/tests/fixtures/fake_cliproxy"

cliproxy._set_data_dir(vim.fn.tempname()) -- never the real ~/.local/share/nvim
local server = fake_releases.start()
cliproxy._set_releases_url(server.url)

-- Run an async fn(done) and block until it calls done(result); return result.
-- 25 s: above UPDATE_RESTART_DEADLINE_MS (20 s), so a wait never gives up while
-- the leg it waits on is still bound to answer (PQ-5).
local function await(fn, ms)
    local result, got = nil, false
    fn(function(r)
        result = r
        got = true
    end)
    vim.wait(ms or 25000, function()
        return got
    end, 20)
    assert(got, "async call timed out")
    return result
end

local function dead_url()
    return ("http://127.0.0.1:%d/router-for-me/CLIProxyAPI/releases"):format(ready_port.free_port())
end

-- Every process a case starts is registered here and reaped in after_each, so a
-- failing assertion cannot orphan it (PQ-1, #220). The fixtures also exit when
-- this nvim does (fixture_watchdog.py), which covers a crashed or killed run.
local spawned, servers = {}, {}

local function spawn_fake(args, env)
    local handle, _, err = fixture_process.spawn(FAKE, args,
        vim.tbl_extend("force", { PARLEY_FAKE_EXIT_WITH_PARENT = "1" }, env or {}))
    assert(handle, "failed to spawn fake_cliproxy: " .. tostring(err))
    spawned[#spawned + 1] = handle
    return handle
end

local function start_server(mode)
    local s = fake_releases.start(mode)
    servers[#servers + 1] = s
    return s
end

local function reap()
    for _, h in ipairs(spawned) do
        pcall(function()
            if not h:is_closing() then
                h:kill("sigterm")
            end
        end)
    end
    for _, s in ipairs(servers) do
        fake_releases.stop(s)
    end
    spawned, servers = {}, {}
end

it("the harness keeps every spec off GitHub", function()
    -- A harness flag is only evidence once a spec has seen it (#227).
    assert.equals("http://127.0.0.1:9/router-for-me/CLIProxyAPI/releases",
        vim.env.PARLEY_CLIPROXY_RELEASES_URL)
end)

describe("latest_release", function()
    after_each(function()
        cliproxy._set_releases_url(server.url)
    end)

    it("follows the releases/latest redirect to the newest tag", function()
        fake_releases.publish(server, "9.9.1")
        assert.same({ "9.9.1" }, { cliproxy.latest_release() })
    end)

    it("reports a missing latest pointer instead of inventing a version", function()
        vim.fn.delete(server.root .. "/latest")
        assert.same({ nil, "no release in the redirect (HTTP 404)" }, { cliproxy.latest_release() })
    end)

    it("reports an unreachable GitHub", function()
        cliproxy._set_releases_url(dead_url())
        local v, err = cliproxy.latest_release()
        assert.is_nil(v)
        assert.is_truthy(err:find("^unreachable: "))
    end)

    it("answers asynchronously when given a callback", function()
        fake_releases.publish(server, "9.9.2")
        local got = await(function(done)
            cliproxy.latest_release(function(v, e)
                done({ v = v, e = e })
            end)
        end)
        assert.equals("9.9.2", got.v)
    end)
end)

describe("resolve_target", function()
    local parley = require("parley")
    local saved
    before_each(function()
        saved = parley.config
    end)
    after_each(function()
        parley.config = saved
    end)

    it("uses download_version without asking GitHub", function()
        parley.config = { cliproxy = { manage = true, download_version = "v9.9.1" } }
        fake_releases.clear_requests(server)
        assert.same({ "9.9.1", nil, true }, { cliproxy.resolve_target() })
        assert.same({}, fake_releases.requests(server))
    end)

    it("rejects a download_version that is not a release version", function()
        parley.config = { cliproxy = { manage = true, download_version = "latest" } }
        assert.same({ nil, 'cliproxy.download_version "latest" is not a release version (expected e.g. 7.2.158)', true },
            { cliproxy.resolve_target() })
    end)

    it("falls back to the latest release when unpinned", function()
        parley.config = { cliproxy = { manage = true } }
        fake_releases.publish(server, "9.9.3")
        assert.same({ "9.9.3", nil, false }, { cliproxy.resolve_target() })
    end)
end)

describe("version_probe", function()
    after_each(reap)

    it("reads the version a management-enabled proxy stamps, without a credential", function()
        local port = ready_port.free_port()
        spawn_fake({ "--port", tostring(port), "--management-key", "k" }, { PARLEY_FAKE_CPA_VERSION = "9.9.9" })
        ready_port.wait_listening(port)
        assert.same({ "9.9.9" }, { cliproxy.version_probe("127.0.0.1", port) })
    end)

    it("says no_header when the proxy answers without one", function()
        local port = ready_port.free_port()
        spawn_fake({ "--port", tostring(port) })
        ready_port.wait_listening(port)
        assert.same({ nil, "no_header" }, { cliproxy.version_probe("127.0.0.1", port) })
    end)

    it("says down when nothing listens", function()
        assert.same({ nil, "down" }, { cliproxy.version_probe("127.0.0.1", ready_port.free_port()) })
    end)
end)
```

Add `tests/integration/cliproxy_update_spec.lua` to
`atlas/traceability.yaml` under `providers/cliproxy-managed.tests` (and
`tests/unit/cliproxy_release_spec.lua`, and `lua/parley/cliproxy_release.lua`
under `code`) so `make test-spec SPEC=providers/cliproxy-managed` runs them.

- [x] **Step 2: Run to verify it fails**

Run: `nvim -n --headless --noplugin -u tests/minimal_init.vim -c "PlenaryBustedFile tests/integration/cliproxy_update_spec.lua" -c "qa!"`
Expected: FAIL — `attempt to call field '_set_releases_url' (a nil value)`.

- [x] **Step 3: Implement the IO**

In `lua/parley/cliproxy.lua`:

1. After `local logger = require("parley.logger")` (line 15):

```lua
local rel = require("parley.cliproxy_release")
```

2. Replace `api_argv` (lines 140-154) with:

```lua
-- Build the curl argv for a GET against host:port with an optional bearer.
-- Single source of truth for the request shape (ARCH-DRY): the health probe,
-- the stop-time identity check, list_models, the management-API reader and the
-- version probe all go through here. `-w "\n%{http_code}"` appends the status
-- code on its own line so callers can split body from code. `opts.dump_headers`
-- (the version probe, #237) sends the response HEADERS to stdout and discards
-- the body, so split_status still splits header block from code.
---@param route string|nil # defaults to /v1/models
---@param opts table|nil # { dump_headers: boolean }
local function api_argv(host, port, secret, route, opts)
    local args = { "curl", "-s", "-w", "\n%{http_code}", "--max-time", tostring(CURL_MAX_TIME) }
    if opts and opts.dump_headers then
        vim.list_extend(args, { "-D", "-", "-o", "/dev/null" })
    end
    if type(secret) == "string" and secret ~= "" then
        table.insert(args, "-H")
        table.insert(args, "Authorization: Bearer " .. secret)
    end
    table.insert(args, ("http://%s:%s%s"):format(host, port, route or "/v1/models"))
    return args
end

-- Run argv: async when `cb` is given (cb(obj) on the main loop), else
-- synchronously, returning the vim.system result.
local function run(argv, cb)
    if not cb then
        return vim.system(argv, { text = true }):wait()
    end
    vim.system(argv, { text = true }, function(obj)
        vim.schedule(function()
            cb(obj)
        end)
    end)
end
```

3. After `M.health_probe` (ends line 169):

```lua
--- The running proxy's version (#237), from the X-Cpa-Version header on a
--- /v0/management/* response. An unauthenticated request draws a 401 that
--- still carries it (verified live on 7.1.71), so no credential is sent.
--- Sync when `cb` is nil (returns version, reason); else cb(version, reason)
--- on the main loop. reason: "down" (no answer) | "no_header" (no version).
---@param host string
---@param port number
---@param cb fun(version: string|nil, reason: string|nil)|nil
function M.version_probe(host, port, cb)
    local argv = api_argv(host, port, nil, "/v0/management/latest-version", { dump_headers = true })
    if not cb then
        return rel.parse_version_probe(run(argv))
    end
    run(argv, function(obj)
        cb(rel.parse_version_probe(obj))
    end)
end
```

4. Replace the section header and the first three constants at the end of the
file (lines 1757-1763) with:

```lua
--------------------------------------------------------------------------------
-- Releases: resolve, install, update (#131 M2, #237)
--------------------------------------------------------------------------------

-- Root of CLIProxyAPI's GitHub releases: `/latest` redirects to the newest tag,
-- `/download/v<ver>/<asset>` serves it. Specs point it at
-- tests/fixtures/fake_github_releases through _set_releases_url; the harness
-- points it at a dead local port through $PARLEY_CLIPROXY_RELEASES_URL
-- (tests/minimal_init.vim), so a spec that forgets the seam fails fast instead
-- of reaching github.com.
local RELEASES_URL = "https://github.com/router-for-me/CLIProxyAPI/releases"
local LATEST_MAX_TIME = 10 -- seconds: :ParleyProxy update and first-run resolve
M.STATUS_LATEST_MAX_TIME = 5 -- seconds: :ParleyProxy status waits less
local BIN_NAME = "cli-proxy-api" -- the executable inside the release tarball

local _releases_url_override = nil

--- Test seam: point release lookups and downloads at `url` (nil restores).
---@param url string|nil
function M._set_releases_url(url)
    _releases_url_override = url
end

local function releases_url()
    local env = vim.env.PARLEY_CLIPROXY_RELEASES_URL
    return _releases_url_override or (env ~= nil and env ~= "" and env) or RELEASES_URL
end

--- The newest published release, from GitHub's releases/latest redirect: no
--- API token, no rate-limit quota (#237). Sync when `cb` is nil (returns
--- version, err); else cb(version, err) on the main loop.
---@param cb fun(version: string|nil, err: string|nil)|nil
---@param max_time number|nil # seconds; default LATEST_MAX_TIME
function M.latest_release(cb, max_time)
    local argv = { "curl", "-sS", "-o", "/dev/null", "-w", "%{redirect_url}\n%{http_code}",
        "--connect-timeout", "5", "--max-time", tostring(max_time or LATEST_MAX_TIME),
        releases_url() .. "/latest" }
    if not cb then
        return rel.parse_latest_response(run(argv))
    end
    run(argv, function(obj)
        cb(rel.parse_latest_response(obj))
    end)
end

--- The release parley should install (#237): cliproxy.download_version when
--- set, else the latest release. One rule for :ParleyProxy update and the
--- first-run auto_download (ARCH-DRY). Sync when `cb` is nil (returns version,
--- err, pinned); else cb(version, err, pinned).
---@param cb fun(version: string|nil, err: string|nil, pinned: boolean)|nil
function M.resolve_target(cb)
    local pin = (cfg() or {}).download_version
    if pin ~= nil then
        local v = rel.parse_version(pin)
        local err = nil
        if not v then
            err = ("cliproxy.download_version %q is not a release version (expected e.g. 7.2.158)")
                :format(tostring(pin))
        end
        if cb then
            return cb(v, err, true)
        end
        return v, err, true
    end
    if cb then
        return M.latest_release(function(v, err)
            cb(v, err, false)
        end)
    end
    local v, err = M.latest_release()
    return v, err, false
end
```

`RELEASE_BASE` and `PINNED_VERSION` are gone; `download` still names them until
Task 6, so do Task 6 before running `make lint`.

- [x] **Step 4: Run the spec to verify it passes**

Expected: PASS for the harness check, `latest_release`, `resolve_target` and
`version_probe`.

- [x] **Step 5: Commit** (after Task 6 compiles; commit Tasks 5 and 6 together if
lint blocks) — `#237 M1: resolve the release from GitHub's redirect, and read the running version`.

### Task 6: Install a version atomically, and record it

**Files:**
- Modify: `lua/parley/cliproxy.lua` (`bin_dir`, `M.managed_binary`, `sha256_of`, `M.download`)
- Modify: `tests/integration/cliproxy_download_spec.lua` (rewrite)

- [x] **Step 1: Rewrite the download spec against the fake**

```lua
-- Integration test for installing a CLIProxyAPI release (#131 M2, #237).
-- Serves releases from tests/fixtures/fake_github_releases (no network) and
-- verifies download → checksum-verify → staged extract → atomic rename →
-- version record, and that a tampered checksum or a non-version is refused.

local uv = vim.uv or vim.loop
local cliproxy = require("parley.cliproxy")
local fake_releases = require("tests.helpers.fake_releases")

cliproxy._set_data_dir(vim.fn.tempname()) -- never touch the real ~/.local/share/nvim
local server = fake_releases.start()
cliproxy._set_releases_url(server.url)

describe("cliproxy download", function()
    before_each(function()
        local mb = cliproxy.managed_binary()
        if mb then
            vim.fn.delete(mb)
            vim.fn.delete(mb .. ".version")
        end
        fake_releases.publish(server, "9.9.9") -- also restores good checksums
    end)

    it("downloads, checksum-verifies, installs, and records the version", function()
        local bin, err = cliproxy.download({ version = "9.9.9" })
        assert.is_truthy(bin, "download failed: " .. tostring(err))
        assert.equals(1, vim.fn.executable(bin))
        assert.equals(bin, cliproxy.managed_binary())
        assert.equals("9.9.9", cliproxy.installed_version())
    end)

    it("makes the downloaded binary discoverable", function()
        cliproxy.download({ version = "9.9.9" })
        local saved = require("parley").config
        require("parley").config = { cliproxy = { manage = true } }
        assert.equals(cliproxy.managed_binary(), cliproxy.discover_binary())
        require("parley").config = saved
    end)

    it("replaces an installed binary by rename, so a running copy keeps its file", function()
        local bin = cliproxy.download({ version = "9.9.9" })
        local before = uv.fs_stat(bin).ino
        fake_releases.publish(server, "9.9.10")
        assert.is_truthy(cliproxy.download({ version = "9.9.10" }))
        assert.are_not.equal(before, uv.fs_stat(bin).ino)
        assert.equals("9.9.10", cliproxy.installed_version())
        assert.is_nil(uv.fs_stat(vim.fn.fnamemodify(bin, ":h:h") .. "/staging"), "staging left behind")
    end)

    it("REFUSES to install on a checksum mismatch, leaving the previous install", function()
        assert.is_truthy(cliproxy.download({ version = "9.9.9" }))
        fake_releases.publish(server, "9.9.11", { sha = ("0"):rep(64) })
        local bin, err = cliproxy.download({ version = "9.9.11" })
        assert.is_nil(bin)
        assert.is_truthy(err and err:find("checksum mismatch"))
        assert.equals("9.9.9", cliproxy.installed_version())
    end)

    it("refuses a version it would have to put in a URL unparsed", function()
        local bin, err = cliproxy.download({ version = "../../evil" })
        assert.is_nil(bin)
        assert.is_truthy(err:find("not a release version", 1, true))
    end)

    it("reads a missing or garbled version record as unknown", function()
        local bin = cliproxy.download({ version = "9.9.9" })
        vim.fn.writefile({ "not a version" }, bin .. ".version")
        assert.is_nil(cliproxy.installed_version())
        vim.fn.delete(bin .. ".version")
        assert.is_nil(cliproxy.installed_version())
    end)
end)
```

- [x] **Step 2: Run to verify it fails** — `installed_version` is nil; the
rename case fails (tar overwrote in place; no record).

- [x] **Step 3: Rewrite `download` and add `installed_version`**

Keep `bin_dir`, `M.managed_binary` and `sha256_of` as they are. Add after
`sha256_of`:

```lua
local function version_record()
    return bin_dir() .. "/" .. BIN_NAME .. ".version"
end

--- The version parley recorded when it installed the managed binary, or nil:
--- no binary, or a record that is missing, truncated, hand-edited or otherwise
--- not a version — all of which mean "unknown" (ARCH-SECURE).
---@return string|nil
function M.installed_version()
    if not M.managed_binary() then
        return nil
    end
    local ok, lines = pcall(vim.fn.readfile, version_record(), "", 1)
    return ok and rel.parse_version(lines[1]) or nil
end
```

Replace `M.download` and `M.update` (lines 1789-1852) with:

```lua
--- Download, checksum-verify and install release `opts.version` as the managed
--- binary (#131 M2, #237). The tarball is extracted into a staging dir beside
--- the bin dir and renamed over the binary, so a running proxy keeps its old
--- file and an interrupted install leaves the previous binary in place; the
--- version is recorded last. Synchronous: it blocks the editor for the fetch,
--- bounded by curl's timeouts (the audit's B5, owned by #209). Refuses a value
--- that is not a version and a checksum mismatch.
---@param opts table # { version: string }
---@return string|nil binary_path, string|nil err
function M.download(opts)
    local raw = (opts or {}).version
    local version = rel.parse_version(raw)
    if not version then
        return nil, "not a release version: " .. tostring(raw)
    end
    local plat = cc.platform()
    if not plat then
        return nil, "no published cliproxy release for this platform"
    end
    if plat.os == "windows" then
        return nil, "auto_download does not support Windows (.zip) — install cliproxyapi manually"
    end
    local asset = cc.asset_name(version, plat)
    local base = ("%s/download/v%s"):format(releases_url(), version)
    local tarball_url = base .. "/" .. asset
    local sums_url = base .. "/checksums.txt"

    local tmp = vim.fn.tempname() .. ".tar.gz"
    local dl = vim.system({ "curl", "-fsSL", "--connect-timeout", "10", "--max-time", "300",
        "-o", tmp, tarball_url }, { text = true }):wait()
    if dl.code ~= 0 then
        os.remove(tmp) -- curl -o may have left a partial file
        return nil, "download failed (" .. tarball_url .. "): " .. tostring(dl.stderr)
    end
    local sums = vim.system({ "curl", "-fsSL", "--connect-timeout", "10", "--max-time", "30",
        sums_url }, { text = true }):wait()
    if sums.code ~= 0 then
        os.remove(tmp)
        return nil, "checksums fetch failed: " .. tostring(sums.stderr)
    end
    local expected = cc.parse_checksums(sums.stdout or "", asset)
    if not expected then
        os.remove(tmp)
        return nil, asset .. " not listed in checksums.txt"
    end
    local actual = sha256_of(tmp)
    if not actual or actual ~= expected then
        os.remove(tmp)
        return nil, "checksum mismatch for " .. asset .. " — refusing to install (expected "
            .. expected .. ", got " .. tostring(actual) .. ")"
    end

    -- Stage beside the bin dir: the same filesystem, so the rename is atomic.
    -- `stage` is a leaf this function constructs under the data root, which is
    -- never empty — the only path the recursive delete can reach.
    local stage = data_root() .. "/staging"
    vim.fn.delete(stage, "rf")
    vim.fn.mkdir(stage, "p")
    local ex = vim.system({ "tar", "-xzf", tmp, "-C", stage, BIN_NAME }, { text = true }):wait()
    os.remove(tmp)
    if ex.code ~= 0 then
        vim.fn.delete(stage, "rf")
        return nil, "extract failed: " .. tostring(ex.stderr)
    end
    local staged = stage .. "/" .. BIN_NAME
    uv.fs_chmod(staged, tonumber("755", 8))
    local bin = bin_dir() .. "/" .. BIN_NAME
    local renamed, rerr = uv.fs_rename(staged, bin)
    vim.fn.delete(stage, "rf")
    if not renamed then
        return nil, "install failed: " .. tostring(rerr)
    end
    local record = version_record()
    vim.fn.writefile({ version }, record .. ".tmp")
    uv.fs_rename(record .. ".tmp", record)
    return bin
end
```

(`M.update` is rewritten in Task 7; delete the old one-line version here.)

- [x] **Step 4: Run the download and update specs, then `make lint`**

Expected: PASS; lint clean (no `PINNED_VERSION`/`RELEASE_BASE` left).

- [x] **Step 5: Commit**

```bash
git add lua/parley/cliproxy.lua tests/integration/cliproxy_download_spec.lua \
  tests/integration/cliproxy_update_spec.lua atlas/traceability.yaml
git commit -m "#237 M1: install a release by staged rename, and record its version"
```

### Task 7: `:ParleyProxy update`, and restart only parley's own proxy

**Files:**
- Modify: `lua/parley/cliproxy.lua` (`M.peers`, new `ps_output`/`port_identity`, `M.update`; delete `M.restart`)
- Modify: `lua/parley/init.lua` (`register_proxy_command`: `SUBS_HELP`, the `update` and `restart` branches)
- Test: `tests/integration/cliproxy_update_spec.lua`, `tests/integration/cliproxy_command_spec.lua`

- [x] **Step 1: Write the failing update tests**

Append to `tests/integration/cliproxy_update_spec.lua`:

```lua
describe(":ParleyProxy update", function()
    local parley = require("parley")
    local saved_config, saved_path, proxy_port

    local function set_endpoint(port)
        parley.dispatcher = parley.dispatcher or {}
        parley.dispatcher.providers = parley.dispatcher.providers or {}
        parley.dispatcher.providers.cliproxyapi = {
            endpoint = ("http://127.0.0.1:%d/v1/chat/completions"):format(port),
        }
        require("parley.vault").add_secret("cliproxyapi", "testkey")
    end

    local function wipe_install()
        local mb = cliproxy.managed_binary()
        if mb then
            vim.fn.delete(mb)
            vim.fn.delete(mb .. ".version")
        end
    end

    local function update()
        return await(function(done)
            cliproxy.update(function(ok, msg)
                done({ ok = ok, msg = msg })
            end)
        end)
    end

    -- parley launches its managed binary (a published fake release) on the port
    local function start_managed(version)
        fake_releases.publish(server, version, { latest = false })
        assert.is_truthy(cliproxy.download({ version = version }))
        local result = await(function(done)
            cliproxy.ensure_running(function()
                done(true)
            end, function(msg)
                done(msg)
            end)
        end)
        assert.is_true(result == true, tostring(result))
        assert.same({ version }, { cliproxy.version_probe("127.0.0.1", proxy_port) })
    end

    before_each(function()
        saved_config, saved_path = parley.config, vim.env.PATH
        vim.env.PATH = "/usr/bin:/bin:/usr/sbin:/sbin" -- no brew binary (#197)
        proxy_port = ready_port.free_port()
        set_endpoint(proxy_port)
        parley.config = { cliproxy = { manage = true } }
        cliproxy._set_releases_url(server.url)
        fake_releases.clear_requests(server)
    end)

    -- Owns every process a case starts (Process ownership, PQ-1).
    after_each(function()
        reap()
        cliproxy.stop()
        cliproxy._reset_spawned()
        cliproxy._set_update_restart_deadline_ms(nil)
        parley.config, vim.env.PATH = saved_config, saved_path
    end)

    it("installs the latest release into an empty managed dir", function()
        wipe_install()
        fake_releases.publish(server, "9.9.1")
        local r = update()
        assert.is_true(r.ok, r.msg)
        assert.equals("installed 9.9.1", r.msg)
        assert.equals("9.9.1", cliproxy.installed_version())
    end)

    it("updates to a newer release and reports old → new", function()
        wipe_install()
        fake_releases.publish(server, "9.9.1", { latest = false })
        cliproxy.download({ version = "9.9.1" })
        fake_releases.publish(server, "9.9.2")
        local r = update()
        assert.equals("updated 9.9.1 → 9.9.2", r.msg)
        assert.equals("9.9.2", cliproxy.installed_version())
    end)

    it("downloads nothing when already at the latest", function()
        fake_releases.publish(server, "9.9.2")
        cliproxy.download({ version = "9.9.2" })
        fake_releases.clear_requests(server)
        assert.equals("already at 9.9.2", update().msg)
        for _, line in ipairs(fake_releases.requests(server)) do
            assert.is_nil(line:find("/download/", 1, true), "fetched " .. line)
        end
    end)

    it("installs exactly the pinned version without asking for the latest", function()
        fake_releases.publish(server, "9.9.1", { latest = false })
        fake_releases.publish(server, "9.9.2")
        cliproxy.download({ version = "9.9.2" })
        parley.config = { cliproxy = { manage = true, download_version = "9.9.1" } }
        fake_releases.clear_requests(server)
        assert.equals("updated 9.9.2 → 9.9.1 (pinned by cliproxy.download_version)", update().msg)
        for _, line in ipairs(fake_releases.requests(server)) do
            assert.is_nil(line:find("/latest", 1, true), "asked for the latest despite the pin")
        end
    end)

    it("changes nothing when GitHub cannot be reached", function()
        fake_releases.publish(server, "9.9.2")
        local bin = cliproxy.download({ version = "9.9.2" })
        local before = uv.fs_stat(bin).ino
        cliproxy._set_releases_url(dead_url())
        local r = update()
        assert.is_false(r.ok)
        assert.is_truthy(r.msg:find("could not find the latest cliproxyapi release", 1, true))
        assert.equals(before, uv.fs_stat(bin).ino)
        assert.equals("9.9.2", cliproxy.installed_version())
    end)

    it("changes nothing when the new release fails its checksum", function()
        fake_releases.publish(server, "9.9.2")
        local bin = cliproxy.download({ version = "9.9.2" })
        local before = uv.fs_stat(bin).ino
        fake_releases.publish(server, "9.9.3", { sha = ("0"):rep(64) })
        local r = update()
        assert.is_false(r.ok)
        assert.is_truthy(r.msg:find("checksum mismatch", 1, true))
        assert.equals(before, uv.fs_stat(bin).ino)
        assert.equals("9.9.2", cliproxy.installed_version())
    end)

    it("refuses when binary_path is set, before asking GitHub", function()
        parley.config = { cliproxy = { manage = true, binary_path = "/usr/local/bin/cliproxyapi" } }
        local r = update()
        assert.is_false(r.ok)
        assert.is_truthy(r.msg:find("binary_path is set", 1, true))
        assert.same({}, fake_releases.requests(server))
    end)

    it("refuses when parley does not manage the proxy, before asking GitHub", function()
        parley.config = { cliproxy = { manage = false } }
        assert.is_truthy(update().msg:find("cliproxy.manage is off", 1, true))
        assert.same({}, fake_releases.requests(server))
    end)

    it("restarts parley's own proxy onto the new release", function()
        start_managed("9.9.4")
        fake_releases.publish(server, "9.9.5")
        local r = update()
        assert.is_true(r.ok, r.msg)
        assert.equals("updated 9.9.4 → 9.9.5 — restarting the proxy", r.msg)
        assert.same({ "9.9.5" }, { cliproxy.version_probe("127.0.0.1", proxy_port) })
    end)

    it("leaves a proxy parley did not start running, and says how to replace it", function()
        wipe_install()
        fake_releases.publish(server, "9.9.4", { latest = false })
        cliproxy.download({ version = "9.9.4" })
        fake_releases.publish(server, "9.9.6")
        -- a cliproxy parley did not launch holds the port (think brew services)
        spawn_fake({ "--port", tostring(proxy_port), "--management-key", "k" }, { PARLEY_FAKE_CPA_VERSION = "1.0.0" })
        ready_port.wait_listening(proxy_port)
        local r = update()
        assert.is_true(r.ok, r.msg)
        assert.is_truthy(r.msg:find("updated 9.9.4 → 9.9.6", 1, true))
        assert.is_truthy(r.msg:find("was not started by parley", 1, true))
        assert.is_truthy(r.msg:find("still runs 1.0.0", 1, true))
        assert.same({ "1.0.0" }, { cliproxy.version_probe("127.0.0.1", proxy_port) }) -- untouched
    end)

    it("refuses a second update while the first is still restarting", function()
        start_managed("9.9.4")
        fake_releases.publish(server, "9.9.7")
        local first, second
        cliproxy.update(function(ok, msg)
            first = { ok = ok, msg = msg }
        end)
        cliproxy.update(function(ok, msg)
            second = { ok = ok, msg = msg }
        end)
        -- Wait for the first update's restart BEFORE any assertion: returning
        -- early would leave its spawn in flight past after_each (PQ-5).
        vim.wait(25000, function()
            return first ~= nil
        end, 20)
        assert.same({ ok = false, msg = "an update is already running" }, second)
        assert.is_true(first and first.ok, first and first.msg)
    end)

    it("answers, and releases the guard, when the restart never does", function()
        start_managed("9.9.4")
        fake_releases.publish(server, "9.9.8")
        cliproxy._set_update_restart_deadline_ms(300)
        local saved = cliproxy.restart_managed
        -- An async leg that raised and never answered. Stubbed for the WHOLE
        -- body, so nothing this case starts can spawn after after_each (PQ-5).
        cliproxy.restart_managed = function() end
        local r = update()
        local again = update()
        cliproxy.restart_managed = saved
        assert.is_false(r.ok)
        assert.is_truthy(r.msg:find("the restart did not answer", 1, true))
        assert.are_not.equal("an update is already running", again.msg)
    end)

    it("no longer offers the restart that skips the port wait", function()
        assert.is_nil(cliproxy.restart)
    end)
end)
```

- [x] **Step 2: Run to verify they fail** — `update` still returns synchronously
without a callback; the restart and foreign-proxy cases fail.

- [x] **Step 3: Share the ps read, and name the port's owner**

In `lua/parley/cliproxy.lua`, directly above `M.peers`:

```lua
-- `ps ax -o pid,lstart,command`, or nil when the process table is unreadable.
-- pcall: vim.system RAISES (EPERM) rather than returning an error when the
-- process table is unreadable — sandboxes and hardened runtimes do this.
local function ps_output()
    if vim.fn.executable("ps") ~= 1 then
        return nil
    end
    local ok, res = pcall(function()
        return vim.system({ "ps", "ax", "-o", "pid,lstart,command" }, { text = true }):wait()
    end)
    return (ok and res) and res.stdout or nil
end

-- Who holds the managed port: { ours, exe } or nil (cliproxy_release.
-- running_identity). Synchronous ps + lsof (~80-150 ms); :ParleyProxy update
-- only, never the dispatch path. A read failure yields "not ours", so update
-- never restarts a process it could not identify.
local function port_identity(port)
    return rel.running_identity(ca.parse_ps(ps_output()), pids_on_port(port), config_path())
end
```

Rewrite `M.peers`'s body on `ps_output` (keep its docstring):

```lua
function M.peers()
    local out = ps_output()
    if not out then
        return {}
    end
    local opts = render_opts()
    local port_pids = (opts.host and opts.port) and pids_on_port(opts.port) or {}
    return ca.parse_peers(out, M.spawned_pids(), port_pids)
end
```

- [x] **Step 4: Write `M.update`; delete `M.restart`**

Delete `M.restart` (lines 799-803). At the end of the release section:

```lua
local _update_in_flight = false
-- Longer than restart_managed's own budget (PORT_RELEASE_MS + POLL_BUDGET_MS +
-- probes, ~11 s), so it fires only when the restart truly never answers (PQ-3).
local UPDATE_RESTART_DEADLINE_MS = 20000
local _update_restart_deadline_ms = UPDATE_RESTART_DEADLINE_MS

--- Test seam: shorten update's restart deadline (nil restores the default).
---@param ms number|nil
function M._set_update_restart_deadline_ms(ms)
    _update_restart_deadline_ms = ms or UPDATE_RESTART_DEADLINE_MS
end

--- :ParleyProxy update (#237): install cliproxy.download_version, else the
--- latest release, and restart the proxy when parley launched it. Everything
--- up to the restart is synchronous (the editor blocks for the fetch); the
--- restart is not, so an in-flight guard refuses a second update until this one
--- has answered. cb(ok, message) runs exactly once, on every path.
---@param cb fun(ok: boolean, message: string)
function M.update(cb)
    if _update_in_flight then
        return cb(false, "an update is already running")
    end
    local refusal = rel.update_refusal({ managed = M.is_managed(), binary_path = (cfg() or {}).binary_path })
    if refusal then
        return cb(false, refusal)
    end
    _update_in_flight = true
    local answered = false
    local function finish(ok, msg)
        if answered then
            return
        end
        answered = true
        _update_in_flight = false
        cb(ok, msg)
    end
    local ok, err = pcall(function()
        local target, target_err, pinned = M.resolve_target()
        local ep = endpoint_opts()
        local running
        if ep.host then
            local version, reason = M.version_probe(ep.host, ep.port)
            if reason ~= "down" then
                local id = port_identity(ep.port)
                running = { version = version, ours = id ~= nil and id.ours, exe = id and id.exe, port = ep.port }
            end
        end
        local plan = rel.plan_update({ target = target, target_err = target_err, pinned = pinned,
            installed = M.installed_version(), running = running })
        if not plan.ok then
            return finish(false, plan.message)
        end
        if plan.install then
            local bin, derr = M.download({ version = plan.install })
            if not bin then
                return finish(false, "update failed — " .. tostring(derr))
            end
        end
        if plan.restart == "managed" then
            -- restart_managed answers within its own budget, but a raise inside
            -- one of its async legs would never reach finish and would wedge the
            -- guard for the session (PQ-3). The deadline is the terminal owner of
            -- last resort; finish drops whichever answer arrives second.
            vim.defer_fn(function()
                finish(false, plan.message .. "; the restart did not answer — check :ParleyProxy status")
            end, _update_restart_deadline_ms)
            return M.restart_managed(function()
                finish(true, plan.message)
            end, function(msg)
                finish(false, plan.message .. "; the restart failed — " .. tostring(msg))
            end)
        end
        finish(true, plan.message)
    end)
    if not ok then
        logger.error("cliproxy update: " .. tostring(err))
        finish(false, "update failed — unexpected error (details in the parley log)")
    end
end
```

- [x] **Step 5: Wire the command**

In `lua/parley/init.lua` `register_proxy_command`:

- `SUBS_HELP`: replace the `update` row with
  `{ name = "update", desc = "install the latest cliproxyapi release (or cliproxy.download_version), restarting parley's proxy" },`
- Replace the `update` branch (lines 374-381) with:

```lua
		elseif sub == "update" then
			vim.notify("cliproxy: finding the release to install…", vim.log.levels.INFO)
			cliproxy.update(function(ok, msg)
				vim.notify("cliproxy: " .. msg, ok and vim.log.levels.INFO or vim.log.levels.ERROR)
			end)
```

- Replace `cliproxy.restart(` in the `restart` branch (line 383) with
  `cliproxy.restart_managed(`; the callbacks stay as they are.

Append to `tests/integration/cliproxy_command_spec.lua`, inside the top-level
`describe`:

```lua
    describe("update and restart", function()
        local cliproxy = require("parley.cliproxy")
        local saved_update, saved_restart

        before_each(function()
            saved_update, saved_restart = cliproxy.update, cliproxy.restart_managed
        end)

        after_each(function()
            cliproxy.update, cliproxy.restart_managed = saved_update, saved_restart
        end)

        it("update reports the outcome as INFO", function()
            cliproxy.update = function(cb)
                cb(true, "updated 7.1.71 → 7.2.158 — restarting the proxy")
            end
            local msgs = capture_notify(function()
                vim.cmd("ParleyProxy update")
            end)
            assert.equals("cliproxy: updated 7.1.71 → 7.2.158 — restarting the proxy", msgs[#msgs].msg)
            assert.equals(vim.log.levels.INFO, msgs[#msgs].level)
        end)

        it("update reports a failure as ERROR", function()
            cliproxy.update = function(cb)
                cb(false, "could not find the latest cliproxyapi release (unreachable: x)")
            end
            local msgs = capture_notify(function()
                vim.cmd("ParleyProxy update")
            end)
            assert.equals(vim.log.levels.ERROR, msgs[#msgs].level)
        end)

        it("restart goes through restart_managed, which waits for the old proxy", function()
            local called = false
            cliproxy.restart_managed = function(on_ready)
                called = true
                on_ready()
            end
            local msgs = capture_notify(function()
                vim.cmd("ParleyProxy restart")
            end)
            assert.is_true(called)
            assert.equals("cliproxy: restarted", msgs[#msgs].msg)
        end)

        it("the help says update installs the latest release", function()
            local msgs = capture_notify(function()
                vim.cmd("ParleyProxy")
            end)
            assert.is_truthy(msgs[1].msg:find("install the latest cliproxyapi release", 1, true))
        end)
    end)
```

- [x] **Step 6: Run the update and command specs, then `make lint`** — PASS.

- [x] **Step 7: Commit**

```bash
git add lua/parley/cliproxy.lua lua/parley/init.lua \
  tests/integration/cliproxy_update_spec.lua tests/integration/cliproxy_command_spec.lua
git commit -m "#237 M1: update installs the latest release and restarts only parley's proxy"
```

### Task 8: First-run auto_download follows the same rule

**Files:**
- Modify: `lua/parley/cliproxy.lua` (`M.ensure_running`, the down branch, lines 719-737)
- Test: `tests/integration/cliproxy_lifecycle_spec.lua` (lines 361-393), `tests/integration/cliproxy_update_spec.lua`

- [x] **Step 1: Write the failing tests**

In `tests/integration/cliproxy_lifecycle_spec.lua`, change the first
auto_download case (lines 361-376) so it pins and asserts what `download` was
asked for:

```lua
        it("auto_download=true downloads the target release when no binary is found, then proceeds", function()
            local port = ready_port.free_port()
            set_endpoint(port)
            path_without_cliproxy()
            vim.env.PARLEY_FAKE_MODE = "healthy"
            parley.config = { cliproxy = { manage = true, auto_download = true,
                binary_path = "/no/such", download_version = "9.9.9" } }
            local saved_dl, dl_opts = cliproxy.download, nil
            cliproxy.download = function(o) -- stand in for the network fetch; hand back a spawnable binary
                dl_opts = o
                return FAKE
            end
            local outcome = run_ensure()
            cliproxy.download = saved_dl
            assert.same({ version = "9.9.9" }, dl_opts) -- resolve_target chose the pin
            assert.is_true(outcome.ok)
        end)
```

The "does NOT download when auto_download is unset" case is unchanged.

Append to `tests/integration/cliproxy_update_spec.lua`:

```lua
describe("first-run auto_download", function()
    local parley = require("parley")
    local saved_config, saved_path, port

    before_each(function()
        saved_config, saved_path = parley.config, vim.env.PATH
        vim.env.PATH = "/usr/bin:/bin:/usr/sbin:/sbin"
        port = ready_port.free_port()
        parley.dispatcher = parley.dispatcher or {}
        parley.dispatcher.providers = parley.dispatcher.providers or {}
        parley.dispatcher.providers.cliproxyapi = {
            endpoint = ("http://127.0.0.1:%d/v1/chat/completions"):format(port),
        }
        require("parley.vault").add_secret("cliproxyapi", "testkey")
        local mb = cliproxy.managed_binary()
        if mb then
            vim.fn.delete(mb)
            vim.fn.delete(mb .. ".version")
        end
        parley.config = { cliproxy = { manage = true, auto_download = true } }
        cliproxy._set_releases_url(server.url)
    end)

    after_each(function()
        cliproxy.stop()
        cliproxy._reset_spawned()
        cliproxy._set_releases_url(server.url)
        parley.config, vim.env.PATH = saved_config, saved_path
    end)

    local function ensure()
        return await(function(done)
            cliproxy.ensure_running(function()
                done({ ok = true })
            end, function(msg)
                done({ ok = false, msg = msg })
            end)
        end)
    end

    it("installs the latest release, not a version baked into parley", function()
        fake_releases.publish(server, "9.9.8")
        local r = ensure()
        assert.is_true(r.ok, r.msg)
        assert.equals("9.9.8", cliproxy.installed_version())
        assert.same({ "9.9.8" }, { cliproxy.version_probe("127.0.0.1", port) })
    end)

    it("fails clearly when no release can be chosen", function()
        cliproxy._set_releases_url(dead_url())
        local r = ensure()
        assert.is_false(r.ok)
        assert.is_truthy(r.msg:find("auto_download could not choose a release", 1, true))
    end)
end)
```

- [x] **Step 2: Run both specs to verify they fail** — `dl_opts` is `nil`/`{}`
(download still called with no version); the first-run case installs nothing.

- [x] **Step 3: Implement**

Replace the down branch of `ensure_running` (lines 719-737) with:

```lua
        -- down → spawn our own
        local function spawn_and_poll(bin)
            local pid, err = M.spawn(bin, path)
            if not pid then
                return on_error("cliproxy: failed to spawn " .. bin .. ": " .. tostring(err))
            end
            poll_until_healthy(host, port, secret, pid, callback, on_error)
        end
        local bin = M.discover_binary()
        if not bin and (cfg() or {}).auto_download then
            -- The same target rule as :ParleyProxy update (#237). Synchronous,
            -- like the download after it, so this branch keeps the interleavings
            -- it had.
            local version, verr = M.resolve_target()
            if not version then
                return on_error("cliproxy: auto_download could not choose a release — " .. tostring(verr))
            end
            vim.notify(("cliproxy: downloading %s (one-time)…"):format(version), vim.log.levels.INFO)
            local dlbin, derr = M.download({ version = version })
            if not dlbin then
                return on_error("cliproxy: auto_download failed — " .. tostring(derr))
            end
            return spawn_and_poll(dlbin)
        end
        if not bin then
            return on_error("cliproxy: no cliproxy binary found — `brew install cliproxyapi`, "
                .. "set cliproxy.binary_path, or enable auto_download")
        end
        spawn_and_poll(bin)
```

- [x] **Step 4: Run both specs** — PASS; `make lint` clean.

- [x] **Step 5: Commit**

```bash
git add lua/parley/cliproxy.lua tests/integration/cliproxy_lifecycle_spec.lua \
  tests/integration/cliproxy_update_spec.lua
git commit -m "#237 M1: first-run auto_download installs the latest release too"
```

### Task 9: M1 docs, gate and boundary

**Files:**
- Modify: `lua/parley/config.lua` (cliproxy block comment, lines 119-125)
- Modify: `atlas/providers/cliproxy-managed.md` (lines 24-29, 62, 370-381)
- Modify: `atlas/traceability.yaml` (already updated in Task 5 — confirm)

- [x] **Step 1: Config comment.** Replace the `auto_download` comment lines
(119-125) with:

```lua
		auto_download = true,  -- if no cliproxy binary is found, fetch the latest
		--   checksum-verified release into stdpath('data') (skips `brew install`).
		--   ON in this config. NOTE: auto-fetching an executable is a trust
		--   decision — a general distribution may prefer to comment this out (the
		--   original opt-in default; see issue #131 spec). `:ParleyProxy update`
		--   installs the latest release and restarts a proxy parley launched;
		--   set `download_version = "7.2.158"` to pin one instead.
```

- [x] **Step 2: Atlas.** In `atlas/providers/cliproxy-managed.md`:
  - Pieces: add a bullet for **`cliproxy_release.lua`** (pure, #237): version
    grammar, redirect and header parsers, `running_identity`, `update_refusal`,
    `plan_update`, `version_summary`. In the `cliproxy.lua` bullet, make the
    discovery chain `binary_path` → the managed download → `cliproxyapi`/
    `cli-proxy-api` on PATH; list `version_probe`, `latest_release`,
    `resolve_target`, `update`; replace `restart` with `restart_managed`; note
    `api_argv`'s `dump_headers` option.
  - Line 62: "`restart` = `stop` + ensure" → "`restart` = `restart_managed`:
    `stop`, wait for the port, ensure".
  - Replace the `## auto_download (M2)` section with `## Releases: auto_download
    and update (#131 M2, #237)` covering: the target rule (`download_version`,
    else GitHub's `releases/latest` redirect; no built-in pin), the staged
    rename and `cli-proxy-api.version` record, the refusals, what "parley's
    proxy" means (`-config <config.yaml>` on the listener) and why a proxy parley
    did not launch is left running, the in-flight guard, the synchronous fetch
    and its time limits, `$PARLEY_CLIPROXY_RELEASES_URL`/`_set_releases_url`, and
    the release fake.
  - Before editing, `grep -n -i -E "pinned|restart|update|download" atlas/providers/cliproxy-managed.md`
    and walk every hit, not only the named lines (the #128 lesson: a name-only
    sweep missed behavior lines four times).

- [x] **Step 3: Gate.** Run `make test`. Expected: exit 0, lint 0 warnings.
Then `PARLEY_LIVE_GITHUB=1` is not yet wired (Task 13); skip.

- [x] **Step 4: Commit and cross the boundary**

```bash
git add lua/parley/config.lua atlas/providers/cliproxy-managed.md atlas/traceability.yaml
git commit -m "#237 M1: atlas and config describe the latest-release update"
sdlc milestone-close --issue 237 --milestone M1
```

Fix every Critical/Important finding before M2; log the verdict in the issue.

---

## Chunk 2: M2 — status shows the running version against the latest

### Task 10: The status version text

**Files:**
- Modify: `lua/parley/cliproxy_release.lua`
- Test: `tests/unit/cliproxy_release_spec.lua`

- [x] **Step 1: Write the failing tests**

```lua
describe("version_summary", function()
    local CMD = ":ParleyProxy update"

    it("marks a current proxy", function()
        assert.equals("7.2.158 (latest)", rel.version_summary({ running = "7.2.158", latest = "7.2.158" }, CMD))
    end)

    it("tells the user how to catch up", function()
        assert.equals("7.1.71 (latest 7.2.158 — run :ParleyProxy update)",
            rel.version_summary({ running = "7.1.71", latest = "7.2.158" }, CMD))
    end)

    it("does not nag when a pin is what holds the version back", function()
        assert.equals("7.1.71 (pinned to 7.1.71; latest 7.2.158)",
            rel.version_summary({ running = "7.1.71", latest = "7.2.158", pinned = "7.1.71" }, CMD))
    end)

    it("points at update when the running version is not the pin", function()
        assert.equals("7.2.158 (pinned to 7.1.71 — run :ParleyProxy update; latest 7.2.158)",
            rel.version_summary({ running = "7.2.158", latest = "7.2.158", pinned = "7.1.71" }, CMD))
    end)

    it("does not call a build newer than the latest stale", function()
        assert.equals("7.3.0 (latest 7.2.158)",
            rel.version_summary({ running = "7.3.0", latest = "7.2.158" }, CMD))
    end)

    it("says why the latest is unknown", function()
        assert.equals("7.1.71 (latest unknown: unreachable: curl: (7) x)",
            rel.version_summary({ running = "7.1.71", latest_err = "unreachable: curl: (7) x" }, CMD))
    end)

    it("reports a stopped proxy with the installed version, never a guess", function()
        assert.equals("not running (installed 7.2.158; latest 7.2.158)",
            rel.version_summary({ running_err = "down", installed = "7.2.158", latest = "7.2.158" }, CMD))
        assert.equals("not running (latest 7.2.158)",
            rel.version_summary({ running_err = "down", latest = "7.2.158" }, CMD))
    end)

    it("says when a running proxy reports no version", function()
        assert.equals("unknown — the proxy sent no version header (latest 7.2.158)",
            rel.version_summary({ running_err = "no_header", latest = "7.2.158" }, CMD))
    end)
end)
```

- [x] **Step 2: Run to verify they fail** — `version_summary` is nil.

- [x] **Step 3: Implement** (before `return M`):

```lua
--- The `version:` value :ParleyProxy status prints (#237).
---@param v table # { running?, running_err?, installed?, latest?, latest_err?, pinned? }
---@param update_cmd string # e.g. ":ParleyProxy update"
---@return string
function M.version_summary(v, update_cmd)
    local latest = v.latest and ("latest " .. v.latest)
        or ("latest unknown: " .. tostring(v.latest_err or "not checked"))
    if not v.running then
        if v.running_err == "no_header" then
            return ("unknown — the proxy sent no version header (%s)"):format(latest)
        end
        local parts = {}
        if v.installed then
            parts[#parts + 1] = "installed " .. v.installed
        end
        parts[#parts + 1] = latest
        return ("not running (%s)"):format(table.concat(parts, "; "))
    end
    local run = v.running
    if v.pinned then
        local pin = run == v.pinned and ("pinned to " .. v.pinned)
            or ("pinned to %s — run %s"):format(v.pinned, update_cmd)
        return ("%s (%s; %s)"):format(run, pin, latest)
    end
    if v.latest and M.compare_versions(run, v.latest) < 0 then
        return ("%s (latest %s — run %s)"):format(run, v.latest, update_cmd)
    end
    if v.latest and run == v.latest then
        return run .. " (latest)"
    end
    return ("%s (%s)"):format(run, latest)
end
```

- [x] **Step 4: Run to verify they pass**; `make lint`.

- [x] **Step 5: Commit** — `#237 M2: the status version line, pure`.

### Task 11: `status` joins health, version and latest

**Files:**
- Modify: `lua/parley/cliproxy.lua` (`M.status`, lines 826-855)
- Test: `tests/integration/cliproxy_update_spec.lua`

- [x] **Step 1: Write the failing tests**

Append to `tests/integration/cliproxy_update_spec.lua` (reuse the
`start_managed` shape from Task 7 — lift it and `set_endpoint` to file scope if
two describes need them):

```lua
describe("status version", function()
    -- set_endpoint, start_managed and proxy_port are shared with the
    -- ":ParleyProxy update" describe: lift them to file scope, above both.
    local parley = require("parley")
    local saved_config, saved_path

    before_each(function()
        saved_config, saved_path = parley.config, vim.env.PATH
        vim.env.PATH = "/usr/bin:/bin:/usr/sbin:/sbin" -- no brew binary (#197)
        proxy_port = ready_port.free_port()
        set_endpoint(proxy_port)
        parley.config = { cliproxy = { manage = true } }
        cliproxy._set_releases_url(server.url)
    end)

    -- Owns every process a case starts (Process ownership, PQ-1).
    after_each(function()
        reap()
        cliproxy.stop()
        cliproxy._reset_spawned()
        cliproxy._set_releases_url(server.url)
        parley.config, vim.env.PATH = saved_config, saved_path
    end)

    it("reports the running version against the latest", function()
        start_managed("9.9.4")
        fake_releases.publish(server, "9.9.5")
        local info = await(function(done)
            cliproxy.status(done)
        end)
        assert.equals("9.9.4", info.version.running)
        assert.equals("9.9.5", info.version.latest)
        assert.equals("9.9.4", info.version.installed)
        assert.equals("managed", info.binary_source)
    end)

    it("answers once, after the slowest read, whatever the order", function()
        local slow = start_server("slow")
        fake_releases.publish(slow, "9.9.5")
        cliproxy._set_releases_url(slow.url)
        local calls = 0
        local info
        cliproxy.status(function(i)
            calls = calls + 1
            info = i
        end)
        vim.wait(8000, function()
            return info ~= nil
        end, 20)
        vim.wait(300, function()
            return false
        end) -- a second callback would land here
        assert.equals(1, calls)
        assert.equals("9.9.5", info.version.latest)
    end)

    it("says the proxy is not running rather than guessing", function()
        local info = await(function(done)
            cliproxy.status(done)
        end)
        assert.is_nil(info.version.running)
        assert.equals("down", info.version.running_err)
    end)

    it("does not contact GitHub when parley does not manage the proxy", function()
        parley.config = { cliproxy = { manage = false } }
        fake_releases.clear_requests(server)
        local info = await(function(done)
            cliproxy.status(done)
        end)
        assert.is_nil(info.version.latest)
        assert.equals("not checked: cliproxy.manage is off", info.version.latest_err)
        assert.same({}, fake_releases.requests(server))
    end)
end)
```

- [x] **Step 2: Run to verify they fail** — `info.version` is nil.

- [x] **Step 3: Implement.** Replace `M.status` with:

```lua
--- Gather a status snapshot (#131, #237). Health, the running version and the
--- latest release are read in parallel and complete in IO order; cb(info) runs
--- once, when the last lands (ARCH-ORDER). Each read is bounded, so this
--- always answers.
---@param cb fun(info: table)
function M.status(cb)
    local bin = M.discover_binary()
    local c = cfg() or {}
    local opts = render_opts()
    local source = "none"
    if bin then
        if c.binary_path == bin then
            source = "binary_path"
        elseif bin == M.managed_binary() then
            source = "managed"
        else
            source = "PATH"
        end
    end
    local info = {
        managed = M.is_managed(),
        binary = bin,
        binary_source = source,
        host = opts.host,
        port = opts.port,
        auth_dir = c.auth_dir,
        config_path = config_path(),
        spawned_by_parley = #M.spawned_pids() > 0,
        config_drift = config_drift(),
        version = { installed = M.installed_version(), pinned = rel.parse_version(c.download_version) },
    }
    local reads = opts.host and 3 or 1
    local function landed()
        reads = reads - 1
        if reads == 0 then
            cb(info)
        end
    end
    if not opts.host then
        info.health = "unknown"
        info.version.running_err = "no endpoint"
    else
        M.health_probe(opts.host, opts.port, opts.secret, function(state)
            info.health = state
            landed()
        end)
        M.version_probe(opts.host, opts.port, function(v, reason)
            info.version.running, info.version.running_err = v, reason
            landed()
        end)
    end
    if not info.managed then
        -- Opted out: status must not reach github.com on parley's behalf (PQ-2).
        info.version.latest_err = "not checked: cliproxy.manage is off"
        landed()
    else
        M.latest_release(function(v, err)
            info.version.latest, info.version.latest_err = v, err
            landed()
        end, M.STATUS_LATEST_MAX_TIME)
    end
end
```

- [x] **Step 4: Run the update spec and the lifecycle spec** (its status test
at 451-471 must stay green; its latest read now fails fast against the harness's
dead URL). `make lint`.

- [x] **Step 5: Commit** — `#237 M2: status reads the running version and the latest in parallel`.

### Task 12: `:ParleyProxy status` prints the version

**Files:**
- Modify: `lua/parley/init.lua` (`SUBS_HELP` status row; the `status` branch, lines 351-364)
- Test: `tests/integration/cliproxy_command_spec.lua`

- [x] **Step 1: Write the failing test** (inside the `update and restart`
describe, or a sibling):

```lua
        it("status prints the version line", function()
            local saved = cliproxy.status
            cliproxy.status = function(cb)
                cb({ managed = true, health = "healthy", binary = "/b", binary_source = "managed",
                    host = "127.0.0.1", port = 8317, config_path = "/c", spawned_by_parley = true,
                    config_drift = false, version = { running = "7.1.71", latest = "7.2.158" } })
            end
            local msgs = capture_notify(function()
                vim.cmd("ParleyProxy status")
            end)
            cliproxy.status = saved
            local out = msgs[1].msg
            assert.is_truthy(out:find("version:       7.1.71 (latest 7.2.158 — run :ParleyProxy update)", 1, true))
            assert.is_truthy(out:find("/b (managed)", 1, true))
        end)
```

- [x] **Step 2: Run to verify it fails** — no `version:` line.

- [x] **Step 3: Implement.** In the `status` branch, insert after the `health`
line:

```lua
					"  version:       " .. require("parley.cliproxy_release").version_summary(
						info.version, ":" .. prefix .. "Proxy update"),
```

and change the `SUBS_HELP` status row to
`{ name = "status", desc = "show proxy health, version vs latest, endpoint, binary, drift" },`.

- [x] **Step 4: Run the command spec** — PASS; `make lint`.

- [x] **Step 5: Commit** — `#237 M2: :ParleyProxy status shows the version`.

### Task 13: Conformance, docs, live check, close

**Files:**
- Modify: `tests/integration/cliproxy_conformance_spec.lua`
- Modify: `atlas/providers/cliproxy-managed.md`, `README.md` (line 221)

- [x] **Step 1: Conformance cases** — append inside the conformance `describe`:

```lua
    -- #237: the running version comes from X-Cpa-Version on a /v0/management/*
    -- response, read WITHOUT a credential. The fake stamps it; only the real
    -- binary can say the header still exists.
    local function probe_until_up(p)
        local v, reason
        vim.wait(20000, function()
            v, reason = cliproxy.version_probe("127.0.0.1", p)
            return reason ~= "down"
        end, 250)
        return v, reason
    end

    it("stamps X-Cpa-Version on an unauthenticated management response", function()
        if not binary then
            pending("cliproxyapi binary not available")
            return
        end
        local p = boot()
        local v, reason = probe_until_up(p)
        assert.is_string(v, "no X-Cpa-Version from the real binary (reason: " .. tostring(reason) .. ")")
    end)

    it("pins whether the header survives with management disabled", function()
        if not binary then
            pending("cliproxyapi binary not available")
            return
        end
        local p = boot(true)
        local v = probe_until_up(p)
        -- fake_cliproxy stamps only when a management key is configured. If
        -- this fails, the real binary stamps regardless: change the fake's
        -- end_headers to match, then flip this assertion.
        assert.is_nil(v, "the real binary sends X-Cpa-Version with management disabled")
    end)

    it("resolves the real latest release from GitHub (PARLEY_LIVE_GITHUB=1)", function()
        if vim.env.PARLEY_LIVE_GITHUB ~= "1" then
            pending("set PARLEY_LIVE_GITHUB=1 to check the real releases/latest redirect")
            return
        end
        cliproxy._set_releases_url("https://github.com/router-for-me/CLIProxyAPI/releases")
        local v, err = cliproxy.latest_release()
        cliproxy._set_releases_url(nil)
        assert.is_string(v, err)
    end)
```

Run the conformance spec with a real binary discoverable (the managed download
or brew). If "management disabled" fails, align the fake and the assertion as
the comment says, and record it in the Log. Then run
`PARLEY_LIVE_GITHUB=1 nvim -n --headless --noplugin -u tests/minimal_init.vim -c "PlenaryBustedFile tests/integration/cliproxy_conformance_spec.lua" -c "qa!"`
— the live check overrides the harness URL itself.

- [x] **Step 2: Docs.** Atlas: a `### Versions and status` subsection under the
Releases section (the `X-Cpa-Version` source and why no credential is sent; the
latest from the same redirect; the `version:` line's forms; the live checks and
how to run them). README line 221: after the subcommand list add "`update`
installs the latest release (pin one with `cliproxy.download_version`); `status`
shows the running version against the latest." Grep README and atlas for
`ParleyProxy` and walk every hit (#187, #176).

- [ ] **Step 3: Live check (operator, or with consent — it touches the real
proxy and data dir).** With no `download_version` set: `:ParleyProxy update` →
expect "updated 7.1.71 → 7.2.158 — restarting the proxy"; `:ParleyProxy status`
→ `version: 7.2.158 (latest)`; then a Fable chat through cliproxyapi answers.
Record the three outputs in the Log.

- [ ] **Step 4: Gate and close.** `make test` exit 0 (lint included). Reconcile
every checkbox in this plan against commits (#186). Then
`sdlc milestone-close --issue 237 --milestone M2`, and `sdlc close --issue 237
--verified '<make test result; conformance + live GitHub result; the three live
outputs>'`.

---

## Revisions

### 2026-09-11 — plan-quality round 1

**Reason.** The change-code gate refused on PQ-1 (Important) and recorded three
Minor findings. All four are fixed here rather than carried to the close review.

**Delta.**

- PQ-1 (`fixture-process-leak`), fixed as a class. The Process ownership
  section enumerates every process the plan's specs start and names its owner
  for a failing assertion and for a crashed nvim. New
  `tests/fixtures/fixture_watchdog.py` makes a fixture exit with the nvim that
  started it: always on for `fake_github_releases`, opt-in
  (`PARLEY_FAKE_EXIT_WITH_PARENT=1`) for `fake_cliproxy`, which the release
  wrapper and `spawn_fake` both set. The update spec registers every spawned
  handle and server and reaps them in `after_each`; no `kill` remains as the
  last line of an `it`, and every handle is asserted.
- PQ-2: `status` skips the latest-release read when `cliproxy.manage` is off,
  with a test that the release fake sees no request.
- PQ-3: `update` arms a deadline (`UPDATE_RESTART_DEADLINE_MS`, 20 s) when it
  restarts, so an async leg that never answers cannot wedge the in-flight
  guard. `_set_update_restart_deadline_ms` is the test seam, and a test proves a
  later update is accepted after the deadline fires.
- PQ-4: the ARCH-ORDER table splits "not ours" from "nothing listening" to match
  what `plan_update` says.

### 2026-09-11 — plan-quality round 2

**Reason.** The gate cleared the plan and recorded one Minor, PQ-5, the second
finding in `fixture-process-leak`: ownership was enumerated by who starts a
process, not by when, so a case could return while an async leg it started could
still spawn.

**Delta.** Process ownership gains the temporal rule — an `it` body must not
return while an async leg it started can still spawn — and a table of every case
with such a leg. The restart-deadline case keeps `restart_managed` stubbed across
both calls; the second-update case waits for the first update before asserting;
and `await`'s timeout rises to 25 s, above `UPDATE_RESTART_DEADLINE_MS`, so no
wait can give up while the leg it waits on is still bound to answer.

### 2026-09-12 — implementation: the plan-symbol arch check

**Reason.** `tests/arch/single_source_sweeps_spec.lua` requires every plain
backticked name in a plan table row that starts with a backticked cell to have a
Lua definition in the tree. Three kinds of name in these tables could never
satisfy it, and one would have turned M1's boundary red.

**Delta.**

- Task 10's pure `version_summary` moves into M1, so M1 closes with every symbol
  its tables name defined; M2 is Tasks 11–13 (the status wiring, docs, live
  checks).
- Fixture rows name the fixture by path (`tests/fixtures/…`): the check resolves
  Lua definitions, and a Python fixture has none.
- Process-ownership rows start with plain words, since that table is not a
  symbol inventory and its cells name plenary's `after_each`.
- The `M.download` row writes `uv.fs_rename`, the libuv call it wraps.

### 2026-09-12 — implementation: M1 notes

- The branch-scoped arch check also runs code→table: every module function the
  branch adds, or whose definition line changes, must appear by bare name in a
  Core-concepts row. The integration-point rows now name `version_probe`,
  `update` and the rest bare (a dotted `M.x` does not match), and `peers` gets a
  row because it now reads through `ps_output`. `M.restart` stays dotted: a bare
  `restart` in its `deleted` row would match the quoted `"restart"` subcommand
  name in `init.lua`.
- Identity needs `ps`, which an agent sandbox refuses (EPERM). `port_identity`
  degrades to "not ours", so update never restarts on doubt; the three identity
  cases in the update spec report `pending` where `ps` is unavailable, following
  the conformance spec's precedent, and were run unsandboxed in the harness's
  isolation (26/0/0, none pending).
- `port_identity` wraps its whole read in `pcall`, so a refused `lsof` cannot
  raise into `update`.

### 2026-09-12 — M1 review round 1 (FIX-THEN-SHIP)

The boundary review (window 27bac4f4..615dd8a1) raised one Important finding and
six Minor ones. Each is fixed as a class, except one deferral:

- **README drift (BR-1, Important).** Every text that told a new machine it
  needs `brew install` now names `:ParleyProxy update` first: README line 221,
  the atlas intro, the `config.lua` comment, and both "no cliproxy binary found"
  errors, which now share one `NO_BINARY` text. The README's `update` sentence
  moves here from Task 13; M2 adds only the `status` half.
- **Test seam in production.** `releases_url()` honours
  `$PARLEY_CLIPROXY_RELEASES_URL` only when `$PARLEY_TEST_MODE` is `1`, the
  signal `tests/minimal_init.vim` already exports (#227). New row
  `_releases_url`: the accessor the harness case uses to check which root wins
  without contacting it. Trust boundaries updated.
- **Outcome severity.** `plan_update` marks the manual case `warn`; `update`
  passes it to its callback as a third value, and `:ParleyProxy update` shows it
  at WARN.
- **Message provenance.** A port holder that sends no `X-Cpa-Version` is no
  longer called an older cliproxyapi with a brew hint; the message says only
  that parley did not start it and that it reports no version.
- **Helper duplication.** The wait loop behind `await` lives once, in
  `tests/helpers/await.lua` (`await` fails on timeout; `settle` returns
  `settled, result`). The update, lifecycle and login specs bind their own
  budgets to it. Deferred: the `spawn_fake`/`reap` ownership registry goes to
  #220, whose subject is who owns a spec's fixture processes.
- **Error-path coverage.** A case for update's "the restart failed" cell.
- **Plan tracking.** The M1 steps are ticked at this close.
- **Notice before a blocking call.** `:ParleyProxy update` and first-run
  auto_download redraw after their notice, so it shows before the fetch blocks.

### 2026-09-12 — M1 review round 2 (FIX-THEN-SHIP)

Round 2 disposed round 1's seven findings and found the rule behind BR-4
unswept (BR-8, Important): every claim in an outcome message must come from an
observation the call made; where none was possible, the message says so and
names what to check. The outcome messages on this issue's surface, and what
backs each:

| Message | Observation | Before | Now |
|---|---|---|---|
| refusals; "an update is already running" | config; the guard | backed | backed |
| "could not find the latest …"; "update failed — …" | curl, checksum, tar | backed | backed |
| "installed X", "updated A → B", "already at X" | the version record, after the download | backed | backed |
| "was not started by parley … still runs V" | `ps` + `lsof` identity | a failed read counted as "not ours" | a failed read, or a listener missing from the table, is "could not tell (why)"; never restarted |
| "— restarting the proxy", then success | nothing after the restart | asserted | one `version_probe`: "now serving T", or a warning (still the old version; unconfirmed) |
| `:ParleyProxy restart` "restarted" | `restart_managed`'s on_ready | a cliproxyapi still answering after the 2 s wait was reused | reported through on_error, never reused |
| "the restart failed — …"; "did not answer — check …" | the error; the deadline | backed | backed, one renderer |
| status "not running (…)" | `version_probe` said down | also said for a probe never made | only for "down"; otherwise "unknown — why" |

Code: `running_identity` returns `nil, why` when it cannot tell, and
`port_identity` carries the reason (`ps unavailable`, `ps unreadable`, `lsof
unavailable`, …). `plan_update` adds `restart = "unknown"` (warn; never
restarts). `restart_outcome` (new, pure) words the restart's result from the
probe, the error or the deadline. `restart_managed` reports a cliproxyapi still
answering after `PORT_RELEASE_MS` (`is_cliproxy_state`, shared with
`port_holds_cliproxy`); its other callers, the management-route repair and the
recovery ladder's restart rung, get that error instead of a reused dying proxy,
and their specs use the instant-exit fake. `version_summary` says "unknown —
why" for anything but "down".

Minor findings: `pids_on_port` degrades at the IO seam, so a refused `lsof` no
longer raises out of `stop`; `fake_cliproxy` gains `PARLEY_FAKE_EXIT_DELAY_MS`,
and the update spec drives a restart through a slow shutdown; `settle` and
`await` join the Integration points table. New seam `_set_process_tools` names
a missing `ps`, so the "could not tell" case runs in every environment; the case
that says "not started by parley" now needs `ps`.

### 2026-09-12 — M1 review round 3 (FIX-THEN-SHIP, converging)

Round 3 disposed BR-8, BR-9 and BR-11 and found two gaps in how the fixes are
pinned:

- **BR-12 (Important): six identity cases ran only where a real `ps` is
  permitted.** The pins for BR-6, BR-8 and BR-9 went pending in two of three
  review shells. `tests/fixtures/fake_ps` prints the rows a real `ps` would; the
  spec's `ps_sees(rows)` points `_set_process_tools` at it only where `ps` is
  refused, so every identity case runs in every shell and reads the real table
  where it can. `needs_ps` is gone.
- **BR-10 (Minor): `pids_on_port`'s guard was unpinned.** A case points
  `_set_process_tools` at an executable whose interpreter is missing (it passes
  `executable()`, and `vim.system` raises, as it does for a refused `lsof`) and
  asserts that update says "lsof unreadable" and that `stop()` does not raise.
- `running_identity`'s empty-lsof reason says what was observed: "lsof lists no
  process on the port" (a root-owned holder is invisible to a user's lsof).

### 2026-09-12 — M1 closed (review round 4: SHIP)

Round 4 revert-verified both round-3 fixes in a `ps`-refused shell and shipped
M1. Its one advisory finding (readme-surface-drift, the family's second) is
swept in the close commit: the atlas said the identity cases go pending where
`ps` is refused, and now names `fake_ps`. A grep for the old phrase found no
other site.

Carried into M2's live check (Task 13 Step 3): `restart_managed` now fails,
for all four callers, when a cliproxyapi still answers 2 s after SIGTERM. The
real binary drains in-flight requests on shutdown, so a restart during a
streaming chat may report "the restart failed — … still answers 2 s after …"
and then exit on its own. Measure the real binary's port release after
SIGTERM, idle and mid-stream; if the drain routinely takes longer than 2 s,
raise `PORT_RELEASE_MS` or word the message for a request still streaming.

### 2026-09-12 — M2 Task 13: conformance against the real binary

With the real binary on `PATH` (7.2.158 from the release, and a copy of the
installed 7.1.71), the three new cases pass on both. 7.2.158 stamps
`X-Cpa-Version` on an unauthenticated management response and sends none with
remote management disabled, as the fake assumes; the live GitHub redirect
resolves 7.2.158.

The same runs surfaced two things the harness never saw, because no real
binary had been on its `PATH`:

- **`updated_at` changed meaning in 7.2.x.** 7.1.71 copies the credential
  file's mtime into `updated_at` on first load; 7.2.158 stamps its own load
  clock, a moment later. The staleness rung (`modtime > updated_at + skew`)
  reads both as "not stale", so parley is unaffected. The conformance case
  pinned 7.1.71's equality and now pins the property the rung needs.
- **The two #205 catalog cases cannot pass with this spec's fabricated
  credential**, on either build: the proxy registers no models for it, so
  `/v1beta/models` is empty. They predate #237 and ran `pending` until now.
  Left unchanged here for a follow-up; the live check covers the catalog with a
  real login meanwhile.

Two conformance runs each left a plenary child nvim orphaned: a datum for #220.
